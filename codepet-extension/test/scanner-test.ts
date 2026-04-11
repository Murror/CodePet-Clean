// ── This file tests all 3 tiers of the Codepet scanner ──

// 🔴 ERROR tier
debugger;

// 🟡 WARNING tier — console.log
console.log("testing the scanner");

// 🟡 WARNING tier — var instead of const/let
var oldSchool = "should be const";

// 🟡 WARNING tier — any type
function processData(input: any): any {
  return input;
}

// 🟡 WARNING tier — empty catch
try {
  JSON.parse("bad json");
} catch (e) {}

// 🟡 WARNING tier — loose equality (JS pattern, won't fire in .ts)
// if (x == 5) {}

// 🟡 WARNING tier — TODO
// TODO: refactor this later

// 🟡 WARNING tier — FIXME
// FIXME: this breaks on edge cases

// 🟡 WARNING tier — nested ternary
const status = true ? (false ? "a" : "b") : "c";

// 🟢 CLEAN tier — good error handling
try {
  const data = JSON.parse('{"valid": true}');
  console.log(data);
} catch (error) {
  console.error("Parse failed:", error);
}

// 🟢 CLEAN tier — JSDoc comment
/**
 * Calculates the sum of two numbers.
 * @param a - First number
 * @param b - Second number
 */
function add(a: number, b: number): number {
  return a + b;
}

// 🟢 CLEAN tier — const usage
const MAX_RETRIES = 3;
const API_URL = "https://api.codepet.dev";

// 🟢 CLEAN tier — guard clause
function validateUser(user: { name?: string }) {
  if (!user.name) return null;
  return user.name.trim();
}

// 🟢 CLEAN tier — type annotation
const greeting: string = "Hello from Codepet!";
const count: number = 42;

export { add, validateUser, processData, greeting, count, status, oldSchool, MAX_RETRIES, API_URL };
