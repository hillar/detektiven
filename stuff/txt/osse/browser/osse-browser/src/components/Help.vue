<template>
  <div style='background-color:#b5b5b5' class="is-expanded">
  <div class="is-fluid">
      <h2>Help</h2>
      <p>
        <br>AND - ..
        <br>OR - ..
      </p>
      <p><b-icon icon="magnify"></b-icon> - click to search
      </p>
      <p><b-icon icon="settings"></b-icon> - click to set some settings
      </p>
      <p><b-icon icon="email"></b-icon> - click to subscribe
      </p>
      <p><b-icon icon="upload"></b-icon> - click to upload files
      </p>
  </div>
  </div>
</template>

<script>
export default {
  name: 'Help',
  data() {
    return {
      msg: 'Help is here ;)',
    };
  },
};
</script>
