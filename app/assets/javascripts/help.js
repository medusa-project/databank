var help_ready;
help_ready = function () {


    $('body').scrollspy({
        target: '.bs-docs-sidebar',
        offset: 40
    });
    $("#sidebar").affix({
        offset: {
            top: 60
        }
    });
    var $recaptcha = document.querySelector('#g-recaptcha-response');

    if($recaptcha) {
        $recaptcha.setAttribute("required", "required");
    }
}

$(document).ready(help_ready);
$(document).on('page:load', help_ready);
