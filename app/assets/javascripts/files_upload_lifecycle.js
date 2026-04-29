(function (window) {
    window.Databank = window.Databank || {};
    Databank.files = Databank.files || {};

    Databank.files.uploadLifecycle = {
        initFileUpload: function () {
            var bHaveFileAPI = (window.File && window.FileReader);

            if (!bHaveFileAPI) {
                jQuery('.fileselect').html("<p class='notice'>This browser does not support the HTML 5 File API required to upload files. Current versions of Chrome do, as do most modern browsers.</p>");
                return;
            }

            var selectElement = document.getElementById('file-select-area');

            if (selectElement !== null) {
                Databank.files.uploadLifecycle.makeDroppable(selectElement, Databank.files.uploadLifecycle.uploadSelectedFiles);
            }
        },

        makeDroppable: function (element, callback) {
            var input = document.createElement('input');
            input.setAttribute('type', 'file');
            input.setAttribute('multiple', true);
            input.style.display = 'none';

            input.addEventListener('change', triggerCallback);
            element.appendChild(input);

            element.addEventListener('dragover', function (e) {
                e.preventDefault();
                e.stopPropagation();
                element.classList.add('dragover');
            });

            element.addEventListener('dragleave', function (e) {
                e.preventDefault();
                e.stopPropagation();
                element.classList.remove('dragover');
            });

            element.addEventListener('drop', function (e) {
                e.preventDefault();
                e.stopPropagation();
                element.classList.remove('dragover');
                triggerCallback(e);
            });

            element.addEventListener('click', function () {
                input.value = null;
                input.click();
            });

            function triggerCallback(e) {
                var files;
                if (e.dataTransfer) {
                    files = e.dataTransfer.files;
                } else if (e.target) {
                    files = e.target.files;
                }
                callback.call(null, files);
            }
        },

        uploadSelectedFiles: function (files) {
            jQuery('#files').css('display', 'block');
            jQuery('#collapseFiles').collapse('show');

            jQuery('#divFiles').html('');
            for (var i = 0; i < files.length; i++) {
                var fileId = i;

                jQuery('#datafiles_upload_progress').append('<div class="container-fluid" id="progress_' + fileId + '">' +
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

            for (var j = 0; j < files.length; j++) {
                Databank.files.uploadLifecycle.uploadSingleFile(files[j], j);
            }
        },

        uploadSingleFile: function (file, i) {
            var fileId = i;

            var upload = new tus.Upload(file, {
                endpoint: '/files/',
                retryDelays: [0, 1000, 3000, 5000],
                chunkSize: 5 * 1024 * 1024,
                metadata: {
                    filename: file.name,
                    filetype: file.type,
                    size: file.size
                },
                onError: function (error) {
                    jQuery('#status_' + fileId).text('Upload Failed because: ' + error);
                },
                onProgress: function (bytesUploaded, bytesTotal) {
                    var percentage = (bytesUploaded / bytesTotal * 100).toFixed(2);
                    jQuery('#progressbar_' + fileId).css('width', percentage + '%');
                },
                onSuccess: function () {
                    var ajax = new XMLHttpRequest();
                    ajax.addEventListener('load', function (event) {
                        var response = JSON.parse(event.target.responseText);
                        var newFile = response.files[0];

                        jQuery('#status_' + fileId).text(event.target.responseText);
                        jQuery('#progressbar_' + fileId).css('width', '100%');

                        Databank.files.rowMutations.appendFileRow(newFile);

                        jQuery('#progress_' + fileId).remove();

                        var _cancel = jQuery('#cancel_' + fileId);
                        _cancel.hide();
                    }, false);

                    ajax.addEventListener('error', function () {
                        jQuery('#status_' + fileId).text('Upload Failed');
                    }, false);

                    ajax.addEventListener('abort', function () {
                        jQuery('#status_' + fileId).text('Upload Aborted');
                    }, false);

                    ajax.open('POST', '/datafiles');

                    var uploaderForm = new FormData();
                    uploaderForm.append('datafile[dataset_id]', dataset_id);
                    uploaderForm.append('datafile[tus_url]', upload.url);
                    uploaderForm.append('datafile[filename]', upload.file.name);
                    uploaderForm.append('datafile[size]', upload.file.size);
                    uploaderForm.append('datafile[mime_type]', upload.file.type);

                    var csrfToken = jQuery('meta[name="csrf-token"]').attr('content');
                    ajax.setRequestHeader('X-CSRF-Token', csrfToken);
                    ajax.setRequestHeader('Accept', 'application/json');
                    ajax.send(uploaderForm);

                    var _cancel = jQuery('#cancel_' + fileId);
                    _cancel.show();
                    _cancel.on('click', function () {
                        ajax.abort();
                    });
                }
            });

            upload.start();
        }
    };
})(window);
