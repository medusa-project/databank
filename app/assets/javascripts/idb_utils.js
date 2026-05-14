// Shared utility functions for the Illinois Data Bank front-end.
// All methods are namespaced under Databank.utils.
// Legacy global function names remain available in their original files via thin wrappers.

(function (window) {
  window.Databank = window.Databank || {};

  window.Databank.utils = {
    // Email validation -------------------------------------------------

    // Returns true if the given string matches a basic e-mail pattern.
    isEmail: function (email) {
      var regex =
        /^([a-zA-Z0-9_.+-])+\@(([a-zA-Z0-9-])+\.)+([a-zA-Z0-9]{2,4})+$/;
      return regex.test(email);
    },

    // Validates an e-mail <input> element and applies error styling.
    // Keeps the caller-facing behaviour identical to the previous per-file
    // handle_creator_email_change / handle_contributor_email_change functions.
    validateEmailField: function (input) {
      var $input = jQuery(input);
      var value = $input.val();

      if (Databank.utils.isEmail(value)) {
        $input.closest("td").removeClass("input-field-required");
        $input.removeClass("invalid-email");
      } else if (value !== "") {
        $input.addClass("invalid-email");
        alert("email address must be in valid format");
        $input.focus();
      } else {
        $input.removeClass("invalid-email");
      }
    },

    // ORCID helpers ----------------------------------------------------

    // Enables the "Import Selected ORCID" button inside the search modal.
    // Duplicated verbatim in creators.js and contributors.js previously.
    enableOrcidImport: function () {
      jQuery("#orcid-import-btn").prop("disabled", false);
    },

    // Dynamic table helpers --------------------------------------------

    // Returns a jQuery UI sortable options object with the standard
    // drag-handle and highlight behaviour used by all dynamic tables.
    // Pass an `onUpdate` function as the sortable `update` callback.
    sortableTableOptions: function (onUpdate) {
      return {
        axis: "y",
        items: ".item",
        cursor: "move",
        sort: function (e, ui) {
          return ui.item.addClass("active-item-shadow");
        },
        stop: function (e, ui) {
          ui.item.removeClass("active-item-shadow");
          return ui.item.children("td").effect("highlight", {}, 1000);
        },
        update: onUpdate || function () {},
      };
    },

    // Builds standard Remove/Add action button markup for dynamic rows.
    // Supports either inline onclick handlers or data-attribute actions.
    rowActionButtons: function (options) {
      var removeButton =
        '<button class="' +
        (options.removeClass || "btn btn-danger btn-sm") +
        '" ' +
        Databank.utils.buildHtmlAttributes(options.removeAttributes) +
        ' type="button">' +
        (options.removeLabel || "Remove") +
        "</button>";

      if (!options.includeAdd) {
        return removeButton;
      }

      var addButton =
        '<button class="' +
        (options.addClass || "btn btn-success btn-sm") +
        '" ' +
        Databank.utils.buildHtmlAttributes(options.addAttributes) +
        ' type="button">' +
        (options.addLabel || "Add") +
        "</button>";

      return removeButton + "&nbsp;&nbsp;" + addButton;
    },

    // Converts an object of attributes to an HTML attribute string.
    buildHtmlAttributes: function (attributes) {
      var attrString = "";
      var key;

      if (!attributes) {
        return attrString;
      }

      for (key in attributes) {
        if (Object.prototype.hasOwnProperty.call(attributes, key)) {
          attrString += key + '="' + attributes[key] + '" ';
        }
      }

      return attrString;
    },
  };
})(window);
