# Data sources and test-data policy

This document distinguishes operational data from presentation defaults in the current branch. The mobile app is configured for the local development stack by default (`http://10.0.2.2:8004` from the Android emulator); it is not connected to a production backend.

| Area | Source | Status |
| --- | --- | --- |
| Authentication | Firebase Authentication development project | Real development identity/session data |
| Alerts/events | Django REST API backed by local Docker PostGIS | Real persisted development data |
| UI-validation events | Nine alerts with either `בדיקת תצוגה מקומית` or `נתון פיתוח —` in their title | Deliberate local database fixtures covering active, resolved, and cancelled states; not frontend mock data and not production data |
| Alert acceptance/decline/arrival | Django assignment/response endpoints | Real writes to the local development database |
| Contacts | API user profiles, excluding the currently signed-in account | Real development data; an empty list is expected while no other development profiles exist |
| Profile/settings | Current-profile API | Real read/write data in the local development database |
| Groups and PTT recordings | Group/message APIs plus device microphone recorder | Real implementation and local development data; the account has no groups unless an administrator adds it |
| Text/voice messages | API plus WebSocket/polling client transport | Real implementation; authenticated device-to-device end-to-end verification remains outstanding |
| User locations/incident markers | Profile-location and alert APIs | Real local API data when coordinates are available |
| Map imagery | Mapbox | Live third-party map tiles; the Tel Aviv camera is a presentation fallback when no saved camera exists |
| Push notifications | Firebase FCM registration plus backend notification sender | Real implementation; production delivery has not been verified |
| Copy, icons, Figma images, empty states, filter labels | Bundled Flutter assets/source | Static presentation content, not operational data |

## Removed legacy mock/prototype code

The stale Django `populate_mock_data` command and disconnected legacy mobile call/auth prototype screens/services were removed. They were not part of the active app flow and should not be used to populate or represent operational data.

## Data handling rule

Development fixtures must be clearly labelled in Hebrew/English and stored only in the local development database. They must never be shipped as default UI records or copied to production.
