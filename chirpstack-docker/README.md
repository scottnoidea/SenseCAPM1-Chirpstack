# ChirpStack AU915 FSB2

See the [installation and upgrade guide](../README.md) for gateway setup, systemd installation, backups and migration from PostgreSQL.

Run `sudo ./scripts/configure.sh --gateway-id YOUR_EUI` from the repository root before starting this stack. It generates `.env` and prepares writable SQLite storage. Then install using `sudo ./scripts/install-chirpstack-service.sh`, or run `sudo docker compose up -d` here.

| Service | Image | Host access |
|---|---|---|
| ChirpStack | `chirpstack/chirpstack-sqlite:4` | Web UI / native gRPC on 8080 |
| UDP Gateway Bridge | `chirpstack/chirpstack-gateway-bridge:4` | 127.0.0.1:1700/udp |
| Mosquitto | `eclipse-mosquitto:2` | 127.0.0.1:1883 |
| Redis | `redis:7-alpine` | Compose network only |

SQLite is persisted in `data/chirpstack/`; Redis uses the `redisdata` named volume with AOF enabled. Preserve both plus `.env`, the configuration directory and `/etc/sensecap-m1/`. The MQTT region prefix is `au915_1`. Only this region is enabled. Basic Station, PostgreSQL and the optional REST API have been removed.

Configuration uses ChirpStack's [SQLite settings](https://www.chirpstack.io/docs/chirpstack/configuration.html). SQLite runs with one connection, a busy timeout, foreign keys and WAL enabled. The image runs as UID/GID 65534; the configuration script prepares ownership without recursively modifying existing database files.
