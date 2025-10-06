# Blue / Green deployments with Traefik and Docker Compose

Building blocks:

- Traefik
- Traefik router configuration for the app
- Docker Compose with `blue` and `green` services for the same app
- Traefik service configuration for both services
- Only one service is exposed to the outside world via router, `blue` or `green`
- Github Actions will check which service is currently active
- Github Actions will deploy a new build to the other service
- Github Actions will update the router configuration to point to the new service (when it's ready)
