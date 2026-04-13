import { describe, it, expect } from 'vitest';
import { parseParams } from '../url-params.js';

describe('parseParams', () => {
  it('extracts PR number from ?pr=123', () => {
    const result = parseParams('?pr=123');
    expect(result.pr).toBe(123);
  });

  it('extracts entity filter from ?entity=okyeame', () => {
    const result = parseParams('?entity=okyeame');
    expect(result.entity).toBe('okyeame');
  });

  it('extracts commit range from ?from=abc&to=def', () => {
    const result = parseParams('?from=abc&to=def');
    expect(result.from).toBe('abc');
    expect(result.to).toBe('def');
  });

  it('returns null defaults when parameters are missing', () => {
    const result = parseParams('');
    expect(result.pr).toBeNull();
    expect(result.entity).toBeNull();
    expect(result.stage).toBeNull();
    expect(result.from).toBeNull();
    expect(result.to).toBeNull();
    expect(result.gen).toBeNull();
  });

  it('returns null defaults when called with no argument', () => {
    const result = parseParams();
    expect(result.pr).toBeNull();
    expect(result.entity).toBeNull();
  });

  it('handles malformed URLs gracefully (no throws)', () => {
    // These should not throw; they should return defaults.
    expect(() => parseParams('???===')).not.toThrow();
    expect(() => parseParams('not-a-query')).not.toThrow();
    const result = parseParams('???===');
    expect(result.pr).toBeNull();
  });

  it('parses multiple params combined: ?pr=123&entity=okyeame&stage=review', () => {
    const result = parseParams('?pr=123&entity=okyeame&stage=review');
    expect(result.pr).toBe(123);
    expect(result.entity).toBe('okyeame');
    expect(result.stage).toBe('review');
  });

  it('ignores non-positive PR numbers', () => {
    expect(parseParams('?pr=0').pr).toBeNull();
    expect(parseParams('?pr=-5').pr).toBeNull();
    expect(parseParams('?pr=abc').pr).toBeNull();
    expect(parseParams('?pr=1.5').pr).toBeNull();
  });

  it('trims whitespace from string values', () => {
    const result = parseParams('?entity=%20okyeame%20');
    expect(result.entity).toBe('okyeame');
  });

  it('returns null for empty string values', () => {
    const result = parseParams('?entity=&stage=');
    expect(result.entity).toBeNull();
    expect(result.stage).toBeNull();
  });

  it('extracts gen parameter', () => {
    const result = parseParams('?gen=gen-003');
    expect(result.gen).toBe('gen-003');
  });
});
