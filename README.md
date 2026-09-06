# Journey360

**Every journey. One place.**

Journey360 is a Flutter app that brings real-time location sharing, journey
recording and fitness tracking into one neomorphic interface — people, walks,
runs and rides tracked from a single place. It is built to run entirely on free
tiers (Flutter + Supabase + Vercel + OpenStreetMap).

> Journey360 uses **this phone's GPS**. It is not an OBD or vehicle telematics
> device, and GPS-derived figures are estimates.

---

## Features

**Working now (MVP core)**

- **Glassmorphic UI**: frosted, translucent panels floating over a soft aurora
  gradient, with a floating glass navigation pill. Full light / dark, haptics.
  Tuned for 60 fps — real `BackdropFilter` blur is reserved for a couple of
  transient surfaces; cards use translucency, and tabs mount lazily.
- Email/password auth with email confirmation and password reset (Supabase), plus
  a fully functional **offline mode** with no account.
- **Real GPS engine**: permission flow with rationale, a continuous adaptive
  position stream, geodesic (Haversine) distance, moving vs. paused time, current
  / average / max speed, pace, elevation gain and a calorie estimate.
- **Auto-pause / auto-resume**: the timer pauses itself when you stop moving and
  resumes when you set off again (configurable).
- **Live GPS-signal indicator** on the tracking screen, derived from each fix's
  accuracy — you always know how trustworthy the numbers are.
- Bad-fix filtering: samples with poor accuracy or an implausible "teleport"
  speed are dropped before they reach your statistics.
- **Per-kilometre splits**: a live "this km" pace while you record, and a split
  bar chart on the summary with the fastest kilometre highlighted.
- **Crash-safe resume**: a recording is snapshotted every 15 s, so if the app is
  killed mid-journey the Home screen offers to Resume, Save, or Discard it.
- **Activity tracking** for running / walking / cycling — large live screen with
  a route polyline, pause / resume / finish, and a post-journey summary with the
  full route on a map.
- **Unified journey history** with type filters, lifetime + today totals, and a
  weekly summary on the Home dashboard.
- **Live map** (OpenStreetMap tiles) with your position, an active-route
  polyline, an always-visible *Sharing ON/OFF* control, and realtime circle
  member markers with a battery / status / "updated" popup.
- **Circles**: create, share an invite code, join by code, and see members move
  on a circle map in realtime (requires a Supabase project).
- **Offline-first persistence**: every journey is written to on-device storage
  first, so a network drop never loses a recording. When a backend is configured,
  unsynced journeys are pushed up automatically.
- **Last-known location continuity**: the latest location and timestamp are
  restored after a refresh or reopen so the map does not appear to reset.
- **Automatic travel-mode detection**: sustained GPS speed identifies driving
  automatically and shares the detected activity state with the Circle. This
  is phone-GPS classification, not vehicle or OBD telemetry.
- Light / dark / system theme, persisted. Settings for sharing scope, default
  activity visibility (defaults to **Private**), GPS profile and notifications.

**Deferred to the next milestone** (models and DB tables already ship): full
vehicle journeys and driving-event detection, social kudos / comments, a
chart-based statistics dashboard, place-alert geofencing, push notifications, and
a SQLite offline store.

## Screenshots

_Add screenshots of Home, Map, Activity tracking and the journey summary here._

## Architecture

Clean-ish architecture with business logic kept out of widgets (Riverpod).

```
lib/
├── config/            # compile-time config (AppConfig)
├── core/
│   ├── providers.dart # Riverpod: clients, repositories, derived state
│   ├── services/      # LocationService (permissions + position stream)
│   ├── theme/         # AppColors, AppTheme, glass.dart (AppBackground/GlassSurface)
│   └── utils/         # formatters, initials, page transitions
├── data/
│   ├── models/        # Journey, JourneyPoint, LiveLocation, Circle, …
│   ├── datasources/   # LocalJourneyStore, SettingsStore, SupabaseJourneySource
│   └── repositories/  # JourneyRepository, CircleRepository, AuthRepository
├── features/
│   ├── auth/          # AuthGate, login, register
│   ├── shell/         # 5-tab JourneyShell + NeoBottomNav
│   ├── home/  map/  activity/  circles/  vehicles/  profile/  settings/
│   └── journey/       # JourneyRecorder (pure maths) + TrackingController
├── shared/components.dart   # NeoCard, NeoButton, NeoAvatar, SharingPill, …
└── main.dart
```

Data flow for tracking:

```
GPS (Geolocator)  ->  LocationService  ->  TrackingController
                                             ├─ JourneyRecorder (filter + maths)
                                             ├─ LocalJourneyStore (always)
                                             └─ SupabaseJourneySource (when online)
                                                   └─ Postgres + Realtime -> circle members
```

## Flutter setup

```bash
flutter --version   # stable channel
flutter pub get
```

Key packages: `flutter_riverpod`, `supabase_flutter`, `geolocator`,
`flutter_map` + `latlong2`, `battery_plus`, `shared_preferences`, `intl`.

## Supabase setup

1. Create a free project at <https://supabase.com>.
2. In the SQL editor, run the migrations **in order**:
   - `supabase/migrations/001_initial_schema.sql`
   - `supabase/migrations/002_journey360_core.sql`
   - `supabase/migrations/003_circle_management.sql`
   - `supabase/migrations/004_backend_contract.sql`
  - `supabase/migrations/006_final_hardening.sql`
3. Auth → Providers: enable **Email**.
4. Project settings → API: copy the **Project URL** and the **publishable
   (anon) key**. Row Level Security is enabled by every migration — only the
   publishable key belongs in the app.

For a project where migrations were already partly run, do **not** rerun
`001` through `004`. Run only `006_final_hardening.sql`; it repairs existing
tables, policies, triggers, indexes, and realtime entries without deleting
data. The migration files are safe to use in a new empty project in the order
shown above.

### Database

`002_journey360_core.sql` adds the Journey360 core: `journeys`, `journey_points`,
`locations` (live position, one row per user), `places`, `user_settings`, and a
`vehicles` stub. It also extends `handle_new_user()` to seed `user_settings` /
`locations`, keeps `circle_members.display_name` in sync with the profile, and
adds `journeys` + `locations` to the `supabase_realtime` publication. The legacy
`trips` tables from `001` are left in place but unused.

RLS summary: a user reads/writes only their own journeys, points, places,
settings and live location; circle co-members may read each other's `locations`
row; journeys are additionally readable by visibility (`public`, or `circle` when
shared to a circle you belong to).

The app includes dedicated mobile-first screens for Smart Notifications,
Location Sharing, Activity Sharing, Circle Management, Invite Codes, Places,
About, Privacy Center, and Terms of Use. These are available from the Circle
sheet, Settings, and Profile surfaces.

## Environment variables

The app reads these compile-time values (never hard-code them):

```
SUPABASE_URL
SUPABASE_PUBLISHABLE_KEY
SOS_ENDPOINT
```

Do **not** put `SUPABASE_SERVICE_ROLE_KEY` in the app. With no values supplied,
Journey360 runs in offline mode.

Copy `dart_defines.example.json` to `dart_defines.json` (gitignored) and fill it
in.

## Running locally

```bash
# Offline mode (no backend):
flutter run -d chrome

# With a backend:
flutter run -d chrome --dart-define-from-file=dart_defines.json
```

To exercise GPS on the web, open Chrome DevTools → **Sensors** → set a location,
then change it while an activity is recording.

## Android build

`minSdk` is raised to 23 (geolocator 14). Location permissions are declared in
`android/app/src/main/AndroidManifest.xml`, including
`ACCESS_BACKGROUND_LOCATION` and `FOREGROUND_SERVICE_LOCATION`.

```bash
flutter build apk --release --dart-define-from-file=dart_defines.json
```

Background tracking on Android 10+ requires the user to additionally grant
"Allow all the time" and runs behind a foreground-service notification.

## iOS build

Usage strings and `UIBackgroundModes: location` are set in
`ios/Runner/Info.plist`.

```bash
flutter build ipa --release --dart-define-from-file=dart_defines.json
```

iOS throttles background location and may suspend updates; "Always" permission is
required for background journeys.

## Web build

```bash
flutter build web --release --dart-define-from-file=dart_defines.json
# output: build/web
```

## Vercel deployment

`vercel.json` is committed. Vercel's build image has no Flutter SDK, so the
build command clones the Flutter `stable` channel first, then builds web:

```json
{
  "framework": null,
  "buildCommand": "if [ -d flutter ]; then (cd flutter && git pull); else git clone https://github.com/flutter/flutter.git --depth 1 -b stable flutter; fi && flutter/bin/flutter config --enable-web && flutter/bin/flutter build web --release --dart-define=SUPABASE_URL=$SUPABASE_URL --dart-define=SUPABASE_PUBLISHABLE_KEY=$SUPABASE_PUBLISHABLE_KEY",
  "outputDirectory": "build/web",
  "rewrites": [{ "source": "/(.*)", "destination": "/index.html" }]
}
```

1. Push this repo to GitHub, then **Add New… → Project** in Vercel and import it.
2. Framework preset: **Other**. Leave build command / output dir as detected
   from `vercel.json`.
3. Project → Settings → Environment Variables: add `SUPABASE_URL`,
  `SUPABASE_PUBLISHABLE_KEY`, and `SOS_ENDPOINT`.
4. Set `SOS_ENDPOINT` to
  `https://your-domain.vercel.app/api/dispatch-sos` after the first deploy,
  then redeploy so the Flutter web build includes it.
5. Supabase → Authentication → URL Configuration: add your Vercel domain
   (e.g. `https://journey360.vercel.app`) to **Site URL** and **Redirect URLs**.
6. Deploy. The SPA rewrite keeps Flutter routing working. First build is slow
   (it downloads Flutter); later builds reuse the cached `flutter/` dir.

Vercel hosts the **web frontend only**. It is not the GPS/background backend —
Supabase handles database, auth and realtime. Mobile builds ship through the
Play Store / App Store against the same Supabase project.

## Free-tier limitations

- Supabase free tier caps database size, realtime connections and bandwidth.
  High-frequency GPS from many users will eventually need paid infrastructure —
  the app already batches points and throttles live-location writes.
- OpenStreetMap's public tile servers have a usage policy; a heavier app should
  use its own tile proxy or a paid provider. The tile layer is isolated in
  `lib/features/map/map_tiles.dart` for easy swapping.
- SMS / emergency dispatch would require a paid provider and is out of scope.

## Privacy

- Location sharing defaults to your circle only; activity visibility defaults to
  **Private**.
- The *Sharing ON/OFF* state is always visible on the map and can be toggled
  there.
- Live position is only written when sharing is on and a backend is configured;
  otherwise GPS never leaves the device.
- RLS prevents any client from reading data it is not entitled to.

## GPS limitations

- **Web**: works over HTTPS/localhost; **no background** — recording pauses when
  the tab is backgrounded/closed. The app restores the last known location, but
  it cannot collect new GPS fixes while the browser process is closed.
- **Android**: reliable in the foreground; background needs "Allow all the time"
  notifications, and a foreground service. Force-closing the app can still stop
  OS location delivery.
- **iOS**: background updates are OS-throttled and can be suspended.
- Accuracy depends on the device and surroundings; poor and impossible fixes are
  filtered out of statistics.

## Future improvements

Vehicle journeys + driving-event detection, social feed / kudos / comments,
statistics charts and personal records, geofenced place alerts, live journey
share links, SOS / crash detection, background-tracking hardening, wearable and
health-platform integrations.

## Local checks

```bash
flutter analyze
flutter test
```
#   j o u r n e y _ 3 6 0 
 
 