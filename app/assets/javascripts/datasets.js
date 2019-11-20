var confirmOnPageExit
confirmOnPageExit = function (e) {
    // If we haven't been passed the event get the window.event
    e = e || window.event;

    var message = 'If you navigate away from this page, unsaved changes may be lost.';

    // For IE6-8 and Firefox prior to version 4
    if (e) {
        e.returnValue = message;
    }

    // For Chrome, Safari, IE8+ and Opera 12+
    return message;
};

// work-around turbo links to trigger ready function stuff on every page.

var ready;
ready = function () {

    $('.bytestream_name').css("visibility", "hidden");

    $('.deposit-agreement-warning').hide();

    $('.deposit-agreement-selection-warning').hide();
    $('#agree-button').prop("disabled", true);


    $("#publish-then-review-btn").click(function () {

        $('#offer_review_h').modal('hide');
        $('#deposit').modal('show');

    });

    $("#review-then-publish-btn").click(function () {

        $('#offer_review_h').modal('hide');
        window.location.href = "/datasets/" + dataset_key + "/request_review"

    });

    $(".choose_review_block_v").click(function () {
        $('#choose_review_v').trigger("click");
    });


    $(".choose_continue_block_v").click(function () {
        $('#choose_continue_v').trigger("click");
    });

    $(".choose_review_block_h").click(function () {
        $('#choose_review_h').trigger("click");
    });


    $(".choose_continue_block_h").click(function () {
        $('#choose_continue_h').trigger("click");
    });


    $('#keyword-text').keyup(handleKeywordKeyup);
    $('#keyword-text').blur(handleKeywordKeyup);

    // handle non-chrome datepicker:
    if (!Modernizr.inputtypes.date) {
        $("#dataset_release_date").prop({type: "text"});
        $("#dataset_release_date").prop({placeholder: "YYYY-MM-DD"});
        $("#dataset_release_date").prop({"data-mask": "9999-99-99"});

        $("#dataset_release_date").datepicker({
            inline: true,
            showOtherMonths: true,
            minDate: 0,
            maxDate: "+1Y",
            dateFormat: "yy-mm-dd",
            defaultDate: (Date.now())
        });
    }

    // dynamically hide/show long description text
    var showChar = 140;
    var ellipsestext = "...";
    var moretext = "more";
    var lesstext = "less";
    $('.more').each(function () {
        var content = $(this).html();

        if (content.length > showChar) {

            var c = content.substr(0, showChar);
            var h = content.substr(showChar, content.length - showChar);

            var html = c + '<span class="moreellipses">' + ellipsestext + '&nbsp;</span><span class="morecontent"><span>' + h + '</span>&nbsp;&nbsp;<a href="" class="morelink">' + moretext + '</a></span>';

            $(this).html(html);
        }

    });

    $(".morelink").click(function () {
        if ($(this).hasClass("less")) {
            $(this).removeClass("less");
            $(this).html(moretext);
        } else {
            $(this).addClass("less");
            $(this).html(lesstext);
        }
        $(this).parent().prev().toggle();
        $(this).prev().toggle();
        return false;
    });

    $(".upload-consistent").tooltip({
        html: "true",
        title: "<em>consistent</em>--Reliable performance for a variety of connection speeds and configurations."
    });

    $(".upload-inconsistent").tooltip({
        html: "true",
        title: "<em>inconsistent</em>--Depends for reliability on connection strength and speed. Works well on campus, but home and coffee-shop environments vary."
    });

    $(".upload-unavailable").tooltip({
        html: "true",
        title: "<em>unavailable</em>--Either does not work at all, or is so unreliable as to be inadvisable. </td> </tr> </table> </table>"
    });

    // $(".upload-consistent").tooltip({
    //     html: "true",
    //     title: "<table class='upload-key'><tr class='highlight-background'> <td> <span class='fas upload-guide fa-circle'></span></td> <td> consistent </td><td> Reliable performance for a variety of connection speeds and configurations. </td> </tr> <tr> <td> <span class='fas upload-guide fa-adjust'></span> <td>inconsistent</td> </td> <td> Depends for reliability on connection strength and speed. Works well on campus, but home and coffee-shop environments vary. </td> </tr> <tr> <td> <span class='far upload-guide fa-circle'></span> <td>unavailable</td> </td> <td> Either does not work at all, or is so unreliable as to be inadvisable. </td> </tr> </table> </table>"
    // });

    // $(".upload-inconsistent").tooltip({
    //     html: "true",
    //     title: "<table class='upload-key'><tr> <td> <span class='fas upload-guide fas-circle'></span></td> <td> consistent </td><td> Reliable performance for a variety of connection speeds and configurations. </td> </tr> <tr class='highlight-background'> <td> <span class='fas upload-guide fa-adjust'></span> <td>inconsistent</td> </td> <td> Depends for reliability on connection strength and speed. Works well on campus, but home and coffee-shop environments vary. </td> </tr> <tr> <td> <span class='far upload-guide fa-circle'></span> <td>unavailable</td> </td> <td> Either does not work at all, or is so unreliable as to be inadvisable. </td> </tr> </table> </table>"
    // });
    //
    // $(".upload-unavailable").tooltip({
    //     html: "true",
    //     title: "<table class='upload-key'><tr> <td> <span class='fas upload-guide fa-circle'></span></td> <td> consistent </td><td> Reliable performance for a variety of connection speeds and configurations. </td> </tr> <tr> <td> <span class='fas upload-guide fa-adjust'></span> <td>inconsistent</td> </td> <td> Depends for reliability on connection strength and speed. Works well on campus, but home and coffee-shop environments vary. </td> </tr> <tr class='highlight-background'> <td> <span class='far upload-guide fa-circle'></span> <td>unavailable</td> </td> <td> Either does not work at all, or is so unreliable as to be inadvisable. </td> </tr> </table> </table>"
    // });

    var numChecked = $('input.checkFile:checked').length;

    $(".checkFileSelectedCount").html('(' + numChecked + ')');

    $("#checkAllFiles").click(function () {
        $(".checkFileGroup").prop('checked', $(this).prop('checked'));

        var numChecked = $('input.checkFile:checked').length;

        $(".checkFileSelectedCount").html("(" + numChecked + ")");
    });

    $('#term-supports').tooltip();

    $('#cancel-button').click(function () {
        // alert("You must agree to the Deposit Agreement before depositing data into Illinois Data Bank.");
        handleNotAgreed();
    });

    $('#dropdown-login').click(function (event) {
        if (event.stopPropagation) {
            event.stopPropagation();
        } else if (window.event) {
            window.event.cancelBubble = true;
        }
    });

    $('#new-exit-button').click(function () {
        $('#new_dataset').append("<input type='hidden' name='context' value='exit' />");
        window.onbeforeunload = null;
        $('#new_dataset').submit();
    });

    $('.new-save').hide();

    $('.preview').hide();
    $('.markdown_preview').hide();

    $('.nav-item').click(function () {

        $('.nav-item').removeClass('current');
        $(this).addClass('current');
    });

    $('#update-save-button').click(function () {


        if ($(".invalid-name").length > 0) {
            alert("All names must be complete.");
            $(".invalid-name > input").first().focus();
            return
        }

        if ($(".progress-bar").length == 0) {

            window.onbeforeunload = null;

            $("[id^=edit_dataset]").submit();
        } else {
            alert("UPLOADS IN PROGRESS. Try again once uploads are complete.")
            return
        }

    });

    $('#update-confirm').prop('disabled', true);

    $("[id^=edit_dataset] :input").keyup(function () {
        $('#update-confirm').prop('disabled', false);
    });

    $("[id^=edit_dataset] :input").change(function () {
        $('#update-confirm').prop('disabled', false);
    });

    $('#save-exit-button').click(function () {

        if ($(".invalid-email").length == 0) {

            if ($(".progress-bar").length == 0) {

                $("[id^=edit_dataset]").append("<input type='hidden' name='context' value='exit' />");
                window.onbeforeunload = null;
                $("[id^=edit_dataset]").submit();

            } else {
                alert("UPLOADS IN PROGRESS. Try again once uploads are complete.")
            }
        } else {
            alert("Email address must be in a valid format.");
            $(".invalid-email").first().focus();
        }

    });

    $('input.dataset').change(function () {
        if ($(this).val() != "") {
            window.onbeforeunload = confirmOnPageExit;
        }
    });

    //$('.preview').css("visibility", "hidden");

    $('#dataset_title').change(function () {
        if ($("input[name='dataset[publication_state]']").val() == 'draft' || $(this).val() != "") {
            $('#title-preview').html($(this).val() + '.');
            $('#update-save-button').prop('disabled', false);
        } else {
            alert("Published Dataset must have a title.");
            $('#update-save-button').prop('disabled', true);
        }
    });

    $('#dataset_publication_year').change(function () {
        $('#year-preview').html('(' + $(this).val() + '):');
    });

    $('#dataset_identifier').change(function () {
        $('#doi-preview').html("https://doi.org/" + $(this).val());
    });

    $('#show-all-button').click(function () {
        window.location.assign('/datasets');
    });

    $('#show-my-button').click(function () {
        var current_user_email = $('input#current_user_email').val();
        window.location.assign('/datasets?depositor_email=' + current_user_email);
    });

    $("#chunked-upload-btn").click(function () {
        window.location.assign('/datasets/' + dataset_key + '/datafiles/add');
    });

    $("#portable-upload").click(function () {
        window.location.assign('/help?context=pickup&key=' + dataset_key);
    });

    if (!$('#dataset_embargo').val()) {

        $('#release-date-picker').hide();
    }

    $("#dataset_embargo").change(function () {
        $('#update-confirm').prop('disabled', false);
        switch ($(this).val()) {
            case 'file embargo':
                $('#release-date-picker').show();
                break;
            case 'metadata embargo':
                $('#release-date-picker').show();
                break;
            default:
                $('#dataset_release_date').val('');
                $('#release-date-picker').hide();
        }
    });

    $('[data-toggle="tooltip"]').tooltip();

    var clip = new ZeroClipboard($(".copy-btn"));

    $("#login-prompt").modal('show');
    //alert("pre-validity check");
    //alert("dataset key: "+ dataset_key)

    $("#api-modal-btn").click(function () {

        $.getJSON("/datasets/" + dataset_key + "/get_current_token", function (data) {
            if (data.token && data.expires && data.token != "none") {
                $('#token-header').text('Here is your token:');
                setTokenExamples(data.token, data.expires);

            } else {
                getNewToken();
            }

        });

        $("#api_modal").modal('show');
    });

    $("#reserve-doi-btn").click(function () {

        $.getJSON("/datasets/" + dataset_key + "/reserve_doi", function (data) {
            if (data.status && data.status == "ok") {

                $("#deposit").modal('show');

                $("#your-doi-here").html("We've reserved a DOI for you: " + data.doi + ", but your dataset is not yet published.");

            } else {
                alert("We're sorry, something went wrong during an attempt to reserve a DOI for this dataset.")
            }

        });

    });


    var boxSelect = new BoxSelect();
    // Register a success callback handler
    boxSelect.success(function (response) {
        $('#files').css("display", "block");
        $('#collapseFiles').collapse('show');

        $.each(response, function (i, boxItem) {

            if (filename_isdup(boxItem.name)) {
                alert("Duplicate file error: A file named " + boxItem.name + " is already in this dataset.  For help, please contact the Research Data Service.");
            } else {
                boxItem.dataset_key = dataset_key;
                window.onbeforeunload = confirmOnPageExit;
                $.ajax({
                    type: "POST",
                    url: "/datafiles/create_from_url",
                    data: boxItem,
                    success: function (data) {
                        eval($(data).text());
                    },
                    dataType: 'script'
                });
            }

        });

    });

    // Register a cancel callback handler
    boxSelect.cancel(function () {
        console.log("The user clicked cancel or closed the popup");
    });

    $('#box-upload-in-progress').hide();


}


var Reflector = function (obj) {
    this.getProperties = function () {
        var properties = [];
        for (var prop in obj) {
            if (typeof obj[prop] != 'function') {
                properties.push(prop);
            }
        }
        return properties;
    };
}

function pad(n) {
    return n < 10 ? '0' + n : n
}

function cancelBoxUpload(datafile, job) {

    $.getJSON( '/datasets/' + dataset_key + '/datafiles/' + datafile + '/cancel_box_upload' )
        .done(function() {
            $("#job" + job).remove();
        })
        .fail(function() {
            console.log( "cancel failed, see server log" );
        });
}

function setDepositor(email, name) {

    $('#depositor_email').val(email);
    $('#depositor_name').val(name);
    $('.save').show();
    $('.new-dataset-progress').show();
    $('.dataset').removeAttr("disabled");
    $('.file-field').removeAttr("disabled");
    $('.add-attachment-subform-button').show();
    $('.deposit-agreement-warning').hide();

    //$('#show-agreement-modal-link').hide();
}

function handleAgreeModal(email, name) {

    if ($('#owner-yes').is(":checked") && $('#agree-yes').is(":checked") && ($('#private-yes').is(":checked") || $('#private-na').is(":checked"))) {
        setDepositor(email, name);
        $('#new_dataset').submit();
    } else {
        // should not get here
        $('#agree-button').prop("disabled", true);
    }
}


function handlePrivateYes() {
    if ($('#private-yes').is(':checked')) {
        $('#dataset_removed_private').val('yes');
        $('#review_link').html('<a href="/review_deposit_agreement?removed=yes" target="_blank">Review Deposit Agreement</a>');
        $('#private-na').attr('checked', false);
        $('#private-no').attr('checked', false);
        if (agree_answers_all_yes()) {
            allow_agree_submit();
        }
        if (agree_answers_none_no()) {
            $('.deposit-agreement-selection-warning').hide();
        }
    } else {
        $('#agree-button').prop("disabled", true);
        $('#dataset_removed_private').val('no');
    }
}

function handlePrivateNA() {

    if ($('#private-na').is(':checked')) {
        $('#review_link').html('<a href="/review_deposit_agreement?removed=na" target="_blank">Review Deposit Agreement</a>');
        $('#dataset_removed_private').val('na');
        $('#private-yes').attr('checked', false);
        $('#private-no').attr('checked', false);
        if (agree_answers_all_yes()) {
            allow_agree_submit();
        }
        if (agree_answers_none_no()) {
            $('.deposit-agreement-selection-warning').hide();
        }
    } else {
        $('#agree-button').prop("disabled", true);
        $('#dataset_removed_private').val('no');
    }
}

function handlePrivateNo() {
    if ($('#private-no').is(':checked')) {
        $('#dataset_removed_private').val('no');
        $('#private-na').attr('checked', false);
        $('#private-yes').attr('checked', false);
        $('#agree-button').prop("disabled", true);
        $('.deposit-agreement-selection-warning').show();
    } else {
        if (agree_answers_none_no()) {
            $('.deposit-agreement-selection-warning').hide();
        }
    }
}

function handleOwnerYes() {
    if ($('#owner-yes').is(':checked')) {
        $('#dataset_have_permission').val('yes');
        $('#owner-no').attr('checked', false);
        if (agree_answers_all_yes()) {
            allow_agree_submit();
        }
        if (agree_answers_none_no()) {
            $('.deposit-agreement-selection-warning').hide();
        }
    } else {
        $('#agree-button').prop("disabled", true);
        $('#dataset_have_permission').val('no');
    }
}

function handleOwnerNo() {
    if ($('#owner-no').is(':checked')) {
        $('#dataset_have_permission').val('no');
        $('#owner-yes').attr('checked', false);
        $('#agree-button').prop("disabled", true);
        $('.deposit-agreement-selection-warning').show();
    } else {
        if (agree_answers_none_no()) {
            $('.deposit-agreement-selection-warning').hide();
        }
    }
}

function handleAgreeYes() {
    if ($('#agree-yes').is(':checked')) {
        $('#agree-no').attr('checked', false);
        $('#dataset_agree').val('yes');
        if (agree_answers_all_yes()) {
            allow_agree_submit();
        }
        if (agree_answers_none_no()) {
            $('.deposit-agreement-selection-warning').hide();
        }

    } else {
        $('#agree-button').prop("disabled", true);
        $('#dataset_agree').val('no');
    }
}

function handleAgreeNo() {
    if ($('#agree-no').is(':checked')) {
        $('#dataset_agree').val('no');
        $('#agree-yes').attr('checked', false);
        $('#agree-button').prop("disabled", true);
        $('.deposit-agreement-selection-warning').show();
    } else {
        if (agree_answers_none_no()) {
            $('.deposit-agreement-selection-warning').hide();
        }
    }
}

function agree_answers_all_yes() {
    return (($('#owner-yes').is(':checked')) && (($('#private-yes').is(':checked')) || ($('#private-na').is(':checked'))) && ($('#agree-yes').is(':checked')))
}

function agree_answers_none_no() {
    return !(($('#owner-no').is(':checked')) || ($('#private-no').is(':checked')) || ($('#agree-no').is(':checked')))
}

function allow_agree_submit() {
    $('#agree-button').prop("disabled", false);
    $('.deposit-agreement-selection-warning').hide();
}

function clear_help_form() {
    $('input .help').val('');
}

function validateReleaseDate() {
    var yearFromNow = new Date(new Date().setFullYear(new Date().getFullYear() + 1));
    var releaseDate = new Date($('#dataset_release_date').val());

    if (releaseDate > yearFromNow) {
        alert('The maximum amount of time that data can be delayed for publication is is 1 year.');
        $('#dataset_release_date').val(yearFromNow.getFullYear() + '-' + pad((yearFromNow.getMonth() + 1)) + '-' + pad(yearFromNow.getDate()));
    }
}

function filename_isdup(proposed_name) {
    var returnVal = false;

    $.each($('.bytestream_name'), function (index, value) {

        if (proposed_name == $(value).val()) {
            returnVal = true;
        }
        if ($(value).text() == proposed_name) {
            returnVal = true;
        }
    });

    return returnVal;
}

function offerDownloadLink() {
    var selected_files = $('input[name="selected_files[]"]:checked');
    var web_id_string = "";
    var zip64_threshold = 4000000000;

    $.each(selected_files, function (index, value) {
        if (web_id_string != "") {
            web_id_string = web_id_string + "~";
        }
        web_id_string = web_id_string + $(value).val();
    });
    if (web_id_string != "") {
        $.ajax({
            url: "/datasets/" + dataset_key + "/download_link?",
            data: {"web_ids": web_id_string},
            dataType: 'json',
            success: function (result) {
                if (result.status == 'ok') {
                    $('.download-link').html("<h2><a href='" + result.url + "' target='_blank'>Download</a></h2>");
                    if (Number(result.total_size) > zip64_threshold) {
                        $('.download-help').html("<p>For selections of files larger than 4GB, the zip file will be in zip64 format. To open a zip64 formatted file on OS X (Mac) requires additional software not built into the operating system since version 10.11. Options include 7zX and The Unarchiver. If a Windows system has trouble opening the zip file, 7-Zip can be used.</p>")
                    }
                    $('#downloadLinkModal').modal('show');
                } else {
                    $('.download-link').html("An unexpected error occurred.<br/>Details have been logged for review.<br/><a href='/help' target='_blank'>Contact the Research Data Service Team</a> with any questions.");
                    $('#downloadLinkModal').modal('show');
                }
            },
            error: function (xhr, ajaxOptions, thrownError) {
                console.log(xhr.status);
                console.log(thrownError);
                $('.download-link').html("An unexpected error occurred.<br/>Details have been logged for review.<br/><a href='/help' target='_blank'>Contact the Research Data Service Team</a> with any questions.");
                $('#downloadLinkModal').modal('show');

            }
            //context: document.body
        }).done(function () {
            console.log("done");

        });
    }
}

function openRemoteFileModal() {
    $("#remote-file-modal").modal();
}

function license_change_warning() {
    $("#licenseChangeModal").modal();
}

function suppressChangelog() {
    if (window.confirm("Are you sure?")) {
        $('#suppression_action').val("suppress_changelog");
        $('#suppression_form').submit();
    }
}

function unsuppressChangelog() {
    if (window.confirm("Are you sure?")) {
        $('#suppression_action').val("unsuppress_changelog");
        $('#suppression_form').submit();
    }
}

function tmpSuppressFiles() {

    if (window.confirm("Are you sure?")) {
        $('#suppression_action').val("temporarily_suppress_files");
        $('#suppression_form').submit();
    }
}

function tmpSuppressMetadata() {
    if (window.confirm("Are you sure?")) {
        $('#suppression_action').val("temporarily_suppress_metadata");
        $('#suppression_form').submit();
    }
}

function unsuppress() {
    if (window.confirm("Are you sure?")) {
        $('#suppression_action').val("unsuppress");
        $('#suppression_form').submit();
    }
}

function permSuppressFiles() {
    if (window.confirm("Are you sure?")) {
        $('#suppression_action').val("permanently_suppress_files");
        $('#suppression_form').submit();
    }
}

function permSuppressMetadata() {
    if (window.confirm("Are you sure?")) {
        $('#suppression_action').val("permanently_suppress_metadata");
        $('#suppression_form').submit();
    }
}

function update_and_publish() {
    $("[id^=edit_dataset]").append("<input type='hidden' name='context' value='publish' />");
    window.onbeforeunload = null;
    $("[id^=edit_dataset]").submit();
}

function confirm_update() {

    // using patch because that method designation is in the form already
    if ($(".invalid-email").length > 0) {
        alert("Email address must be in a valid format.");
        $(".invalid-email").first().focus();
        return
    }
    if ($(".invalid-name").length > 0) {
        alert("All names must be complete.");
        $(".invalid-name > input").first().focus();
        return
    }

    $('#validation-warning').empty();
    $.ajax({
        url: '/datasets/' + dataset_key + '/validate_change2published',
        type: 'patch',
        data: $("[id^=edit_dataset]").serialize(),
        datatype: 'json',
        success: function (data) {

            if (data.message == "ok") {
                reset_confirm_msg();
                $('#deposit').modal('show');
            } else {
                $('#validation-warning').html('<div class="alert alert-alert">' + data.message + '</div>');
                $('#update-confirm').prop('disabled', true);
            }

        }
    });
}

/*function confirm_update(){
 if ($(".invalid-input").length == 0) {
 reset_confirm_msg();
 $('#deposit').modal('show');
 } else {
 alert("Email address must be in a valid format.");
 $(".invalid-input").first().focus();
 }
 }*/

function show_release_date() {
    $('#release-date-picker').show();
}

function reset_confirm_msg() {

    if ($('.publish-msg').html() != undefined && $('.publish-msg').html().length > 0) {
        var new_embargo = $('#dataset_embargo').val();
        var release_date = $('#dataset_release_date').val();

        $.getJSON("/datasets/" + dataset_key + "/confirmation_message?new_embargo_state=" + new_embargo + "&release_date=" + release_date, function (data) {
            $('.publish-msg').html(data.message);
        })
            .fail(function (xhr, textStatus, errorThrown) {
                console.log("error" + textStatus);
                console.log(xhr.responseText);
            });
    } else {
        console.log("publish-msg element not found");
    }

}

function clear_alert_message() {

    $('#read-only-alert-text').val("");
    //$('.edit_admin').submit();
}

function getNewToken() {
    $.getJSON("/datasets/" + dataset_key + "/get_new_token", function (data) {
        window.has_current_token = true;
        $('#token-header').text('Here is your new token:');
        setTokenExamples(data.token, data.expires);
    });
}

function setTokenExamples(upload_token, token_expiration) {
    $('.current-token').html("<p><strong>Current HTTP Authentication Token: </strong>" + upload_token + "<br/><strong>Expires:</strong> " + (new Date(token_expiration)).toISOString() + "</p>");
    $('#token-button-text').text('View token for command line tools');

    if (rails_env==="development") {
        $('.command-to-copy').html("<pre><code>python databank_api_client_v2.py " + dataset_key + " " + upload_token + " myfile.csv development</code></pre>");
        $('.curl-to-copy').html("<pre><code>curl -F &quot;binary=@my_datafile.csv&quot; -H &quot;Authorization: Token token=" + upload_token + "&quot; -H &quot;Transfer-Encoding: chunked&quot; -X POST https://rds-dev.library.illinois.edu/api/dataset/" + dataset_key + "/datafile -o output.txt -k</code></pre>");
    } else if (rails_env==="aws-production") {
        $('.command-to-copy').html("<pre><code>python databank_api_client_v2.py " + dataset_key + " " + upload_token + " myfile.csv aws_test</code></pre>");
        $('.curl-to-copy').html("<pre><code>curl -F &quot;binary=@my_datafile.csv&quot; -H &quot;Authorization: Token token=" + upload_token + "&quot; -H &quot;Transfer-Encoding: chunked&quot; -X POST https://databank.illinois.edu/api/dataset/" + dataset_key + "/datafile -o output.txt</code></pre>");
    } else if (rails_env==="aws-demo") {
        $('.command-to-copy').html("<pre><code>python databank_api_client_v2.py " + dataset_key + " " + upload_token + " myfile.csv</code></pre>");
        $('.curl-to-copy').html("<pre><code>curl -F &quot;binary=@my_datafile.csv&quot; -H &quot;Authorization: Token token=" + upload_token + "&quot; -H &quot;Transfer-Encoding: chunked&quot; -X POST https://demo.databank.illinois.edu/api/dataset/" + dataset_key + "/datafile -o output.txt</code></pre>");
    } else {
        $('.command-to-copy').html("<p>Please <a (href='/help#contact' target='_blank')>contact the Research Data Service Team</a> for assistance.</p>");
        $('.curl-to-copy').html("<p>Please <a (href='/help#contact' target='_blank')>contact the Research Data Service Team</a> for assistance.</p>");}
}

function cancelUpload() {

    console.log("inside cancel upload");

    if (!event) {
        event = window.event; // Older versions of IE use
                              // a global reference
                              // and not an argument.
    }
    var el = (event.target || event.srcElement); // DOM uses 'target';
    // older versions of
    // IE use 'srcElement'

    $(el).parent().remove();
}

function deleteSelected() {

    var numChecked = $('input.checkFile:checked').length;

    if (window.confirm("Are you sure?")) {

        $('.checkFileSelectedCount').html('(' + numChecked + ')');
        $('#checkAllFiles').prop('checked', false);

        $.each($("input[name='selected_files[]']:checked"), function () {
            remove_file_row_pre_confirm($(this).val());
        });
    }
}

function handleCheckFileGroupChange() {

    var numChecked = $('input.checkFile:checked').length;

    if (typeof numChecked === 'undefined' || isNaN(numChecked) || numChecked < 1) {
        numChecked = 0;
    }


    $(".checkFileSelectedCount").html('(' + numChecked + ')');
    $('#checkAllFiles').prop('checked', false);
}

function handleKeywordKeyup() {
    var keywordString = $('#keyword-text').val();
    keywordArr = keywordString.split(";");
    var keyword_count = keywordArr.length;

    $.each(keywordArr, function (index, keyword) {
        if ((keyword.trim()).length < 1) {
            keyword_count = keyword_count - 1;
        }
    });

    if (keyword_count > 0) {
        $('#keyword-label').html("Keywords (" + keyword_count + " -- semicolon separated)");
    } else {
        $('#keyword-label').html("Keywords");
        $('#keyword-text').attr("placeholder", "[Semicolon separated list of keywords or phrases, e.g.: institutional repositories; file formats]")
    }
}

function setOrgCreators(dataset_id, new_value) {
    if (window.confirm("Are you sure?")) {
        window.onbeforeunload = null;
        $('#dataset_org_creators').val(new_value);
        window.onbeforeunload = null;
        $('#edit_dataset_' + dataset_id).submit();
    }
}

function addInternalReviewerRow(){
    var netid = $("#newInternalReviewer").val();
    var reviewerRow ="<div class='row'><div class='col-md-1'><div class='pull-right'><input name='internal_reviewer[]' type='checkbox' value='" + netid + "' checked='checked'></div></div><div class='col-md-3'>"+ netid +"</div>"
    $(reviewerRow).prependTo("#newInternalReviewersDiv");
    $("#newInternalReviewer").val("");
}

function addInternalEditorRow(){
    var netid = $("#newInternalEditor").val();
    var reviewerRow ="<div class='row'><div class='col-md-1'><div class='pull-right'><input name='internal_editor[]' type='checkbox' value='" + netid + "' checked='checked'></div></div><div class='col-md-3'>"+ netid +"</div>"
    $(reviewerRow).prependTo("#newInternalEditorsDiv");
    $("#newInternalEditor").val("");
}

$(document).ready(ready);
$(document).on('page:load', ready);
