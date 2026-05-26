/**
 * TypeScript Error Code Knowledge Base
 * ─────────────────────────────────────
 * Modeled after how Apple (Foundation Error Codes), Mozilla (HTTP Status),
 * and Microsoft (Win32 Error Handling) document system error codes:
 *
 *   Code → Category → Description → Fix Strategy → Context Overrides
 *
 * Each error code maps to a FixStrategy — a declarative description of HOW
 * to fix it. The FixEngine reads this and applies the fix safely.
 *
 * To add a new error code: just add an entry to TS_ERROR_KNOWLEDGE.
 * No switch statements. No spaghetti. Just data.
 */

// ───── Fix Strategy Types ─────

export type FixStrategyType =
  | "ts-ignore"            // Add // @ts-ignore above the line
  | "remove-line"          // Delete the entire line
  | "remove-from-list"     // Remove identifier from export/import list
  | "prefix-underscore"    // Prefix identifier with _ (unused vars)
  | "add-type-annotation"  // Insert `: any` after identifier
  | "cast-as-any"          // Wrap identifier: (x as any)
  | "add-non-null-assert"  // Append ! after identifier
  | "change-type"          // Change existing type annotation
  | "replace-line"         // Replace entire line with new content
  | "remove-stale-directive" // Remove @ts-ignore/@ts-expect-error
  | "rename-duplicate"     // Append _1 to duplicate identifier
  | "init-variable"        // Add initializer to uninitialized declaration
  | "search-fix-declaration" // Search upward and fix declaration
  | "fix-return-type"      // Find function declaration, change return type
  | "fix-typo"             // Replace with suggested correct name
  | "cast-argument"        // Wrap function argument with type cast
  | "cast-object"          // Cast object before property access
  | "add-module-ignore"    // @ts-ignore for missing modules
  ;

export interface FixStrategy {
  type: FixStrategyType;
  reason?: string; // Human-readable reason for the fix
}

// ───── Context: when a different strategy should be used ─────

export type CodeContext =
  | "import-line"       // Line starts with import or require()
  | "export-line"       // Line starts with export {
  | "already-prefixed"  // Identifier already starts with _
  | "return-statement"  // Line starts with return
  | "no-type-annotation" // Variable declared without explicit type (let x = null)
  ;

export interface ContextOverride {
  when: CodeContext;
  strategy: FixStrategy;
}

// ───── Error Category (for grouping/display) ─────

export type ErrorCategory =
  | "type-safety"       // Type mismatches, unknown types, implicit any
  | "name-resolution"   // Cannot find name, module, property
  | "declaration"       // Duplicate, unused, uninitialized declarations
  | "syntax"            // Unexpected tokens, missing statements
  | "module"            // Import/export/require issues
  | "directive"         // @ts-ignore, @ts-expect-error issues
  | "control-flow"      // Return type, assignment before use
  | "compatibility"     // Version-specific issues
  ;

// ───── The Knowledge Entry ─────

export interface ErrorKnowledge {
  code: number;
  category: ErrorCategory;
  description: string;
  strategy: FixStrategy;
  contextOverrides?: ContextOverride[];
  messagePattern?: RegExp; // Extract info from error message
}

// ═══════════════════════════════════════════════════════════════════
//  THE KNOWLEDGE BASE
//  Each entry: code → what it means → how to fix it → context rules
// ═══════════════════════════════════════════════════════════════════

export const TS_ERROR_KNOWLEDGE: Map<number, ErrorKnowledge> = new Map([

  // ──────────── TYPE SAFETY ────────────

  [1010, {
    code: 1010,
    category: "type-safety",
    description: "Type expected",
    strategy: { type: "ts-ignore", reason: "type expected" },
  }],

  [2322, {
    code: 2322,
    category: "type-safety",
    description: "Type 'X' is not assignable to type 'Y'",
    strategy: { type: "change-type" },
    messagePattern: /Type '(.+?)' is not assignable to type '(.+?)'/,
    contextOverrides: [
      { when: "return-statement", strategy: { type: "fix-return-type" } },
      { when: "no-type-annotation", strategy: { type: "search-fix-declaration" } },
    ],
  }],

  [2345, {
    code: 2345,
    category: "type-safety",
    description: "Argument of type 'X' is not assignable to parameter of type 'Y'",
    strategy: { type: "cast-argument" },
    messagePattern: /Argument of type '(.+?)' is not assignable to parameter of type '(.+?)'/,
  }],

  [2571, {
    code: 2571,
    category: "type-safety",
    description: "Object is of type 'unknown'",
    strategy: { type: "cast-as-any", reason: "unknown type" },
  }],

  [18046, {
    code: 18046,
    category: "type-safety",
    description: "'X' is of type 'unknown' (TS 4.8+)",
    strategy: { type: "cast-as-any", reason: "unknown type" },
  }],

  [18047, {
    code: 18047,
    category: "type-safety",
    description: "'X' is possibly 'null'",
    strategy: { type: "add-non-null-assert" },
  }],

  [18048, {
    code: 18048,
    category: "type-safety",
    description: "'X' is possibly 'undefined'",
    strategy: { type: "add-non-null-assert" },
  }],

  [2352, {
    code: 2352,
    category: "type-safety",
    description: "Conversion of type 'X' to type 'Y' may be a mistake",
    strategy: { type: "ts-ignore", reason: "type conversion" },
  }],

  [2769, {
    code: 2769,
    category: "type-safety",
    description: "No overload matches this call",
    strategy: { type: "ts-ignore", reason: "no overload matches" },
  }],

  [2698, {
    code: 2698,
    category: "type-safety",
    description: "Spread types may only be created from object types",
    strategy: { type: "ts-ignore", reason: "spread type" },
  }],

  // ──────────── IMPLICIT ANY / TYPE ANNOTATIONS ────────────

  [7006, {
    code: 7006,
    category: "type-safety",
    description: "Parameter 'X' implicitly has an 'any' type",
    strategy: { type: "add-type-annotation" },
  }],

  [7005, {
    code: 7005,
    category: "type-safety",
    description: "Variable 'X' implicitly has an 'any' type",
    strategy: { type: "add-type-annotation" },
  }],

  [7015, {
    code: 7015,
    category: "type-safety",
    description: "Element implicitly has an 'any' type (index expression)",
    strategy: { type: "add-type-annotation" },
  }],

  [7031, {
    code: 7031,
    category: "type-safety",
    description: "Binding element 'X' implicitly has an 'any' type",
    strategy: { type: "add-type-annotation" },
  }],

  [7043, {
    code: 7043,
    category: "type-safety",
    description: "Variable 'X' implicitly has an 'any' type (better type may be inferred)",
    strategy: { type: "add-type-annotation" },
  }],

  [7044, {
    code: 7044,
    category: "type-safety",
    description: "Parameter 'X' implicitly has an 'any' type, but a better type may be inferred from usage",
    strategy: { type: "add-type-annotation" },
  }],

  [7008, {
    code: 7008,
    category: "type-safety",
    description: "Member 'X' implicitly has an 'any' type",
    strategy: { type: "add-type-annotation" },
  }],

  [7009, {
    code: 7009,
    category: "type-safety",
    description: "'new' expression, whose target lacks a construct signature, implicitly has an 'any' type",
    strategy: { type: "ts-ignore", reason: "implicit any from new" },
  }],

  [7010, {
    code: 7010,
    category: "type-safety",
    description: "'X', which lacks return-type annotation, implicitly has an 'any' return type",
    strategy: { type: "add-type-annotation" },
  }],

  [7011, {
    code: 7011,
    category: "type-safety",
    description: "Function expression, which lacks return-type annotation, implicitly has an 'any' return type",
    strategy: { type: "ts-ignore", reason: "implicit any return" },
  }],

  [7016, {
    code: 7016,
    category: "type-safety",
    description: "Could not find a declaration file for module 'X'",
    strategy: { type: "add-module-ignore" },
    messagePattern: /Could not find a declaration file for module '(.+?)'/,
  }],

  [7017, {
    code: 7017,
    category: "type-safety",
    description: "Element implicitly has an 'any' type (type has no index signature)",
    strategy: { type: "ts-ignore", reason: "no index signature" },
  }],

  [7022, {
    code: 7022,
    category: "type-safety",
    description: "'X' implicitly has type 'any' because it does not have a type annotation and is referenced in its own initializer",
    strategy: { type: "add-type-annotation" },
  }],

  [7023, {
    code: 7023,
    category: "type-safety",
    description: "'X' implicitly has return type 'any' because it does not have a return type annotation and is referenced in one of its return expressions",
    strategy: { type: "ts-ignore", reason: "circular return type" },
  }],

  [7024, {
    code: 7024,
    category: "type-safety",
    description: "Function implicitly has return type 'any' because it does not have a return type annotation and is referenced directly or indirectly in one of its return expressions",
    strategy: { type: "ts-ignore", reason: "circular return type" },
  }],

  [7025, {
    code: 7025,
    category: "type-safety",
    description: "Generator implicitly has yield type 'any'",
    strategy: { type: "ts-ignore", reason: "implicit yield type" },
  }],

  [7034, {
    code: 7034,
    category: "type-safety",
    description: "Variable 'X' implicitly has type 'any' in some locations where its type cannot be determined",
    strategy: { type: "add-type-annotation" },
  }],

  [7053, {
    code: 7053,
    category: "type-safety",
    description: "Element implicitly has an 'any' type (expression of type 'X' can't index 'Y')",
    strategy: { type: "ts-ignore", reason: "dynamic index access" },
  }],

  // ──────────── NAME RESOLUTION ────────────

  [2304, {
    code: 2304,
    category: "name-resolution",
    description: "Cannot find name 'X'",
    strategy: { type: "ts-ignore", reason: "name not defined" },
    messagePattern: /Cannot find name '(.+?)'/,
    contextOverrides: [
      { when: "export-line", strategy: { type: "remove-from-list" } },
      { when: "import-line", strategy: { type: "add-module-ignore" } },
    ],
  }],

  [2339, {
    code: 2339,
    category: "name-resolution",
    description: "Property 'X' does not exist on type 'Y'",
    strategy: { type: "cast-object" },
    messagePattern: /Property '(.+?)' does not exist on type '(.+?)'/,
  }],

  [2552, {
    code: 2552,
    category: "name-resolution",
    description: "Cannot find name 'X'. Did you mean 'Y'?",
    strategy: { type: "fix-typo" },
    messagePattern: /Cannot find name '(.+?)'. Did you mean '(.+?)'/,
  }],

  [2551, {
    code: 2551,
    category: "name-resolution",
    description: "Property 'X' does not exist. Did you mean 'Y'?",
    strategy: { type: "fix-typo" },
    messagePattern: /Property '(.+?)' does not exist on type '(.+?)'. Did you mean '(.+?)'/,
  }],

  // ──────────── MODULE / IMPORT / EXPORT ────────────

  [2307, {
    code: 2307,
    category: "module",
    description: "Cannot find module 'X' or its type declarations",
    strategy: { type: "add-module-ignore" },
    messagePattern: /Cannot find module '(.+?)'/,
  }],

  [2580, {
    code: 2580,
    category: "module",
    description: "Cannot find name 'require' (needs @types/node)",
    strategy: { type: "ts-ignore", reason: "needs @types/node" },
  }],

  [2584, {
    code: 2584,
    category: "module",
    description: "Cannot find name 'console' (needs @types/node)",
    strategy: { type: "ts-ignore", reason: "needs @types/node" },
  }],

  [1259, {
    code: 1259,
    category: "module",
    description: "Module 'X' can only be default-imported with esModuleInterop",
    strategy: { type: "ts-ignore", reason: "needs esModuleInterop" },
  }],

  [1192, {
    code: 1192,
    category: "module",
    description: "Module 'X' has no default export",
    strategy: { type: "ts-ignore", reason: "no default export" },
  }],

  [2497, {
    code: 2497,
    category: "module",
    description: "Module 'X' resolves to non-module entity",
    strategy: { type: "ts-ignore", reason: "non-module entity" },
  }],

  // ──────────── DECLARATIONS ────────────

  [2451, {
    code: 2451,
    category: "declaration",
    description: "Cannot redeclare block-scoped variable 'X'",
    strategy: { type: "rename-duplicate" },
    messagePattern: /Cannot redeclare block-scoped variable '(.+?)'/,
  }],

  [2300, {
    code: 2300,
    category: "declaration",
    description: "Duplicate identifier 'X'",
    strategy: { type: "remove-line" },
    messagePattern: /Duplicate identifier '(.+?)'/,
    contextOverrides: [
      // Only remove if it looks like a generated declaration
      // For real code, use @ts-ignore
    ],
  }],

  [6133, {
    code: 6133,
    category: "declaration",
    description: "'X' is declared but its value is never read",
    strategy: { type: "prefix-underscore" },
    messagePattern: /'(.+?)' is declared but/,
    contextOverrides: [
      { when: "import-line", strategy: { type: "ts-ignore", reason: "unused import" } },
      { when: "export-line", strategy: { type: "remove-from-list" } },
      { when: "already-prefixed", strategy: { type: "ts-ignore", reason: "intentionally unused" } },
    ],
  }],

  [6196, {
    code: 6196,
    category: "declaration",
    description: "'X' is declared but never used",
    strategy: { type: "prefix-underscore" },
    messagePattern: /'(.+?)' is declared but never used/,
    contextOverrides: [
      { when: "import-line", strategy: { type: "ts-ignore", reason: "unused import" } },
      { when: "already-prefixed", strategy: { type: "ts-ignore", reason: "intentionally unused" } },
    ],
  }],

  [2454, {
    code: 2454,
    category: "declaration",
    description: "Variable 'X' is used before being assigned",
    strategy: { type: "init-variable" },
    messagePattern: /Variable '(.+?)' is used before being assigned/,
  }],

  [2456, {
    code: 2456,
    category: "declaration",
    description: "Type alias 'X' circularly references itself",
    strategy: { type: "replace-line" },
    messagePattern: /Type alias '(.+?)' circularly references itself/,
  }],

  // ──────────── CONTROL FLOW / RETURN TYPES ────────────

  [2355, {
    code: 2355,
    category: "control-flow",
    description: "A function whose declared type is not 'void'/'undefined' must return a value",
    strategy: { type: "fix-return-type" },
  }],

  [2366, {
    code: 2366,
    category: "control-flow",
    description: "Function lacks ending return statement",
    strategy: { type: "fix-return-type" },
  }],

  [2365, {
    code: 2365,
    category: "control-flow",
    description: "Operator 'X' cannot be applied to types 'Y' and 'Z'",
    strategy: { type: "ts-ignore", reason: "operator type mismatch" },
  }],

  [2532, {
    code: 2532,
    category: "control-flow",
    description: "Object is possibly 'undefined'",
    strategy: { type: "add-non-null-assert" },
  }],

  [2531, {
    code: 2531,
    category: "control-flow",
    description: "Object is possibly 'null'",
    strategy: { type: "add-non-null-assert" },
  }],

  // ──────────── SYNTAX ────────────

  [1128, {
    code: 1128,
    category: "syntax",
    description: "Declaration or statement expected",
    strategy: { type: "remove-line" },
  }],

  [1005, {
    code: 1005,
    category: "syntax",
    description: "';' expected",
    strategy: { type: "ts-ignore", reason: "syntax error" },
  }],

  [1003, {
    code: 1003,
    category: "syntax",
    description: "Identifier expected",
    strategy: { type: "ts-ignore", reason: "syntax error" },
  }],

  [1002, {
    code: 1002,
    category: "syntax",
    description: "Unterminated string literal",
    strategy: { type: "ts-ignore", reason: "syntax error" },
  }],

  [1109, {
    code: 1109,
    category: "syntax",
    description: "Expression expected",
    strategy: { type: "ts-ignore", reason: "syntax error" },
  }],

  [1136, {
    code: 1136,
    category: "syntax",
    description: "Property assignment expected",
    strategy: { type: "ts-ignore", reason: "syntax error" },
  }],

  [1434, {
    code: 1434,
    category: "directive",
    description: "Unused '@ts-expect-error' directive (alternate code)",
    strategy: { type: "remove-stale-directive" },
  }],

  // ──────────── DIRECTIVES ────────────

  [2578, {
    code: 2578,
    category: "directive",
    description: "Unused '@ts-expect-error' directive",
    strategy: { type: "remove-stale-directive" },
  }],

  [2593, {
    code: 2593,
    category: "directive",
    description: "Unused '@ts-ignore' directive (with strict mode)",
    strategy: { type: "remove-stale-directive" },
  }],

  // ──────────── DEPRECATION ────────────

  [6385, {
    code: 6385,
    category: "declaration",
    description: "'X' is deprecated",
    strategy: { type: "ts-ignore", reason: "deprecated API usage" },
    messagePattern: /'(.+?)' is deprecated/,
  }],

  [6387, {
    code: 6387,
    category: "declaration",
    description: "The signature 'X' of 'Y' is deprecated",
    strategy: { type: "ts-ignore", reason: "deprecated signature" },
  }],

  // ──────────── COMPATIBILITY / MISC ────────────

  [2488, {
    code: 2488,
    category: "compatibility",
    description: "Type 'X' must have a '[Symbol.iterator]()' method",
    strategy: { type: "ts-ignore", reason: "not iterable" },
  }],

  [2538, {
    code: 2538,
    category: "compatibility",
    description: "Type 'X' cannot be used as an index type",
    strategy: { type: "ts-ignore", reason: "invalid index type" },
  }],

  [2416, {
    code: 2416,
    category: "compatibility",
    description: "Property 'X' in type 'Y' is not assignable to the same property in base type",
    strategy: { type: "ts-ignore", reason: "property override mismatch" },
  }],

  [2740, {
    code: 2740,
    category: "type-safety",
    description: "Type 'X' is missing properties from type 'Y'",
    strategy: { type: "ts-ignore", reason: "missing properties" },
  }],

  [2741, {
    code: 2741,
    category: "type-safety",
    description: "Property 'X' is missing in type 'Y' but required in type 'Z'",
    strategy: { type: "ts-ignore", reason: "missing required property" },
  }],

  [2353, {
    code: 2353,
    category: "type-safety",
    description: "Object literal may only specify known properties",
    strategy: { type: "ts-ignore", reason: "excess property" },
  }],

  [2739, {
    code: 2739,
    category: "type-safety",
    description: "Type 'X' is missing properties from type 'Y': a, b, c",
    strategy: { type: "ts-ignore", reason: "missing properties" },
  }],

  [2559, {
    code: 2559,
    category: "type-safety",
    description: "Type 'X' has no properties in common with type 'Y'",
    strategy: { type: "ts-ignore", reason: "no common properties" },
  }],

  [2589, {
    code: 2589,
    category: "type-safety",
    description: "Type instantiation is excessively deep and possibly infinite",
    strategy: { type: "ts-ignore", reason: "deep type instantiation" },
  }],

  [2540, {
    code: 2540,
    category: "type-safety",
    description: "Cannot assign to 'X' because it is a read-only property",
    strategy: { type: "ts-ignore", reason: "read-only property" },
  }],

  [2564, {
    code: 2564,
    category: "declaration",
    description: "Property 'X' has no initializer and is not definitely assigned in the constructor",
    strategy: { type: "ts-ignore", reason: "needs definite assignment" },
  }],

  [2612, {
    code: 2612,
    category: "type-safety",
    description: "Property 'X' is not assignable to the constraint of type 'Y'",
    strategy: { type: "ts-ignore", reason: "constraint mismatch" },
  }],

  [2688, {
    code: 2688,
    category: "name-resolution",
    description: "Cannot find type definition file for 'X'",
    strategy: { type: "ts-ignore", reason: "missing type definitions" },
  }],

  [2689, {
    code: 2689,
    category: "name-resolution",
    description: "Cannot extend an interface 'X'. Did you mean 'implements X' instead?",
    strategy: { type: "ts-ignore", reason: "extend vs implements" },
  }],

  [2693, {
    code: 2693,
    category: "name-resolution",
    description: "'X' only refers to a type, but is being used as a value here",
    strategy: { type: "ts-ignore", reason: "type used as value" },
  }],

  [2724, {
    code: 2724,
    category: "module",
    description: "'X' has or is using name 'Y' from private module 'Z'",
    strategy: { type: "ts-ignore", reason: "private module reference" },
  }],

  [2792, {
    code: 2792,
    category: "module",
    description: "Cannot find module 'X'. Did you mean to set moduleResolution to 'node16'?",
    strategy: { type: "add-module-ignore" },
    messagePattern: /Cannot find module '(.+?)'/,
  }],

  [2802, {
    code: 2802,
    category: "type-safety",
    description: "Type 'X' is only a type and cannot be imported/exported as a value",
    strategy: { type: "ts-ignore", reason: "type-only import needed" },
  }],

  // ──────────── STRICT NULL CHECKS ────────────

  [18049, {
    code: 18049,
    category: "type-safety",
    description: "'X' is possibly 'null' or 'undefined'",
    strategy: { type: "add-non-null-assert" },
  }],

  [18050, {
    code: 18050,
    category: "type-safety",
    description: "The value 'X' is never used",
    strategy: { type: "prefix-underscore" },
    contextOverrides: [
      { when: "already-prefixed", strategy: { type: "ts-ignore", reason: "intentionally unused" } },
    ],
  }],

  // ──────────── ADDITIONAL SYNTAX ────────────

  [1108, {
    code: 1108,
    category: "syntax",
    description: "A 'return' statement can only be used within a function body",
    strategy: { type: "remove-line" },
  }],

  [1110, {
    code: 1110,
    category: "syntax",
    description: "Type expected (in type annotation position)",
    strategy: { type: "ts-ignore", reason: "type expected" },
  }],

  [1135, {
    code: 1135,
    category: "syntax",
    description: "Argument expression expected",
    strategy: { type: "ts-ignore", reason: "syntax error" },
  }],

  [1134, {
    code: 1134,
    category: "syntax",
    description: "Variable declaration expected",
    strategy: { type: "ts-ignore", reason: "syntax error" },
  }],

  [1054, {
    code: 1054,
    category: "syntax",
    description: "A 'get' accessor cannot have parameters",
    strategy: { type: "ts-ignore", reason: "accessor error" },
  }],

  [1055, {
    code: 1055,
    category: "syntax",
    description: "A 'set' accessor must have exactly one parameter",
    strategy: { type: "ts-ignore", reason: "accessor error" },
  }],

  // ──────────── ADDITIONAL DECLARATIONS ────────────

  [6192, {
    code: 6192,
    category: "declaration",
    description: "All imports in import declaration are unused",
    strategy: { type: "remove-line" },
    contextOverrides: [
      { when: "import-line", strategy: { type: "remove-line" } },
    ],
  }],

  [6138, {
    code: 6138,
    category: "declaration",
    description: "Property 'X' is declared but its value is never read",
    strategy: { type: "prefix-underscore" },
    messagePattern: /Property '(.+?)' is declared but its value is never read/,
    contextOverrides: [
      { when: "already-prefixed", strategy: { type: "ts-ignore", reason: "intentionally unused" } },
    ],
  }],

  [6198, {
    code: 6198,
    category: "declaration",
    description: "All destructured elements are unused",
    strategy: { type: "ts-ignore", reason: "unused destructuring" },
  }],

  [6199, {
    code: 6199,
    category: "declaration",
    description: "Unused ts-expect-error directive",
    strategy: { type: "remove-stale-directive" },
  }],

  // ──────────── ADDITIONAL CONTROL FLOW ────────────

  [2367, {
    code: 2367,
    category: "control-flow",
    description: "This comparison appears to be unintentional",
    strategy: { type: "ts-ignore", reason: "intentional comparison" },
  }],

  [2358, {
    code: 2358,
    category: "control-flow",
    description: "The left-hand side of an 'instanceof' expression must be of type 'any', an object type or a type parameter",
    strategy: { type: "ts-ignore", reason: "instanceof check" },
  }],

  [7027, {
    code: 7027,
    category: "control-flow",
    description: "Unreachable code detected",
    strategy: { type: "remove-line" },
  }],

  [7030, {
    code: 7030,
    category: "control-flow",
    description: "Not all code paths return a value",
    strategy: { type: "fix-return-type" },
  }],

  [2363, {
    code: 2363,
    category: "type-safety",
    description: "The right-hand side of an arithmetic operation must be 'any', 'number', 'bigint', or enum",
    strategy: { type: "ts-ignore", reason: "arithmetic type mismatch" },
  }],

  [2362, {
    code: 2362,
    category: "type-safety",
    description: "The left-hand side of an arithmetic operation must be 'any', 'number', 'bigint', or enum",
    strategy: { type: "ts-ignore", reason: "arithmetic type mismatch" },
  }],

  [2349, {
    code: 2349,
    category: "type-safety",
    description: "This expression is not callable",
    strategy: { type: "ts-ignore", reason: "not callable" },
  }],

  [2350, {
    code: 2350,
    category: "type-safety",
    description: "Only a void function can be called with the 'new' keyword",
    strategy: { type: "ts-ignore", reason: "not constructable" },
  }],

  [2515, {
    code: 2515,
    category: "type-safety",
    description: "Non-abstract class 'X' does not implement all members of 'Y'",
    strategy: { type: "ts-ignore", reason: "missing implementation" },
  }],

  [2420, {
    code: 2420,
    category: "type-safety",
    description: "Class 'X' incorrectly implements interface 'Y'",
    strategy: { type: "ts-ignore", reason: "incorrect implementation" },
  }],

  [2694, {
    code: 2694,
    category: "module",
    description: "Namespace 'X' has no exported member 'Y'",
    strategy: { type: "ts-ignore", reason: "no exported member" },
  }],

  [2305, {
    code: 2305,
    category: "module",
    description: "Module 'X' has no exported member 'Y'",
    strategy: { type: "ts-ignore", reason: "no exported member" },
  }],

  [2503, {
    code: 2503,
    category: "name-resolution",
    description: "Cannot find namespace 'X'",
    strategy: { type: "ts-ignore", reason: "namespace not found" },
  }],

]);

// ───── Fallback for unknown error codes ─────

export const FALLBACK_STRATEGY: FixStrategy = {
  type: "ts-ignore",
  reason: "auto-suppressed by Codepet",
};

// ───── Lookup helper ─────

export function getErrorKnowledge(code: number): ErrorKnowledge | undefined {
  return TS_ERROR_KNOWLEDGE.get(code);
}

export function getFixStrategy(code: number): FixStrategy {
  return TS_ERROR_KNOWLEDGE.get(code)?.strategy ?? FALLBACK_STRATEGY;
}
