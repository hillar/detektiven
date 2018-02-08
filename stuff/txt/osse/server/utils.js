const fs = require('fs')
const path = require('path')

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

module.exports = {
  guid: guid,
  now: now,
  logNotice: logNotice,
  logWarning: logWarning,
  logError: logError,
  readFile: readFile,
  writeFile: writeFile,
  ensureDirectory: ensureDirectory,
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
