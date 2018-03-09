const nodemailer = require('nodemailer')
const { logInfo, logWarning } = require('./log.js')

module.exports = {
  sendMail
}

function sendMail(to, subject, body, from, host, port) {
  return new Promise((resolve, reject) => {
    const func = 'sendMail'
    const transport = nodemailer.createTransport({host:host, port:port,tls: {rejectUnauthorized: false}})
    transport.sendMail({from:from, to:to, subject:subject, text:body },(err, info) => {
        if (err) {
          const error = err.message
          logWarning({sendMail:{'status':'mail not sent',error}})
          resolve(false)
        } else {
          logInfo({sendMail:{'status':'mail sent',info}})
          resolve(true)
        }
      })
  })
}
