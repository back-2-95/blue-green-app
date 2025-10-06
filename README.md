# Blue / Green deployments with Traefik and Docker Compose

## Building blocks

- Traefik
- Traefik router configuration for the app
- Docker Compose with `blue` and `green` services for the same app
- Traefik service configuration for both services
- Only one service is exposed to the outside world via router, `blue` or `green`
- Github Actions will check which service is currently active
- Github Actions will deploy a new build to the other service
- Github Actions will update the router configuration to point to the new service (when it's ready)

## Process of deployment

- Push to `main` branch
- Github Actions
  - builds new Docker image with tag `build-123`
  - checks which service is currently active e.g. `blue`
  - defines `BUILD_BLUE=current-build-123` and `BUILD_GREEN=${{ github.run_number }}`
  - deploys a new build to `green` service with Docker Compose: `BUILD_BLUE=123 BUILD_GREEN=124 docker compose up app-green --wait`
  - does possible deployment tasks (e.g. database migrations)
  - checks if the new `green` service is ready and healthy for receiving traffic
  - updates the router configuration to point to the new service (or informs devs in e.g. Slack and devs do this manually)

Notes:

- Docker image tags won't have a mention of `blue` or `green`, tag is just `build-123`
