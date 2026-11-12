(function () {
  "use strict";

  var pickerLibrary;
  var pollTimer;
  var authorizationWindow;
  var selectionId;

  function loadPicker() {
    if (!pickerLibrary) {
      pickerLibrary = new Promise(function (resolve, reject) {
        var script = document.createElement("script");
        script.src = "https://apis.google.com/js/api.js";
        script.onload = function () {
          window.gapi.load("picker", {
            callback: resolve,
            onerror: function () { reject(new Error("Google Drive selector could not be loaded.")); },
            timeout: 15000,
            ontimeout: function () { reject(new Error("Google Drive selector timed out. Please try again.")); }
          });
        };
        script.onerror = function () { reject(new Error("Google Drive selector could not be loaded.")); };
        document.head.appendChild(script);
      }).catch(function (error) {
        pickerLibrary = null;
        throw error;
      });
    }
    return pickerLibrary;
  }

  function request(url, method, data) {
    return new Promise(function (resolve, reject) {
      jQuery.ajax({
        url: url,
        type: method || "GET",
        data: data,
        dataType: "json",
        headers: { "X-CSRF-Token": jQuery('meta[name="csrf-token"]').attr("content") },
        success: resolve,
        error: function (xhr) {
          reject(new Error((xhr.responseJSON && xhr.responseJSON.error) ||
            "The Google Drive request failed. Please try again or contact the Research Data Service."));
        }
      });
    });
  }

  function showError(error) {
    jQuery("#google-drive-error").text(error.message);
    jQuery('[data-dataset-action="import-google-drive"]').prop("disabled", false).trigger("focus");
  }

  function basePath() {
    return jQuery("#google-drive-imports").data("base-path");
  }

  function showPicker() {
    return Promise.all([loadPicker(), request(basePath() + "/picker")]).then(function (results) {
      var config = results[1];
      var view = new google.picker.DocsView(google.picker.ViewId.DOCS)
        .setIncludeFolders(false)
        .setSelectFolderEnabled(false);
      var picker = new google.picker.PickerBuilder()
        .setAppId(config.app_id)
        .setDeveloperKey(config.api_key)
        .setOAuthToken(config.access_token)
        .setOrigin(window.location.origin)
        .addView(view)
        .setTitle("Select one file to import into Illinois Data Bank")
        .setCallback(function (result) {
          if (result.action === google.picker.Action.PICKED) {
            if ((result.docs[0].mimeType || "").indexOf("application/vnd.google-apps.") === 0) {
              picker.dispose();
              showError(new Error("Choose an ordinary file such as a CSV, ZIP, PDF, or image. Google documents and shortcuts are not supported."));
              return;
            }
            request(basePath() + "/preview", "POST", { file_id: result.docs[0].id }).then(function (file) {
              selectionId = file.selection_id;
              jQuery("#google-drive-selected-name").text(file.name);
              jQuery("#google-drive-selected-size").text(file.size.toLocaleString() + " bytes");
              var dialog = document.getElementById("google-drive-confirmation");
              dialog.showModal();
              document.getElementById("google-drive-confirm").focus();
            }).catch(showError);
          }
          if (result.action === google.picker.Action.PICKED || result.action === google.picker.Action.CANCEL) {
            picker.dispose();
            if (result.action === google.picker.Action.CANCEL) {
              request(basePath() + "/authorization", "DELETE").catch(showError);
              jQuery('[data-dataset-action="import-google-drive"]').prop("disabled", false).trigger("focus");
            }
          }
        })
        .build();
      picker.setVisible(true);
    });
  }

  function renderImports(imports) {
    var list = jQuery("#google-drive-import-list");
    // Avoid replacing focused controls or repeating unchanged live announcements.
    var snapshot = JSON.stringify(imports);
    if (list.data("snapshot") === snapshot) { return; }
    list.data("snapshot", snapshot);
    var focusedId = document.activeElement && document.activeElement.id;
    list.empty();
    imports.forEach(function (item) {
      var row = jQuery("<li>");
      row.append(jQuery("<span>").text(item.name + ": " + item.status + ". "));
      if (item.status === "queued" || item.status === "importing") {
        row.append(jQuery("<progress>").attr({
          max: item.size, value: item.bytes_downloaded, "aria-label": "Download progress for " + item.name
        }));
        row.append(document.createTextNode(" " + item.bytes_downloaded.toLocaleString() +
          " of " + item.size.toLocaleString() + " bytes downloaded. "));
        row.append(jQuery("<button>", {
          type: "button", id: "cancel-drive-import-" + item.id,
          "class": "btn btn-default btn-sm", text: "Cancel",
          "aria-label": "Cancel import of " + item.name
        }).on("click", function () {
          request(basePath() + "/imports/" + item.id, "DELETE").then(function () {
            jQuery('[data-dataset-action="import-google-drive"]').trigger("focus");
            refreshImports();
          }).catch(showError);
        }));
      }
      if (item.error) { row.append(jQuery("<span>").text(" " + item.error)); }
      if (item.status === "complete") {
        row.append(jQuery("<a>", {
          href: window.location.pathname, text: "Reload the page to show the imported file"
        }));
      }
      list.append(row);
    });
    if (focusedId && document.getElementById(focusedId)) {
      document.getElementById(focusedId).focus();
    }
  }

  function refreshImports() {
    window.clearTimeout(pollTimer);
    return request(basePath() + "/imports").then(function (imports) {
      renderImports(imports);
      if (imports.some(function (item) { return item.status === "queued" || item.status === "importing"; })) {
        pollTimer = window.setTimeout(refreshImports, 5000);
      }
    }).catch(function (error) {
      showError(error);
      pollTimer = window.setTimeout(refreshImports, 15000);
    });
  }

  jQuery(function () {
    var result = document.getElementById("google-drive-oauth-result");
    if (result) {
      if (window.opener && result.dataset.success === "true") {
        window.opener.postMessage({ type: "databank-google-drive-authorized" }, window.location.origin);
        window.close();
      }
      return;
    }
    if (!document.getElementById("google-drive-imports")) { return; }
    refreshImports();
    jQuery(document).on("click.googleDrive", '[data-dataset-action="import-google-drive"]', function () {
      jQuery("#google-drive-error").text("");
      authorizationWindow = window.open("", "databankGoogleDrive", "popup,width=700,height=700");
      if (!authorizationWindow) {
        showError(new Error("Allow pop-up windows for this site to authorize Google Drive."));
        return;
      }
      request(basePath() + "/authorize", "POST").then(function (data) {
        authorizationWindow.location.assign(data.authorization_url);
      }).catch(function (error) {
        authorizationWindow.close();
        showError(error);
      });
    });
    window.addEventListener("message", function (event) {
      if (event.origin === window.location.origin && event.source === authorizationWindow &&
          event.data && event.data.type === "databank-google-drive-authorized") {
        authorizationWindow = null;
        showPicker().catch(showError);
      }
    });
    jQuery("#google-drive-confirm").on("click", function () {
      var button = jQuery(this).prop("disabled", true);
      request(basePath() + "/imports", "POST", { selection_id: selectionId }).then(function () {
        document.getElementById("google-drive-confirmation").close();
        jQuery('[data-dataset-action="import-google-drive"]').trigger("focus");
        refreshImports();
      }).catch(function (error) {
        document.getElementById("google-drive-confirmation").close();
        showError(error);
      }).finally(function () { button.prop("disabled", false); });
    });
    jQuery("#google-drive-dismiss").on("click", function () {
      document.getElementById("google-drive-confirmation").close();
      request(basePath() + "/authorization", "DELETE").catch(showError);
    });
    document.getElementById("google-drive-confirmation").addEventListener("cancel", function () {
      request(basePath() + "/authorization", "DELETE").catch(showError);
    });
    document.getElementById("google-drive-confirmation").addEventListener("close", function () {
      jQuery('[data-dataset-action="import-google-drive"]').trigger("focus");
    });
  });
})();
