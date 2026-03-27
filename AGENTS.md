# Repository Guidelines

## Project Structure & Module Organization

This repository is currently document-first. Keep top-level folders organized by topic or product area:

- `ios-app/`: iOS planning and implementation docs (tasks live under `ios-app/tasks/`).
- `learning/`: reference material and study assets such as PDFs, HTML guides, and diagrams.

When application code is added, place it under `ios-app/App/`, tests under `ios-app/Tests/`, and assets under `ios-app/Assets/`. Avoid mixing generated files and notes with source files.

## Agent Quickstart

- Read `workflow.md` for the executable workflow and document-update rules.
- Use `organization.md` as the task index and milestone view.
- Start from a task file under `ios-app/tasks/` and keep it updated as you work.
- Current product/tech plan lives in `project.md`.

## Build, Test, and Development Commands

There is no build system configured yet. For now, use simple validation commands:

- `rg --files .`: list working files quickly.
- `markdownlint AGENTS.md project.md organization.md workflow.md`: optional Markdown linting if installed.
- `open project.md`: review the main product plan on macOS.

Once the iOS app is created, document the canonical commands here, for example:

- `xcodebuild -scheme App build`
- `xcodebuild test -scheme App -destination 'platform=iOS Simulator,name=iPhone 16'`

## Coding Style & Naming Conventions

Use clear, stable names for files and folders. Prefer lowercase with hyphens for docs, for example `feature-roadmap.md`. Keep Markdown concise and sectioned with `#` headings.

For future Swift code:

- Use 4-space indentation.
- Follow Swift API Design Guidelines.
- Use `UpperCamelCase` for types and `lowerCamelCase` for methods and properties.
- Keep feature modules small and separated by domain.

## Testing Guidelines

No test framework is present yet. When code is introduced, add automated tests alongside the app module. Prefer XCTest, with filenames such as `TaskServiceTests.swift` and methods like `testCreatesSharedTask()`.

Add tests for new business logic before UI polish. Cover record creation, task scheduling, calendar sync mapping, and permission-gated health data reads first.

## Commit & Pull Request Guidelines

Git history is not available in this directory yet, so use a consistent convention from the start:

- Commit format: `type: short summary`
- Examples: `docs: refine iOS product scope`, `feat: add task entity model`

For pull requests, include:

- A short description of the change
- A linked issue or planning note when relevant
- Screenshots for UI changes
- Notes on data model, permissions, or sync behavior if affected

## Security & Configuration Tips

Do not commit personal health data, exported calendars, or private screenshots. Keep secrets, API keys, and provisioning details out of the repository. Document Apple capabilities, entitlements, and privacy permissions before implementing HealthKit or EventKit access.
