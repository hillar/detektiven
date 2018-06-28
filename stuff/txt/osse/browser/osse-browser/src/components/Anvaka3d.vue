<template>
  <div id="a3" ref="a3" class="b-table" :class="{ 'is-loading': loading }"></div>
</template>

<script>

import axios from 'axios'
const createGraph = require('ngraph.graph');
//const nthree = require('ngraph.three');
const renderGraph = require('ngraph.pixel');

async function getConnectors(doc,fields){
  return new Promise((resolve, reject) => {
    let connectors = []
    for (let i in fields) {
      let f = fields[i]
      if (doc[f]) {
        if (Array.isArray(doc[f])) {
          for (let j in doc[f]){
            if (doc[f][j].length > 0) connectors.push('"'+doc[f][j]+'"')
          }
        } else {
          if (doc[f].length > 0) connectors.push('"'+doc[f]+'"')
        }
      }
    }
	  resolve(connectors);
	})
}

async function findDocs(q,rows){
  return new Promise((resolve, reject) => {
    if (!q) resolve(false)
    if (!rows) rows = 2028
    let fl = '*,content:[value v=""]'
    let q_url = `/solr/core1/select?&wt=json&rows=${rows}&fl=${encodeURIComponent(fl)}&q=${encodeURIComponent(q)}`
    axios.get(q_url)
    .then(function (res) {
      if (res.data ) {
        if (res.data.response){
          if (res.data.response.numFound != undefined ) {
            resolve(res.data.response.docs)
          } else {
            console.error('not solr response')
            resolve(false)
          }
        }
      }
    })
    .catch(function (err) {
      console.error(err.message)
      resolve(false)
    })
  })
}


export default {
  name: 'a3',
  props: {
            thing: {type: Object, default: {}},
            connectors: Array
  },
  data() {
    return {
      loading: true,
    }
  },
  methods: {
    async expandNode(graph,id){
        console.log('expandNode',id)
        return new Promise(async (resolve, reject) => {
          const node = graph.getNode(id)
          if (node.data && node.data.doc) {
            let qs = await getConnectors(node.data.doc,this.connectors)
            graph.beginUpdate();
            for (const q of qs ) {
              const docs = await findDocs(q)
              console.log('docs',q,docs.length)
              if (!graph.getNode(q)) graph.addNode(q,{__size__:6, __color__:0x0000ff})
              if (!graph.getLink(id,q)) graph.addLink(id,q)
              for (const doc of docs) {
                if (!graph.getNode(doc.id)) graph.addNode(doc.id,{doc:doc})
                if (!graph.getLink(q,doc.id)) graph.addLink(q,doc.id)
              }
            }
            graph.endUpdate();
          }
          resolve(true)
      })
    },
    async _mounted() {
      console.log('mounting..')
      const graph = createGraph()
      if (! this.thing.id) {
        return
      }
      let root = await findDocs(`id:${this.thing.id}`)
      console.log(root)
      graph.addNode(this.thing.id,{id:this.thing.id, __size__:10, __color__:0xff0000,doc:root[0]})
      await this.expandNode(graph,this.thing.id)
      await new Promise((resolve, reject) => {
        console.log('exp loop start',this.thing.id)
        graph.forEachLinkedNode(this.thing.id, async (linkedNode, link) => {
            console.log('linkedNode',linkedNode.links)
            for (const link of linkedNode.links) {
              console.log('link',link.fromId,link.toId)
              if (link.toId !== linkedNode.id){
                await this.expandNode(graph,link.toId)
              }
            }
        })
        resolve()
      })
      const renderer = renderGraph(graph,{container: document.getElementById('a3'),stable:true})
      //renderer.showNode(this.thing.id)
      const that = this
      renderer.on('nodeclick', function(node) {
        //that.expandNode(graph, node.id)
        renderer.showNode(node.id)
        console.log('Clicked on ' + JSON.stringify(node));
      });
      /*
      renderer.on('nodedblclick', function(node) {
        console.log('Double clicked on ' + JSON.stringify(node));
      });

      renderer.on('nodehover', function(node) {
        console.log('Hover node ' + JSON.stringify(node));
      });
      */
      this.loading = false
    }
  },
  async mounted() { this._mounted()}
};
</script>

<style>
#a3 {

  width: 100% !important;
  height: 100% !important;
}
</style>
