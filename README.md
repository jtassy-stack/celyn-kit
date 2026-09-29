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
- **Apps follow the kit**: Keskonfé's `celynkit-bump` workflow opens a PR when a newer tag exists, and its App Store submit refuses to ship a stale kit.
- **Kit changes are checked against an app before they land**: `.github/workflows/consumers.yml` builds Keskonfé against the PR branch (needs the `CONSUMER_REPO_TOKEN` secret; without it the job is skipped).
- **Where fixes go**: model, decoding and API-call fixes are made here first, then the apps bump the version. Do not patch DTOs app-side.
