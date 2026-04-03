jQuery.noConflict();
function trapFocus(e) {
  const focusableSelectors = 'a[href], area[href], input:not([disabled]), select:not([disabled]), textarea:not([disabled]), button:not([disabled]), iframe, object, embed, [tabindex]:not([tabindex="-1"]), [contenteditable]';
  const modal = e.currentTarget || e.target;
  const focusableElements = modal.querySelectorAll(focusableSelectors);
  if (focusableElements.length === 0) {
    return;
  }

  const firstFocusable = focusableElements[0];
  const lastFocusable = focusableElements[focusableElements.length - 1];

  if (e.key === 'Tab') {
    if (!modal.contains(document.activeElement)) {
      e.preventDefault();
      firstFocusable.focus();
      return;
    }

    if (e.shiftKey) {
      if (document.activeElement === firstFocusable) {
        e.preventDefault();
        lastFocusable.focus();
      }
    } else {
      if (document.activeElement === lastFocusable) {
        e.preventDefault();
        firstFocusable.focus();
      }
    }
  }
}

// Registers delegated shown/hidden Bootstrap modal handlers that trap keyboard
// focus within the modal and focus the first focusable element on open.
// selector  - CSS selector for the modal element (e.g. '#my-modal')
// namespace - unique event namespace string (e.g. 'myModal')
function bindModalFocusTrap(selector, namespace) {
  var shownEvent  = 'shown.bs.modal.'  + namespace;
  var hiddenEvent = 'hidden.bs.modal.' + namespace;
  var focusableSelectors = 'a[href], area[href], input:not([disabled]), select:not([disabled]), textarea:not([disabled]), button:not([disabled]), iframe, object, embed, [tabindex]:not([tabindex="-1"]), [contenteditable]';

  jQuery(document)
    .off(shownEvent + ' ' + hiddenEvent, selector)
    .on(shownEvent, selector, function () {
      var modal = this;
      var focusableElements = modal.querySelectorAll(focusableSelectors);

      modal.removeEventListener('keydown', trapFocus);
      modal.addEventListener('keydown', trapFocus);

      if (focusableElements.length > 0) {
        focusableElements[0].focus();
      } else {
        modal.setAttribute('tabindex', '-1');
        modal.focus();
      }
    })
    .on(hiddenEvent, selector, function () {
      this.removeEventListener('keydown', trapFocus);
    });
}