import Vue from 'vue'
import Router from 'vue-router'
import search from '@/components/search.vue'

Vue.use(Router)

export default new Router({
  routes: [
    {
      path: '/',
      name: 'search',
      component: search
    }
  ]
})
