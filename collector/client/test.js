var clients = require('restify-clients');
client = clients.createClient({
  url: 'http://127.0.0.1:3000/api/v0/fli'
});

client.post({}, function(err, req) {
  if (err) {
    console.dir(err);
  } else {
    req.on('result', function(err, res) {
      console.dir(err);
      res.body = '';
      res.setEncoding('utf8');
      res.on('data', function(chunk) {
        res.body += chunk;
      });

      res.on('end', function() {
        console.log(res.body);
      });
    });
  }

  req.write('{"meta":"kala"}\n[[{"k":1}][{"k":2}]]\n');
  req.end();
});
