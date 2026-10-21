# Mobile route inventory

The application exposes only the routes in this document. A screen is either a
supported deep link, an internal child of the authenticated home shell, or
removed from the product surface.

## Supported URLs

| URL | Access | Screen |
| --- | --- | --- |
| `/sign-in` | Public | Sign in |
| `/sign-up` | Public | Sign up |
| `/forgot-password` | Public | Password-reset request |
| `/reset-password/:uid/:token` | Public | Password reset confirmation |
| `/` | Authenticated | Home shell |
| `/events/:id` | Authenticated | Event detail |

An unauthenticated request for an event URL is redirected to sign-in with a
validated return location. After sign-in it returns to that event. A session
expiry follows the same path. Unsupported notification and app links are
discarded rather than routed to an unregistered screen.

## Authenticated home shell

The home shell owns the Events, Map, PTT, Contacts, and Settings tabs. User
Details and About are internal modal navigation from the Events tab. They are
not deep-linkable URLs and must not be used as notification targets.

## Removed prototypes

The old static `EventsTabScreen`, `HistoryTabScreen`, message queue/detail
screens, and their message BLoC/Cubit were unreachable through the supported
router and have been removed. New product screens must be added here and to
`AppRoutePaths` with route coverage before they ship.
