/**
 * Ahuofe — Embeddable Gallery Widget
 *
 * Lightweight, self-contained module that renders an image gallery from a
 * manifest URL.  Designed to be loaded via a `<script>` tag inside GitHub
 * PR comments or any HTML page.
 *
 * Public API:
 *   initGallery(container, manifestUrl)  — bootstrap the widget
 *   renderThumbnails(images)             — render a thumbnail grid
 *   navigateImage(direction)             — move prev (-1) / next (+1)
 *
 * @module embed
 */

// ---------------------------------------------------------------------------
// State (module-scoped, one gallery per page)
// ---------------------------------------------------------------------------

let _container = null;
let _images = [];
let _currentIndex = -1;
let _detailEl = null;

// ---------------------------------------------------------------------------
// CSS (injected once)
// ---------------------------------------------------------------------------

const WIDGET_CSS = `
.ahuofe-gallery { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: #161616; border-radius: 8px; padding: 8px; color: #e0e0e0; }
.ahuofe-gallery-grid { display: flex; flex-wrap: wrap; gap: 6px; }
.ahuofe-gallery-thumb { width: 120px; height: 120px; border-radius: 6px; overflow: hidden; cursor: pointer; border: 2px solid transparent; transition: border-color 0.2s; position: relative; }
.ahuofe-gallery-thumb:hover { border-color: #32E975; }
.ahuofe-gallery-thumb img { width: 100%; height: 100%; object-fit: cover; display: block; }
.ahuofe-gallery-thumb .badge { position: absolute; bottom: 0; left: 0; right: 0; padding: 2px 4px; font-size: 9px; background: rgba(0,0,0,0.75); color: #ccc; text-align: center; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.ahuofe-gallery-detail { position: fixed; inset: 0; background: rgba(0,0,0,0.92); z-index: 10000; display: flex; align-items: center; justify-content: center; flex-direction: column; }
.ahuofe-gallery-detail img { max-width: 90%; max-height: 75vh; object-fit: contain; border-radius: 6px; }
.ahuofe-gallery-detail-meta { margin-top: 10px; text-align: center; font-size: 13px; color: #e0e0e0; }
.ahuofe-gallery-detail-meta .entity { color: #32E975; font-weight: 600; }
.ahuofe-gallery-detail-meta .stage { display: inline-block; margin-left: 8px; padding: 1px 8px; border-radius: 10px; font-size: 11px; background: rgba(153,102,255,0.2); color: #9966FF; }
.ahuofe-gallery-detail-meta .drift { margin-left: 8px; font-size: 11px; color: #888; }
.ahuofe-gallery-detail-nav { margin-top: 12px; display: flex; gap: 12px; }
.ahuofe-gallery-detail-nav button { padding: 4px 14px; border: 1px solid #333; border-radius: 6px; background: #1a1a1a; color: #e0e0e0; cursor: pointer; font-size: 13px; }
.ahuofe-gallery-detail-nav button:hover { border-color: #32E975; color: #32E975; }
.ahuofe-gallery-empty { padding: 20px; text-align: center; color: #888; font-size: 13px; }
`;

let _cssInjected = false;

function injectCSS() {
  if (_cssInjected) return;
  const style = document.createElement('style');
  style.textContent = WIDGET_CSS;
  document.head.appendChild(style);
  _cssInjected = true;
}

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/**
 * Initialise the gallery widget.
 *
 * @param {HTMLElement} container  The DOM element to render into.
 * @param {string}      manifestUrl  URL of the manifest JSON.
 * @returns {Promise<void>}
 */
export async function initGallery(container, manifestUrl) {
  if (!container) return;

  injectCSS();
  _container = container;
  _container.classList.add('ahuofe-gallery');

  let manifest;
  try {
    const res = await fetch(manifestUrl);
    manifest = await res.json();
  } catch {
    _container.innerHTML =
      '<div class="ahuofe-gallery-empty">Could not load manifest.</div>';
    return;
  }

  const images = manifest && Array.isArray(manifest.images) ? manifest.images : [];

  _images = images.map((img) => ({
    file: img.file || '',
    title: img.title || img.id || '',
    entity: manifest.entity || '',
    stage: manifest.stage || '',
    driftScore: img.driftScore ?? null,
  }));

  renderThumbnails(_images);
}

/**
 * Render a thumbnail grid inside the current container.
 *
 * @param {Array<{ file: string, title: string, entity?: string,
 *                  stage?: string, driftScore?: number | null }>} images
 */
export function renderThumbnails(images) {
  if (!_container) return;

  if (!images || images.length === 0) {
    _container.innerHTML =
      '<div class="ahuofe-gallery-empty">No images to display.</div>';
    return;
  }

  _images = images;

  const grid = document.createElement('div');
  grid.className = 'ahuofe-gallery-grid';

  images.forEach((img, idx) => {
    const thumb = document.createElement('div');
    thumb.className = 'ahuofe-gallery-thumb';

    const imgEl = document.createElement('img');
    imgEl.src = img.file;
    imgEl.alt = img.title;
    thumb.appendChild(imgEl);

    const badge = document.createElement('div');
    badge.className = 'badge';
    badge.textContent = img.title;
    thumb.appendChild(badge);

    thumb.addEventListener('click', () => openDetail(idx));
    grid.appendChild(thumb);
  });

  _container.innerHTML = '';
  _container.appendChild(grid);
}

/**
 * Navigate to the previous or next image in the detail view.
 *
 * @param {number} direction  -1 for previous, +1 for next.
 */
export function navigateImage(direction) {
  if (_images.length === 0) return;
  _currentIndex =
    ((_currentIndex + direction) % _images.length + _images.length) %
    _images.length;
  showDetail(_currentIndex);
}

// ---------------------------------------------------------------------------
// Detail view (internal)
// ---------------------------------------------------------------------------

function openDetail(idx) {
  _currentIndex = idx;

  if (!_detailEl) {
    _detailEl = document.createElement('div');
    _detailEl.className = 'ahuofe-gallery-detail';
    _detailEl.addEventListener('click', (e) => {
      if (e.target === _detailEl) closeDetail();
    });
    document.body.appendChild(_detailEl);
  }

  showDetail(idx);
  _detailEl.style.display = 'flex';
}

function showDetail(idx) {
  if (!_detailEl) return;
  const img = _images[idx];
  if (!img) return;

  const driftHtml =
    img.driftScore != null
      ? `<span class="drift">drift ${img.driftScore}</span>`
      : '';
  const entityHtml = img.entity
    ? `<span class="entity">${img.entity}</span>`
    : '';
  const stageHtml = img.stage
    ? `<span class="stage">${img.stage}</span>`
    : '';

  _detailEl.innerHTML = `
    <img src="${img.file}" alt="${img.title}">
    <div class="ahuofe-gallery-detail-meta">
      ${entityHtml}${stageHtml}${driftHtml}
      <div style="margin-top:4px;font-size:12px;color:#888;">${idx + 1} / ${_images.length}</div>
    </div>
    <div class="ahuofe-gallery-detail-nav">
      <button id="ahuofe-prev">Prev</button>
      <button id="ahuofe-close">Close</button>
      <button id="ahuofe-next">Next</button>
    </div>
  `;

  _detailEl.querySelector('#ahuofe-prev').addEventListener('click', () => navigateImage(-1));
  _detailEl.querySelector('#ahuofe-next').addEventListener('click', () => navigateImage(1));
  _detailEl.querySelector('#ahuofe-close').addEventListener('click', closeDetail);
}

function closeDetail() {
  if (_detailEl) _detailEl.style.display = 'none';
}

// ---------------------------------------------------------------------------
// Reset (useful for tests)
// ---------------------------------------------------------------------------

/**
 * Reset all internal state.  Primarily for test isolation.
 */
export function _reset() {
  _container = null;
  _images = [];
  _currentIndex = -1;
  if (_detailEl && _detailEl.parentNode) {
    _detailEl.parentNode.removeChild(_detailEl);
  }
  _detailEl = null;
}
