#!/usr/bin/env node
// check.mjs — is the CelynKit an app resolves the latest celyn-kit release?
//
// Single source of truth for every app consuming CelynKit (Keskonfé, Sirius,
// Pause...). Apps never copy this file: CI uses the composite action next to
// it (pinned ref), local tooling fetches it by pinned ref from raw.githubusercontent.
//
// The committed Package.resolved pins an exact version, so builds are
// reproducible but silently drift behind new celyn-kit tags. This compares
// the pinned version with the newest plain-semver tag of the remote.
//
//   node check.mjs                                  # exit 1 when behind (enforce)
//   node check.mjs --warn                           # report only (TestFlight, dry runs)
//   node check.mjs --resolved path/to/Package.resolved
//   node check.mjs --print-latest                   # print the latest release tag and exit
//   CELYNKIT_ALLOW_STALE=1 node check.mjs           # explicit waiver
//   node --test check.test.mjs
//
// Without --resolved, the single `*.xcodeproj/project.xcworkspace/xcshareddata/
// swiftpm/Package.resolved` of the current directory is used (0 or >1 match = error).
import { readFileSync, readdirSync, existsSync } from "node:fs";
import { join } from "node:path";
import { execFileSync } from "node:child_process";
import { fileURLToPath } from "node:url";

export const REMOTE = "https://github.com/jtassy-stack/celyn-kit.git";
const RESOLVED_SUFFIX = join("project.xcworkspace", "xcshareddata", "swiftpm", "Package.resolved");

/** "1.18.0" -> [1, 18, 0]; null for anything that is not plain MAJOR.MINOR.PATCH. */
export function parseSemver(s) {
  const m = /^v?(\d+)\.(\d+)\.(\d+)$/.exec(String(s).trim());
  return m ? [Number(m[1]), Number(m[2]), Number(m[3])] : null;
}

export function compare(a, b) {
  for (let i = 0; i < 3; i++) if (a[i] !== b[i]) return a[i] < b[i] ? -1 : 1;
  return 0;
}

/** Newest plain-semver tag out of `git ls-remote --tags --refs` output (other tags are ignored). */
export function latestTag(lsRemote) {
  const tags = lsRemote
    .split("\n")
    .map((l) => l.split("refs/tags/")[1])
    .filter(Boolean)
    .map((t) => ({ tag: t.trim(), v: parseSemver(t) }))
    .filter((t) => t.v);
  if (!tags.length) return null;
  return tags.reduce((best, t) => (compare(t.v, best.v) > 0 ? t : best)).tag;
}

/** Pinned celyn-kit version out of a Package.resolved (v2/v3 `pins` array). */
export function pinnedVersion(resolvedJson) {
  const pin = (resolvedJson.pins ?? []).find((p) => /celyn-?kit/i.test(p.identity ?? ""));
  return pin?.state?.version ?? null;
}

export function evaluate(pinned, latest) {
  const p = parseSemver(pinned ?? "");
  const l = parseSemver(latest ?? "");
  if (!p) return { ok: false, reason: `celyn-kit is not pinned to a released version (${pinned ?? "none"})` };
  if (!l) return { ok: false, reason: "no released celyn-kit tag found on the remote" };
  return compare(p, l) >= 0
    ? { ok: true, reason: `celyn-kit ${pinned} is the latest release` }
    : { ok: false, reason: `celyn-kit ${pinned} is behind the latest release ${latest}` };
}

/** The one Package.resolved under `<dir>/*.xcodeproj/`. Throws on 0 or several. */
export function findResolved(dir = ".") {
  const hits = readdirSync(dir)
    .filter((f) => f.endsWith(".xcodeproj"))
    .map((f) => join(dir, f, RESOLVED_SUFFIX))
    .filter((p) => existsSync(p));
  if (hits.length !== 1) {
    throw new Error(`expected exactly one *.xcodeproj/${RESOLVED_SUFFIX}, found ${hits.length}; pass --resolved <path>`);
  }
  return hits[0];
}

function arg(name) {
  const i = process.argv.indexOf(name);
  return i >= 0 ? process.argv[i + 1] : undefined;
}

function remoteLatest() {
  return latestTag(execFileSync("git", ["ls-remote", "--tags", "--refs", REMOTE], { encoding: "utf8" }));
}

function main() {
  if (process.argv.includes("--print-latest")) {
    const l = remoteLatest();
    if (!l) { console.error("no released celyn-kit tag found"); process.exit(1); }
    console.log(l);
    return;
  }
  const warnOnly = process.argv.includes("--warn");
  const waived = process.env.CELYNKIT_ALLOW_STALE === "1";
  const resolved = arg("--resolved") || findResolved();
  const pinned = pinnedVersion(JSON.parse(readFileSync(resolved, "utf8")));
  const r = evaluate(pinned, remoteLatest());
  if (r.ok) {
    console.log(`ok   ${r.reason}`);
    return;
  }
  if (warnOnly || waived) {
    console.log(`::warning::${r.reason}${waived ? " (waived: CELYNKIT_ALLOW_STALE=1)" : ""}`);
    console.log(`warn ${r.reason}`);
    return;
  }
  console.error(`::error::${r.reason}. Bump it (celynkit-bump workflow, or project.yml + Package.resolved) or set CELYNKIT_ALLOW_STALE=1 to waive.`);
  process.exit(1);
}

if (process.argv[1] === fileURLToPath(import.meta.url)) main();
