var dcn_ready;
dcn_ready = function () {

    jQuery(".dcn-contact").click(function () {
        window.location.href = "mailto:researchdata@illinois.library.illinois.edu"
    });

    jQuery(".dcn-login").click(function () {
        window.location.href = "/data_curation_network/login"
    });

    jQuery(".dcn-home").click(function () {
        window.location.href = "/data_curation_network"
    });

    jQuery(".dcn-datasets").click(function () {
        window.location.href = "/data_curation_network/datasets"
    });
    jQuery(".dcn-account").click(function () {
        window.location.href = "/data_curation_network/my_account"
    });
    jQuery(".dcn-accounts").click(function () {
        window.location.href = "/data_curation_network/accounts"
    });

}
jQuery(document).ready(dcn_ready);
jQuery(document).on('page:load', dcn_ready);