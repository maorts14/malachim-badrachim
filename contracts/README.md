# API contract corpus

`openapi.yaml` is generated from Django and is the reviewable canonical API
artifact. `alert-group-message.json` contains the shared Alert, Group, and
Message examples consumed by backend and client contract tests. Breaking a
field name, nullability, enum, or required field requires a schema update and
simultaneous client update in the same change.
