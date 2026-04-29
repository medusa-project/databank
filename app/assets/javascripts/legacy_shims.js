(function (window) {
    window.Databank = window.Databank || {};
    window.Databank.shims = window.Databank.shims || {};

    // permissions.html.haml currently calls addEditorRow from inline onclick.
    // Keep this alias during migration to avoid regressions.
    if (typeof window.addEditorRow !== 'function') {
        window.addEditorRow = function () {
            if (typeof window.addInternalEditorRow === 'function') {
                return window.addInternalEditorRow();
            }
            return null;
        };
    }
})(window);