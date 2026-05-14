(function (window) {
    window.Databank = window.Databank || {};
    Databank.files = Databank.files || {};

    Databank.files.previewUI = {
        preview: function (web_id) {
            jQuery('#preview_' + web_id).show();

            if (jQuery('#preview_' + web_id).hasClass('fetched')) {
                console.log('using previously fetched text');
            } else {
                jQuery('.spinner_' + web_id).show();

                jQuery.getJSON('/datafiles/' + web_id + '/viewtext', function (json) {
                    jQuery('#preview_' + web_id).html('<pre>' + json.peek_text + '</pre>');
                    jQuery('#preview_' + web_id).addClass('fetched');
                    jQuery('.spinner_' + web_id).hide();
                });
            }

            jQuery('#preview_btn_' + web_id).attr('aria-expanded', 'true');
            jQuery('#preview_glyph_' + web_id).removeClass('glyphicon-eye-open');
            jQuery('#preview_glyph_' + web_id).addClass('glyphicon-eye-close');
            jQuery('#preview_btn_' + web_id).attr('onclick', "hide_preview('" + web_id + "')");
        },

        previewMd: function (web_id) {
            jQuery('#preview_' + web_id).show();
            jQuery('#preview_btn_' + web_id).attr('aria-expanded', 'true');
            jQuery('#preview_glyph_' + web_id).removeClass('glyphicon-eye-open');
            jQuery('#preview_glyph_' + web_id).addClass('glyphicon-eye-close');
            jQuery('#preview_md_btn_' + web_id).attr('onclick', "hide_md_preview('" + web_id + "')");
        },

        hideMdPreview: function (web_id) {
            jQuery('#preview_btn_' + web_id).attr('aria-expanded', 'falase');
            jQuery('#preview_glyph_' + web_id).removeClass('glyphicon-eye-close');
            jQuery('#preview_glyph_' + web_id).addClass('glyphicon-eye-open');
            jQuery('#preview_md_btn_' + web_id).attr('onclick', "preview_md('" + web_id + "')");
            jQuery('#preview_' + web_id).hide();
        },

        hidePreview: function (web_id) {
            jQuery('#preview_btn_' + web_id).attr('aria-expanded', 'false');
            jQuery('#preview_glyph_' + web_id).removeClass('glyphicon-eye-close');
            jQuery('#preview_glyph_' + web_id).addClass('glyphicon-eye-open');
            jQuery('#preview_btn_' + web_id).attr('onclick', "preview('" + web_id + "')");
            jQuery('#preview_' + web_id).hide();
        },

        previewImage: function (iiif_root, web_id) {
            jQuery('#preview_' + web_id).show();
            if (jQuery('#preview_' + web_id).hasClass('fetched')) {
                console.log('using previously fetched image');
            } else {
                jQuery('.spinner_' + web_id).show();
                var image_url = iiif_root + '/' + web_id + '/full/max/0/default.jpg';
                jQuery('#preview_' + web_id).addClass('fetched');
                jQuery('#preview_' + web_id).html("<img src=" + image_url + " class='preview_body'>");
                jQuery('.spinner_' + web_id).hide();
            }
            jQuery('#preview_img_btn_' + web_id).html('<button type="button" aria-expanded="true" class="btn btn-sm btn-success" onclick="hide_image_preview(&#39;' + iiif_root + '&#39;, &#39;' + web_id + '&#39;)"><span class="glyphicon glyphicon-eye-close"></span> View</button>');
        },

        hideImagePreview: function (iiif_root, web_id) {
            jQuery('#preview_img_btn_' + web_id).html('<button type="button" aria-expaneded="false" class="btn btn-sm btn-success" onclick="preview_image(&#39;' + iiif_root + '&#39;, &#39;' + web_id + '&#39;)"><span class="glyphicon glyphicon-eye-open"></span> View</button>');
            jQuery('#preview_' + web_id).hide();
        }
    };
})(window);
