/**
 * Load and validate .ahuofe.yaml configuration.
 */
import { readFileSync, existsSync } from "node:fs";
import { resolve, dirname } from "node:path";
import yaml from "js-yaml";
import type { PipelineConfig, Stage } from "./types.js";

const DEFAULTS: Partial<PipelineConfig> = {
  defaults: {
    stage: "draft" as Stage,
    max_iterations: 3,
    pass_threshold: 85,
  },
  approval: {
    require_human_approval: true,
    stages_requiring_approval: ["review", "finalize"],
    approvers: [],
    auto_approve_draft: true,
  },
  fal: {
    retention: {
      cdn_expiration_seconds: 3600,
      store_payloads: false,
      delete_after_download: true,
    },
    models: {
      draft: "fal-ai/nano-banana-2",
      review: "fal-ai/flux-pro",
      final: "fal-ai/flux-pro/kontext/max/multi",
      reference: "fal-ai/flux-pro/kontext",
      evaluator: "claude-sonnet-4-20250514",
    },
  },
  notifications: {
    post_to_pr: true,
  },
};

/**
 * Load pipeline configuration from a .ahuofe.yaml file.
 * Merges with defaults for any missing fields.
 */
export function loadConfig(configPath: string): PipelineConfig {
  const absPath = resolve(configPath);

  if (!existsSync(absPath)) {
    throw new Error(`Config file not found: ${absPath}`);
  }

  const raw = readFileSync(absPath, "utf-8");
  const parsed = yaml.load(raw) as Record<string, unknown>;

  if (!parsed || typeof parsed !== "object") {
    throw new Error(`Invalid config file: ${absPath} — expected YAML object`);
  }

  return mergeDefaults(parsed);
}

/**
 * Resolve the brand path relative to the config file's directory.
 */
export function resolveBrandPath(
  configPath: string,
  brandPath: string,
): string {
  if (brandPath.startsWith("/") || brandPath.startsWith("C:")) {
    return brandPath;
  }
  return resolve(dirname(configPath), brandPath);
}

/**
 * Merge user config with defaults, preferring user values.
 */
function mergeDefaults(
  userConfig: Record<string, unknown>,
): PipelineConfig {
  const defaults = DEFAULTS.defaults!;
  const approvalDefaults = DEFAULTS.approval!;
  const falDefaults = DEFAULTS.fal!;
  const notifDefaults = DEFAULTS.notifications!;

  const userDefaults = (userConfig.defaults as Record<string, unknown>) ?? {};
  const userApproval = (userConfig.approval as Record<string, unknown>) ?? {};
  const userFal = (userConfig.fal as Record<string, unknown>) ?? {};
  const userNotif = (userConfig.notifications as Record<string, unknown>) ?? {};

  const userFalRetention =
    (userFal.retention as Record<string, unknown>) ?? {};
  const userFalModels = (userFal.models as Record<string, unknown>) ?? {};

  return {
    plugin: (userConfig.plugin as PipelineConfig["plugin"]) ?? {
      repo: "",
      path: "",
      ref: "main",
    },
    project: (userConfig.project as PipelineConfig["project"]) ?? {
      name: "",
      command_prefix: "@ahuofe",
    },
    brand_path: (userConfig.brand_path as string) ?? "./brand",
    defaults: {
      stage: (userDefaults.stage as Stage) ?? defaults.stage,
      max_iterations:
        (userDefaults.max_iterations as number) ?? defaults.max_iterations,
      pass_threshold:
        (userDefaults.pass_threshold as number) ?? defaults.pass_threshold,
    },
    approval: {
      require_human_approval:
        (userApproval.require_human_approval as boolean) ??
        approvalDefaults.require_human_approval,
      stages_requiring_approval:
        (userApproval.stages_requiring_approval as string[]) ??
        approvalDefaults.stages_requiring_approval,
      approvers:
        (userApproval.approvers as string[]) ?? approvalDefaults.approvers,
      auto_approve_draft:
        (userApproval.auto_approve_draft as boolean) ??
        approvalDefaults.auto_approve_draft,
    },
    fal: {
      retention: {
        cdn_expiration_seconds:
          (userFalRetention.cdn_expiration_seconds as number) ??
          falDefaults.retention.cdn_expiration_seconds,
        store_payloads:
          (userFalRetention.store_payloads as boolean) ??
          falDefaults.retention.store_payloads,
        delete_after_download:
          (userFalRetention.delete_after_download as boolean) ??
          falDefaults.retention.delete_after_download,
      },
      models: {
        draft:
          (userFalModels.draft as string) ?? falDefaults.models.draft,
        review:
          (userFalModels.review as string) ?? falDefaults.models.review,
        final:
          (userFalModels.final as string) ?? falDefaults.models.final,
        reference:
          (userFalModels.reference as string) ?? falDefaults.models.reference,
        evaluator:
          (userFalModels.evaluator as string) ?? falDefaults.models.evaluator,
      },
    },
    secrets: (userConfig.secrets as PipelineConfig["secrets"]) ?? {
      fal_key: "FAL_KEY",
      anthropic_key: "ANTHROPIC_API_KEY",
    },
    notifications: {
      post_to_pr:
        (userNotif.post_to_pr as boolean) ?? notifDefaults.post_to_pr,
      label_on_pass: userNotif.label_on_pass as string | undefined,
    },
  };
}
