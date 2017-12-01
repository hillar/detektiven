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
            queryURL : ''
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
      //   elements: [],
      //elements: [{data:{id:'a',data:{name:'kala'}}},{data:{id:'b'}},{data:{id:'c'}},{data:{id:'ab',source:'a',target:'b'}},{data:{id:'bc',source:'b',target:'c'}}],
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
    this.cy = cytoscape({
        container: document.getElementById('cy'),
        layout: this.layout,
        style: this.style
    });
    this.loading = true
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
          content: 'exportNodeJson',
          select: this.exportNodeJson
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
          content: "Center graph",
          select: this.centerOnGraph
        },
        {
          content: "Redraw graph",
          select: this.reDrawGraph
        },
        {
          content: "Get json",
          select: this.exportGraphJson
        },
        {
          content: "Get png",
          select: this.exportGraphImage
        }
      ],
      fillColor: "rgba(96, 125, 139, 0.75)"
    })

    for (let element of this.elements) {
      if (this.cy.getElementById(element.data.id).length == 0) {
          this.cy.add(element)
      } else {
        console.log('cy dublicate element',element.data.id)
      }
    }
    let layout = this.cy.makeLayout(this.layout);
    layout.run();
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
      let that = this
      this.$toast.open('expanding: '+node.data('label'))
      const axios = require('axios')
      let q_url = `${this.queryURL}"${node.data('label')}"`
      this.loading = true
      axios.get(q_url)
      .then(function(response){
        let currentID = node.data('id')
        // TODO make response.data.response.docs param
        for (let doc of response.data.response.docs) {
          if (that.cy.getElementById(doc.id).length == 0)
            // TODO make doc.id & doc.title.join param
            that.cy.add({data:{id:doc.id,label:doc.title.join(','),doc:doc}})
          if (doc.id != currentID) // do not link self
            that.cy.add({data:{source:currentID,target:doc.id}})
          for (let key of Object.keys(doc)){
            // TODO make _ss param
            if (Array.isArray(doc[key]) === true && key.indexOf('_ss')>0) {
              for (let value of doc[key]) {
                if (that.cy.getElementById(key+value).length == 0)
                  that.cy.add({data:{id:key+value,label:value}})
                that.cy.add({data:{source:doc.id,target:key+value}})
              }
            }
          }
        }
        let layout = that.cy.makeLayout(that.layout);
        layout.run();
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
    this.$toast.open(node.data('label'))
    },
    exportNodeJson: function(node) {
      this.download(
        "graph.json",
        JSON.stringify(node.data('doc')),
        "data:text/plain;charset=utf-8,"
      );
    },
    // context menu items for core
    centerOnGraph: function() {
      this.cy.center();
      this.cy.zoom(this.initialZoom);
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
