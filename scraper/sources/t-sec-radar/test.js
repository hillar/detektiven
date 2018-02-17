// TODO move helper funcs to separate module

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

const http = require('http')
const https = require('https')
async function get(proto, host, port, path, body, contenttype, method,insecure){
  return new Promise((resolve, reject) => {
    if (!host) reject(new Error('get no host'))
    if (!path) reject(new Error('get no path'))
    const start = Date.now()
    if (!port) port = (proto === 'https' ? 443 : 80)
    if (!contenttype) contenttype = 'application/json; charset=UTF-8'
    if (insecure) process.env.NODE_TLS_REJECT_UNAUTHORIZED = "0";
    if (!method) method = 'GET'
    logInfo({'get':'start',proto, host, port, path})
    try {
      const contentlength = ( (body) ? Buffer.byteLength(body) : 0 )
      const options = {
        hostname: host,
        port: port,
        path: path,
        method: method,
        headers: {
          'content-type' : contenttype,
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
          logInfo({'get':'end', 'took':Date.now() - start, proto, host, port, path})
          resolve(data)
        });
        res.on('error', (error) => {
          logError({'get':'res error', error})
          reject(error)
        })
      });
      req.on('error', (error) => {
        logError({'get':'req error', error})
        reject(error)
      });
      if (body) req.write(body);
      req.end();
    } catch (error) {
      logError({'get':'try error', error})
      reject(error)
    }
  })
}


// ------------------


async function main() {
  const USERNAME = 'blabla'
  const TOKEN = 'blabla'
  const PROTO = 'https'
  const HOST = 'www.t-sec-radar.de'
  const PATH = '/alert/retrieveIPs?out=json'
  const CONTENTTYPE = 'text/xml;charset=UTF-8'
  const METHOD = 'POST'

  // authentication_required xml post data
  // see https://github.com/dtag-dev-sec/PEBA/blob/master/peba.py#L49
  // sample https://github.com/dtag-dev-sec/PEBA/blob/master/misc/get-requests/request.xml
  const authData = `<EWS-SimpleMessage version="2.0">
      <Authentication>
          <username>${USERNAME}</username>
          <token>${TOKEN}</token>
      </Authentication>
  </EWS-SimpleMessage>`
  let response = await get(PROTO,HOST,null,PATH,authData,CONTENTTYPE,METHOD)
  console.dir(response)
  return 'done'
}

main()
.then(console.log)
.catch(console.error)
