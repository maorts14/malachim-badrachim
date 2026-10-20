# Product and delivery audit

## Product boundary

The system has two intentionally different products sharing one API:

| Surface | Primary actor | Operational responsibility |
| --- | --- | --- |
| Flutter mobile app | Volunteer responder | Authenticate, share location while using the app, receive and inspect relevant incidents, accept/decline an assignment, coordinate through contacts/PTT/chat, and configure alert preferences. |
| React admin panel | Dispatcher or manager | Create and dispatch incidents, view status/location of responders, assign and manage incident lifecycle, and coordinate teams centrally. |

The new Figma mobile group is the lower set of frames (around y=4065). It contains welcome/login, active events, nearby-alert map, event detail and accept/decline, PTT, contacts, and settings. It deliberately contains no incident-creation flow. The older upper Figma frames are not the target mobile experience.

## Current implementation facts

* The backend exposes authenticated DRF CRUD endpoints, but authorization is only `IsAuthenticated` and `Alert` has no assignee or dispatch record. It cannot enforce the intended dispatcher/manager versus volunteer responsibilities.
* Mobile has Firebase sign-in and an API client, but the visible home tabs are the legacy UI. Its role and event-domain helpers are mostly disconnected from the router.
* The new mobile design calls for active events, nearby alert discovery, an event detail/response action, PTT, contacts and settings. Existing mobile UI has partial equivalents, not the designed flow.
* Admin routes/screens exist for events, status, map, chat, and PTT, but key screens use local arrays. The login form does not authenticate and incident creation only renders a form.
* The admin's existing Firebase config and alert service provide a useful base for moving it to the same backend contract as mobile.

## GitHub issue inventory and implementation order

The open issues (#13–#62) are an audit backlog. This branch prioritizes the runtime-critical vertical slice before infrastructure/release work:

1. Incident lifecycle, assignment/matching, secure roles, and API contracts (#17–#25, #45).
2. Mobile active-event/nearby/event-detail flow, error/refresh handling, and operational map markers (#14–#21, #39–#41).
3. Admin authentication, real incident dispatch controls, and replacement of static dashboard data (#28–#31, #58).
4. Notifications, messaging, PTT and group membership (#32–#37, #42–#43).
5. Tests, lint, CI, dependencies and deployment/privacy work (#46–#62).

## Working constraints

* Branch: `codex/align-mobile-admin-and-api`.
* The branch began with local uncommitted changes (local Firebase configuration, compose/config improvements, and migration correction). They are preserved and treated as user work unless a necessary overlap is explicitly reviewed.
* API changes must retain a documented, shared contract for both clients and be tested locally before use by either UI.

## Implemented in this branch so far

* `AlertAssignment` introduces one persisted assignment per alert/volunteer and captures pending, accepted, declined, and arrived responses.
* `/api/alerts/{id}/dispatch/` is dispatcher-only and performs best-effort FCM delivery after saving assignments.
* `/api/alerts/{id}/respond/` lets only the assigned volunteer accept, decline, or mark arrival. Alert status is derived from assignment state.
* Alert CRUD and profile/group administration now enforce manager/dispatcher roles at the API boundary; volunteers cannot elevate themselves through the profile endpoint.
* The mobile events tab now supports pull-to-refresh, event detail, accept/decline, and arrival updates against that contract.
* The admin panel now has Firebase email/password sign-in, protected dispatcher routes, a live alert table, lifecycle close control, and a map-backed new-event form using the same Firebase bearer-token API.
* Dispatchers can now assign volunteers from the live alert table; the geography view renders API-backed alert and volunteer markers instead of a static operational map.
* User contact settings (`display_name`, `phone`) persist through the profile API and the mobile settings/profile screens now load and save them.
* The mobile shell now uses the new-design destination order (Events, Map, PTT, Contacts, Settings) and applies its emergency visual hierarchy to the active-events surface.
* Added backend regression coverage for dispatch authorization, volunteer response, and non-escalating contact-profile updates. It awaits execution once Docker's PostGIS environment is available.
* Assignment pushes now carry an event deep link (`rescue://events/{id}`). The mobile deep-link pipeline normalizes it to `/events/{id}`, loads the live alert, and opens the actionable event-detail screen.
* Messages now support optional incident and group context. Volunteer visibility and posting are constrained to their own assignments/groups; dispatchers retain cross-incident coordination access.
* The admin message screen now uses the same incident-scoped message API: a dispatcher selects a live alert, sees only that alert's thread, and sends updates with its `alert` context. It replaces the static “Group 50” demo data for the dispatcher workflow.
* Group lists are now also role-scoped: a volunteer can list only groups they belong to, while dispatchers retain full operational visibility.
* The mobile message decoder now accepts the API's nullable location fields and preserves optional `alert`/`group` context. Multipart voice messages also retain that context, so a voice update cannot silently become an unscoped message.

## Verification record

* `flutter test` — passed (2 focused active-event widget tests).
* `flutter analyze` — passed with no issues.
* `npm run lint` — passed.
* `npm run build` — passed. Vite reports only a non-blocking large-chunk warning.
* The PostGIS-backed Django suite now runs through `docker compose -f docker-compose.local.yml run --rm --build --no-deps backend python manage.py test alerts --verbosity 1`: all 5 current API contract tests pass. The container migrations through `0008_message_context` also complete successfully.
* The test run exposed and fixed a real DRF defect: the custom method name `dispatch` overrode `ViewSet.dispatch`. The public route remains `POST /api/alerts/{id}/dispatch/`, but the Python handler is now `dispatch_alert`, preserving DRF's request/action lifecycle.
* After the contextual-message client fix, `flutter analyze` passed with no issues and `flutter test` passed (2 tests).
* Native Windows still lacks GDAL for direct GeoDjango execution, but Docker Desktop/PostGIS is now available and is the verified backend test path.
* Emulator startup uncovered a Firebase native/Dart initialization race. Android can create the default app after Dart observes an empty `Firebase.apps`; `main()` now tolerates only Firebase's `duplicate-app` result and continues with that native default app. A clean-install emulator relaunch now reaches the active-events screen.
* The mobile home shell now uses the lower-Figma dark header and five-destination bottom navigation, with the Figma-provided logo and navigation icons stored locally. `flutter analyze` passes and an emulator screenshot was taken after installation. The remaining individual screens still need their content-level redesign.
* The local Docker backend has been started against the healthy PostGIS service. It completed migrations through `0008_message_context`, passes Django system checks, and answers unauthenticated `GET /api/alerts/` with the expected `401`.
* Device verification also exposed a client error-path flaw: a failed alert-list response was parsed as a list. `getAllAlerts()` now checks for a 2xx response before decoding, so callers receive the actual API error instead of a misleading JSON-shape error.
* The admin dispatch prompt has been replaced by a searchable volunteer picker. The profile list now exposes a distinct read-only `user_id`, which is the exact account identifier accepted by `POST /api/alerts/{id}/dispatch/`; profile `id` remains the profile-row identifier. The local Postman collection documents that distinction.
* `docker compose -f docker-compose.local.yml run --rm --build --no-deps backend python manage.py test alerts --verbosity 1` now passes 6 tests, including the profile/account-ID dispatch-contract regression. Admin lint and production build pass; the Postman collection parses as JSON.
* The mobile PTT screen now follows the lower-Figma dark communication layout and uses real API groups instead of hard-coded demo channels. A hold begins device recording and release uploads the clip as a group-scoped `Message`; the existing server authorization determines whether the current user can publish to that group. It presents the genuine empty-group state when no permitted groups are returned. Emulator rendering, `flutter analyze`, and focused widget tests pass.
* Incident chat is now refreshed automatically in the admin panel every five seconds, and the signed-in mobile app refreshes its message queue every ten seconds while preserving the last successful state on transient failures. This is authenticated polling, not a WebSocket transport; the message contract remains unchanged for a later WebSocket upgrade.
* Foreground location tracking now checks service/permission state before subscribing, sends updates after approximately 50m of movement instead of 1km, and retains only the latest failed update in local preferences for retry after connectivity/authentication recovers. It does not claim background execution: Android background service/permission policy still needs an explicit product decision before a persistent tracker is enabled.
* The PostGIS-backed alert suite now has 7 passing tests, including group-scoped message authorization: a volunteer can post a PTT transmission to a group they belong to and receives `403` for a private group.
* GitHub Actions CI has been added for pull requests and the main/integration branches. It provisions PostGIS for the Django contract suite, runs admin lint/build plus a production dependency audit, runs Flutter analysis/tests, and scans Git history for secrets. Dependabot opens weekly updates for Actions, npm, and Python dependencies. The workflow YAML has been parsed locally; it still needs its first hosted GitHub run after the branch is pushed.
* The mobile settings tab has been replaced with a Hebrew, lower-Figma-aligned profile/settings surface. It retains live profile read/save behavior behind an expandable personal-details row, makes the current foreground-only location boundary explicit, and avoids displaying Firebase UIDs as a responder name. It was installed and visually checked on the emulator; `flutter analyze` and the focused widget suite pass.
* The active-events content now follows the lower-Figma hierarchy: urgent-event banner, status filters, event cards, and an explicit empty state. Device rendering caught a one-pixel header overflow; it was corrected before final verification. `flutter analyze` and both widget tests pass.
* The map now loads responder markers only after Mapbox's annotation manager is ready and excludes profiles without a real coordinate. Its camera listener no longer submits a duplicate, non-queued location update; the app-level foreground tracker remains the sole upload path. Map permission and style controls are localized to Hebrew. `flutter analyze` and the focused widget suite pass.
* Device UI audit against the shared 1280×2856 emulator fixed the observed Events/Contacts header overflow, the Contacts list-row overflow, raw Firebase UID exposure in Contacts and map labels, and the stale map-token snackbar path. Events, Map, PTT, Contacts, and Settings were visually rechecked with no Flutter overflow indicator; `flutter analyze` and 2 widget tests pass.
* The event-detail screen now uses the lower-Figma incident hierarchy: a compact dark incident header, urgent-response notice, live location/status/detail sections, and a fixed accept/decline response bar. It deliberately renders only fields supplied by the alert API rather than static assignment data. The deep-link loader contract remains compatible with `/events/:id`; `flutter analyze` and 3 widget tests pass, and the debug APK was installed on the emulator.
