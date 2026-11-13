(function () {
  "use strict";

  var library;
  function loadPicker() {
    if (!library) {
      library = new Promise(function (resolve, reject) {
        var script = document.createElement("script");
        script.src = "https://apis.google.com/js/api.js";
        script.onload = function () {
          window.gapi.load("picker", {
            callback: resolve,
            onerror: function () { reject(new Error("Google Drive selector could not be loaded.")); },
            timeout: 15000,
            ontimeout: function () { reject(new Error("Google Drive selector timed out. Please try again.")); },
          });
        };
        script.onerror = function () { reject(new Error("Google Drive selector could not be loaded.")); };
        document.head.appendChild(script);
      }).catch(function (error) {
        library = null;
        throw error;
      });
    }
    return library;
  }

  function openPicker(config) {
    return loadPicker().then(function () {
      return new Promise(function (resolve, reject) {
        var view = new google.picker.DocsView(google.picker.ViewId.DOCS)
          .setIncludeFolders(false).setSelectFolderEnabled(false);
        var picker = new google.picker.PickerBuilder()
          .setAppId(config.app_id).setDeveloperKey(config.api_key).setOAuthToken(config.access_token)
          .setOrigin(window.location.origin).addView(view)
          .setTitle("Select one file to import into Illinois Data Bank")
          .setCallback(function (result) {
            if (result.action === google.picker.Action.PICKED) {
              picker.dispose();
              if ((result.docs[0].mimeType || "").indexOf("application/vnd.google-apps.") === 0) {
                reject(new Error("Choose an ordinary file such as a CSV, ZIP, PDF, or image. Google documents and shortcuts are not supported."));
              } else {
                resolve(result.docs[0].id);
              }
            } else if (result.action === google.picker.Action.CANCEL) {
              picker.dispose();
              resolve();
            }
          }).build();
        picker.setVisible(true);
      });
    });
  }

  window.DatabankCloudImport({ prefix: "google-drive", name: "Google Drive", openPicker: openPicker });
})();
