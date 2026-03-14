/**
 * URL parameter parsing for the Ahuofe lineage browser.
 *
 * Extracts PR number, entity, stage, commit range, and generation IDs
 * from the current URL search string.  All values are optional and
 * fall back to sensible defaults so callers never need null-checks.
 *
 * @module url-params
 */

/**
 * Parse viewer-relevant parameters from a URL search string.
 *
 * @param {string} [search]  The query string (e.g. location.search).
 *                            Defaults to an empty string.
 * @returns {{ pr: number | null, entity: string | null, stage: string | null,
 *             from: string | null, to: string | null, gen: string | null }}
 */
export function parseParams(search = '') {
  let params;
  try {
    params = new URLSearchParams(search);
  } catch {
    // Malformed input — return all defaults.
    return defaults();
  }

  return {
    pr: parsePositiveInt(params.get('pr')),
    entity: nonEmpty(params.get('entity')),
    stage: nonEmpty(params.get('stage')),
    from: nonEmpty(params.get('from')),
    to: nonEmpty(params.get('to')),
    gen: nonEmpty(params.get('gen')),
  };
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function defaults() {
  return { pr: null, entity: null, stage: null, from: null, to: null, gen: null };
}

/**
 * Return a positive integer or null.
 * @param {string | null} raw
 * @returns {number | null}
 */
function parsePositiveInt(raw) {
  if (raw == null) return null;
  const n = Number(raw);
  return Number.isInteger(n) && n > 0 ? n : null;
}

/**
 * Return the trimmed string if non-empty, else null.
 * @param {string | null} raw
 * @returns {string | null}
 */
function nonEmpty(raw) {
  if (raw == null) return null;
  const trimmed = raw.trim();
  return trimmed.length > 0 ? trimmed : null;
}
