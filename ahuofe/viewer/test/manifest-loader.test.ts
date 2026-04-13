import { describe, it, expect } from 'vitest';
import {
  parseManifest,
  buildGenerationList,
  filterByPr,
  filterByEntity,
  filterByStage,
  sortByTimestamp,
  filterAndSort,
} from '../manifest-loader.js';

import sampleLineage from './fixtures/sample-lineage.json';

// ---------------------------------------------------------------------------
// parseManifest
// ---------------------------------------------------------------------------

describe('parseManifest', () => {
  it('parses valid manifest JSON', () => {
    const raw = JSON.stringify({ id: 'gen-001', images: [] });
    const result = parseManifest(raw);
    expect(result).toEqual({ id: 'gen-001', images: [] });
  });

  it('returns null for invalid JSON', () => {
    expect(parseManifest('{')).toBeNull();
    expect(parseManifest('')).toBeNull();
    expect(parseManifest('null')).toBeNull();
    expect(parseManifest('42')).toBeNull();
  });
});

// ---------------------------------------------------------------------------
// buildGenerationList
// ---------------------------------------------------------------------------

describe('buildGenerationList', () => {
  it('builds generation list from lineage data', () => {
    const list = buildGenerationList(sampleLineage);
    expect(list).toHaveLength(3);
    expect(list[0].id).toBe('gen-001');
    expect(list[2].id).toBe('gen-003');
  });

  it('returns empty array for null / undefined / missing generations', () => {
    expect(buildGenerationList(null)).toEqual([]);
    expect(buildGenerationList(undefined)).toEqual([]);
    expect(buildGenerationList({})).toEqual([]);
    expect(buildGenerationList({ generations: 'bad' })).toEqual([]);
  });

  it('filters out entries without a string id', () => {
    const lineage = { generations: [{ id: 'a' }, { id: 123 }, null, { id: 'b' }] };
    const list = buildGenerationList(lineage);
    expect(list).toEqual([{ id: 'a' }, { id: 'b' }]);
  });
});

// ---------------------------------------------------------------------------
// filterByPr
// ---------------------------------------------------------------------------

describe('filterByPr', () => {
  const gens = sampleLineage.generations;

  it('filters generations by PR number', () => {
    const result = filterByPr(gens, 42);
    expect(result).toHaveLength(3);
  });

  it('returns empty when no generations match the PR', () => {
    expect(filterByPr(gens, 999)).toHaveLength(0);
  });

  it('returns all generations when pr is null', () => {
    expect(filterByPr(gens, null)).toHaveLength(3);
  });
});

// ---------------------------------------------------------------------------
// filterByEntity
// ---------------------------------------------------------------------------

describe('filterByEntity', () => {
  const gens = sampleLineage.generations;

  it('filters by entity name', () => {
    expect(filterByEntity(gens, 'okyeame')).toHaveLength(3);
  });

  it('is case-insensitive', () => {
    expect(filterByEntity(gens, 'OKYEAME')).toHaveLength(3);
  });

  it('returns empty when no match', () => {
    expect(filterByEntity(gens, 'unknown')).toHaveLength(0);
  });

  it('returns all when entity is null', () => {
    expect(filterByEntity(gens, null)).toHaveLength(3);
  });
});

// ---------------------------------------------------------------------------
// filterByStage
// ---------------------------------------------------------------------------

describe('filterByStage', () => {
  const gens = sampleLineage.generations;

  it('filters by stage', () => {
    expect(filterByStage(gens, 'draft')).toHaveLength(2);
    expect(filterByStage(gens, 'review')).toHaveLength(1);
  });

  it('is case-insensitive', () => {
    expect(filterByStage(gens, 'DRAFT')).toHaveLength(2);
  });

  it('returns all when stage is null', () => {
    expect(filterByStage(gens, null)).toHaveLength(3);
  });
});

// ---------------------------------------------------------------------------
// sortByTimestamp
// ---------------------------------------------------------------------------

describe('sortByTimestamp', () => {
  const gens = sampleLineage.generations;

  it('sorts newest first by default (desc)', () => {
    const sorted = sortByTimestamp(gens);
    expect(sorted[0].id).toBe('gen-003');
    expect(sorted[2].id).toBe('gen-001');
  });

  it('sorts oldest first when order is asc', () => {
    const sorted = sortByTimestamp(gens, 'asc');
    expect(sorted[0].id).toBe('gen-001');
    expect(sorted[2].id).toBe('gen-003');
  });

  it('does not mutate the original array', () => {
    const original = [...gens];
    sortByTimestamp(gens, 'desc');
    expect(gens).toEqual(original);
  });

  it('handles missing timestamps gracefully', () => {
    const items = [{ id: 'a' }, { id: 'b', timestamp: '2026-01-01T00:00:00Z' }];
    const sorted = sortByTimestamp(items, 'asc');
    // Missing timestamp treated as epoch 0, so comes first in ascending
    expect(sorted[0].id).toBe('a');
  });
});

// ---------------------------------------------------------------------------
// filterAndSort (combined convenience)
// ---------------------------------------------------------------------------

describe('filterAndSort', () => {
  const gens = sampleLineage.generations;

  it('applies pr + entity + stage filters and sorts desc', () => {
    const result = filterAndSort(gens, { pr: 42, entity: 'okyeame', stage: 'draft' });
    expect(result).toHaveLength(2);
    expect(result[0].id).toBe('gen-002'); // newer draft first
  });

  it('returns empty for mismatched filters', () => {
    expect(filterAndSort(gens, { pr: 1 })).toHaveLength(0);
  });

  it('returns all sorted desc with no filters', () => {
    const result = filterAndSort(gens);
    expect(result).toHaveLength(3);
    expect(result[0].id).toBe('gen-003');
  });
});

// ---------------------------------------------------------------------------
// Handles missing / malformed manifest JSON
// ---------------------------------------------------------------------------

describe('error handling', () => {
  it('parseManifest returns null for malformed JSON', () => {
    expect(parseManifest('not json')).toBeNull();
    expect(parseManifest(undefined as unknown as string)).toBeNull();
  });

  it('buildGenerationList returns empty for garbage input', () => {
    expect(buildGenerationList({ generations: [null, undefined, 42] })).toEqual([]);
  });
});
