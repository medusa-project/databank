(function (window) {
  window.Databank = window.Databank || {};
  Databank.files = Databank.files || {};

  Databank.files.previewUI = {
    preview: function (web_id) {
      jQuery("#preview_" + web_id).show();

      if (jQuery("#preview_" + web_id).hasClass("fetched")) {
        console.log("using previously fetched text");
      } else {
        jQuery(".spinner_" + web_id).show();

        jQuery.getJSON("/datafiles/" + web_id + "/viewtext", function (json) {
          jQuery("#preview_" + web_id).html(
            "<pre>" + json.peek_text + "</pre>",
          );
          jQuery("#preview_" + web_id).addClass("fetched");
          jQuery(".spinner_" + web_id).hide();
        });
      }

      jQuery("#preview_btn_" + web_id).attr("aria-expanded", "true");
      jQuery("#preview_btn_" + web_id).attr(
        "data-file-action",
        "hide-preview-text",
      );
      jQuery("#preview_glyph_" + web_id).removeClass("glyphicon-eye-open");
      jQuery("#preview_glyph_" + web_id).addClass("glyphicon-eye-close");
    },

    previewMd: function (web_id) {
      jQuery("#preview_" + web_id).show();
      jQuery("#preview_btn_" + web_id).attr("aria-expanded", "true");
      jQuery("#preview_md_btn_" + web_id).attr(
        "data-file-action",
        "hide-preview-md",
      );
      jQuery("#preview_glyph_" + web_id).removeClass("glyphicon-eye-open");
      jQuery("#preview_glyph_" + web_id).addClass("glyphicon-eye-close");
    },

    hideMdPreview: function (web_id) {
      jQuery("#preview_btn_" + web_id).attr("aria-expanded", "false");
      jQuery("#preview_glyph_" + web_id).removeClass("glyphicon-eye-close");
      jQuery("#preview_glyph_" + web_id).addClass("glyphicon-eye-open");
      jQuery("#preview_md_btn_" + web_id).attr(
        "data-file-action",
        "preview-md",
      );
      jQuery("#preview_" + web_id).hide();
    },

    hidePreview: function (web_id) {
      jQuery("#preview_btn_" + web_id).attr("aria-expanded", "false");
      jQuery("#preview_btn_" + web_id).attr("data-file-action", "preview-text");
      jQuery("#preview_glyph_" + web_id).removeClass("glyphicon-eye-close");
      jQuery("#preview_glyph_" + web_id).addClass("glyphicon-eye-open");
      jQuery("#preview_" + web_id).hide();
    },

    previewImage: function (iiif_root, web_id) {
      jQuery("#preview_" + web_id).show();
      if (jQuery("#preview_" + web_id).hasClass("fetched")) {
        console.log("using previously fetched image");
      } else {
        jQuery(".spinner_" + web_id).show();
        var image_url = iiif_root + "/" + web_id + "/full/max/0/default.jpg";
        jQuery("#preview_" + web_id).addClass("fetched");
        jQuery("#preview_" + web_id).html(
          "<img src=" + image_url + " class='preview_body'>",
        );
        jQuery(".spinner_" + web_id).hide();
      }
      var imageButton = jQuery("#preview_img_btn_" + web_id).find("button");
      imageButton.attr("aria-expanded", "true");
      imageButton.attr("data-file-action", "hide-preview-image");
      imageButton.attr("data-iiif-root", iiif_root);
      imageButton.attr("data-web-id", web_id);
      jQuery("#preview_glyph_" + web_id).removeClass("glyphicon-eye-open");
      jQuery("#preview_glyph_" + web_id).addClass("glyphicon-eye-close");
    },

    hideImagePreview: function (iiif_root, web_id) {
      var imageButton = jQuery("#preview_img_btn_" + web_id).find("button");
      imageButton.attr("aria-expanded", "false");
      imageButton.attr("data-file-action", "preview-image");
      imageButton.attr("data-iiif-root", iiif_root);
      imageButton.attr("data-web-id", web_id);
      jQuery("#preview_glyph_" + web_id).removeClass("glyphicon-eye-close");
      jQuery("#preview_glyph_" + web_id).addClass("glyphicon-eye-open");
      jQuery("#preview_" + web_id).hide();
    },
  };
})(window);
