// this is just brute force experiment
// do not use it
// there are better ways to skin a cat

const http = require('http');
const { StringDecoder } = require('string_decoder');
const decoder = new StringDecoder('ascii');
const jwt = require('jsonwebtoken');
const fs = require('fs');
const crypto = require('crypto');
const base64url = require('base64url');

const UPLOADDIR = '/tmp/uploads'


function parseReqUrl(requrl){
  // req.url  /api/v0/fli/csv?feed=webiron&time=1502259611&webiron
  if (! requrl) return {}
  var bites = requrl.split('?');
  var meta = {}
  meta['url'] = bites[0]; // url or ?
  meta['params'] = {} ;
  var urlparams = bites.length > 1 ? bites[1] : '';
  var params = urlparams.split('&');
  params.forEach(function(param){
      var kv = param.split('=');
      if (kv[0].length > 0) meta.params[kv[0]] = kv[1] || true;
  });
  return meta
}

function parseAuthorization(authorization){
  if (! authorization) return {}
  //  authorization header 'Bearer eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiJ9.eyJub25jZSI6Im5vbmNlIiwiaXNzIjoia2tAa2siLCJhdWQiOiJodHRwOi8vbG9jYWxob3N0OjMwMDAvYXBpIiwic3ViIjoiLi9wdXNobmV3cy5iYXNoIiwiZXhwIjoxNTAyMjYxNTAyLCJpYXQiOjE1MDIyNjE0MDJ9.Sq7x-0wG9B4HzojEV0ua8DhmPZX33ke-wedKQ8splIft0KWG7pgTmtKkxTTrCJCeQU_lfS95fI9BeNBtFp38rqfQvLM-XgZ5ZRgYmlMdcjgpS2aoMi-_z3NDdW9SSykY1EOwY3Nnjn0Gplcbk0j05bvO1cEyhvO1LWZVXiS1v-s'
  var bites = authorization.split(' ');
  var ret = {}
  if (bites[0] === 'Bearer'){
    if (bites[1] && bites[1].length > 7){
      var decoded = jwt.decode(bites[1], {complete: true});
      if (decoded && decoded.header && decoded.header.typ && decoded.header.typ === 'JWT' && decoded.header.alg && decoded.header.alg === 'RS256'){
        if (decoded.payload && decoded.payload.nonce && decoded.payload.iss && decoded.payload.iat && decoded.payload.exp  && decoded.payload.sub && decoded.payload.aud){
            ret['JWT'] = decoded;
        } else {
          ret['warning'] = 'not JWT payload';
        }
      } else {
        ret['warning'] = 'not JWT header';
      }
    } else {
      ret['warning'] = 'not JWT';
    }
  } else {
    ret['warning'] = 'no Bearer';
  }
  return ret;
}


async function getPublicKeyFromDB(nonce,db){
  return new Promise(function (resolve, reject) {
    if (nonce && db) {
      var pkf = db+'/'+nonce+'/publickey.pem'
      try {
        fs.readFile(pkf, 'utf8', (err,data) => {
          if (err) reject(err);
          resolve(data);
        });
      } catch (err) {
          reject(err);
      }
    } else {
      reject(new Error('no public key'));
    }
  });
}

async function storePublicKeyToDB(db,nonce,pubkey,email, meta){
  return new Promise(function (resolve, reject) {
    if (nonce && pubkey && email && meta) {
      try {
        var dir = db+'/'+nonce;
        var pkf = dir+'/publickey.pem'
        var ef = dir+'/email.txt'
        var mf = dir+'/meta.json'
        fs.mkdirSync(dir);
        fs.writeFile(pkf, pubkey, (err) => {
          if (err) reject(err);
          fs.writeFile(ef, email, (err) => {
            if (err) reject(err);
            fs.writeFile(mf, JSON.stringify(meta), (err) => {
              if (err) reject(err);
              resolve(true);
            });
          });
        });
      } catch (err) {
        reject(err)
      }
    } else {
      reject(new Error('missing param'));
    }
  });
}

function guid() {
  function s4() {
    return Math.floor((1 + Math.random()) * 0x10000)
      .toString(16)
      .substring(1);
  }
  return s4() + s4() + '-' + s4() + '-' + s4() + '-' +
    s4() + '-' + s4() + s4() + s4();
}

async function register(params,auth,key,res){
  return new Promise(async function (resolve, reject) {
    if (! (auth && auth.ip && params && params.email && params.email.length>5 && key && key.length > 271)) {
      reject( new Error('register param missing'));
    }
    var nonce = guid();
    try {
      var encryptedAndBase64UrlEncodedNonce = base64url(crypto.publicEncrypt({ key: key, padding: crypto.constants.RSA_PKCS1_PADDING},Buffer.from(nonce)));
    } catch (err){
      console.error(err);
      reject( new Error('bad key'));
    }
    /*
    TODO
    test ip is 'abusing'
    test is email
    test is domain & ban sender with 3+ last same
    test MX & host
    test email not pwnd curl -v -D kala https://haveibeenpwned.com/api/v2/breachedaccount/oskar@kala.ee
    test email exist on mx
    */
    try {
      var ok = await storePublicKeyToDB(UPLOADDIR,nonce,key,params.email,params);
      if (ok) {
        res.end(encryptedAndBase64UrlEncodedNonce);
        console.log("sent nonce",encryptedAndBase64UrlEncodedNonce,params.email,auth.ip);
      }
      resolve(true);
    } catch (err) {
      reject(err);
    }
  });
}

async function dummy(a,u,b,res) {
  return new Promise(async function (resolve, reject) {
  console.dir(a);
  console.dir(u);
  console.dir(b);
  res.end('Accepted \n');
  if (a && u && b) {
    resolve(true)
  } else {
    reject(new Error('dummy missing param'))
  }
});
}



var routes = {
                  '/api/v0/register': {
                      'POST': register
                  },
                  '/api/v0/fli/csv': {
                      'POST': dummy
                  },
                  '/api/v0/blih/blah': {
                      'POST': dummy,
                      'GET': dummy,
                      'PUT': dummy
                  }
              }

server = http.createServer( function(req, res) {
    var remoteAddress = req.headers['x-forwarded-for'] || req.connection.remoteAddress;
    var userAgent = req.headers['user-agent'] || '';
    var authorization = req.headers['authorization'] || '';
    console.log('Request started', remoteAddress, req.method, req.url, userAgent);
    var url = parseReqUrl(req.url);
    if ( ! (routes[url.url] && routes[url.url][req.method] && routes[url.url][req.method] instanceof Function)){
        console.error('not implemented',remoteAddress,req.method,req.url,userAgent);
        res.writeHead(501);
        res.end('Not Implemented');
        return
    }
    var body = '';
    var total = 0;
    /*
    TODO 429
    The 429 status code indicates that the user has sent too many
    requests in a given amount of time ("rate limiting").
    res.writeHead( 429 Too Many Requests)
    Retry-After: 3600
    */

    req.on('data', function (data) {
        total += data.length;
        if (total > 268393408)  {
          console.error('Request Entity Too Large',remoteAddress,req.method,req.url,userAgent,total);
          res.writeHead(413);
          res.end('Request Entity Too Large');
          req.destroy();
        } else {
          body += decoder.write(data);
        }
    });

    req.on('end', async function () {
        body += decoder.end();
        res.writeHead(202);
        console.log('Request Accepted',remoteAddress,req.method,req.url,userAgent,total);
        var warnings = [];
        if (! Object.keys(url.params).length > 0) {
          var msg = 'no metadata';
          warnings.push(msg);
          res.writeHead(299,msg);
        }
        try {
          var auth = parseAuthorization(authorization);
          if (auth.warning) {
            warnings.push(auth.warnings);
            res.writeHead(299,auth.warnings);
          }
          if (auth.JWT && auth.JWT.payload && auth.JWT.payload.nonce ){
            var pubkey = await getPublicKeyFromDB(auth.JWT.payload.nonce,UPLOADDIR);
            if (pubkey) {
                var verified = jwt.verify(authorization.split(' ')[1],pubkey);
                if (verified && verified.nonce && verified.nonce === auth.JWT.payload.nonce ){
                  auth['verified'] = true;
                }
            }
          }
          auth['ip'] =  remoteAddress;
          auth['ua'] = userAgent;
          // process body now
          var ok = await routes[url.url][req.method](url.params, auth, body,res);
          if (!ok && !res.finished) res.end('Accepted, however...');
        } catch (err) {
            console.error(err);
            if (! res.finished) {
              res.writeHead(500);
              res.end('something went wrong ;(');
            }
        }
    });
});

port = 3000;
host = '127.0.0.1';
server.listen(port, host);
console.log('server started ' + host + ':' + port);
