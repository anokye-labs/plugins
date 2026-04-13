import { describe, it, expect, beforeEach, vi, afterEach } from 'vitest';
import {
  initGallery,
  renderThumbnails,
  navigateImage,
  _reset,
} from '../embed.js';

import sampleManifest from './fixtures/sample-manifest.json';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function makeContainer(): HTMLDivElement {
  const el = document.createElement('div');
  document.body.appendChild(el);
  return el;
}

function stubFetchWith(data: unknown) {
  vi.stubGlobal(
    'fetch',
    vi.fn().mockResolvedValue({
      ok: true,
      json: () => Promise.resolve(data),
    }),
  );
}

// ---------------------------------------------------------------------------
// Setup / Teardown
// ---------------------------------------------------------------------------

beforeEach(() => {
  _reset();
  document.body.innerHTML = '';
});

afterEach(() => {
  _reset();
  vi.restoreAllMocks();
});

// ---------------------------------------------------------------------------
// initGallery
// ---------------------------------------------------------------------------

describe('initGallery', () => {
  it('initialises the widget with a container and manifest URL', async () => {
    stubFetchWith(sampleManifest);
    const container = makeContainer();

    await initGallery(container, 'http://example.com/manifest.json');

    expect(container.classList.contains('ahuofe-gallery')).toBe(true);
    expect(container.querySelectorAll('.ahuofe-gallery-thumb').length).toBe(2);
  });

  it('renders correct number of thumbnails from manifest data', async () => {
    stubFetchWith(sampleManifest);
    const container = makeContainer();

    await initGallery(container, 'http://example.com/manifest.json');

    const thumbs = container.querySelectorAll('.ahuofe-gallery-thumb');
    expect(thumbs.length).toBe(sampleManifest.images.length);
  });

  it('handles empty manifest gracefully', async () => {
    stubFetchWith({ images: [] });
    const container = makeContainer();

    await initGallery(container, 'http://example.com/manifest.json');

    expect(container.querySelector('.ahuofe-gallery-empty')).not.toBeNull();
    expect(container.querySelectorAll('.ahuofe-gallery-thumb').length).toBe(0);
  });

  it('handles fetch failure gracefully', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn().mockRejectedValue(new Error('Network error')),
    );
    const container = makeContainer();

    await initGallery(container, 'http://example.com/bad.json');

    expect(container.querySelector('.ahuofe-gallery-empty')).not.toBeNull();
  });

  it('does nothing when container is null', async () => {
    stubFetchWith(sampleManifest);
    // Should not throw
    await expect(initGallery(null as unknown as HTMLElement, 'url')).resolves.toBeUndefined();
  });
});

// ---------------------------------------------------------------------------
// renderThumbnails
// ---------------------------------------------------------------------------

describe('renderThumbnails', () => {
  it('renders a grid of thumbnails', async () => {
    stubFetchWith(sampleManifest);
    const container = makeContainer();
    await initGallery(container, 'url');

    const images = [
      { file: 'a.png', title: 'A' },
      { file: 'b.png', title: 'B' },
      { file: 'c.png', title: 'C' },
    ];

    renderThumbnails(images);

    expect(container.querySelectorAll('.ahuofe-gallery-thumb').length).toBe(3);
  });

  it('shows empty message for null images', async () => {
    stubFetchWith(sampleManifest);
    const container = makeContainer();
    await initGallery(container, 'url');

    renderThumbnails(null as unknown as any[]);

    expect(container.querySelector('.ahuofe-gallery-empty')).not.toBeNull();
  });
});

// ---------------------------------------------------------------------------
// Thumbnail click -> detail view
// ---------------------------------------------------------------------------

describe('thumbnail click triggers detail view', () => {
  it('opens a detail overlay when a thumbnail is clicked', async () => {
    stubFetchWith(sampleManifest);
    const container = makeContainer();
    await initGallery(container, 'url');

    const thumb = container.querySelector('.ahuofe-gallery-thumb') as HTMLElement;
    thumb.click();

    const detail = document.querySelector('.ahuofe-gallery-detail') as HTMLElement;
    expect(detail).not.toBeNull();
    expect(detail.style.display).toBe('flex');
  });

  it('shows entity name and stage badge in detail view', async () => {
    stubFetchWith(sampleManifest);
    const container = makeContainer();
    await initGallery(container, 'url');

    const thumb = container.querySelector('.ahuofe-gallery-thumb') as HTMLElement;
    thumb.click();

    const detail = document.querySelector('.ahuofe-gallery-detail') as HTMLElement;
    expect(detail.querySelector('.entity')?.textContent).toBe('okyeame');
    expect(detail.querySelector('.stage')?.textContent).toBe('review');
  });
});

// ---------------------------------------------------------------------------
// navigateImage
// ---------------------------------------------------------------------------

describe('navigateImage', () => {
  it('cycles forward through images', async () => {
    stubFetchWith(sampleManifest);
    const container = makeContainer();
    await initGallery(container, 'url');

    // Open the first image
    const thumb = container.querySelector('.ahuofe-gallery-thumb') as HTMLElement;
    thumb.click();

    navigateImage(1);

    const detail = document.querySelector('.ahuofe-gallery-detail') as HTMLElement;
    // Should now show "2 / 2"
    expect(detail.textContent).toContain('2 / 2');
  });

  it('cycles backward (wraps around)', async () => {
    stubFetchWith(sampleManifest);
    const container = makeContainer();
    await initGallery(container, 'url');

    const thumb = container.querySelector('.ahuofe-gallery-thumb') as HTMLElement;
    thumb.click();

    navigateImage(-1);

    const detail = document.querySelector('.ahuofe-gallery-detail') as HTMLElement;
    // Wraps from index 0 to last (index 1 for 2 images)
    expect(detail.textContent).toContain('2 / 2');
  });

  it('does nothing when there are no images', () => {
    // No gallery initialised, should not throw
    expect(() => navigateImage(1)).not.toThrow();
  });
});
