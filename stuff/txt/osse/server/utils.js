const fs = require('fs')
const path = require('path')
const net = require('net')
const http = require('http')
const https = require('https')
const nodemailer = require('nodemailer')

function guid() {
  function s4() {
    return Math.floor((1 + Math.random()) * 0x10000).toString(16).substring(1);
  }
  return s4() + s4() + '-' + s4() + '-' + s4() + '-' + s4() + '-' + s4() + s4() + s4();
}

function now(){
  const now = new Date()
  return now.toJSON()
}

function logError(error){
  const time = now()
  console.error(JSON.stringify({time, error}))
}

function logInfo(info){
  const time = now()
  if (process.stdout.isTTY) console.log(JSON.stringify({time, info}))
}

function logNotice(notice){
  const time = now()
  console.log(JSON.stringify({time, notice}))
}

function logWarning(warning){
  const time = now()
  console.log(JSON.stringify({time, warning}))
}

async function ensureDirectory(directory){
  return new Promise((resolve, reject) => {
    const func = 'ensureDirectory'
    const testFile = path.join(directory,'test_______.txt')
    if (!fs.existsSync(directory)) {
      try {
        fs.mkdirSync(directory)
        fs.writeFileSync(testFile,'test123456')
        fs.unlinkSync(testFile)
        resolve(true)
      } catch (error) {
        const msg = error.message
        logError({func,directory,msg})
        resolve(false)
      }
    } else {
      try {
        fs.writeFileSync(testFile,'test123456')
        fs.unlinkSync(testFile)
        resolve(true)
      } catch (error) {
        const msg = error.message
        logError({func,directory,msg})
        resolve(false)
      }
    }
  })
}

async function readFile(filename){
  return new Promise((resolve, reject) => {
    try {
      let data = fs.readFileSync(filename)
      resolve(data)
    } catch (error) {
      const func = 'readFile'
      const msg = error.message
      logWarning({func,filename,msg})
      resolve(false)
    }
  })
}
async function writeFile(filename,data){
  return new Promise((resolve, reject) => {
    try {
      fs.writeFileSync(filename,data)
      resolve(true)
    } catch (error) {
      const func = 'writeFile'
      const msg = error.message
      logError({func,filename,msg})
      resolve(false)
    }
  })
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

function getIpUser(req){
  let username = req.user || 'anonymous'
  let ip = req.socket.remoteAddress
  return {ip, username}
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

function sendMail(to, subject, body, from, host, port) {
  return new Promise((resolve, reject) => {
    const func = 'sendMail'
    const transport = nodemailer.createTransport({host:host, port:port,tls: {rejectUnauthorized: false}})
    transport.sendMail({from:from, to:to, subject:subject, text:body },(err, info) => {
        if (err) {
          const error = err.message
          logWarning({func,'status':'mail not sent',error})
          resolve(false)
        } else {
          logInfo({func,'status':'mail sent',info})
          resolve(true)
        }
      })
  })
}

module.exports = {
  guid: guid,
  now: now,
  logNotice: logNotice,
  logWarning: logWarning,
  logError: logError,
  readFile: readFile,
  writeFile: writeFile,
  ensureDirectory: ensureDirectory,
  pingServer: pingServer,
  sendMail, sendMail,
  httpGet: httpGet,
  getIpUser: getIpUser,
  readJSON: async function(filename){
    let data = await readFile(filename)
    if (data === false) {
        return false
    } else {
        try {
          let json = JSON.parse(data)
          return json
        } catch (error) {
          const func = 'readJSON'
          const msg = error.message
          logError({func,filename,msg})
          return false
        }
    }
  }
}
