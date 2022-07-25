// work-around turbo links to trigger ready function stuff on every page.

var search_ready;
search_ready = function () {

    setSortStyle();
    // alert("search.js javascript working");
}

function clearFilters(){
    $(".checkFacetGroup").prop("checked",false);
    $("#searchForm").submit();
}


function handleFilterChange() {
    $("#searchForm").submit();
}

function backToSearch() {
  $("input[name='download']").remove();
    $("#searchForm").submit();
}

function generateReport() {

    $("#searchForm").append("<input type='hidden' name='report' value='generate' />");
    $("#searchForm").submit();
}

function downloadCitationReport(){
    $("#searchForm").append("<input type='hidden' name='download' value='now' />");
    $("#searchForm").submit();
}

function clearSearchTerm(){
    $("input[name='q']").val("");
    $("#searchForm").submit();
}

function setSortStyle(){
    var sort_criteria = $("input[name='sort_by']").val();

    $('.btn-sort').removeClass('btn-current-sort');

    switch(sort_criteria) {
        case 'sort_updated_asc':
            $('.updated_asc').addClass('btn-current-sort');
            break;
        case 'sort_updated_desc':
            $('.updated_desc').addClass('btn-current-sort');
            break;
        case 'sort_released_asc':
            $('.released_asc').addClass('btn-current-sort');
            break;
        case 'sort_released_desc':
            $('.released_desc').addClass('btn-current-sort');
            break;
        case 'sort_ingested_asc':
            $('.ingested_asc').addClass('btn-current-sort');
            break;
        case 'sort_ingested_desc':
            $('.ingested_desc').addClass('btn-current-sort');
            break;

        default:
            $('.updated_desc').addClass('btn-current-sort');
    }
}

function set_per_page(){
    $("#searchForm").submit();
}

$(document).ready(search_ready);
$(document).on('page:load', search_ready);