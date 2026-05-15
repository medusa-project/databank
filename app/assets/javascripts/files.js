// Files domain entrypoint and compatibility wrappers.
// Canonical implementations are split across:
// - files_row_mutations.js
// - files_remote_ingest.js
// - files_preview_ui.js
// - files_upload_lifecycle.js

var files_ready;
files_ready = function () {
  jQuery(".view-load-spinner").hide();
  jQuery.ajaxSetup({
    headers: {
      "X-CSRF-Token": jQuery('meta[name="csrf-token"]').attr("content"),
    },
  });

  Databank.files.uploadLifecycle.initFileUpload();
  bindFilesDelegatedActions();
};

function bindFilesDelegatedActions() {
  jQuery(document)
    .off("click.filesActions", "[data-file-action]")
    .on("click.filesActions", "[data-file-action]", function (event) {
      var $target = jQuery(this);
      var action = $target.data("file-action");

      switch (action) {
        case "create-remote":
          event.preventDefault();
          Databank.files.remoteIngest.createFromRemote();
          break;
        case "preview-text":
          event.preventDefault();
          Databank.files.previewUI.preview($target.data("web-id"));
          break;
        case "hide-preview-text":
          event.preventDefault();
          Databank.files.previewUI.hidePreview($target.data("web-id"));
          break;
        case "preview-md":
          event.preventDefault();
          Databank.files.previewUI.previewMd($target.data("web-id"));
          break;
        case "hide-preview-md":
          event.preventDefault();
          Databank.files.previewUI.hideMdPreview($target.data("web-id"));
          break;
        case "preview-image":
          event.preventDefault();
          Databank.files.previewUI.previewImage(
            $target.data("iiif-root"),
            $target.data("web-id"),
          );
          break;
        case "hide-preview-image":
          event.preventDefault();
          Databank.files.previewUI.hideImagePreview(
            $target.data("iiif-root"),
            $target.data("web-id"),
          );
          break;
        case "remove-row":
          event.preventDefault();
          Databank.files.rowMutations.removeFileRow($target.data("file-index"));
          break;
        case "remove-filejob":
          event.preventDefault();
          Databank.files.rowMutations.removeFileJobRow(
            $target.data("job-id"),
            $target.data("datafile-id"),
          );
          break;
        case "delete-selected":
          event.preventDefault();
          if (typeof window.deleteSelected === "function") {
            window.deleteSelected();
          }
          break;
        case "offer-download-link":
          event.preventDefault();
          if (typeof window.offerDownloadLink === "function") {
            window.offerDownloadLink();
          }
          break;
        default:
          break;
      }
    })
    .off("change.filesActions", '[data-file-action="selection-change"]')
    .on(
      "change.filesActions",
      '[data-file-action="selection-change"]',
      function () {
        if (typeof window.handleCheckFileGroupChange === "function") {
          window.handleCheckFileGroupChange();
        }
      },
    );
}

// Legacy global wrappers -----------------------------------------------------

function remove_file_row_pre_confirm(datafile_index) {
  return Databank.files.rowMutations.removeFileRowPreConfirm(datafile_index);
}

function remove_file_row(datafile_index) {
  return Databank.files.rowMutations.removeFileRow(datafile_index);
}

function remove_filejob_row(job_id, datafile_id) {
  return Databank.files.rowMutations.removeFileJobRow(job_id, datafile_id);
}

function download_selected() {
  return Databank.files.rowMutations.downloadSelected();
}

function create_from_remote_unknown_size() {
  return Databank.files.remoteIngest.createFromRemoteUnknownSize();
}

function create_from_remote() {
  return Databank.files.remoteIngest.createFromRemote();
}

function preview(web_id) {
  return Databank.files.previewUI.preview(web_id);
}

function preview_md(web_id) {
  return Databank.files.previewUI.previewMd(web_id);
}

function hide_md_preview(web_id) {
  return Databank.files.previewUI.hideMdPreview(web_id);
}

function hide_preview(web_id) {
  return Databank.files.previewUI.hidePreview(web_id);
}

function preview_image(iiif_root, web_id) {
  return Databank.files.previewUI.previewImage(iiif_root, web_id);
}

function hide_image_preview(iiif_root, web_id) {
  return Databank.files.previewUI.hideImagePreview(iiif_root, web_id);
}

function initFileUpload() {
  return Databank.files.uploadLifecycle.initFileUpload();
}

function makeDroppable(element, callback) {
  return Databank.files.uploadLifecycle.makeDroppable(element, callback);
}

function uploadSelectedFiles(files) {
  return Databank.files.uploadLifecycle.uploadSelectedFiles(files);
}

function uploadSingleFile(file, i) {
  return Databank.files.uploadLifecycle.uploadSingleFile(file, i);
}

function appendFileRow(newFile) {
  return Databank.files.rowMutations.appendFileRow(newFile);
}

jQuery(document).ready(files_ready);
jQuery(document).on("page:load", files_ready);
