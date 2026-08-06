# ChirpStack Docker (SenseCAP M1 / AS923)

Docker Compose stack for [ChirpStack](https://www.chirpstack.io) LoRaWAN Network Server **v4**, pre-wired for **AS923** (Thailand) as used by this SenseCAP M1 guide.

**Note:** Treat `docker-compose.yml` as a starting point. Harden credentials, MQTT auth, and reverse proxies before production use on untrusted networks.

## Requirements

- Docker Engine + Compose plugin (`docker compose`)
- Raspberry Pi OS **Trixie** (64-bit) recommended on SenseCAP M1 — see the [root README](../README.md)

## Directory layout

| Path | Purpose |
|------|---------|
| `docker-compose.yml` | Services: ChirpStack, Gateway Bridge (UDP + Basic Station), REST API, PostgreSQL, Redis, Mosquitto |
| `configuration/chirpstack/` | ChirpStack + region TOML files |
| `configuration/chirpstack-gateway-bridge/` | Gateway Bridge configs (UDP + Basic Station per region) |
| `configuration/mosquitto/` | MQTT broker config |
| `configuration/postgresql/initdb/` | DB role/database bootstrap |

## Quick start

```bash
docker compose up -d
```

- Web UI: http://localhost:8080 (default `admin` / `admin`)
- REST API UI: http://localhost:8090
- Semtech UDP: port **1700/udp**
- Basic Station: port **3001**
- MQTT: port **1883**

## Regions

ChirpStack `enabled_regions` lives in `configuration/chirpstack/chirpstack.toml`.

This compose file sets Gateway Bridge MQTT topic templates to the **`as923`** prefix. For another region, change:

1. `INTEGRATION__MQTT__*_TOPIC_TEMPLATE` env vars on `chirpstack-gateway-bridge` (prefix must match the region `topic_prefix`)
2. Basic Station command config file on `chirpstack-gateway-bridge-basicstation`
3. `enabled_regions` in `chirpstack.toml` if needed

## Data persistence

PostgreSQL and Redis use named Docker volumes (`postgresqldata`, `redisdata`).

## Import device repository (optional)

```bash
make import-lorawan-devices
```

Requires `make`. Clones a lorawan-devices snapshot and runs ChirpStack’s legacy import.

## Images

| Service | Image |
|---------|--------|
| ChirpStack | `chirpstack/chirpstack:4` |
| Gateway Bridge | `chirpstack/chirpstack-gateway-bridge:4` |
| REST API | `chirpstack/chirpstack-rest-api:4` |
| PostgreSQL | `postgres:16-alpine` |
| Redis | `redis:7-alpine` |
| Mosquitto | `eclipse-mosquitto:2` |

## Documentation

- https://www.chirpstack.io/docs/
- Upstream example: https://github.com/chirpstack/chirpstack-docker
