# Rescue Alert System — API Collection

> Complete Postman collection for the Rescue Alert System backend.  
> Covers all endpoints including authentication, alerts, users, groups, messages, and push notifications.

---

## Quick Start

### 1. Import the Collection

Drag and drop **`rescue-alert-system.postman_collection.json`** directly into the Postman app.

> **Postman app → Collections sidebar → drag the file in**  
> Or: File → Import → drag the file onto the import dialog

---

### 2. Set Your Base URL

After importing, click the collection name → **Variables** tab.

| Variable | Default | Change to |
|---|---|---|
| `base_url` | `http://localhost:8000` | Your dev/staging server URL |
| `access_token` | *(auto-filled)* | Leave blank — Login fills this |
| `refresh_token` | *(auto-filled)* | Leave blank — Login fills this |

---

### 3. Authenticate

Open **Authentication → Login (Obtain Tokens)**, update the request body with real credentials, and hit **Send**.

```json
{
  "username": "your_username",
  "password": "your_password"
}
```

The `access_token` and `refresh_token` collection variables are **automatically saved** by the built-in test script. Every other request in the collection will use the token from that point on — no copy-pasting needed.

If your token expires, run **Authentication → Refresh Access Token**.

---

## What's Included

| Folder | # Requests | Description |
|---|---|---|
| Authentication | 4 | Register, login, refresh, and token verification |
| Alerts | 9 | Full CRUD, nearby geosearch, dispatch, and volunteer response |
| User Profiles | 8 | Full CRUD + location update + my profile |
| Groups | 7 | Full CRUD + add/remove members |
| Messages | 8 | Full CRUD + voice attachments + newest-first list |
| Notifications | 6 | Full CRUD for push tokens |
| Device Registration | 1 | JWT-authenticated mobile device registration |

**37 requests total.**

---

## Authentication Overview

Most endpoints use **JWT Bearer tokens** (obtained from Login).

```
Authorization: Bearer <access_token>
```

The **Device Registration** endpoint also uses the same Django JWT Bearer token.

Use **Authentication → Refresh Access Token** when the access token expires. Token lifetime is controlled by the server's SimpleJWT configuration; clients must not assume a fixed duration.

---

## Field Reference

### Alert Status Values
`OPEN` · `DISPATCHED` · `ACCEPTED` · `IN_PROGRESS` · `RESOLVED` · `CANCELLED`

### Alert Priority Values
`LOW` · `MEDIUM` · `HIGH` · `CRITICAL`

### User Role Values
`user` (volunteer) · `emergency_dispatcher` · `manager`

### Dispatch and response

Only `manager` and `emergency_dispatcher` roles can create, edit, delete, or
dispatch alerts. Dispatch uses `POST /api/alerts/{id}/dispatch/` with a
non-empty `user_ids` integer array. A dispatched volunteer uses
`POST /api/alerts/{id}/respond/` with `accept`, `decline`, or `arrive`.
`arrive` is valid only after acceptance. The returned alert always includes its
current assignment records and lifecycle status.

### Device Platform Values
`android` · `ios` · `other`

---

## Notes

- Requests that include `{id}` in the URL (e.g. `/api/alerts/1/`) — replace `1` with the actual record ID.
- Message voice attachments use `multipart/form-data`. The dedicated **Create Message (With Voice)** request is pre-configured for this.
- Nearby alerts search takes `lat`, `lon`, and `radius` (in **meters**) as query parameters.
- The `sender` field on messages is **read-only** — it is set automatically to the authenticated user.
