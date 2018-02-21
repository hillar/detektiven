<template>
  <div id="cy" ref="cy" class="b-table" :class="{ 'is-loading': loading }"></div>
</template>

<script>
import cytoscape from 'cytoscape'
import Weaver from "weaverjs";
import cxtmenu from 'cytoscape-cxtmenu'
import axios from 'axios'
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
  console.log((!q),q,f)
  return new Promise((resolve, reject) => {
    if (!q) resolve([])
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
          }
        }
      }
    })
    .catch(function (err) {
      console.error(err.message)
      resolve([])
    })
  })
}

async function addElements(cy,docs,fields){
  return new Promise((resolve, reject) => {
    let label = 'path_basename_s'
    for (let i in docs) {
      let doc = docs[i]
      if (cy.getElementById(doc.id).length == 0) {
          if (doc.id.length > 0) cy.add({data:{id:doc.id,label:doc[label],doc:doc}})
      }
      let connectors = []
      for (let i in fields) {
        let f = fields[i]
        if (doc[f]) {
          if (Array.isArray(doc[f])) {
            for (let j in doc[f]){
              if (doc[f][j].length > 0) connectors.push(doc[f][j])
            }
          } else {
            if (doc[f].length > 0) connectors.push(doc[f])
          }
        }
      }
      for (let i in connectors){
        let c = connectors[i]
        if (cy.getElementById(c).length == 0) {
          cy.add({data:{id:c,label:c}})
        }
        cy.add({data:{source:c,target:doc.id}})
      }
    }
    resolve(true)
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
               selector: 'edge',
               style: {
                 'width': 1,
                 'line-color': '#ccc',
                 'target-arrow-color': '#ccc',
                 'target-arrow-shape': 'triangle'
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
          content: "<h1 style='color:blue'>?</h1>",
          select: this.searchbarNode
        },
        {
          content: "<h1 style='color:yellow'>*</h1>",
          select: this.highlightNode
        },
        {
          content: "<h1 style='color:green'>+</h1>",
          select: this.expandNode
        },
        {
          content: "<h1 style='color:red'>-</h1>",
          select: this.removeNode
        },
        {
          content: 'meta',
          select: this.exportNodeJson
        },
        {
          content: 'peek',
          select: this.peekNodeContent
        },
        {
          content: 'export',
          select: this.exportNodeFile
        }
      ],
      fillColor: "rgba(96, 125, 139, 0.75)"
    })

    this.cy.cxtmenu({
      selector: "core",
      commands: [
        {
          content: "Clear highlights",
          select: this.clearHighlights
        },
        {
          content: "Highlight root",
          select: this.centerOnGraph
        },
        {
          content: "Redraw",
          select: this.reDrawGraph
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
      let docs = await findDocs(`id:"${root.id}"`, this.connectors.concat(['id','path_basename_s']))
      await addElements(this.cy, docs, this.connectors, 'path_basename_s')
      let qs = await getConnectors(docs[0],this.connectors)
      docs = await findDocs(qs.join(' OR '), this.connectors.concat(['id','path_basename_s']))
      await addElements(this.cy, docs, this.connectors, 'path_basename_s')
      let layout = this.cy.makeLayout(this.layout);
      layout.run();
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
        node.closedNeighborhood().removeClass("element-transparent");
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
      this.loading = true
      let doc = node.data('doc')
      let docs = []
      if (doc && doc.id){
        let qs = await getConnectors(doc,this.connectors)
        docs = await findDocs(qs.join(' OR '), this.connectors.concat(['id','path_basename_s']))
      } else {
        docs = await findDocs([node.data('label')], this.connectors.concat(['id','path_basename_s']))
      }
      await addElements(this.cy,docs,this.connectors)
      let layout = this.cy.makeLayout(this.layout);
      layout.run();
      this.highlightNode(node)
      this.loading = false
    },
    searchbarNode (node) {
    console.log('searchbarNode')
    let label = node.data('label')
    // TODO find a better way to emit
    this.$parent.$emit('add2filter',label)
    },
    exportNodeJson: function(node) {
      console.log('exportNodeJson')
      let filename = `${node.data('id')}.json`
      let filecontent = JSON.stringify(node.data(),null,4)
      this.$modal.open(`${filename}<hr><pre>${filecontent}</pre>`)
      //this.download(filename, filecontent, "data:text/plain;charset=utf-8,");
    },
    peekNodeContent: async function(node) {
      //console.log('peekNodeContent')
      let doc = node.data('doc')
      if (doc && doc.id) {
        if (!doc.content){
          this.loading = true
          let docs = await findDocs(`id:"${doc.id}"`, ['id','content'])
          doc.content = docs[0].content.join('\n').replace(/(\n\n\n\n)/gm,"\n").replace(/(\n\n\n)/gm,"\n").replace(/(\n\n)/gm,"\n");
          this.loading = false
          this.$modal.open(`${doc.id}<hr><pre>${doc.content}</pre>`)
        } else {
          this.$modal.open(`${doc.id}<hr><pre>${doc.content}</pre>`)
        }
      } else {
      this.$toast.open(`no doc ${node.data('id')}`)
      }
    },
    exportNodeFile: function(node) {
      console.log('exportNodeFile')
      let filename = node.data('filename')
      if (filename ) {
      this.$dialog.confirm({
                    message: `Download file ${filename}?`,
                    onConfirm: () => this.$toast.open('User confirmed')
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
