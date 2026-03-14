import { describe, it, expect } from "vitest";
import {
  formatApprovalRequest,
  checkApprovalStatus,
} from "../../src/actions/request-approval.js";
import type { Stage } from "../../src/types.js";

describe("formatApprovalRequest", () => {
  it("formats a review approval request", () => {
    const comment = formatApprovalRequest({
      prNumber: 42,
      stage: "review" as Stage,
      entities: ["okyeame"],
      costEstimate: 0.08,
      approvers: ["henry-somuah"],
    });

    expect(comment).toContain("Approval Required");
    expect(comment).toContain("Review");
    expect(comment).toContain("okyeame");
    expect(comment).toContain("$0.08");
    expect(comment).toContain("@henry-somuah");
    expect(comment).toContain("@ahuofe approve");
  });

  it("formats a finalize approval request", () => {
    const comment = formatApprovalRequest({
      prNumber: 42,
      stage: "final" as Stage,
      entities: ["okyeame", "ohemaa"],
      costEstimate: 0.75,
      approvers: ["henry-somuah"],
    });

    expect(comment).toContain("Finalization requested");
    expect(comment).toContain("okyeame, ohemaa");
    expect(comment).toContain("$0.75");
    expect(comment).toContain("consistency loop");
  });

  it("includes the approval command", () => {
    const comment = formatApprovalRequest({
      prNumber: 42,
      stage: "review" as Stage,
      entities: ["okyeame"],
      approvers: ["henry-somuah"],
    });

    expect(comment).toContain("`@ahuofe approve`");
  });
});

describe("checkApprovalStatus", () => {
  it("detects approval from authorized approver", () => {
    const comments = [
      {
        body: "@ahuofe approve",
        user: "henry-somuah",
        created_at: "2026-03-13T10:05:00Z",
      },
    ];

    const result = checkApprovalStatus(comments, ["henry-somuah"]);
    expect(result.approved).toBe(true);
    expect(result.approver).toBe("henry-somuah");
  });

  it("rejects approval from unauthorized user", () => {
    const comments = [
      {
        body: "@ahuofe approve",
        user: "random-user",
        created_at: "2026-03-13T10:05:00Z",
      },
    ];

    const result = checkApprovalStatus(comments, ["henry-somuah"]);
    expect(result.approved).toBe(false);
  });

  it("returns not approved when no approval comment exists", () => {
    const comments = [
      {
        body: "looks good but let me think about it",
        user: "henry-somuah",
        created_at: "2026-03-13T10:05:00Z",
      },
    ];

    const result = checkApprovalStatus(comments, ["henry-somuah"]);
    expect(result.approved).toBe(false);
  });

  it("handles empty comment list", () => {
    const result = checkApprovalStatus([], ["henry-somuah"]);
    expect(result.approved).toBe(false);
  });

  it("is case-insensitive for approver names", () => {
    const comments = [
      {
        body: "@ahuofe approve",
        user: "Henry-Somuah",
        created_at: "2026-03-13T10:05:00Z",
      },
    ];

    const result = checkApprovalStatus(comments, ["henry-somuah"]);
    expect(result.approved).toBe(true);
  });

  it("uses the most recent approval comment", () => {
    const comments = [
      {
        body: "@ahuofe approve",
        user: "henry-somuah",
        created_at: "2026-03-13T10:00:00Z",
      },
      {
        body: "@ahuofe approve",
        user: "other-approver",
        created_at: "2026-03-13T10:05:00Z",
      },
    ];

    const result = checkApprovalStatus(comments, [
      "henry-somuah",
      "other-approver",
    ]);
    expect(result.approved).toBe(true);
    // Most recent approval found first
    expect(result.approver).toBe("other-approver");
  });

  it("works with custom command prefix", () => {
    const comments = [
      {
        body: "@custom-bot approve",
        user: "henry-somuah",
        created_at: "2026-03-13T10:05:00Z",
      },
    ];

    const result = checkApprovalStatus(
      comments,
      ["henry-somuah"],
      "@custom-bot",
    );
    expect(result.approved).toBe(true);
  });
});
