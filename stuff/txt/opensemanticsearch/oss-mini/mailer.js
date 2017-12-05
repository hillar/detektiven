const nodemailer = require('nodemailer')

exports.send = async function(to, subject, body, from, host, port) {
  var host = host || process.env.SMTP_HOST
  var port = port || process.env.SMTP_PORT
  const transport = nodemailer.createTransport({
    host: host,
    port: port
  })
  var from = from || process.env.SMTP_FROM
  return transport.sendMail(
    {
      from: from,
      to: to,
      subject: subject,
      text: body
    },
    (error, info) => {
      if (error) {
        console.error(error.message)
      } else {
          console.log('message sent:', info.messageId)
      }
    }
  )
}
