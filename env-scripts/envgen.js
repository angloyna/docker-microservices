const fetch = require('node-fetch')

const consulURL = `http://${process.env.CONSUL_HTTP_ADDR}/v1/kv/${process.env.CONSUL_PATH}/?recurse=true`;
fetch(consulURL)
  .then(async(response)=>{
    const json = await response.json()
    const props = json
      .filter(c => !!c.Value)
      .forEach((c) => {
        console.log(c.Key.split('/').pop()+'='+ JSON.stringify(new Buffer(c.Value , 'base64').toString('ascii')).slice(1,-1))
      })
  }) 
  .catch((err)=>{console.log (`error fetching consul values for ${process.env.CONSUL_PATH}`, err)}) 
