const fs = require('fs')
const net = require('net')
const http = require('http')
const https = require('https')
const request = require('request')
const { logError, logWarning, logInfo } = require('./log.js')

module.exports = {
  pingServer,
  httpGet,
  httpPost
}

function checkHostPortConnection(host, port, timeout) {
    return new Promise(function(resolve, reject) {
        timeout = timeout || 1000
        var timer = setTimeout(function() {
            socket.end()
            reject(new Error('timeout '+timeout))
        }, timeout)
        var socket = net.createConnection(port, host, function() {
            clearTimeout(timer)
            socket.end()
            resolve(true)
        })
        socket.on('error', function(err) {
            clearTimeout(timer)
            reject (err)
        })
    })
}

async function pingServer(service,host,port){
  return new Promise(function(resolve, reject) {
    checkHostPortConnection(host,port)
    .then(function(){
      logInfo({'ping':'OK',service,host,port})
      resolve(true)
    })
    .catch(function(err){
      let error = err.message
      logInfo({'ping':'FAILED',service,host,port,error})
      resolve(false)
    })
  })
}

async function httpGet(proto, host, port, path, body){
  return new Promise((resolve, reject) => {
    if (!host) reject(new Error('httpGet no host'))
    if (!port) reject(new Error('httpGet no port'))
    if (!path) reject(new Error('httpGet no path'))
    const start = Date.now()
    process.env.NODE_TLS_REJECT_UNAUTHORIZED = "0";
    logInfo({'httpGet':'start',proto, host, port, path, body})
    try {
      const contentlength = ( (body) ? Buffer.byteLength(body) : 0 )
      const options = {
        hostname: host,
        port: port,
        path: path,
        method: 'GET',
        headers: {
          'content-type' : 'application/json; charset=UTF-8',
          'content-length' : contentlength
        }
      };
      const req = (proto === 'https' ? https : http).request(options, (res) => {
        res.setEncoding('utf8');
        let data = '';
        res.on('data', (chunk) => {
          data += chunk;
        });
        res.on('end', () => {
          logInfo({'httpGet':'end', 'took':Date.now() - start, proto, host, port, path, body})
          resolve(data)
        });
        res.on('error', (error) => {
          logWarning({'httpGet':'res error', error})
          reject(error)
        })
      });
      req.on('error', (error) => {
        reject(error)
      });
      if (body) req.write(body);
      req.end();
    } catch (error) {
      logError({'httpGet':'try error', error})
      reject(error)
    }
  })
}

async function httpPost(proto, host, port, path,filename,fields){
  return new Promise((resolve, reject) => {
    if (!host) reject(new Error('httpPost no host'))
    if (!port) reject(new Error('httpPost no port'))
    if (!path) reject(new Error('httpPost no path'))
    if (!filename) reject(new Error('httpPost no filename'))
    const start = Date.now()
    process.env.NODE_TLS_REJECT_UNAUTHORIZED = "0";
    let formData = {file: fs.createReadStream(filename)}
    if (fields) for (const field of Object.keys(fields).sort()){
      if (fields[field]) formData[field] = fields[field]
    }
    const url = `${(proto === 'https' ? 'https' : 'http')}://${host}:${port}/${path}`
    logInfo({'httpPost':'start',proto, host, port, path, filename,url})
    try {
      request.post({url:url, formData: formData}, function cb(err, httpResponse, body) {
        if (err) {
          logWarning({'httpPost':'request error', error:err.message})
          reject(err);
        }
        resolve(body)
      });
    } catch (error) {
      logWarning({'httpPost':'try error', error})
      reject(error)
    }
  })
}
