<template>
    <section>
    <div class="is-fullwidth" style='background-color:white'>
      <b-field label="Add some tags" class="is-fluid is-expanded">
       <b-taginput
           v-model="tagsList"
           icon="label"
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
                filesList: []
            }
        },
        methods: {
            doNotUploadThatFile(index) {
                console.log('doNotUploadThatFile')
                this.filesList.splice(index, 1)
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
                    data.append('file', file);
                    axios.put("/files",data)
                      .then(function (res) {
                        console.log('uploaded',file.name,file.size)
                        if (res.data.length > 0) {
                          console.log(file.name,'server returned:',res.data)
                        }
                        resolve(file.name)
                      })
                      .catch(function (err) {
                        console.error(err.message)
                        that.$snackbar.open('contact your admin:'+err.message)
                        reject()
                      });
                  })
                )
              }
              Promise.all(uploadz).then(function(filenames){
                //console.log('uploaded',JSON.stringify(filenames))
                console.log('end uploadFiles')
                that.$toast.open('uploaded '+files.length+' files<br>'+filenames.join('<br>'))
              })
              .catch(function(error) {
                console.error(error.message)
                that.$snackbar.open(err.message)
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
