//import webeid from './vendor/web-eid/web-eid.js';
//TODO configure rollup so, that import works

export function hello(logo,html) {
  html.style.filter = "blur(1px)";
  logo.className = "pulse";
  var message = document.createElement("p");
  message.className = "message-text";
  html.appendChild(message);
  webeid.hasExtension().then(function (d) {
    message.innerHTML = "Getting Web-eid version, please wait ...";
    webeid.getVersion().then(function (v) {
      // TODO check version
      message.innerHTML = "Getting certificate, please wait ...";
      webeid.getCertificate().then(function (certificate) {
        // TODO get name from certificate
        var name = certificate.substr(0,14);
        message.innerHTML = "Hello <b>" + name + "</b>!<br>Please click on <i>authenticate</i> button to log in!";
        var b = document.createElement("button");
        html.appendChild(b);
        b.className = "btn";
        b.innerHTML = "Authenticate";
        logo.className = "";
        html.style.filter = "";
        //b.onClick =  auth(24,webeidLogo,p);
      }).catch(function (e) {
        message.innerHTML = "No card in reader !?";
        logo.className = "spin";
        // TODO check again OR listen to connect ?
        // https://github.com/web-eid/web-eid.js#webeidconnect
      });
    }).catch(function (e) {
      logo.className = "";
      logo.style.filter = "invert()";
      message.innerHTML = 'Can not get Web-eid version';
    });
  }).catch(function (e) {
      logo.className = "";
      logo.style.filter = "invert()";
      message.innerHTML = 'No web-eid. <br> Please see <a href="https://web-eid.com/" target="_bank">web-eid.com</a>';
  });
}
