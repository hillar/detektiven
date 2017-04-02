(function (window) {

'use strict';

var VERSION = "0.0.0";

var pending = null; // pending promise

const socket = new WebSocket('ws://localhost:3000');

function getNonce(l) {
  if (l === undefined) {
    l = 24;
  }
  var val = "";
  var hex = "abcdefghijklmnopqrstuvwxyz0123456789ABCDEFGHIJKLMNOPQRSTUVXYZ";
  for (var i = 0; i < l; i++) val += hex.charAt(Math.floor(Math.random() * hex.length));
  return val;
}

// Resolve or reject the promise
 function processMessage(m) {
   var reply = m.data;
   if (reply.id) {
     if (pending.id == reply.id) {
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
    console.log("chat SEND: " + JSON.stringify(msg));
      // send message to WebSocket
      var s = socket.send(msg);
      // and store promise callbacks
    pending = {
      resolve: resolve,
      reject: reject,
      id: msg["id"]
    };
  });
}

var chat = function () {

  console.log("dummy chat " +  VERSION);
  socket.addEventListener('message', processMessage);
  var fields = {} ;

  fields.getVersion = function () {
      return msg2promise({
        "type": "VERSION",
      }).then(function (r) {
        return r.version;
      });
  };

  fields.getNonce = function (certificate) {
    return msg2promise({
      "type": "certificate",
      "certificate": certificate,
    }).then(function (r) {
      return r.nonce;
    });
  };

  return fields;

}

window.chat = chat();

})(typeof window === 'object' ? window : this);
