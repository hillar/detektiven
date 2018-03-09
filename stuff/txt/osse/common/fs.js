const fs = require('fs')
const path = require('path')
const readChunk = require('read-chunk')
const fileType = require('file-type')
const { logError, logWarning } = require('./log.js')

module.exports = {
  ensureDirectory,
  readFile,
  writeFile,
  isFile,
  getMime,
  readJSON
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

async function readJSON(filename){
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

function isFile(filename){
  try {
   fs.accessSync(filename, fs.constants.R_OK)
  } catch (err) {
   return false
  }
  return true
}

function getMime(filename){
  try {
   let t = fileType(readChunk.sync(filename, 0, 4100))
   if (t) {
    return t.mime
   } else {
    return 'application/octet-stream'
   }
  } catch (err) {
   return false
  }
}
