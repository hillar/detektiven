const fs = require('fs')
const http = require('http');
const path = require('path');
const crypto = require('crypto')
const cliParams = require('commander')
const Busboy = require('busboy')
const { nowAsJSON } = require('./common/time.js')
const { ensureDirectory, writeFile, isFile, getMime } = require('./common/fs.js')
const { logError, logWarning, logNotice, logCritical } = require('./common/log.js')
const { getIpUser } = require('./common/request.js')
const { guid } = require('./common/var.js')
//const { guid, now, logNotice, logWarning, logError, ensureDirectory, writeFile, getIpUser } = require('./common/utils')

async function  main() {

  cliParams
    .version('0.0.1')
    .usage('[options]')
    .option('--port [number]','port to listen')
    .option('--ip [ip address]','ip to bind')
    .option('--root [path]','path to serve')
    .option('--meta [filename]','meta file name')
    .parse(process.argv);

  let config = {}
  config.portListen = cliParams.port || 8125
  config.ipListen = cliParams.ip || '127.0.0.1'
  config.pathRoot = cliParams.root || '/tmp/'
  config.metaFilename = cliParams.meta || 'meta.json'

  if (isNaN(parseInt(config.portListen))) {
    logError({'port':'not a number'})
    process.exit(1)
  }
  let pathCheck = await ensureDirectory(config.pathRoot)
  if (pathCheck === false){
    logError({'path':'not writeable '+ config.pathRoot})
    process.exit(1);
  }
  
  var fileserver = http.createServer(function (request, response) {
      const { ip, username } = getIpUser(request)
      if (request.method === 'GET') {
        let reqFile = decodeURIComponent(request.url)
        let filename = config.pathRoot + reqFile
        logNotice({ip,username,get:{filename,url:request.url}})
        if (!isFile(filename)) {
           logWarning({ip,username,filenotexists:filename})
           response.writeHead(403)
           response.end()
        } else {
          let contentType = getMime(filename)
          if (contentType === false) {
            logerror({contentType:filename})
            response.writeHead(404)
            response.end()
          } else {
            fs.readFile(filename, function(error, content) {
                if (error) {
                    logerror({readFile:filename})
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
      } else {
        if (request.method === 'POST' || request.method === 'PUT') {
          if (request.headers['content-type'] && request.headers['content-type'].indexOf('multipart/form-data;') > -1 ) {
            try {
              let busboy = new Busboy({ preservePath: true, headers: request.headers })
              busboy.on('error', function(error){
                response.statusCode = 500
                response.write('busboy error: ',error.message)
                response.end()
                logWarning({'busboy':{error}})
              })
              busboy.on('finish', async function() {
                response.end()
              })
              let fields = {}
              busboy.on('field', function(fieldname, val, fieldnameTruncated, valTruncated, encoding, mimetype) {
                if (val) fields[fieldname] = val
              })
              busboy.on('file', async function(fieldname, file, filename, encoding, mimetype) {
                const uid = guid()
                const savePath = path.join(config.pathRoot,uid)
                const isDir = await ensureDirectory(savePath)
                if (isDir) {
                  const hash = crypto.createHash('md5');
                  const saveTo = path.join(savePath, filename);
                  file.pipe(fs.createWriteStream(saveTo));
                  file.on('data', function(data) {
                    hash.update(data)
                    //NOOP !?
                  })
                  file.on('end', async function() {
                    fields.saved_time_dt = nowAsJSON()
                    fields.saved_ip_s = ip
                    fields.saved_md5_s = hash.digest('hex')
                    if (username) fields.saved_user = username
                    logNotice({ip, username, saved:{to:saveTo,orig:filename,fields}})
                    metaSaved = await writeFile(path.join(savePath, config.metaFilename),JSON.stringify(fields))
                    if (metaSaved === false) logError({critical:'can not write to  ' + path.join(savePath, config.metaFilename) })
                  })
                } else {
                  logError({critical:'can not create ' + savePath})
                }
              })
              request.pipe(busboy);
            } catch (error) {
              console.dir(error)
              // busboy error
              response.statusCode = 500
              response.write('error: ' + error.message)
              response.end()
              logError({'500':error.message})
            }
          } else {
            // not multipart/form-data
            response.statusCode = 501
            response.write('Not implemented: '+ request.headers)
            response.end()
            logWarning({'501':{ip,username,headers:request.headers}})
          }
        } else {
          // not POST nor PUT
          response.statusCode = 503
          response.write('Unavailable: ' + request.method)
          response.end()
          logWarning({'503':{ip,username,headers:request.headers}})
        }
      }
  })

  fileserver.on('error', (error) => {
    logCritical({error:error.message})
    process.exit(1)
  })

  process.on('SIGTERM', function () {
    fileserver.close(function () {
      logNotice({'msg':'got SIGTERM'})
      process.exit(0);
    });
  })

  logNotice({'starting':config})
  fileserver.listen(config.portListen, config.ipListen)

}

process.on('uncaughtException', (error) => {
logError({'uncaughtException':`${error}`})
if (process.stdout.isTTY) console.log(error)
});

main()
.then(() => {})
.catch((error) => {
  console.error(error)
  logCritical(error)
})
