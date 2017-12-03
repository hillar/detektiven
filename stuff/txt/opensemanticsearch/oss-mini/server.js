const http = require('http')
const httpProxy = require('http-proxy')

let portTarget = 8983
let portListen = 9983
let ipListen = '192.168.11.2'
var proxy = httpProxy.createProxyServer({});

proxy.on('proxyReq', function(proxyReq, req, res, options) {
  //console.dir(req.connection.remoteAddress)
  console.log(Date.now(),req.socket.remoteAddress,req.url,JSON.stringify(req.headers))
});

let server = http.createServer(function(req, res) {
  proxy.web(req, res, {
      target: `http://127.0.0.1:${portTarget}`
  });
});

try {
    server.listen(portListen, ipListen);
    console.log(`listening on port ${portListen} target ${portTarget}`)
} catch (e) {
  console.error(e)
}

