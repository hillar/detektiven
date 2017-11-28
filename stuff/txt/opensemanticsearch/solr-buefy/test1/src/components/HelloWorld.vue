<template>
    <section>
      <div class="flipper">
      <div class="front">
      <b-field grouped style='width:90%;'>
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
          <b-input grouped placeholder="Search..." style='width:90%;'
              v-model="userQuery"
              @keyup.native.enter = "test()"
              type="search"
              icon="magnify">
          </b-input>
          &nbsp;
          <b-collapse :open="false">
            <button class="button is-primary" slot="trigger">
              <b-icon icon="help"></b-icon></button>
            <div class="notification" style="position: absolute; right: 10px">
                    <h3>HELP</h3>
                    <p>
                        <br>double click row for result preview
                        <br>click gear on top left for settings
                    </p>
            </div>
          </b-collapse>
          &nbsp;
          &nbsp;
      </b-field>

      <hr>
        <b-table
            @dblclick="(row, index) => $modal.open(`${row.id}<hr><pre>${row.highlighted}</pre>`)"
            @details-open="(row, index) => this.connected(`${row.id}`,`${row.json}`,`${row}`)"
            :data="data"
            :loading="loading"

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

            <template slot="detail" slot-scope="props">
                <!-- word cloud /solr/core1/select?&fl=id&rows=0&q=*&q.op=AND&wt=json&facet=true&facet.field=_text_&facet.minCount=1&facet.limit=50 -->
                <!-- to {{ props.row.g.getNodesCount() || 0}}  {{ props.row.g.getLinksCount() || 0}} -->
                <strong>{{ props.row.id }} connceted </strong>
                <hr>
                <div v-observe-visibility="(isVisible, entry) => gvisibilityChanged(isVisible, entry, `${props.row.id}`)">
                  <code style="font-size:50%"> {{props.row.connections}} </code>
                </div>
                <hr>
                <pre style="font-size:50%" v-innerhtml="props.row.json"></pre>

            </template>

            <template slot="bottom-left">
                        &nbsp;<b>Total found</b>: {{ total }}
            </template>

        </b-table>
      </div>
      <div class="back">
      </div>
    </div>
    </section>
</template>

<script>
    import axios from 'axios'
    export default {

        data() {
            return {
                userQuery: 'kala maja sõiduauto',
                isAndOr: 'OR',
                data: [],
                g: {},
                layout: {},
                total: 0,
                loading: false,
                sortField: 'file_modified_dt',
                sortOrder: 'desc',
                defaultSortOrder: 'desc',
                page: 1,
                perPage: 10,
                fragsize: 1024
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
            gvisibilityChanged (isVisible, entry, id) {
              console.log(isVisible, entry, id)
              if (isVisible) {
                
              }
            },
            letsFlip: function(item){
              console.log('flipping')
            },

            async connected (id,meta) {
              let datarow = null
              // look up our data row
              for (let rr of this.data) {
                if (rr.id == id){
                  if ( rr.connections) {
                    console.log(rr.g)
                    this.$toast.open('using cached '+id)
                    return
                  }
                }
              }
              // lets load connections
              this.loading = true
              let connections = {}
              let q = []
              let row = null
              try {
                row = await JSON.parse(meta)
              } catch (e) {
                console.error('row is not json')
                return
              }
              // find all *_ss from row meta
              for (let k of Object.keys(row)) {
                if (Array.isArray(row[k]) === true && k.indexOf('_ss')>0) {
                  for (let v of row[k] ) {
                    q.push({'field': k, 'value': v})
                  }
                }
              }
              // build ngraph.graph
              const createGraph = require('ngraph.graph')
              let g = createGraph()
              g.beginUpdate();
              g.addNode(id,row)
              // query all *_ss and append to row.connections
              const axios = require('axios')
              for (let i of q) {
                g.addNode(i.value)
                g.addLink(id,i.value,i.field)
                let q_url = `${this.$solr_server}/solr/core1/select?fl=id,score,title&q=${i.field}:${i.value}&wt=json&rows=100`
                console.log(q_url)
                let res = await axios(q_url)
                for (let doc of res.data.response.docs) {
                  g.addNode(doc.id,doc)
                  g.addLink(i.value,doc.id,i.field)
                  if (!connections[doc.id]) connections[doc.id] = {'title':doc.title[0],'fields':[]}
                  connections[doc.id].fields.push({'field':i.field, 'value':i.value})
                }
              }
              g.endUpdate()
              // put it into data
              for (let rr of this.data) {
                if (rr.id == id){
                  rr.connections = JSON.stringify(connections,null,4)
                  rr.connectedCount = Object.keys(connections).length
                  rr.g = g
                  const toJSON = require('ngraph.tojson');
                  const toDot = require('ngraph.todot');
                  let layout = require('ngraph.forcelayout3d')(g);
                  let ITERATIONS_COUNT = 100
                  for (var i = 0; i < ITERATIONS_COUNT; ++i) {
                    layout.step();
                  }
                  g.forEachNode(function(node) {
                      node.position = layout.getNodePosition(node.id)
                      // Node position is pair of x,y,z coordinates:
                      // {x: ... , y: ... , z: ... }
                    });
                  rr.connections = toJSON(g)
                }
              }

              this.loading = false
            },

            loadAsyncData () {
                this.loading = true
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
                this.$http.get(q_url)
                    .then(({ data }) => {
                        this.data = []
                        let currentTotal = data.response.numFound
                        this.total = currentTotal
                        data.response.docs.forEach((item) => {
                          delete(item['content'])
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
                        this.total = 0
                        this.loading = false
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
            this.loadAsyncData()
        }
    }
</script>
<style>
  em {background: #ff0;}

  /* 3D FLIP CARD */
  .flipper{
    transition: 0.6s;
  	transform-style: preserve-3d;
  	position: relative;
  }
  .flipper.flip{
    transform: rotateY(180deg);
  }

  .front,
  .back {
    margin: 0;
    display: block;
    width: 100%;
    height: 100%;
    position: absolute;
  	top: 0;
  	left: 0;
    backface-visibility: hidden;
  }

  .front {
    z-index: 2;
  	/* for firefox 31 */
  	transform: rotateY(0deg);
  }
  .back {
    transform: rotateY( 180deg );
  }



</style>
