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

    jQuery('.bytestream_name').css("visibility", "hidden");

    jQuery('.deposit-agreement-warning').hide();

    jQuery('.deposit-agreement-selection-warning').hide();
    jQuery('#agree-button').prop("disabled", true);


    jQuery("#publish-then-review-btn").click(function () {

        jQuery('#offer_review_h').modal('hide');
        jQuery('#deposit').modal('show');

    });

    jQuery("#review-then-publish-btn").click(function () {

        jQuery('#offer_review_h').modal('hide');
        window.location.href = "/datasets/" + dataset_key + "/request_review"

    });
    jQuery("#review-version-btn").click(function () {
        window.location.href = "/datasets/" + dataset_key + "/request_review"
    });

    jQuery(".choose_review_block_v").click(function () {
        jQuery('#choose_review_v').trigger("click");
    });


    jQuery(".choose_continue_block_v").click(function () {
        jQuery('#choose_continue_v').trigger("click");
    });

    jQuery(".choose_review_block_h").click(function () {
        jQuery('#choose_review_h').trigger("click");
    });


    jQuery(".choose_continue_block_h").click(function () {
        jQuery('#choose_continue_h').trigger("click");
    });


    jQuery('#keyword-text').keyup(handleKeywordKeyup);
    jQuery('#keyword-text').blur(handleKeywordKeyup);

    // handle non-chrome datepicker:
    if (!Modernizr.inputtypes.date) {
        jQuery("#dataset_release_date").prop({type: "text"});
        jQuery("#dataset_release_date").prop({placeholder: "YYYY-MM-DD"});
        jQuery("#dataset_release_date").prop({"data-mask": "9999-99-99"});

        jQuery("#dataset_release_date").datepicker({
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
    var moretext = "more description";
    var lesstext = "less description";
    jQuery('.more').each(function () {
      var content = jQuery(this).html();

      if (content.length > showChar) {

        var c = content.substr(0, showChar);
        var h = content.substr(showChar, content.length - showChar);

        var html = c + '<span class="moreellipses">' + ellipsestext + '&nbsp;</span><span class="morecontent"><span>' + h + '</span>&nbsp;&nbsp;<a href="" class="morelink">' + moretext + '</a></span>';

        jQuery(this).html(html);
      }

    });

    jQuery(".morelink").click(function () {
      if (jQuery(this).hasClass("less")) {
        jQuery(this).removeClass("less");
        jQuery(this).html(moretext);
      } else {
        jQuery(this).addClass("less");
        jQuery(this).html(lesstext);

        // move focus to the anchor with the dataset-link class that comes before this element
        var $moreclasses = jQuery(this).parent().parent().attr('class');
        var morekey = $moreclasses.replace('more', '').trim();
        var $focusElement = jQuery('#link' + morekey);
        if ($focusElement.length) {
            $focusElement.focus();
        } else {
          console.log("Focus element not found.");
          console.log("Focus element with id link" + morekey + " not found.");
        }
      }
      jQuery(this).parent().prev().toggle();
      jQuery(this).prev().toggle();
      return false;
    });

    jQuery(".upload-consistent").tooltip({
        html: "true",
        title: "<em>consistent</em>--Reliable performance for a variety of connection speeds and configurations."
    });

    jQuery(".upload-inconsistent").tooltip({
        html: "true",
        title: "<em>inconsistent</em>--Depends for reliability on connection strength and speed. Works well on campus, but home and coffee-shop environments vary."
    });

    jQuery(".upload-unavailable").tooltip({
        html: "true",
        title: "<em>unavailable</em>--Either does not work at all, or is so unreliable as to be inadvisable. </td> </tr> </table> </table>"
    });

    jQuery(".clipboard-btn").tooltip({
        html: "false",
        title: "copy to clipboard"
    });

    jQuery(".remove-share-btn").tooltip({
        html: "false",
        title: "remove sharing link"
    });

    var numChecked = jQuery('input.checkFile:checked').length;

    jQuery(".checkFileSelectedCount").html('(' + numChecked + ')');

    jQuery("#checkAllFiles").click(function () {
        jQuery(".checkFileGroup").prop('checked', jQuery(this).prop('checked'));

        var numChecked = jQuery('input.checkFile:checked').length;

        jQuery(".checkFileSelectedCount").html("(" + numChecked + ")");
    });

    jQuery("#checkAllVFiles").click(function () {
        jQuery(".checkVFileGroup").prop('checked', jQuery(this).prop('checked'));
    });

    jQuery('#term-supports').tooltip();

    jQuery('#cancel-button').click(function () {
        // alert("You must agree to the Deposit Agreement before depositing data into Illinois Data Bank.");
        handleNotAgreed();
    });

    jQuery('#dropdown-login').click(function (event) {
        if (event.stopPropagation) {
            event.stopPropagation();
        } else if (window.event) {
            window.event.cancelBubble = true;
        }
    });

    jQuery('#new-exit-button').click(function () {
        jQuery('#new_dataset').append("<input type='hidden' name='context' value='exit' />");
        window.onbeforeunload = null;
        jQuery('#new_dataset').submit();
    });

    jQuery('#update_datafile').click(function () {
        window.onbeforeunload = null;
        jQuery('.edit_datafile').submit();
    });

    jQuery('.new-save').hide();

    jQuery('.preview').hide();
    jQuery('.markdown_preview').hide();

    jQuery('.nav-item').click(function () {

        jQuery('.nav-item').removeClass('current');
        jQuery(this).addClass('current');
    });

    jQuery('#update-save-button').click(function () {
        if (jQuery(".invalid-name").length > 0) {
            alert("All names must be complete.");
            jQuery(".invalid-name > input").first().focus();
            return
        }
        if (jQuery(".progress-bar").length == 0) {
            window.onbeforeunload = null;
            jQuery("[id^=edit_dataset]").submit();
        } else {
            alert("UPLOADS IN PROGRESS. Try again once uploads are complete.")
        }
    });

    jQuery('#update-confirm').prop('disabled', true);

    jQuery("[id^=edit_dataset] :input").keyup(function () {
        jQuery('#update-confirm').prop('disabled', false);
    });

    jQuery("[id^=edit_dataset] :input").change(function () {
        jQuery('#update-confirm').prop('disabled', false);
    });

    jQuery('#save-exit-button').click(function () {

        if (jQuery(".invalid-email").length == 0) {

            if (jQuery(".progress-bar").length == 0) {

                jQuery("[id^=edit_dataset]").append("<input type='hidden' name='context' value='exit' />");
                window.onbeforeunload = null;
                jQuery("[id^=edit_dataset]").submit();

            } else {
                alert("UPLOADS IN PROGRESS. Try again once uploads are complete.")
            }
        } else {
            alert("Email address must be in a valid format.");
            jQuery(".invalid-email").first().focus();
        }

    });

    jQuery('input.dataset').change(function () {
        if (jQuery(this).val() != "") {
            window.onbeforeunload = confirmOnPageExit;
        }
    });

    //jQuery('.preview').css("visibility", "hidden");

    jQuery('#dataset_title').change(function () {
        if (jQuery("input[name='dataset[publication_state]']").val() == 'draft' || jQuery(this).val() != "") {
            jQuery('#title-preview').html(jQuery(this).val() + '.');
            jQuery('#update-save-button').prop('disabled', false);
        } else {
            alert("Published Dataset must have a title.");
            jQuery('#update-save-button').prop('disabled', true);
        }
    });

    jQuery('#dataset_publication_year').change(function () {
        jQuery('#year-preview').html('(' + jQuery(this).val() + '):');
    });

    jQuery('#dataset_identifier').change(function () {
        jQuery('#doi-preview').html("https://doi.org/" + jQuery(this).val());
    });

    jQuery('#show-all-button').click(function () {
        window.location.assign('/datasets');
    });

    jQuery('#show-my-button').click(function () {
        var current_user_email = jQuery('input#current_user_email').val();
        window.location.assign('/datasets?depositor_email=' + current_user_email);
    });

    jQuery("#chunked-upload-btn").click(function () {
        window.location.assign('/datasets/' + dataset_key + '/datafiles/add');
    });

    jQuery("#portable-upload").click(function () {
        window.location.assign('/help?context=pickup&key=' + dataset_key);
    });

    if (!jQuery('#dataset_embargo').val()) {

        jQuery('#release-date-picker').hide();
    }

    jQuery("#dataset_embargo").change(function () {
        jQuery('#update-confirm').prop('disabled', false);
        switch (jQuery(this).val()) {
            case 'file embargo':
                jQuery('#release-date-picker').show();
                break;
            case 'metadata embargo':
                jQuery('#release-date-picker').show();
                break;
            default:
                jQuery('#dataset_release_date').val('');
                jQuery('#release-date-picker').hide();
        }
    });

    jQuery('[data-toggle="tooltip"]').tooltip();

    var clip = new Clipboard('.clipboard-btn');

    jQuery("#login-prompt").modal('show');
    //alert("pre-validity check");
    //alert("dataset key: "+ dataset_key)

    jQuery("#api-modal-btn").click(function () {

        jQuery.getJSON("/datasets/" + dataset_key + "/get_current_token", function (data) {
            if (data.token && data.token != "none") {
                jQuery('#token-header').text('Here is your token:');
                setTokenExamples(data.token);
            } else {
                getNewToken();
            }

        });

        jQuery("#api_modal").modal('show');
    });

    jQuery("#reserve-doi-btn").click(function () {

        jQuery.getJSON("/datasets/" + dataset_key + "/reserve_doi", function (data) {
            if (data.status && data.status == "ok") {

                jQuery("#deposit").modal('show');

                jQuery("#your-doi-here").html("We've reserved a DOI for you: " + data.doi + ", but your dataset is not yet published.");

            } else {
                alert("We're sorry, something went wrong during an attempt to reserve a DOI for this dataset.")
            }

        });

    });


    // var boxSelect = new BoxSelect();
    // Register a success callback handler
    // boxSelect.success(function (response) {
    //     jQuery('#files').css("display", "block");
    //     jQuery('#collapseFiles').collapse('show');
    //
    //     jQuery.each(response, function (i, boxItem) {
    //
    //         if (filename_isdup(boxItem.name)) {
    //             alert("Duplicate file error: A file named " + boxItem.name + " is already in this dataset.  For help, please contact the Research Data Service.");
    //         } else {
    //             boxItem.dataset_key = dataset_key;
    //             window.onbeforeunload = confirmOnPageExit;
    //             jQuery.ajax({
    //                 type: "POST",
    //                 url: "/datafiles/create_from_url",
    //                 data: boxItem,
    //                 success: function (data) {
    //                     eval(jQuery(data).text());
    //                 },
    //                 dataType: 'script'
    //             });
    //         }
    //
    //     });
    //
    // });
    //
    // // Register a cancel callback handler
    // boxSelect.cancel(function () {
    //     console.log("The user clicked cancel or closed the popup");
    // });
    //
    // jQuery('#box-upload-in-progress').hide();


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

function setDepositor(email, name) {

    jQuery('#depositor_email').val(email);
    jQuery('#depositor_name').val(name);
    jQuery('.save').show();
    jQuery('.new-dataset-progress').show();
    jQuery('.dataset').removeAttr("disabled");
    jQuery('.file-field').removeAttr("disabled");
    jQuery('.add-attachment-subform-button').show();
    jQuery('.deposit-agreement-warning').hide();

    //jQuery('#show-agreement-modal-link').hide();
}

function handleAgreeModal(email, name) {

    if (jQuery('#owner-yes').is(":checked") && jQuery('#agree-yes').is(":checked") && (jQuery('#private-yes').is(":checked") || jQuery('#private-na').is(":checked"))) {
        setDepositor(email, name);
        jQuery('#new_dataset').submit();
    } else {
        // should not get here
        jQuery('#agree-button').prop("disabled", true);
    }
}


function handlePrivateYes() {
    if (jQuery('#private-yes').is(':checked')) {
        jQuery('#dataset_removed_private').val('yes');
        jQuery('#review_link').html('<a href="/datasets/review_deposit_agreement?removed=yes" target="_blank">Review Deposit Agreement</a>');
        jQuery('#private-na').attr('checked', false);
        jQuery('#private-no').attr('checked', false);
        if (agree_answers_all_yes()) {
            allow_agree_submit();
        }
        if (agree_answers_none_no()) {
            jQuery('.deposit-agreement-selection-warning').hide();
        }
    } else {
        jQuery('#agree-button').prop("disabled", true);
        jQuery('#dataset_removed_private').val('no');
    }
}

function handlePrivateNA() {

    if (jQuery('#private-na').is(':checked')) {
        jQuery('#review_link').html('<a href="/datasets/review_deposit_agreement?removed=na" target="_blank">Review Deposit Agreement</a>');
        jQuery('#dataset_removed_private').val('na');
        jQuery('#private-yes').attr('checked', false);
        jQuery('#private-no').attr('checked', false);
        if (agree_answers_all_yes()) {
            allow_agree_submit();
        }
        if (agree_answers_none_no()) {
            jQuery('.deposit-agreement-selection-warning').hide();
        }
    } else {
        jQuery('#agree-button').prop("disabled", true);
        jQuery('#dataset_removed_private').val('no');
    }
}

function handlePrivateNo() {
    if (jQuery('#private-no').is(':checked')) {
        jQuery('#dataset_removed_private').val('no');
        jQuery('#private-na').attr('checked', false);
        jQuery('#private-yes').attr('checked', false);
        jQuery('#agree-button').prop("disabled", true);
        jQuery('.deposit-agreement-selection-warning').show();
    } else {
        if (agree_answers_none_no()) {
            jQuery('.deposit-agreement-selection-warning').hide();
        }
    }
}

function handleOwnerYes() {
    if (jQuery('#owner-yes').is(':checked')) {
        jQuery('#dataset_have_permission').val('yes');
        jQuery('#owner-no').attr('checked', false);
        if (agree_answers_all_yes()) {
            allow_agree_submit();
        }
        if (agree_answers_none_no()) {
            jQuery('.deposit-agreement-selection-warning').hide();
        }
    } else {
        jQuery('#agree-button').prop("disabled", true);
        jQuery('#dataset_have_permission').val('no');
    }
}

function handleOwnerNo() {
    if (jQuery('#owner-no').is(':checked')) {
        jQuery('#dataset_have_permission').val('no');
        jQuery('#owner-yes').attr('checked', false);
        jQuery('#agree-button').prop("disabled", true);
        jQuery('.deposit-agreement-selection-warning').show();
    } else {
        if (agree_answers_none_no()) {
            jQuery('.deposit-agreement-selection-warning').hide();
        }
    }
}

function handleAgreeYes() {
    if (jQuery('#agree-yes').is(':checked')) {
        jQuery('#agree-no').attr('checked', false);
        jQuery('#dataset_agree').val('yes');
        if (agree_answers_all_yes()) {
            allow_agree_submit();
        }
        if (agree_answers_none_no()) {
            jQuery('.deposit-agreement-selection-warning').hide();
        }

    } else {
        jQuery('#agree-button').prop("disabled", true);
        jQuery('#dataset_agree').val('no');
    }
}

function handleAgreeNo() {
    if (jQuery('#agree-no').is(':checked')) {
        jQuery('#dataset_agree').val('no');
        jQuery('#agree-yes').attr('checked', false);
        jQuery('#agree-button').prop("disabled", true);
        jQuery('.deposit-agreement-selection-warning').show();
    } else {
        if (agree_answers_none_no()) {
            jQuery('.deposit-agreement-selection-warning').hide();
        }
    }
}

function agree_answers_all_yes() {
    return ((jQuery('#owner-yes').is(':checked')) && ((jQuery('#private-yes').is(':checked')) || (jQuery('#private-na').is(':checked'))) && (jQuery('#agree-yes').is(':checked')))
}

function agree_answers_none_no() {
    return !((jQuery('#owner-no').is(':checked')) || (jQuery('#private-no').is(':checked')) || (jQuery('#agree-no').is(':checked')))
}

function allow_agree_submit() {
    jQuery('#agree-button').prop("disabled", false);
    jQuery('.deposit-agreement-selection-warning').hide();
}

function clear_help_form() {
    jQuery('input .help').val('');
}

function validateReleaseDate() {
    var yearFromNow = new Date(new Date().setFullYear(new Date().getFullYear() + 1));
    var releaseDate = new Date(jQuery('#dataset_release_date').val());

    if (releaseDate > yearFromNow) {
        alert('The maximum amount of time that data can be delayed for publication is is 1 year.');
        jQuery('#dataset_release_date').val(yearFromNow.getFullYear() + '-' + pad((yearFromNow.getMonth() + 1)) + '-' + pad(yearFromNow.getDate()));
    }
}

function filename_isdup(proposed_name) {
    var returnVal = false;

    jQuery.each(jQuery('.bytestream_name'), function (index, value) {

        if (proposed_name == jQuery(value).val()) {
            returnVal = true;
        }
        if (jQuery(value).text() == proposed_name) {
            returnVal = true;
        }
    });

    return returnVal;
}

function offerDownloadLink() {
    var selected_files = jQuery('input[name="selected_files[]"]:checked');
    var web_id_string = "";
    var zip64_threshold = 4000000000;

    jQuery.each(selected_files, function (index, value) {
        if (web_id_string !== "") {
            web_id_string = web_id_string + "~";
        }
        web_id_string = web_id_string + jQuery(value).val();
    });
    if (web_id_string !== "") {
        jQuery.ajax({
            url: "/datasets/" + dataset_key + "/download_link?",
            data: {"web_ids": web_id_string},
            dataType: 'json',
            success: function (result) {
                if (result.status === 'ok') {
                    jQuery('.download-link').html("<h2><a href='" + result.url + "' target='_blank'>Download</a></h2>");
                    if (Number(result.total_size) > zip64_threshold) {
                        jQuery('.download-help').html("<p>For selections of files larger than 4GB, the zip file will be in zip64 format. To open a zip64 formatted file on OS X (Mac) requires additional software not built into the operating system since version 10.11. Options include 7zX and The Unarchiver. If a Windows system has trouble opening the zip file, 7-Zip can be used.</p>")
                    }
                    jQuery('#downloadLinkModal').modal('show');
                } else {
                    console.log(result);
                    jQuery('.download-link').html("An unexpected error occurred.<br/>Details have been logged for review.<br/><a href='/help' target='_blank'>Contact the Research Data Service Team</a> with any questions.");
                    jQuery('#downloadLinkModal').modal('show');
                }
            },
            error: function (xhr, ajaxOptions, thrownError) {
                console.log("error in offering download link");
                console.log(xhr.status);
                console.log(thrownError);
                jQuery('.download-link').html("An unexpected error occurred.<br/>Details have been logged for review.<br/><a href='/help' target='_blank'>Contact the Research Data Service Team</a> with any questions.");
                jQuery('#downloadLinkModal').modal('show');

            }
            //context: document.body
        }).done(function () {
            console.log("done");
        });
    }
}

function openRemoteFileModal() {
    jQuery("#remote-file-modal").modal();
}

function license_change_warning() {
    jQuery("#licenseChangeModal").modal();
}

function suppressChangelog() {
    if (window.confirm("Are you sure?")) {
        jQuery('#suppression_action').val("suppress_changelog");
        jQuery('#suppression_form').submit();
    }
}

function unsuppressChangelog() {
    if (window.confirm("Are you sure?")) {
        jQuery('#suppression_action').val("unsuppress_changelog");
        jQuery('#suppression_form').submit();
    }
}

function tmpSuppressFiles() {
    if (window.confirm("Are you sure?")) {
        jQuery('#suppression_action').val("temporarily_suppress_files");
        jQuery('#suppression_form').submit();
    }
}

function tmpSuppressMetadata() {
    if (window.confirm("Are you sure?")) {
        jQuery('#suppression_action').val("temporarily_suppress_metadata");
        jQuery('#suppression_form').submit();
    }
}

function unsuppressReview() {
    if (window.confirm("Are you sure?")) {
        jQuery('#suppression_action').val("unsuppress_review");
        jQuery('#suppression_form').submit();
    }
}
function suppressReview() {
    if (window.confirm("Are you sure?")) {
        jQuery('#suppression_action').val("suppress_review");
        jQuery('#suppression_form').submit();
    }
}

function version2draft() {
    if (window.confirm("Are you sure?")) {
        jQuery('#suppression_action').val("version_to_draft");
        jQuery('#suppression_form').submit();
    }
}

function draft2version() {
    if (window.confirm("Are you sure?")) {
        jQuery('#suppression_action').val("draft_to_version");
        jQuery('#suppression_form').submit();
    }
}

function unsuppress() {
    if (window.confirm("Are you sure?")) {
        jQuery('#suppression_action').val("unsuppress");
        jQuery('#suppression_form').submit();
    }
}

function permSuppressFiles() {
    if (window.confirm("Are you sure?")) {
        jQuery('#suppression_action').val("permanently_suppress_files");
        jQuery('#suppression_form').submit();
    }
}

function permSuppressMetadata() {
    if (window.confirm("Are you sure?")) {
        jQuery('#suppression_action').val("permanently_suppress_metadata");
        jQuery('#suppression_form').submit();
    }
}

function update_and_publish() {
    jQuery("[id^=edit_dataset]").append("<input type='hidden' name='context' value='publish' />");
    window.onbeforeunload = null;
    jQuery("[id^=edit_dataset]").submit();
}

function confirm_update() {

    // using patch because that method designation is in the form already
    if (jQuery(".invalid-email").length > 0) {
        alert("Email address must be in a valid format.");
        jQuery(".invalid-email").first().focus();
        return
    }
    if (jQuery(".invalid-name").length > 0) {
        alert("All names must be complete.");
        jQuery(".invalid-name > input").first().focus();
        return
    }

    jQuery('#validation-warning').empty();
    jQuery.ajax({
        url: '/datasets/' + dataset_key + '/validate_change2published',
        type: 'patch',
        data: jQuery("[id^=edit_dataset]").serialize(),
        datatype: 'json',
        success: function (data) {

            if (data.message === "ok") {
                reset_confirm_msg();
                jQuery('#deposit').modal('show');
            } else {
                jQuery('#validation-warning').html('<div class="alert alert-alert">' + data.message + '</div>');
                jQuery('#update-confirm').prop('disabled', true);
            }

        }
    });
}

/*function confirm_update(){
 if (jQuery(".invalid-input").length == 0) {
 reset_confirm_msg();
 jQuery('#deposit').modal('show');
 } else {
 alert("Email address must be in a valid format.");
 jQuery(".invalid-input").first().focus();
 }
 }*/

function show_release_date() {
    jQuery('#release-date-picker').show();
}

function reset_confirm_msg() {

    if (jQuery('.publish-msg').html() != undefined && jQuery('.publish-msg').html().length > 0) {
        var new_embargo = jQuery('#dataset_embargo').val();
        var release_date = jQuery('#dataset_release_date').val();

        jQuery.getJSON("/datasets/" + dataset_key + "/confirmation_message?new_embargo_state=" + new_embargo + "&release_date=" + release_date, function (data) {
            jQuery('.publish-msg').html(data.message);
        })
            .fail(function (xhr, textStatus, errorThrown) {
                console.log("error" + textStatus);
                console.log(xhr.responseText);
            });
    } else {
        console.log("publish-msg element not found");
    }

}

function clear_msg_middle() {

    jQuery('#msg_middle').val("");
    //jQuery('.edit_admin').submit();
}

function getNewToken() {
    jQuery.getJSON("/datasets/" + dataset_key + "/get_new_token", function (data) {
        window.has_current_token = true;
        jQuery('#token-header').text('Here is your new token:');
        setTokenExamples(data.token);
    });
}

function setTokenExamples(upload_token) {
    jQuery('.current-token').html("<p><strong>Current HTTP Authentication Token: </strong>" + upload_token);
    jQuery('#token-button-text').text('View token for command line tools');
    jQuery('.command-to-copy').html("<pre><code>python databank_api_client_v2.py " + dataset_key + " " + upload_token + " myfile.csv</code></pre>");
    jQuery('.curl-to-copy').html("<pre><code>curl -F &quot;binary=@my_datafile.csv&quot; -H &quot;Authorization: Token token=" + upload_token + "&quot; -H &quot;Transfer-Encoding: chunked&quot; -X POST https://databank.illinois.edu/api/dataset/" + dataset_key + "/datafile -o output.txt</code></pre>");
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

    jQuery(el).parent().remove();
}

function deleteSelected() {

    var numChecked = jQuery('input.checkFile:checked').length;

    if (window.confirm("Are you sure?")) {

        jQuery('.checkFileSelectedCount').html('(' + numChecked + ')');
        jQuery('#checkAllFiles').prop('checked', false);

        jQuery.each(jQuery("input[name='selected_files[]']:checked"), function () {
            remove_file_row_pre_confirm(jQuery(this).val());
        });
    }
}

function handleCheckFileGroupChange() {

    var numChecked = jQuery('input.checkFile:checked').length;

    if (typeof numChecked === 'undefined' || isNaN(numChecked) || numChecked < 1) {
        numChecked = 0;
    }


    jQuery(".checkFileSelectedCount").html('(' + numChecked + ')');
    jQuery('#checkAllFiles').prop('checked', false);
}

function handleKeywordKeyup() {
    var keywordString = jQuery('#keyword-text').val();
    keywordArr = keywordString.split(";");
    var keyword_count = keywordArr.length;

    jQuery.each(keywordArr, function (index, keyword) {
        if ((keyword.trim()).length < 1) {
            keyword_count = keyword_count - 1;
        }
    });

    if (keyword_count > 0) {
        jQuery('#keyword-label').html("Keywords (" + keyword_count + " -- semicolon separated)");
    } else {
        jQuery('#keyword-label').html("Keywords");
        jQuery('#keyword-text').attr("placeholder", "[Semicolon separated list of keywords or phrases, e.g.: institutional repositories; file formats]")
    }
}

function setOrgCreators(dataset_id, new_value) {
    if (window.confirm("Are you sure?")) {
        window.onbeforeunload = null;
        jQuery('#dataset_org_creators').val(new_value);
        window.onbeforeunload = null;
        jQuery('#edit_dataset_' + dataset_id).submit();
    }
}

function addReviewerRow(){
    var email = jQuery("#newReviewer").val();
    var reviewerRow ="<div class='row'><div class='col-md-1'><div class='pull-right'><input name='reviewer_emails[]' type='checkbox' value='" + email + "' checked='checked'></div></div><div class='col-md-3'>"+ email +"</div>"
    jQuery(reviewerRow).prependTo("#newReviewersDiv");
    jQuery("#newReviewer").val("");
}

function addInternalEditorRow(){
    var netid = jQuery("#newInternalEditor").val();
    var reviewerRow ="<div class='row'><div class='col-md-1'><div class='pull-right'><input name='internal_editor[]' type='checkbox' value='" + netid + "' checked='checked'></div></div><div class='col-md-3'>"+ netid +"</div>"
    jQuery(reviewerRow).prependTo("#newEditorsDiv");
    jQuery("#newInternalEditor").val("");
}

function importFromGlobus(){
    jQuery.ajax({
        dataType: "json",
        url: "/datasets/" + dataset_key + "/import_from_globus"
    }).done(function(data, textStatus, jqXHR) {
        jQuery('#message').html("<div class='alert alert-alert'><p>Refresh page to see datafiles</p></div>");
    }).fail(function (xhr, textStatus, errorThrown) {
        jQuery('#message').html("<div class='alert alert-alert'><p>Problem ingesting datafiles. " +  xhr.responseText + "</p></div>");
        console.log("error" + textStatus);
        console.log(xhr.responseText);
    });
}

jQuery(document).ready(ready);
jQuery(document).on('page:load', ready);
