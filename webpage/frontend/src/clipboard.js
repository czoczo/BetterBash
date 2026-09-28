// Copying text out of the page, for the "Copy command" and "Copy URL" buttons.
//
// The clipboard API is not available everywhere a page runs. Browsers expose
// navigator.clipboard only to a secure context, so a page loaded over plain http
// - `./dev.sh` on a host name, a preview reached by a LAN address, the Pages
// deployment reached over http before it redirects - has no clipboard to write at
// all, and `navigator.clipboard.writeText(...)` throws a TypeError before anything
// is attempted. That is the difference between the button working on
// https://betterbash.cz0.cz and refusing on http://devcode.dom.cz0.cz:5173.
//
// So there are two ways to copy, and the second is not merely a fallback for old
// browsers but the only way an insecure page has:
//
//   1. navigator.clipboard.writeText, when the browser exposes it,
//   2. a throwaway textarea whose selection is copied by document.execCommand,
//      which insecure contexts still answer.
//
// Both can still refuse - the API denies a write whose document lost focus or
// whose permission is off, execCommand answers false - and when neither worked the
// page is handed the reason, selects the field the button belongs to and leaves
// Ctrl+C as the last way out.

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
 * The clipboard API of the browser, or null when there is none.
 *
 * A secure context is what decides whether the property exists, so testing the
 * property rather than `window.isSecureContext` covers both the browsers that hide
 * it and the ones that expose it only to take it away again later.
 */
export function clipboardApi() {
  const api = typeof navigator === 'undefined' ? null : navigator.clipboard;
  return typeof api?.writeText === 'function' ? api : null;
}

/**
 * Copy through a selection of the document: the old way, and the only one an
 * insecure context has. The field is placed over the page rather than off it, so a
 * copy of a long command cannot scroll the window, and it is removed again whatever
 * execCommand answered.
 */
function copySelection(text) {
  if (typeof document === 'undefined' || typeof document.execCommand !== 'function') return false;
  const area = document.createElement('textarea');
  area.value = text;
  // A readonly field is selectable but cannot be typed into, and aria-hidden keeps
  // a screen reader out of a box that exists for one keystroke.
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
    // The selection above took the focus away from whatever had it - the button
    // usually - and a keyboard user should not have to find it again.
    if (previous && typeof previous.focus === 'function') previous.focus();
  }
  return copied;
}

/**
 * Write `text` to the clipboard however it can, and say which way worked:
 * 'clipboard' for the API, 'selection' for the copied selection. Throws
 * CopyFailed with the reason when neither did, which is what lets the page show
 * one message that explains the situation instead of "copy it manually".
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
  // No clipboard API and no selection either: nowhere near a browser (a test
  // running the module under node), or a context that offers neither way.
  const reason = typeof document === 'undefined' ? REASONS.unsupported : REASONS.insecure;
  throw new CopyFailed(reason, refused);
}
