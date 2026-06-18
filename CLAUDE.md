# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

MyRoad — a Flutter travel planning app (ROI research → Trip planning → Itinerary). Targets iOS, macOS, Android, Linux, Windows.

## Commands

```bash
# Run app
flutter run

# Run all tests
flutter test

# Run a single test file
flutter test test/database/dao/roi_dao_test.dart

# Drift code generation (after changing tables.dart or database.dart)
dart run build_runner build --delete-conflicting-outputs

# i18n code generation (after changing .arb files)
flutter gen-l10n

# Lint
flutter analyze
```

## Architecture

- **State management:** Riverpod (`flutter_riverpod`). Database provided via `appDatabaseProvider` in `lib/database/database.dart`.
- **Database:** Drift (SQLite). All tables defined in `lib/database/tables.dart`. One DAO per aggregate root in `lib/database/dao/`. DAOs are plain classes taking `AppDatabase`, not Drift `@DriftAccessor`.
- **Generated code:** `*.g.dart` files are gitignored. Run `build_runner` after cloning or modifying Drift/Riverpod annotated files.
- **i18n:** ARB files in `lib/l10n/` (en, zh, ja). Generated localizations also gitignored (`app_localizations*.dart`). Access via `AppLocalizations.of(context)`.
- **Domain enums:** `lib/models/enums.dart` — `TransportMode`, `SpotType`, `RegionType`, `PlanMode`. Each has a `value` string and `fromString` factory for DB storage.
- **Google Maps:** `google_maps_flutter` for map display (Android/iOS/web only — hidden on desktop). API key loaded via `flutter_dotenv` (.env). Web uses `web/env.js` (gitignored) to inject the key at runtime.
- **Places API:** `lib/api/places_api_client.dart` wraps Google Places API (New). `resolveFromUrl` handles short links (goo.gl) and full Maps URLs by following redirects and searching by place name.
- **Photos:** Local photo storage via `image_picker` + `path_provider`. Photos saved to app documents dir under `photos/`.

## Data Model Conventions

- UUIDs as TEXT primary keys, auto-generated via `clientDefault(() => Uuid().v4())`
- Duration stored as integer minutes
- TimeOfDay stored as integer (hours * 60 + minutes)
- GeoBounds stored as 4 nullable doubles (south, west, north, east)
- Zone belongs to exactly one of ROI or Trip (enforced in DAO, not DB constraint)
- Cascading deletes handled manually in DAOs (ROI → Zones → Regions → Spots → CustomInfos/OpeningHours/Photos)

## Testing

- DAO tests use in-memory database: `AppDatabase(NativeDatabase.memory())`
- Tests import DAOs directly, no DI/mocking needed
