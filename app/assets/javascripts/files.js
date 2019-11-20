// work-around turbo links to trigger ready function stuff on every page.

var files_ready;
files_ready = function () {
    $('.view-load-spinner').hide();
    $.ajaxSetup({
        headers: {
            'X-CSRF-Token': $('meta[name="csrf-token"]').attr('content')
        }
    });

    initFileUpload();

    //alert("files.js javascript working");
}
//work-around turbo links to trigger ready function stuff on every page.


function remove_file_row_pre_confirm(datafile_index){

    if ($("#dataset_datafiles_attributes_" + datafile_index + "_web_id").val() == undefined) {
        console.log("web_id undefined");
    }
    else {

        var old_count = Number($("#datafilesCount").html())
        $("#datafilesCount").html(String(old_count - 1));

        web_id = $("#dataset_datafiles_attributes_" + datafile_index + "_web_id").val();

        $.ajax({
            url: '/datafiles/' + web_id + '.json',
            type: 'DELETE',
            datatype: "json",
            success: function(result) {
                $("#datafile_index_" + datafile_index).remove();
                $("#dataset_datafiles_attributes_" + datafile_index + "_id").remove();
            },
            error: function(xhr, status, error){
                var err = eval("(" + xhr.responseText + ")");
                alert(err.Message);
            }
        });
    }
}

function remove_file_row(datafile_index) {

    if (window.confirm("Are you sure?")) {

        remove_file_row_pre_confirm(datafile_index);

    }

}

function remove_filejob_row(job_id, datafile_id){

    if (window.confirm("Are you sure?")) {

        var maxId = Number($('#datafile_index_max').val());
        var newId = 1;

        if (maxId != NaN) {
            newId = maxId + 1;
        }

        $('#datafile_index_max').val(newId);

        var row = '<tr id= "datafile_index_' + newId + '"><td>' +
            '<input value="true" type="hidden" name="dataset[datafiles_attributes]['+ newId + '][_destroy]" id="dataset_datafiles_attributes_' + newId + '__destroy "/>' +
            '<input value="'+ datafile_id +'" type="hidden" name="dataset[datafiles_attributes]['+ newId + '][_id]" id="dataset_datafiles_attributes_' + newId + '_id "/>' +
            '</td></tr>'

        $("table#datafiles > tbody:last-child").append(row);

        $("#job"+job.id).hide;
    }

}

function download_selected() {
    var file_ids = $("input[name='selected_files[]']:checked").map(function (index, domElement) {
        return $(domElement).val();
    });

    $.each(file_ids, function (i, file_id) {
        fileURL = "<iframe class='hidden' src='/datasets/" + dataset_key + "/stream_file/" + file_id + "'></iframe>";
        $('#frames').append(fileURL);
    });
}

function create_from_remote_unknown_size(){
    $('#loadingModal').modal('show');

    console.log("inside create_from_remote_unknown_size()")

    // Use Ajax to submit form data

    $.ajax({
        url: $('#form_for_remote').attr('action'),
        type: 'POST',
        data: $('#form_for_remote').serialize(),
        datatype: 'json',
        success: function (data) {

            var maxId = Number($('#datafile_index_max').val());
            var newId = 1;

            if (maxId != NaN) {
                newId = maxId + 1;
            }
            $('#datafile_index_max').val(newId);

            var file = data.files[0];

            var row =
                '<tr id="datafile_index_' + newId + '"><td><div class = "row">' +

                '<input value="false" type="hidden" name="dataset[datafiles_attributes][' + newId + '][_destroy]" id="dataset_datafiles_attributes_' + newId + '__destroy" />' +
                '<input type="hidden"  value="' + file.datafileId + '" name="dataset[datafiles_attributes][' + newId + '][id]" id="dataset_datafiles_attributes_' + newId + '_id" />' +

                '<span class="col-md-8">' + file.name + '<input class="bytestream_name" value="' + file.name + '" style="visibility: hidden;"/></span><span class="col-md-2">' + file.size + '</span><span class="col-md-2">';
            if (file.error) {
                row = row + '<button type="button" class="btn btn-danger"><span class="glyphicon glyphicon-warning-sign"></span>';
            } else {
                row = row + '<button type="button" class="btn btn-danger btn-sm" onclick="remove_file_row(' + newId + ')"><span class="glyphicon glyphicon-trash"></span></button></span>';
            }

            row = row + '</span></div></td></tr>';
            if (file.error) {
                $("#datafiles > tbody:last-child").append('<tr><td><div class="row"><p>' + file.name + ': ' + file.error + '</p></div></td></tr>');
            } else {
                $("#datafiles > tbody:last-child").append(row);
            }

            $('#loadingModal').modal('hide');
        },
        error: function (data) {
            console.log(data);
            alert("There was a problem ingesting the remote file");
            $('#loadingModal').modal('hide');
        }
    });
}

function create_from_remote(){

    if (filename_isdup($('#remote_filename').val())) {
        alert("Duplicate filename error: A file named " + $('#remote_filename').val() + " is already in this dataset.  For help, please contact the Research Data Service.");
    }
    else {

        $.ajax({
            url: "/datafiles/remote_content_length",
            type: 'POST',
            data: $('#form_for_remote').serialize(),
            datatype: 'json',
            success: function (data) {
                if(data.status == "ok" ) {
                    var content_length = data.remote_content_length;

                    if (content_length > 100000000000){
                        alert("For files larger than 100 GB, please contact the Research Data Service.");
                    } else {
                        // getting here means not known to be too big
                        create_from_remote_unknown_size();
                    }
                }
                else{
                    create_from_remote_unknown_size();
                }
            },
            error: function (data) {
                console.log("content-length unavailable");
                create_from_remote_unknown_size();
            }
        });
    }
}

function preview(web_id){
    $("#preview_" + web_id).show();

    if ($("#preview_" + web_id).hasClass('fetched')){
        console.log("using previously fetched text");
    } else {
        $('.spinner_'+web_id).show();

        $.getJSON( "/datafiles/" + web_id + "/viewtext", function( json ) {
            $("#preview_" + web_id).html("<pre>" + json.peek_text + "</pre>");
            $("#preview_" + web_id).addClass('fetched');
            $('.spinner_'+web_id).hide();
        });
    }

    $("#preview_glyph_" + web_id).removeClass("glyphicon-eye-open");
    $("#preview_glyph_" + web_id).addClass("glyphicon-eye-close");
    $("#preview_btn_" + web_id).attr('onclick', "hide_preview('" + web_id  + "')");
}

function preview_md(web_id){
    $("#preview_" + web_id).show();
    $("#preview_glyph_" + web_id).removeClass("glyphicon-eye-open");
    $("#preview_glyph_" + web_id).addClass("glyphicon-eye-close");
    $("#preview_md_btn_" + web_id).attr('onclick', "hide_md_preview('" + web_id  + "')");
}

function hide_md_preview(web_id){
    $("#preview_glyph_" + web_id).removeClass("glyphicon-eye-close");
    $("#preview_glyph_" + web_id).addClass("glyphicon-eye-open");
    $("#preview_md_btn_" + web_id).attr('onclick', "preview_md('" + web_id  + "')");
    $("#preview_" + web_id).hide();
}

function hide_preview(web_id){
    $("#preview_glyph_" + web_id).removeClass("glyphicon-eye-close");
    $("#preview_glyph_" + web_id).addClass("glyphicon-eye-open");
    $("#preview_btn_" + web_id).attr('onclick', "preview('" + web_id  + "')");
    $("#preview_" + web_id).hide();
}

function preview_image(iiif_root, web_id){

    $("#preview_" + web_id).show();
    if ($("#preview_" + web_id).hasClass('fetched')){
        console.log("using previously fetched image");
    } else {
        $('.spinner_'+web_id).show();
        var image_url = iiif_root + "/" + web_id + "/full/full/0/default.jpg";
        $("#preview_" + web_id).addClass('fetched');
        $("#preview_" + web_id).html("<img src="+ image_url +" class='preview_body'>");
        $('.spinner_'+web_id).hide();
    }
    $("#preview_img_btn_" + web_id).html('<button type="button" class="btn btn-sm btn-success" onclick="hide_image_preview(&#39;' + iiif_root + '&#39;, &#39;' + web_id + '&#39;)"><span class="glyphicon glyphicon-eye-close"></span> View</button>');
}

function hide_image_preview(iiif_root, web_id){
    $("#preview_img_btn_" + web_id).html('<button type="button" class="btn btn-sm btn-success" onclick="preview_image(&#39;' + iiif_root + '&#39;, &#39;' + web_id + '&#39;)"><span class="glyphicon glyphicon-eye-open"></span> View</button>');
    $("#preview_" + web_id).hide();
}

function initFileUpload() {
    var bHaveFileAPI = (window.File && window.FileReader);

    if (!bHaveFileAPI) {
        $(".fileselect").html("<p class='notice'>This browser does not support the HTML 5 File API required to upload files. Current versions of Chrome do, as do most modern browsers.</p>")
        return;
    }

    // support drag-and-drop file upload

    var dropElement = document.getElementById("file-drop-area");

    if (dropElement !== null){
      makeDroppable(dropElement, uploadSelectedFiles);
    }

    var selectElement = document.getElementById("file-select-area");

    if (selectElement !== null){
        makeDroppable(selectElement, uploadSelectedFiles);
    }

}

function makeDroppable(element, callback) {

    var input = document.createElement('input');
    input.setAttribute('type', 'file');
    input.setAttribute('multiple', true);
    input.style.display = 'none';

    input.addEventListener('change', triggerCallback);
    element.appendChild(input);

    element.addEventListener('dragover', function(e) {
        e.preventDefault();
        e.stopPropagation();
        element.classList.add('dragover');
    });

    element.addEventListener('dragleave', function(e) {
        e.preventDefault();
        e.stopPropagation();
        element.classList.remove('dragover');
    });

    element.addEventListener('drop', function(e) {
        e.preventDefault();
        e.stopPropagation();
        element.classList.remove('dragover');
        triggerCallback(e);
    });

    element.addEventListener('click', function() {
        input.value = null;
        input.click();
    });

    function triggerCallback(e) {
        var files;
        if(e.dataTransfer) {
            files = e.dataTransfer.files;
        } else if(e.target) {
            files = e.target.files;
        }
        callback.call(null, files);
    }
}

function uploadSelectedFiles(files){
    $('#files').css("display", "block");
    $('#collapseFiles').collapse('show');

    $('#divFiles').html('');
    for (var i = 0; i < files.length; i++) { //Progress bar and status label's for each file genarate dynamically
        var fileId = i;

        $('#datafiles_upload_progress').append('<div class="container-fluid" id="progress_' + fileId + '">' +
            '<div class="row">' +
            '<div class="col-md-10">' +
            '<p class="progress-status" id="status_' + fileId + '">' + files[i].name.toString() + '</p>' +
            '</div>' +
            '<div class="col-md-2">' +
            '<input type="button" class="btn btn-block btn-danger" id="cancel_' + fileId + '" value="cancel">' +
            '</div></div>' +

            '<div class="row">' +
            '<div class="progress col-md-12">' +
            '<div class="progress-bar progress-bar-striped active" id="progressbar_' + fileId + '" role="progressbar" aria-valuemin="0" aria-valuemax="100" style="width:0%"></div>' +
            '</div></div>' +
            '<div class="col-md-12">' +
            '<p id="notify_' + fileId + '" style="text-align: right;"></p>' +
            '</div></div>');
    }

    for (var i = 0; i < files.length; i++) {
        uploadSingleFile(files[i], i);
    }
}


/*function onFileChanged(theEvt) {
    var files = theEvt.target.files;

    $('#files').css("display", "block");
    $('#collapseFiles').collapse('show');

    $('#divFiles').html('');
    for (var i = 0; i < files.length; i++) { //Progress bar and status label's for each file genarate dynamically
        var fileId = i;

        console.log(files[i].name.toString());

        $('#datafiles_upload_progress').append('<div class="container-fluid" id="progress_' + fileId + '">' +
            '<div class="row">' +
            '<div class="col-md-10">' +
            '<p class="progress-status" id="status_' + fileId + '">' + files[i].name.toString() + '</p>' +
            '</div>' +
            '<div class="col-md-2">' +
            '<input type="button" class="btn btn-block btn-danger" id="cancel_' + fileId + '" value="cancel">' +
            '</div></div>' +

            '<div class="row">' +
            '<div class="progress col-md-12">' +
            '<div class="progress-bar progress-bar-striped active" id="progressbar_' + fileId + '" role="progressbar" aria-valuemin="0" aria-valuemax="100" style="width:0%"></div>' +
            '</div></div>' +
            '<div class="col-md-12">' +
            '<p id="notify_' + fileId + '" style="text-align: right;"></p>' +
            '</div></div>');
    }

    for (var i = 0; i < files.length; i++) {
        uploadSingleFile(files[i], i);
    }

}*/

function uploadSingleFile(file, i){

    var fileId = i;

    // Create a new tus upload
    var upload = new tus.Upload(file, {
        endpoint: "/files/",
        retryDelays: [0, 1000, 3000, 5000],
        chunkSize: 5*1024*1024, // 5MB
        metadata: {
            filename: file.name,
            filetype: file.type,
            size: file.size
        },
        onError: function(error) {
            $("#status_" + fileId).text("Upload Failed because: " + error);
        },
        onProgress: function(bytesUploaded, bytesTotal) {
            var percentage = (bytesUploaded / bytesTotal * 100).toFixed(2)
            $('#progressbar_' + fileId).css("width", percentage + "%")
        },
        onSuccess: function() {

            var ajax = new XMLHttpRequest();
            ajax.addEventListener("load", function (event) {

                var response = JSON.parse(event.target.responseText);

                var newFile = response.files[0];

                $("#status_" + fileId).text(event.target.responseText);
                $('#progressbar_' + fileId).css("width", "100%");

                appendFileRow(newFile);

                $("#progress_" + fileId).remove();

                //Hide cancel button
                var _cancel = $('#cancel_' + fileId);
                _cancel.hide();
            }, false);

            ajax.addEventListener("error", function (e) {
                $("#status_" + fileId).text("Upload Failed");
            }, false);
            //Abort Listener
            ajax.addEventListener("abort", function (e) {
                $("#status_" + fileId).text("Upload Aborted");
            }, false);

            ajax.open("POST", "/datafiles");

            var uploaderForm = new FormData();
            uploaderForm.append('datafile[dataset_id]', dataset_id);
            uploaderForm.append('datafile[tus_url]', upload.url);
            uploaderForm.append('datafile[filename]', upload.file.name);
            uploaderForm.append('datafile[size]', upload.file.size);
            uploaderForm.append('datafile[mime_type]', upload.file.type);

            var csrfToken = $('meta[name="csrf-token"]').attr('content');

            ajax.setRequestHeader('X-CSRF-Token', csrfToken);
            ajax.setRequestHeader('Accept', 'application/json');

            ajax.send(uploaderForm);

            //Cancel button
            var _cancel = $('#cancel_' + fileId);
            _cancel.show();

            _cancel.on('click', function () {
                ajax.abort();
            })


        }
    })

    // Start the upload
    upload.start()
}

function appendFileRow(newFile){
    var maxId = Number($('#datafile_index_max').val());
    var newId = 1;

    if (maxId != NaN) {
        newId = maxId + 1;
    }
    $('#datafile_index_max').val(newId);

    var file = newFile;

    var row =
        '<tr id="datafile_index_' + newId + '"><td><div class = "row checkbox">' +
        '<input value="false" type="hidden" name="dataset[datafiles_attributes][' + newId + '][_destroy]" id="dataset_datafiles_attributes_' + newId + '__destroy" />' +
        '<input type="hidden" value="'+ file.webId +'" name="dataset[datafiles_attributes]['+ newId +'][web_id]" id="dataset_datafiles_attributes_'+ newId +'_web_id" />' +
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
        row = row + '<button type="button" class="btn btn-danger btn-sm" onclick="remove_file_row(' + newId + ')"><span class="glyphicon glyphicon-trash"></span></button></span>';
    }

    row = row + '</span></div></td></tr>';
    if (file.error) {
        $("#datafiles > tbody:last-child").append('<tr><td><div class="row"><p>' + file.name + ': ' + file.error + '</p></div></td></tr>');
    } else {
        var old_count = Number($("#datafilesCount").html());
        $("#datafilesCount").html(String(old_count + 1));
        $("#datafiles > tbody:last-child").append(row);
    }
}

$(document).ready(files_ready);
$(document).on('page:load', files_ready);
