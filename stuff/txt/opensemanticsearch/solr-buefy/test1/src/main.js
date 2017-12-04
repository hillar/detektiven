// The Vue build version to load with the `import` command
// (runtime-only or standalone) has been set in webpack.base.conf with an alias.
import Vue from 'vue'
import App from './App'
import router from './router'
import axios from 'axios'
import Buefy from 'buefy'
import 'buefy/lib/buefy.css'
import 'mdi/css/materialdesignicons.css'
Vue.use(Buefy)

import cytoscape from '@/components/cytoscape.vue'
Vue.component('cytoscape',cytoscape)

Vue.config.productionTip = false
Vue.prototype.$http = axios


Vue.directive('innerhtml', {
    deep: false,
    bind(el, binding) {
      el.innerHTML = binding.value
    },
    componentUpdated(el, binding) {
      el.innerHTML = binding.value
    }
})


// set solr server
const solr_server = 'https://192.168.11.2'
//const solr_server = ''
Vue.prototype.$solr_server = solr_server
console.log('solr server',Vue.prototype.$solr_server)
// grab fields
// https://192.168.11.2/solr/core1/schema/fields?showDefaults=true

import fingerprint from '@/utils/fingerprint'
fingerprint()
.then(function(fp){
  console.log('fingerprint',fp)
axios.get(`${solr_server}/solr/core1/schema/fields?showDefaults=true`)
  .then(function(response) {
    console.log(response.data.fields);
    Vue.prototype.$solr_fields = response.data.fields
    Vue.prototype.$solr_fields2get = []
    response.data.fields.forEach((item) => {
      // we do not want to grab content !
      if (item.name != 'content') Vue.prototype.$solr_fields2get.push(item.name)
    })
    console.log('field list',Vue.prototype.$solr_fields2get.join(','))
    /* eslint-disable no-new */
    new Vue({
      el: '#app',
      router,
      template: '<App/>',
      components: { App },
      solr_server: solr_server
    })
  })
  .catch(function(error) {
    console.error(error);
    alert('can not talk to solr server ;( ', solr_server)
  })
})
.catch(function(error) {
  console.error(error);
  alert('can not fingerprint browser ;( ')
})
