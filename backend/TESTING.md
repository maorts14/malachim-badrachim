# Backend test suites

Run the API suite against the disposable Django/PostGIS test database:

```text
docker compose -f docker-compose.local.yml exec -T backend python manage.py test alerts.tests
```

`CrossClientPersistenceTests` uses separate authenticated API clients to model
independent dispatcher/manager and volunteer apps. It verifies that alert
creation, dispatch, incident messages, and group membership changes survive a
fresh client reload. Django creates and destroys the test database for every
run; it does not use the development records.
