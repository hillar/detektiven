
const crypto = require('crypto')
const fs = require('fs')
const jwt = require('jsonwebtoken')
const x509 = require('x509')



// reconstruct message
var message = JSON.parse(JSON.stringify({token:fs.readFileSync('like.ed790fb5b3ca65e92ea6bfced9ba534f02583255','utf8').replace(/\"/g,'')}));
//console.dir(message)

function cert (token) {
  const parsed = jwt.decode(token, {complete: true, json: true})
  if (parsed && parsed.header.x5c) { return '-----BEGIN CERTIFICATE-----\n' + parsed.header.x5c[0] + '\n-----END CERTIFICATE-----' } else { return '' }
}


// load issuers and subjects
var issuers = JSON.parse(fs.readFileSync('./issuer.commonNames','utf8'));
var subjects = JSON.parse(fs.readFileSync('./subject.serialNumbers','utf8'));
//console.dir(issuers);
//console.dir(subjects);


var pubcrt = cert(message.token);
var crt = x509.parseCert(pubcrt);
var issuerOK = issuers.names.includes(crt.issuer.commonName);
//console.dir(crt.subject.commonName);
var subjectOK = subjects.serials.includes(crt.subject.serialNumber);
if ( issuerOK && subjectOK ) {
jwt.verify(message.token, pubcrt, {ignoreExpiration: true }, (err, decoded) => {
  console.dir(decoded);
  console.dir(crt.subject.commonName === decoded.sub);
})
} else {
  console.log('no no');
}
