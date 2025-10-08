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
  - checks if the new `green` service is ready and healthy for receiving traffic (this is app specific)
  - updates the router configuration to point to the new service (or informs devs in e.g. Slack and devs do this manually)

Notes:

- Docker image tags won't have a mention of `blue` or `green`, tag is just `build-123`

## Example flow

- `build-1` is active as `blue` service and Traefik router routes traffic to that service
- New deployment happens, `build-2` is built and deployed to `green` service
- `build-2` is ready and healthy
- Traefik router is updated to route traffic to `green` service
- `build-1` is no longer active (and optionally deleted)
- New deployment happens, `build-3` is built and deployed to `blue` service
- `build-3` is ready and healthy
- Traefik router is updated to route traffic to `blue` service
- `build-2` is no longer active (and optionally deleted)
- and so on...

## Makefile Commands

The Makefile provides several commands to help with deployment and management of the blue/green services.

### Available Commands

#### `make debug`
Displays debugging information about the current state of the blue/green deployment.

**Output includes:**
- Current active service (blue or green)
- Router configuration
- Service states
- Current build numbers
- Next service to be deployed

**Usage:**
```bash
make debug
```

#### `make config`
Generates and displays the Docker Compose configuration with current build numbers.

**Usage:**
```bash
make config
```

#### `make deploy`
Deploys the next (inactive) service with the new build.

**Usage:**
```bash
make deploy
```

This command:
- Determines which service is currently active
- Deploys the new build to the inactive service
- Waits for the service to be ready

#### `make test-health`
Tests the health of the newly deployed service before switching traffic to it.

**Usage:**
```bash
make test-health
```

**Options:**
- `MAX_ATTEMPTS` - Maximum number of health check attempts (default: 10)
- `SLEEP_INTERVAL` - Seconds to wait between attempts (default: 3)

**Example with custom values:**
```bash
make test-health MAX_ATTEMPTS=20 SLEEP_INTERVAL=5
```

#### `make switch-router`
Switches the Traefik router to point to the newly deployed service, making it active.

**Usage:**
```bash
make switch-router
```

This command:
- Updates the Traefik router configuration
- Points the router to the next (newly deployed) service
- Copies the configuration to the remote server via SCP

### Configurable Variables

The following variables can be overwritten when calling make commands or by setting them in your environment:

#### Core Variables

- **`ENV`** (default: `prod`)
  - Environment name, used to load `.env.$(ENV)` file
  - Example: `make deploy ENV=staging`

- **`PROJECT`** (default: `blue-green-app`)
  - Project name, used in service and container naming

- **`SSH_HOST`** (default: `ineen`)
  - SSH host for remote server operations

- **`SSH_USER`** (default: `deployment`)
  - SSH user for remote server operations

- **`TRAEFIK_API`** (default: `http://$(SSH_HOST)/api/http`)
  - Traefik API endpoint URL

- **`TRAEFIK_ROUTER_NAME`** (default: `$(PROJECT)@file`)
  - Name of the Traefik router to manage

- **`TRAEFIK_DYNAMIC_CONF_PATH`** (default: `/opt/traefik/dynamic`)
  - Path to Traefik dynamic configuration directory on remote server

- **`EXPECTED_STRING`** (default: `Blue/Green`)
  - String to check for in health check response body

#### Command-Specific Variables

**For `test-health` command:**
- **`MAX_ATTEMPTS`** (default: `10`)
  - Maximum number of health check attempts before failing
  
- **`SLEEP_INTERVAL`** (default: `3`)
  - Seconds to wait between health check attempts

### Usage Examples

**Deploy with custom project name:**
```bash
make deploy PROJECT=my-app
```

**Test health with more attempts:**
```bash
make test-health MAX_ATTEMPTS=20 SLEEP_INTERVAL=5
```

**Full deployment workflow:**
```bash
# Check current state
make debug

# Deploy to inactive service
make deploy

# Verify health
make test-health

# Switch traffic to new service
make switch-router

# Verify new state
make debug
```

**Override multiple variables:**
```bash
make deploy PROJECT=my-app ENV=staging SSH_HOST=myserver.com
```
