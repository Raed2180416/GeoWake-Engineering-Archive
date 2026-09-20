> Historical product README, preserved on 20 September 2026. Claims and plans below are not the current sale description. See `docs/sale/README.md`.

# GeoWake

**A destination alarm for transit journeys.** GeoWake is a location-based wake-up alarm for transit commuters — metro, bus, or car. Set a destination, and GeoWake monitors your journey in real time, alerting you just before you arrive.

Flutter, Android-first, India-first. iOS support is partial (no background location).

For software acquisition or licensing review, start with the [buyer package](docs/sale/README.md). Underground consistency remains unfinished; simulation results are not a field-reliability guarantee. The current preparation branch has original alarm tones and a configurable backend endpoint.

---

## Quickstart

### Prerequisites

- Flutter 3.44.x (stable)
- Android compile SDK 36, target SDK 35, minSdk 24; NDK 28.2.13676358
- A Google Maps API key with Directions, Places, and Geocoding enabled

### Setup

```bash
flutter pub get
```

Create `android/key.properties`:
```
googleMapsApiKey=YOUR_GOOGLE_MAPS_API_KEY
```

For the backend server (`geowake-server/`), create `.env`:
```
GOOGLE_MAPS_API_KEY=YOUR_KEY
JWT_SECRET=your_32_plus_char_secret
APP_BUNDLE_ID=com.geowake.app
```

### Run

```bash
# App
flutter run

# Backend
cd geowake-server && npm install && npm start
```

### Test

```bash
flutter test --coverage         # headless suite; coverage scope documented in buyer package
flutter analyze lib/ --no-fatal-infos  # infos are reported but non-fatal
```

---

## What GeoWake Does

1. **Set a destination** — search via Google Places or pick from recents
2. **Choose alarm mode** — distance-based, time-based, or stops-based (metro mode)
3. **Arm the alarm** — GeoWake starts a foreground service tracking your position
4. **Sleep / commute** — the app runs in the background, with Android background-service support; OEM behavior requires device testing
5. **Wake up** — GeoWake fires a high-priority full-screen alarm with sound + vibration before you reach your stop

### Optional premium features

- **Anti-theft mode** — accelerometer + gyroscope snatch detection triggers a loud alarm if someone moves your phone
- **Guardian mode** — auto-share your commute with a saved contact; "arrived safely" push notification
- **Custom alarm sounds** — personalized wake tones
- **Home-screen widget** — quick arm/disarm from the home screen
- **Ad-free** — remove all banner ads

The paywall uses prepaid entitlement periods; store configuration and fulfillment require verification before launch. Historical prices are not a current sales offer.

The **core wake alarm is always free**. Reliability features (foreground service, exact-alarm backstop) are never gated.

---

## Project Structure

```
WakePoint/
├── lib/                          # Flutter app
│   ├── main.dart                 # Entry point, routing, service init
│   ├── config/                   # App config, test flags, power policy
│   ├── core/                     # EKF, clock, logging, reachability
│   ├── dashboard/                # Simulation dashboards & dev tools
│   ├── l10n/                     # Localization (80+ languages)
│   ├── models/                   # Route models
│   ├── screens/                  # UI screens
│   ├── services/                 # All business logic
│   │   ├── tracking/             # Modular tracking components
│   │   ├── monetization/         # IAP, premium, ads
│   │   ├── data_asset/           # Consent-gated DP aggregate pipeline
│   │   ├── share/                # Journey sharing & guardian
│   │   ├── telemetry/            # Error & event logging
│   │   ├── reliability/          # Preflight checks
│   │   ├── widget/               # Home screen widget bridge
│   │   └── ...                   # Tracking, notifications, EKF, etc.
│   ├── themes/                   # Light/dark themes
│   └── widgets/                  # Reusable UI components
├── geowake-server/               # Express.js backend
│   └── src/
│       ├── config/               # Env config
│       ├── controllers/          # Auth, maps proxy, aggregate
│       ├── middleware/           # JWT auth, rate limiting
│       ├── routes/               # Auth, maps, aggregate
│       └── utils/                # Cache, merge engine
├── android/                      # Android native config
├── test/                         # 1373+ tests
├── packages/wakepoint_native/    # Native Android plugin (full-screen intent)
└── docs/                         # Architecture docs
```

## Branches

- **`production-ready-audit-v2`** — active development
- **`stable-release-1`** — release branch

## Documentation

- [Architecture](docs/ARCHITECTURE.md) — complete system design
- [Backend API](docs/BACKEND.md) — server endpoints and contracts
- [Android Setup](docs/ANDROID.md) — permissions, build config, native plugin
- [Testing](docs/TESTING.md) — test suite structure and CI gates
- [Privacy & Data](docs/PRIVACY.md) — consent, DP, k-anonymity, data asset pipeline
