(function (exports) {
'use strict';

//import webeid from './vendor/web-eid/web-eid.js';
//TODO configure rollup so, that import works

function guid() {
  function s4() {
    return Math.floor((1 + Math.random()) * 0x10000)
      .toString(16)
      .substring(1);
  }
  return s4() + s4() + '-' + s4() + '-' + s4() + '-' +
    s4() + '-' + s4() + s4() + s4();
}
function getGuid() {
  var cookiestring=RegExp("guid[^;]+").exec(document.cookie);
  return unescape(!!cookiestring ? cookiestring.toString().replace(/^[^=]+./,"") : "");
}

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
      // 1000	CLOSE_NORMAL
      // 1008	Policy Violation
      if (c.code !== 1000 && c.code !== 1008) { // server sent unclean close, we try to reconnect
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

// https://developer.mozilla.org/en-US/docs/Web/API/Document/cookie#Example_5_Do_something_only_once_–_a_general_library
function executeOnce () {
  var argc = arguments.length, bImplGlob = typeof arguments[argc - 1] === "string";
  if (bImplGlob) { argc++; }
  if (argc < 3) { throw new TypeError("executeOnce - not enough arguments"); }
  var fExec = arguments[0], sKey = arguments[argc - 2];
  if (typeof fExec !== "function") { throw new TypeError("executeOnce - first argument must be a function"); }
  if (!sKey || /^(?:expires|max\-age|path|domain|secure)$/i.test(sKey)) { throw new TypeError("executeOnce - invalid identifier"); }
  if (decodeURIComponent(document.cookie.replace(new RegExp("(?:(?:^|.*;)\\s*" + encodeURIComponent(sKey).replace(/[\-\.\+\*]/g, "\\$&") + "\\s*\\=\\s*([^;]*).*$)|^.*$"), "$1")) === "1") { return false; }
  fExec.apply(argc > 3 ? arguments[1] : null, argc > 4 ? Array.prototype.slice.call(arguments, 2, argc - 2) : []);
  document.cookie = encodeURIComponent(sKey) + "=1; expires=Fri, 31 Dec 9999 23:59:59 GMT" + (bImplGlob || !arguments[argc - 1] ? "; path=/" : "");
  return true;
}

function hello(logo, html) {

  function alertCookie (sMsg) {
    var expiration_date = new Date();
    var cookie_string = '';
    expiration_date.setFullYear(expiration_date.getFullYear() + 1);
    // Build the set-cookie string:
    var uuid = guid();
    cookie_string = "guid=" + uuid + "; path=/; expires=" + expiration_date.toUTCString();
    // Create or update the cookie:
    document.cookie = cookie_string;
    alert(sMsg);
  }

  executeOnce(alertCookie, null, "this site uses cookies", "executeOnce");
  const CUID = getGuid();


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
        const url = 'wss://'+window.location.host.replace(/:\d+/, '')+':443/chat/'+CUID;

        authenticatedWebSocket(url).then(function (ws) {
          console.dir(ws);
          msg('auth ok');
          ws.send(JSON.stringify({cuid:CUID}));
          let qchat = input('q',function click () {
            ws.send(JSON.stringify({raw:this.parentElement.childNodes[0].value}));
            this.parentElement.childNodes[0].value = "";
          });
          html.appendChild(qchat);
          const ping = window.setInterval(function ping() {
            console.log('ping '+Date.now());
            ws.send(JSON.stringify({ping:Date.now()}));
          }, wsPING_INTERVAL);
          ws.onclose = function onclose(c){
            console.dir(c);
            window.clearInterval(ping);
            html.removeChild(qchat);
            msg('server closed');
            html.appendChild(signin);

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
