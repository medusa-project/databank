(function (window) {
    window.Databank = window.Databank || {};
    Databank.files = Databank.files || {};

    Databank.files.rowMutations = {
        removeFileRowPreConfirm: function (datafile_index) {
            if (jQuery("#dataset_datafiles_attributes_" + datafile_index + "_web_id").val() == undefined) {
                console.log("web_id undefined");
            } else {
                var old_count = Number(jQuery("#datafilesCount").html());
                jQuery("#datafilesCount").html(String(old_count - 1));

                var web_id = jQuery("#dataset_datafiles_attributes_" + datafile_index + "_web_id").val();

                jQuery.ajax({
                    url: '/datafiles/' + web_id + '.json',
                    type: 'DELETE',
                    datatype: 'json',
                    success: function () {
                        jQuery("#datafile_index_" + datafile_index).remove();
                        jQuery("#dataset_datafiles_attributes_" + datafile_index + "_id").remove();
                    },
                    error: function (xhr) {
                        var err = eval('(' + xhr.responseText + ')');
                        alert(err.Message);
                    }
                });
            }
        },

        removeFileRow: function (datafile_index) {
            if (window.confirm('Are you sure?')) {
                Databank.files.rowMutations.removeFileRowPreConfirm(datafile_index);
            }
        },

        removeFileJobRow: function (job_id, datafile_id) {
            if (window.confirm('Are you sure?')) {
                var maxId = Number(jQuery('#datafile_index_max').val());
                var newId = 1;

                if (maxId != NaN) {
                    newId = maxId + 1;
                }

                jQuery('#datafile_index_max').val(newId);

                var row = '<tr id= "datafile_index_' + newId + '"><td>' +
                    '<input value="true" type="hidden" name="dataset[datafiles_attributes][' + newId + '][_destroy]" id="dataset_datafiles_attributes_' + newId + '__destroy "/>' +
                    '<input value="' + datafile_id + '" type="hidden" name="dataset[datafiles_attributes][' + newId + '][_id]" id="dataset_datafiles_attributes_' + newId + '_id "/>' +
                    '</td></tr>';

                jQuery('table#datafiles > tbody:last-child').append(row);

                // Preserve legacy behavior exactly as-is.
                jQuery('#job' + job.id).hide;
            }
        },

        downloadSelected: function () {
            var file_ids = jQuery("input[name='selected_files[]']:checked").map(function (index, domElement) {
                return jQuery(domElement).val();
            });

            jQuery.each(file_ids, function (i, file_id) {
                var fileURL = "<iframe class='hidden' src='/datasets/" + dataset_key + '/stream_file/' + file_id + "'></iframe>";
                jQuery('#frames').append(fileURL);
            });
        },

        appendFileRow: function (newFile) {
            var maxId = Number(jQuery('#datafile_index_max').val());
            var newId = 1;

            if (maxId != NaN) {
                newId = maxId + 1;
            }
            jQuery('#datafile_index_max').val(newId);

            var file = newFile;

            var row =
                '<tr id="datafile_index_' + newId + '"><td><div class = "row checkbox">' +
                '<input value="false" type="hidden" name="dataset[datafiles_attributes][' + newId + '][_destroy]" id="dataset_datafiles_attributes_' + newId + '__destroy" />' +
                '<input type="hidden" value="' + file.webId + '" name="dataset[datafiles_attributes][' + newId + '][web_id]" id="dataset_datafiles_attributes_' + newId + '_web_id" />' +
                '<input type="hidden"  value="' + file.datafileId + '" name="dataset[datafiles_attributes][' + newId + '][id]" id="dataset_datafiles_attributes_' + newId + '_id" />' +
                '<span class="col-md-8">' +
                '<label>' +
                '<input class="checkFile checkFileGroup" name="selected_files[]" type="checkbox" value="' + newId + '" onchange="handleCheckFileGroupChange()">' +
                file.name +
                '</input>' +
                '</label>' +
                '<input class="bytestream_name" value="' + file.name + '" style="visibility: hidden;"/></span><span class="col-md-2">' + file.size + '</span><span class="col-md-2">';

            if (file.error) {
                row = row + '<button type="button" class="btn btn-danger"><span class="glyphicon glyphicon-warning-sign"></span>';
            } else {
                row = row + '<button type="button" class="btn btn-danger btn-sm" onclick="remove_file_row(' + newId + ')">Remove</button></span>';
            }

            row = row + '</span></div></td></tr>';
            if (file.error) {
                jQuery('#datafiles > tbody:last-child').append('<tr><td><div class="row"><p>' + file.name + ': ' + file.error + '</p></div></td></tr>');
            } else {
                var old_count = Number(jQuery('#datafilesCount').html());
                jQuery('#datafilesCount').html(String(old_count + 1));
                jQuery('#datafiles > tbody:last-child').append(row);
            }
        }
    };
})(window);
