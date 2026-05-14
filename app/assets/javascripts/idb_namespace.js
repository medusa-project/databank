(function (window, document) {
    window.Databank = window.Databank || {};

    var Databank = window.Databank;

    Databank.page = Databank.page || {};
    Databank.events = Databank.events || {};

    Databank.page.getContext = function () {
        var body = document.body;

        return {
            controller: body ? body.getAttribute('data-controller') : null,
            action: body ? body.getAttribute('data-action') : null,
            page: body ? body.getAttribute('data-page') : null,
            datasetKey: window.dataset_key || null,
            datasetId: window.dataset_id || null,
            datafileWebId: window.datafile_web_id || null,
            railsEnv: window.rails_env || null,
            userRole: window.user_role || null
        };
    };

    Databank.events.emit = function (name, detail) {
        if (typeof window.CustomEvent === 'function') {
            document.dispatchEvent(new CustomEvent(name, { detail: detail }));
            return;
        }

        var event = document.createEvent('CustomEvent');
        event.initCustomEvent(name, false, false, detail);
        document.dispatchEvent(event);
    };

    var notifyPageReady = function () {
        Databank.events.emit('databank:page-ready', Databank.page.getContext());
    };

    jQuery(document).ready(notifyPageReady);
    jQuery(document).on('page:load', notifyPageReady);
})(window, document);