// work-around turbo links to trigger ready function stuff on every page.

var related_materials_ready;
related_materials_ready = function () {
  bindMaterialTableEvents();
  handleMaterialTable();
};

function bindMaterialTableEvents() {
  jQuery("#material_table")
    .off("click.materialActions")
    .on("click.materialActions", "button[data-material-action]", function () {
      var action = jQuery(this).data("material-action");

      if (action === "add") {
        add_material_row();
        return;
      }

      if (action === "remove") {
        remove_material_row(jQuery(this).data("material-index"));
      }
    })
    .off(
      "change.materialActions",
      "select[id^='dataset_related_materials_attributes_'][id$='_selected_type']",
    )
    .on(
      "change.materialActions",
      "select[id^='dataset_related_materials_attributes_'][id$='_selected_type']",
      function () {
        var match = this.id.match(
          /^dataset_related_materials_attributes_(\d+)_selected_type$/,
        );
        if (match) {
          handleMaterialChange(match[1]);
        }
      },
    )
    .off(
      "change.materialActions",
      "input[name='datacite_relation'][class*='material_checkbox_']",
    )
    .on(
      "change.materialActions",
      "input[name='datacite_relation'][class*='material_checkbox_']",
      function () {
        var classMatch = (this.className || "").match(
          /material_checkbox_(\d+)/,
        );
        if (classMatch) {
          handle_relationship_box(classMatch[1]);
        }
      },
    );
}

function handleMaterialChange(materialIndex) {
  jQuery("#update-confirm").prop("disabled", false);
  var materialSelectVal = jQuery(
    "#dataset_related_materials_attributes_" + materialIndex + "_selected_type",
  ).val();

  switch (materialSelectVal) {
    case "Article":
    case "Code":
    case "Presentation":
    case "Thesis":
    case "Dataset":
      jQuery(
        "#dataset_related_materials_attributes_" +
          materialIndex +
          "_material_type",
      ).val(materialSelectVal);
      jQuery(
        "#dataset_related_materials_attributes_" +
          materialIndex +
          "_material_type",
      ).css("visibility", "hidden");
      break;
    case "Other":
      jQuery(
        "#dataset_related_materials_attributes_" +
          materialIndex +
          "_material_type",
      ).val("");
      jQuery("#material_cell_" + materialIndex).html(
        '<input class="form-control dataset material-text" type="text" name="dataset[related_materials_attributes][' +
          materialIndex +
          '][material_type]" id="dataset_related_materials_attributes_' +
          materialIndex +
          '_material_type" />',
      );
      jQuery(
        "#dataset_related_materials_attributes_" +
          materialIndex +
          "_material_type",
      ).css("visibility", "visible");

      jQuery(
        "#dataset_related_materials_attributes_" +
          materialIndex +
          "_material_type",
      ).focus();
      break;
    // should not get to default
    default:
      jQuery(
        "#dataset_related_materials_attributes_" +
          materialIndex +
          "_material_type",
      ).val("");
  }
}

function handleMaterialTable() {
  var rows = jQuery("#material_table tr.item");
  var rowCount = rows.length;

  rows.each(function (i) {
    var split_id = this.id.split("_");
    var material_index = split_id[2];

    jQuery("td:last-child", this).html(
      materialRowActions(material_index, i + 1 == rowCount),
    );
  });
}

function materialRowActions(material_index, isLastRow) {
  return Databank.utils.rowActionButtons({
    includeAdd: isLastRow,
    removeAttributes: {
      "data-material-action": "remove",
      "data-material-index": material_index,
    },
    addAttributes: {
      "data-material-action": "add",
    },
  });
}

function add_material_row() {
  jQuery("#update-confirm").prop("disabled", false);

  var maxId = Number(jQuery("#material_index_max").val());
  var newId = 0;

  if (!isNaN(maxId)) {
    newId = maxId + 1;
  }
  jQuery("#material_index_max").val(newId);

  var material_row =
    '<tr class="item row" id="material_index_' +
    newId +
    '">' +
    "<td>" +
    '<input value="false" type="hidden" name="dataset[related_materials_attributes][' +
    newId +
    '][_destroy]" id="dataset_related_materials_attributes_' +
    newId +
    '__destroy" />' +
    '<select class="form-control dataset" name="dataset[related_materials_attributes][' +
    newId +
    '][selected_type]" id="dataset_related_materials_attributes_' +
    newId +
    '_selected_type">' +
    '<option value="">Select...</option>' +
    '<option value="Article">Article</option>' +
    '<option value="Code">Code</option>' +
    '<option value="Dataset">Dataset</option>' +
    '<option value="Presentation">Presentation</option>' +
    '<option value="Thesis">Thesis</option>' +
    '<option value="Other">Other:</option></select>' +
    "</td>" +
    '<td id="material_cell_' +
    newId +
    '">' +
    '<input type="hidden" name="dataset[related_materials_attributes][' +
    newId +
    '][material_type]" id="dataset_related_materials_attributes_' +
    newId +
    '_material_type" />' +
    "</td>" +
    "<td>" +
    '<input class="form-control dataset" type="text" placeholder="[ URL to resource, e.g:   http://hdl.handle.net/2142/46427 ]"  name="dataset[related_materials_attributes][' +
    newId +
    '][link]" id="dataset_related_materials_attributes_' +
    newId +
    '_link" />' +
    "</td>" +
    "<td>" +
    '<textarea rows="2" class="form-control dataset" placeholder="[ related resource citation, e.g.:  Author(s). &quot;Title of Article.&quot; Title of Periodical Date: pages. Medium of publication.  identifier ]" name="dataset[related_materials_attributes][' +
    newId +
    '][citation]" id="dataset_related_materials_attributes_' +
    newId +
    '_citation">' +
    "</textarea>" +
    "</td>" +
    "<td></td>" +
    "</tr>";

  if (user_role == "admin") {
    material_row =
      material_row +
      '<tr class="row datacite-relationship curator-only" id="datacite_material_index_' +
      newId +
      '">' +
      "<td></td>" +
      "<td><h3>This dataset...</h3></td>" +
      "<td>" +
      '<div class="form-group">' +
      '<input type="hidden" name="dataset[related_materials_attributes][' +
      newId +
      '][datacite_list]" id="dataset_related_materials_attributes_' +
      newId +
      '_datacite_list" />' +
      '<input name="datacite_relation" type="checkbox" value="IsSupplementTo" class="material_checkbox_' +
      newId +
      '"> IsSupplementTo </input>' +
      "<br/>" +
      '<input name="datacite_relation" type="checkbox" value="IsSupplementedBy" class="material_checkbox_' +
      newId +
      '"> IsSupplementedBy  </input>' +
      "<br/>" +
      '<input name="datacite_relation" type="checkbox" value="IsCitedBy" class="material_checkbox_' +
      newId +
      '"> IsCitedBy </input>' +
      "<br/>" +
      '<input name="datacite_relation" type="checkbox" value="IsPreviousVersionOf" class="material_checkbox_' +
      newId +
      '"> IsPreviousVersionOf </input>' +
      "<br/>" +
      '<input name="datacite_relation" type="checkbox" value="IsNewVersionOf" class="material_checkbox_' +
      newId +
      '"> IsNewVersionOf </input>' +
      "</div>" +
      "</td>" +
      "<td>" +
      '<div class="form-group">' +
      '<select class="form-control dataset" name="dataset[related_materials_attributes][' +
      newId +
      '][uri_type]" id="dataset_related_materials_attributes_' +
      newId +
      '_uri_type">' +
      '<option value="">Select Type</option>' +
      '<option value="ARK">ARK</option>' +
      '<option value="arXiv">arXiv</option>' +
      '<option value="bibcode">bibcode</option>' +
      '<option value="DOI">DOI</option>' +
      '<option value="EAN13">EAN13</option>' +
      '<option value="EISSN">EISSN</option>' +
      '<option value="Handle">Handle</option>' +
      '<option value="ISBN">ISBN</option>' +
      '<option value="ISSN">ISSN</option>' +
      '<option value="ISTC">ISTC</option>' +
      '<option value="LISSN">LISSN</option>' +
      '<option value="LSID">LSID</option>' +
      '<option value="PMID">PMID</option>' +
      '<option value="PURL">PURL</option>' +
      '<option value="UPC">UPC</option>' +
      '<option value="URL">URL</option>' +
      '<option value="URN">URN</option>' +
      "</select>" +
      "</div>" +
      '<div class="form-group">' +
      '<input placeholder="URI: For a DOI, the part that starts with 10." class="form-control dataset" type="text" name="dataset[related_materials_attributes][' +
      newId +
      '][uri]" id="dataset_related_materials_attributes_' +
      newId +
      '_uri" />' +
      "</div>" +
      "</td><td></td></tr>";
  }

  jQuery("#material_table tbody:last-child").append(material_row);
  handleMaterialTable();
}

function remove_material_row(material_index) {
  if (
    jQuery(
      "#dataset_related_materials_attributes_" + material_index + "_id",
    ).val() != undefined
  ) {
    jQuery(
      "#dataset_related_materials_attributes_" + material_index + "__destroy",
    ).val("true");
    jQuery("#deleted_material_table > tbody:last-child").append(
      jQuery("#material_index_" + material_index),
    );
    jQuery("#material_index_" + material_index).hide();
  } else {
    jQuery("#material_index_" + material_index).remove();
  }

  jQuery("#datacite_material_index_" + material_index).remove();

  if (jQuery("#material_table tr").length < 2) {
    add_material_row();
  }
  jQuery("#update-confirm").prop("disabled", false);
  handleMaterialTable();
}

function handle_relationship_box(material_index) {
  console.log(material_index);
  var checked_values = "";
  var i = 0;
  jQuery(".material_checkbox_" + material_index + ":checked").each(function () {
    if (i > 0) {
      checked_values = checked_values + ",";
    }
    checked_values = checked_values + jQuery(this).val();
    i = i + 1;
  });

  jQuery(
    "#dataset_related_materials_attributes_" +
      material_index +
      "_datacite_list",
  ).val(checked_values);
}

jQuery(document).ready(related_materials_ready);
jQuery(document).on("page:load", related_materials_ready);
