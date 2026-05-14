// Legacy global kept for inline handlers and files that call isEmail() directly.
// The canonical implementation lives in Databank.utils.isEmail (idb_utils.js).
function isEmail(email) {
    return Databank.utils.isEmail(email);
}