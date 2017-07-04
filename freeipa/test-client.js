var ldap = require('ldapjs');
var client = ldap.createClient({url: 'ldap://192.168.10.2:389'});
client.bind('uid=webeid,cn=users,cn=accounts,dc=example,dc=org', 'kalakala', function(err) {console.dir(err);});
//ldapsearch -x -D "uid=webeid,cn=users,cn=accounts,dc=example,dc=org" -w kalakala -h 192.168.10.2 -b
//"cn=accounts,dc=example,dc=org" -s sub 'uid=webeid'
// SRCH base="cn=accounts,dc=example,dc=org" scope=2 filter="(uid=webeid)" attrs=ALL
var opts = {
  filter: '(uid=webeid)',
  scope: 'sub'
};

client.search('cn=accounts,dc=example,dc=org', opts, function(err, res) {
  console.dir(err);

  res.on('searchEntry', function(entry) {
    console.log('entry: ' + JSON.stringify(entry.object));
  });
  res.on('searchReference', function(referral) {
    console.log('referral: ' + referral.uris.join());
  });
  res.on('error', function(err) {
    console.error('error: ' + err.message);
  });
  res.on('end', function(result) {
    console.log('status: ' + result.status);
  });
});
