window.DatabankCloudImport = function (options) {
  "use strict";

  var prefix = options.prefix;
  var name = options.name;
  var buttonSelector = '[data-dataset-action="import-' + prefix + '"]';
  var pollTimer;
  var authorizationWindow;
  var selectionId;

  function element(suffix) {
    return jQuery("#" + prefix + "-" + suffix);
  }

  function request(url, method, data) {
    return new Promise(function (resolve, reject) {
      jQuery.ajax({
        url: url,
        type: method || "GET",
        data: data,
        dataType: "json",
        headers: {
          "X-CSRF-Token": jQuery('meta[name="csrf-token"]').attr("content"),
        },
        success: resolve,
        error: function (xhr) {
          reject(
            new Error(
              (xhr.responseJSON && xhr.responseJSON.error) ||
                "The " + name + " request failed. Please try again or contact the Research Data Service.",
            ),
          );
        },
      });
    });
  }

  function showError(error, background) {
    var message = element("error");
    if (message.text() !== error.message) {
      message.text(error.message);
    }
    if (!background) {
      focusImportControl();
    }
  }

  function focusImportControl() {
    var button = jQuery(buttonSelector);
    (button.prop("disabled") ? element("imports") : button).trigger("focus");
  }

  function updateImportAvailability(imports) {
    var active = imports.some(function (item) {
      return item.status === "queued" || item.status === "importing";
    });
    var button = jQuery(buttonSelector);
    var hadFocus = button.is(":focus");
    button.prop("disabled", active);
    var message = active
        ? "A " + name + " import is queued or in progress for this dataset. Wait for it to finish or cancel it before starting another."
        : "";
    var availability = element("import-availability");
    if (availability.text() !== message) {
      availability.text(message);
    }
    if (active && hadFocus) {
      focusImportControl();
    }
  }

  function basePath() {
    return element("imports").data("base-path");
  }

  function showPicker() {
    return request(basePath() + "/picker").then(function (config) {
      return options.openPicker(config);
    }).then(function (fileId) {
      if (fileId) {
        return preview(fileId);
      }
      request(basePath() + "/authorization", "DELETE").catch(showError);
      focusImportControl();
    });
  }

  function preview(fileId) {
    return request(basePath() + "/preview", "POST", { file_id: fileId }).then(function (file) {
      selectionId = file.selection_id;
      element("selected-name").text(file.name);
      element("selected-size").text(file.size.toLocaleString() + " bytes");
      element("confirmation")[0].showModal();
      element("confirm").trigger("focus");
    });
  }

  function renderImports(imports) {
    var list = element("import-list");
    // Avoid replacing focused controls or repeating unchanged live announcements.
    var snapshot = JSON.stringify(imports);
    if (list.data("snapshot") === snapshot) {
      return;
    }
    list.data("snapshot", snapshot);
    var focusedId = document.activeElement && document.activeElement.id;
    var focusWasInList = list[0].contains(document.activeElement);
    element("import-notices").prop("hidden", imports.length === 0);
    var announcements = [];
    list.children().each(function () {
      var id = jQuery(this).data("import-id");
      if (!imports.some(function (item) { return item.id === id; })) {
        jQuery(this).remove();
      }
    });
    imports.forEach(function (item) {
      var previousRow = element("import-row-" + item.id);
      var state = JSON.stringify([item.name, item.status, item.error]);
      var progressText = " " + item.bytes_downloaded.toLocaleString() +
        " of " + item.size.toLocaleString() + " bytes downloaded. ";
      if (previousRow.data("state") === state) {
        previousRow.find("progress").attr({ max: item.size, value: item.bytes_downloaded });
        previousRow.find(".drive-import-progress-text").text(progressText);
        return;
      }
      announcements.push(item.name + ": " + item.status + "." + (item.error ? " " + item.error : ""));
      var row = jQuery("<li>", { id: prefix + "-import-row-" + item.id })
        .data("import-id", item.id).data("state", state);
      row.append(jQuery("<span>").text(item.name + ": " + item.status + ". "));
      if (item.status === "queued" || item.status === "importing") {
        row.append(
          jQuery("<progress>").attr({
            max: item.size,
            value: item.bytes_downloaded,
            "aria-label": "Download progress for " + item.name,
          }),
        );
        row.append(jQuery("<span>", { "class": "drive-import-progress-text", text: progressText }));
        row.append(
          jQuery("<button>", {
            type: "button",
            id: prefix + "-cancel-import-" + item.id,
            class: "btn btn-default btn-sm",
            text: "Cancel",
            "aria-label": "Cancel import of " + item.name,
          }).on("click", function () {
            request(basePath() + "/imports/" + item.id, "DELETE")
              .then(function () {
                return refreshImports().then(focusImportControl);
              })
              .catch(showError);
          }),
        );
      }
      if (item.error) {
        row.append(jQuery("<span>").text(" " + item.error));
      }
      if (item.status === "complete") {
        row.append(
          jQuery("<a>", {
            id: prefix + "-reload-import-" + item.id,
            href: window.location.pathname,
            text: "Reload the page to show the imported file",
          }),
        );
        row.append(document.createTextNode(" "));
      }
      if (
        item.status === "complete" ||
        item.status === "failed" ||
        item.status === "cancelled"
      ) {
        row.append(
          jQuery("<button>", {
            type: "button",
            id: prefix + "-remove-import-" + item.id,
            class: "btn btn-default btn-sm",
            text: "Clear Notice",
            "aria-label":
              "Clear Notice for " + item.name + " (" + item.status + ")",
          }).on("click", function () {
            request(basePath() + "/imports/" + item.id + "/notice", "DELETE")
              .then(function () {
                return refreshImports().then(focusImportControl);
              })
              .catch(showError);
          }),
        );
      }
      if (previousRow.length) {
        previousRow.replaceWith(row);
      } else {
        list.append(row);
      }
    });
    if (announcements.length) {
      element("import-announcement").text(announcements.join(" "));
    }
    if (focusWasInList) {
      if (focusedId && document.getElementById(focusedId)) {
        var target = document.getElementById(focusedId);
        if (document.activeElement !== target) {
          target.focus();
        }
      } else {
        focusImportControl();
      }
    }
  }

  function refreshImports() {
    window.clearTimeout(pollTimer);
    return request(basePath() + "/imports")
      .then(function (imports) {
        updateImportAvailability(imports);
        renderImports(imports);
        var active = imports.some(function (item) {
          return item.status === "queued" || item.status === "importing";
        });
        pollTimer = window.setTimeout(refreshImports, active ? 5000 : 15000);
      })
      .catch(function (error) {
        showError(error, true);
        pollTimer = window.setTimeout(refreshImports, 15000);
      });
  }

  jQuery(function () {
    var result = element("oauth-result")[0];
    if (result) {
      if (window.opener && result.dataset.success === "true") {
        window.opener.postMessage(
          { type: "databank-" + prefix + "-authorized" },
          window.location.origin,
        );
        window.close();
      }
      return;
    }
    if (!element("imports").length) {
      return;
    }
    refreshImports();
    jQuery(document).on(
      "click." + prefix,
      buttonSelector,
      function () {
        element("error").text("");
        authorizationWindow = window.open(
          "",
          "databank-" + prefix,
          "popup,width=700,height=700",
        );
        if (!authorizationWindow) {
          showError(
            new Error(
              "Allow pop-up windows for this site to authorize " + name + ".",
            ),
          );
          return;
        }
        request(basePath() + "/authorize", "POST")
          .then(function (data) {
            authorizationWindow.location.assign(data.authorization_url);
          })
          .catch(function (error) {
            authorizationWindow.close();
            showError(error);
          });
      },
    );
    window.addEventListener("message", function (event) {
      if (
        event.origin === window.location.origin &&
        event.source === authorizationWindow &&
        event.data &&
        event.data.type === "databank-" + prefix + "-authorized"
      ) {
        authorizationWindow = null;
        showPicker().catch(showError);
      }
    });
    element("confirm").on("click", function () {
      var button = jQuery(this).prop("disabled", true);
      request(basePath() + "/imports", "POST", { selection_id: selectionId })
        .then(function (importStatus) {
          updateImportAvailability([importStatus]);
          element("confirmation")[0].close();
          refreshImports();
        })
        .catch(function (error) {
          element("confirmation")[0].close();
          showError(error);
          refreshImports();
        })
        .finally(function () {
          button.prop("disabled", false);
        });
    });
    element("dismiss").on("click", function () {
      element("confirmation")[0].close();
      request(basePath() + "/authorization", "DELETE").catch(showError);
    });
    element("confirmation")[0]
      .addEventListener("cancel", function () {
        request(basePath() + "/authorization", "DELETE").catch(showError);
      });
    element("confirmation")[0]
      .addEventListener("close", function () {
        focusImportControl();
      });
  });
};
