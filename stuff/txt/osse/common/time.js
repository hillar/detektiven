module.exports = {
  now,
  nowAsJSON: now,
  date2JSON
}
function now(){
  const now = new Date()
  return now.toJSON()
}

function date2JSON(v){
  if (!v) {
    v = new Date()
    return v.toJSON()
  }
  const tmp = parseInt(v)
  if (! isNaN(tmp) ) {
    const d = new Date(tmp)
    if (isNaN(d.getTime())) return false
    else return d.toJSON()
  } else {
    const d = new Date(v)
    if (isNaN(d.getTime())) return false
    else return d.toJSON()
  }
}
