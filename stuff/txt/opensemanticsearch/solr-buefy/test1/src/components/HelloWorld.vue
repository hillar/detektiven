<template>
    <section>
      <b-input placeholder="Search..."
          type="search"
          icon="search">
      </b-input>
        <b-table
            :data="data"
            :loading="loading"

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
              <!--
              <b-table-column field="content_type_group" label="type">
                      {{ props.row.content_type_group }}
              </b-table-column>
            -->
              <b-table-column field="file_modified_dt" label="lastupdate" sortable centered>
                  {{ props.row.file_modified_dt ? new Date(props.row.file_modified_dt).toLocaleDateString() : '' }}
              </b-table-column>
                <b-table-column field="w.path_basename_s" label="Name" sortable>
                    {{ props.row.path_basename_s }}
                </b-table-column>



                <b-table-column label="content" size="is-small">
                    {{ props.row.highlighting || props.row.content | truncate(80) }}
                </b-table-column>
                <!--
                <b-table-column field="datatype" label="datatype" sortable>
                        {{ props.row.id }}
                </b-table-column>
              -->
            </template>
        </b-table>
    </section>
</template>

<script>
    export default {
        data() {
            return {
                data: [],
                total: 0,
                loading: false,
                sortField: 'file_modified_dt',
                sortOrder: 'desc',
                defaultSortOrder: 'desc',
                page: 1,
                perPage: 10
            }
        },
        methods: {

            loadAsyncData() {

                this.loading = true
                let start = (this.page - 1) * 10
                let rows = 10
                let q = 'test'
                let sort = `${this.sortField}%20${this.sortOrder}`
                let q_url = `https://192.168.11.2/solr/core1/select?q=${q}&wt=json&start=${start}&rows=${rows}&sort=${sort}&hl=on&hl.fl=*&hl.fragsize=512`
                console.log(q_url)
                this.$http.get(q_url)

                    .then(({ data }) => {
                        this.data = []
                        let currentTotal = data.response.numFound
                        this.total = currentTotal
                        data.response.docs.forEach((item) => {
                          if (data.highlighting) {
                            if (data.highlighting[item.id]) {
                              //console.log(data.highlighting[item.id])
                              item.highlighting =  data.highlighting[item.id].content
                              this.data.push(item)

                            }
                          }
                        })
                        this.loading = false
                    }, response => {
                        this.data = []
                        this.total = 0
                        this.loading = false
                    })
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
        filters: {

            truncate(value, length) {
              if (!value) return 'no text ;('
              if (value[0]) value = value[0]
              if (value)  return value.length > length
                    ? value.substr(0, length) + '...'
                    : value
            }
        },
        mounted() {
            this.loadAsyncData()
        }
    }
</script>
