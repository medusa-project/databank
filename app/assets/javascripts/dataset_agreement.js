// Deposit agreement flow for the Illinois Data Bank.
// All logic lives under Databank.agreement.
// Global function wrappers are kept in datasets.js so existing
// inline onclick/onchange handlers in views continue to work unchanged.

(function (window) {
    window.Databank = window.Databank || {};

    window.Databank.agreement = {

        // Warning banner ---------------------------------------------------

        showSelectionWarning: function () {
            var html = "<h2>Selection Alert</h2>" +
                "<p><span class='glyphicon glyphicon-alert'></span> " +
                "The selections you have made indicate that you are not ready to " +
                "deposit your dataset.</p>" +
                "<p>Illinois Data Bank curators are available to discuss your dataset " +
                "with you. Please <a href='/contact'>contact us</a>!</p>";
            jQuery('.deposit-agreement-selection-warning').html(html);
        },

        clearSelectionWarning: function () {
            jQuery('.deposit-agreement-selection-warning').html('');
        },

        // State checks -----------------------------------------------------

        allAnswersYes: function () {
            return (
                jQuery('#owner-yes').is(':checked') &&
                (jQuery('#private-yes').is(':checked') || jQuery('#private-na').is(':checked')) &&
                jQuery('#agree-yes').is(':checked')
            );
        },

        noneAnswersNo: function () {
            return !(
                jQuery('#owner-no').is(':checked') ||
                jQuery('#private-no').is(':checked') ||
                jQuery('#agree-no').is(':checked')
            );
        },

        // Submit control ---------------------------------------------------

        allowSubmit: function () {
            jQuery('#agree-button').prop('disabled', false);
            Databank.agreement.clearSelectionWarning();
        },

        // Depositor setup --------------------------------------------------

        setDepositor: function (email, name) {
            jQuery('#depositor_email').val(email);
            jQuery('#depositor_name').val(name);
            jQuery('.save').show();
            jQuery('.new-dataset-progress').show();
            jQuery('.dataset').removeAttr('disabled');
            jQuery('.file-field').removeAttr('disabled');
            jQuery('.add-attachment-subform-button').show();
            Databank.agreement.clearSelectionWarning();
        },

        // Called when the user cancels or the form is shown without a depositor.
        // Previously undefined in the codebase — this is the canonical definition.
        handleNotAgreed: function () {
            jQuery('#agree-button').prop('disabled', true);
            jQuery('.agree').prop('checked', false);
            jQuery('.private-checkbox').prop('checked', false);
            jQuery('#dataset_have_permission').val('no');
            jQuery('#dataset_removed_private').val('no');
            jQuery('#dataset_agree').val('no');
            Databank.agreement.clearSelectionWarning();
        },

        // Modal submit handler ---------------------------------------------

        handleModal: function (email, name) {
            if (
                jQuery('#owner-yes').is(':checked') &&
                jQuery('#agree-yes').is(':checked') &&
                (jQuery('#private-yes').is(':checked') || jQuery('#private-na').is(':checked'))
            ) {
                Databank.agreement.setDepositor(email, name);
                jQuery('#new_dataset').submit();
            } else {
                // should not get here — button is disabled until all boxes are ticked
                jQuery('#agree-button').prop('disabled', true);
            }
        },

        // Radio / checkbox handlers ----------------------------------------

        handleOwnerYes: function () {
            if (jQuery('#owner-yes').is(':checked')) {
                jQuery('#dataset_have_permission').val('yes');
                jQuery('#owner-no').attr('checked', false);
                if (Databank.agreement.allAnswersYes()) { Databank.agreement.allowSubmit(); }
                if (Databank.agreement.noneAnswersNo()) { Databank.agreement.clearSelectionWarning(); }
            } else {
                jQuery('#agree-button').prop('disabled', true);
                jQuery('#dataset_have_permission').val('no');
            }
        },

        handleOwnerNo: function () {
            if (jQuery('#owner-no').is(':checked')) {
                jQuery('#dataset_have_permission').val('no');
                jQuery('#owner-yes').attr('checked', false);
                jQuery('#agree-button').prop('disabled', true);
                Databank.agreement.showSelectionWarning();
            } else {
                if (Databank.agreement.noneAnswersNo()) { Databank.agreement.clearSelectionWarning(); }
            }
        },

        handlePrivateYes: function () {
            if (jQuery('#private-yes').is(':checked')) {
                jQuery('#dataset_removed_private').val('yes');
                jQuery('#review_link').html(
                    '<a href="/datasets/review_deposit_agreement?removed=yes" target="_blank">' +
                    'Review Deposit Agreement</a>'
                );
                jQuery('#private-na').attr('checked', false);
                jQuery('#private-no').attr('checked', false);
                if (Databank.agreement.allAnswersYes()) { Databank.agreement.allowSubmit(); }
                if (Databank.agreement.noneAnswersNo()) { Databank.agreement.clearSelectionWarning(); }
            } else {
                jQuery('#agree-button').prop('disabled', true);
                jQuery('#dataset_removed_private').val('no');
            }
        },

        handlePrivateNA: function () {
            if (jQuery('#private-na').is(':checked')) {
                jQuery('#review_link').html(
                    '<a href="/datasets/review_deposit_agreement?removed=na" target="_blank">' +
                    'Review Deposit Agreement</a>'
                );
                jQuery('#dataset_removed_private').val('na');
                jQuery('#private-yes').attr('checked', false);
                jQuery('#private-no').attr('checked', false);
                if (Databank.agreement.allAnswersYes()) { Databank.agreement.allowSubmit(); }
                if (Databank.agreement.noneAnswersNo()) { Databank.agreement.clearSelectionWarning(); }
            } else {
                jQuery('#agree-button').prop('disabled', true);
                jQuery('#dataset_removed_private').val('no');
            }
        },

        handlePrivateNo: function () {
            if (jQuery('#private-no').is(':checked')) {
                jQuery('#dataset_removed_private').val('no');
                jQuery('#private-na').attr('checked', false);
                jQuery('#private-yes').attr('checked', false);
                jQuery('#agree-button').prop('disabled', true);
                Databank.agreement.showSelectionWarning();
            } else {
                if (Databank.agreement.noneAnswersNo()) { Databank.agreement.clearSelectionWarning(); }
            }
        },

        handleAgreeYes: function () {
            if (jQuery('#agree-yes').is(':checked')) {
                jQuery('#agree-no').attr('checked', false);
                jQuery('#dataset_agree').val('yes');
                if (Databank.agreement.allAnswersYes()) { Databank.agreement.allowSubmit(); }
                if (Databank.agreement.noneAnswersNo()) { Databank.agreement.clearSelectionWarning(); }
            } else {
                jQuery('#agree-button').prop('disabled', true);
                jQuery('#dataset_agree').val('no');
            }
        },

        handleAgreeNo: function () {
            if (jQuery('#agree-no').is(':checked')) {
                jQuery('#dataset_agree').val('no');
                jQuery('#agree-yes').attr('checked', false);
                jQuery('#agree-button').prop('disabled', true);
                Databank.agreement.showSelectionWarning();
            } else {
                if (Databank.agreement.noneAnswersNo()) { Databank.agreement.clearSelectionWarning(); }
            }
        }
    };

})(window);
