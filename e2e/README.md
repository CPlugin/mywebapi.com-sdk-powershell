# End-to-end tests

These run only when opted in and staging credentials are present in the environment:

- `WEBAPI_E2E=1` (opt-in gate)
- `WEBAPI_CLIENT_ID`, `WEBAPI_CLIENT_SECRET` (required)
- `WEBAPI_ENV` (optional, `Staging` default), `WEBAPI_TRADE_PLATFORM` (optional; auto-discovered if unset)

Without them, every case is skipped. REST only — realtime is not exercised in CI.

Run: `Invoke-Pester ./e2e -Output Detailed`
