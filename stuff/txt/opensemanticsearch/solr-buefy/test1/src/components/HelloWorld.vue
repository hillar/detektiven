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
                    <b-field label="graph force">
                      <b-input v-model="options.force"
                        type="number"
                        min="1000"
                        max="10000"
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
            @details-open="(row, index) => this.connected(`${row.id}`,`${row.json}`,`${row}`)"
            :data="data"
            :nodes="currentNodes"
            :links="currentLinks"
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

            <template slot="detail" slot-scope="props" :nodes="nodes">
              <d3-network :net-nodes="currentNodes" :net-links="currentLinks" :options="options" @node-click="nodeClick"> </d3-network>
              <button class="button block" @click="isMeta = !isMeta">Meta</button>
              <b-message :title="`${props.row.id}`" :active.sync="isMeta">
                  {{ props.row.json }}
              </b-message>
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
                options:
                        {
                          canvas: false,
                          //size: {h: 1000},
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
            async nodeClick (event, node) {
              //expand current node
              if (event.shiftKey) {
                if (node.expand && node.root){
                  //this.nodes[node.root].findIndex()
                  this.loading = true
                  let q_url = `${this.$solr_server}/solr/core1/select?&q=${node.expand}&wt=json&rows=1`
                  console.log(q_url)
                  const axios = require('axios')
                  node._color = 'yellow'
                  let res = {}
                  try {
                    res = await axios(q_url)
                  } catch (e) {
                    console.dir(e)
                    this.$snackbar.open('contact your admin:'+e.message)
                    this.loading = false
                    return
                  }
                  for (let row of res.data.response.docs) {
                    let index = await this.currentNodes.findIndex((node) => { return node.id === row.id })
                    if (index>-1){
                      //this.currentNodes[index]._size *= 1.2;
                    } else {
                      this.currentNodes.push({ id: row.id, name: row.title[0], expand: 'id:"'+row.id+'"', root:node.root, _color:'green'})
                    }
                    this.currentLinks.push({ sid: node.id, tid: row.id })
                  for (let k of Object.keys(row)) {
                      if (Array.isArray(row[k]) === true && k.indexOf('_ss')>0) {
                        for (let v of row[k] ) {
                          //q.push({'field': k, 'value': v})
                          let index = await this.currentNodes.findIndex((node) => { return node.id === v })
                          if (index>-1){
                            this.$toast.open('on the graph already '+k+':'+v)
                          } else {
                            this.currentNodes.push({ id: v, name: v, _color:'green' ,expand: '"'+v+'"', root:node.root, filter:'"'+v+'"' })
                          }
                          this.currentLinks.push({ sid: row.id, tid: v, _color:'orange' })
                        }
                      }
                    }
                  }
                  this.loading = false
                }
              }
              // set current node to filter
              if (event.altKey){
                if (node.filter){
                  this.userQuery += node.filter
                  this.$toast.open(node.filter)
                  /*
                  this.$dialog.confirm({
                      message: 'set this filter:'+node.filter,
                      onConfirm: () => this.userQuery += node.filter
                  })
                  */
                }
              }
              if (event.ctrlKey) {
                this.$toast.open('ctrlKey')
              }
              if (!node.pinned) {
                node.pinned = true
                node.fx = node.x
                node.fy = node.y
              }
            },
            gvisibilityChanged (isVisible, entry, id) {
              //console.log(isVisible, entry, id)
              if (isVisible) {

              }
            },
            letsFlip: function(item){
              console.log('flipping')
            },

            async connected (id,meta) {
              this.currentNodes = []
              this.currentLinks = []
              if (this.nodes[id] && this.links[id]) {
                //this.$toast.open('using cached '+id)
                this.currentNodes = this.nodes[id]
                this.currentLinks = this.links[id]
                return
              }
              this.loading = true
              this.nodes[id] = []
              this.links[id] = []
              let connections = {}
              let q = [] // holds field values filtered from meta
              let row = null // parsed meta obj
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
              /*
              const createGraph = require('ngraph.graph')
              let g = createGraph()
              g.beginUpdate();
              g.addNode(id,row)
              */
              this.currentNodes.push({ id: id, name: id, _color:'red', _size:50 })
              // query all *_ss and append to row.connections
              const axios = require('axios')
              for (let i of q) {
                /*
                g.addNode(i.value)
                g.addLink(id,i.value,i.field)
                */
                //if (!nodeExists(id, this.nodes[id]))
                let index = await this.currentNodes.findIndex((node) => { return node.id === i.value })
                if (index>-1){
                  this.$toast.open(i.value)
                } else {
                  this.currentNodes.push({ id: i.value, name: i.value, _size:25, _color:'blue',filter:' "'+i.value+'"' })
                }
                this.currentLinks.push({ sid: id, tid: i.value, _color:'red' })
                let q_url = `${this.$solr_server}/solr/core1/select?fl=id,score,title&q=${i.field}:${i.value}&wt=json&rows=100`
                console.log(q_url)
                let res = await axios(q_url)
                for (let doc of res.data.response.docs) {
                  /*
                  g.addNode(doc.id,doc)
                  g.addLink(i.value,doc.id,i.field)
                  */
                  //if (!nodeExists(doc.id, this.nodes[id]))
                  let index = await this.currentNodes.findIndex((node) => { return node.id === doc.id })
                  if (index>-1){
                    //this.currentNodes[index]._size *= 1.2;
                  } else {
                    this.currentNodes.push({ id: doc.id, name: doc.title[0], expand: 'id:"'+doc.id+'"', root:id, _color:'green'})
                  }
                  this.currentLinks.push({ sid: i.value, tid: doc.id, _color:'green' })
                  //if (!connections[doc.id]) connections[doc.id] = {'title':doc.title[0],'fields':[]}
                  //connections[doc.id].fields.push({'field':i.field, 'value':i.value})
                }
              }
              //g.endUpdate()
              this.nodes[id] = this.currentNodes
              this.links[id] = this.currentLinks
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
                        this.nodes = {}
                        this.links = {}
                        this.currentNodes = []
                        this.currentLinks = []
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
