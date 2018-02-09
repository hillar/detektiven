const fs = require('fs')
const path = require('path')
const http = require('http');
const https = require('https');

function guid() {
  function s4() {
    return Math.floor((1 + Math.random()) * 0x10000)
      .toString(16)
      .substring(1);
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
  console.log(JSON.stringify({time, info}))
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

function getIpUser(req){
  let username = req.user || 'anonymous'
  let ip = req.socket.remoteAddress
  return {ip, username}
}

async function httpGet(url){
  return new Promise((resolve, reject) => {
    logInfo({'status':'started',url})
    try {
    (url.indexOf('https://')>-1 ? https : http).get(url, (resp) => {

      let data = '';
      resp.on('data', (chunk) => {
        data += chunk;
      });
      resp.on('end', () => {
        logInfo({'status':'end',url})
        resolve(data)
      });
    }).on("error", (error) => {
      logInfo({'status':'error',url})
      const func = 'httpGet'
      const msg = error.message
      //logWarning({func,url,msg})
      reject(error)
    });
  } catch (err) {
    logError({err})
    reject(error)
  }
  })
}
function createSearchPromise(server,args){
  return new Promise((resolve, reject) => {
    //{"HR":"hardCodedDefault","type":"solr","proto":"http","host":"localhost","port":8983,"collection":"default","rotationperiod":"none"}
    if (!server.type) reject(new Error('no server type'))
    //TODO check proto host port
    let query = server.proto+'://'+server.host+':'+server.port
    switch (server.type) {
      case 'solr':
        query += '/solr/'+server.collection+'/select?'
        if (!args.wt) args.wt = 'json'
        query += 'wt='+args.wt+'&q=' + args.q + '&'
        if (args.q.op && args.q.op === 'AND') query += 'q.op=AND&'
        query += 'rows='+args.rows+'&start='+args.start+'&'
        query += 'fl='+args.fl+'&'
        if (args.hl) {
           for (let hl in args.hl) {
             query += 'hl.'+hl+'='+args.hl[hl]+'&'
           }
        }
        httpGet(query)
        .then(function(res){
          let result = res
          resolve({server,result})
        })
        .catch(function(error){
          resolve({server,error})
        })
        break
      case 'elastic':
      case 'elasticsearch':

        if (!args.hl) {
          // http://nocf-www.elastic.co/guide/en/elasticsearch/reference/current/search-uri-request.html
          query += '/'+server.collection+'/_search?track_scores&lenient&q=' + args.q + '&'
          query += 'size='+args.rows+'&from='+args.start+'&'
          //_source_include
          //sort=_score
          httpGet(query)
          .then(function(res){
            let result = res
            resolve({server,result})
          })
          .catch(function(error){
            resolve({server,error})
          })
        } else {
          //TODO https://www.elastic.co/guide/en/elasticsearch/reference/current/search-request-highlighting.html
          resolve({server})
        }
        break
      default:
        logError({'msg':'not supported ' + server.type,server})
        resolve({server})
    }
    //reject('error in createSearchPromise')
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
  createSearchPromise: createSearchPromise,
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
