/**
 * Parse @ahuofe commands from PR comments.
 * Extracts command, entity, stage, and options.
 */
import type { ParsedCommand, Stage } from "../types.js";

const COMMAND_PREFIX_DEFAULT = "@ahuofe";

const VALID_COMMANDS = [
  "generate",
  "regenerate",
  "review",
  "finalize",
  "approve",
  "evaluate",
  "reroll",
  "keep",
  "compare",
  "status",
  "cost",
  "batch",
] as const;

/**
 * Parse a PR comment body for @ahuofe commands.
 */
export function parseComment(
  body: string,
  commandPrefix: string = COMMAND_PREFIX_DEFAULT,
): ParsedCommand {
  const trimmed = body.trim();
  const prefixPattern = commandPrefix.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  const regex = new RegExp(`${prefixPattern}\\s+(\\S+)(.*)`, "i");
  const match = trimmed.match(regex);

  if (!match) {
    return {
      command: "none",
      options: {},
      raw: body,
    };
  }

  const commandStr = match[1].toLowerCase();
  const argsStr = (match[2] ?? "").trim();

  if (!isValidCommand(commandStr)) {
    return {
      command: "none",
      options: {},
      raw: body,
    };
  }

  const command = commandStr as ParsedCommand["command"];
  const parsed = parseArgs(argsStr);

  return {
    command,
    entity: parsed.positional[0],
    entities: parsed.positional.length > 0 ? parsed.positional : undefined,
    pose: parsed.flags["pose"] ?? parsed.flags["p"],
    stage: parseStage(parsed.flags["stage"] ?? parsed.flags["s"]),
    options: parsed.flags,
    raw: body,
  };
}

/**
 * Determine the implied stage from a command verb.
 */
export function impliedStage(command: ParsedCommand["command"]): Stage | undefined {
  switch (command) {
    case "generate":
    case "regenerate":
    case "reroll":
      return "draft" as Stage;
    case "review":
      return "review" as Stage;
    case "finalize":
      return "final" as Stage;
    default:
      return undefined;
  }
}

/**
 * Check if a command requires an entity name.
 */
export function requiresEntity(command: ParsedCommand["command"]): boolean {
  return [
    "generate",
    "regenerate",
    "review",
    "finalize",
    "evaluate",
    "reroll",
  ].includes(command);
}

function isValidCommand(cmd: string): boolean {
  return (VALID_COMMANDS as readonly string[]).includes(cmd);
}

function parseStage(value: string | undefined): Stage | undefined {
  if (!value) return undefined;
  const lower = value.toLowerCase();
  if (["draft", "review", "refine", "final"].includes(lower)) {
    return lower as Stage;
  }
  return undefined;
}

interface ParsedArgs {
  positional: string[];
  flags: Record<string, string>;
}

function parseArgs(argsStr: string): ParsedArgs {
  const tokens = tokenize(argsStr);
  const positional: string[] = [];
  const flags: Record<string, string> = {};

  let i = 0;
  while (i < tokens.length) {
    const token = tokens[i];

    if (token.startsWith("--")) {
      const key = token.slice(2);
      const next = tokens[i + 1];
      if (next && !next.startsWith("-")) {
        flags[key] = next;
        i += 2;
      } else {
        flags[key] = "true";
        i++;
      }
    } else if (token.startsWith("-") && token.length === 2) {
      const key = token.slice(1);
      const next = tokens[i + 1];
      if (next && !next.startsWith("-")) {
        flags[key] = next;
        i += 2;
      } else {
        flags[key] = "true";
        i++;
      }
    } else {
      positional.push(token);
      i++;
    }
  }

  return { positional, flags };
}

function tokenize(input: string): string[] {
  const tokens: string[] = [];
  let current = "";
  let inQuote = false;
  let quoteChar = "";

  for (const char of input) {
    if (inQuote) {
      if (char === quoteChar) {
        inQuote = false;
        tokens.push(current);
        current = "";
      } else {
        current += char;
      }
    } else if (char === '"' || char === "'") {
      inQuote = true;
      quoteChar = char;
    } else if (char === " " || char === "\t") {
      if (current) {
        tokens.push(current);
        current = "";
      }
    } else {
      current += char;
    }
  }

  if (current) tokens.push(current);
  return tokens;
}
