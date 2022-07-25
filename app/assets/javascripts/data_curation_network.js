var dcn_ready;
dcn_ready = function () {

    $(".dcn-contact").click(function () {
        window.location.href = "mailto:researchdata@illinois.library.illinois.edu"
    });

    $(".dcn-login").click(function () {
        window.location.href = "/data_curation_network/login"
    });

    $(".dcn-home").click(function () {
        window.location.href = "/data_curation_network"
    });

    $(".dcn-datasets").click(function () {
        window.location.href = "/data_curation_network/datasets"
    });
    $(".dcn-account").click(function () {
        window.location.href = "/data_curation_network/my_account"
    });
    $(".dcn-accounts").click(function () {
        window.location.href = "/data_curation_network/accounts"
    });

}
$(document).ready(dcn_ready);
$(document).on('page:load', dcn_ready);