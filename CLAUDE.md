# HeatingPlanner

Cross-platform Flutter application for designing optimized floor and wall heating systems. Targets macOS, Linux, Windows, iOS (iPad), and Android.

## Environment Setup

If the development environment is not yet configured (Flutter SDK, Xcode, Android Studio, platform toolchains), follow `.claude/setup-guide.md` before any other work. That guide is run once per machine and covers all five target platforms.

## Agent Reference Files

This project uses role-specific instruction files. **Before writing any code, read the relevant agent file(s) for the task at hand.** Most tasks require reading the Architect file plus one specialist file.

| File | Role | Read When |
|------|------|-----------|
| `.claude/agent-architect.md` | Data models, directory structure, state management, provider contracts, coding standards | ANY structural work, model changes, new providers, code review |
| `.claude/agent-hvac.md` | Calculation engines, formulas, physical constants, material database, EN standards | ANY calculation or formula work, constant definitions, material data |
| `.claude/agent-ui-ux.md` | Interaction specs, design tokens, wireframes, platform patterns, accessibility | ANY UI layout, interaction flow, visual design, responsive behavior |
| `.claude/agent-frontend.md` | Widget implementation, canvas, painters, tools, panels, platform code | ANY Flutter widget, painter, tool, screen, or export implementation |
| `.claude/agent-test.md` | Test strategy, reference values, coverage requirements, performance benchmarks | ANY test writing, bug investigation, coverage analysis |

## Architecture Rules (Always Enforced)

These rules apply to every code change regardless of which agent file is active:

1. **Layer imports are one-directional:** UI → Calculation → Repository → Data. Never import upward. UI never imports repositories directly.
2. **All data models are freezed immutable classes** with toJson/fromJson. Do not create mutable model classes.
3. **Calculation engines are pure static functions** in `lib/calculation/engines/`. No state, no I/O, no provider access. Return `double.nan` for invalid inputs.
4. **UI accesses data only through Riverpod providers.** Never import a DAO or repository class in a widget file.
5. **No hard-coded colours or spacing in widgets.** Use theme tokens from `HeatingPlannerColors` extension and the 4px spacing grid.
6. **Every numeric field name includes its unit suffix:** `Mm`, `M`, `C`, `Pa`, `KgH`, `WPerM2K`.
7. **Zero lint warnings allowed.** Run `flutter analyze` before considering any task complete.

## Tech Stack (Do Not Substitute)

- Flutter 3.24+, Dart 3.5+
- State management: flutter_riverpod ^2.5.0 with riverpod_annotation code generation
- Models: freezed ^2.5.0 + json_serializable ^6.8.0
- Database: drift ^2.18.0 + sqlite3_flutter_libs ^0.5.0
- Full dependency list: `.claude/agent-architect.md` Section 2

After any model or table change, run:
```bash
dart run build_runner build --delete-conflicting-outputs
```

## Directory Structure

Canonical directory tree is defined in `.claude/agent-architect.md` Section 4. Place all new files in the correct location per that structure. Do not create directories outside the defined tree without explicit approval.

## Key Naming Note

The Dart class for windows is named `WindowElement` (file: `window_element.dart`) because `Window` conflicts with `dart:ui`.

## Implementation Decisions

See `DECISIONS.md` for architectural decisions made during implementation 
that aren't captured in the agent spec files. Read this before making 
changes to established patterns.
