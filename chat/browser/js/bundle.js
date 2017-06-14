(function (exports) {
'use strict';

//import webeid from './vendor/web-eid/web-eid.js';
//TODO configure rollup so, that import works


function hello(logo, html) {
    //html.style.filter = "blur(1px)";
    logo.className = "pulse";
    var message = document.createElement("p");
    message.className = "message-text";
    html.appendChild(message);
    webeid.isAvailable({timeout:2}).then(function(d) {
        message.innerHTML = "Getting Web-eid version, please wait ...";
        webeid.getVersion().then(function(v) {
            // TODO check version
            message.innerHTML = "Web-eid version:" +v ;

            webeid.getCertificate().then(function(certificate) {
                logo.className = "";
                html.style.filter = "";
                // TODO get name from certificate
                var name = 't3st1ng'//certificate
                message.innerHTML = "Hello <b>" + name + "</b>!<br>Please click on <i>authenticate</i> button to sign TOKEN!";
                var authButton = document.createElement("button");
                authButton.className = "btn";
                authButton.innerHTML = "Authenticate";
                authButton.onclick = function() {
                        html.style.filter = "blur(1px)";
                        logo.className = "pulse";
                        message.innerHTML = "Signing token ...";
                        authButton.innerHTML = "...";
                        webeid.authenticatedWebSocket('ws://localhost:3000/',{autoclose:true,timeout:1}).then(function(server){
                          message.innerHTML = "done" ;
                          server.onmessage = function (event) {
                                  logo.style.filter = "";
                                  logo.className = "spin";
                                  html.style.filter = "";
                                  message.innerHTML = event.data;
                          }
                          server.onclose = function (c){
                            logo.className = "";
                            logo.style.filter = "invert() blur(3px)";
                            message.innerHTML = 'server closed' + c.reason;
                          }
                          server.onerror = function (e){
                            logo.className = "";
                            logo.style.filter = "invert() blur(3px)";
                            message.innerHTML = 'server error' + e;

                          }

                        }).catch(function(e) { // authenticatedWebSocket
                            message.innerHTML = "authenticatedWebSocket failed" + e;
                            logo.className = "spin";
                            logo.style.filter = "blur(2px)";
                        });
                    }
                html.appendChild(authButton);
            }).catch(function(e) { // getCertificate
                message.innerHTML = "" + e;
                logo.className = "spin";
                logo.style.filter = "blur(2px)";
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
        message.innerHTML = 'No web-eid. <br> Please go to <a href="https://web-eid.com/" target="_blank">web-eid.com</a>';
    });
}

exports.hello = hello;

}((this.main = this.main || {})));
