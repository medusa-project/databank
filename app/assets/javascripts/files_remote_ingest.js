(function (window) {
  window.Databank = window.Databank || {};
  Databank.files = Databank.files || {};

  Databank.files.remoteIngest = {
    createFromRemoteUnknownSize: function () {
      jQuery("#loadingModal").modal("show");
      console.log("inside create_from_remote_unknown_size()");

      jQuery.ajax({
        url: jQuery("#form_for_remote").attr("action"),
        type: "POST",
        data: jQuery("#form_for_remote").serialize(),
        datatype: "json",
        success: function (data) {
          var maxId = Number(jQuery("#datafile_index_max").val());
          var newId = 1;

          if (!isNaN(maxId)) {
            newId = maxId + 1;
          }
          jQuery("#datafile_index_max").val(newId);

          var file = data.files[0];

          var row =
            '<tr id="datafile_index_' +
            newId +
            '"><td><div class = "row">' +
            '<input value="false" type="hidden" name="dataset[datafiles_attributes][' +
            newId +
            '][_destroy]" id="dataset_datafiles_attributes_' +
            newId +
            '__destroy" />' +
            '<input type="hidden"  value="' +
            file.datafileId +
            '" name="dataset[datafiles_attributes][' +
            newId +
            '][id]" id="dataset_datafiles_attributes_' +
            newId +
            '_id" />' +
            '<span class="col-md-8">' +
            file.name +
            '<input class="bytestream_name" value="' +
            file.name +
            '" style="visibility: hidden;"/></span><span class="col-md-2">' +
            file.size +
            '</span><span class="col-md-2">';

          if (file.error) {
            row =
              row +
              '<button type="button" class="btn btn-danger"><span class="glyphicon glyphicon-warning-sign"></span>';
          } else {
            row =
              row +
              '<button type="button" class="btn btn-danger btn-sm" data-file-action="remove-row" data-file-index="' +
              newId +
              '">Remove</button></span>';
          }

          row = row + "</span></div></td></tr>";
          if (file.error) {
            jQuery("#datafiles > tbody:last-child").append(
              '<tr><td><div class="row"><p>' +
                file.name +
                ": " +
                file.error +
                "</p></div></td></tr>",
            );
          } else {
            jQuery("#datafiles > tbody:last-child").append(row);
          }

          jQuery("#loadingModal").modal("hide");
        },
        error: function (data) {
          console.log(data);
          alert("There was a problem ingesting the remote file");
          jQuery("#loadingModal").modal("hide");
        },
      });
    },

    createFromRemote: function () {
      if (filename_isdup(jQuery("#remote_filename").val())) {
        alert(
          "Duplicate filename error: A file named " +
            jQuery("#remote_filename").val() +
            " is already in this dataset.  For help, please contact the Research Data Service.",
        );
      } else {
        jQuery.ajax({
          url: "/datafiles/remote_content_length",
          type: "POST",
          data: jQuery("#form_for_remote").serialize(),
          datatype: "json",
          success: function (data) {
            if (data.status == "ok") {
              var content_length = data.remote_content_length;

              if (content_length > 100000000000) {
                alert(
                  "For files larger than 100 GB, please contact the Research Data Service.",
                );
              } else {
                Databank.files.remoteIngest.createFromRemoteUnknownSize();
              }
            } else {
              Databank.files.remoteIngest.createFromRemoteUnknownSize();
            }
          },
          error: function () {
            console.log("content-length unavailable");
            Databank.files.remoteIngest.createFromRemoteUnknownSize();
          },
        });
      }
    },
  };
})(window);
