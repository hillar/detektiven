<template>
    <section>
      <b-field grouped class="is-fullwidth">
          &nbsp;
          <b-collapse :open="false">
            <button class="button is-primary" slot="trigger">
              <b-icon icon="settings"></b-icon>
            </button>
            <div class="notification" style="position: absolute; left: 10px">
                <div class="content" align="left">
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
                    <b-field label="results per node expand">
                      <b-input v-model="perExpand"
                        type="number"
                        min="2"
                        max="1024"
                      ></b-input>
                      </b-field>
                      <b-field label="graph node size">
                        <b-input v-model="options.nodeSize"
                          type="number"
                          min="1"
                          max="100"
                        ></b-input>

                    </b-field>
                </div>
            </div>
          </b-collapse>
          &nbsp;
          <b-switch grouped is-small v-model="isAndOr"
                    @input = "loadAsyncData()"
                    true-value="AND"
                    false-value="OR">
                    {{ isAndOr }}
          </b-switch>
          &nbsp;
          <b-input grouped placeholder="Search..."
              v-model="userQuery"
              @keyup.native.enter = "test()"
              class="is-expanded"
              icon="magnify">
          </b-input>

          <b-upload v-model="files">
    <a class="button is-primary">
        <b-icon icon="upload"></b-icon>
    </a>
</b-upload>
<div v-if="files && files.length">
    <span class="file-name">
        {{ files[0].name }}
    </span>
</div>

          &nbsp;

          <b-collapse :open="false">
            <button class="button is-primary" slot="trigger">
              <b-icon icon="help"></b-icon></button>
            <div class="notification" style="position: absolute; right: 10px">
                    <h3>HELP</h3>
                    <p>
                        <br>double click row for result preview
                        <br>click gear on top left for settings
                        <br>alt-click on graph node sets filter
                        <br>shift-click on graph node ..
                    </p>
            </div>
          </b-collapse>
          &nbsp;
          &nbsp;
      </b-field>

      <hr>
        <b-table
            @dblclick="(row, index) => $modal.open(`${row.id}<hr><pre>${row.highlighted}</pre>`)"
            @details-open="connected"
            @add2filter="addtoquery"
            :data="data"
            :nodes="currentNodes"
            :links="currentLinks"
            :loading="loading"
            hoverable
            detailed
            detail-key="id"

            paginated
            backend-pagination
            :total="total"
            :per-page="perPage"
            @page-change="onPageChange"

            backend-sorting
            :default-sort-direction="defaultSortOrder"
            :default-sort="[sortField, sortOrder]"
            @sort="onSort">

            <template slot-scope="props">
              <b-table-column field="score" label="Score" numeric sortable>
                  {{ props.row.score }}
              </b-table-column>
              <b-table-column field="file_modified_dt" label="lastupdate" sortable centered>
                  {{ props.row.file_modified_dt ? new Date(props.row.file_modified_dt).toLocaleDateString() : '' }}
              </b-table-column>
                <b-table-column field="id" label="Name" sortable>
                    {{ props.row.name }}
                </b-table-column>
                <b-table-column label="content">
                    <p v-innerhtml="props.row.truncated"></p>
                </b-table-column>
            </template>

            <template slot="detail" slot-scope="props" :nodes="nodes" >

              <!--
              <d3-network :net-nodes="currentNodes" :net-links="currentLinks" :options="options" @node-click="nodeClick"> </d3-network>
              -->
              <div style="height:600px">
              <cytoscape :elements="currentEles" :queryURL="queryURL" :peekURL="peekURL" :fieldFilter="fieldFilter"></cytoscape>

              <button class="button block" @click="isMeta = !isMeta">Meta</button>
              <b-message :title="`${props.row.id}`" :active.sync="isMeta">
                  {{ props.row.json }}
              </b-message>
              </div>
            </template>

            <template slot="bottom-left">
                        &nbsp;<b>Total found</b>: {{ total }}
            </template>

        </b-table>
    </section>
</template>

<script>

function doc2graph(doc,fieldFilter,id){
  return new Promise((resolve, reject) => {
    console.log('doc2graph start',id,doc.id)
    let tmp = []
    tmp.push({data:{id:doc.id,label:doc.title.join(','),doc:doc}})
    if (id) tmp.push({data:{source:id,target:doc.id}})
    for (let key of Object.keys(doc)){
      if (Array.isArray(doc[key]) === true && key.indexOf(fieldFilter)>0) {
        if (doc[key].length > 32) {
          tmp.push({data:{id:doc.id+key,label:key+' - to many '+key+': '+ doc[key].length, [key]:doc[key]}})
          tmp.push({data:{source:doc.id,target:doc.id+key}})
        } else {
          for (let value of doc[key]) {
            if (value.length>0) {
              tmp.push({data:{id:value,label:value}})
              tmp.push({data:{source:doc.id,target:value}})
            }
          }
        }
      }
    }
    console.log('doc2graph end',tmp.length)
    resolve(tmp.slice())
  })
}
    export default {
        data() {
            return {
                userQuery: 'kala maja sõiduauto',
                isAndOr: 'AND',
                data: [],
                currentNodes: [],
                currentLinks: [],
                nodes: {},
                links: {},
                eles: {},
                currentEles:  [],
                perExpand : 64,
                // TODO fix perExpand undefined
                queryURL : `${this.$solr_server}/solr/core1/select?fl=*,score,content:[value v=""]&wt=json&rows=${this.perExpand||64}&sort=score DESC&q=`,
                peekURL : `${this.$solr_server}/solr/core1/select?fl=content&wt=json&rows=1&q=id:`,
                fieldFilter: this.$fieldFilter, //TODO move to parent
                options:
                        {
                          canvas: false,
                          size: {h: 1000},
                          force: 2500,
                          nodeSize: 10,
                          nodeLabels: true,
                          linkWidth:1
                        },
                g: {},
                layout: {},
                total: 0,
                loading: false,
                sortField: 'score',
                sortOrder: 'desc',
                defaultSortOrder: 'desc',
                page: 1,
                perPage: 10,
                fragsize: 1024,
                isMeta: false
            }
        },
        methods: {

            test (){
              if (!this.userQuery == "") {
                this.$toast.open({
                    message: `searching for: ${this.userQuery}`,
                    type: 'is-success'
                })
                this.loadAsyncData()
              }
            },
            addtoquery (filter) {
              this.userQuery += ` "${filter}"`
            },
            async doc2graphExpand(doc,fieldFilter,queryURL){
              const axios = require('axios')
              //prepare query url's
              let urls = []
              for (let key of Object.keys(doc)){
                if (Array.isArray(doc[key]) === true && key.indexOf(fieldFilter)>0) {
                  for (let value of doc[key]) {
                    if (value.length > 0) {
                      urls.push(`${queryURL}"${value}"`)
                    }
                  }
                }
              }
              // await till all queries are done
              let arrayOfDocs = await Promise.all(urls.map(function (url) {
                return new Promise((res,rej)=>{
                  axios.get(url)
                  .then((response) => {
                    res(response.data.response.docs)
                  })
                })
              }))
              //concat all docs, remove duplicates
              let docs = []
              doc['id'] = 'root'
              docs.push(doc)
              for (let ds of arrayOfDocs){
                for (let d in ds){
                  if (!docs.find((v) => {return (v.id == ds[d].id)} )){
                      docs.push(ds[d])
                  } else {
                    console.log('dup',ds[d].id)
                  }
                }
              }
              // build array of nodes & edges
              let tmp = []
              for (let i in docs) {
                let doc = docs[i]
                tmp.push({data:{id:doc.id,label:doc.title.join(','),doc:doc}})
                for (let key of Object.keys(doc)){
                  if (Array.isArray(doc[key]) === true && key.indexOf(fieldFilter) > 0) {
                      for (let value of doc[key]) {
                        if (value.length > 0) {
                          if (!tmp.find((v) => {return (v.id == value)} )){
                            tmp.push({data:{id:value,label:value}})
                          }
                          tmp.push({data:{source:doc.id,target:value}})
                        }
                      }
                  }
                }
              }
              return tmp.slice()
            },
            async connected (row) {
              this.loading = true
              let currentrow = Object.assign({}, row);
              this.$children[1].closeDetailRow(currentrow)
              let id = row.id
              if (this.eles[id]){
                //TODO fix it with vue.set !?
                this.currentEles = this.eles[id]
              } else {

                this.eles[id] = await this.doc2graphExpand(row, this.fieldFilter,this.queryURL)
                this.currentEles = this.eles[id]

                //this.currentEles = this.eles[id]
              }
              this.$children[1].openDetailRow(currentrow)
              this.loading = false

            },
            loadAsyncData () {
                this.loading = true
                this.data = []
                this.nodes = {}
                this.links = {}
                this.currentNodes = []
                this.currentLinks = []
                this.total = 0
                let start = (this.page - 1) * this.perPage
                let rows = this.perPage
                let fragsize = this.fragsize
                let sort = `${this.sortField}%20${this.sortOrder}`
                let op = `q.op=${this.isAndOr}`
                //let fl = 'fl=id,file_modified_dt'
                let fl = '&fl=*,score,content:[value v=""]'//`fl=${this.$solr_fields2get.join(',')}`
                //this.$toast.open(this.$solr_fields2get.join(','))
                let pre = "hl.tag.pre=<highlighted>"
                let post = "hl.tag.post=</highlighted>"
                let hl = `on&hl.fl=content&hl.fragsize=${fragsize}&hl.encoder=html&hl.snippets=100`
                let q_url = `${this.$solr_server}/solr/core1/select?${fl}&q=${this.userQuery}&${op}&wt=json&start=${start}&rows=${rows}&sort=${sort}&hl=${hl}`
                const axios = require('axios')
                axios.get(q_url)
                    .then(({ data }) => {
                        this.data = []
                        let currentTotal = data.response.numFound
                        this.total = currentTotal
                        data.response.docs.forEach((item) => {
                          //delete(item['content'])
                          Object.keys(item).forEach((k) => {
                            // delete all etl_*
                            if (item[k] === true) delete(item[k])
                          })
                          item.json = JSON.stringify(item,null,4)
                          item.name = item.id.substring(7,17)+'..'+item.id.substring(item.id.length-16)
                          if (data.highlighting) {
                            if (data.highlighting[item.id]) {
                              if (data.highlighting[item.id].content) {
                                item.highlighted =  data.highlighting[item.id].content[0].replace(/\n\n\n\n/g, "");
                                item.truncated = this.truncate(item.highlighted || '', fragsize)
                              }
                            }
                          }

                          this.data.push(item)
                        })
                        this.loading = false
                    }, response => {
                        this.data = []
                        this.nodes = {}
                        this.links = {}
                        this.currentNodes = []
                        this.currentLinks = []
                        this.total = 0
                        this.loading = false
                    })
                    .catch(function(error) {
                      that.loading = false
                      console.error(error);
                      that.$snackbar.open('refresh browser, no backend'+error.message)
                    })
            },

            truncate(value, length) {
              let l = 32
              let lp = value.indexOf('<em>')
              let rp = value.lastIndexOf('</em>')
              return '.. '+value.substring(lp-l,rp+l)+' ..'
            },

            onPageChange(page) {
                this.page = page
                this.loadAsyncData()
            },

            onSort(field, order) {
                this.sortField = field
                this.sortOrder = order
                this.loadAsyncData()
            }
        },
        mounted() {
            console.log('mounted search')
            this.loadAsyncData()
        }
    }
</script>
<style>
  em {background: #ff0;}
</style>
