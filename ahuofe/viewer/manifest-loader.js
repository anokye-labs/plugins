/**
 * Manifest / lineage loading and filtering for the Ahuofe lineage browser.
 *
 * All functions are pure (no side-effects) so they can be tested without
 * a DOM or network.  The single exception is `fetchManifest` which wraps
 * the Fetch API for convenience but is still easy to stub in tests.
 *
 * @module manifest-loader
 */

// ---------------------------------------------------------------------------
// Fetching
// ---------------------------------------------------------------------------

/**
 * Fetch and parse a JSON manifest from a URL.
 *
 * @param {string} url
 * @returns {Promise<object | null>}  Parsed JSON or null on failure.
 */
export async function fetchManifest(url) {
  try {
    const res = await fetch(url);
    if (!res.ok) return null;
    return await res.json();
  } catch {
    return null;
  }
}

// ---------------------------------------------------------------------------
// Parsing
// ---------------------------------------------------------------------------

/**
 * Safely parse a manifest JSON string.
 *
 * @param {string} raw  Raw JSON text.
 * @returns {object | null}  The parsed object, or null when the input is
 *                           not valid JSON or is not an object.
 */
export function parseManifest(raw) {
  try {
    const data = JSON.parse(raw);
    if (data && typeof data === 'object') return data;
    return null;
  } catch {
    return null;
  }
}

// ---------------------------------------------------------------------------
// Lineage helpers
// ---------------------------------------------------------------------------

/**
 * Build a flat, ordered list of generations from a lineage object.
 *
 * The lineage object is expected to have a `generations` array.  Each entry
 * must at least contain an `id` field.  Missing or malformed data returns
 * an empty array.
 *
 * @param {object | null | undefined} lineage
 * @returns {Array<object>}
 */
export function buildGenerationList(lineage) {
  if (!lineage || !Array.isArray(lineage.generations)) return [];
  return lineage.generations.filter((g) => g && typeof g.id === 'string');
}

// ---------------------------------------------------------------------------
// Filtering
// ---------------------------------------------------------------------------

/**
 * Filter a generations array by PR number.
 *
 * @param {Array<object>} generations
 * @param {number | null} pr
 * @returns {Array<object>}
 */
export function filterByPr(generations, pr) {
  if (pr == null) return generations;
  return generations.filter((g) => g.pr === pr);
}

/**
 * Filter a generations array by entity name (case-insensitive).
 *
 * @param {Array<object>} generations
 * @param {string | null} entity
 * @returns {Array<object>}
 */
export function filterByEntity(generations, entity) {
  if (entity == null) return generations;
  const lower = entity.toLowerCase();
  return generations.filter(
    (g) => typeof g.entity === 'string' && g.entity.toLowerCase() === lower,
  );
}

/**
 * Filter a generations array by stage name (case-insensitive).
 *
 * @param {Array<object>} generations
 * @param {string | null} stage
 * @returns {Array<object>}
 */
export function filterByStage(generations, stage) {
  if (stage == null) return generations;
  const lower = stage.toLowerCase();
  return generations.filter(
    (g) => typeof g.stage === 'string' && g.stage.toLowerCase() === lower,
  );
}

/**
 * Sort generations by timestamp.
 *
 * @param {Array<object>} generations
 * @param {'asc' | 'desc'} [order='desc']  'desc' = newest first.
 * @returns {Array<object>}  A **new** sorted array (original is not mutated).
 */
export function sortByTimestamp(generations, order = 'desc') {
  const sorted = [...generations].sort((a, b) => {
    const ta = new Date(a.timestamp || 0).getTime();
    const tb = new Date(b.timestamp || 0).getTime();
    return ta - tb;
  });
  return order === 'desc' ? sorted.reverse() : sorted;
}

/**
 * Convenience: apply all filters + sort in one call.
 *
 * @param {Array<object>} generations
 * @param {{ pr?: number | null, entity?: string | null, stage?: string | null,
 *           order?: 'asc' | 'desc' }} opts
 * @returns {Array<object>}
 */
export function filterAndSort(generations, opts = {}) {
  let result = generations;
  result = filterByPr(result, opts.pr ?? null);
  result = filterByEntity(result, opts.entity ?? null);
  result = filterByStage(result, opts.stage ?? null);
  return sortByTimestamp(result, opts.order ?? 'desc');
}
