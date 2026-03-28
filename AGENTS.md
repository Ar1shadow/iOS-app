# Repository Guidelines

## Project Structure & Module Organization

This repository is currently document-first. Keep top-level folders organized by topic or product area:

- `ios-app/`: iOS planning and implementation docs (tasks live under `ios-app/tasks/`).
- `learning/`: reference material and study assets such as PDFs, HTML guides, and diagrams.

The iOS app workspace lives under `ios-app/App/CoupleLife/`:

- Xcodegen spec: `ios-app/App/CoupleLife/project.yml`
- Generated Xcode project: `ios-app/App/CoupleLife/CoupleLife.xcodeproj` (generated; do not hand-edit)
- App source: `ios-app/App/CoupleLife/CoupleLife/`
- Unit tests (XCTest): `ios-app/App/CoupleLife/CoupleLifeTests/`

## Agent Quickstart

- Read `workflow.md` for the executable workflow and document-update rules.
- Use `organization.md` as the task index and milestone view.
- Start from a task file under `ios-app/tasks/` and keep it updated as you work.
- Current product/tech plan lives in `project.md`.

## Build, Test, and Development Commands

Canonical commands (Phase 1):

- Generate the Xcode project:
  - `cd ios-app/App/CoupleLife && xcodegen generate`
- Run tests:
  - `cd ios-app/App/CoupleLife && xcodebuild test -project CoupleLife.xcodeproj -scheme CoupleLife -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.6'`

Notes:
- Simulator destinations can differ between machines; adjust the `-destination` string as needed.

Optional validations:
- `rg --files .`: list working files quickly
- `markdownlint AGENTS.md project.md organization.md workflow.md`: optional Markdown linting if installed

## Coding Style & Naming Conventions

Use clear, stable names for files and folders. Prefer lowercase with hyphens for docs, for example `feature-roadmap.md`. Keep Markdown concise and sectioned with `#` headings.

For future Swift code:

- Use 4-space indentation.
- Follow Swift API Design Guidelines.
- Use `UpperCamelCase` for types and `lowerCamelCase` for methods and properties.
- Keep feature modules small and separated by domain.

## Testing Guidelines

XCTest is set up under `ios-app/App/CoupleLife/CoupleLifeTests/`. Add tests alongside new business logic before UI polish. Prefer filenames such as `TaskServiceTests.swift` and methods like `testCreatesSharedTask()`.

Add tests for new business logic before UI polish. Cover record creation, task scheduling, calendar sync mapping, and permission-gated health data reads first.

## Commit & Pull Request Guidelines

Use a consistent convention:

- Commit format: `type: short summary`
- Examples: `docs: refine iOS product scope`, `feat: add task entity model`

For pull requests, include:

- A short description of the change
- A linked issue or planning note when relevant
- Screenshots for UI changes
- Notes on data model, permissions, or sync behavior if affected

## Security & Configuration Tips

Do not commit personal health data, exported calendars, or private screenshots. Keep secrets, API keys, and provisioning details out of the repository. Document Apple capabilities, entitlements, and privacy permissions before implementing HealthKit or EventKit access.
