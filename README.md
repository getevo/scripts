# Scripts

A collection of setup scripts for Linux servers.

## Runtime & Languages

### golang.sh
Installs Go with CGO support. Prompts for version (defaults to latest). Removes any existing installation, installs gcc, and sets up environment variables.
```bash
# Interactive (prompts for version)
curl -fsSL https://raw.githubusercontent.com/getevo/scripts/main/golang.sh -o golang.sh && sudo bash golang.sh

# With specific version
sudo bash golang.sh 1.23.4
```

### docker.sh
Installs Docker CE and Docker Compose plugin.
```bash
curl -fsSL https://raw.githubusercontent.com/getevo/scripts/main/docker.sh | sudo bash
```

### node.sh
Installs Node.js with npm. Prompts for version (defaults to 24).
```bash
# Interactive (prompts for version)
curl -fsSL https://raw.githubusercontent.com/getevo/scripts/main/node.sh -o node.sh && sudo bash node.sh

# With specific version
sudo bash node.sh 22
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
Installs PHP with common extensions and Composer. Prompts for version (defaults to 8.3).
```bash
# Interactive (prompts for version)
curl -fsSL https://raw.githubusercontent.com/getevo/scripts/main/php.sh -o php.sh && sudo bash php.sh

# With specific version
sudo bash php.sh 8.2
```

### dotnet.sh
Installs .NET SDK 8.0.
```bash
curl -fsSL https://raw.githubusercontent.com/getevo/scripts/main/dotnet.sh | sudo bash
```

## Databases

### mysql.sh
Installs MySQL 8.0 in Docker. Prompts for username, password, and port. Data stored in `/data/mysql`.
```bash
# Interactive (prompts for credentials and port)
curl -fsSL https://raw.githubusercontent.com/getevo/scripts/main/mysql.sh -o mysql.sh && sudo bash mysql.sh

# Non-interactive (via environment variables)
MYSQL_PORT=3307 sudo -E bash mysql.sh <username> <password>
```

### mariadb.sh
Installs MariaDB 11 in Docker. Prompts for username, password, and port. Data stored in `/data/mariadb`.
```bash
# Interactive (prompts for credentials and port)
curl -fsSL https://raw.githubusercontent.com/getevo/scripts/main/mariadb.sh -o mariadb.sh && sudo bash mariadb.sh

# Non-interactive (via environment variables)
MARIADB_PORT=3307 sudo -E bash mariadb.sh <username> <password>
```

### postgres.sh
Installs PostgreSQL 16 in Docker. Prompts for username, password, and port. Data stored in `/data/postgres`.
```bash
# Interactive (prompts for credentials and port)
curl -fsSL https://raw.githubusercontent.com/getevo/scripts/main/postgres.sh -o postgres.sh && sudo bash postgres.sh

# Non-interactive (via environment variables)
POSTGRES_PORT=5433 sudo -E bash postgres.sh <username> <password>
```

### redis.sh
Installs Redis 7 in Docker with persistence. Prompts for password and port. Data stored in `/data/redis`.
```bash
# Interactive (prompts for password and port)
curl -fsSL https://raw.githubusercontent.com/getevo/scripts/main/redis.sh -o redis.sh && sudo bash redis.sh

# Non-interactive (via environment variables)
REDIS_PASSWORD=secret REDIS_PORT=6380 sudo -E bash redis.sh
```

### mongodb.sh
Installs MongoDB 7 in Docker. Prompts for username, password, and port. Data stored in `/data/mongodb`.
```bash
# Interactive (prompts for credentials and port)
curl -fsSL https://raw.githubusercontent.com/getevo/scripts/main/mongodb.sh -o mongodb.sh && sudo bash mongodb.sh

# Non-interactive (via environment variables)
MONGO_ROOT_USERNAME=admin MONGO_ROOT_PASSWORD=secret MONGO_PORT=27018 sudo -E bash mongodb.sh
```

### clickhouse.sh
Installs ClickHouse in Docker. Prompts for username, password, and ports. Data stored in `/data/clickhouse`.
```bash
# Interactive (prompts for credentials and ports)
curl -fsSL https://raw.githubusercontent.com/getevo/scripts/main/clickhouse.sh -o clickhouse.sh && sudo bash clickhouse.sh

# Non-interactive (via environment variables)
CLICKHOUSE_USER=admin CLICKHOUSE_PASSWORD=secret CLICKHOUSE_HTTP_PORT=8124 CLICKHOUSE_NATIVE_PORT=9001 sudo -E bash clickhouse.sh
```

### qdrant.sh
Installs Qdrant vector database in Docker. Prompts for API key and ports. Data stored in `/data/qdrant`.
```bash
# Interactive (prompts for API key and ports)
curl -fsSL https://raw.githubusercontent.com/getevo/scripts/main/qdrant.sh -o qdrant.sh && sudo bash qdrant.sh

# Non-interactive (via environment variables)
QDRANT_API_KEY=secret QDRANT_HTTP_PORT=6333 QDRANT_GRPC_PORT=6334 sudo -E bash qdrant.sh
```

### milvus.sh
Installs Milvus vector database in Docker (standalone mode with etcd and MinIO). Prompts for username, password, and port. Data stored in `/data/milvus`.
```bash
# Interactive (prompts for credentials and port)
curl -fsSL https://raw.githubusercontent.com/getevo/scripts/main/milvus.sh -o milvus.sh && sudo bash milvus.sh

# Non-interactive (via environment variables)
MILVUS_USERNAME=root MILVUS_PASSWORD=secret MILVUS_PORT=19530 sudo -E bash milvus.sh
```

## S3 Storage

### minio.sh
Installs MinIO S3-compatible object storage in Docker. Prompts for credentials and ports. Data stored in `/data/minio`.
```bash
# Interactive (prompts for settings)
curl -fsSL https://raw.githubusercontent.com/getevo/scripts/main/minio.sh -o minio.sh && sudo bash minio.sh

# Non-interactive (via environment variables)
MINIO_ROOT_USER=admin MINIO_ROOT_PASSWORD=secretkey MINIO_API_PORT=9000 MINIO_CONSOLE_PORT=9001 sudo -E bash minio.sh
```

### seaweed.sh
Installs SeaweedFS distributed storage with S3 API in Docker. Prompts for credentials and ports. Data stored in `/data/seaweedfs`.
```bash
# Interactive (prompts for settings)
curl -fsSL https://raw.githubusercontent.com/getevo/scripts/main/seaweed.sh -o seaweed.sh && sudo bash seaweed.sh

# Non-interactive (via environment variables)
SEAWEED_S3_ACCESS_KEY=admin SEAWEED_S3_SECRET_KEY=secret SEAWEED_S3_PORT=8333 sudo -E bash seaweed.sh
```

### garage.sh
Installs Garage (Rust-based) S3-compatible storage in Docker. Prompts for ports. Data stored in `/data/garage`.
```bash
# Interactive (prompts for settings)
curl -fsSL https://raw.githubusercontent.com/getevo/scripts/main/garage.sh -o garage.sh && sudo bash garage.sh

# Non-interactive (via environment variables)
GARAGE_S3_PORT=3900 GARAGE_WEB_PORT=3902 sudo -E bash garage.sh
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

### ssh-keygen.sh
Generates SSH key pair. Prompts for key type (ed25519/rsa/ecdsa), name, comment, and passphrase. Can run as regular user.
```bash
# Interactive (prompts for all options)
curl -fsSL https://raw.githubusercontent.com/getevo/scripts/main/ssh-keygen.sh -o ssh-keygen.sh && bash ssh-keygen.sh

# Non-interactive (via environment variables)
SSH_KEY_TYPE=ed25519 SSH_KEY_NAME=mykey SSH_KEY_COMMENT="me@example.com" SSH_KEY_PASSPHRASE="" bash ssh-keygen.sh
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
