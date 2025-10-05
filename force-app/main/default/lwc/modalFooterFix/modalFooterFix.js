import MODAL_FOOTER_FIX from '@salesforce/resourceUrl/modal_footer_fix'; // Static Resource NAME

let linkEl;         // global stylesheet link element
let refCount = 0;   // how many modals are opting in right now

function ensureSheetLoaded() {
  if (linkEl) return;
  linkEl = document.createElement('link');
  linkEl.rel = 'stylesheet';
  linkEl.href = MODAL_FOOTER_FIX;     // e.g., /resource/<cache-bust>/modal-footer-fix.css
  linkEl.type = 'text/css';
  linkEl.dataset.mff = '1';
  document.head.appendChild(linkEl);
}

export function enableModalFix() {
  ensureSheetLoaded();
  refCount += 1;
  document.body.classList.add('mff-active'); // opt-in flag for our CSS rules
}

export function disableModalFix() {
  refCount = Math.max(0, refCount - 1);
  if (refCount === 0) {
    document.body.classList.remove('mff-active');
  }
}
