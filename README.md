# Scripts

A collection of setup scripts for Linux servers.

## Runtime & Languages

### golang.sh
Installs the latest version of Go with CGO support. Removes any existing installation, installs gcc, and sets up environment variables.
```bash
curl -fsSL https://raw.githubusercontent.com/getevo/scripts/main/golang.sh | sudo bash
```

### docker.sh
Installs Docker CE and Docker Compose plugin.
```bash
curl -fsSL https://raw.githubusercontent.com/getevo/scripts/main/docker.sh | sudo bash
```

### node.sh
Installs Node.js 22 LTS with npm.
```bash
curl -fsSL https://raw.githubusercontent.com/getevo/scripts/main/node.sh | sudo bash
```

### python.sh
Installs Python 3 with pip and venv.
```bash
curl -fsSL https://raw.githubusercontent.com/getevo/scripts/main/python.sh | sudo bash
```

### rust.sh
Installs Rust via rustup. Run as normal user (not root).
```bash
curl -fsSL https://raw.githubusercontent.com/getevo/scripts/main/rust.sh | bash
```

### php.sh
Installs PHP 8.3 with common extensions and Composer.
```bash
curl -fsSL https://raw.githubusercontent.com/getevo/scripts/main/php.sh | sudo bash
```

### dotnet.sh
Installs .NET SDK 8.0.
```bash
curl -fsSL https://raw.githubusercontent.com/getevo/scripts/main/dotnet.sh | sudo bash
```

## Databases

### mysql.sh
Installs MySQL 8.0 in Docker. Prompts for username and password. Data stored in `/data/mysql`.
```bash
# Interactive (prompts for credentials)
curl -fsSL https://raw.githubusercontent.com/getevo/scripts/main/mysql.sh -o mysql.sh && sudo bash mysql.sh

# With arguments
sudo bash mysql.sh <username> <password>
```

### mariadb.sh
Installs MariaDB 11 in Docker. Prompts for username and password. Data stored in `/data/mariadb`.
```bash
# Interactive (prompts for credentials)
curl -fsSL https://raw.githubusercontent.com/getevo/scripts/main/mariadb.sh -o mariadb.sh && sudo bash mariadb.sh

# With arguments
sudo bash mariadb.sh <username> <password>
```

### postgres.sh
Installs PostgreSQL 16 in Docker. Prompts for username and password. Data stored in `/data/postgres`.
```bash
# Interactive (prompts for credentials)
curl -fsSL https://raw.githubusercontent.com/getevo/scripts/main/postgres.sh -o postgres.sh && sudo bash postgres.sh

# With arguments
sudo bash postgres.sh <username> <password>
```

### redis.sh
Installs Redis 7 in Docker with persistence. Data stored in `/data/redis`.
```bash
curl -fsSL https://raw.githubusercontent.com/getevo/scripts/main/redis.sh | sudo bash
```

### mongodb.sh
Installs MongoDB 7 in Docker. Prompts for username and password. Data stored in `/data/mongodb`.
```bash
# Interactive (prompts for credentials)
curl -fsSL https://raw.githubusercontent.com/getevo/scripts/main/mongodb.sh -o mongodb.sh && sudo bash mongodb.sh

# Non-interactive (via environment variables)
curl -fsSL https://raw.githubusercontent.com/getevo/scripts/main/mongodb.sh -o mongodb.sh
MONGO_ROOT_USERNAME=admin MONGO_ROOT_PASSWORD=secret sudo -E bash mongodb.sh
```

### clickhouse.sh
Installs ClickHouse in Docker. Prompts for username and password. Data stored in `/data/clickhouse`.
```bash
# Interactive (prompts for credentials)
curl -fsSL https://raw.githubusercontent.com/getevo/scripts/main/clickhouse.sh -o clickhouse.sh && sudo bash clickhouse.sh

# Non-interactive (via environment variables)
curl -fsSL https://raw.githubusercontent.com/getevo/scripts/main/clickhouse.sh -o clickhouse.sh
CLICKHOUSE_USER=admin CLICKHOUSE_PASSWORD=secret sudo -E bash clickhouse.sh
```

## Web Servers & Proxies

### nginx.sh
Installs Nginx web server.
```bash
curl -fsSL https://raw.githubusercontent.com/getevo/scripts/main/nginx.sh | sudo bash
```

## Security

### ufw.sh
Configures UFW firewall with default rules (SSH, HTTP, HTTPS).
```bash
curl -fsSL https://raw.githubusercontent.com/getevo/scripts/main/ufw.sh | sudo bash
```

### fail2ban.sh
Installs and configures Fail2ban for SSH protection.
```bash
curl -fsSL https://raw.githubusercontent.com/getevo/scripts/main/fail2ban.sh | sudo bash
```

### ssh-harden.sh
Hardens SSH configuration (disables root login, password auth, uses strong ciphers).
```bash
curl -fsSL https://raw.githubusercontent.com/getevo/scripts/main/ssh-harden.sh | sudo bash
```

### certbot.sh
Installs Certbot for Let's Encrypt SSL certificates.
```bash
curl -fsSL https://raw.githubusercontent.com/getevo/scripts/main/certbot.sh | sudo bash
```

### wireguard.sh
Installs and configures WireGuard VPN server.
```bash
curl -fsSL https://raw.githubusercontent.com/getevo/scripts/main/wireguard.sh | sudo bash
```

### wireguard-client.sh
Creates a new WireGuard client configuration. Prompts for client name, generates keys, and prints config with QR code.
```bash
# Interactive
curl -fsSL https://raw.githubusercontent.com/getevo/scripts/main/wireguard-client.sh -o wireguard-client.sh && sudo bash wireguard-client.sh

# With client name
sudo bash wireguard-client.sh phone
```

### visudo.sh
Adds current user to sudoers with NOPASSWD.
```bash
curl -fsSL https://raw.githubusercontent.com/getevo/scripts/main/visudo.sh | sudo bash
```

## System

### timezone.sh
Sets server timezone. Pass timezone as argument or will prompt.
```bash
curl -fsSL https://raw.githubusercontent.com/getevo/scripts/main/timezone.sh | sudo bash -s -- Asia/Tehran
```

### hostname.sh
Sets server hostname. Pass hostname as argument or will prompt.
```bash
curl -fsSL https://raw.githubusercontent.com/getevo/scripts/main/hostname.sh | sudo bash -s -- myserver
```

### ntp.sh
Configures NTP time synchronization.
```bash
curl -fsSL https://raw.githubusercontent.com/getevo/scripts/main/ntp.sh | sudo bash
```

### logrotate.sh
Configures log rotation. Pass log path as argument or will prompt.
```bash
curl -fsSL https://raw.githubusercontent.com/getevo/scripts/main/logrotate.sh | sudo bash -s -- "/var/log/myapp/*.log" 7 100M
```

## Monitoring

### netdata.sh
Installs Netdata real-time monitoring. Access at port 19999.
```bash
curl -fsSL https://raw.githubusercontent.com/getevo/scripts/main/netdata.sh | sudo bash
```

### prometheus.sh
Installs Prometheus in Docker. Access at port 9090.
```bash
curl -fsSL https://raw.githubusercontent.com/getevo/scripts/main/prometheus.sh | sudo bash
```

### grafana.sh
Installs Grafana in Docker. Access at port 3000.
```bash
curl -fsSL https://raw.githubusercontent.com/getevo/scripts/main/grafana.sh | sudo bash
```

### loki.sh
Installs Loki log aggregation in Docker. API at port 3100.
```bash
curl -fsSL https://raw.githubusercontent.com/getevo/scripts/main/loki.sh | sudo bash
```

## Tools & Utilities

### claude.sh
Installs Claude Code with Node.js 24, configures GNU Screen, and creates `cl` alias.
```bash
curl -fsSL https://raw.githubusercontent.com/getevo/scripts/main/claude.sh | sudo bash
```

### htop.sh
Installs htop and other monitoring tools (iotop, iftop, ncdu, etc.).
```bash
curl -fsSL https://raw.githubusercontent.com/getevo/scripts/main/htop.sh | sudo bash
```

### git.sh
Installs Git with global gitignore configuration.
```bash
curl -fsSL https://raw.githubusercontent.com/getevo/scripts/main/git.sh | sudo bash
```

### portainer.sh
Installs Portainer CE 2.33.2 LTS. Access at port 9443.
```bash
curl -fsSL https://raw.githubusercontent.com/getevo/scripts/main/portainer.sh | sudo bash
```

## Message Queues

### rabbitmq.sh
Installs RabbitMQ in Docker with management UI. AMQP port 5672, Management port 15672.
```bash
curl -fsSL https://raw.githubusercontent.com/getevo/scripts/main/rabbitmq.sh | sudo bash
```

### nats.sh
Installs NATS server in Docker with JetStream. Client port 4222, HTTP port 8222.
```bash
curl -fsSL https://raw.githubusercontent.com/getevo/scripts/main/nats.sh | sudo bash
```
