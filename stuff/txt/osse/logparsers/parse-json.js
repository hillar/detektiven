const cliParams = require('commander')
const fs = require('fs')
const zlib = require('zlib')
const lzma = require('lzma-native')
const crypto = require('crypto')
const byline = require('byline')
const http = require('http')
const { Writable } = require('stream');

cliParams
  .version('0.0.1')
  .usage('[options]')
  .option('--file <path>','file to parse')
  .option('--host [name]','solr host','localhost')
  .option('--port [number]','solr port',8983)
  .option('--core [name]','solr core','solrdefalutcore')
  .parse(process.argv);
if (typeof cliParams.file === 'undefined') {
   console.error('no file  given!');
   process.exit(1);
}

let config = {}
config.file = cliParams.file
config.host = cliParams.host
config.port = cliParams.port
config.core = cliParams.core

async function post(postdata) {
  const options = {
    hostname: config.host,
    port: config.port,
    path: `/solr/${config.core}/update?commitWithin=10000&wt=json`,
    headers: {
      'Content-Type': 'application/json',
      'Content-Length': Buffer.byteLength(postdata)
    },
    method: 'POST'
  }
  return new Promise((resolve, reject) => {
    const req = http.request(options, (res) => {
      res.setEncoding('utf8');
      let data = '';
  	  const { statusCode, statusMessage, headers } = res
      if (statusCode !== 200) { console.error(statusMessage, options); process.exit(1) }
      res.on('data', (chunk) => {
            data += chunk
      })
      res.on('end', () => { resolve(data) })
      res.on('error', (e) => { console.error(e); process.exit(1)} )
    })
    req.write(postdata)
    req.end()
  })
}

const fileMD5 = path => new Promise((resolve, reject) => {
	const hash = crypto.createHash('md5')
	const rs = fs.createReadStream(path)
	rs.on('error', reject)
	rs.on('data', chunk => hash.update(chunk))
	rs.on('end', () => resolve(hash.digest('hex')))
})

fileMD5(config.file).then(filehash => {
  spool=[]
  counter=0
  output = new Writable();
  output._write = async (c,e,n) => {
    let line = c.toString()
    let l = {}

    let id = crypto.createHash('md5').update(line).digest("hex");
    try {
        l = Object.assign({},JSON.parse(line.substring(line.search("{"),line.search("}")+1)));
    } catch (e) {

    }
    spool.push(Object.assign(l,{md5:filehash,id:counter,_id_:id,logline:line}))
    counter++
    if (spool.length > 2047) {
      await post(JSON.stringify(spool))
      spool = []
    }
    n()
  }
  output._final = async (n) => {
    await post(JSON.stringify(spool))
    console.log(filehash,counter)
    n()
  }

  const input = fs.createReadStream(config.file)
  const gzip = zlib.createGunzip()
  const bl = byline.createStream()
  const xzout = fs.createWriteStream(`${config.file}.xz`)
  gzip.pipe(bl).pipe(output)
  gzip.pipe(lzma.createCompressor({preset:9})).pipe(xzout)
  input.pipe(gzip)

}).catch(err => {
  console.error(err)
  process.exit(1)
})
