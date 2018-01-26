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
        <div justify-content: center>
          <p v-if="message.length > 0">{{ message }}</p>
          <b-table v-if="data.length > 0"
              @dblclick="(row, index) => $modal.open(`${row.id}<hr><pre>${row.highlighted}</pre>`)"
              @details-open="openDetails"
              :data="data"
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
              :default-sort-direction="sortOrder"
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
                      {{ props.row.path_basename_s }}
                  </b-table-column>
                  <b-table-column label="content">
                      <p v-innerhtml="props.row.highlighting"></p>
                  </b-table-column>
              </template>

              <template slot="detail" slot-scope="props" :nodes="nodes" >

                <!--
                <d3-network :net-nodes="currentNodes" :net-links="currentLinks" :options="options" @node-click="nodeClick"> </d3-network>
                -->
                <div style="height:600px">
                  <cytoscape :elements="currentEles" :queryURL="queryURL" :peekURL="peekURL" :fieldFilter="fieldFilter"></cytoscape>
                </div>
              </template>

              <template slot="bottom-left">
                  &nbsp;<b>Total found</b>: {{ total }}
              </template>

          </b-table>
        </div>
</section>
</template>

<script>

import Help from '@/components/Help'
import Upload from '@/components/Upload'
import Subcribe from '@/components/Subcribe'
import axios from 'axios'

export default {
    data() {
        return {
            message: "do some search ..",
            isAndOr: "AND",
            userQuery: "",
            data: [],
            sortOrder: "desc",
            sortField: "score",
            total: 0,
            page: 1,
            perPage: 10,
            fragSize: 1024
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
        settingsDialog(){},
        openDetails(){

        },
        search(){
          this.message = ""
          if (this.userQuery.length > 0){
            let that = this
            that.loading = true
            this.data = []
            this.total = 0
            let start = (this.page - 1) * this.perPage
            let sort = `sort=${this.sortField}%20${this.sortOrder}`
            let op = `q.op=${this.isAndOr}`
            let fl = 'fl=id,score,path_basename_s,file_modified_dt'
            //let fl = 'fl=*,score,content:[value v=""]'
            let hl = `hl=on&hl.fl=content&hl.fragsize=${this.fragSize}&hl.encoder=html&hl.snippets=100`
            let q_url = `/solr/core1/select?${fl}&q=${this.userQuery}&${op}&wt=json&start=${start}&rows=${this.perPage}&${sort}&${hl}`
            console.log(q_url)
            axios.get(q_url)
            .then(function (res) {
              if (res.data ) {
                if (res.data.response){
                  if (res.data.response.numFound != undefined) {
                    if (res.data.response.start != undefined){
                      if (res.data.response.docs && res.data.response.docs.length > 0){
                        that.total = res.data.response.numFound
                        res.data.response.docs.forEach((item) => {
                          if (res.data.highlighting && res.data.highlighting[item.id] && res.data.highlighting[item.id].content){
                            item.highlighting = res.data.highlighting[item.id].content.join('<br>')
                          } else {
                            item.highlighting = "no highlighting"
                          }
                          that.data.push(item)
                          console.dir(item)
                        })
                      } else {
                        that.message = that.userQuery +" <- no results ;("
                      }
                    }
                  }
                }
              }
              that.loading = false
            })
            .catch(function (err) {
              console.error(err.message)
              that.$snackbar.open('contact your admin:'+err.message)
            })
            .then(function() {
              that.loading = false
            })
          } else {
            this.message = "can not search on empty string ;("
          }
        }, // end search
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
    }
}
</script>

<style>
  em {background: #ff0;}
</style>
