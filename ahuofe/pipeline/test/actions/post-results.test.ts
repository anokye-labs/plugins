import { describe, it, expect } from "vitest";
import {
  formatResultsComment,
  formatDriftTable,
} from "../../src/actions/post-results.js";
import type { GenerationResult, DriftReport, Stage } from "../../src/types.js";

describe("formatResultsComment", () => {
  const TEST_RESULT: GenerationResult = {
    id: "gen-014",
    entity_id: "okyeame",
    pose_id: "idle-standing",
    stage: "draft" as Stage,
    model: "fal-ai/nano-banana-2",
    image_path: "https://raw.githubusercontent.com/example/gen/okyeame-draft.jpg",
    seed: 42,
    width: 1280,
    height: 720,
    prompt: "Okyeame prompt text",
    timestamp: "2026-03-13T10:00:00Z",
    drift_report: {
      score: 60,
      passed: false,
      checks: [
        { name: "Helm present", status: "pass" },
        { name: "Staff in right hand", status: "pass" },
        { name: "Kente drape toga-style", status: "drift" },
      ],
    },
  };

  it("includes entity and stage in the report", () => {
    const comment = formatResultsComment({
      results: [TEST_RESULT],
      stage: "draft" as Stage,
    });

    expect(comment).toContain("gen-014");
    expect(comment).toContain("okyeame");
    expect(comment).toContain("DRAFT");
    expect(comment).toContain("fal-ai/nano-banana-2");
  });

  it("includes image path in markdown image syntax", () => {
    const comment = formatResultsComment({
      results: [TEST_RESULT],
      stage: "draft" as Stage,
    });

    expect(comment).toContain("![okyeame-idle-standing-draft]");
    expect(comment).toContain(TEST_RESULT.image_path);
  });

  it("includes drift report table", () => {
    const comment = formatResultsComment({
      results: [TEST_RESULT],
      stage: "draft" as Stage,
    });

    expect(comment).toContain("Drift Report");
    expect(comment).toContain("Helm present");
    expect(comment).toContain("Pass");
    expect(comment).toContain("DRIFT");
  });

  it("includes cost estimate when provided", () => {
    const comment = formatResultsComment({
      results: [TEST_RESULT],
      stage: "draft" as Stage,
      costEstimate: 0.02,
    });

    expect(comment).toContain("$0.02");
  });

  it("includes pruned generations", () => {
    const comment = formatResultsComment({
      results: [TEST_RESULT],
      stage: "draft" as Stage,
      pruned: ["gen-012", "gen-013"],
    });

    expect(comment).toContain("Pruned");
    expect(comment).toContain("gen-012");
    expect(comment).toContain("gen-013");
  });

  it("includes next steps for draft stage", () => {
    const comment = formatResultsComment({
      results: [TEST_RESULT],
      stage: "draft" as Stage,
    });

    expect(comment).toContain("@ahuofe regenerate okyeame");
    expect(comment).toContain("@ahuofe review okyeame");
    expect(comment).toContain("@ahuofe finalize okyeame");
  });

  it("includes next steps for final stage", () => {
    const finalResult = { ...TEST_RESULT, stage: "final" as Stage };
    const comment = formatResultsComment({
      results: [finalResult],
      stage: "final" as Stage,
    });

    expect(comment).toContain("@ahuofe approve");
  });

  it("returns 'no results' message for empty results", () => {
    const comment = formatResultsComment({
      results: [],
      stage: "draft" as Stage,
    });

    expect(comment).toContain("No generation results");
  });

  it("mentions ephemeral fal.ai retention", () => {
    const comment = formatResultsComment({
      results: [TEST_RESULT],
      stage: "draft" as Stage,
    });

    expect(comment).toContain("Ephemeral");
  });
});

describe("formatDriftTable", () => {
  it("formats drift checks as a Markdown table", () => {
    const drift: DriftReport = {
      score: 80,
      passed: false,
      checks: [
        { name: "Helm present", status: "pass" },
        { name: "Kente drape", status: "drift" },
        { name: "Proportions", status: "unknown" },
      ],
    };

    const table = formatDriftTable(drift);
    expect(table).toContain("| Check | Status |");
    expect(table).toContain("| Helm present | Pass |");
    expect(table).toContain("| Kente drape | DRIFT |");
    expect(table).toContain("80/100");
    expect(table).toContain("NEEDS WORK");
  });

  it("shows PASSED for scores meeting threshold", () => {
    const drift: DriftReport = {
      score: 95,
      passed: true,
      checks: [{ name: "Check", status: "pass" }],
    };

    const table = formatDriftTable(drift);
    expect(table).toContain("PASSED");
  });
});
