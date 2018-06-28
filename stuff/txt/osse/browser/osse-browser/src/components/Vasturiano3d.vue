<template>
  <div id="v3" ref="v3" class="b-table" :class="{ 'is-loading': loading }"></div>
</template>

<script>
console.log('vvvv')
import axios from 'axios'
import ForceGraph3D from '3d-force-graph'
import * as THREE from 'three'
class SpriteText extends THREE.Sprite {
  constructor(text = '', textHeight = 10, color = 'rgba(255, 255, 255, 1)') {
    super(new THREE.SpriteMaterial({ map: new THREE.Texture() }));

    this._text = text;
    this._textHeight = textHeight;
    this._color = color;

    this._fontFace = 'Arial';
    this._fontSize = 90; // defines text resolution

    this._canvas = document.createElement('canvas');
    this._texture = this.material.map;
    this._texture.minFilter = THREE.LinearFilter;

    this._genCanvas();
  }

  get text() { return this._text; }
  set text(text) { this._text = text; this._genCanvas(); }
  get textHeight() { return this._textHeight; }
  set textHeight(textHeight) { this._textHeight = textHeight; this._genCanvas(); }
  get color() { return this._color; }
  set color(color) { this._color = color; this._genCanvas(); }
  get fontFace() { return this._fontFace; }
  set fontFace(fontFace) { this._fontFace = fontFace; this._genCanvas(); }
  get fontSize() { return this._fontSize; }
  set fontSize(fontSize) { this._fontSize = fontSize; this._genCanvas(); }

  _genCanvas() {
    const canvas = this._canvas;
    const ctx = canvas.getContext('2d');

    const font = `normal ${this.fontSize}px ${this.fontFace}`;

    ctx.font = font;
    const textWidth = ctx.measureText(this.text).width;
    canvas.width = textWidth;
    canvas.height = this.fontSize;

    ctx.font = font;
    ctx.fillStyle = this.color;
    ctx.textBaseline = 'bottom';
    ctx.fillText(this.text, 0, canvas.height);

    // Inject canvas into sprite
    this._texture.image = canvas;
    this._texture.needsUpdate = true;

    this.scale.set(this.textHeight * canvas.width / canvas.height, this.textHeight);
  }

  clone() {
    return new this.constructor(this.text, this.textHeight, this.color).copy(this);
  }

  copy(source) {
    THREE.Sprite.prototype.copy.call(this, source);

    this.color = source.color;
    this.fontFace = source.fontFace;
    this.fontSize = source.fontSize;

    return this;
  }
}

async function getConnectors(doc,fields){
  return new Promise((resolve, reject) => {
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
	  resolve(connectors);
	})
}

async function findDocs(q,rows){
  return new Promise((resolve, reject) => {
    if (!q) resolve(false)
    if (!rows) rows = 128
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
  name: 'v3',
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
    async expandNode(graph,id,data){
        console.log('expandNode',id,data)
        return new Promise(async (resolve, reject) => {
          if (data) {
          this.loading = true
          let qs = await getConnectors(data,this.connectors.concat(['aliases','alias_for']))
          for (const q of qs ) {
            const docs = await findDocs(q)
            console.log('docs',q,docs.length)
            const { nodes, links } = graph.graphData()
            graph.graphData({
              nodes: [...nodes, { id:q,color:"blue" }],
              links: [...links, { source: id, target: q }]
            })
            for (const doc of docs) {
              //graph.addNode(doc.id,doc)
              //graph.addLink(q,doc.id)
              const { nodes, links } = graph.graphData()
              graph.graphData({
                nodes: [...nodes, { id:doc.id,color:"yellow",doc:doc }],
                links: [...links, { source: q, target: doc.id }]
              })
            }
            //graph.endUpdate();
          }
          this.loading = false
          }
          resolve(true)
        })
    },
    async _mounted() {
      console.log('mounting v3..')
      if (! this.thing.id) {
        return
      }

      let root = await findDocs(`id:${this.thing.id}`)
      console.log(root[0])
      //nodes.push({id:this.thing.id,color:"red",nodeLabel:'root',doc:root[0]})
      //graph.addNode(this.thing.id,{id:this.thing.id, __size__:10, __color__:0xff0000,data:root[0]})

      const graph = ForceGraph3D()(document.getElementById('v3'))
        .enableNodeDrag(false)
        .forceEngine('ngraph')
        //.onNodeHover(node => {elem.style.cursor = node ? 'pointer' : null})
        .nodeColor(node => {return node.color})
        .onNodeClick(node => {this.expandNode(graph,node.id,node.doc)})
        .nodeThreeObject(node => {
          if (! node.doc) {
          const sprite = new SpriteText(node.id);
          sprite.color = node.color;
          sprite.textHeight = 6;
          return sprite;
        } else return false
        })
        .graphData({nodes:[{id:this.thing.id,color:"red",nodeLabel:'root',doc:root[0]}],links:[]});
      await this.expandNode(graph,this.thing.id,root[0])
      /*
      let { nodes, links } = graph.graphData()
      let ul = {}
      for (const link of links) {
          if (! ul[link.target]) ul[link.target] = 0
          ul[link.target] ++
      }
      for (const key of Object.keys(ul)){
        if (ul[key]>0) {
          console.log(key)
          //function findFirstLargeNumber(element) {return element.id === k}
          const n = nodes.findIndex((e) => {return e.id === key})
          //console.log('start expand',key,n,nodes)
          await this.expandNode(graph,key,nodes[n].doc)
        }
      }
      console.log('links',ul)
      */
      this.loading = false
    }
  },
  async mounted() { this._mounted()}
};
</script>

<style>
#v3 {

  width: 100% !important;
  height: 100% !important;
}
</style>
