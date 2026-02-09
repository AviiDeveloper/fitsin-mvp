# Deployment Guide

## Backend (Render)

`render.yaml` is included at repo root for one-click infrastructure setup.

### Steps

1. Push `fitsin-mvp` to GitHub.
2. In Render: New + Blueprint, select the repo.
3. Render loads `render.yaml` and creates `fitsin-backend` service.
4. Fill secret env vars in Render dashboard:
   - `APP_SHARED_CODE`
   - `SHOPIFY_STORE_DOMAIN`
   - `SHOPIFY_ADMIN_TOKEN`
   - `NOTION_TOKEN`
   - `NOTION_DB_ID`
5. Deploy and verify:
   - `GET /health` should return `ok: true`
   - Call `/v1/today` with valid `X-APP-CODE`

## iOS (TestFlight)

1. Generate project: `cd ios && xcodegen generate`
2. Open `FitsinMVP.xcodeproj` in Xcode.
3. Set signing, bundle ID, and team.
4. Set Release `API_BASE_URL` to the deployed backend URL.
5. Archive and upload to App Store Connect.
6. Add internal testers in TestFlight.

## Smoke test checklist

- Enter shared code and load all tabs.
- Verify Today/Month numbers return in GBP.
- Verify upcoming Notion events open in Safari.
- Verify wrong shared code returns unauthorized behavior.
- Verify offline mode shows cached payload.
