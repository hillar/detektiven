import webeid from './vendor/web-eid/web-eid.js';

export function hello() {
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
}
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
