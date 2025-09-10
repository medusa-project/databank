var help_ready;
help_ready = function () {


    jQuery('body').scrollspy({
        target: '.bs-docs-sidebar',
        offset: 40
    });
    jQuery("#sidebar").affix({
        offset: {
            top: 60
        }
    });
}

jQuery(document).ready(help_ready);
jQuery(document).on('page:load', help_ready);
