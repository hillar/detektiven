const fs = require('fs')
const jwt = require('jsonwebtoken');
const cliParams = require('commander');

cliParams
  .version('0.0.1')
  .option('-n, --nonce <string>', 'nonce')
  .option('-m, --mail <string>', 'email address')
  .option('-k, --key <file>', 'private key','./privatekey.pem')
  .option('-e, --exp [number]','seconds to expire',3600)
  .parse(process.argv);


var cert = fs.readFileSync(cliParams.key);
var iat = Math.floor(Date.now() / 1000);
var exp = iat + parseInt(cliParams.exp);
var claims = { nonce: cliParams.nonce,
               mail: cliParams.mail,
               iat: iat,
               exp: exp
              }
var token = jwt.sign(claims, cert, { algorithm: 'RS256'});
console.log(token)
