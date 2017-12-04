const http = require('http')
const httpProxy = require('http-proxy')
const auth = require('http-auth')
const url = require('url');
const fs = require('fs');
const path = require('path');

let portTarget = 8983
let portListen = 9983
let ipListen = '192.168.11.2'
let staticDir = '../solr-buefy/test1/dist'
// authentication
let basic = auth.basic({
		realm: "oss-mini"
	}, (username, password, callback) => { 
		callback(username === "kala" && password === "maja");
	}
);
basic.on('success', (result, req) => {
	console.log(`User authenticated: ${result.user}`);
});

basic.on('fail', (result, req) => {
	console.log(`User authentication failed: ${result.user}`);
});

basic.on('error', (error, req) => {
	console.log(`Authentication error: ${error.code + " - " + error.message}`);
});

// api is prxy for solr
let proxy = httpProxy.createProxyServer({});
proxy.on('proxyReq', function(proxyReq, req, res, options) {
  console.log('proxy',Date.now(),req.socket.remoteAddress,req.user,req.url,JSON.stringify(req.headers))
});
proxy.on('error', function (err, req, res) {
  console.error('proxy ERROR',Date.now(),err)
  res.writeHead(500, {
    'Content-Type': 'text/plain'
  });
  res.end('Something went wrong.');
});


let server = http.createServer(basic, (req, res) => {
  if (req.url.startsWith("/solr/core")) {
    proxy.web(req, res, {
        target: `http://127.0.0.1:${portTarget}`
    });
  } else {
    console.log('query',Date.now(),req.socket.remoteAddress,req.user,req.url,JSON.stringify(req.headers))
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
            // based on the URL path, extract the file extention. e.g. .js, .doc, ...
            const ext = path.parse(pathname).ext
            // if the file is found, set Content-type and send data
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
})

try {
    server.listen(portListen, ipListen);
    console.log(`listening on port ${portListen} target ${portTarget}`)
} catch (e) {
  console.error(e)
}

