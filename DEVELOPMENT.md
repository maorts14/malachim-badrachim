# Local development

The first local environment uses the `rescue-alert-system-local` Firebase
project and an isolated PostGIS database. It does not access the production
Firebase project or production database.

## One-time setup

1. Copy `.env.local.example` to `.env.local` and choose a local-only database
   password and Django secret.
2. Copy `admin-panel/.env.development.local.example` to
   `admin-panel/.env.development.local`, then add
   the local Firebase web-app values from Firebase Console.
3. Copy `mobile/.env.local.example` to `mobile/.env.local`, then add a Mapbox
   token authorized for local development.
4. Place the local Firebase Admin service account at
   `backend/firebase-service-account.json`. The file must belong to
   `rescue-alert-system-local`; it is mounted read-only and is ignored by Git.
5. Keep the local Android `google-services.json` at
   `mobile/android/app/google-services.json`.

## Start the backend, database, and admin panel

```powershell
docker compose --env-file .env.local -f docker-compose.local.yml up --build
```

- API: `http://localhost:8004/api/`
- Admin panel: `http://localhost:5173/`
- Postgres (host only): `127.0.0.1:15432`

## Run the Android app

For an Android emulator:

```powershell
cd mobile
flutter run --dart-define=ENV=local
```

`mobile/.env.local` uses `10.0.2.2`, which Android emulators resolve to the
host computer. For a physical device, replace it with the computer's LAN IP and
add that IP to `ALLOWED_HOSTS` in `.env.local` before rebuilding the app.

The local Firebase configuration currently supports Android only. Generate and
add separate local FlutterFire configuration before running iOS, macOS, Windows,
or web locally.
