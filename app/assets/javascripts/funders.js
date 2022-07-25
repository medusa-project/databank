// work-around turbo links to trigger ready function stuff on every page.

var funders_ready;
funders_ready = function () {
    //$('.funder-text').css("visibility", "hidden");
    handleFunderTable();
    //alert("funders.js javascript working");
}

function handleFunderChange(funderIndex) {
    $('#update-confirm').prop('disabled', false);
    funderSelectVal = $("#dataset_funders_attributes_" + funderIndex + "_code").val();
    console.log(funderSelectVal);

    //empty current custom value
    $('#dataset_funders_attributes_' + funderIndex + '_name').val('');
    $('#dataset_funders_attributes_' + funderIndex + '_name').css("visibility", "hidden");

    switch (funderSelectVal) {
        case "none":
            $('#dataset_funders_attributes_' + funderIndex + '_name').val('');
            $('#dataset_funders_attributes_' + funderIndex + '_identifier').val('');
            $('#dataset_funders_attributes_' + funderIndex + '_identifier_scheme').val('');
            break;

        case "IDCEO":
            $('#dataset_funders_attributes_' + funderIndex + '_name').val('Illinois Department of Commerce & Economic Opportunity (DCEO)');
            $('#dataset_funders_attributes_' + funderIndex + '_identifier').val('10.13039/100004885');
            $('#dataset_funders_attributes_' + funderIndex + '_identifier_scheme').val('DOI');
            break;

        case "IDHS":
            $('#dataset_funders_attributes_' + funderIndex + '_name').val('Illinois Department of Human Services (DHS)');
            $('#dataset_funders_attributes_' + funderIndex + '_identifier').val('10.13039/100004886');
            $('#dataset_funders_attributes_' + funderIndex + '_identifier_scheme').val('DOI');
            break;

        case "IDNR":
            $('#dataset_funders_attributes_' + funderIndex + '_name').val('Illinois Department of Natural Resources (IDNR)');
            $('#dataset_funders_attributes_' + funderIndex + '_identifier').val('10.13039/100004887');
            $('#dataset_funders_attributes_' + funderIndex + '_identifier_scheme').val('DOI');
            break;

        case "IDOT":
            $('#dataset_funders_attributes_' + funderIndex + '_name').val('Illinois Department of Transportation (IDOT)');
            $('#dataset_funders_attributes_' + funderIndex + '_identifier').val('10.13039/100009637');
            $('#dataset_funders_attributes_' + funderIndex + '_identifier_scheme').val('DOI');
            break;

        case "USARMY":
            $('#dataset_funders_attributes_' + funderIndex + '_name').val('U.S. Army');
            $('#dataset_funders_attributes_' + funderIndex + '_identifier').val('10.13039/100006751');
            $('#dataset_funders_attributes_' + funderIndex + '_identifier_scheme').val('DOI');
            break;

        case "USDA":
            $('#dataset_funders_attributes_' + funderIndex + '_name').val('U.S. Department of Agriculture (USDA)');
            $('#dataset_funders_attributes_' + funderIndex + '_identifier').val('10.13039/100000199');
            $('#dataset_funders_attributes_' + funderIndex + '_identifier_scheme').val('DOI');
            break;

        case "DOE":
            $('#dataset_funders_attributes_' + funderIndex + '_name').val('U.S. Department of Energy (DOE)');
            $('#dataset_funders_attributes_' + funderIndex + '_identifier').val('10.13039/100000015');
            $('#dataset_funders_attributes_' + funderIndex + '_identifier_scheme').val('DOI');
            break;

        case "USGS":
            $('#dataset_funders_attributes_' + funderIndex + '_name').val('U.S. Geological Survey (USGS)');
            $('#dataset_funders_attributes_' + funderIndex + '_identifier').val('10.13039/100000203');
            $('#dataset_funders_attributes_' + funderIndex + '_identifier_scheme').val('DOI');
            break;

        case "NASA":
            $('#dataset_funders_attributes_' + funderIndex + '_name').val('U.S. National Aeronautics and Space Administration (NASA)');
            $('#dataset_funders_attributes_' + funderIndex + '_identifier').val('10.13039/100000104');
            $('#dataset_funders_attributes_' + funderIndex + '_identifier_scheme').val('DOI');
            break;

        case "NIH":
            $('#dataset_funders_attributes_' + funderIndex + '_name').val('U.S. National Institutes of Health (NIH)');
            $('#dataset_funders_attributes_' + funderIndex + '_identifier').val('10.13039/100000002');
            $('#dataset_funders_attributes_' + funderIndex + '_identifier_scheme').val('DOI');
            break;

        case "NSF":
            $('#dataset_funders_attributes_' + funderIndex + '_name').val('U.S. National Science Foundation (NSF)');
            $('#dataset_funders_attributes_' + funderIndex + '_identifier').val('10.13039/100000001');
            $('#dataset_funders_attributes_' + funderIndex + '_identifier_scheme').val('DOI');
            break;

        case "other":
            $('#dataset_funders_attributes_' + funderIndex + '_name').css("visibility", "visible");
            $('#dataset_funders_attributes_' + funderIndex + '_identifier').val('');
            $('#dataset_funders_attributes_' + funderIndex + '_identifier_scheme').val('');
            $('#dataset_funders_attributes_' + funderIndex + '_name').focus();
            break;

        // should not get to default
        default:
            console.log("funder: " + funderSelectVal)
            console.log("funder_index: " + funderIndex)
    }

}

function handleFunderTable() {
    $('#funder_table tr').each(function (i) {
        if (i > 0) {
            var split_id = (this.id).split('_');
            var funder_index = split_id[2];

            if ((i + 1 ) == ($("#funder_table tr").length)) {
                $("td:last-child", this).html("<button class='btn btn-danger btn-sm' onclick='remove_funder_row(\x22" + funder_index + "\x22 )' type='button'><span class='glyphicon glyphicon-trash'></span></button>&nbsp;&nbsp;<button class='btn btn-success btn-sm' onclick='add_funder_row()' type='button'><span class='glyphicon glyphicon-plus'></span></button>");
            } else {
                $("td:last-child", this).html("<button class='btn btn-danger btn-sm' onclick='remove_funder_row(\x22" + funder_index + "\x22 )' type='button'><span class='glyphicon glyphicon-trash'></span></button>");
            }
        }
    });
}

function add_funder_row() {

    $('#update-confirm').prop('disabled', false);

    var maxId = Number($('#funder_index_max').val());
    var newId = 0;

    if (maxId != NaN) {
        newId = maxId + 1;
    }
    $('#funder_index_max').val(newId);

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

    $("#funder_table tbody:last-child").append(funder_row);
    handleFunderTable();
}

function remove_funder_row(funder_index) {
    if ($("#dataset_funders_attributes_" + funder_index + "_id").val() != undefined) {
        $("#dataset_funders_attributes_" + funder_index + "__destroy").val("true");
        $("#deleted_funder_table > tbody:last-child").append($("#funder_index_" + funder_index));
        $("#funder_index_" + funder_index).hide();
    } else {
        $("#funder_index_" + funder_index).remove();
    }
    
    if ($("#funder_table tr").length < 2) {
        add_funder_row();
    }
    $('#update-confirm').prop('disabled', false);
    handleFunderTable();
}

$(document).ready(funders_ready);
$(document).on('page:load', funders_ready);
