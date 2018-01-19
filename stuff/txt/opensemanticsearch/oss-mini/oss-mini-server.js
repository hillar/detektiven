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
  .option('--upload-directory [path]','upload path')
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
let uploadDirectory = cliParams.uploadDirectory || config.uploadDirectory
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
//TODO check is uploadDirectory writeable, if not exit

// authentication
let users = {} //TODO load users history
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
      //TODO send email to user
      //mailer.send(to, subject, body, smtpfrom, smtphost, smtpport)
    }
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
        mailer.send('kala@kala.na', 'subject', 'body', smtpfrom, smtphost, smtpport)
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
    let fields = []
    let uid = guid()
    busboy.on('file', function(fieldname, file, filename, encoding, mimetype) {
      let chuncks = []
      console.log('File [' + fieldname + ']: filename: ' + filename + ', encoding: ' + encoding + ', mimetype: ' + mimetype);
      let savePath = uploadDirectory+'/'+uid
      //TODO
      fs.mkdirSync(savePath)
      let saveTo = path.join(savePath, path.basename(filename));
      file.pipe(fs.createWriteStream(saveTo));
      file.on('data', function(data) {
        chuncks.push(data.length)
        //console.log('File [' + filename + '] got ' + data.length + ' bytes');
      });
      file.on('end', function() {
        files.push({uid,fieldname, filename, encoding, mimetype})
        console.log('File [' + filename + '] saved to',saveTo,'got chuncks',JSON.stringify(chuncks));
        // calc md5, check for previos ...
      });
    });
    busboy.on('field', function(fieldname, val, fieldnameTruncated, valTruncated, encoding, mimetype) {
      fields.push({fieldname,val})
      //console.log('Field [' + fieldname + ']: value: ' + val);
    });
    busboy.on('finish', function() {
      //console.log('Done parsing form!');
      //res.writeHead(303, { Connection: 'close', Location: '/' });
      console.log('fields:',JSON.stringify(fields))
      console.log('files:',JSON.stringify(files))
      let uploadedby = req.user
      let uploadtime = Date.now()
      fs.writeFileSync(uploadDirectory+'/'+uid+'/meta.json',JSON.stringify({uploadtime,uploadedby,fields,files}))
      res.end('OK');
    });

    req.pipe(busboy);
  }
}
})

try {
    server.listen(portListen, ipListen);
    console.log(`listening on port ${portListen} target ${portTarget}`)
} catch (e) {
  console.error(e)
}
