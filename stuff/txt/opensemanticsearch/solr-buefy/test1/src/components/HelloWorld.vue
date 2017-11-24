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
                <b-table-column field="id" label="Name" sortable>
                    {{ props.row.name }}
                </b-table-column>
                <b-table-column label="content">
                    <p v-innerhtml="props.row.truncated"></p>
                </b-table-column>
            </template>

            <template slot="detail" slot-scope="props">
              <strong>{{ props.row.id }} </strong>
              <hr>
              <pre v-innerhtml="props.row.json"></pre>
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
                userQuery: 'hillar aarelaid',
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
              if (!this.userQuery == "") {
                this.$toast.open({
                    message: `searching for: ${this.userQuery}`,
                    type: 'is-success'
                })
                this.loadAsyncData()
              }
            },
            letsFlip: function(item){
              console.log('flipping')
            },

            loadAsyncData() {
                this.loading = true
                let start = (this.page - 1) * this.perPage
                let rows = this.perPage
                let fragsize = this.fragsize
                let sort = `${this.sortField}%20${this.sortOrder}`
                let op = `q.op=${this.isAndOr}`
                //let fl = 'fl=id,file_modified_dt'
                let fl = this.$solr_fields2get.join(',')
                //this.$toast.open(this.$solr_fields2get.join(','))
                let pre = "hl.tag.pre=<highlighted>"
                let post = "hl.tag.post=</highlighted>"
                let hl = `on&hl.fl=content&hl.fragsize=${fragsize}&hl.encoder=html&hl.snippets=1`
                let q_url = `${this.$solr_server}/solr/core1/select?${fl}&q=${this.userQuery}&${op}&wt=json&start=${start}&rows=${rows}&sort=${sort}&hl=${hl}`
                this.$http.get(q_url)
                    .then(({ data }) => {
                        this.data = []
                        let currentTotal = data.response.numFound
                        this.total = currentTotal
                        data.response.docs.forEach((item) => {
                          Object.keys(item).forEach((k) => {
                            console.log(k,(item[k] === true))
                            // delete all etl_* 
                            if (item[k] === true) delete(item[k])
                          })
                          item.name = item.id.substring(7,17)+'..'+item.id.substring(item.id.length-16)
                          if (data.highlighting) {
                            if (data.highlighting[item.id]) {
                              if (data.highlighting[item.id].content) {
                                item.highlighted =  data.highlighting[item.id].content[0].replace(/\n\n\n\n/g, "");
                                item.truncated = this.truncate(item.highlighted || '', fragsize)
                              }
                            }
                          }
                          item.json = JSON.stringify(item,null,4)
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
