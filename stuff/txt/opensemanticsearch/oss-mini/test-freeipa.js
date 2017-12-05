var freeipa = require('./freeipa');

// freeipa server ip
var IPASERVER = '192.168.10.2';
// user to bind
const BASE = 'cn=accounts,dc=example,dc=org';
const bindpass = 'kalakala';
const binduser = 'webeid';

//user & group to search
var employeeNumber  = '36712316013';
var groupName = 'chat';
const passwd = 'password'

// test it
(async ()=>{
    try{
      process.env.NODE_TLS_REJECT_UNAUTHORIZED = "0";
      var user = await freeipa.getUser(IPASERVER, BASE, binduser, bindpass, employeeNumber,passwd,groupName);
      console.log(user);
    }catch(e){
      console.log(e)
    }
})();
