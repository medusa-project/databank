// work-around turbo links to trigger ready function stuff on every page.

var funders_ready;
funders_ready = function () {
    //jQuery('.funder-text').css("visibility", "hidden");
    handleFunderTable();
    //alert("funders.js javascript working");
}

function handleFunderChange(funderIndex) {
    jQuery('#update-confirm').prop('disabled', false);
    funderSelectVal = jQuery("#dataset_funders_attributes_" + funderIndex + "_code").val();
    console.log(funderSelectVal);

    //empty current custom value
    jQuery('#dataset_funders_attributes_' + funderIndex + '_name').val('');
    jQuery('#dataset_funders_attributes_' + funderIndex + '_name').css("visibility", "hidden");

    switch (funderSelectVal) {
        case "none":
            jQuery('#dataset_funders_attributes_' + funderIndex + '_name').val('');
            jQuery('#dataset_funders_attributes_' + funderIndex + '_identifier').val('');
            jQuery('#dataset_funders_attributes_' + funderIndex + '_identifier_scheme').val('');
            break;

        case "IDCEO":
            jQuery('#dataset_funders_attributes_' + funderIndex + '_name').val('Illinois Department of Commerce & Economic Opportunity (DCEO)');
            jQuery('#dataset_funders_attributes_' + funderIndex + '_identifier').val('10.13039/100004885');
            jQuery('#dataset_funders_attributes_' + funderIndex + '_identifier_scheme').val('DOI');
            break;

        case "IDHS":
            jQuery('#dataset_funders_attributes_' + funderIndex + '_name').val('Illinois Department of Human Services (DHS)');
            jQuery('#dataset_funders_attributes_' + funderIndex + '_identifier').val('10.13039/100004886');
            jQuery('#dataset_funders_attributes_' + funderIndex + '_identifier_scheme').val('DOI');
            break;

        case "IDNR":
            jQuery('#dataset_funders_attributes_' + funderIndex + '_name').val('Illinois Department of Natural Resources (IDNR)');
            jQuery('#dataset_funders_attributes_' + funderIndex + '_identifier').val('10.13039/100004887');
            jQuery('#dataset_funders_attributes_' + funderIndex + '_identifier_scheme').val('DOI');
            break;

        case "IDOT":
            jQuery('#dataset_funders_attributes_' + funderIndex + '_name').val('Illinois Department of Transportation (IDOT)');
            jQuery('#dataset_funders_attributes_' + funderIndex + '_identifier').val('10.13039/100009637');
            jQuery('#dataset_funders_attributes_' + funderIndex + '_identifier_scheme').val('DOI');
            break;

        case "USARMY":
            jQuery('#dataset_funders_attributes_' + funderIndex + '_name').val('U.S. Army');
            jQuery('#dataset_funders_attributes_' + funderIndex + '_identifier').val('10.13039/100006751');
            jQuery('#dataset_funders_attributes_' + funderIndex + '_identifier_scheme').val('DOI');
            break;

        case "USDA":
            jQuery('#dataset_funders_attributes_' + funderIndex + '_name').val('U.S. Department of Agriculture (USDA)');
            jQuery('#dataset_funders_attributes_' + funderIndex + '_identifier').val('10.13039/100000199');
            jQuery('#dataset_funders_attributes_' + funderIndex + '_identifier_scheme').val('DOI');
            break;

        case "DOE":
            jQuery('#dataset_funders_attributes_' + funderIndex + '_name').val('U.S. Department of Energy (DOE)');
            jQuery('#dataset_funders_attributes_' + funderIndex + '_identifier').val('10.13039/100000015');
            jQuery('#dataset_funders_attributes_' + funderIndex + '_identifier_scheme').val('DOI');
            break;

        case "USGS":
            jQuery('#dataset_funders_attributes_' + funderIndex + '_name').val('U.S. Geological Survey (USGS)');
            jQuery('#dataset_funders_attributes_' + funderIndex + '_identifier').val('10.13039/100000203');
            jQuery('#dataset_funders_attributes_' + funderIndex + '_identifier_scheme').val('DOI');
            break;

        case "NASA":
            jQuery('#dataset_funders_attributes_' + funderIndex + '_name').val('U.S. National Aeronautics and Space Administration (NASA)');
            jQuery('#dataset_funders_attributes_' + funderIndex + '_identifier').val('10.13039/100000104');
            jQuery('#dataset_funders_attributes_' + funderIndex + '_identifier_scheme').val('DOI');
            break;

        case "NIH":
            jQuery('#dataset_funders_attributes_' + funderIndex + '_name').val('U.S. National Institutes of Health (NIH)');
            jQuery('#dataset_funders_attributes_' + funderIndex + '_identifier').val('10.13039/100000002');
            jQuery('#dataset_funders_attributes_' + funderIndex + '_identifier_scheme').val('DOI');
            break;

        case "NSF":
            jQuery('#dataset_funders_attributes_' + funderIndex + '_name').val('U.S. National Science Foundation (NSF)');
            jQuery('#dataset_funders_attributes_' + funderIndex + '_identifier').val('10.13039/100000001');
            jQuery('#dataset_funders_attributes_' + funderIndex + '_identifier_scheme').val('DOI');
            break;

        case "other":
            jQuery('#dataset_funders_attributes_' + funderIndex + '_name').css("visibility", "visible");
            jQuery('#dataset_funders_attributes_' + funderIndex + '_identifier').val('');
            jQuery('#dataset_funders_attributes_' + funderIndex + '_identifier_scheme').val('');
            jQuery('#dataset_funders_attributes_' + funderIndex + '_name').focus();
            break;

        // should not get to default
        default:
            console.log("funder: " + funderSelectVal)
            console.log("funder_index: " + funderIndex)
    }

}

function handleFunderTable() {
    jQuery('#funder_table tr').each(function (i) {
        if (i > 0) {
            var split_id = (this.id).split('_');
            var funder_index = split_id[2];

            if ((i + 1 ) == (jQuery("#funder_table tr").length)) {
                jQuery("td:last-child", this).html("<button class='btn btn-danger btn-sm' onclick='remove_funder_row(\x22" + funder_index + "\x22 )' type='button'>Remove</button>&nbsp;&nbsp;<button class='btn btn-success btn-sm' onclick='add_funder_row()' type='button'>Add</button>");
            } else {
                jQuery("td:last-child", this).html("<button class='btn btn-danger btn-sm' onclick='remove_funder_row(\x22" + funder_index + "\x22 )' type='button'>Remove</button>");
            }
        }
    });
}

function add_funder_row() {

    jQuery('#update-confirm').prop('disabled', false);

    var maxId = Number(jQuery('#funder_index_max').val());
    var newId = 0;

    if (maxId != NaN) {
        newId = maxId + 1;
    }
    jQuery('#funder_index_max').val(newId);

    var funder_row = '<tr class="item row" id="funder_index_' + newId + '">' +
        '<td>' +
        '<input type="hidden" name="dataset[funders_attributes][' + newId + '][identifier]" id="dataset_funders_attributes_' + newId + '_identifier" />' +
        '<input type="hidden" name="dataset[funders_attributes][' + newId + '][identifier_scheme]" id="dataset_funders_attributes_' + newId + '_identifier_scheme" />' +
        '<select class="form-control dataset" onchange="handleFunderChange(' + newId + ')" name="dataset[funders_attributes][' + newId + '][code]" id="dataset_funders_attributes_' + newId + '_code"><option value="">Please select</option>' +
        '<option value="IDCEO">Illinois Department of Commerce &amp; Economic Opportunity (DCEO)</option>' +
        '<option value="IDHS">Illinois Department of Human Services (DHS)</option>' +
        '<option value="IDNR">Illinois Department of Natural Resources (IDNR)</option>' +
        '<option value="IDOT">Illinois Department of Transportation (IDOT)</option>' +
        '<option value="USARMY">U.S. Army</option>' +
        '<option value="USDA">U.S. Department of Agriculture (USDA)</option>' +
        '<option value="DOE">U.S. Department of Energy (DOE)</option>' +
        '<option value="USGS">U.S. Geological Survey (USGS)</option>' +
        '<option value="NASA">U.S. National Aeronautics and Space Administration (NASA)</option>' +
        '<option value="NIH">U.S. National Institutes of Health (NIH)</option>' +
        '<option value="NSF">U.S. National Science Foundation (NSF)</option>' +
        '<option value="other">Other -- Please provide name:</option></select>' +
        '</td>' +
        '<td>' +
        '<input class="form-control dataset funder-text" placeholder="[Funder Name]" type="text" name="dataset[funders_attributes][' + newId + '][name]" id="dataset_funders_attributes_' + newId + '_name" style="visibility: hidden;" />' +
        '</td>' +
        '<td>' +
        '<input class="form-control dataset" type="text" name="dataset[funders_attributes][' + newId + '][grant]" id="dataset_funders_attributes_' + newId + '_grant" />' +
        '</td>' +
        '<td></td>' +
        '</tr>'

    jQuery("#funder_table tbody:last-child").append(funder_row);
    handleFunderTable();
}

function remove_funder_row(funder_index) {
    if (jQuery("#dataset_funders_attributes_" + funder_index + "_id").val() != undefined) {
        jQuery("#dataset_funders_attributes_" + funder_index + "__destroy").val("true");
        jQuery("#deleted_funder_table > tbody:last-child").append(jQuery("#funder_index_" + funder_index));
        jQuery("#funder_index_" + funder_index).hide();
    } else {
        jQuery("#funder_index_" + funder_index).remove();
    }
    
    if (jQuery("#funder_table tr").length < 2) {
        add_funder_row();
    }
    jQuery('#update-confirm').prop('disabled', false);
    handleFunderTable();
}

jQuery(document).ready(funders_ready);
jQuery(document).on('page:load', funders_ready);
