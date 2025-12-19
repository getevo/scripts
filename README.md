# Scripts

A collection of setup scripts for Linux servers.

## golang.sh

Installs the latest version of Go. Removes any existing installation from `/usr/local/go`, downloads the latest release, and sets up environment variables (`GOROOT`, `GOPATH`, `PATH`).

```bash
curl -fsSL https://raw.githubusercontent.com/getevo/scripts/main/golang.sh | sudo bash
```

## claude.sh

Installs Claude Code with Node.js 24, configures GNU Screen for 256-color and UTF-8 support, and creates the `cl` alias for quick access.

```bash
curl -fsSL https://raw.githubusercontent.com/getevo/scripts/main/claude.sh | sudo bash
```
