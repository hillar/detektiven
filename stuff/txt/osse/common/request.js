module.exports = {
  getIpUser
}

function getIpUser(req){
  let username = req.user || false
  let ip = req.socket.remoteAddress
  if (req.headers['x-real-ip']) ip = req.headers['x-real-ip']
  if (req.headers['x-public-ip']) ip = req.headers['x-public-ip']
  /*
  'x-client-ssl-serial': '3..',
  */
  return {ip, username}
}
