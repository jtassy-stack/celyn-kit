import test from "node:test";
import assert from "node:assert/strict";
import { parseSemver, latestTag, pinnedVersion, evaluate, findResolved } from "./check.mjs";

const LS = [
  "aaa\trefs/tags/1.9.0",
  "bbb\trefs/tags/1.16.1",
  "ccc\trefs/tags/1.18.0",
  "ddd\trefs/tags/1.17.0",
  "eee\trefs/tags/v2.0.0-beta.1",
  "fff\trefs/tags/not-a-version",
].join("\n");

test("parseSemver accepts plain MAJOR.MINOR.PATCH only", () => {
  assert.deepEqual(parseSemver("1.18.0"), [1, 18, 0]);
  assert.deepEqual(parseSemver("v1.2.3"), [1, 2, 3]);
  assert.equal(parseSemver("2.0.0-beta.1"), null);
  assert.equal(parseSemver("main"), null);
});

test("latestTag compares numerically (1.18.0 > 1.9.0) and ignores pre-releases", () => {
  assert.equal(latestTag(LS), "1.18.0");
  assert.equal(latestTag(""), null);
});

test("pinnedVersion reads the celyn-kit pin from Package.resolved", () => {
  const resolved = { pins: [{ identity: "other", state: { version: "9.9.9" } }, { identity: "celyn-kit", state: { version: "1.16.1" } }] };
  assert.equal(pinnedVersion(resolved), "1.16.1");
  assert.equal(pinnedVersion({ pins: [] }), null);
});

test("evaluate: behind fails, equal or ahead passes, missing data fails", () => {
  assert.equal(evaluate("1.16.1", "1.18.0").ok, false);
  assert.equal(evaluate("1.18.0", "1.18.0").ok, true);
  assert.equal(evaluate("1.19.0", "1.18.0").ok, true);
  assert.equal(evaluate(null, "1.18.0").ok, false);
  assert.equal(evaluate("1.18.0", null).ok, false);
});

test("findResolved picks the single *.xcodeproj Package.resolved, refuses 0 or several", async () => {
  const { mkdtempSync, mkdirSync, writeFileSync } = await import("node:fs");
  const { tmpdir } = await import("node:os");
  const { join } = await import("node:path");
  const sub = join("project.xcworkspace", "xcshareddata", "swiftpm");
  const d = mkdtempSync(join(tmpdir(), "ckf-"));
  assert.throws(() => findResolved(d), /found 0/);
  mkdirSync(join(d, "App.xcodeproj", sub), { recursive: true });
  writeFileSync(join(d, "App.xcodeproj", sub, "Package.resolved"), "{}");
  assert.equal(findResolved(d), join(d, "App.xcodeproj", sub, "Package.resolved"));
  mkdirSync(join(d, "Other.xcodeproj", sub), { recursive: true });
  writeFileSync(join(d, "Other.xcodeproj", sub, "Package.resolved"), "{}");
  assert.throws(() => findResolved(d), /found 2/);
});
