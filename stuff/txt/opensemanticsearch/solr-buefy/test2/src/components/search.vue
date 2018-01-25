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
          <p v-if="data.length === 0">input some search strings and press enter ;)</p>
          <b-table v-if="data.length > 0"
              @dblclick="(row, index) => $modal.open(`${row.id}<hr><pre>${row.highlighted}</pre>`)"
              @details-open="connected"
              @add2filter="addtoquery"
              :data="data"
              :nodes="currentNodes"
              :links="currentLinks"
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
              :default-sort-direction="defaultSortOrder"
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
                      {{ props.row.name }}
                  </b-table-column>
                  <b-table-column label="content">
                      <p v-innerhtml="props.row.truncated"></p>
                  </b-table-column>
              </template>

              <template slot="detail" slot-scope="props" :nodes="nodes" >

                <!--
                <d3-network :net-nodes="currentNodes" :net-links="currentLinks" :options="options" @node-click="nodeClick"> </d3-network>
                -->
                <div style="height:600px">
                <cytoscape :elements="currentEles" :queryURL="queryURL" :peekURL="peekURL" :fieldFilter="fieldFilter"></cytoscape>

                <button class="button block" @click="isMeta = !isMeta">Meta</button>
                <b-message :title="`${props.row.id}`" :active.sync="isMeta">
                    {{ props.row.json }}
                </b-message>
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

export default {
    data() {
        return {
            isAndOr: "AND",
            userQuery: "",
            data: []
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
        search(){}

    }
}
</script>
