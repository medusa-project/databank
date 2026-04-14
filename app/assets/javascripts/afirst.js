jQuery.noConflict();

function canReceiveFocus(element) {
  if (!element || typeof element.focus !== 'function' || !document.contains(element)) {
    return false;
  }

  if (element.disabled) {
    return false;
  }

  return element.getClientRects().length > 0;
}

function findModalTrigger(modal) {
  if (!modal || !modal.id) {
    return null;
  }

  var selector = '[data-target="#' + modal.id + '"], [href="#' + modal.id + '"]';
  var candidates = document.querySelectorAll(selector);

  for (var i = 0; i < candidates.length; i += 1) {
    if (canReceiveFocus(candidates[i])) {
      return candidates[i];
    }
  }

  return null;
}

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
  var showEvent = 'show.bs.modal.' + namespace;
  var shownEvent  = 'shown.bs.modal.'  + namespace;
  var hiddenEvent = 'hidden.bs.modal.' + namespace;
  var focusableSelectors = 'a[href], area[href], input:not([disabled]), select:not([disabled]), textarea:not([disabled]), button:not([disabled]), iframe, object, embed, [tabindex]:not([tabindex="-1"]), [contenteditable]';

  jQuery(document)
    .off(showEvent + ' ' + shownEvent + ' ' + hiddenEvent, selector)
    .on(showEvent, selector, function () {
      var modal = this;
      var activeElement = document.activeElement;

      if (canReceiveFocus(activeElement) && activeElement !== modal && !modal.contains(activeElement)) {
        modal.__openerElement = activeElement;
      } else {
        modal.__openerElement = null;
      }
    })
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
      var modal = this;
      var opener = modal.__openerElement;
      var fallback;

      this.removeEventListener('keydown', trapFocus);

      if (canReceiveFocus(opener)) {
        opener.focus();
      } else {
        fallback = findModalTrigger(modal);
        if (canReceiveFocus(fallback)) {
          fallback.focus();
        }
      }

      modal.__openerElement = null;
    });
}

bindModalFocusTrap('.modal', 'globalModalFocus');