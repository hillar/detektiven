'use strict'
const cliParams = require('commander');
const wsocket = require('ws')
const crypto = require('crypto')
const fs = require('fs')
const jwt = require('jsonwebtoken')
const x509 = require('x509')

// helper functions
// TODO move to separate fail

// pem'ify cert, so x509 and jwt like it more
function cert (token) {
  const parsed = jwt.decode(token, {complete: true, json: true})
  if (parsed && parsed.header.x5c) { return '-----BEGIN CERTIFICATE-----\n' + parsed.header.x5c[0] + '\n-----END CERTIFICATE-----' } else { return '' }
}
// make a nonce
function getNonce (l) {
  if (l === undefined) {
    l = 24
  }
  var val = ''
  var hex = 'abcdefghijklmnopqrstuvwxyz0123456789ABCDEFGHIJKLMNOPQRSTUVXYZ'
  for (var i = 0; i < l; i++) val += hex.charAt(Math.floor(Math.random() * hex.length))
  return val
}

// main
cliParams
  .version('0.0.1')
  .usage('[options] <file ...>')
  .option('-i, --issuers [file]', 'issuers list','./issuer.commonNames')
  .option('-s, --subjects [file]','subjects list','./subject.serialNumbers')
  .option('-p, --port [number]','port to listen',3000)
  .parse(process.argv);
//console.log(' args: %j', cliParams.args);
console.log('Starting server with:', cliParams.issuers, cliParams.subjects, cliParams.port);
// load issuers and subjects
try {
var issuers = JSON.parse(fs.readFileSync(cliParams.issuers,'utf8'));
} catch(e) {
  console.error('failed to load issuers',e);
  process.exit(1);
}
if (!issuers.names || issuers.names.length < 1) {
  console.error('no issuers');
  process.exit(1);
}
try {
  var subjects = JSON.parse(fs.readFileSync(cliParams.subjects,'utf8'));
} catch(e) {
  console.error('failed to load subjects',e);
  process.exit(1);
}
if (! subjects.serials || subjects.serials.length < 1) {
  console.error('no subjects');
  process.exit(1);
}
// create websocketserver
var wss = new wsocket.Server({port: cliParams.port})

// On every new connection
wss.on('connection', function (ws) {
  // send a nonce , see https://github.com/martinpaljak/authenticated-websocket#sample-messages
  var nonce = getNonce();
  ws.send(JSON.stringify({nonce: nonce}));

  ws.on('message', function (message) {
    try {
      var message = JSON.parse(message.trim());
    } catch (e) {
      ws.terminate();
    }
    if (!message.token)  {
      ws.terminate();
    } else {
      // we good to check the token
      //const sha = crypto.createHash('sha1').update(JSON.stringify(message.token)).digest('hex')
      var pubcrt = cert(message.token);
      var crt = x509.parseCert(pubcrt);
      var issuerOK = issuers.names.includes(crt.issuer.commonName);
      var subjectOK = subjects.serials.includes(crt.subject.serialNumber);
      if ( issuerOK && subjectOK ) {
        jwt.verify(message.token, pubcrt, {ignoreExpiration: true, nonce: nonce}, (err, decoded) => {
          if (err) {
            ws.send('No, no, no ...')
            ws.terminate()
            console.log('Did not verify', err)
          } else {
            //fs.writeFileSync('./like.' + sha, JSON.stringify(message.token))
            ws.send('We like you too, ' + decoded.sub)
            console.log('Verified', decoded.sub)
          }
        });
      } else {
        ws.terminate();
        console.log('issuer:', issuerOK, 'subject:', subjectOK);
      }
    }
  })
})
