# MyRoad

A Flutter travel planning app: ROI research → Trip planning → Itinerary.

Targets iOS, macOS, Android, Linux, Windows.

## Features

- **ROI Library** — Collect and organize places of interest (Regions → Zones → Spots) with Google Places integration, photos, opening hours, and custom info.
- **Trip Creation** — Create trips with date ranges, transport preferences, and plan modes. Import ROIs as deep copies for trip-specific editing.
- **Trip Dashboard** — (Coming soon) Stage-based trip organization and itinerary builder.

## Getting Started

```bash
# Install dependencies
flutter pub get

# Generate Drift database code
dart run build_runner build --delete-conflicting-outputs

# Generate i18n
flutter gen-l10n

# Run
flutter run
```

## Architecture

- **State management:** Riverpod
- **Database:** Drift (SQLite) — tables in `lib/database/tables.dart`, one DAO per aggregate
- **i18n:** ARB files (en, zh, ja) in `lib/l10n/`
- **Maps:** Google Maps Flutter (mobile/web only)
- **Places:** Google Places API (New) via `lib/api/places_api_client.dart`
