<template>
  <div id="cy" ref="cy" class="b-table" :class="{ 'is-loading': loading }"></div>
</template>

<script>
import cytoscape from 'cytoscape'
import Weaver from "weaverjs";
import cxtmenu from 'cytoscape-cxtmenu'
import axios from 'axios'
const createGraph = require('ngraph.graph');
cxtmenu(cytoscape)

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

async function findDocs(q,f,rows){
  return new Promise((resolve, reject) => {
    if (!q) resolve(false)
    if (!rows) rows = 32
    let fl = '*,content:[value v=""]'
    if (Array.isArray(f) && f.length>0) {
      fl = f.join(',')
    }
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

async function addElements(cy,docs,fields){
  return new Promise((resolve, reject) => {
    let label = 'path_basename_s'
    cy.startBatch()
    for (let i in docs) {
      let doc = docs[i]
      if (cy.getElementById(doc.id).length === 0) {
          if (doc.id.length > 0) cy.add({data:{id:doc.id,type:'doc',label:doc[label],doc:doc}})
      }
      let connectors = {}
      for (let i in fields) {
        let f = fields[i]
        if (doc[f]) {
          if (Array.isArray(doc[f])) {
              if (doc[f].length > 0) connectors[f] = doc[f]
          } else {
            connectors[f] = [doc[f]]
          }
        }
      }
      for (let f in connectors){
        let c = doc.id + f
        if (cy.getElementById(c).length === 0) {
          cy.add({data:{id:c,label:f,type:'connector'}})
          cy.add({data:{source:doc.id,target:c}})
          //console.log(f,doc.id)
        }
        for (let i in connectors[f]){
            let cc = connectors[f][i].replace(/['"]+/g, '')
            if (cy.getElementById(cc).length == 0) {
              cy.add({data:{id:cc,type:f,label:cc}})
              //console.log(cc)
            }
            cy.add({data:{source:c,target:cc}})
        }
      }
    }
    cy.endBatch()
    resolve(true)
  })
}

async function buildG(docs,fields){
  return new Promise(async (resolve, reject) => {
    let g = createGraph()
    let label = 'path_basename_s'
    let counts = {}
    g.beginUpdate()
    for (let i in docs) {
      let doc = docs[i]
      if (!g.getNode(doc.id)) {
          if (doc.id.length > 0) g.addNode(doc.id,{type:'doc',label:doc[label],doc:doc})
      }
      let connectors = {}
      for (let i in fields) {
        let f = fields[i]
        if (doc[f]) {
          if (Array.isArray(doc[f])) {
              if (doc[f].length > 0) connectors[f] = doc[f]
          } else {
            connectors[f] = [doc[f]]
          }
        }
      }
      //console.log('connectors',Object.keys(connectors).length,doc.id)
      for (let f in connectors){
        //console.log(f,connectors[f].length,doc.id)
        if (!counts[f]) counts[f] = 0
        let c = doc.id + f
        if (!g.getNode(c)) {
          g.addNode(c,{label:f,type:'connector'})
          g.addLink(doc.id,c)
        }
        for (let i in connectors[f]){
            let cc = connectors[f][i]
            if (!g.getNode(cc)) {
              g.addNode(cc,{type:f,label:cc})
            }
            g.addLink(c,cc)
            counts[f] += 1
        }
      }
    }
    // remove leaves
    if (g.getNodesCount() > 384) {
    console.log('start',g.getNodesCount(),g.getLinksCount())
    await new Promise((resolve, reject) => {
      let nodes = g.getNodesCount()
      let i = 0
      g.forEachNode(function(node){
        i += 1
        if (node && node.links && node.links.length < 2 ) {
          g.removeNode(node.id)
        }
        if (nodes === i ) resolve(true)
      })
    })
    console.log('step1',g.getNodesCount(),g.getLinksCount())
      if (g.getNodesCount() > 384) {
      await new Promise((resolve, reject) => {
        let nodes = g.getNodesCount()
        let i = 0
        g.forEachNode(function(node){
          i += 1
          if (node && node.links && node.links.length < 2 ) {
            g.removeNode(node.id)
          }
          if (nodes === i ) resolve(true)
        })
      })
      console.log('step2',g.getNodesCount(),g.getLinksCount())
    }
    // 4K is 3840  X 2160
    // still to big ;(
    if (g.getNodesCount() > 384) {
        for (let f in counts ) {
          //console.log(counts[f])
          if (counts[f] > 384) {
            await new Promise((resolve, reject) => {
              let nodes = g.getNodesCount()
              let i = 0
              g.forEachNode(function(node){
                i += 1
                if (node && node.data && node.data.type === f ) {
                  g.removeNode(node.id)
                }
                if (nodes === i ) resolve(true)
              })
            })
          }
        }
        console.log('now should be small.. ',g.getNodesCount(),g.getLinksCount())
    }
    }
    g.endUpdate()
    resolve(g)
  })
}


export default {
  name: 'cytoscape',
  props: {
            thing: {type: Object, default: {}},
            connectors: Array
  },
  data () {
    return {
      loading: false,
      initialZoom: 1,
      layout: {
        name: "cose",
        animate: true,
        idealEdgeLength: 100,
        nodeOverlap: 20,
        refresh: 20,
        fit: true,
        padding: 30,
        randomize: false,
        componentSpacing: 100,
        nodeRepulsion: 400000,
        edgeElasticity: 100,
        nestingFactor: 5,
        gravity: 80,
        numIter: 1000,
        initialTemp: 450,
        coolingFactor: 0.99,
        minTemp: 1.0,
        root: ''
      },
      style: [
              {
               selector: 'node',
               style: {
                 'label': 'data(label)',
                 "font-size": 9,
                 "min-zoomed-font-size": 9,
                 "text-valign": "top",
               }
             },
             {
              selector: 'node[type="connector"]',
              style: {
                'label': '',
                'opacity': "0.1"
              }
            },
            {
             selector: 'node[type="doc"]',
             style: {
               'background-color':  '#0ff',
             }
           },
           {
            selector: 'node[type="root"]',
            style: {
              'background-color':  '#f00',
            }
          },
             {
               selector: 'edge',
               style: {
                 'width': 1,
                 'line-color': '#ccc',
                 'target-arrow-color': '#ccc',
                 'target-arrow-shape': 'triangle'
               }
             },
             {
               selector: ".element-red",
               style: {
                 'font-size': 9,
                 'background-color':  '#f00',
               }
             },
             {
               selector: ".element-green",
               style: {
                 'font-size': 12,
                 'background-color':  '#0f0',
               }
             },
             {
               selector: ".element-transparent",
               style: {
                 opacity: "0.2"
               }
             },
      ]
    }
  },
  created () {
    Object.assign(this, { cy: {} });
  },
  mounted () {
    this.loading = true
    this.cy = cytoscape({
        container: document.getElementById('cy'),
        layout: this.layout,
        style: this.style
    });
    this.cy.zoom({level:this.initialZoom/100})
    this.cy.cxtmenu({
      selector: "node",
      commands: [


        {
          content: "<h1 style='color:green'>+</h1>",
          select: this.expandNode
        },
        {
          content: "<h1 style='color:yellow'>*</h1>",
          select: this.highlightNode
        },
        {
          content: "<h1 style='color:blue'>?</h1>",
          select: this.searchbarNode
        },
        {
          content: 'peek',
          select: this.peekNodeContent
        },
        {
          content: 'export',
          select: this.exportNodeFile
        },
        {
          content: 'meta',
          select: this.exportNodeJson
        },
        {
          content: "<h1 style='color:red'>-</h1>",
          select: this.removeNode
        }
      ],
      fillColor: "rgba(96, 125, 139, 0.75)"
    })

    this.cy.cxtmenu({
      selector: "core",
      commands: [
        {
          content: "Redraw",
          select: this.reDrawGraph
        },
        {
          content: "Clear highlights",
          select: this.clearHighlights
        },
        {
          content: "Highlight root",
          select: this.centerOnGraph
        },
        {
          content: "json",
          select: this.exportGraphJson
        },
        {
          content: "png",
          select: this.exportGraphImage
        }
      ],
      fillColor: "rgba(96, 125, 139, 0.75)"
    })

    this.root = this.thing.id
    if (!this.cy.getElementById(this.thing.id).length){
      this.loadRoot(this.thing)
    } else {
      let layout = this.cy.makeLayout(this.layout);
      layout.run();
      // find root & highlight it
      this.highlightNode(this.cy.getElementById(this.thing.id))
      this.loading = false
    }
  },
  methods: {
    async loadRoot(root){
      this.loading = true
      let start = Date.now()
      let rootDoc = await findDocs(`id:"${root.id}"`, this.connectors.concat(['id','path_basename_s','container_s']))
      let qs = await getConnectors(rootDoc[0],this.connectors)
      if (qs.length > 128) this.$toast.open('sorry, wait a bit ..<br>object to query: '+qs.length)
      let docs = []
      docs.push(rootDoc[0])
      let i,j,temparray,chunk = 128;
      for (let i=0,j=qs.length; i<j; i+=chunk) {
          let tmpq = qs.slice(i,i+chunk)
          //console.log(i,j,tmpq.join(' OR '))
          let tmp = await findDocs(tmpq.join(' OR '), this.connectors.concat(['id','path_basename_s','container_s']))
          for (let y in tmp) if (!docs.find(x => x.id === tmp[y].id)) docs.push(tmp[y])
          //console.log('docs',docs.length,'q',tmpq.join(' OR ').length)
      }
      if ((Date.now()-start)>4000) this.$toast.open('got docs: '+docs.length)
      console.log('queries took',Date.now()-start,'got docs',docs.length)
      let graph = await buildG(docs, this.connectors)
      console.log('ngraph took',Date.now()-start,'got graph',graph.getNodesCount(),graph.getLinksCount())
      if ((Date.now()-start)>5000) this.$toast.open('nodes: '+graph.getNodesCount()+' <br> edges: '+graph.getLinksCount())
      this.cy.startBatch()
      let cy = this.cy
      graph.forEachNode(function(node) {
        if (cy.getElementById(node.id).length === 0) {
            if (node.id.length > 0) cy.add({data:{id:node.id,type:node.data.type,label:node.data.label,data:node.data}})
        }
      })
      graph.forEachLink(function(link) {
        cy.add({data:{source:link.fromId,target:link.toId}})
      })
      this.cy.getElementById(this.root).addClass("element-green")
      this.cy.endBatch()
      console.log('cyto took',Date.now()-start)
      let layout = this.cy.makeLayout(this.layout);
      layout.run();
      console.log('total took',Date.now()-start)
      this.loading = false
    },

    settings () {
      this.$dialog.prompt({
                    message: `settings`,
                    inputAttrs: {
                        type: 'number',
                        placeholder: 'idealEdgeLength',
                        value: this.layout.idealEdgeLength,
                        maxlength: 2,
                        min: 18
                    },
                    onConfirm: (value) => this.$toast.open(`${value}`)
                })

    },
    // context menu items for nodes
    highlightNode (node) {
      var that = this;
      that.cy.batch(function() {
        that.cy.elements().addClass("element-transparent");
        node.closedNeighborhood().closedNeighborhood().removeClass("element-transparent");
        node.addClass("element-red")
      });
    },
    clearHighlights () {
      this.cy.elements().removeClass("element-transparent");
    },
    removeNode (node) {
      console.log('removeNode')
      node.neighborhood().forEach(ele => {
        ele.connectedEdges().length <= 1 ? this.cy.remove(ele) : null;
      }, this);
      this.cy.remove(node);
    },
    async expandNode(node) {
      //console.log('expandNode')
      this.loading = true
      let id = node.data('id')
      let data = node.data('data')
      let cy = this.cy
      let docs = []
      let added = false
      if (data && data.doc && data.doc.id){
        let qs = await getConnectors(data.doc,this.connectors)
        if (qs.length > (384/8)) {
          this.$toast.open('will explode, to many objects ..<br>object:'+qs.length)
        } else {
          added = await new Promise((resolve, reject) => {
            let a = false
            cy.startBatch()
            for (let i in qs) {
              let cc = qs[i].replace(/['"]+/g, '')
              if (cy.getElementById(cc).length === 0) {
                  if (cc.length > 0) cy.add({data:{id:cc,type:'expanded',label:cc}})
                  cy.add({data:{source:id,target:cc}})
                  a = true
              }
            }
            cy.endBatch()
            resolve(a)
          })
        }
      } else {
        if (data && data.type && data.type !== 'connector') {
          docs = await findDocs([node.data('label')], this.connectors.concat(['id','path_basename_s','container_s']))
          if (docs.length > (384/8)) {
            this.$toast.open('will explode, to many objects ..<br>object:'+docs.length)
          } else {
            added = await new Promise((resolve, reject) => {
              let a = false
              cy.startBatch()
              for (let i in docs) {
                let doc = docs[i]
                if (cy.getElementById(doc.id).length === 0) {
                    if (doc.id.length > 0) cy.add({data:{id:doc.id,type:'doc',label:doc['path_basename_s'],doc:doc}})
                    cy.add({data:{source:id,target:doc.id}})
                    a = true
                }
              }
              cy.endBatch()
              resolve(a)
            })
          }
        }
      }
      if (added) {
        let layout = this.cy.makeLayout(this.layout);
        layout.run();
      }
      this.highlightNode(node)
      this.loading = false
    },
    searchbarNode (node) {
    console.log('searchbarNode')
    let label = node.data('label')
    // TODO find a better way to change user query
    this.$parent.$parent.userQuery += ' ' + label

    },
    exportNodeJson: function(node) {
      console.log('exportNodeJson')
      let filename = `${node.data('id')}.json`
      let filecontent = JSON.stringify(node.data(),null,4)
      this.$modal.open(`${filename}<hr><pre>${filecontent}</pre>`)
      //this.download(filename, filecontent, "data:text/plain;charset=utf-8,");
    },
    peekNodeContent: async function(node) {
      console.log('peekNodeContent')
      let data = node.data('data')

      if (data && data.doc && data.doc.id) {
        if (!data.doc.content){
          this.loading = true
          let docs = await findDocs(`id:"${data.doc.id}"`, ['id','content'])
          if (!docs || !docs[0] || !docs[0].content) {
              this.$toast.open(`no doc ${node.data('id')}`)
          } else {
            data.doc.content = docs[0].content.join('\n').replace(/(\n\n\n\n)/gm,"\n").replace(/(\n\n\n)/gm,"\n").replace(/(\n\n)/gm,"\n");
            this.$modal.open(`${data.doc.id}<hr><pre>${data.doc.content}</pre>`)
          }
          this.loading = false
        } else {
          this.$modal.open(`${data.doc.id}<hr><pre>${data.doc.content}</pre>`)
        }
      } else {
      this.$toast.open(`no doc ${node.data('id')}`)
      }
    },
    exportNodeFile: function(node) {
      console.log('exportNodeFile')
      let data = node.data('data')
      if (data && data.doc && data.doc.id && data.doc._server_) {
        let fn = (data.doc.container_s ? data.doc.container_s : data.doc.id)
        this.$dialog.confirm({        
                    message: `Download file ${fn}?`,
                    onConfirm: () => {
                      window.open('files?server='+data.doc._server_+'&file='+encodeURIComponent(fn), '_blank');
                    }
                })
      } else {
        this.$toast.open('sorry, no file')
      }
    },
    // context menu items for core
    centerOnGraph: function() {
      this.cy.center(this.cy.getElementById(this.root));
      this.cy.zoom(this.initialZoom);
      this.highlightNode(this.cy.getElementById(this.root))
    },
    reDrawGraph: function() {
      let layout = this.cy.makeLayout(this.layout);
      layout.run();
    },
    exportGraphJson: function() {
      let json = this.cy.json();
      this.download(
        "graph.json",
        JSON.stringify(json),
        "data:text/plain;charset=utf-8,"
      );
    },
    exportGraphImage: function() {
      let png = this.cy.png();
      this.download("graph.png", png, "");
    },
    download: function(filename, text, datatype) {
      // This only works on HTML5 ready browsers
      let element = document.createElement("a");
      element.setAttribute("href", datatype + text);
      element.setAttribute("download", filename);
      element.style.display = "none";
      document.body.appendChild(element);
      element.click();
      document.body.removeChild(element);
    }
  }
}
</script>

<style>
#cy {
  background-color: yellow;
  width: 100% !important;
  height: 100% !important;
}
</style>
