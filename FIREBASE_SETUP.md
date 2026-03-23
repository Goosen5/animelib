# Firebase Configuration Status

This project is configured with FlutterFire and initializes Firebase before `runApp`.

## Included

- Firebase Core initialization through `lib/services/firebase_init_service.dart`
- Generated platform options in `lib/firebase_options.dart`
- Android plugin wiring in `android/app/build.gradle.kts`
- Android config file in `android/app/google-services.json`
- Web config through `DefaultFirebaseOptions.web`

## iOS

`lib/firebase_options.dart` includes iOS options.

If you need native iOS Firebase tooling integration in Xcode, place your
`GoogleService-Info.plist` under `ios/Runner/` and run:

```bash
flutterfire configure --platforms=ios
```

## Added Dependencies

- `firebase_core`
- `firebase_auth`
- `cloud_firestore`

## Startup Flow

App startup calls:

1. `WidgetsFlutterBinding.ensureInitialized()`
2. `FirebaseInitService.initialize()`
3. `runApp(...)`
