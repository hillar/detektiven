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

//TODO better ip test
function isIPv4(string) {
    return !!/^(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$/.test(string);
}

function isCUID(string) {
  return !!/^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$/.test(string);
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
  var bites = httpobj.url.split('/');
  if (bites.length !== 4) {
    console.dir(bites);
    ws.close();
  }
  var remote_addr = bites[3];
  if (!isIPv4(remote_addr)){
    console.dir(bites);
    ws.close();
  }
  var urlCUID = bites[2];
  if (!isCUID(urlCUID)) {
    console.dir(bites);
    ws.close()
  }

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
      // check the token
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
            ws.send(JSON.stringify({welcome:'welcome '+decoded.sub}))
            //ws.broadcast(decoded.sub joined)
            console.log('Verified', decoded.sub)
            ws.onmessage = function onmessage(message) {
              try {
                var clientmessage = JSON.parse(message.data.trim());
              } catch (e) {
                console.dir(e);
                ws.close();
              }
              console.dir(clientmessage);
              if (!clientmessage.cuid) { // first thing after welcome must be cuid
                ws.send(JSON.stringify({bye:'good bye '+decoded.sub}))
                ws.close();
              } else {
                // finally we age good to do chat, add client to clients set
                var client = {};
                client.ws = ws;
                client.sub = decoded.sub;
                client.cuid = clientmessage.cuid;
                clients.add(client);
                client.onclose = function close(c) {
                  console.log('client closed');
                  console.dir(c);
                  clients.delete(client);
                }
                ws.onmessage = function onmessage(message) {
                  try {
                    var clientmessage = JSON.parse(message.data.trim());
                  } catch (e) {
                    console.dir(e);
                    ws.close();
                  }
                  console.dir(clientmessage);
                  ws.send(JSON.stringify(clientmessage));
                }
              }
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
