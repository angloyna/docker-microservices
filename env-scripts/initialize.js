const config = require('./config.json')
const fetch = require('node-fetch')
const fs = require('fs')

const retries = {}

const status = {}

const delay = (time) => new Promise(resolve => setTimeout(resolve, time))

const forceExit = setTimeout(() => {
  console.log('timing out after 39 seconds')
  fs.writeFileSync('status.json', JSON.stringify(status))
  process.exit()
}, 39000)

var setIn = async (obj,path) => {
  var keys = Object.keys(obj)
  for(let k of keys) {
    await delay(5)
    if (obj[k] === null || typeof obj[k] === 'string') {
      status[`${path}/${k}`]? status[`${path}/${k}`].attempted = true : status[`${path}/${k}`] = {attempted: true}
      const consulURL = `http://${process.env.CONSUL_HTTP_ADDR}/v1/kv/${path}/${k}`;
      fetch(consulURL, { method:'PUT', body: obj[k]})
        .then(()=>{console.log (`set ${path}/${k} to ${obj[k]}`); status[`${path}/${k}`].set = true; status[`${path}/${k}`].value = obj[k]}) 
        .catch((err)=>{
          console.log (`error seting ${path}/${k} to ${obj[k]}`, err)
          retries[`${path}/${k}`] = !retries[`${path}/${k}`] ? 1 : retries[`${path}/${k}`] + 1
          status[`${path}/${k}`].failed = retries[`${path}/${k}`]
          if ( retries[`${path}/${k}`] > 2 ) {
            console.log(`GIVING UP trying to set: ${path}/${k}`)
          } else {
            let o = {}
            o[k] = obj[k] 
              setTimeout(()=>{
              console.log ('retrying ',k, path, o)
              status[`${path}/${k}`].retry = true
              setIn(o,path)
            }, 100) // */
          }
        }) 
    } else if (typeof obj[k] === 'object' && Object.keys(obj[k]).length > 0) {
      setIn(obj[k],path.split('/').filter(i=> i != '').concat(k).join('/'))
    }
  }
}

setIn(config,'')

clearTimeout(forceExit)
