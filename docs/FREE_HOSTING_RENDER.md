# Free Hosting (Render)

This project can be shared with friends by hosting the backend on Render (free tier) and building mobile apps with a public API URL.

## 1) Prerequisites

- A Render account
- A valid `GEMINI_API_KEY`
- This repository pushed to GitHub

## 2) Create service from `render.yaml`

1. In Render, choose **New +** -> **Blueprint**.
2. Connect this GitHub repo.
3. Render will detect `render.yaml` and create `lifelens-backend`.
4. Add secret env vars when prompted:
   - `GEMINI_API_KEY`
   - `SECRET_KEY` (any long random value)

## 3) Wait for deploy and verify

After deploy finishes, open:

- `https://<your-render-service>.onrender.com/health`

You should see a healthy response.

## 4) Build app pointing at hosted backend

Use your Render URL as `LIFELENS_API_BASE_URL`:

```bash
flutter build ipa --release --dart-define=LIFELENS_API_BASE_URL=https://<your-render-service>.onrender.com
```

For Android:

```bash
flutter build apk --release --dart-define=LIFELENS_API_BASE_URL=https://<your-render-service>.onrender.com
```

## Notes

- Free tier may spin down after inactivity, causing a cold-start delay.
- If you want always-on backend, move to a paid plan.
- Keep secrets only in Render env vars, not in source code.
