import Vue from 'vue'
import Router from 'vue-router'
import Search from '@/components/Search'

Vue.use(Router)

export default new Router({
  routes: [
    { path: '/', redirect: { name: 'search' }},
    { path: '/search', name: 'search',component: Search, props: (route) => ({ query: route.query.q }) }
  ]
})
