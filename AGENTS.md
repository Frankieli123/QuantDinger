# AGENTS.md - QuantDinger AI Coding Assistant Guide

## Project Overview

QuantDinger is a **local-first, privacy-first, self-hosted AI quantitative trading platform**. It provides:
- Multi-user accounts backed by PostgreSQL
- LLM-based multi-agent research system
- Visual Python strategy development
- Backtesting and live trading capabilities

## Architecture

```
QuantDinger/
├── backend_api_python/     # Flask API backend (Python 3.12+)
│   ├── app/
│   │   ├── routes/         # API endpoints
│   │   ├── services/       # Business logic (trading, analysis, agents)
│   │   ├── data_sources/   # Market data providers (crypto, stocks, forex)
│   │   ├── config/         # Configuration (database, API keys)
│   │   └── utils/          # Utilities (auth, cache, logging)
│   ├── migrations/         # SQL schema (init.sql)
│   └── Dockerfile
├── quantdinger_vue/        # Vue 2.x frontend
│   ├── src/
│   │   ├── views/          # Page components
│   │   ├── api/            # API client modules
│   │   └── store/          # Vuex state management
│   ├── deploy/             # Nginx config for Docker
│   └── Dockerfile
└── docker-compose.yml      # Full stack deployment
```

## Tech Stack

| Component | Technology |
|-----------|------------|
| Backend | Python 3.12, Flask 2.3.3, SQLAlchemy |
| Frontend | Vue 2.6, Ant Design Vue, ECharts, KlineCharts |
| Database | PostgreSQL 16 |
| Container | Docker, docker-compose |
| Trading | CCXT, IBKR (ib_insync), MT5 |
| AI/LLM | Multi-provider (OpenAI, DeepSeek, Google, Grok) |

## Common Commands

### Docker Deployment (Recommended)

```bash
# Start all services
docker-compose up -d

# Rebuild after code changes
docker-compose up -d --build

# View logs
docker-compose logs -f backend
docker-compose logs -f frontend

# Stop all services
docker-compose down
```

### Local Development

**Backend (Flask API)**:
```bash
cd backend_api_python
pip install -r requirements.txt
cp env.example .env  # Then configure .env
python run.py
# Runs at http://localhost:5000
```

**Frontend (Vue)**:
```bash
cd quantdinger_vue
npm install --legacy-peer-deps
npm run serve
# Runs at http://localhost:8000, proxies /api/* to backend
```

### Testing & Linting

```bash
# Frontend linting
cd quantdinger_vue
npm run lint

# Frontend unit tests
npm run test:unit

# Backend - no formal test suite, verify via health endpoint
curl http://localhost:5000/health
curl http://localhost:5000/api/health
```

### Database

```bash
# Initialize schema (first time)
psql -U quantdinger -d quantdinger -f backend_api_python/migrations/init.sql

# Backup
docker exec quantdinger-db pg_dump -U quantdinger quantdinger > backup.sql

# Restore
cat backup.sql | docker exec -i quantdinger-db psql -U quantdinger quantdinger
```

## Code Conventions

### Backend (Python)
- Use Flask blueprints for route organization
- Services contain business logic, routes handle HTTP
- Use SQLAlchemy for database operations
- Follow existing patterns in `app/routes/` and `app/services/`
- Environment configuration via `.env` file

### Frontend (Vue)
- Vue 2.x with Options API
- Ant Design Vue components
- API modules in `src/api/` return axios promises
- State management via Vuex in `src/store/`
- Use Less for styling

## Key Files

| File | Purpose |
|------|---------|
| `backend_api_python/run.py` | Backend entry point |
| `backend_api_python/app/__init__.py` | Flask app factory |
| `backend_api_python/app/config/settings.py` | Configuration loader |
| `backend_api_python/migrations/init.sql` | Database schema |
| `quantdinger_vue/vue.config.js` | Vue CLI & proxy config |
| `quantdinger_vue/src/main.js` | Frontend entry point |
| `docker-compose.yml` | Full stack orchestration |

## API Endpoints

- `GET /health` - Health check
- `GET /api/health` - API health check
- `POST /api/user/login` - User authentication
- `GET /api/user/info` - Current user info
- See `backend_api_python/app/routes/` for full list

## Environment Variables

Key settings in `backend_api_python/.env`:
- `DATABASE_URL` - PostgreSQL connection string
- `SECRET_KEY` - JWT signing key
- `ADMIN_USER` / `ADMIN_PASSWORD` - Default admin credentials
- `LLM_PROVIDER` - AI provider (openrouter/openai/google/deepseek/grok)
- See `env.example` for complete list

## Docker Services

| Service | Container | Port | Description |
|---------|-----------|------|-------------|
| postgres | quantdinger-db | 5432 (internal) | PostgreSQL database |
| backend | quantdinger-backend | 5000 (internal) | Flask API |
| frontend | quantdinger-frontend | 8888 | Nginx serving Vue SPA |

## Notes

- Frontend proxies `/api/*` requests to backend (both in dev and Docker)
- PostgreSQL data persisted in `postgres_data` Docker volume
- Backend logs in `backend_api_python/logs/`
- Memory/RAG data in `backend_api_python/data/memory/`
