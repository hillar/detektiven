const ldap = require('ldapjs')
const { logError, logWarning, logInfo } = require('./log.js')

module.exports = {
  getUser
}

function ldapBindandFind(server,base,binduser,bindpass,field,user,pass,group){
  return new Promise((resolve, reject) => {
    const func = 'ldapBindandFind'
    try {
      let client = ldap.createClient({url: `ldaps://${server}`, tlsOptions: {rejectUnauthorized: false}})
      client.on('error',function(err){
        logWarning({func,'clientError':err.message})
        resolve(false)
      })
      client.bind(`uid=${binduser},cn=users,${base}`,bindpass,function(err){
        if (err) {
          logWarning({func,'bindError':err.message})
          resolve(false)
        } else {
          let opts = { filter: `(&(${field}=${user})(memberof=cn=${group},cn=groups,${base}))`, scope: 'sub'};
          //logInfo({'ldap':'binded', opts})
          client.search(base,opts,function(err, res) {
            if (err) {
              logWarning({func,'searchError':err.message})
              resolve(false)
            } else {
              let entries = []
              res.on('searchEntry', function(entry) {
                entries.push(entry.object)
              });
              res.on('error', function(err) {
                resolve(false)
              });
              res.on('end', function(result) {
                //logInfo({'end':entries})
                if (entries.length === 1) {
                    resolve(entries[0])
                } else {
                  if (entries.length === 0 ) logInfo({'notfound':{user,group}})
                  else logError({'shouldNotHappen':user +' to many entiries ' + entries.length })
                  resolve(false)
                }
              });
            }
          })
        }
      })
  } catch (err) {
    logError({func,'error':err.message})
    resolve(false);
  }
  })
}

async function getUser(server,base,binduser,bindpass,field,user,pass,group){
  let a = await ldapBindandFind(server,base,binduser,bindpass,field,user,pass,group)
  if (!a) return false
  let b = await ldapBindandFind(server,base,a.uid,pass,'uid',user,null,group)
  if (!b) return false
  let u = {}
  u['uid'] = b.uid
  u['cn'] = b.cn
  u['mail'] = (Array.isArray(b.mail) ? b.mail.join('; '):  b.mail)
  u['employeeNumber'] = b.employeeNumber
  u['memberOf'] = []
  let tmp = b.memberOf.filter(g => g.indexOf(',cn=groups,') > -1)
  for (let i in tmp){
    u['memberOf'].push(tmp[i].split(',')[0].split('=')[1])
  }

  return u
}
