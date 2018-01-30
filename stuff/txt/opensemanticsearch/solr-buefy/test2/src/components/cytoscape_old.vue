<!--
<cytoscape :elements="eles" :queryURL="queryURL"></cytoscape>

data() {
          return {
            eles:  this.$demodata,
            queryURL : queryURL,
            ..
          }
-->
<template>
  <!-- b-table && are from buefy -->
  <div id="cy" ref="cy" class="b-table" :class="{ 'is-loading': loading }"></div>
</template>

<script>
import cytoscape from 'cytoscape'
import Weaver from "weaverjs";
import cxtmenu from 'cytoscape-cxtmenu'
import 'mdi/css/materialdesignicons.css'
cxtmenu(cytoscape)
export default {
  name: 'cytoscape',
  props: {
            elements: {
                type: Array,
                default: () => []
            },
            queryURL : '',
            peekURL : '',
            fieldFilter: ''
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
    console.dir(this.elements)
    if (this.elements && this.elements.length > 0) {
      for (let element of this.elements) {
        if (element && element.data && (element.data.id||(element.data.source && element.data.target))) {
          if (this.cy.getElementById(element.data.id).length == 0) {
              this.cy.add(element)
          } else {
            console.log('cy dublicate element',element.data.id)
          }
        } else {
          console.error('not a element')
          this.$snackbar.open('contact your admin, graph is broken: '+JSON.stringify(element))
        }
      }
    } else {
      console.log('no elements')
      this.$toast.open('empty graph')
    }
    let layout = this.cy.makeLayout(this.layout);
    layout.run();
    // find root & highlight it
    this.highlightNode(this.cy.getElementById('root'))
    this.loading = false
  },
  methods: {
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
      console.log('highlightNode')
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
    expandNode(node) {
      console.log('expandNode')
      let filter = `"${node.data('label')}"`
      let fieldFilter = this.fieldFilter
      let that = this
      let doc = node.data('doc')
      if (doc && doc.id) {
        let fields = []
        for (let key of Object.keys(doc)){

          if (Array.isArray(doc[key]) === true && key.indexOf(fieldFilter)>0) {
            console.log(key,fieldFilter)
            for (let value of doc[key]) {
                fields.push(`"${value}"`)
            }
          }
        }
        if (fields.length > 0) {
          if (fields.length < 64) {
            filter = fields.join(' AND ')
          } else {
            this.$toast.open(filter+' will explode, not doing ', + fields.length)
            return
          }
        } else {
          this.$toast.open(filter+' nothing to expand on ;(')
          return
        }
      }
      console.log('expandNode',filter)
      this.$toast.open('expanding: '+node.data('label'))
      const axios = require('axios')
      let q_url = `${this.queryURL}${filter}`
      this.loading = true
      console.log('expanding node',node.data('label'),q_url)
      axios.get(q_url)
      .then(function(response){
        if (response.status == 200) {
        console.log('found',response.data.response.numFound)
        console.log('got',response.data.responseHeader.params.rows)
        if (response.data.responseHeader.params.rows && response.data.response.numFound > response.data.responseHeader.params.rows){
          let notshowing = response.data.response.numFound - response.data.responseHeader.params.rows
          console.log('not showing',notshowing)
          that.$toast.open('to many results, not showing '+notshowing)
        }
        let currentID = node.data('id')
        let addedNodes = 0
        let addedEdges = 0
        // TODO make response.data.response.docs param
        for (let doc of response.data.response.docs) {
          if (that.cy.getElementById(doc.id).length == 0) {
            // TODO make doc.id & doc.title.join param
            addedNodes ++
            that.cy.add({data:{id:doc.id,label:doc.title.join(','),doc:doc}})
          }
          if (doc.id != currentID) { // do not link self
            that.cy.add({data:{source:currentID,target:doc.id}})
            addedEdges ++
          }
          for (let key of Object.keys(doc)){
            if (Array.isArray(doc[key]) === true && key.indexOf(fieldFilter)>0) {
              for (let value of doc[key]) {
                if (that.cy.getElementById(value).length == 0) {
                  // TODO fix exlosion ;(
                  //that.cy.add({data:{id:value,label:value}})
                  // that.cy.add({data:{source:doc.id,target:value}})
                  addedNodes ++
                  addedEdges ++
                } else {
                that.cy.add({data:{source:doc.id,target:value}})
                addedEdges ++
                }
              }
            }
          }
        }
        console.log('new nodes',addedNodes,'edges',addedEdges)
        //let layoutstart = Date.now()
        let layout = that.cy.makeLayout(that.layout);
        layout.run();
        //console.log('layout took', Date.now() - layoutstart)
        that.highlightNode(node)
      } else {
        that.$snackbar.open('contact your admin:'+response.status)
      }
        that.loading = false
      })
      .catch(function(error) {
        that.loading = false
        console.error(error);
        that.$snackbar.open('contact your admin:'+error.message)
      })
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
    peekNodeContent:function(node) {
      //console.log('peekNodeContent')
      let doc = node.data('doc')
      if (doc && doc.id) {
        this.loading = false
        let that = this
        let q_url = `${this.peekURL}"${doc.id}"`
        console.log('peek',q_url)
        const axios = require('axios')
        this.loading = true
        axios.get(q_url)
        .then(function(response){
          let currentID = node.data('id')
          // TODO make response.data.response.docs param
          for (let doc of response.data.response.docs) {
                    //.replace(/\n\n\n\n/g, "")
                    let content = doc.content.join('\n') //
                    content = content.replace(/\n\n/g, "\n")
                    that.loading = false
                    that.$modal.open(`${doc.id}<hr><pre>${content}</pre>`)
          }
        })
        .catch(function(error) {
          that.loading = false
          console.error(error);
          that.$snackbar.open('contact your admin:'+error.message)
        })

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
      this.cy.center(this.cy.getElementById('root'));
      this.cy.zoom(this.initialZoom);
      this.highlightNode(this.cy.getElementById('root'))
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
