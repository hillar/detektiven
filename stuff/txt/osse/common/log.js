const { nowAsJSON } = require('../common/time.js')
module.exports = {
  logCritical,
  logError,
  logInfo,
  logNotice,
  logWarning
}

function logCritical(critical){
  const time = nowAsJSON()
  console.error(JSON.stringify({time, critical}))
}

function logError(error){
  const time = nowAsJSON()
  console.error(JSON.stringify({time, error}))
}

function logInfo(info){
  const time = nowAsJSON()
  if (process.stdout.isTTY) console.log(JSON.stringify({time, info}))
}

function logNotice(notice){
  const time = nowAsJSON()
  console.log(JSON.stringify({time, notice}))
}

function logWarning(warning){
  const time = nowAsJSON()
  console.log(JSON.stringify({time, warning}))
}
