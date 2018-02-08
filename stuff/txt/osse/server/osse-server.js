#!/usr/bin/env node
const os = require('os')
const fs = require('fs')
const path = require('path')
const url = require('url')
const cliParams = require('commander')
const http = require('http')
const auth = require('http-auth')
const Busboy = require('busboy')
const base64url = require('base64url')
const mailer = require('./mailer')
const freeipa = require('./freeipa')
const { guid, now, logNotice, logWarning, logError, ensureDirectory, readFile, writeFile, readJSON, getIpUser } = require('./utils')

async function main() {
cliParams
  .version('0.0.1')
  .usage('[options]')
  .option('-c, --config [file]', 'config file','./config.json')
  .option('-g, --generate-config ', 'generate sample config file')
	.option('-p, --port [number]','port to listen')
	.option('-h, --host [number]','host to listen')
	.option('-s, --static [path]','static files to serve')
  .option('-t, --test','test config')
  .option('--users-file [file]','users sessions full path file name')
  .option('--upload-directory [path]','upload path')
  .option('--subscriptions-directory [path]','subscriptions path')
	.option('--smtp-host [host]','smtp host')
	.option('--smtp-port [number]','smtp port')
	.option('--smtp-sender [email]','smtp sender')
	.option('--ipa-server [host]','freeipa server (or any other ldap)')
	.option('--ipa-base [string]','ldap base')
	.option('--ipa-user [string]','ldap bind user')
	.option('--ipa-pass [string]','ldap bind password')
	.option('--ipa-group [string]','ldap search group')
  .parse(process.argv);

  // load config file
  var configFile = {}
  if (!cliParams.generateConfig){
    configFile = await readJSON(cliParams.config)
    if (configFile === false ) {
      if (process.stdout.isTTY) console.log('failded to load config file, try -g to generate sample config')
      process.exit(1);
    }
  }
  // override config with cmd params
  let config = {}
  config.portListen = cliParams.port || configFile.port || '9983'
  config.ipListen = cliParams.host || configFile.host || '127.0.0.1'
  config.usersFile = cliParams.usersFile || configFile.usersFile || '/tmp/osse/users.json'
  config.uploadDirectory = cliParams.uploadDirectory || configFile.uploadDirectory || '/tmp/osse/uploads'
  config.subscriptionsDirectory = cliParams.subscriptionsDirectory || configFile.subscriptionsDirectory || '/tmp/osse/subscriptions'
  config.smtpfrom = cliParams.smtpSender || configFile.smtpSender || 'noreply-osse@localhost'
  config.smtphost = cliParams.smtpHost || configFile.smtpHost || '127.0.0.1'
  config.smtpport = cliParams.smtpPort || configFile.smtpPort || 25
  config.IPASERVER = cliParams.ipaServer || configFile.ipaServer || '127.0.0.1'
  config.BASE = cliParams.ipaBase || configFile.ipaBase || 'cn=accounts,dc=example,dc=org'
  config.bindpass = cliParams.ipaPass || configFile.ipaPass || 'password'
  config.binduser = cliParams.ipaUser || configFile.ipaUser || 'username'
  config.groupName = cliParams.ipaGroup || configFile.ipaGroup || 'osse'
  config.realm = configFile.realm || 'oss-mini'
  config.reauth = configFile.reauth || 1000 * 60
  config.metaFilename = configFile.metaFilename || 'meta.json'
  config.servers = configFile.servers || [{"HR":"hardCodedDefault","type":"solr","proto":"http","host":"localhost","port":8983,"collection":"default","rotationperiod":"none"},{"HR":"hardCodedDefaultElastic","type":"elastic","proto":"http","host":"localhost","port":9200,"collection":"osse","rotationperiod":"yearly"}]
  // generate sample configFile
  if (cliParams.generateConfig) {
    console.log(JSON.stringify(config, null, 2))
    process.exit(0);
  }
  //start with notice
  logNotice({'msg':'starting',config})
  // test paths
  let usersFileDir = await ensureDirectory(path.dirname(config.usersFile))
  if (!usersFileDir) process.exit(1)
  let uploadDirectory = await ensureDirectory(config.uploadDirectory)
  if (!uploadDirectory) process.exit(1)
  let subscriptionsDirectory = await ensureDirectory(config.subscriptionsDirectory)
  if (!subscriptionsDirectory) process.exit(1)

  // test connection to ipa and servers
  if (cliParams.test) {
    console.log('TODO tests')
    //testing ipa
    //testing servers
    process.exit(0);
  }

  let users = await readJSON(config.usersFile)
  if (users === false ) {
    users = {}
    if (process.stdout.isTTY) console.log('fresh start !?, no users sessions history file',config.usersFile)
  }

  let server = http.createServer( async (req, res) => {
    let bittes = req.url.split('?')
    let leftpath = bittes[0] || '/'
    bittes.shift()
    let params = bittes.join('?').split('&')
    // build 1 level nested struct
    // see https://lucene.apache.org/solr/guide/6_6/highlighting.html
    args = {}
    for (let i in params){
        let tmp = params[i].split('=')
        if (!tmp[1]) { tmp[1] = true }
        let nested = tmp[0].split('.')
        if (nested[1]) {
          if (!args[nested[0]]) args[nested[0]] = {}
          args[nested[0]][nested[1]]= tmp[1]
        }
        else args[tmp[0]] = tmp[1]
    }
    const route = req.method + leftpath
    const { ip, username } = getIpUser(req)
    logNotice({ip,username,route,args})
    switch (route) {
      case 'GET/search':
        res.end('FOUND!\n')
        break;
      case 'POST/errors':
        let errors = [];
        req.on('data', (chunk) => {
          errors.push(chunk);
        }).on('end', () => {
          errors = Buffer.concat(errors).toString();
          logWarning({ip,username,errors})
        })
        res.end('thanks for errors')
        break;
      case 'PUT/files':
      case 'POST/files':
        if (req.headers['content-type'] && req.headers['content-type'].indexOf('multipart/form-data;')>-1) {
        try {
          let busboy = new Busboy({ preservePath: true, headers: req.headers })
          let files = []
          let fields = {}
          let uid = guid()
          busboy.on('error', function(error){
            let msg = error.message
            logWarning({ip,username,route,msg})
          })
          busboy.on('field', function(fieldname, val, fieldnameTruncated, valTruncated, encoding, mimetype) {
            fields['upload_'+fieldname] = val
          })
          busboy.on('file', async function(fieldname, file, filename, encoding, mimetype) {
            let chuncks = []
            let savePath = path.join(config.uploadDirectory,uid)
            let sDir = await ensureDirectory(savePath)
            if (sDir) {
              let fname = base64url(filename)
              logNotice({ip,username,filename,fname})
              let saveTo = path.join(savePath, fname);
              file.pipe(fs.createWriteStream(saveTo));
              file.on('data', function(data) {
                chuncks.push(data.length)
              });
              file.on('end', function() {
                files.push({uid,filename, fname, encoding, mimetype})
                logNotice({ip,username,filename,fname, saveTo})
              });
            }
          })
          busboy.on('finish', async function() {
            fields['upload_by'] = username
            fields['upload_time'] = now()
            let saveTo = path.join(config.uploadDirectory,uid)
            let fDir = await ensureDirectory(saveTo)
            if (fDir) {
              let fSave = await writeFile(path.join(saveTo,config.metaFilename),JSON.stringify(fields))
              if (!fSave) res.end('try again')
              else res.end('thanks for files')
            }
          });
          req.pipe(busboy);
        } catch (error){
          res.end('try again')
          let msg = error.message
          logWarning({ip,username,route,msg})

        }
      } else logWarning({ip,username,route,'msg':'not a multipart/form-data'})
        break;
      case 'GET/subscriptions':
        let subscriptions  = await readFile(path.join(config.subscriptionsDirectory,username,'subscriptions.json'))
        console.dir(subscriptions)
        if (subscriptions == false) res.end('')
        else res.end(subscriptions)
        break;
      case 'POST/subscriptions':
        if (req.headers['content-type'] && req.headers['content-type'].indexOf('multipart/form-data;')>-1) {
        let subsFields = {}
        try {
          let subsBusBoy = new Busboy({ preservePath: true, headers: req.headers })
          busboy.on('error', function(error){
            let msg = error.message
            logWarning({ip,username,route,msg})
          });
          subsBusBoy.on('field', function(fieldname, val, fieldnameTruncated, valTruncated, encoding, mimetype) {
            subsFields[fieldname] = val
          })
          subsBusBoy.on('finish', async function() {
            let uploadtime = now()
            let emails = '' // TODO
            let subsFile = false
            let subscriptionsDirectory = await ensureDirectory(path.join(config.subscriptionsDirectory,username))
            if (subscriptionsDirectory) {
              subsFile = await writeFile(path.join(config.subscriptionsDirectory,username,'subscriptions.json'),JSON.stringify({uploadtime,username,emails,subsFields}))
            }
            if (!subsFile) {
              res.end('try again')
              let msg = 'writing subscriptions failed'
              logError({ip,username,msg})
            } else res.end('thanks for subscriptions')
          })
          req.pipe(subsBusBoy);
        } catch (error){
          res.end('try again')
          let msg = error.message
          logWarning({ip,username,route,msg})

        }
        } else logWarning({ip,username,route,'msg':'not a multipart/form-data'})
        break;
      default:
        let msg = 'missing route'
        logWarning({ip,username,msg,route})
        res.statusCode = 418
        res.end('NOOP')
    }
  })

  process.on('SIGTERM', function () {
    server.close(function () {
      logNotice({'msg':'got SIGTERM'})
      process.exit(0);
    });
  })

  server.listen(config.portListen, config.ipListen);

}

main()
.then(console.log)
.catch(console.error)
