(function (exports) {
'use strict';

// https://github.com/web-eid/web-eid.js/blob/master/web-eid.js

  var VERSION = "0.0.2";
  // make a nonce
  function getNonce(l) {
    if (l === undefined) {
      l = 24;
    }
    var val = "";
    var hex = "abcdefghijklmnopqrstuvwxyz0123456789ABCDEFGHIJKLMNOPQRSTUVXYZ";
    for (var i = 0; i < l; i++) val += hex.charAt(Math.floor(Math.random() * hex.length));
    return val;
  }

  var pending = null; // pending promise

  // Resolve or reject the promise if extension and id match
  function processMessage(m) {
    var reply = m.data;
    if (reply.extension) {
      if (reply.id && pending.id == reply.id) {
        console.log("RECV: " + JSON.stringify(reply));
        if (reply.result == "ok" && !reply.error) {
          pending.resolve(reply);
        } else {
          pending.reject(new Error(reply.result));
        }
        pending = null;
      }
    }
  }

  // Send a message and return the promise.
  function msg2promise(msg) {
    if (pending != null) {
      return Promise.reject(new Error("operation_pending")); // TODO: define
    }
    return new Promise(function (resolve, reject) {
        // amend with necessary metadata
      msg["id"] = getNonce();
      msg["hwcrypto"] = true; // This will be removed by content script
      console.log("SEND: " + JSON.stringify(msg));
        // send message to content script
      window.postMessage(msg, "*");
        // and store promise callbacks
      pending = {
        resolve: resolve,
        reject: reject,
        id: msg["id"]
      };
    });
  }

  // construct
  var webeid = function () {
    console.log("Web eID JS shim v" + VERSION);
    // register incoming message handler
    window.addEventListener('message', processMessage);
    // Fields to be exported
    var fields = {};

    fields.hasExtension = function () {
      console.log("Testing for extension");
      var v = msg2promise({});
      var t = new Promise(function (resolve, reject) {
        setTimeout(reject, 700, 'timeout'); // TODO: make faster ?
      });
      return Promise.race([v, t]).then(function (r) {
        return r.extension;
      });
    };

    fields.getVersion = function () {
      return msg2promise({
        "type": "VERSION",
      }).then(function (r) {
        return r.version;
      });
    };

    fields.getCertificate = function () {
      // resolves to a certificate handle (in real life b64)
      return msg2promise({ "type": "CERT" }).then(function (r) {
        return r.cert;
      });
    };

    fields.sign = function (cert, hash) {
      return msg2promise({
        "type": "SIGN",
        "cert": cert,
        "hash": hash,
      }).then(function (r) {
        return r.signature;
      });
    };

    fields.auth = function (nonce) {
      return msg2promise({
        "type": "AUTH",
        "nonce": nonce,
      }).then(function (r) {
        return r.token;
      });
    };

    fields.VERSION = VERSION;
    fields.promisify = msg2promise;

    return fields;
  };

function hello() {
// make a nonce
// see https://github.com/web-eid/web-eid.com/blob/master/hello.js#L24
function getNonce(l,p) {
  p.className = "pulse";
  if (l === undefined) {
    l = 24;
  }
  var val = "";
  var hex = "abcdefghijklmnopqrstuvwxyz0123456789ABCDEFGHIJKLMNOPQRSTUVXYZ";
  for (var i = 0; i < l; i++) val += hex.charAt(Math.floor(Math.random() * hex.length));
  return val;
}

var auth = function(l,webeidLogo,p){
  webeidLogo.className = "pulse";
  webeid.auth(getNonce(l,webeidLogo)).then(function (d) {
    var token = d.token;
    p.innerHTML = d.token;
    //var pem = b2pem(JSON.parse(atob(token.split(".")[0]))["x5c"][0]);

  }).catch(function (f) {
    p.innerHTML = "Failed to authenticate: " + JSON.stringify(f.message);
    webeidLogo.className = "";
  });
};
document.body.style.filter = "blur(1px)";
var m = document.getElementById("main");
var p = document.createElement("p");
p.className = "lead-text";
m.appendChild(p);
webeid.hasExtension().then(function (d) {
  var webeidLogo = document.getElementById("webeid-logo");
  webeidLogo.className = "pulse";
  webeid.getVersion().then(function (v) {
    // TODO check version
    p.appendChild(document.createTextNode("Loading certificate from card, please wait ..."));
    webeid.getCertificate().then(function (certificate) {
      // TODO get name from certificate
      var name = certificate.substr(0,14);
      p.innerHTML = "Hello <b>" + name + "</b>!<br>Please click on <i>authenticate</i> button to log in!";
      var b = document.createElement("button");
      m.appendChild(b);
      b.className = "btn";
      b.innerHTML = "Authenticate";
      webeidLogo.className = "";
      document.body.style.filter = "";
      //b.onClick =  auth(24,webeidLogo,p);

    }).catch(function (e) {
      p.innerHTML = "No card in reader !?";
      webeidLogo.className = "";
      // TODO check again OR listen to connect ?
      // https://github.com/web-eid/web-eid.js#webeidconnect
    });
  }).catch(function (e) {
    p.appendChild(document.createTextNode("No webeid."));
  });
}).catch(function (e) {
    p.appendChild(document.createTextNode("No webeid."));
});
}

exports.hello = hello;

}((this.main = this.main || {})));
