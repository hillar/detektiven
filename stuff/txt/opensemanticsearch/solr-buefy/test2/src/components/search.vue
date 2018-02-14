<template>
   <section>
      <b-field grouped class="container is-fullwidth">
         <b-field class="is-fluid is-expanded">
            <button class="is-disabled">Archive</button>
            <b-input class="is-expanded is-focused"
               placeholder="Search .. "
               v-model="userQuery"
               @keyup.native.enter = "search()">
            </b-input>
            <b-select v-model="isAndOr">
               {{ isAndOr }}
               <option>AND</option>
               <option>OR</option>
            </b-select>
            <button class="button is-success"
               @click= "search()">
               <b-icon icon="magnify"></b-icon>
            </button>
         </b-field>
         <b-field grouped>
            <button class="button is-primary"
               @click= "settingsDialog()">
               <b-icon icon="settings"></b-icon>
            </button>
            &nbsp;
            <button class="button is-primary"
               @click= "uploadDialog()">
               <b-icon icon="upload"></b-icon>
            </button>
            &nbsp;
            <button class="button is-primary"
               @click= "subscribeDialog()">
               <b-icon icon="email"></b-icon>
            </button>
            &nbsp;
            <button class="button is-primary"
               @click= "helpDialog()">
               <b-icon icon="help"></b-icon>
            </button>
         </b-field>
      </b-field>
      <div v-if="settings" class="columns is-multiline is-mobile">
         <div class="column is-one-quarter">
            <h3>SETTINGS</h3>
            <b-field label="results per page">
               <b-input v-model="perPage" type="number" min="1" max="100"></b-input>
            </b-field>
            <b-field label="matched fragment size">
               <b-input v-model="fragSize" type="number" min="32" max="256"></b-input>
            </b-field>
            <b-field label="matched fragments count">
               <b-input v-model="snippetsCount" type="number" min="1" max="128"></b-input>
            </b-field>
            <b-field label="array join separator">
               <b-input v-model="separator"></b-input>
            </b-field>
         </div>
         <div class="column">
            <h3>search results columns</h3>
            <b-field  grouped group-multiline>
               <div v-for="(column, index) in columns" :key="index" class="control">
                  <b-checkbox v-model="column.visible">
                     {{ column.title }}
                  </b-checkbox>
               </div>
            </b-field>
            <hr>
         </div>
      </div>
      <div justify-content: center>
         <p v-if="message.length > 0">{{ message }}</p>
         <b-table v-if="data.length > 0"
         @dblclick="(row) => preview(row)"
         :data="data"
         :loading="loading"
         paginated
         backend-pagination
         :total="total"
         :per-page="perPage"
         @page-change="onPageChange"
         detailed
         detail-key="id"
         backend-sorting
         :default-sort-direction="defaultSortOrder"
         :default-sort="[sortField, sortOrder]"
         @sort="onSort">
         <template slot-scope="props">
            <b-table-column v-for="(column, index) in columns"
               :key="index"
               :label="column.title"
               :visible="column.visible">
               <p v-if="column.field === '_highlighting_' "v-innerhtml="props.row._highlighting_"></p>
               <p v-else>{{ props.row[column.field] }}</p>
            </b-table-column>
         </template>
         <template slot="detail" slot-scope="props">
            <div style="height:600px">
               <cytoscape :thing="props.row" :connectors="connectorFields"></cytoscape>
            </div>
         </template>
         <template slot="bottom-left">
            &nbsp;<b>Total found</b>: {{ total }} on page {{ page }}
         </template>
         </b-table>
      </div>
   </section>
</template>

<script>

    import axios from 'axios'
    import Help from '@/components/Help'
    import Upload from '@/components/Upload'
    import Subcribe from '@/components/Subcribe'

    async function axiosGet(u) {
      return new Promise((resolve, reject) => {
        axios.get(u)
        .then(function (res) {
          resolve(res)
        })
        .catch(function (err) {
          resolve(false)
        })
      })
    }
    async function axiosPost(u,d){
      return new Promise((resolve, reject) => {
        axios.post(u,d)
          .then(function (res) {
            resolve(res)
          })
          .catch(function (err) {
            resolve(false)
          })
      })
    }

    async function askSolr(params){
      return new Promise((resolve, reject) => {
        const url = `/solr/core1/select?${params}`
        //const url = `/search?${params}`
        const defaultResult = {response:{numFound:0,start:0,docs:[]}}
        axiosGet(url)
        .then(function (res) {
          if (res.data ) {
            if (params.indexOf('wt=json') !== -1) {
              if (res.data.response){
                if (res.data.response.numFound != undefined ) {
                  resolve(res.data)
                } else {
                  errorsPush('nonumFound', url)
                  console.dir(res.data)
                  resolve(defaultResult)
                }
              } else {
                errorsPush('noResponse', url)
                console.dir(res.data)
                resolve(defaultResult)
              }
            } else {
              resolve(res.data)
            }
          }  else {
            errorsPush('noData', url)
            console.dir(res)
            resolve(false)
          }
          })
      })
    }

    async function errorsSend(){
      if (errors.length === 0) return
      let sending = errors.slice()
      errors = []
      let es = await axiosPost('/errors',JSON.stringify(sending))
      if (es === false) {
        errors = errors.concat(sending)
      }
      return
    }

    function errorsPush(...args){
      let msg = {}
      let now = new Date()
      msg['time'] = now.toJSON()
      let type = args[0]
      args.shift()
      msg[type] = args
      errors.push(msg)
      console.log(msg)
    }

    let errors = []

    export default {
        data() {
            let columns = [
                { title: 'ID', field: 'id', visible: false },
                { title: 'Score', field: 'score', visible: true },
                { title: 'Server', field: '_server_', visible: false },
                { title: 'Name', field: 'upload_filename', visible: true },
                { title: 'Highlights', field: '_highlighting_', visible: true }
            ]
            let connectorFields = [
              "email_ss",
              "upload_tags"
            ]
            return {
                data: [],
                columns,
                connectorFields,
                total: 0,
                loading: false,
                sortField: 'score',
                sortOrder: 'desc',
                defaultSortOrder: 'desc',
                page: 1,
                perPage: 10,
                message: 'do some search ..',
                settings: false,
                isAndOr: 'AND',
                userQuery: '',
                fragSize: 128,
                snippetsCount: 4,
                separator: '; '
            }
        },
        methods: {

            async loadFields() {
              this.loading = true
              const loadingComponent = this.$loading.open()
              let old = this.message
              this.message = "wait, loading fields from solr"
              let fields = []
              let q = 'q=*:*&wt=csv&rows=0&facet'
              let answer = await askSolr(q)
              if (answer === false || typeof(answer) !== 'string') {
                errorsPush('noFields',q)
                this.$snackbar.open('notify your admin, field list is not loading')
              } else {
                fields = answer.trim().split(',')
                for (let i in fields){
                  if ((fields[i].indexOf('_b') - fields[i].length)!=-2) {
                    let found = false
                    for (let j in this.columns) {
                      //console.log(this.columns[j].field,fields[i])
                      if (this.columns[j].field === fields[i]) {
                        found = true
                        //console.log(this.columns[j].field,fields[i])
                        break
                      }
                    }

                    if (!found) this.columns.push({ title: fields[i], field: fields[i], visible: false })
                  }
                }
              }
              this.message = old
              loadingComponent.close()
              this.loading = false
            },

            async search() {
              errorsSend()
              const loadingComponent = this.$loading.open()
              let old = this.message
              this.message = "wait, searching .."
              this.data = []
              this.total = 0
              let fields = []
              for (let i in this.columns) if (this.columns[i].visible) fields.push(this.columns[i].field)
              const params = [
                  'wt=json',
                  `fl=id,${fields.join(',')}`,
                  `start=${(this.page - 1) * this.perPage}`,
                  `rows=${this.perPage}`,
                  `sort=${this.sortField}%20${this.sortOrder}`,
                  `q.op=${this.isAndOr}`,
                  `q=${encodeURIComponent(this.userQuery)}`,
                  `hl=on&hl.fl=content&hl.fragsize=${this.fragSize}&hl.encoder=html&hl.snippets=${this.snippetsCount}`
                  ].join('&')
              let answer = await askSolr(params)
              if (answer === false ) {
                  this.message = old
                  errorsPush('noResponse',params)
                  this.$snackbar.open('notify your admin, solr did not returned any answers')
              } else {
                this.message = ""
                if (answer.response.numFound > 0) {
                  this.total = answer.response.numFound
                  answer.response.docs.forEach((item) => {
                    for (let i in item) if (Array.isArray(item[i])) item[i] = item[i].join(this.separator)
                    if (!item._highlighting_){
                      if (answer.highlighting && answer.highlighting[item.id] && answer.highlighting[item.id].content){
                        item._highlighting_ = answer.highlighting[item.id].content.join('<br>...<br>')
                      } else {
                        item._highlighting_ = " .. "
                      }
                    }
                    this.data.push(item)
                  })
                } else {
                  this.message = this.userQuery +" <- no results ;("
                }
              }
              loadingComponent.close()
            },

            async preview(row){
              if (!row.content){
                this.loading = true
                let q = encodeURIComponent(`id:"${row.id}"`)
                let u = `&wt=json&fl=content&q=${q}`
                let answer = await askSolr(u)
                if (answer === false) {
                   errorsPush('noPreview',u)
                   this.$snackbar.open('contact your admin, backend returned no data')
                } else {
                  if (answer.response.numFound != undefined && answer.response.docs && answer.response.docs[0] && answer.response.docs[0].content) {
                      row.content = answer.response.docs[0].content.join('\n').replace(/(\n\n\n\n)/gm,"\n").replace(/(\n\n\n)/gm,"\n").replace(/(\n\n)/gm,"\n");
                      this.$modal.open('<pre>'+row.content+'</pre>')
                  } else {
                    this.$toast.open('no content, sorry ;(')
                    if (!answer.response.docs) errorsPush('noDocs',answer.response)
                    if (!answer.response.docs[0]) errorsPush('emptyDoc',answer.response)
                  }
                }
                this.loading = false
              } else {
                this.$modal.open('<pre>'+row.content+'</pre>')
              }
            },

            onPageChange(page) {
                this.page = page
                this.search()
            },
            onSort(field, order) {
                this.sortField = field
                this.sortOrder = order
                this.search()
            },
            helpDialog(){
              this.$modal.open({parent: this, component: Help})
            },
            uploadDialog(){
              this.$modal.open({parent: this, component: Upload})
            },
            subscribeDialog(){
              this.$modal.open({parent: this, component: Subcribe})
            },
            async settingsDialog(){
              if (!this.settings) {
                await this.loadFields() //reload fields from solr
              }
              this.settings = !this.settings
              if (!this.settings) await this.search() // reload search if settings closed
            }
        },
        mounted() {
            //this.loadFields()
        }
    }
</script>
<style>
  em {background: #ff0;}
</style>
