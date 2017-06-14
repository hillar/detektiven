'use strict'

const wsocket = require('ws')
const crypto = require('crypto')
const fs = require('fs')
const jwt = require('jsonwebtoken')

console.log('Server started')

var wss = new wsocket.Server({port: 3000})

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
      const sha = crypto.createHash('sha1').update(JSON.stringify(message.token)).digest('hex')
      jwt.verify(message.token, cert(message.token), {ignoreExpiration: true, nonce: nonce}, (err, decoded) => {
        if (err) {
          ws.send('No, no, no ...')
          ws.terminate()
          console.log('Did not verify', err)
        } else {
          fs.writeFileSync('./like.' + sha, JSON.stringify(message.token))
          ws.send('We like you too, ' + decoded.sub)
          console.log('Verified', decoded.sub)
        }
      })
    }
  })
})
