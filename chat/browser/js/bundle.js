(function (exports) {
'use strict';

//import webeid from './vendor/web-eid/web-eid.js';
//TODO configure rollup so, that import works


function parseMessage(message){
  try {
    var r = JSON.parse(message);
    console.log(r);
    return r;
  } catch (e) {
    return {error:e}
  }
}


const autoReconnectInterval = 1000 * 3;
const autoReconnectMaxCount = 3;
let autoReconnectCounter = 0;

var authenticatedWebSocket = function (url) {
  return new Promise(function (resolve, reject) {
    var socket = new WebSocket(url)
    socket.onclose = function (c){
      if (c.code !== 1000) { // server sent unclean close, we try to reconnect
        if (autoReconnectCounter < autoReconnectMaxCount ) {
        autoReconnectCounter += 1;
        console.log('reconnect '+ url + ' in ' + autoReconnectInterval + ' count ' + autoReconnectCounter)
        setTimeout(function(){
            console.log("reconnecting...");
            authenticatedWebSocket(url)
              .then(function (ws) {resolve(ws);})
              .catch(function(e) {reject(e)});
        },autoReconnectInterval);
      } else {
        console.log("reached autoReconnectMaxCount "+autoReconnectMaxCount);
        reject(new Error('server has disappeared'));
      }
    } else { // server sent clean close
        console.dir(c);
        reject(new Error('server closed connection'));
      }
    }
    socket.onmessage = function (m) {
      try {
        var msg = JSON.parse(m.data);
      } catch(e) {
        console.log('Server did not send JSON');
        reject(new Error('please contact your sysadmin!'));
      }
      if (!msg.nonce){
        console.log('Server did not send nonce');
        reject(new Error('please contact your sysadmin!'));
      } else {
        webeid.authenticate(msg.nonce).then(function (token) {
          socket.send(JSON.stringify({token: token}));
          console.log('sent token to server');
          socket.onmessage = function (m){ //if server answers, then we are ok
            console.dir(m);
            socket.onclose = undefined;
            socket.onmessage = undefined;
            resolve(socket);
          }
        }, function (reason) { // TODO handle reasons
          socket.send(JSON.stringify({user : reason.message}));
          socket.close();
          reject(new Error(reason.message));
          /*
          if (reason.message == 'CKR_FUNCTION_CANCELED'){
            reject(new Error('user cancel'));
          } else {
            // !? try again ...
          }
          */
        });
      } // !msg.nonce
    } //onmessage

  });
}

// -----

function hello(logo, html) {
  const wsPING_INTERVAL = 30000;
  function msg(m){
    var div = document.createElement("div");
    var content = document.createTextNode(m);
    div.appendChild(content);
    html.appendChild(div);
    //return div;
  }
  function btn(m,f){
    var theButton = document.createElement("button");
    theButton.innerHTML = m;
    theButton.onclick = f;
    theButton.className = "btn";
    return theButton;
  }
  function input(m,f){
    var div = document.createElement("div");
    var bt = btn("<div style='transform: rotate(45deg);'>&#9906;</div>",f)
    div.appendChild(bt);
    bt.insertAdjacentHTML('beforebegin','<input "type=text" name="q" className="message-text">');
    return div;
  }

    msg('looking for web-eid, please wait ...')
    webeid.isAvailable({timeout:6}).then(function(d) {

      let signin = btn('auth',function click () {
        msg('asking nonce from server, please wait ...')
        const url = window.location.href.replace('https','wss').slice(0, -1)+':443/chat';
        authenticatedWebSocket(url).then(function (ws) {
          console.dir(ws);
          msg('auth ok');
          let qchat = input('q',function click () {
            ws.send(JSON.stringify({raw:this.parentElement.childNodes[0].value}));
            this.parentElement.childNodes[0].value = "";
          });
          html.appendChild(qchat);
          window.setInterval(function ping() {
            console.log('ping '+Date.now());
            ws.send(JSON.stringify({ping:Date.now()}));
          }, wsPING_INTERVAL);
          ws.onclose = function onclose(c){
            console.dir(c);
            msg('server closed');
          }
          ws.onmessage = function onmessage(m) {
            console.dir(m);
            msg(m.data);
          }
        }).catch(function(e) {
          console.dir(e);
          msg('no server, redirecting...');
          setTimeout(function(){
              console.log("rediderct to interpol");
              window.location.href = "https://www.interpol.int/Crime-areas/Cybercrime/Cybercrime"
          },5000);
        }); //authenticatedWebSocket
        html.removeChild(signin);

      });
      html.appendChild(signin);
    }).catch(function(e) { // hasExtension
        console.dir(e);
        msg('no web-eid, redirecting...');
        setTimeout(function(){
            console.log("rediderct to web-eid.com");
            window.location.href = "https://web-eid.com/"
        },5000);
    }); // isAvailable
}

exports.hello = hello;

}((this.main = this.main || {})));
