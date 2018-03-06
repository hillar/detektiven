const fs = require('fs')
const http = require('http');
const path = require('path');
const readChunk = require('read-chunk')
const fileType = require('file-type')
const cliParams = require('commander')

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

cliParams
  .version('0.0.1')
  .usage('[options]')
  .option('--port [number]','port to listen')
  .option('--ip [ip address]','ip to bind')
  .option('--root [path]','path to serve')
  .parse(process.argv);

let config = {}
config.portListen = cliParams.port || 8125
config.ipListen = cliParams.ip || '127.0.0.1'
config.pathRoot = cliParams.root || '/tmp/'

http.createServer(function (request, response) {
    let reqFile = decodeURIComponent(request.url)
    let filename = config.pathRoot + reqFile
    console.log('request ', reqFile);
    if (!isFile(filename)) {
       console.log('not in path',filename)
       response.writeHead(403)
       response.end()
    } else {
      let contentType = getMime(filename)
      if (contentType === false) {
        console.log('not readable')
        response.writeHead(404)
        response.end()
      } else {
        fs.readFile(filename, function(error, content) {
            if (error) {
                console.dir(error)
                response.writeHead(520)
                response.end()
            }
            else {
                response.writeHead(200, { 'Content-Type': contentType })
                response.write(content)
                response.end()
            }
        })
      }
    }
}).listen(config.portListen, config.ipListen)
console.log(config)
