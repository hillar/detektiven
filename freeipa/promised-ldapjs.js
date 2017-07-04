var ldap = require('ldapjs');

function Client(options) {
  this.client = ldap.createClient(options);
}

function promisify(fn) {
  return function () {
    var client = this.client;
    var args = Array.prototype.slice.call(arguments);

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
Client.prototype._search = promisify('search');


Client.prototype.search = function (base, options, controls) {
  var client = this.client;

  return new Promise(function (resolve, reject) {
    var searchCallback = function (err, result) {
      var r = {
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

    var args = ([base, options, controls, searchCallback])
      .filter(function (x) { return typeof x !== 'undefined'; });

    client.search.apply(client, args);
  });
};

module.exports = Client;
