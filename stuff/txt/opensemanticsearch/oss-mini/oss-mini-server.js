#!/usr/bin/env node

const http = require('http')
const httpProxy = require('http-proxy')
const auth = require('http-auth')
const Busboy = require('busboy')
const url = require('url')
const os = require('os')
const fs = require('fs')
const path = require('path')
const mailer = require('./mailer')
const cliParams = require('commander');
const freeipa = require('./freeipa');

//TODO move hlpers to separate file
// helpers
function guid() {
  function s4() {
    return Math.floor((1 + Math.random()) * 0x10000)
      .toString(16)
      .substring(1);
  }
  return s4() + s4() + '-' + s4() + '-' + s4() + '-' + s4() + '-' + s4() + s4() + s4();
}

// TODO add sane hardcoded defaults
// like os.tmpdir()+'/oss-mini'

cliParams
  .version('0.0.1')
  .usage('[options]')
  .option('-c, --config [file]', 'config file','./config.json')
	.option('-p, --port [number]','port to listen')
	.option('-h, --host [number]','host to listen')
	.option('-s, --static [path]','static files to serve')
  .option('-t, --target [host:port]','api target host and port')
	.option('-a, --api [path]','api path')
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
try {
	var config = require(cliParams.config)
} catch (e) {
	console.error('can not load config from',cliParams.config)
	process.exit(1);
}

// override config with cmd params
let portListen = cliParams.port || config.port
let ipListen = cliParams.host || config.host
let staticDir = cliParams.static || config.static
let portTarget = cliParams.target || config.target
let apiUrl = cliParams.api || config.api
let usersFile = cliParams.usersFile || config.usersFile
let uploadDirectory = cliParams.uploadDirectory || config.uploadDirectory
let subscriptionsDirectory = cliParams.subscriptionsDirectory || config.subscriptionsDirectory
let smtpfrom = cliParams.smtpSender || config.smtpSender
let smtphost = cliParams.smtpHost || config.smtpHost
let smtpport = cliParams.smtpPort || config.smtpPort
let IPASERVER = cliParams.ipaServer || config.ipaServer
let BASE = cliParams.ipaBase || config.ipaBase
let bindpass = cliParams.ipaPass || config.ipaPass
let binduser = cliParams.ipaUser || config.ipaUser
let groupName = cliParams.ipaGroup || config.ipaGroup
let realm = config.realm || 'oss-mini'
let reauth = config.reauth || 1000 * 60
let metaFilename = config.metaFilename || '/meta.json'

//done with config
console.log('starting with:',ipListen,portListen,staticDir,portTarget,apiUrl,uploadDirectory,smtphost,smtpport,smtpfrom)

if (!fs.existsSync(uploadDirectory)) {
  try {
    console.log('creating directory for uploads',uploadDirectory)
    fs.mkdirSync(uploadDirectory)
  } catch (e) {
    console.error('can not create upload directory', uploadDirectory)
    process.exit(1);
  }
}
if (!fs.existsSync(subscriptionsDirectory)) {
  try {
    console.log('creating directory for uploads',subscriptionsDirectory)
    fs.mkdirSync(subscriptionsDirectory)
  } catch (e) {
    console.error('can not create upload directory', subscriptionsDirectory)
    process.exit(1);
  }
}
//TODO check is uploadDirectory && subscriptionsDirectory writeable, if not exit

// authentication
let users = {}
try {
  users = fs.readFileSync(usersFile)
} catch (error) {
  console.log('fresh start !?, no users sessions history file',usersFile)
}
let basic = auth.basic({
		realm: realm
	}, async (username, password, callback) => {
		// do not reauth in X milliseconds
		if (users[username] && users[username]['lastseen'] && (Date.now() - users[username]['lastseen'] < reauth)){
			 callback(true)
		} else {
			console.log('notice start auth for',username)
			process.env.NODE_TLS_REJECT_UNAUTHORIZED = "0";
			//TODO get employeeNumber from header
			let employeeNumber = 'uid='+username
			try {
	    	let user = await freeipa.getUser(IPASERVER, BASE, binduser, bindpass, employeeNumber,password,groupName);
				if (username == user.uid) {
					if (!users[username]) {
						users[username] = {}
						console.log('notice user first time login', username)
					}
					users[username]['ipa'] = user
					users[username]['logintime'] = Date.now()
          let to = ''
          if (Array.isArray(users[username].ipa.mail)) to = users[username].ipa.mail.join(';')
          else to = users[username].ipa.mail
          let subject = "welcome"
          let body = "nice to see You!"
          mailer.send(to, subject, body, smtpfrom, smtphost, smtpport)
					callback(true);
				} else {
					console.error('should not happen, user',username,' does not match system user',user.uid)
					callback(false);
				}
			} catch (error) {
				console.error('auth error for',username,error)
				callback(false)
			}
		}
	}
);
basic.on('success', (result, req) => {
  if (!users[result.user]){
    users[result.user] = {logintime:Date.now(), lastseen:Date.now(), ip: req.socket.remoteAddress}
  } else {
    users[result.user]['lastseen'] = Date.now()
    if (users[result.user]['ip'] && req.socket.remoteAddress != users[result.user]['ip']) {
      console.log('WARNING! user', req.user, 'has new ip',req.socket.remoteAddress,'old',users[req.user]['ip'])
      let to = users[result.user].ipa.mail.join(';')
      let subject = "new ip"
      let body = "new login from "+ req.socket.remoteAddress
      mailer.send(to, subject, body, smtpfrom, smtphost, smtpport)
    }
  }
  try {
    fs.writeFileSync(usersFile,JSON.stringify(users))
  } catch (error) {
    console.error('failed writing users sessions file',usersFile,error.message)
  }
  let user_online = users[result.user]['lastseen'] - users[result.user]['logintime']
	console.log(`User ${result.user} authenticated since ${users[result.user]['logintime']} online time ${user_online}`);
});
basic.on('fail', (result, req) => {
  delete users[result.user]
	console.log(`User authentication failed: ${req.socket.remoteAddress}`);
});
basic.on('error', (error, req) => {
	console.log(`Authentication error: ${error.code + " - " + error.message}`);
});

// api is prxy for solr
let proxy = httpProxy.createProxyServer({changeOrigin:true,target: `http://${portTarget}`});
proxy.on('proxyReq', function(proxyReq, req, res, options) {
  //console.log('proxy',Date.now(),req.socket.remoteAddress,req.user,req.url,JSON.stringify(req.headers['user-agent']))
});
proxy.on('proxyRes', function (proxyRes, req, res) {
	if (proxyRes.statusCode != 200) {
		// TODO find where headers are sent before this and set content to undefined
		proxyRes.statusCode = 418
		console.error('proxy',proxyRes.statusMessage,req.socket.remoteAddress,req.user,req.url)
    //hack solr is sending answer but status is not 200 ;(
    if (req.url == '/solr/core1/select?q=*:*&wt=csv&rows=0&facet') proxyRes.statusCode = 200
	}
});
proxy.on('error', function (err, req, res) {
  console.error('proxy ERROR',Date.now(),err)
  res.writeHead(418, {
    'Content-Type': 'text/plain'
  });
  res.end('Something went wrong 162');
});

// server
let server = http.createServer(basic, (req, res) => {
  if (req.method === 'GET'){

  // api queries proxied to target
  if (req.url.startsWith(apiUrl)) {
		console.log('proxy',Date.now(),req.socket.remoteAddress,req.user,req.url,JSON.stringify(req.headers['user-agent']))

    if (users[req.user]['fp']) {
      proxy.web(req, res);
    } else {
			console.error('notice user do not have fingerprint',req.user,req.socket.remoteAddress)
		}
  } else {
    console.log('query',Date.now(),req.socket.remoteAddress,req.user,req.url,JSON.stringify(req.headers))
    // get to / with params .. obscurity
    if (req.url.startsWith("/?")) {
        const parsedUrl = url.parse(req.url)
        let bits = parsedUrl.query.split('&')
        let params = []
        for ( let bit of bits ) {
          [key,value] = bit.split('=')
          params.push(key)
          if (key == 'fp' || key == 'pk') {
              if (users[req.user][key]) {
                if (users[req.user][key] != value) {
                  console.log('WARNING! user', req.user, 'has new',key,value,'old',users[req.user][key])
                  //TODO send email to user
                }
              } else {
                users[req.user][key] = value
            }
          }
        }
        res.end()
        console.log('got user',req.user,'new params',params.join(','),'all',JSON.stringify(users[req.user]))
        let to = users[req.user].ipa.mail.join(';')
        let subject = "new browser"
        let body = "new browser from "+ req.socket.remoteAddress
        mailer.send(to, subject, body, smtpfrom, smtphost, smtpport)
        try {
          fs.writeFileSync(usersFile,JSON.stringify(users))
        } catch (error) {
          console.error('failed writing users sessions file',usersFile,error.message)
        }
    } else {
      if (req.url.startsWith("/subscriptions")){
        let uploadedby = req.user
        let subs = ""
        try {
          subs = fs.readFileSync(subscriptionsDirectory+'/'+uploadedby+'/subscriptions.json')
        } catch (e) {
          console.log('no sobscritions for ',uploadedby)
        }
        console.log('sendings subscriptions to',uploadedby)
        res.end(subs)

      } else {
      // static files
      if (req.url.startsWith("/")) {
        const parsedUrl = url.parse(req.url)
        let pathname = `${staticDir}${parsedUrl.pathname}`;
        console.log('static:',pathname,';')
        const mimeType = {
                        '.ico': 'image/x-icon',
                        '.html': 'text/html',
                        '.js': 'text/javascript',
                        '.json': 'application/json',
                        '.css': 'text/css',
                        '.png': 'image/png'}
        fs.exists(pathname, function (exist) {
          if(!exist) {
						console.error('file not exists',Date.now(),req.socket.remoteAddress,req.user,req.url)
            res.statusCode = 418
            res.end(`something went wrong 219`)
            return
          }
          if (fs.statSync(pathname).isDirectory()) {
            res.writeHead(302, {
                  "Location": `${parsedUrl.pathname}index.html`
            })
            res.end()
            return
          }
          // read file from file system
          fs.readFile(pathname, function(err, data){
            if(err){
							console.error('error reading file',pathname,Date.now(),req.socket.remoteAddress,req.user,req.url)
              res.statusCode = 500
              res.end('Something went wrong 234')
            } else {
              const ext = path.parse(pathname).ext
              res.setHeader('Content-type', mimeType[ext] || 'text/plain' )
              res.end(data)
            }
          })
        })
      } else {

					console.error('should never happen!',Date.now(),req.socket.remoteAddress,req.user,req.url)
          res.writeHead(302, {
                "Location": "/index.html"
          });
          res.end();
      }
    } // end subsc
    }
  }
} else {
  if (req.method === 'PUT') {
    //try {
      let busboy = new Busboy({ preservePath: true, headers: req.headers })
    /*} catch (error) {
      console.error('PUT', error);
      return
    }*/
    let files = []
    let fields = {}
    let uid = guid()
    busboy.on('file', function(fieldname, file, filename, encoding, mimetype) {
      let chuncks = []
      //console.log('File [' + fieldname + ']: filename: ' + filename + ', encoding: ' + encoding + ', mimetype: ' + mimetype);
      let savePath = uploadDirectory+'/'+uid
      //TODO
      fs.mkdirSync(savePath)
      let fname = Buffer.from(filename).toString('base64')
      console.log('saving',filename,'as',fname)
      let saveTo = path.join(savePath, fname);
      file.pipe(fs.createWriteStream(saveTo));
      file.on('data', function(data) {
        chuncks.push(data.length)
        //console.log('File [' + filename + '] got ' + data.length + ' bytes');
      });
      file.on('end', function() {
        files.push({uid,filename, encoding, mimetype})
        console.log('File [' + filename + '] saved to',saveTo,'got chuncks',JSON.stringify(chuncks.length));
        // calc md5, check for previos ...
      });
    });
    busboy.on('field', function(fieldname, val, fieldnameTruncated, valTruncated, encoding, mimetype) {
      //fields.push({fieldname,val})
      fields['upload_'+fieldname] = val
      //console.log('Field [' + fieldname + ']: value: ' + val);
    });
    busboy.on('finish', function() {
      //console.log('Done parsing form!');
      //res.writeHead(303, { Connection: 'close', Location: '/' });
      //console.log('fields:',JSON.stringify(fields))
      //console.log('files:',JSON.stringify(files))
      fields['upload_by'] = req.user
      fields['upload_time'] = Date.now()
      fs.writeFileSync(uploadDirectory+'/'+uid+metaFilename,JSON.stringify(fields))
      res.end('OK');
    });
    req.pipe(busboy);
  }
  if (req.method === 'POST') {
      if (req.url.startsWith("/errors")){
        let errors = [];
        request.on('data', (chunk) => {
          errors.push(chunk);
        }).on('end', () => {
          errors = Buffer.concat(errors).toString();
          console.log('browser side errors from ',req.user,errors)
        });
      }
      if (req.url.startsWith("/subscriptions")){
        let fields = {}
        let busboy = new Busboy({ preservePath: true, headers: req.headers })
        busboy.on('field', function(fieldname, val, fieldnameTruncated, valTruncated, encoding, mimetype) {
          fields[fieldname] = val
          //fields.push(o)
        });
        busboy.on('finish', function() {
          console.log('fields:',JSON.stringify(fields))
          let subscribedby = req.user
          let emails = users[subscribedby].ipa.mail
          let uploadtime = Date.now()
          // let email = user.email
          if (!fs.existsSync(subscriptionsDirectory+'/'+subscribedby)) {
            try {
              console.log('creating subscriptions directory for',subscribedby,subscriptionsDirectory+'/'+subscribedby)
              fs.mkdirSync(subscriptionsDirectory+'/'+subscribedby)
            } catch (e) {
              console.error('can not create subscriptions directory', subscriptionsDirectory+'/'+subscribedby)
              res.end('FAILED');
              return
            }
          }
          // TODO keep old subscriptions history
          let saved = "OK"
          try {
              console.log('writing subscriptions', subscribedby,'to',subscriptionsDirectory+'/'+subscribedby+'/subscriptions.json')
              fs.writeFileSync(subscriptionsDirectory+'/'+subscribedby+'/subscriptions.json',JSON.stringify({uploadtime,subscribedby,emails,fields}))
          } catch (error) {
            saved = "Can not write subscriptions"
            console.error(error.message)
          }
        res.end(saved);
        console.log(JSON.stringify({uploadtime,subscribedby,emails,fields}))
        });
        req.pipe(busboy);
      }
  }
}
})

try {
    server.listen(portListen, ipListen);
    console.log(`listening on port ${portListen} target ${portTarget}`)
} catch (e) {
  console.error(e)
}
