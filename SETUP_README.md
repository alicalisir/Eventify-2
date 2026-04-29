# Flutter App Structure Setup

## Quick Setup

Run this command in the project root directory to create all directories and files:

```bash
node create_dirs.js
```

## What gets created

### Directory Structure:
```
lib/
├── core/
│   ├── constants/
│   │   ├── app_colors.dart
│   │   ├── app_spacing.dart
│   │   └── app_strings.dart
│   ├── theme/
│   │   └── app_theme.dart
│   ├── router/
│   │   └── app_router.dart
│   └── utils/
│       ├── extensions.dart
│       └── validators.dart
├── shared/
│   ├── widgets/
│   │   ├── app_button.dart
│   │   ├── app_text_field.dart
│   │   ├── loading_indicator.dart
│   │   └── error_view.dart
│   └── models/
│       ├── user.dart
│       └── suggestion.dart
├── services/
│   ├── auth_service.dart
│   ├── location_service.dart
│   └── notification_service.dart
└── features/
    ├── auth/
    │   ├── presentation/screens/
    │   ├── presentation/widgets/
    │   └── providers/
    ├── onboarding/
    │   ├── presentation/screens/
    │   ├── presentation/widgets/
    │   └── providers/
    ├── dashboard/
    │   ├── presentation/screens/
    │   ├── presentation/widgets/
    │   └── providers/
    ├── suggestion_detail/
    │   ├── presentation/screens/
    │   ├── presentation/widgets/
    │   └── providers/
    └── profile/
        ├── presentation/screens/
        ├── presentation/widgets/
        └── providers/
```

## After running the script

1. Add these dependencies to your `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: ^2.4.9
  go_router: ^13.0.0
  firebase_core: ^2.24.2
  firebase_auth: ^4.16.0
  freezed_annotation: ^2.4.1
  json_annotation: ^4.8.1
  geolocator: ^10.1.0
  flutter_local_notifications: ^16.3.0
  permission_handler: ^11.1.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  build_runner: ^2.4.8
  freezed: ^2.4.6
  json_serializable: ^6.7.1
  flutter_lints: ^3.0.1
```

2. Run these commands:
```bash
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
```

## Features

- ✅ Material 3 Design
- ✅ Light/Dark theme support
- ✅ Riverpod state management
- ✅ GoRouter navigation
- ✅ Firebase authentication
- ✅ 48x48 minimum touch targets
- ✅ Proper Semantics for accessibility
- ✅ Responsive layouts
- ✅ Freezed models for immutability
