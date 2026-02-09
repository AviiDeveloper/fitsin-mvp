# fit'sin iOS MVP (SwiftUI)

This folder contains the full Swift source and an `XcodeGen` project spec.

## Build the iOS project

1. Install XcodeGen: `brew install xcodegen`
2. Generate project:
   - `cd ios`
   - `xcodegen generate`
3. Open `ios/FitsinMVP.xcodeproj` in Xcode.
4. Set signing/team + bundle identifier.
5. In build settings, set `API_BASE_URL`:
   - Debug: `https://overgently-warless-jemma.ngrok-free.dev`
   - Release: `https://overgently-warless-jemma.ngrok-free.dev` (temporary)
6. For production/TestFlight, switch Release `API_BASE_URL` to your deployed backend URL.

## App behavior

- Prompts for shared code on first launch.
- Stores shared code in Keychain.
- Sends `X-APP-CODE` on every API call.
- Pull-to-refresh on Today, Month, Events.
- Caches last successful payload for offline fallback.
- Includes a Settings tab to clear shared code.
