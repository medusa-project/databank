// creators_ready is a work-around for turbo links to trigger ready function stuff on every page.

Databank.creators = Databank.creators || {};

const creators_ready = function () {
  jQuery(".orcid-search-spinner").hide();
  bindCreatorTableEvents();
  let cells, desired_width, table_width;
  if (jQuery("#creator_table tr").length > 0) {
    const person_creators_type = 0;
    const org_creators_type = 1;
    let dataset_creator_type = null;
    const dataset_org_creators = jQuery("#dataset_org_creators").val();
    let creator_table = jQuery("#creator_table");

    if (dataset_org_creators === "true") {
      dataset_creator_type = org_creators_type;
    } else {
      dataset_creator_type = person_creators_type;
    }

    table_width = creator_table.width();
    cells = creator_table.find("tr")[0].cells.length;
    desired_width = table_width / cells + "px";

    handleCreatorTable(dataset_creator_type);

    jQuery("#creator_table td").css("width", desired_width);

    return creator_table.sortable(
      Databank.utils.sortableTableOptions(function () {
        handleCreatorTable(dataset_creator_type);
        generate_creator_preview();
      }),
    );
  }
};

function bindCreatorTableEvents() {
  jQuery("#creator_table")
    .off("click.creatorActions")
    .on("click.creatorActions", "button[data-creator-action]", function () {
      const action = jQuery(this).data("creator-action");

      if (action === "add") {
        const addType = jQuery(this).data("creator-add-type");
        if (addType === 1) {
          add_institution_creator();
        } else {
          add_person_creator();
        }
        return;
      }

      if (action === "remove") {
        remove_creator_row(
          jQuery(this).data("creator-index"),
          jQuery(this).data("creator-type"),
        );
        return;
      }

      if (action === "orcid-search") {
        showCreatorOrcidSearchModal(jQuery(this).data("creator-index"));
      }
    });
}

function add_person_creator() {
  jQuery("#update-confirm").prop("disabled", false);
  const creator_index_max_element = jQuery("#creator_index_max");

  const maxId = Number(creator_index_max_element.val());
  let newId = 1;

  if (!isNaN(maxId)) {
    newId = maxId + 1;
  }
  creator_index_max_element.val(newId);
  const creator_row = `<tr class="item row" id="creator_index_${newId}"><td><span style="display:inline;" class="glyphicon glyphicon-resize-vertical"></span></td><td class="col-md-2"><input type="hidden" value="${jQuery("#creator_table tr").length}" name="dataset[creators_attributes][${newId}][row_position]" id="dataset_creators_attributes_${newId}_row_position" /><input value="0" type="hidden" name="dataset[creators_attributes][${newId}][type_of]" id="dataset_creators_attributes_${newId}_type_of" /><input onchange="generate_creator_preview()" class="form-control dataset creator" placeholder="[e.g.: Smith]" type="text" name="dataset[creators_attributes][${newId}][family_name]" id="dataset_creators_attributes_${newId}_family_name" /></td><td class="col-md-2"><input onchange="generate_creator_preview()" class="form-control dataset creator" placeholder="[e.g.: Jean W.]" type="text" name="dataset[creators_attributes][${newId}][given_name]" id="dataset_creators_attributes_${newId}_given_name" /></td><td class="col-md-2"><input value="ORCID" type="hidden" name="dataset[creators_attributes][${newId}][identifier_scheme]" id="dataset_creators_attributes_${newId}_identifier_scheme" /><input class="form-control dataset orcid-mask" data-mask="9999-9999-9999-999*" placeholder="[xxxx-xxxx-xxxx-xxxx]" type="text" name="dataset[creators_attributes][${newId}][identifier]" id="dataset_creators_attributes_${newId}_identifier" /></td><td class="col-md-1"><button type="button" class="btn btn-primary btn-block orcid-search-btn" data-creator-action="orcid-search" data-creator-index="${newId}"><span class="glyphicon glyphicon-search"></span>&nbsp;Look Up&nbsp;<img src="/iD_icon_16x16.png" alt="orcid icon"></td><td class="col-md-2"><input onchange="handle_creator_email_change(this)" class="form-control dataset creator-email" placeholder="[e.g.: netid@illinois.edu]" type="email" name="dataset[creators_attributes][${newId}][email]" id="dataset_creators_attributes_${newId}_email" /></td><td class="col-md-2"><input name="dataset[creators_attributes][${newId}][is_contact]" type="hidden" value="false" id="dataset_creators_attributes_${newId}_is_contact"><input class="dataset contact_radio" name="primary_contact" onchange="handle_contact_change()" type="radio"  value="${newId}"></td><td class="col-md-1"></td></tr>`;
  jQuery("#creator_table tbody:last-child").append(creator_row);

  handleCreatorTable(0);
}

function add_institution_creator() {
  const creator_index_max_element = jQuery("#creator_index_max");
  jQuery("#update-confirm").prop("disabled", false);
  const maxId = Number(creator_index_max_element.val());
  let newId = 1;
  if (!isNaN(maxId)) {
    newId = maxId + 1;
  }
  creator_index_max_element.val(newId);

  const creator_row =
    '<tr class="item row" id="creator_index_${newId}">' +
    "  <td>" +
    '    <span style="display:inline;" class="glyphicon glyphicon-resize-vertical"></span>' +
    "  </td>" +
    '  <td class="col-md-6">' +
    '    <input type="hidden" value="${jQuery(\'#creator_table tr\').length}" name="dataset[creators_attributes][${newId}][row_position]" id="dataset_creators_attributes_${newId}_row_position" />' +
    '    <input value="1" type="hidden" name="dataset[creators_attributes][${newId}][type_of]" id="dataset_creators_attributes_${newId}_type_of" />' +
    '    <input onchange="generate_creator_preview()" class="form-control dataset creator" placeholder="[e.g.: Institute of Phenomenon Observation and Measurement]" type="text" name="dataset[creators_attributes][${newId}][institution_name]" id="dataset_creators_attributes_${newId}_institution_name" />' +
    "  </td>" +
    '  <td class="col-md-3">' +
    '    <input onchange="handle_creator_email_change(this)" class="form-control dataset creator-email" placeholder="[e.g.: netid@illinois.edu]" type="email" name="dataset[creators_attributes][${newId}][email]" id="dataset_creators_attributes_${newId}_email" />' +
    "  </td>" +
    '  <td class="col-md-2">' +
    '    <input name="dataset[creators_attributes][${newId}][is_contact]" type="hidden" value="false" id="dataset_creators_attributes_${newId}_is_contact">' +
    '    <input class="dataset contact_radio" name="primary_contact" onchange="handle_contact_change()" type="radio" value="${newId}">' +
    "  </td>" +
    '  <td class="col-md-1"></td>' +
    "</tr>";
  jQuery("#creator_table tbody:last-child").append(creator_row);

  handleCreatorTable(1);
}

function remove_creator_row(creator_index, creator_type) {
  // do not allow removal of primary contact for published dataset

  const person_creators_type = 0;
  const org_creators_type = 1;
  let dataset_creator_type = person_creators_type;

  if (jQuery("#dataset_org_creators").val() === "true") {
    dataset_creator_type = org_creators_type;
  }

  if (
    jQuery("input[name='dataset[publication_state]']").val() !== "draft" &&
    jQuery(
      "#dataset_creators_attributes_" + creator_index + "_is_contact",
    ).val() === "true"
  ) {
    alert(
      "The primary long term contact for a published dataset may not be removed." +
        "To delete this author listing, first select a different contact.",
    );
  } else {
    if (
      jQuery("#dataset_creators_attributes_" + creator_index + "_id").val() ===
      undefined
    ) {
      jQuery("#creator_index_" + creator_index).remove();
    } else {
      jQuery("#dataset_creators_attributes_" + creator_index + "__destroy").val(
        "true",
      );
      let current_creator_index_element = jQuery(
        "#creator_index_" + creator_index,
      );
      jQuery("#deleted_creator_table > tbody:last-child").append(
        current_creator_index_element,
      );
      current_creator_index_element.hide();
    }

    jQuery("#creator_table").sortable("refresh");

    if (jQuery("#creator_table tr").length < 2) {
      if (creator_type === org_creators_type) {
        add_institution_creator();
      } else {
        add_person_creator();
      }
    }
    jQuery("#update-confirm").prop("disabled", false);
    handleCreatorTable(dataset_creator_type);
    generate_creator_preview();
  }
}

function handleCreatorTable(creator_type) {
  const org_creators_type = 1;
  const rows = jQuery("#creator_table tr");
  const rowCount = rows.length;

  rows.each(function (i) {
    // for all but header row, set the row_position value of the input to match the table row position
    if (i > 0) {
      const split_id = this.id.split("_");
      const creator_index = split_id[2];
      jQuery(
        "#dataset_creators_attributes_" + creator_index + "_row_position",
      ).val(i);
      jQuery("td:last-child", this).html(
        creatorRowActions(creator_index, creator_type, i + 1 === rowCount),
      );
    }
  });
}

function creatorRowActions(creator_index, creator_type, isLastRow) {
  const org_creators_type = 1;
  const removeCreatorType = creator_type === org_creators_type ? 1 : 0;
  const addCreatorType = creator_type === org_creators_type ? 1 : 0;

  return Databank.utils.rowActionButtons({
    includeAdd: isLastRow,
    removeAttributes: {
      "data-creator-action": "remove",
      "data-creator-index": creator_index,
      "data-creator-type": removeCreatorType,
    },
    addAttributes: {
      "data-creator-action": "add",
      "data-creator-add-type": addCreatorType,
    },
  });
}

// Delegates to Databank.utils.validateEmailField (idb_utils.js).
// Global name kept for existing onchange="handle_creator_email_change(this)" handlers.
function handle_creator_email_change(input) {
  Databank.utils.validateEmailField(input);
}

function generate_creator_preview() {
  const person_creators_type = 0;
  const org_creators_type = 1;
  let dataset_creator_type = person_creators_type;

  if (jQuery("#dataset_org_creators").val() === "true") {
    dataset_creator_type = org_creators_type;
  }
  let creator_list_preview = "";

  jQuery("#creator_table tr").each(function (i) {
    var split_id = this.id.split("_");
    var creator_index = split_id[2];

    if (i > 0) {
      if (dataset_creator_type === org_creators_type) {
        const current_institution_name = jQuery(
          "#dataset_creators_attributes_" + creator_index + "_institution_name",
        ).val();
        if (current_institution_name !== "") {
          jQuery(this).removeClass("invalid-name");
          if (creator_list_preview.length > 0) {
            creator_list_preview = creator_list_preview + "; ";
          }
          creator_list_preview =
            creator_list_preview + current_institution_name;
        } else {
          jQuery(this).addClass("invalid-name");
        }
      } else {
        const current_family_name = jQuery(
          "#dataset_creators_attributes_" + creator_index + "_family_name",
        ).val();
        const current_given_name = jQuery(
          "#dataset_creators_attributes_" + creator_index + "_given_name",
        ).val();
        if (current_family_name !== "" && current_given_name !== "") {
          jQuery(this).removeClass("invalid-name");
          if (creator_list_preview.length > 0) {
            creator_list_preview = creator_list_preview + "; ";
          }
          creator_list_preview = creator_list_preview + current_family_name;
          creator_list_preview = creator_list_preview + ", ";
          creator_list_preview = creator_list_preview + current_given_name;
        } else {
          jQuery(this).addClass("invalid-name");
        }
      }
    }
  });

  jQuery("#creator-preview").html(creator_list_preview);
}

function handle_contact_change() {
  // set is_contact value to match selection status and highlight required email input field if blank
  var selectedVal = jQuery(
    "input[type='radio'][name='primary_contact']:checked",
  ).val();

  jQuery("#creator_table tr").each(function (i) {
    if (i > 0) {
      var creator_index = jQuery(this)
        .find("td")
        .first()
        .next()
        .find("input")
        .first()
        .attr("id")
        .split("_")[3];

      //mark all as not the contact -- then later mark the contact as the contact.
      jQuery(
        "input[name='dataset[creators_attributes][" +
          creator_index +
          "][email]']",
      )
        .closest("td")
        .removeClass("input-field-required");
      jQuery(
        "input[name='dataset[creators_attributes][" +
          creator_index +
          "][is_contact]']",
      ).val("false");
    }
  });

  jQuery(
    "input[name='dataset[creators_attributes][" +
      selectedVal +
      "][is_contact]']",
  ).val("true");
}

// *** ORCID stuff
function set_creator_orcid_from_search_modal() {
  let creator_index = jQuery("#creator-index").val();
  let selected = jQuery(
    "input[type='radio'][name='orcid-search-select']:checked",
  ).val();
  let select_split = selected.split("~");
  let selected_id = select_split[0];
  let selected_family = select_split[1];
  let selected_given = select_split[2];

  jQuery("#dataset_creators_attributes_" + creator_index + "_identifier").val(
    selected_id,
  );
  jQuery("#dataset_creators_attributes_" + creator_index + "_family_name").val(
    selected_family,
  );
  jQuery("#dataset_creators_attributes_" + creator_index + "_given_name").val(
    selected_given,
  );
  jQuery("#orcid-search-summary").empty();
}

function search_creator_orcid() {
  jQuery("#orcid-search-results").empty();
  jQuery(".orcid-search-spinner").show();
  jQuery("#orcid-search-summary").empty();
  // for accessibility, announce that search is in progress
  jQuery("#orcid-search-summary").text("Searching");

  let family_name = jQuery("#creator-family").val();
  let given_names = jQuery("#creator-given").val();
  let host = window.location.protocol + "//" + window.location.host;
  let search_url =
    host +
    "/creators/orcid_search?family_name=" +
    family_name +
    "&given_names=" +
    given_names;
  let max_orcid_results = 25;

  jQuery.ajax({
    url: search_url,
    dataType: "json",
    success: function (data) {
      jQuery(".orcid-search-spinner").hide();
      jQuery("#orcid-search-summary").empty();
      jQuery("#orcid-search-summary").text("Search complete");
      try {
        const responseJson = data;
        let total_found = responseJson["num-found"];
        let resultJson = responseJson["result"];
        let identifiers = [];
        for (let i = 0; i < total_found; i++) {
          if (typeof resultJson[i] != "undefined") {
            identifiers.push(resultJson[i]["orcid-identifier"]);
          }
        }
        let choices = [];
        let max_records = total_found;
        if (total_found > max_orcid_results) {
          jQuery("#orcid-search-summary").html(
            "<p>Showing first " +
              max_orcid_results +
              " results of " +
              total_found +
              ". For more results, search <a href='https://orcid.org/' target='_blank'>The ORCiD site</a>.</p>",
          );
          max_records = max_orcid_results;
        } else if (total_found === 1) {
          jQuery("#orcid-search-summary").html("<p>1 result found</p>");
        } else if (total_found > 1) {
          jQuery("#orcid-search-summary").html(
            "<p>" +
              total_found +
              " results found. Showing first " +
              max_records +
              ". For more results, search <a href='https://orcid.org/' target='_blank'>The ORCiD site</a>.</p>",
          );
        }
        if (total_found > 0) {
          jQuery("#orcid-search-summary").append(
            "<p>Select creator then click 'Import Selected ORCID' button.</p>",
          );
          jQuery("#orcid-search-results").append(
            "<table class='table table-striped' id='orcid-search-results-table'><thead><tr class='row'><th class='col-md-5'>Identifier (click link for details)</th><th class='col-md-5'>Affiliation</span></th><th class='col-md-1'>Select</th></tr></thead><tbody></tbody></table>",
          );

          for (let i = 0; i < max_records; i++) {
            let orcid = identifiers[i];
            let orcid_uri = "https://orcid.org/" + orcid;
            let orcidPerson = getOrcidPerson(orcid);
            let given_name = orcidPerson["given_names"];
            let family_name = orcidPerson["family_name"];
            let affiliation = orcidPerson["affiliation"];
            jQuery("#orcid-search-results-table > tbody:last-child").append(
              "<tr class='row'><td><a href='" +
                orcid_uri +
                "' target='_blank'>" +
                family_name +
                ", " +
                given_name +
                ": " +
                orcid +
                "</a></td><td>" +
                affiliation +
                "</td><td><input type='radio' name='orcid-search-select' value='" +
                orcid +
                "~" +
                family_name +
                "~" +
                given_name +
                "'/></td></tr>",
            );
          }
        } else {
          jQuery("#orcid-search-summary").text(
            "No results found. Try fewer letters or <a href='http://orcid.org' target='_blank'>The ORCID site</a>",
          );
        }
      } catch (err) {
        console.trace();
        jQuery("#orcid-search-summary").text("Error searching");
        console.error("Error in search: " + err.message);
      }
    },
    error: function (xhr) {
      jQuery("#orcid-search-summary").text("Error searching.");
      console.error("Error in search: " + xhr.statusText);
    },
  });
}

function getOrcidPerson(orcid) {
  let host = window.location.protocol + "//" + window.location.host;
  let personUrl = host + "/creators/orcid_person?orcid=" + orcid;
  let xmlHttp = new XMLHttpRequest();
  xmlHttp.open("GET", personUrl, false); // false for synchronous request
  xmlHttp.setRequestHeader("Accept", "application/json");
  xmlHttp.send(null);
  return JSON.parse(xmlHttp.responseText);
}

function getOrcidAffiliation(orcid) {
  const endpoint = "https://pub.orcid.org/v3.0/";
  const employmentsUrl = endpoint + orcid + "/employments";
  let xmlHttp = new XMLHttpRequest();
  xmlHttp.open("GET", employmentsUrl, false); // false for synchronous request
  xmlHttp.setRequestHeader("Accept", "application/json");
  xmlHttp.send(null);
  let response = xmlHttp.responseText;
  let responseJson = JSON.parse(response);
  let affiliation = "unknown";
  if (
    responseJson["employment-summary"] != null &&
    responseJson["employment-summary"][0] != null &&
    responseJson["employment-summary"][0]["organization"] != null
  ) {
    affiliation =
      responseJson["employment-summary"][0]["organization"]["name"] ||
      "unknown";
  }
  return affiliation;
}
// Delegates to Databank.utils.enableOrcidImport (idb_utils.js).
function enableOrcidImport() {
  Databank.utils.enableOrcidImport();
}

function showCreatorOrcidSearchModal(creator_index) {
  jQuery("#orcid-import-creator-btn").prop("disabled", true);
  jQuery("#creator-index").val(creator_index);
  let creatorFamilyName = jQuery(
    "#dataset_creators_attributes_" + creator_index + "_family_name",
  ).val();
  let creatorGivenName = jQuery(
    "#dataset_creators_attributes_" + creator_index + "_given_name",
  ).val();
  jQuery("#creator-family").val(creatorFamilyName);
  jQuery("#creator-given").val(creatorGivenName);
  jQuery("#orcid-search-results").empty();
  jQuery("#orcid-search-summary").empty();
  jQuery("#orcid_creator_search")
    .off("shown.bs.modal.creatorOrcidFocus")
    .on("shown.bs.modal.creatorOrcidFocus", function () {
      jQuery("#creator-family").focus();
    });
  jQuery("#orcid_creator_search").modal("show");
}

function bindCreatorOrcidModalEvents() {
  jQuery(document)
    .off("click.creatorOrcid", "#creator-orcid-search-btn")
    .on("click.creatorOrcid", "#creator-orcid-search-btn", function () {
      search_creator_orcid();
    })
    .off("click.creatorOrcid", "#orcid-import-creator-btn")
    .on("click.creatorOrcid", "#orcid-import-creator-btn", function () {
      set_creator_orcid_from_search_modal();
    })
    .off(
      "change.creatorOrcid",
      "#orcid_creator_search input[name='orcid-search-select']",
    )
    .on(
      "change.creatorOrcid",
      "#orcid_creator_search input[name='orcid-search-select']",
      function () {
        enableOrcidImport();
      },
    );
}

bindCreatorOrcidModalEvents();

Databank.creators.ready = creators_ready;
Databank.creators.addPersonCreator = add_person_creator;
Databank.creators.addInstitutionCreator = add_institution_creator;
Databank.creators.removeCreatorRow = remove_creator_row;
Databank.creators.handleCreatorTable = handleCreatorTable;
Databank.creators.handleCreatorEmailChange = handle_creator_email_change;
Databank.creators.generateCreatorPreview = generate_creator_preview;
Databank.creators.handleContactChange = handle_contact_change;
Databank.creators.setCreatorOrcidFromSearchModal =
  set_creator_orcid_from_search_modal;
Databank.creators.searchCreatorOrcid = search_creator_orcid;
Databank.creators.getOrcidPerson = getOrcidPerson;
Databank.creators.enableOrcidImport = enableOrcidImport;
Databank.creators.showCreatorOrcidSearchModal = showCreatorOrcidSearchModal;

jQuery(document).ready(Databank.creators.ready);
jQuery(document).on("page:load", Databank.creators.ready);
