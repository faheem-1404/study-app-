# StudyEarn - Get Paid to Study

Flutter MVP for camera-verified study sessions.

## Stack

- Flutter + Dart
- Provider for state management
- Camera for live preview
- ML Kit face detection for on-device verification
- Permission handler for runtime camera access
- Audioplayers for ambient focus audio
- Shared preferences for local persistence

## Core Flow

Login -> Home -> Study Mode -> Result

## Notes

- The app uses on-device face detection and does not require a heavy backend for video processing.
- A native Android platform-channel bridge is included for future computer-vision integration.
- Focus audio is generated locally as loopable WAV bytes so the MVP does not depend on bundled audio assets.

## Next Step in VS Code

Open the folder as a Flutter workspace, run `flutter pub get`, then `flutter run` on a device or emulator.