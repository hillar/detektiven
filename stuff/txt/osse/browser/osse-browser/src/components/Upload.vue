<template>
    <section>
    <div class="is-fullwidth" style='background-color:white'>
      <b-field label="Add some tags" class="is-fluid is-expanded">
       <b-taginput
           v-model="tagsList"
           :data="lookupTags"
           :allowNew="true"
           icon="label"
           autocomplete
           @typing="getTags"
           placeholder="Add a tag">
       </b-taginput>
     </b-field>
        <b-field label="Add some files" class="is-expanded">
            <b-upload
                v-model="filesList"
                multiple

                drag-drop>
                <section class="section">
                    <div class="content has-text-centered is-expanded">
                        <p>
                            <b-icon
                                icon="upload"
                                size="is-large">
                            </b-icon>
                        </p>
                        <p>Drop your files here or click to upload</p>
                    </div>
                </section>
            </b-upload>
        </b-field>

        <div class="tags">
            <span v-for="(file, index) in filesList"
                :key="index"
                class="tag is-primary" >
                {{file.name}}
                <button class="delete is-small"
                    type="button"
                    @click="doNotUploadThatFile(index)">
                </button>
            </span>
        </div>
        <button class="button is-success is-large"
          :disabled="filesList.length === 0"
          @click="uploadFiles(filesList,tagsList)">
        Upload now</button>
    </div>
    </section>
</template>

<script>

import axios from 'axios'
    export default {
        name: 'Upload',
        data() {
            return {
                tagsList: [],
                lookupTags: [],
                filesList: []
            }
        },
        methods: {
            doNotUploadThatFile(index) {
                console.log('doNotUploadThatFile')
                this.filesList.splice(index, 1)
            },
            getTags(text) {
                if (text.length > 0) {
                  this.lookupTags = []
                  this.isFetching = true
                  axios.get(`/select?wt=json&fl=upload_tags&rows=1024&q=upload_tags:*${text}*`)
                      .then(({ data }) => {
                          if (data.response && data.response.numFound && data.response.numFound > 0) {
                            if (data.response.docs) {
                              for (const doc of data.response.docs) {
                                for (const tag of doc.upload_tags){
                                  if (this.lookupTags.indexOf(tag) === -1) this.lookupTags.push(tag)
                                }
                              }
                            }
                          }
                          this.isFetching = false
                      })
                      .catch((error) => {
                          this.isFetching = false
                          console.error(error)
                    })
                }

            },
            uploadFiles(files,tags) {
              const loadingComponent = this.$loading.open()
              let that = this
              console.log('start uploadFiles')
              // calc total size & prep uploads
              let sizeTotal = 0
              let uploadz = []
              for (var i = 0; i < files.length; i++) {
                let file = files[i];
                sizeTotal += file.size
                uploadz.push(
                  new Promise((resolve,reject)=>{
                    let data = new FormData();
                    data.append('tags', tags);
                    data.append('lastModified',file.lastModified)
                    data.append('size',file.size)
                    data.append('type',file.type)
                    data.append('filename',file.name)
                    data.append('file', file)
                    axios.put("/files",data)
                      .then(function (res) {
                        console.log('uploaded',file.name,file.size)
                        if (res.data && res.data.error) {
                          //that.$toast.open(`${file.name} : ${res.data.error}`)
                        }
                        resolve({filename:file.name,server:res.data})
                      })
                      .catch(function (err) {
                        console.error(err.message)
                        that.$snackbar.open('contact your admin:'+err.message)
                        reject(err)
                      });
                  })
                )
              }
              Promise.all(uploadz)
              .then(function(filenames){
                let uploadErrors = []
                let uploads = []
                for (const file of filenames) {
                  if (file.server && file.server.error) {
                    uploadErrors.push(file.filename+' : '+file.server.error)
                  } else {
                    uploads.push(file.filename)
                  }
                }
                that.$dialog.alert({message:'uploaded OK '+uploads.length+' files<br>'+uploads.join('<br>')+'<p>upload ERRORS '+uploadErrors.length+' files<br>'+uploadErrors.join('<br>')})
              })
              .catch(function(error) {
                if (error) that.$snackbar.open(error.message)
              })
              .then(function() {
                that.tagsList = []
                that.filesList = []
                loadingComponent.close()
                //that.$parent.close()
              })
            }
        }
    }
</script>
