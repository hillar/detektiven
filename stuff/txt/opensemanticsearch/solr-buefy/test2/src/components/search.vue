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
        <div v-if="settings" >
          <h3>
              SETTINGS
          </h3>
          <b-field label="results per page">
            <b-input v-model="perPage"
              type="number"
              min="1"
              max="100"
            ></b-input>
          </b-field>
          <hr>
          <h1> search results columns</h1>
          <b-field  grouped group-multiline>
              <div v-for="(column, index) in columns" :key="index" class="control">
                  <b-checkbox v-model="column.visible">
                      {{ column.title }}
                  </b-checkbox>
              </div>

          </b-field>
          <hr>
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
                    <p v-if="column.field === 'highlighting' "v-innerhtml="props.row.highlighting"></p>
                    <p v-else>{{ props.row[column.field] }}</p>
                </b-table-column>
            </template>
            <template slot="detail" slot-scope="props" >
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

    async function askSolr(params){
      return new Promise((resolve, reject) => {
        const url = `/solr/core1/select?${params}`
        console.log('findDocs', url)
        axios.get(url)
        .then(function (res) {
          if (res.data ) {
            if (params.indexOf('wt=json') !== -1) {
              if (res.data.response){
                if (res.data.response.numFound != undefined ) {
                  resolve(res.data)
                } else {
                  console.error('not solr response, missing numFound', url)
                  console.dir(res.data)
                }
              } else {
                console.error('not solr response, missing response', url)
                console.dir(res.data)
              }
            } else {
              resolve(res.data)
            }
          }  else {
            console.error('not solr response, missing data', url)
            console.dir(res)
          }
        })
        .catch(function (err) {
          console.error(err.message)
          resolve({response:{numFound:0,start:0,docs:[]}})
        })
      })
    }

    export default {
        data() {
            let columns = [
                { title: 'ID', field: 'id', visible: false },
                { title: 'Score', field: 'score', visible: true },
                { title: 'Name', field: 'upload_filename', visible: true },
                { title: 'Highlights', field: 'highlighting', visible: true }
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
            helpDialog(){
              this.$modal.open({parent: this, component: Help})
            },
            uploadDialog(){
              this.$modal.open({parent: this, component: Upload})
            },
            subscribeDialog(){
              this.$modal.open({parent: this, component: Subcribe})
            },
            settingsDialog(){
              this.settings = !this.settings
              if (!this.settings) this.search()
            },
            async preview(row){
              if (!row.content){
                this.loading = true
                let q = `&wt=json&fl=content&q=id:"${row.id}"`
                let answer = await askSolr(q)
                if (answer.response.numFound != undefined ) {
                    row.content = answer.response.docs[0].content.join('\n').replace(/(\n\n\n\n)/gm,"\n").replace(/(\n\n\n)/gm,"\n").replace(/(\n\n)/gm,"\n");
                    this.$modal.open('<pre>'+row.content+'</pre>')
                }
                this.loading = false
              } else {
                this.$modal.open('<pre>'+row.content+'</pre>')
              }
            },
            async loadFields() {
              this.loading = true
              // q=*:*&wt=csv&rows=0&facet
              let answer = await askSolr('q=*:*&wt=csv&rows=0&facet')
              let fields = answer.split(',')
              for (let i in fields){
                  if (fields[i].indexOf('_b') < fields[i].length-2) {
                    for (let i in this.columns) if (this.columns[i].field == fields[i]) break
                    this.columns.push({ title: fields[i], field: fields[i], visible: false })
                  }
              }
              console.dir(fields)
              this.loading = false
            },

            async search() {
              this.loading = true
              this.message = ""
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
                  `q=${this.userQuery}`,
                  `hl=on&hl.fl=content&hl.fragsize=${this.fragSize}&hl.encoder=html&hl.snippets=${this.snippetsCount}`
                  ].join('&')
              let answer = await askSolr(params)
              console.dir(answer)
              if (answer.response.numFound > 0) {
                this.total = answer.response.numFound
                answer.response.docs.forEach((item) => {
                  for (let i in item) if (Array.isArray(item[i])) item[i] = item[i].join(this.separator)
                  if (answer.highlighting && answer.highlighting[item.id] && answer.highlighting[item.id].content){
                    item.highlighting = answer.highlighting[item.id].content.join('<br>...<br>')
                  } else {
                    item.highlighting = " .. "
                  }
                  this.data.push(item)
                })
              } else { this.message = this.userQuery +" <- no results ;(" }
              this.loading = false
            },

            onPageChange(page) {
                this.page = page
                this.search()
            },

            onSort(field, order) {
                this.sortField = field
                this.sortOrder = order
                this.search()
            }
        },
        mounted() {
            this.loadFields()
        }
    }
</script>
<style>
  em {background: #ff0;}
</style>
