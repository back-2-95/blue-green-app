# blue-green-app

A demo application for zero-downtime **blue/green deployments** using Traefik and Docker Compose.

## What this project is about

Blue/green deployment is the core concept. Two identical containers run side-by-side (`app-blue` and `app-green`). Only one is live at a time — the Traefik router points to the active slot. Deploying means starting the inactive slot with a new image, health-checking it, then switching the router. No downtime, instant rollback by switching back.

## Application

- `index.php` — simple PHP page that shows the active `INSTANCE` (blue/green), env vars, and request headers
- `Dockerfile` — based on `trafex/php-nginx`; copies `index.php` and favicons
- Image: `ghcr.io/back-2-95/blue-green-app:build-<N>` (built for `linux/arm64`)

## Deployment

```
BUILD=<build_number> make deploy
```

Full flow (automated via CI):
1. **build** — Docker image built and pushed to GHCR
2. **pull** — new image pulled into the inactive slot on the remote host
3. **deploy** — inactive container started (`make deploy`)
4. **test-health** — new container health-checked from within Docker (`make test-health`)
5. **switch** — Traefik router updated to point at new slot (`make switch-router`)
6. **cleanup** — old images pruned (`make clear-old-images`)

## Infrastructure

- **Remote host:** `ineen` (accessed via Tailscale zero-trust network)
- **SSH user:** `deployment`
- **Remote Docker:** `DOCKER_HOST=ssh://deployment@ineen`
- **Traefik dynamic config:** `/opt/traefik/dynamic/blue-green-app.yaml` on remote host
- **Router switches** by rewriting `config/traefik/blue-green-app.yaml` with `yq` and uploading via SSH
- **Live URL:** `https://blue-green.ineen.net`

## Key files

| File | Purpose |
|------|---------|
| `compose.yaml` | Defines `app-blue` and `app-green` services |
| `Makefile` | All deploy operations (`debug`, `pull`, `deploy`, `test-health`, `switch-router`, `clear-old-images`) |
| `config/traefik/blue-green-app.yaml` | Traefik router + service definitions; edited to switch active slot |
| `.env.prod` | Remote host config (`COMPOSE_PROJECT_NAME`, `DOCKER_HOST`, `TRAEFIK_NETWORK`) |
| `.github/workflows/deploy.yml` | CI pipeline: build → deploy → switch jobs |

## Makefile targets

| Target | Description |
|--------|-------------|
| `make debug` | Show current/next slot, image, and build number |
| `make config` | Validate Docker Compose config |
| `make pull` | Pull new image into inactive slot |
| `make deploy` | Start inactive slot with new image |
| `make test-health` | Health-check the inactive container |
| `make switch-router` | Flip Traefik router to the new slot |
| `make clear-old-images` | Prune images not in use (requires `LABEL`) |
