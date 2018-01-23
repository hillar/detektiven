<template>
    <section>
    <div class="is-fullwidth" style='background-color:white'>
      <b-field label="Add some strings to get email on search match on new uploaded files" class="is-fluid is-expanded">
       <b-taginput
           v-model="stringsList"
           icon="label"
           placeholder="Add a string">
       </b-taginput>
     </b-field>
        <button class="button is-success is-large"
          @click="uploadSubscriptions(stringsList)">
        Update subcribed strings </button>
    </div>
    </section>
</template>

<script>

import axios from 'axios'
    export default {
        name: 'Subcribe',
        data() {
            return {
                stringsList: []
            }
        },
        methods: {
            unSubscribe(index) {
                console.log('unSubscribe',index,this.stringsList[index])
                this.stringsList.splice(index, 1)
            },
            getSubscriptions(){
              console.log('starting getSubscriptions')
              let that = this
              axios.get("/subscriptions")
                .then(function (res) {
                  if (res.data) {
                    try {
                      let fd = res.data
                      that.stringsList = fd.fields.strings.split(',')
                      if (that.stringsList[0] === "") that.stringsList = []
                    } catch (err) {
                      console.error(err);
                      that.$snackbar.open('contact your admin: subscriptions error '+err.message)
                    }
                  }
                  console.log('end getSubscriptions')
                })
                .catch(function (err) {
                  console.error(err.message)
                  that.$snackbar.open('contact your admin:'+err.message)
                });
            },
            uploadSubscriptions(strings) {
              const loadingComponent = this.$loading.open()
              let that = this
              console.log('start subscribe update')
              let data = new FormData();
              data.append('strings', strings);
              data.append('lastModified',Date.now())
              axios.post("/subscriptions",data)
                .then(function (res) {
                  console.log('subscriptions updated',strings.join(","))
                  if (res.data ) {
                    console.log('subcribe','server returned:',res.data)
                    that.$toast.open('server returned:'+ res.data)
                  }
                })
                .catch(function (err) {
                  console.error(err.message)
                  that.$snackbar.open('contact your admin:'+err.message)

                })
                .then(function() {
                  console.log('end subscribe update')
                  that.stringsList = []
                  loadingComponent.close()
                  that.$parent.close()
                })
            }
        },
        mounted(){
          this.getSubscriptions()
        }
    }
</script>
