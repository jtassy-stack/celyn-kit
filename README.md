# CelynKit

Swift package for the [culture-api](https://celyn.io) — cultural events, venues, œuvres, seances, and critic opinions. Mirrors the TypeScript SDK at `culture-api/sdk/`.

> **Vendored copy.** Origin: `culture-api@47c76a3` (branch `feat/swift-sdk`). When the upstream SDK changes meaningfully, re-extract via `git archive feat/swift-sdk:sdk-swift | tar -x -C Packages/CelynKit` from the culture-api repo.

## Install

Local SPM dependency from the keskonfé project:

```yaml
# project.yml (XcodeGen)
packages:
  CelynKit:
    path: Packages/CelynKit
targets:
  Keskonfe:
    dependencies:
      - package: CelynKit
```

## Use

```swift
import CelynKit

let client = CultureAPIClient(apiKey: "your-key")

// Resource sugar
let events = try await client.events.list(.init(
    lat: 48.8566, lng: 2.3522, radiusKm: 5
))
let venues = try await client.venues.list(.init(
    lat: 48.8566, lng: 2.3522, hasMentions: true
))

// Or generic — decode into your own model type
let mine: MyEvent = try await client.get("events/abc")
```

## What's in the box

- `CultureAPIClient` — `Sendable` HTTP client. `get<T: Decodable>(path:query:)` decodes off the main thread, parses ISO8601 / fractional / PostgreSQL date formats, converts snake_case → camelCase.
- `CultureAPIError` — `.invalidResponse` / `.missingAPIKey` / `.httpError(statusCode:body:)`.
- DTOs: `Event`, `Venue`, `Oeuvre`, `OeuvreOpinion`, `Seance`, `RecommendedOeuvre`, plus refs (`VenueRef`, `OeuvreRef`).
- Enums: `VenueType`, `OeuvreType`, `Sentiment` — all forward-compatible (unknown values decode to `.other` / `.mixed`).
- Resource sugar: `client.events`, `client.venues`, `client.oeuvres`, `client.seances`, `client.recommendations`.

## Design notes

- **No app state.** This package owns network + decoding. Caching, observability, view models live in the consuming app.
- **Generic over T.** Apps that have their own model types (Treve's `CulturalEvent` with Pause-specific fields like `partnerId`) keep using them via `client.get<MyType>(...)`.
- **Forward-compatible enums.** API adds a new venue type tomorrow → old clients decode it as `.other` and don't crash.
- **Date strategy is custom**, not `.iso8601`, because the API mixes three formats.

## Test

```bash
swift build
swift test
```

## Releases and consumers

- **CI**: every PR builds and tests the package (`.github/workflows/ci.yml`).
- **Releases are automatic.** A merge that changes `Sources/` or `Package.swift` is tested, then tagged and published by `.github/workflows/release.yml`. The bump comes from conventional commit subjects since the last tag (`scripts/next-version.sh`): `feat:` → minor, `fix:`/other → patch, `type!:` or a `BREAKING CHANGE` body → major. Docs/CI/test-only merges do not release; add `[skip release]` to the merge commit to skip one on purpose.
- **Kit changes are checked against every app before they land**: `.github/workflows/consumers.yml` builds each consumer (matrix: Keskonfé, Sirius, Pause) against the PR branch (needs the `CONSUMER_REPO_TOKEN` secret with read access to all of them; without it the rows are skipped). Pause is `allow-failure` while it lags far behind. **New consumer app → add a matrix row.**

## Shared CI for apps (freshness guard + daily bump)

The logic lives here once; apps only keep thin callers pinned to a celyn-kit ref (never copies).

- **Freshness guard** — composite action `.github/actions/celynkit-freshness` (script `check.mjs` next to it). Compares the celyn-kit version pinned in the app's `Package.resolved` with the latest release tag. `mode: warn` for TestFlight / dry runs, `mode: enforce` for App Store submission; `allow-stale: ${{ vars.CELYNKIT_ALLOW_STALE }}` = `1` waives on purpose.
  ```yaml
  - uses: jtassy-stack/celyn-kit/.github/actions/celynkit-freshness@<sha>
    with: { mode: enforce, allow-stale: "${{ vars.CELYNKIT_ALLOW_STALE }}" }
  ```
  Local tooling (fastlane) fetches the same script by the same pinned ref from `raw.githubusercontent.com/jtassy-stack/celyn-kit/<sha>/.github/actions/celynkit-freshness/check.mjs`.
- **Daily bump PR** — reusable workflow `.github/workflows/celynkit-bump.yml` (`on: workflow_call`, header documents the inputs and a full caller). Bumps `project.yml` (XcodeGen) or the pbxproj requirement, regenerates, resolves, `build-for-testing`, opens `chore(deps): CelynKit <v>` on branch `chore/celynkit-<v>` (skipped if that branch already has an open PR). If the build fails, the PR is opened as a draft and the run fails. The caller job needs `permissions: { contents: write, pull-requests: write }` and the app repo needs "Allow GitHub Actions to create and approve pull requests".
- **Pinning and update path** — callers pin `@<full sha>` (or a semver tag of the kit: any tag cut after these files landed contains them). To change the shared logic: PR here, merge, then repoint the callers (`sed -i '' 's/<old sha>/<new sha>/' .github/workflows/*.yml` + the Fastfile URL where present) in one small PR per app. Apps carry a Dependabot `github-actions` config that proposes these repoints automatically when callers are pinned to a tag.

- **Where fixes go**: model, decoding and API-call fixes are made here first, then the apps bump the version. Do not patch DTOs app-side.
