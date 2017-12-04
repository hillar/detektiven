import Fingerprint2 from 'fingerprintjs2'
export default function fingerprint () {
  return new Promise((resolve, reject) => {
    const fingerprint = new Fingerprint2()
    try {
      fingerprint.get((result, components) => {
        resolve(result)
      })
    } catch (err) {
      reject(err)
    }
  })
}
