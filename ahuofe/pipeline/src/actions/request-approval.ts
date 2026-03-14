/**
 * Post approval gate comments and check if an approver has responded.
 */
import type { Stage } from "../types.js";

export interface ApprovalRequest {
  prNumber: number;
  stage: Stage;
  entities: string[];
  costEstimate?: number;
  approvers: string[];
}

export interface ApprovalStatus {
  approved: boolean;
  approver?: string;
  timestamp?: string;
}

/**
 * Format an approval request comment for posting to a PR.
 */
export function formatApprovalRequest(request: ApprovalRequest): string {
  const { stage, entities, costEstimate, approvers } = request;
  const lines: string[] = [];

  const stageLabel = stage.charAt(0).toUpperCase() + stage.slice(1);
  const entityList = entities.join(", ");

  lines.push(`## Approval Required -- ${stageLabel} Generation`);
  lines.push("");
  lines.push(`**Stage:** ${stageLabel}`);
  lines.push(`**Entities:** ${entityList}`);

  if (costEstimate !== undefined) {
    lines.push(`**Estimated cost:** ~$${costEstimate.toFixed(2)}`);
  }

  lines.push("");

  switch (stage) {
    case "review":
      lines.push(
        `Review generation requested for ${entityList}. This uses a mid-tier model for better quality.`,
      );
      break;
    case "final":
      lines.push(
        `Finalization requested for ${entityList}. This runs the full consistency loop with an expensive model + Claude vision evaluation.`,
      );
      break;
    default:
      lines.push(
        `${stageLabel} generation requested for ${entityList}.`,
      );
  }

  lines.push("");
  lines.push(
    `**Authorized approvers:** ${approvers.map((a) => `@${a}`).join(", ")}`,
  );
  lines.push("");
  lines.push(
    `To approve, reply with: \`@ahuofe approve\``,
  );

  return lines.join("\n");
}

/**
 * Check if an approval comment exists in a list of PR comments.
 * Looks for "@ahuofe approve" from an authorized approver.
 */
export function checkApprovalStatus(
  comments: Array<{ body: string; user: string; created_at: string }>,
  approvers: string[],
  commandPrefix: string = "@ahuofe",
): ApprovalStatus {
  const approverSet = new Set(approvers.map((a) => a.toLowerCase()));
  const approvePattern = new RegExp(
    `${commandPrefix.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}\\s+approve`,
    "i",
  );

  // Search from newest to oldest
  const sorted = [...comments].sort(
    (a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime(),
  );

  for (const comment of sorted) {
    if (
      approverSet.has(comment.user.toLowerCase()) &&
      approvePattern.test(comment.body)
    ) {
      return {
        approved: true,
        approver: comment.user,
        timestamp: comment.created_at,
      };
    }
  }

  return { approved: false };
}
