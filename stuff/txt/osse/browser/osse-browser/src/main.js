import Vue from 'vue'
import Buefy from 'buefy'
import App from './App'
import router from './router'

Vue.use(Buefy)
import cytoscape from '@/components/Cytoscape'
Vue.component('cytoscape',cytoscape)

Vue.config.productionTip = false

/* eslint-disable no-new */
new Vue({
  el: '#app',
  router,
  render: h => h(App)
})
