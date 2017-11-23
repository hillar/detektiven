<template>
    <section>

      <p v-model="total" align="left"> found: {{ total}}  </p>

      <b-field grouped>
        <p class="control">
        <b-switch grouped v-model="isAndOr"
                  @input = "loadAsyncData()"
                  true-value="AND"
                  false-value="OR">
                  {{ isAndOr }}
        </b-switch>
      </p>
        <b-input grouped placeholder="Search..."
            v-model="userQuery"
            @keyup.native.enter = "test()"
            type="search"
            icon="search">
        </b-input>
      </b-field>
      <hr>
        <b-table
            @dblclick="(row, index) => $modal.open(`${row.id}<hr><pre>${row.highlighted}</pre>`)"
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
              <b-table-column field="file_modified_dt" label="lastupdate" sortable centered>
                  {{ props.row.file_modified_dt ? new Date(props.row.file_modified_dt).toLocaleDateString() : '' }}
              </b-table-column>
                <b-table-column field="path_basename_s" label="Name" sortable>
                    {{ props.row.path_basename_s }}
                </b-table-column>
                <b-table-column label="content">
                    <p v-innerhtml="props.row.truncated"></p>
                </b-table-column>
            </template>
            <template slot="detail" slot-scope="props">
              <strong>{{ props.row.id }} </strong>
              <hr>
              <pre v-innerhtml="props.row.highlighted"></pre>
            </template>

        </b-table>
    </section>
</template>

<script>
    export default {
        data() {
            return {
                userQuery: 'laeva kapten',
                isAndOr: 'AND',
                data: [],
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
              console.dir(this.userQuery)
              if (!this.userQuery == "") {
                this.$toast.open({
                    message: `searching for: ${this.userQuery}`,
                    type: 'is-success'
                })
                this.loadAsyncData()
              }
            },
            test2 (){
              console.dir(this)
              if (!this.userQuery == "") {
                this.$toast.open({
                    message: `test2 ${this.userQuery}`,
                    type: 'is-success'
                })

              }
            },

            loadAsyncData() {

                this.loading = true
                let start = (this.page - 1) * this.perPage
                let rows = this.perPage
                let fragsize = this.fragsize
                let sort = `${this.sortField}%20${this.sortOrder}`
                let pre = "hl.tag.pre=<highlighted>"
                let post = ""
                let op = `q.op=${this.isAndOr}`
                let fl = 'fl=id,file_modified_dt,path_basename_s'
                let hl = `on&hl.fl=content&hl.fragsize=${fragsize}&hl.encoder=html&hl.snippets=100`
                let q_url = `https://192.168.11.2/solr/core1/select?${fl}&q=${this.userQuery}&${op}&wt=json&start=${start}&rows=${rows}&sort=${sort}&hl=${hl}`
                console.log(q_url)
                this.$http.get(q_url)
                    .then(({ data }) => {
                        this.data = []
                        let currentTotal = data.response.numFound
                        this.total = currentTotal
                        data.response.docs.forEach((item) => {
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
                this.$toast.open({
                    message: `going to page ${page} `,
                    type: 'is-success'
                })
                this.loadAsyncData()
            },

            onSort(field, order) {
                this.sortField = field
                this.sortOrder = order
                this.$toast.open({
                    message: `sorting on ${field} ${order}`,
                    type: 'is-success'
                })
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
</style>
