# AnimeLib

AnimeLib is a cross-platform Flutter app for discovering anime, playing anime-themed guessing games, and managing a personal anime library.

It combines:
- Jikan API (MyAnimeList unofficial API) for anime data
- Supabase Auth for account/session management
- SharedPreferences for local user profile and library persistence
- Riverpod for app-wide auth state and async state handling

## Table of Contents

- [Features](#features)
- [Tech Stack](#tech-stack)
- [Architecture](#architecture)
- [Project Structure](#project-structure)
- [Prerequisites](#prerequisites)
- [Setup](#setup)
- [Supabase Configuration](#supabase-configuration)
- [Run the App](#run-the-app)
- [Build](#build)
- [Data and Persistence](#data-and-persistence)
- [API Notes](#api-notes)
- [Troubleshooting](#troubleshooting)
- [Testing](#testing)
- [Roadmap](#roadmap)
- [License](#license)

## Features

### Core Discovery
- Browse top anime with infinite scroll pagination.
- Search anime by title.
- Filter anime by genre.
- Open detailed anime pages with:
	- poster, synopsis, metadata
	- characters
	- related recommendations
	- trailer launch support

### Auth and Session
- Email/password sign up and sign in via Supabase.
- Reactive auth gate (auto-route to login/home based on session state).
- Persistent Supabase session handling across app restarts.

### Personal Library
- Add anime to personal list.
- Track status:
	- Watching
	- Completed
	- Dropped
	- Plan to Watch
- Update watched episodes and score (0-10).
- View library by status tabs.

### Profile and Stats
- Edit local profile data (display name + avatar URL).
- View dashboard metrics:
	- total entries
	- average score
	- completion rate
	- status distribution

### Game Modes
- AniGuessr:
	- random anime image guessing
	- easy/hard blur modes
	- score, streak, best streak tracking (runtime)
- Anime Wordle (daily):
	- one daily target anime
	- up to 6 guesses
	- similarity feedback (year/score/studio/source/genres/tags)
	- progress persistence per day

### Content Filtering
- Blocks explicit categories from fetched anime results:
	- ecchi
	- erotica
	- hentai

## Tech Stack

- Flutter (Material 3)
- Dart SDK `^3.10.8`
- `flutter_riverpod` for state management
- `dio` + `http` for networking
- `supabase_flutter` for authentication
- `shared_preferences` for local persistence
- `url_launcher` for opening trailer links

## Architecture

The app follows a pragmatic layered architecture:

- `screens/`: UI and interaction logic
- `services/`: external I/O, API calls, persistence, and domain operations
- `models/`: typed data objects and JSON mapping
- `providers/`: Riverpod providers for auth stream and auth mutations
- `widgets/`: reusable UI primitives

Request flow example:

1. `Screen` triggers an action.
2. `Service` fetches/transforms data (Jikan, Supabase, local storage).
3. `Model` maps response payloads.
4. UI renders async state (loading/error/success).

## Project Structure

```text
lib/
	main.dart
	models/
		anime.dart
		anime_recommendation.dart
		aniguessr_round.dart
		character.dart
		genre.dart
		user_anime_entry.dart
		user_profile.dart
		user_stats.dart
	providers/
		auth_provider.dart
	screens/
		auth_gate.dart
		auth_screen.dart
		anime_home_screen.dart
		anime_detail_screen.dart
		recommendations_screen.dart
		user_library_screen.dart
		user_profile_screen.dart
		statistics_dashboard_screen.dart
		aniguessr_screen.dart
		anime_wordle_screen.dart
	services/
		api_service.dart
		auth_service.dart
		supabase_init_service.dart
		supabase_config.dart
		user_anime_list_service.dart
		user_profile_service.dart
		statistics_service.dart
	widgets/
		ui_primitives.dart
```

## Prerequisites

- Flutter SDK installed and available in PATH
- Dart SDK compatible with Flutter channel in use
- Android Studio and/or Xcode (for mobile targets)
- A Supabase project (URL + anon key)
- Internet connection (Jikan API is required for anime content)

Verify toolchain:

```bash
flutter --version
flutter doctor
```

## Setup

1. Clone the repository.
2. Install dependencies:

```bash
flutter pub get
```

3. Configure Supabase (recommended via runtime defines, see below).
4. Run the app.

## Supabase Configuration

The app initializes Supabase in `lib/services/supabase_init_service.dart` before `runApp`.

Configuration priority:

1. `--dart-define` values (recommended)
2. fallback values in `lib/services/supabase_config.dart`

Supported keys:
- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`

### Recommended: local, untracked defines

Run with explicit defines:

```bash
flutter run \
	--dart-define=SUPABASE_URL=https://your-project.supabase.co \
	--dart-define=SUPABASE_ANON_KEY=your-anon-key
```

Or from a local JSON file:

```json
{
	"SUPABASE_URL": "https://your-project.supabase.co",
	"SUPABASE_ANON_KEY": "your-anon-key"
}
```

```bash
flutter run --dart-define-from-file=.env.json
```

### Important security note

Avoid committing production credentials. Even anon keys should be treated carefully and rotated if leaked.

## Run the App

### Default

```bash
flutter run
```

### Common targets

```bash
flutter run -d android
flutter run -d ios
flutter run -d chrome
flutter run -d linux
flutter run -d windows
flutter run -d macos
```

### List devices

```bash
flutter devices
```

## Build

```bash
flutter build apk
flutter build appbundle
flutter build ios
flutter build web
flutter build linux
flutter build windows
flutter build macos
```

## Data and Persistence

### Authentication
- Backed by Supabase Auth.
- `AuthGate` listens to auth stream and routes accordingly.

### User profile and library
- Persisted locally with SharedPreferences.
- Data keys are namespaced per authenticated user ID:
	- `local_profile_<userId>`
	- `local_library_<userId>`
- This means profile/library are currently device-local and not synced through Supabase database tables.

### Anime Wordle progress
- Persisted daily with key format: `anime_wordle_YYYY-MM-DD`.

## API Notes

Anime data is fetched from Jikan API (`https://api.jikan.moe/v4`) via `lib/services/api_service.dart`.

Implemented API capabilities include:
- top anime listing
- text search
- anime full details
- characters
- recommendations
- genres
- random anime (AniGuessr)

Caching strategy:
- In-memory TTL cache per endpoint/query key.
- In-flight request deduplication to prevent duplicate concurrent requests.

Daily Wordle target selection:
- Deterministic by day-of-year and year, then mapped to a top-anime page/item.

## Troubleshooting

### App opens login but sign-in always fails
- Verify Supabase URL/key values.
- Ensure the Supabase project has email/password auth enabled.

### App starts but auth never initializes
- Check console logs for Supabase configuration warnings.
- Ensure `SUPABASE_URL` and `SUPABASE_ANON_KEY` are non-empty.

### No anime displayed
- Check internet connectivity.
- Jikan may be rate-limited temporarily; retry after a short delay.

### Platform-specific build errors
- Run:

```bash
flutter clean
flutter pub get
flutter doctor
```

## Testing

Run tests:

```bash
flutter test
```

Run static analysis:

```bash
flutter analyze
```

Note: `test/widget_test.dart` is currently the default Flutter template test and does not reflect this app's navigation/auth feature set yet.

## Roadmap

- Sync profile and library to Supabase tables (cross-device data).
- Add robust unit tests for services and parsing.
- Add widget/integration tests for auth and main user journeys.
- Improve offline behavior and retry/backoff for API failures.
- Add localization and accessibility improvements.

## License

No license file is currently declared in this repository.
Add a `LICENSE` file (for example MIT, Apache-2.0, or proprietary) before distribution.
