/**
 * CLI tool to validate brand YAML against JSON schemas.
 * Works entirely offline — no API keys required.
 *
 * Usage:
 *   npx tsx src/local/validate-yaml.ts --brand ./brand
 *   npx tsx src/local/validate-yaml.ts --brand ./brand --entity okyeame
 *   npx tsx src/local/validate-yaml.ts --brand ./brand --all
 *   npx tsx src/local/validate-yaml.ts --help
 */
import { readdirSync, readFileSync, existsSync } from "node:fs";
import { resolve, join, basename } from "node:path";
import yaml from "js-yaml";
import _Ajv from "ajv";
const Ajv = _Ajv.default ?? _Ajv;

export interface ValidationError {
  file: string;
  path: string;
  message: string;
}

export interface ValidationResult {
  valid: boolean;
  file: string;
  errors: ValidationError[];
}

/**
 * Validate a single YAML file against the entity schema.
 */
export function validateEntityYaml(
  filePath: string,
  schemaDir?: string,
): ValidationResult {
  const absPath = resolve(filePath);
  const result: ValidationResult = {
    valid: true,
    file: absPath,
    errors: [],
  };

  if (!existsSync(absPath)) {
    result.valid = false;
    result.errors.push({
      file: absPath,
      path: "",
      message: `File not found: ${absPath}`,
    });
    return result;
  }

  try {
    const raw = readFileSync(absPath, "utf-8");
    const data = yaml.load(raw) as Record<string, unknown>;

    if (!data || typeof data !== "object") {
      result.valid = false;
      result.errors.push({
        file: absPath,
        path: "/",
        message: "YAML must be an object (mapping), not a scalar or array",
      });
      return result;
    }

    // Check required fields
    if (!data.base_form) {
      result.valid = false;
      result.errors.push({
        file: absPath,
        path: "/base_form",
        message: "Missing required field: base_form",
      });
    }

    if (!data.id && !data.name) {
      result.valid = false;
      result.errors.push({
        file: absPath,
        path: "/id",
        message: "Must have at least 'id' or 'name' field",
      });
    }

    // Validate body_parts structure if present
    if (data.body_parts) {
      if (typeof data.body_parts !== "object" || Array.isArray(data.body_parts)) {
        result.valid = false;
        result.errors.push({
          file: absPath,
          path: "/body_parts",
          message: "body_parts must be an object mapping part names to specs",
        });
      } else {
        for (const [partName, partSpec] of Object.entries(
          data.body_parts as Record<string, unknown>,
        )) {
          if (!partSpec || typeof partSpec !== "object") {
            result.valid = false;
            result.errors.push({
              file: absPath,
              path: `/body_parts/${partName}`,
              message: `Body part '${partName}' must be an object with at least a 'description' field`,
            });
          } else {
            const spec = partSpec as Record<string, unknown>;
            if (!spec.description) {
              result.valid = false;
              result.errors.push({
                file: absPath,
                path: `/body_parts/${partName}/description`,
                message: `Body part '${partName}' missing required 'description' field`,
              });
            }
          }
        }
      }
    }

    // Validate poses if present
    if (data.poses) {
      if (!Array.isArray(data.poses)) {
        result.valid = false;
        result.errors.push({
          file: absPath,
          path: "/poses",
          message: "poses must be an array",
        });
      }
    }

    // Validate not_this if present
    if (data.not_this && !Array.isArray(data.not_this)) {
      result.valid = false;
      result.errors.push({
        file: absPath,
        path: "/not_this",
        message: "not_this must be an array of strings",
      });
    }

    // If a JSON schema is available, use ajv for full validation
    if (schemaDir) {
      const schemaPath = join(schemaDir, "entity.schema.json");
      if (existsSync(schemaPath)) {
        const schema = JSON.parse(readFileSync(schemaPath, "utf-8"));
        const ajv = new Ajv({ allErrors: true });
        const validate = ajv.compile(schema);
        if (!validate(data)) {
          result.valid = false;
          for (const err of validate.errors ?? []) {
            result.errors.push({
              file: absPath,
              path: err.instancePath || "/",
              message: err.message ?? "Unknown schema validation error",
            });
          }
        }
      }
    }
  } catch (err) {
    result.valid = false;
    result.errors.push({
      file: absPath,
      path: "/",
      message: `YAML parse error: ${(err as Error).message}`,
    });
  }

  return result;
}

/**
 * Validate all entity YAML files in a brand directory.
 */
export function validateAllEntities(
  brandPath: string,
  schemaDir?: string,
): ValidationResult[] {
  const entitiesDir = resolve(brandPath, "entities");
  const results: ValidationResult[] = [];

  if (!existsSync(entitiesDir)) {
    results.push({
      valid: false,
      file: entitiesDir,
      errors: [
        {
          file: entitiesDir,
          path: "",
          message: `Entities directory not found: ${entitiesDir}`,
        },
      ],
    });
    return results;
  }

  const scanDir = (dir: string) => {
    for (const entry of readdirSync(dir, { withFileTypes: true })) {
      if (entry.isDirectory()) {
        scanDir(join(dir, entry.name));
      } else if (entry.name.endsWith(".yaml") || entry.name.endsWith(".yml")) {
        results.push(validateEntityYaml(join(dir, entry.name), schemaDir));
      }
    }
  };

  scanDir(entitiesDir);
  return results;
}

/**
 * CLI entry point.
 */
export function main(args: string[] = process.argv.slice(2)): void {
  if (args.includes("--help") || args.includes("-h")) {
    console.log(`
Usage: npx tsx src/local/validate-yaml.ts [options]

Options:
  --brand <path>    Path to brand directory (required)
  --entity <name>   Validate a specific entity
  --all             Validate all entities in the brand directory
  --schema <path>   Path to JSON schema directory
  --help, -h        Show this help

Examples:
  npx tsx src/local/validate-yaml.ts --brand ./brand --all
  npx tsx src/local/validate-yaml.ts --brand ./brand --entity okyeame
`);
    return;
  }

  const brandIdx = args.indexOf("--brand");
  const entityIdx = args.indexOf("--entity");
  const schemaIdx = args.indexOf("--schema");
  const all = args.includes("--all");

  if (brandIdx === -1) {
    console.error("Error: --brand <path> is required");
    process.exitCode = 1;
    return;
  }

  const brandPath = args[brandIdx + 1];
  const schemaDir = schemaIdx !== -1 ? args[schemaIdx + 1] : undefined;

  if (entityIdx !== -1) {
    const entityName = args[entityIdx + 1];
    const entitiesDir = resolve(brandPath, "entities");
    const candidates = [
      join(entitiesDir, `${entityName}.yaml`),
      join(entitiesDir, "physical", `${entityName}.yaml`),
      join(entitiesDir, "virtual", `${entityName}.yaml`),
      join(entitiesDir, "collective", `${entityName}.yaml`),
    ];

    const found = candidates.find((p) => existsSync(p));
    if (!found) {
      console.error(`Entity not found: ${entityName}`);
      process.exitCode = 1;
      return;
    }

    const result = validateEntityYaml(found, schemaDir);
    printResult(result);
    process.exitCode = result.valid ? 0 : 1;
  } else if (all) {
    const results = validateAllEntities(brandPath, schemaDir);
    let allValid = true;
    for (const result of results) {
      printResult(result);
      if (!result.valid) allValid = false;
    }
    console.log(
      `\n${results.length} files checked. ${allValid ? "All valid." : "Some files have errors."}`,
    );
    process.exitCode = allValid ? 0 : 1;
  } else {
    console.error("Error: specify --entity <name> or --all");
    process.exitCode = 1;
  }
}

function printResult(result: ValidationResult): void {
  const status = result.valid ? "PASS" : "FAIL";
  const name = basename(result.file);
  console.log(`[${status}] ${name}`);
  for (const err of result.errors) {
    console.log(`  ${err.path}: ${err.message}`);
  }
}

// Run if called directly
const isMain = process.argv[1]?.includes("validate-yaml");
if (isMain) {
  main();
}
