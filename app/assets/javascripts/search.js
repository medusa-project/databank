// Search and facet filtering for the Illinois Data Bank.
// All logic lives under Databank.search.
// Legacy global function names are kept at the bottom as thin wrappers so any
// remaining external callers (inline onclick in _citation_report.html.haml etc.)
// continue to work unchanged during the migration.

(function (window) {
  window.Databank = window.Databank || {};

  window.Databank.search = {
    // Highlight the active sort button based on the current sort_by value.
    setSortStyle: function () {
      var sort_criteria = jQuery("input[name='sort_by']").val();
      jQuery(".btn-sort").removeClass("btn-current-sort");
      switch (sort_criteria) {
        case "sort_updated_asc":
          jQuery(".updated_asc").addClass("btn-current-sort");
          break;
        case "sort_released_asc":
          jQuery(".released_asc").addClass("btn-current-sort");
          break;
        case "sort_released_desc":
          jQuery(".released_desc").addClass("btn-current-sort");
          break;
        case "sort_ingested_asc":
          jQuery(".ingested_asc").addClass("btn-current-sort");
          break;
        case "sort_ingested_desc":
          jQuery(".ingested_desc").addClass("btn-current-sort");
          break;
        default:
          jQuery(".updated_desc").addClass("btn-current-sort");
      }
    },

    // Submit the search form as-is (used when a facet checkbox changes).
    handleFilterChange: function () {
      jQuery("#searchForm").submit();
    },

    // Uncheck all facet checkboxes then resubmit.
    clearFilters: function () {
      jQuery(".checkFacetGroup").prop("checked", false);
      jQuery("#searchForm").submit();
    },

    // Clear the text search input then resubmit.
    clearSearchTerm: function () {
      jQuery("input[name='q']").val("");
      jQuery("#searchForm").submit();
    },

    // Remove any previous download hidden input then resubmit (returns
    // from a citation-report view back to normal search results).
    backToSearch: function () {
      jQuery("input[name='download']").remove();
      jQuery("#searchForm").submit();
    },

    // Append a hidden field that triggers report generation on the server.
    generateReport: function () {
      jQuery("#searchForm").append(
        "<input type='hidden' name='report' value='generate' />",
      );
      jQuery("#searchForm").submit();
    },

    // Append a hidden field that triggers a CSV download of citations.
    downloadCitationReport: function () {
      jQuery("#searchForm").append(
        "<input type='hidden' name='download' value='now' />",
      );
      jQuery("#searchForm").submit();
    },

    // Attach delegated event listeners to #searchForm.
    // Called once on DOM ready — replaces all per-checkbox onchange attrs
    // and the three action-button onclick attrs removed from _search.html.haml.
    bindEvents: function () {
      var $form = jQuery("#searchForm");
      if ($form.length === 0) {
        return;
      }

      // Single delegated listener replaces ~15 identical onchange="handleFilterChange()"
      // attributes previously scattered across every facet checkbox.
      $form.on("change", ".checkFacetGroup", function () {
        Databank.search.handleFilterChange();
      });

      // Button click listeners (onclick attributes removed from view).
      $form.on("click", "#clearSearchTermBtn", function () {
        Databank.search.clearSearchTerm();
      });
      $form.on("click", "#clearFiltersBtn", function () {
        Databank.search.clearFilters();
      });
      $form.on("click", "#generateReportBtn", function () {
        Databank.search.generateReport();
      });
      $form.on("click", "#citationBackBtn", function () {
        Databank.search.backToSearch();
      });
      $form.on("click", "#citationDownloadBtn", function () {
        Databank.search.downloadCitationReport();
      });
    },

    init: function () {
      Databank.search.setSortStyle();
      Databank.search.bindEvents();
    },
  };
})(window);

// ---------------------------------------------------------------------------
// Legacy global wrappers — do not add new callers; use Databank.search instead.
// ---------------------------------------------------------------------------

function setSortStyle() {
  Databank.search.setSortStyle();
}
function handleFilterChange() {
  Databank.search.handleFilterChange();
}
function clearFilters() {
  Databank.search.clearFilters();
}
function clearSearchTerm() {
  Databank.search.clearSearchTerm();
}
function backToSearch() {
  Databank.search.backToSearch();
}
function generateReport() {
  Databank.search.generateReport();
}
function downloadCitationReport() {
  Databank.search.downloadCitationReport();
}
function set_per_page() {
  Databank.search.handleFilterChange();
}

jQuery(document).ready(function () {
  Databank.search.init();
});
jQuery(document).on("page:load", function () {
  Databank.search.init();
});
