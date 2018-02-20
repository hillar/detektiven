<template>
  <div id="app">
    <router-view/>
  </div>
</template>

<script>
import 'buefy/lib/buefy.css'
import 'mdi/css/materialdesignicons.css'
export default {
  name: 'App'
}
</script>

<style>

#app {
  font-family: 'Avenir', Helvetica, Arial, sans-serif;
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
  text-align: center;
  color: #2c3e50;
  margin-top: 6px;
}
</style>
