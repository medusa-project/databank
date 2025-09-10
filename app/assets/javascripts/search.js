const search_ready = function () {
    setSortStyle();
    //alert("search.js javascript working");
}
function clearFilters(){
    jQuery(".checkFacetGroup").prop("checked",false);
    jQuery("#searchForm").submit();
}
function handleFilterChange() {
    jQuery("#searchForm").submit();
}
function backToSearch() {
  jQuery("input[name='download']").remove();
    jQuery("#searchForm").submit();
}
function generateReport() {

    jQuery("#searchForm").append("<input type='hidden' name='report' value='generate' />");
    jQuery("#searchForm").submit();
}
function downloadCitationReport(){
    jQuery("#searchForm").append("<input type='hidden' name='download' value='now' />");
    jQuery("#searchForm").submit();
}
function clearSearchTerm(){
    jQuery("input[name='q']").val("");
    jQuery("#searchForm").submit();
}
function setSortStyle(){
    const sort_criteria = jQuery("input[name='sort_by']").val();

    jQuery('.btn-sort').removeClass('btn-current-sort');

    switch(sort_criteria) {
        case 'sort_updated_asc':
            jQuery('.updated_asc').addClass('btn-current-sort');
            break;
        // case 'sort_updated_desc':
        //     jQuery('.updated_desc').addClass('btn-current-sort');
        //     break;
        case 'sort_released_asc':
            jQuery('.released_asc').addClass('btn-current-sort');
            break;
        case 'sort_released_desc':
            jQuery('.released_desc').addClass('btn-current-sort');
            break;
        case 'sort_ingested_asc':
            jQuery('.ingested_asc').addClass('btn-current-sort');
            break;
        case 'sort_ingested_desc':
            jQuery('.ingested_desc').addClass('btn-current-sort');
            break;
        default:
            jQuery('.updated_desc').addClass('btn-current-sort');
    }
}
function set_per_page(){
    jQuery("#searchForm").submit();
}
jQuery(document).ready(search_ready);
jQuery(document).on('page:load', search_ready);