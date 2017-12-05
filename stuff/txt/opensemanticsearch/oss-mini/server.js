const http = require('http')
const httpProxy = require('http-proxy')
const auth = require('http-auth')
const url = require('url');
const fs = require('fs');
const path = require('path');

let portTarget = 8983 // solr
let portListen = 9983
let ipListen = '192.168.11.2'
let staticDir = '../solr-buefy/test1/dist'

// authentication
let users = {}
let basic = auth.basic({
		realm: "oss-mini"
	}, (username, password, callback) => {
    //if (users[username]) return true
		callback(username === "kala" && password === "maja");
	}
);
basic.on('success', (result, req) => {
  if (!users[result.user]){
    users[result.user] = {logintime:Date.now(), lastseen:Date.now(), ip: req.socket.remoteAddress}
  } else {
    users[result.user]['lastseen'] = Date.now()
    if (req.socket.remoteAddress != users[result.user]['ip']) {
      console.log('WARNING! user', req.user, 'has new ip',req.socket.remoteAddress,'old',users[req.user]['ip'])
      //TODO send email to user
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
let proxy = httpProxy.createProxyServer({changeOrigin:true,target: `http://127.0.0.1:${portTarget}`});
proxy.on('proxyReq', function(proxyReq, req, res, options) {
  console.log('proxy',Date.now(),req.socket.remoteAddress,req.user,req.url,JSON.stringify(req.headers['user-agent']))
});
proxy.on('proxyRes', function (proxyRes, req, res) {
	if (proxyRes.statusCode != 200) {
		console.error('proxy',proxyRes.statusMessage,req.socket.remoteAddress,req.user,req.url)
	}
});
proxy.on('error', function (err, req, res) {
  console.error('proxy ERROR',Date.now(),err)
  res.writeHead(500, {
    'Content-Type': 'text/plain'
  });
  res.end('Something went wrong.');
});


// server
let server = http.createServer(basic, (req, res) => {
  // solr queries proxied
  if (req.url.startsWith("/solr/core")) {
    if (users[req.user]['fp']) {
      proxy.web(req, res);
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
            res.statusCode = 404
            res.end(`File ${pathname} not found!`)
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
              res.statusCode = 500
              res.end(`Error getting the file: ${err}.`)
            } else {
              const ext = path.parse(pathname).ext
              res.setHeader('Content-type', mimeType[ext] || 'text/plain' )
              res.end(data)
            }
          })
        })
      } else {
          res.writeHead(302, {
                "Location": "/index.html"
          });
          res.end();
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
