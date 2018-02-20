// The Vue build version to load with the `import` command
// (runtime-only or standalone) has been set in webpack.base.conf with an alias.
import Vue from 'vue'
import App from './App'
import router from './router'
import Buefy from 'buefy'
//import 'buefy/lib/buefy.css'
//import 'mdi/css/materialdesignicons.css'
Vue.use(Buefy)

import cytoscape from '@/components/cytoscape.vue'
Vue.component('cytoscape',cytoscape)

Vue.config.productionTip = false

Vue.directive('innerhtml', {
    deep: false,
    bind(el, binding) {
      el.innerHTML = binding.value
    },
    componentUpdated(el, binding) {
      el.innerHTML = binding.value
    }
})

const config = require('@/config.json')

Vue.prototype.$fieldFilter = config.fieldFilter || '_ss'

const solr_server = ''
Vue.prototype.$solr_server = solr_server

import axios from 'axios'
import fingerprint from '@/utils/fingerprint'
fingerprint()
.then(function(fp){
  console.log('sending fingerprint',fp,'to',Vue.prototype.$solr_server)
  axios.get(`${solr_server}/?fp=${fp}`)
  .then(function(response) {
    if (response.status == 200) {
      /*
      get list of fields
      http://localhost:8080/solr/core1/select?q=*:*&wt=csv&rows=0&facet
      */
      /* eslint-disable no-new */
      new Vue({
        el: '#app',
        router,
        template: '<App/>',
        components: { App }
      })
    } else {
        alert('can not talk to server ;(',response.status)
    }
  })
  .catch(function(error) {
    console.error(error);
    alert('can not talk to server ;( ', solr_server)
  })
})
.catch(function(error) {
  console.error(error);
  alert('can not fingerprint browser ;( ')
})
