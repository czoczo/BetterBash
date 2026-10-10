// Copying text out of the page, for the "Copy command" and "Copy URL" buttons.
//
// navigator.clipboard exists only in a secure context, so a page over plain http has no
// clipboard at all and writeText throws before anything is attempted. Two ways to copy:
//
//   1. navigator.clipboard.writeText, when the browser exposes it,
//   2. a throwaway textarea whose selection document.execCommand copies - the only way
//      an insecure page has.
//
// Both can still refuse (permission off, focus lost, execCommand false); the page then
// gets the reason, selects its field and leaves Ctrl+C as the last way out.

/** Why a copy did not happen, in the words the page shows under its boxes. */
export class CopyFailed extends Error {
  constructor(reason, detail) {
    super(reason.message);
    this.name = 'CopyFailed';
    this.reason = reason.kind;
    this.detail = detail;
  }
}

const REASONS = {
  // A page over plain http: no clipboard API, and no selection to copy either.
  insecure: {
    kind: 'insecure',
    message: 'Plain http leaves this page no clipboard: serve it over https, or select the text and press Ctrl+C.',
  },
  // The browser has a clipboard and refused to write it: permission off, focus
  // lost, or the page hidden.
  denied: {
    kind: 'denied',
    message: 'The browser refused to write the clipboard. Select the text and press Ctrl+C.',
  },
  // Nothing to copy with: not a browser at all (a test, node), or a browser that
  // answers neither way.
  unsupported: {
    kind: 'unsupported',
    message: 'This browser cannot copy from a page. Select the text and press Ctrl+C.',
  },
};

/**
 * The clipboard API of the browser, or null. Testing the property rather than
 * `window.isSecureContext` covers browsers that hide it and those that expose it only
 * to take it away again.
 */
function clipboardApi() {
  const api = typeof navigator === 'undefined' ? null : navigator.clipboard;
  return typeof api?.writeText === 'function' ? api : null;
}

/**
 * Copy through a selection of the document - the only way an insecure context has. The
 * field is placed over the page rather than off it, so a long command cannot scroll the
 * window, and removed whatever execCommand answered.
 */
function copySelection(text) {
  if (typeof document === 'undefined' || typeof document.execCommand !== 'function') return false;
  const area = document.createElement('textarea');
  area.value = text;
  // Readonly: selectable but not typeable. aria-hidden keeps a screen reader out of a
  // box that exists for one keystroke.
  area.setAttribute('readonly', '');
  area.setAttribute('aria-hidden', 'true');
  area.style.cssText =
    'position:fixed;top:0;left:0;width:1px;height:1px;min-height:0;padding:0;border:0;opacity:0';
  const previous = document.activeElement;
  document.body.appendChild(area);
  let copied = false;
  try {
    area.select();
    // iOS Safari ignores select() on a textarea without an explicit range.
    area.setSelectionRange?.(0, area.value.length);
    copied = document.execCommand('copy') === true;
  } catch {
    copied = false;
  } finally {
    area.remove();
    // The selection took the focus away; a keyboard user should not have to find the
    // button again.
    if (previous && typeof previous.focus === 'function') previous.focus();
  }
  return copied;
}

/**
 * Write `text` to the clipboard however it can and say which way worked: 'clipboard' or
 * 'selection'. Throws CopyFailed with the reason when neither did, so the page can
 * explain the situation instead of saying "copy it manually".
 */
export async function copyText(text) {
  const api = clipboardApi();
  let refused = null;
  if (api) {
    try {
      await api.writeText(text);
      return 'clipboard';
    } catch (error) {
      refused = error; // the selection may still take it
    }
  }
  if (copySelection(text)) return 'selection';
  if (api) throw new CopyFailed(REASONS.denied, refused);
  // Neither way available: not a browser (node running this module), or a context that
  // offers neither.
  const reason = typeof document === 'undefined' ? REASONS.unsupported : REASONS.insecure;
  throw new CopyFailed(reason, refused);
}
