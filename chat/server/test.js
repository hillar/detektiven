'use strict'
const cliParams = require('commander');
const wsocket = require('ws')
const crypto = require('crypto')
const fs = require('fs')
const jwt = require('jsonwebtoken')
const x509 = require('x509')
const http = require('http');

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

function abortConnection (socket, code, message) {
  if (socket.writable) {
    message = message || http.STATUS_CODES[code];
    socket.write(
      `HTTP/1.1 ${code} ${http.STATUS_CODES[code]}\r\n` +
      'Connection: close\r\n' +
      'Content-type: text/html\r\n' +
      `Content-Length: ${Buffer.byteLength(message)}\r\n` +
      '\r\n' +
      message
    );
  }

  socket.removeListener('error', socketError);
  socket._socket.destroy();
}
function socketError () {
  this.destroy();
}

// main
cliParams
  .version('0.0.1')
  .usage('[options] <file ...>')
  .option('-i, --issuers [file]', 'issuers list','./issuer.commonNames')
  .option('-s, --subjects [file]','subjects list','./subject.serialNumbers')
  .option('-p, --port [number]','port to listen',3000)
  .parse(process.argv);

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
var wss = new wsocket.Server({port: cliParams.port, clientTracking: false})
//console.dir(wss);
var clients = new Set();

function broadcast(msg,type){
  var type = type || 'broadcast';
  for (const client of clients) clinet.ws.send(JSON.stringify({type:msg}));
}

// On every new connection
wss.on('connection', function (ws, httpobj) {
  //console.dir(httpobj.headers);
  console.dir(httpobj.url);
  // send a nonce , see https://github.com/martinpaljak/authenticated-websocket#sample-messages
  var nonce = getNonce();
  ws.send(JSON.stringify({nonce: nonce}));
  ws.onmessage = function onmessage(message) {
    //console.dir(message);
    try {
      var clientmessage = JSON.parse(message.data.trim());
    } catch (e) {
      console.dir(e);
      ws.close();
    }
    if (!clientmessage.token)  {
      ws.close();
    } else {
      // we good to check the token
      var pubcrt = cert(clientmessage.token);
      var crt = x509.parseCert(pubcrt);
      var issuerOK = issuers.names.includes(crt.issuer.commonName);
      var subjectOK = subjects.serials.includes(crt.subject.serialNumber);
      if ( issuerOK && subjectOK ) {
        jwt.verify(clientmessage.token, pubcrt, {ignoreExpiration: true, nonce: nonce}, (err, decoded) => {
          if (err) {
            ws.send(JSON.stringify({error:'did not verify'}));
            ws.close();
            console.log('Did not verify', err)
          } else {
            var client = {};
            client.ws = ws;
            client.sub = decoded.sub;
            clients.add(client);
            client.onclose = function close(c) {
              console.log('client closed');
              console.dir(c);
              clients.delete(client);
            }
            ws.send(JSON.stringify({welcome:'welcome '+decoded.sub}))
            //ws.broadcast(decoded.sub joined)
            console.log('Verified', decoded.sub)
            ws.onmessage = function onmessage(message) {
              console.dir(message.data);
            }
          }
        });
      } else {
        ws.send(JSON.stringify({error:'did not verify'}));
        ws.close();
        console.log('issuer:', issuerOK, 'subject:', subjectOK);
      }
    }
  }//fisrt message must be nonce
})
