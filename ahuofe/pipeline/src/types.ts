/**
 * Shared types for the Ahuofe v2 pipeline.
 */

/** Generation stages in escalating cost/quality order. */
export enum Stage {
  Draft = "draft",
  Review = "review",
  Refine = "refine",
  Final = "final",
}

/** A brand entity (character, object, scene, etc.) loaded from YAML. */
export interface BrandEntity {
  id: string;
  name: string;
  class?: string;
  base_form: string;
  proportions?: Record<string, string>;
  body_parts?: Record<string, BodyPartSpec>;
  adinkra_ref?: string;
  poses?: PoseSpec[];
  not_this?: string[];
  metadata?: Record<string, unknown>;
}

/** Body-part-level specification for drift checking. */
export interface BodyPartSpec {
  description: string;
  material?: string;
  color_ref?: string;
  constraints?: string[];
}

/** A pose/view definition for an entity. */
export interface PoseSpec {
  id: string;
  name: string;
  description: string;
  camera_angle?: string;
}

/** Shared config loaded from shared YAML files (colors, materials, etc.). */
export interface SharedConfig {
  colors?: Record<string, string>;
  materials?: Record<string, MaterialSpec>;
  environment?: EnvironmentSpec;
  proportions?: Record<string, string>;
  adinkra_map?: Record<string, AdinkraSpec>;
  differentiation_matrix?: Record<string, Record<string, string>>;
}

export interface MaterialSpec {
  description: string;
  texture?: string;
  sheen?: string;
}

export interface EnvironmentSpec {
  lighting?: string;
  background?: string;
  atmosphere?: string;
}

export interface AdinkraSpec {
  name: string;
  meaning: string;
  rendering?: string;
}

/** Preset config for a generation stage. */
export interface Preset {
  name: string;
  model: string;
  reference_sheet: boolean;
  reference_model?: string;
  max_iterations: number;
  pass_threshold?: number;
  drift_evaluation: "quick" | "quick_plus" | "vision";
  output_format: "jpg" | "png";
  quality?: number;
  aspect_ratio?: string;
  requires_approval: boolean;
}

/** Result of a single image generation. */
export interface GenerationResult {
  id: string;
  entity_id: string;
  pose_id?: string;
  stage: Stage;
  model: string;
  image_path: string;
  seed?: number;
  width?: number;
  height?: number;
  prompt: string;
  drift_score?: number;
  drift_report?: DriftReport;
  timestamp: string;
  parent_id?: string;
  cost_estimate?: number;
}

/** Drift evaluation report. */
export interface DriftReport {
  score: number;
  passed: boolean;
  checks: DriftCheck[];
  summary?: string;
}

export interface DriftCheck {
  name: string;
  status: "pass" | "drift" | "unknown";
  detail?: string;
}

/** A lineage entry tracking generation parent-child relationships. */
export interface LineageEntry {
  id: string;
  timestamp: string;
  parent: string | null;
  entity_id: string;
  pose_id?: string;
  stage: Stage;
  image_count: number;
  model: string;
  drift_score?: number;
}

/** Top-level pipeline configuration loaded from .ahuofe.yaml. */
export interface PipelineConfig {
  plugin: {
    repo: string;
    path: string;
    ref: string;
  };
  project: {
    name: string;
    command_prefix: string;
    viewer_title?: string;
  };
  brand_path: string;
  defaults: {
    stage: Stage;
    max_iterations: number;
    pass_threshold: number;
  };
  approval: {
    require_human_approval: boolean;
    stages_requiring_approval: string[];
    approvers: string[];
    auto_approve_draft: boolean;
  };
  fal: FalConfig;
  secrets: {
    fal_key: string;
    anthropic_key: string;
  };
  notifications: {
    post_to_pr: boolean;
    label_on_pass?: string;
  };
}

/** fal.ai-specific configuration. */
export interface FalConfig {
  retention: {
    cdn_expiration_seconds: number;
    store_payloads: boolean;
    delete_after_download: boolean;
  };
  models: {
    draft: string;
    review: string;
    final: string;
    reference: string;
    evaluator: string;
  };
}

/** Compiled prompt ready to send to fal.ai. */
export interface CompiledPrompt {
  entity_id: string;
  pose_id?: string;
  main_prompt: string;
  negative_prompt: string;
  drift_checklist: DriftCheck[];
  not_this_guards: string[];
  char_count: number;
}

/** Parsed PR comment command. */
export interface ParsedCommand {
  command: "generate" | "regenerate" | "review" | "finalize" | "approve" | "evaluate" | "reroll" | "keep" | "compare" | "status" | "cost" | "batch" | "none";
  entity?: string;
  entities?: string[];
  pose?: string;
  stage?: Stage;
  options: Record<string, string>;
  raw: string;
}

/** fal.ai image result. */
export interface FalImage {
  url: string;
  width?: number;
  height?: number;
  content_type?: string;
}

/** fal.ai generation response. */
export interface FalGenerateResponse {
  images: FalImage[];
  seed?: number;
  timings?: Record<string, number>;
}
