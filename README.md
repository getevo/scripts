# Scripts

A collection of setup scripts for Linux servers.

## golang.sh

Installs the latest version of Go with CGO support. Removes any existing installation from `/usr/local/go`, installs gcc, downloads the latest release, and sets up environment variables (`GOROOT`, `GOPATH`, `PATH`, `CGO_ENABLED=1`).

```bash
curl -fsSL https://raw.githubusercontent.com/getevo/scripts/main/golang.sh | sudo bash
```

## claude.sh

Installs Claude Code with Node.js 24, configures GNU Screen for 256-color and UTF-8 support, and creates the `cl` alias for quick access.

```bash
curl -fsSL https://raw.githubusercontent.com/getevo/scripts/main/claude.sh | sudo bash
```

## portainer.sh

Installs Portainer CE 2.33.2 LTS. Automatically installs Docker if not present. Access the web UI at `https://your-server-ip:9443`.

```bash
curl -fsSL https://raw.githubusercontent.com/getevo/scripts/main/portainer.sh | sudo bash
```
