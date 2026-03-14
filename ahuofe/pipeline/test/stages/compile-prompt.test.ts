import { describe, it, expect } from "vitest";
import { compilePrompt } from "../../src/stages/compile-prompt.js";
import type { BrandEntity, SharedConfig } from "../../src/types.js";

const TEST_ENTITY: BrandEntity = {
  id: "okyeame",
  name: "Okyeame",
  class: "robotic-royal",
  base_form: "Tall humanoid figure in ceremonial regalia",
  body_parts: {
    helm: {
      description: "Crested ceremonial helm",
      material: "burnished_gold",
      color_ref: "kente_gold",
    },
    torso_armor: {
      description: "Layered plate armor with adinkra engravings",
      material: "dark_steel",
      constraints: ["no visible skin or face"],
    },
  },
  adinkra_ref: "nkyinkyim",
  poses: [
    {
      id: "idle-standing",
      name: "Idle Standing",
      description: "Standing upright, staff in right hand",
      camera_angle: "front 3/4 view",
    },
    {
      id: "speaking",
      name: "Speaking",
      description: "Animated gesture",
    },
  ],
  not_this: ["exposed face or skin", "modern clothing"],
};

const TEST_SHARED: SharedConfig = {
  colors: { kente_gold: "#D4A017" },
  materials: {
    burnished_gold: {
      description: "Warm metallic gold with subtle patina",
      sheen: "semi-reflective",
    },
    dark_steel: {
      description: "Dark gunmetal steel",
    },
  },
  adinkra_map: {
    nkyinkyim: {
      name: "Nkyinkyim",
      meaning: "Twisting, life's journey",
      rendering: "Engraved on chest plate",
    },
  },
  environment: {
    lighting: "Golden hour side-lighting",
    background: "Neutral dark gradient",
    atmosphere: "Dignified and ceremonial",
  },
};

describe("compilePrompt", () => {
  it("includes the entity name in the main prompt", () => {
    const result = compilePrompt(TEST_ENTITY, TEST_SHARED);
    expect(result.main_prompt).toContain("Okyeame");
    expect(result.entity_id).toBe("okyeame");
  });

  it("includes body part descriptions", () => {
    const result = compilePrompt(TEST_ENTITY, TEST_SHARED);
    expect(result.main_prompt).toContain("Crested ceremonial helm");
    expect(result.main_prompt).toContain("Layered plate armor");
  });

  it("includes material descriptions from shared config", () => {
    const result = compilePrompt(TEST_ENTITY, TEST_SHARED);
    expect(result.main_prompt).toContain("Warm metallic gold with subtle patina");
  });

  it("includes adinkra symbol reference", () => {
    const result = compilePrompt(TEST_ENTITY, TEST_SHARED);
    expect(result.main_prompt).toContain("Nkyinkyim");
    expect(result.main_prompt).toContain("Twisting, life's journey");
  });

  it("builds drift checklist items", () => {
    const result = compilePrompt(TEST_ENTITY, TEST_SHARED);
    expect(result.drift_checklist.length).toBeGreaterThan(0);

    const checkNames = result.drift_checklist.map((c) => c.name);
    expect(checkNames).toContain(
      "Base form is: Tall humanoid figure in ceremonial regalia",
    );
  });

  it("includes NOT_THIS guards", () => {
    const result = compilePrompt(TEST_ENTITY, TEST_SHARED);
    expect(result.not_this_guards).toContain("exposed face or skin");
    expect(result.not_this_guards).toContain("modern clothing");
    expect(result.main_prompt).toContain("NOT_THIS");
    expect(result.main_prompt).toContain("DO NOT");
  });

  it("includes negative constraints in the negative prompt", () => {
    const result = compilePrompt(TEST_ENTITY, TEST_SHARED);
    expect(result.negative_prompt).toContain("exposed face or skin");
    expect(result.negative_prompt).toContain("modern clothing");
    expect(result.negative_prompt).toContain("no visible skin or face");
    expect(result.negative_prompt).toContain("blurry");
  });

  it("uses the first pose by default when no poseId specified", () => {
    const result = compilePrompt(TEST_ENTITY, TEST_SHARED);
    expect(result.pose_id).toBe("idle-standing");
    expect(result.main_prompt).toContain("Idle Standing");
  });

  it("uses a specific pose when poseId is provided", () => {
    const result = compilePrompt(TEST_ENTITY, TEST_SHARED, "speaking");
    expect(result.pose_id).toBe("speaking");
    expect(result.main_prompt).toContain("Speaking");
    expect(result.main_prompt).toContain("Animated gesture");
  });

  it("includes environment information from shared config", () => {
    const result = compilePrompt(TEST_ENTITY, TEST_SHARED);
    expect(result.main_prompt).toContain("Golden hour side-lighting");
    expect(result.main_prompt).toContain("Neutral dark gradient");
  });

  it("computes character count", () => {
    const result = compilePrompt(TEST_ENTITY, TEST_SHARED);
    expect(result.char_count).toBe(
      result.main_prompt.length + result.negative_prompt.length,
    );
    expect(result.char_count).toBeGreaterThan(0);
  });

  it("handles entity with minimal fields", () => {
    const minimal: BrandEntity = {
      id: "simple",
      name: "Simple Entity",
      base_form: "A simple shape",
    };

    const result = compilePrompt(minimal, {});
    expect(result.entity_id).toBe("simple");
    expect(result.main_prompt).toContain("Simple Entity");
    expect(result.main_prompt).toContain("A simple shape");
    expect(result.not_this_guards).toEqual([]);
  });
});
