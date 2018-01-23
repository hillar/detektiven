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
