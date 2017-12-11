const ldap = require('ldapjs');

function Client(options) {
  this.client = ldap.createClient(options);
}

function promisify(fn) {
  return function () {
    let client = this.client;
    let args = Array.prototype.slice.call(arguments);
    return new Promise(function (resolve, reject) {
      args.push(function (err, result) {
        if (err) reject(err);
        else resolve(result);
      });
      client[fn].apply(client, args);
    });
  };
}

['bind', 'unbind'].forEach(function (fn) {
  Client.prototype[fn] = promisify(fn);
});

Client.prototype.destroy = function () { this.client.destroy(); };

Client.prototype.search = function (base, options, controls) {
  let client = this.client;
  return new Promise(function (resolve, reject) {
    let searchCallback = function (err, result) {
      let r = {
        entries: [],
        references: []
      };

      result.on('searchEntry', function (entry) {
        r.entries.push(entry);
      });

      result.on('searchReference', function (reference) {
        r.references.push(reference);
      });

      result.on('error', function (err) {
        reject(err);
      });

      result.on('end', function (result) {
        if (result.status === 0) {
          resolve(r);
        } else {
          reject(new Error('non-zero status code: ' + result.status));
        }
      });
    };

    let args = ([base, options, controls, searchCallback])
      .filter(function (x) { return typeof x !== 'undefined'; });

    client.search.apply(client, args);
  });
};

exports.getUser = async function (server='127.0.0.1', base='cn=accounts,dc=example,dc=org', binduser='readonly', bindpass='password', uid='employeeNumber==test', pass='passwd',group='chat'){
    let client = new Client({url: 'ldaps://'+server});
    let bindid = 'uid='+binduser+',cn=users,'+base;
    return new Promise(function (resolve, reject) {
      client.bind(bindid,bindpass).then(function () {
        let grf = '(memberof=cn='+group+',cn=groups,'+base+')';
        let opts = { filter: '(&('+ uid +')'+grf+')', scope: 'sub'};
        client.search(base, opts).then(function (result) {
          if (result.entries) {
            if (result.entries.length === 1) {
                client.unbind();
                client = null
                let uid = 'uid='+result.entries[0].object.uid+',cn=users,'+base;
                let user = new Client({url: 'ldaps://'+server});
                user.bind(uid,pass).then(function () {
                  resolve(result.entries[0].object);
                  user.unbind()
                  user = null
                }).catch(function (err) {
                  reject(new Error('wrong username or password') );
                })
            } else {
              client.unbind();
              reject(new Error('none or to many entires') );
            }
          } else {
            client.unbind();
            reject(new Error('no entires') );
          }
        }).catch(function (err) {
          client.unbind();
          reject(err);
        });
      }).catch(function (err) {
        reject(err);
      });
    });
}
