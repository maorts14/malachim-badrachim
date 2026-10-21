# Admin tests

Run the browser-level component tests with `npm test` from `admin-panel`.

`ptt/` contains the live push-to-talk coverage. The synthetic-audio test is
opt-in because it requires a reachable LiveKit server and runs with its own
Node command rather than the browser test runner.
