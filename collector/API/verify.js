const fs = require('fs')
const jwt = require('jsonwebtoken');
const cliParams = require('commander');

cliParams
  .version('0.0.1')
  .option('-t, --token <file>', 'token')
  .option('-p, --publickey <file>', 'public key','./publickey.pem')
  .parse(process.argv);

var publickey = fs.readFileSync(cliParams.publickey);
var token = fs.readFileSync(cliParams.token).toString().replace(/[\n\r]/g, '');

jwt.verify(token, publickey, { algorithms: ['RS256']},function(err, decoded){
  if (err){
    console.error(err);
  } else {
    console.log("NODE Verified OK",JSON.stringify(decoded));
  }
});
