# LifeLens

## Run Locally

One command from the repo root:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\run-dev.ps1
```

Optional:

- `-Device windows` to target a specific Flutter device.
- `-SkipBackend` to keep the API closed and only run Flutter.
- `-SkipFlutter` to start only the backend.

The backend runs at `http://127.0.0.1:8000`.

