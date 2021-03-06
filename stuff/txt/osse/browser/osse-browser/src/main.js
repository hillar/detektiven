import Vue from 'vue'
import Buefy from 'buefy'
import App from './App'
import router from './router'

Vue.use(Buefy)
import cytoscape from '@/components/Cytoscape'
Vue.component('cytoscape',cytoscape)
/*
import a3 from '@/components/Anvaka3d'
Vue.component('a3',a3)
import v3 from '@/components/Vasturiano3d'
Vue.component('v3',v3)
*/
Vue.config.productionTip = false

/* eslint-disable no-new */
new Vue({
  el: '#app',
  router,
  render: h => h(App)
})
