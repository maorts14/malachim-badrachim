# Local development

The first local environment uses the `rescue-alert-system-local` Firebase
project and an isolated PostGIS database. It does not access the production
Firebase project or production database.

PostGIS is mandatory for this application. SQLite is unsupported, including
for local development and tests.

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
.\scripts\dev.ps1 up
```

This is the supported local-development entry point. It starts PostGIS, Redis,
the Django API, and the Vite admin panel. It is deliberately separate from the
root `docker-compose.yml`, which is production-oriented and does not start a
long-lived Vite development server by default.

Use the helper commands below for the rest of the local lifecycle:

```powershell
.\scripts\dev.ps1 status  # show container state and health
.\scripts\dev.ps1 down    # stop the local stack
.\scripts\dev.ps1 reset   # delete local Docker volumes, then start again
```

`reset` permanently removes the local PostGIS and admin-panel Docker volumes.
It never touches remote environments, but it does delete local development
data.

- API: `http://localhost:8004/api/`
- Admin panel: `http://localhost:5173/`
- Postgres (host only): `127.0.0.1:15432`

## Reset the local database after the initial-schema migration reset

The alert migrations are intentionally a single initial schema because no
deployment needs an upgrade path. If you previously ran the old migration
chain, recreate the local Compose data once before starting the stack again:

```powershell
.\scripts\dev.ps1 reset
```

This removes local development data and Docker volumes; it does not affect a
remote environment. The command asks for confirmation before deleting anything.

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
