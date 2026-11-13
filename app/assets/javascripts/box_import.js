(function () {
  "use strict";

  var library;

  function loadPicker() {
    if (!library) {
      library = Promise.all([
        loadAsset("link", {
          rel: "stylesheet",
          href: "https://cdn01.boxcdn.net/platform/elements/26.3.0/en-US/picker.css",
        }),
        loadAsset("script", {
          src: "https://cdn01.boxcdn.net/platform/elements/26.3.0/en-US/picker.js",
        }),
      ]).catch(function (error) {
        library = null;
        throw error;
      });
    }
    return library;
  }

  function loadAsset(tag, attributes) {
    return new Promise(function (resolve, reject) {
      var asset = document.createElement(tag);
      Object.keys(attributes).forEach(function (key) { asset[key] = attributes[key]; });
      var timer = window.setTimeout(function () {
        asset.remove();
        reject(new Error("The Box selector timed out. Please try again."));
      }, 15000);
      asset.onload = function () { window.clearTimeout(timer); resolve(); };
      asset.onerror = function () {
        window.clearTimeout(timer);
        asset.remove();
        reject(new Error("The Box selector could not be loaded. Please try again."));
      };
      document.head.appendChild(asset);
    });
  }

  function openPicker(config) {
    return loadPicker().then(function () {
      return new Promise(function (resolve, reject) {
        var dialog = document.getElementById("box-picker-dialog");
        var cancel = document.getElementById("box-picker-cancel");
        var picker = new Box.FilePicker();
        function finish(fileId, error) {
          picker.hide();
          dialog.close();
          dialog.removeEventListener("cancel", onCancel);
          cancel.removeEventListener("click", onCancel);
          if (error) { reject(error); } else { resolve(fileId); }
        }
        function onCancel(event) {
          if (event && typeof event.preventDefault === "function") { event.preventDefault(); }
          finish();
        }
        picker.addListener("choose", function (files) {
          if (files.length !== 1 || files[0].type !== "file") {
            finish(null, new Error("Choose one ordinary Box file. Folders and links are not supported."));
            return;
          }
          finish(files[0].id);
        });
        picker.addListener("cancel", onCancel);
        dialog.addEventListener("cancel", onCancel);
        cancel.addEventListener("click", onCancel);
        dialog.showModal();
        document.getElementById("box-picker-title").focus();
        try {
          picker.show("0", config.access_token, {
            container: "#box-picker-container", maxSelectable: 1, autoFocus: true,
            canUpload: false, canSetShareAccess: false, canCreateNewFolder: false,
          });
        } catch (error) {
          finish(null, new Error("The Box selector could not be opened. Please try again."));
        }
      });
    });
  }

  window.DatabankCloudImport({ prefix: "box", name: "Box", openPicker: openPicker });
})();
