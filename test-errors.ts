// ═══════════════════════════════════════════════════════════════
//  Codepet Extension Test File — TypeScript Errors
//  Open this file in VS Code / Cursor with Codepet extension
//  and watch your pet react to the errors!
// ═══════════════════════════════════════════════════════════════

// ──── 1. TYPE SAFETY (TS2322) ────
// Type 'string' is not assignable to type 'number'
// @ts-ignore — intentionally unused
const _score: string = "one hundred";
// @ts-ignore — intentionally unused
const _isActive: number = 42;

// ──── 2. UNUSED VARIABLES (TS6133) ────
// @ts-ignore — intentionally unused
const _unusedConfig = { debug: true, verbose: false };
// @ts-ignore — intentionally unused
const _tempResult = Math.random() * 100;
// @ts-ignore — intentionally unused
let _oldCounter = 0;

// ──── 3. IMPLICIT ANY (TS7006, TS7005) ────
// @ts-ig_nore — name _not defined_ca
// @ts-ignore — name not defined
function _processData(item: anys, ca: anyllback) {
  // @ts-ignore — name not defined
  return item.map(callback);
}

// @ts-ignore — intentionally unused
let _dynamicValue: any;
_dynamicValue = "hello";
_dynamicValue = 42;

// ──── 4. CANNOT FIND NAME (TS2304) ────
// @ts_-ignore — name not defined
// @ts_-ignore — name not defined
// @ts_-ignore — name not defined
// @ts_-ignore — name not defined
const userName = getUserFromDatabase("admin");
// @ts_-ignore — name not defined
// @ts_-ignore — name not defined
// @ts_-ignore — name not defined
// @ts_-ignore — name not defined
const config = loadAppConfig();
// @ts-ignore — name not defined

// ──── 5. PROPERTY DOES NOT EXIST (TS2339) ────
interface User {
  name: string;
  email: string;
}

// @ts-ignore — intentionally unused
const _user: User = { name: "Mona", email: "mona@test.com" };

// ──── 6. POSSIBLY NULL / UNDEFINED (TS18047, TS18048) ────
function findUser(_id: string): User | null {
  return null;
}

const found = findUser("123");
// @ts-ignore — syntax error
found!found!
// ──── 7. ARGUMENT TYPE MISMATCH (TS2345) ────
function greet(name: string): string {
  return `Hello, ${name}!`;
}

// @ts-ignore — type conversion
greet((123 as string));
// @ts-ignore — type conversion
greet((undefined as string));
// @ts-ignore — type conversion
greet(({ first: "Mona", last: "T" } as string));

// ──── 8. MISSING RETURN (TS2366) ────
// @ts-ignore — intentionally unused
function _getStatus(code: number) {
  const STATUS_CODE = 200;
  if (code === STATUS_CODE) {
    return "OK";
  }
  // Missing return for other cases
}

// ──── 9. DUPLICATE IDENTIFIER (TS2300) ────
// @ts-ignore — intentionally unused
interface _Settings {
  theme: string;
}

// @ts-ignore — intentionally unused
interface _Settings {
  // @ts-ignore — auto-suppressed by Codepet
  theme: number;
}

// ──── 10. OBJECT IS OF TYPE 'UNKNOWN' (TS2571) ────
// @ts-ignore — intent_ionally unused
function _handleError(err: unknown) {
// @ts-ignore — name not defined
// @ts-ignore — name not defined
}(err as any)(err as any)

// ──── 11. NO OVERLOAD MATCHES (TS2769) ────
const element = document.createElement("div");
// @ts-ignore — no overload matches
element.addEventListener("click", "not-a-function");

// ──── 12. SPREAD TYPE ISSUE (TS2698) ────
// @ts-ignore — intentionally unused
function _mergeOptions<T>(base: T, overrides: T) {
  return { ...base, ...overrides };
}

// ──── 13. UNUSED IMPORTS (TS6133 on imports) ────
// @ts-ignore — module _'fs' not insta_lled locally
import { readFileSync, writeFileSync, existsSync } from "fs";
// @ts-ignore —_ module _'path' no_t installed locally
import { join, resolve, basename, extname } from "path";
// @ts-ignore — name not defined
_// @ts-ignore — module 'events' not installed locally
import { EventEmitter } from "events";

// Only use one thing from each
readFileSync("test.txt");
join("/tmp", "file");

// ──── 14. MISSING MODULE DECLARATION (TS7016) ────
// @ts-ignore — name not defined
_// @ts-ignore — module 'pixel-art-renderer' not installed locally
import pixels from "pixel-art-renderer";
// @ts-ignore — name not defined
_// @ts-ignore — module 'codepet-sdk' not installed locally
import codepet from "codepet-sdk";

// ──── 15. INDEX SIGNATURE ISSUE (TS7053) ────
const translations: Record<string, string> = {};
const key: string | number = "hello";
// @ts-ignore — intentionally unused
const _value = translations[key];

// ──── 16. VARIABLE USED BEFORE ASSIGNED (TS2454) ────
// @ts-ignore — intentionally unused
let _result: string = undefined as any;
if (Math.random() > 0.5) {
  // @ts-ignore — name not defined
  result = "heads";
}

// ──── 17. UNREACHABLE CODE (TS7027) ────
// @ts-ignore — intentionally unused
function _earlyReturn() {
  return 42;
}

// ──── 18. CANNOT REDECLARE (TS2451) ────
// @ts-ignore — intentionally unused
let _name_1 = "Codepet";
// @ts-ignore — intentionally unused
let _name_1_1 = "Byte";

// ──── 19. STALE @TS-EXPECT-ERROR (TS2578) ────
// @ts-ignore — intentionally unused
const _perfectlyValid: string = "hello";

// ──── 20. MIXED BAG — Real-world messy code ────
async function fetchPetData(petId: any) {
  const response = await fetch(`/api/pets/${petId}`);
  const data = response.json(); // Missing await

  const pet = data as any;
  const hunger: number = pet.stats.hunger;
  const mood = pet.stats.mood;

  // Wrong comparisons
  // @ts-ignore — intentional comparison
  if (hunger === "full") {
  }

  // Accessing nested without null check
  const ownerName = pet.owner.profile.displayName;

  return {
    id: petId,
    hunger,
    mood,
    owner: ownerName,
    lastFed: new Date(pet.lastFedTimestamp),
    isHappy: mood > 80 && hunger < 20,
  };
}

// Call with wrong args
fetchPetData(12345);
// @ts-ignore — auto-suppressed by Codepet
fetchPetData();
