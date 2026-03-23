# animelib

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Supabase Setup

You can configure Supabase in two ways:

1. Git-tracked config (works everywhere, including non-VS Code):
	- Edit `lib/services/supabase_config.dart`
	- Set `SupabaseConfig.url` and `SupabaseConfig.anonKey`

2. Local override (recommended for per-machine values):
	- Use `--dart-define` or `--dart-define-from-file`
	- Keys:
	  - `SUPABASE_URL`
	  - `SUPABASE_ANON_KEY`

`--dart-define` values take precedence over `supabase_config.dart`.
