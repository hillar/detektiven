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
const { guid, now, logNotice, logWarning, logError, ensureDirectory, readFile, writeFile, readJSON, pingServer,createSearchPromise, getIpUser } = require('./utils')

async function main() {
cliParams
  .version('0.0.1')
  .usage('[options]')
  .option('-c, --config [file]', 'config file','./config.json')
  .option('-g, --generate-config ', 'generate sample config file')
  .option('-t, --test','test connections')
  .option('--port [number]','port to listen')
  .option('--ip [ip address]','ip to bind')
  .option('--static [path]','static files to serve')
  .option('--users-file [file]','users sessions full path file name')
  .option('--upload-directory [path]','upload path')
  .option('--subscriptions-directory [path]','subscriptions path')
  .option('--smtp-host [host]','smtp host')
  .option('--smtp-port [number]','smtp port')
  .option('--smtp-sender [email]','smtp sender')
  .option('--ipa-server [host]','freeipa server (or any other ldap)')
  .option('--ipa-base [string]','ldap base')
  .option('--ipa-binduser [string]','ldap bind user')
  .option('--ipa-bindpass [string]','ldap bind password')
  .option('--ipa-usergroup [string]','user group')
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
  config.staticDirectory = cliParams.static || config.staticDirectory || '/tmp/osse/dist'
  config.smtpfrom = cliParams.smtpSender || configFile.smtpSender || 'noreply-osse@localhost'
  config.smtphost = cliParams.smtpHost || configFile.smtpHost || '127.0.0.1'
  config.smtpport = cliParams.smtpPort || configFile.smtpPort || 25
  config.ipaServer = cliParams.ipaServer || configFile.ipaServer || '127.0.0.1'
  config.ipaBase = cliParams.ipaBase || configFile.ipaBase || 'cn=accounts,dc=example,dc=org'
  config.ipaBindpass = cliParams.ipaBindpass || configFile.ipaBindpass || 'password'
  config.ipaBinduser = cliParams.ipaBinduser || configFile.ipaBinduser || 'username'
  config.ipaUsergroup = cliParams.ipaUsergroup || configFile.ipaUsergroup || 'osse'
  config.realm = configFile.realm || 'osse'
  config.reauth = configFile.reauth || 1000 * 60
  config.metaFilename = configFile.metaFilename || 'meta.json'
  config.subscriptionsFilename = configFile.subscriptionsFilename || 'subscriptions.json'
  config.servers = configFile.servers || [{"HR":"hardCodedDefault","type":"solr","proto":"http","host":"localhost","port":8983,"collection":"default","rotationperiod":"none"},{"HR":"hardCodedDefaultElastic","type":"elastic","proto":"http","host":"localhost","port":9200,"collection":"osse","rotationperiod":"yearly"}]
  // generate sample configFile
  if (cliParams.generateConfig) {
    console.log(JSON.stringify(config, null, 2))
    process.exit(0);
  }
  //start with notice
  if (process.stdout.isTTY) console.log(JSON.stringify({'msg':'starting',config}, null, 4))
  else   logNotice({'msg':'starting',config})
  // test paths
  let usersFileDir = await ensureDirectory(path.dirname(config.usersFile))
  if (!usersFileDir) process.exit(1)
  let uploadDirectory = await ensureDirectory(config.uploadDirectory)
  if (!uploadDirectory) process.exit(1)
  let subscriptionsDirectory = await ensureDirectory(config.subscriptionsDirectory)
  if (!subscriptionsDirectory) process.exit(1)

  // test connection to ipa and servers
  if (cliParams.test) {
    await pingServer('ipa',config.ipaServer,389)
    await pingServer('smtp',config.smtphost,config.smtpport)
    for (let i in config.servers){
      let server = config.servers[i]
      await pingServer(server.HR,server.host,server.port)
    }
    process.exit(0);
  }

  let users = await readJSON(config.usersFile)
  if (users === false ) {
    users = {}
    if (process.stdout.isTTY) console.log('fresh start !?, no users sessions history file',config.usersFile)
  }

  let server = http.createServer( async (req, res) => {
    let bittes = req.url.split('?')
    let urlPath = bittes[0]
    let leftpath = '/'+bittes[0].split('/')[1] || '/'
    bittes.shift()
    let params = bittes.join('?').trim().split('&').filter(String)
    args = {}
    for (let i in params){
        let tmp = params[i].split('=')
        if (!tmp[1]) { tmp[1] = true }
        // handle sort
        // see https://lucene.apache.org/solr/guide/6_6/common-query-parameters.html#CommonQueryParameters-ThesortParameter
        if (tmp[0] === 'sort') {
          // split fields and then order
        }
        // build 1 level nested struct
        // see https://lucene.apache.org/solr/guide/6_6/highlighting.html
        let nested = tmp[0].split('.')
        if (nested[1]) {
          if (!args[nested[0]]) args[nested[0]] = {}
          args[nested[0]][nested[1]]= tmp[1]
        }
        else args[tmp[0]] = tmp[1]
    }
    const route = req.method + leftpath
    const { ip, username } = getIpUser(req)
    logNotice({ip,username,route,urlPath,args})
    switch (route) {
      // ----------------------------------------------------------------
      case 'GET/search':
        const func = 'search'
        if (!args.q)  {
          logError({func,'msg':'no q in args'})
          res.end('')
          break
        }
        //TODO check max
        if (!args.rows) args.rows = 1024
        if (!args.start) args.start = 0
        if (!args.fl) args.fl = 'id'
        if (args.hl) {
          args.hl.encoder = 'html'
          if (!args.hl.snippets) args.hl.snippets = 8
          if (!args.hl.fragsize) args.hl.fragsize = 64
        }
        let httpgets = []
        for (let i in config.servers){
          let server = config.servers[i]
          httpgets.push(createSearchPromise(server,args))
        }
        Promise.all(httpgets).then(function(results){
          for (let i in results){
            let result = results[i]
            if (!result.server) throw new Error('no server')
            if (result.error) {
                let msg = result.error.message
                logWarning({func,msg,'server':result.server})
            } else {
                if (result.result) {
                  console.dir(result.result)
                }
            }
          }
          res.end('gut')
        })
        .catch(function(err) {
          let critical = 'This Should Never Happen :: ' + err.message
          logError({func,critical,err})
          res.end('')
        })
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
                let safename = base64url(filename)
                logNotice({ip,username,filename,safename})
                let saveTo = path.join(savePath, safename);
                file.pipe(fs.createWriteStream(saveTo));
                file.on('data', function(data) {
                  chuncks.push(data.length)
                });
                file.on('end', function() {
                  files.push({uid,filename, safename, encoding, mimetype})
                  logNotice({ip,username,filename,safename, saveTo})
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
        break
      case 'GET/static':
        let staticFilename = path.join(config.staticDirectory,urlPath)
        let staticFile = await readFile(staticFilename)
        if (staticFile === false){
          logError({ip,username,'msg':'file does not exist',staticFilename,urlPath})
          res.end()
        } else {
          const mimeType = {
                          '.ico': 'image/x-icon',
                          '.html': 'text/html',
                          '.js': 'text/javascript',
                          '.json': 'application/json',
                          '.css': 'text/css',
                          '.png': 'image/png'}
          const ext = path.parse(staticFilename).ext
          res.setHeader('Content-type', mimeType[ext] || 'text/plain' )
          res.end(staticFile)
        }
        break
      case 'GET/index.html':
        let indexFile = await readFile(path.join(config.staticDirectory,'index.html'))
        if (indexFile === false) {
          logError({'msg':'missing index.html'})
          res.end('')
        } else {
          res.setHeader('Content-type','text/plain')
          res.end(indexFile)
        }
        break
      case 'GET/':
          res.writeHead(301, {'Location' : '/index.html'});
          res.end();
          break
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
