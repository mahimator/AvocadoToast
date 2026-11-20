# AvocadoToast API

FastAPI adapter for YouTube Music catalog search metadata.

```bash
python -m venv .venv
source .venv/bin/activate
pip install -e .
uvicorn app.main:app --reload
```

Test with `/health`, `/docs`, or `/v1/search?q=...`.

This service does not expose audio stream URLs or proxy/redistribute media. Add rate limiting, restrictive CORS, observability, and deployment-specific configuration before production.