(function (exports) {
'use strict';

//import webeid from './vendor/web-eid/web-eid.js';
//TODO configure rollup so, that import works

//import chat from './chat.js'

function hello(logo, html) {
    html.style.filter = "blur(1px)";
    logo.className = "pulse";
    var message = document.createElement("p");
    message.className = "message-text";
    html.appendChild(message);
    webeid.hasExtension().then(function(d) {
        message.innerHTML = "Getting Web-eid version, please wait ...";
        webeid.getVersion().then(function(v) {
            // TODO check version
            message.innerHTML = "Getting certificate, please wait ...";
            webeid.getCertificate().then(function(certificate) {
                logo.className = "";
                html.style.filter = "";
                // TODO get name from certificate
                var name = certificate.substr(0, 14);
                message.innerHTML = "Getting nonce from server. Please wait ...";
                chat.getNonce(certificate).then(function(nonce){
                      message.innerHTML = "Hello <b>" + name + "</b>!<br>Please click on <i>authenticate</i> button to get TOKEN!";
                      var authButton = document.createElement("button");
                      authButton.className = "btn";
                      authButton.innerHTML = "Authenticate";
                      authButton.onclick = function() {
                              html.style.filter = "blur(1px)";
                              logo.className = "pulse";
                              message.innerHTML = "Getting token, please wait ...";
                              authButton.innerHTML = "";
                              webeid.auth(nonce).then(function(token) {
                                  var pem = JSON.parse(atob(token.split(".")[0]))["x5c"][0];
                                  //debug += "<br>Authenticaton: <a href=\"https://jwt.io/#debugger?&id_token=" + token + "&public-key=" + encodeURIComponent(pem) + "\">JWT token</a> is <br><pre>" + token + "</pre>";
                                  logo.className = "";
                                  html.style.filter = "";
                                  authButton.onclick = function() {
                                          message.innerHTML = "Connecting to server. Please wait ...";
                                          authButton.innerHTML = "";
                                          alert('ping');
                                  }; // connect button
                                  message.innerHTML = "Token ready!<br>Please click <i>connect</> to start connection with server as <b>" + name + "</b>";
                                  authButton.innerHTML = "Connect";
                              }).catch(function(f) { // auth
                                  message.innerHTML = "Failed to authenticate: " + JSON.stringify(f.message);
                                  logo.className = "";
                                  html.style.filter = "";
                              });
                      }; // auth button
                      html.appendChild(authButton);
                }).catch(function(e){ // getNonce
                      message.innerHTML = "Get Nonce failed " + e;
                });
            }).catch(function(e) { // getCertificate
                message.innerHTML = "No card in reader !?" + e;
                logo.className = "spin";
                logo.style.filter = "blur(1px)";
                // TODO check again OR listen to connect ?
                // https://github.com/web-eid/web-eid.js#webeidconnect
            });
        }).catch(function(e) { // getVersion
            logo.className = "";
            logo.style.filter = "invert() blur(3px)";
            message.innerHTML = 'Can not get Web-eid version' + e;
        });
    }).catch(function(e) { // hasExtension
        logo.className = "";
        logo.style.filter = "invert() blur(1px)";
        message.innerHTML = 'No web-eid. <br> Please go to <a href="https://web-eid.com/" target="_bank">web-eid.com</a>';
    });
}

exports.hello = hello;

}((this.main = this.main || {})));
