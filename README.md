# SenseCAP M1 private Australian LoRaWAN network

Run a Seeed SenseCAP M1 (Raspberry Pi 4, **WM1302 / SX1302 with SX1250 radios over SPI**) as a private ChirpStack v4 AU915 **FSB2** gateway and network server. Use a 915 MHz concentrator and antenna. The supplied aarch64 packet-forwarder binary is retained; rebuild from [Semtech sx1302_hal](https://github.com/Lora-net/sx1302_hal) if needed for your OS.

The deployment contains ChirpStack's [official SQLite image](https://www.chirpstack.io/docs/chirpstack/downloads.html), Redis, Mosquitto and one Semtech UDP Gateway Bridge. SQLite stores network configuration; Redis persists sessions, metrics and cache. There is no PostgreSQL, Basic Station bridge or REST API container. ChirpStack's native web UI and gRPC API remain on port 8080.

## Channel plan

| Channels | Frequencies | Bandwidth |
|---|---|---|
| 8–15 | 916.8, 917.0, 917.2, 917.4, 917.6, 917.8, 918.0, 918.2 MHz | 125 kHz |
| 65 | 917.5 MHz, SF8 (DR6) | 500 kHz |

ChirpStack region ID and gateway MQTT prefix are both `au915_1` (FSB2). End devices must use **AU915 FSB2**, not US915 or AS923. RX2 is 923.3 MHz / DR8. The two radio centres are 917.1 and 917.9 MHz. Receive channels are set in the packet-forwarder JSON; the region TOML alone cannot retune a Semtech UDP gateway.

The original RSSI calibration, temperature compensation, TX gain table, SPI settings, gateway ID and GPIO reset helper are retained. Downlink power is set to 27 dBm, the highest calibrated entry in this board's table. Set antenna gain and transmit power to suit your actual installation. `lorawan_public=true` selects the standard LoRaWAN sync word, including for this private network; tenant privacy is separately enabled with `force_gws_private=true`.

## Installation

Use Raspberry Pi OS **64-bit Trixie**, with SSH enabled. Enable SPI using `sudo raspi-config`, then reboot. Install prerequisites and Docker Engine with its Compose plugin ([Docker instructions](https://docs.docker.com/engine/install/debian/)):

```bash
sudo apt update
sudo apt install -y git gpiod python3
# Install Docker Engine and the Compose plugin before continuing.
docker compose version
```

Clone your fork onto the M1 into a path without spaces or `%`, then enter its root directory. The installers use its absolute path; keep the checkout there after installation.

### Configure gateway identity

Read the gateway EUI from your existing working configuration, or read the concentrator EUI with the retained binary:

```bash
cd packet_forwarder
chmod +x lora_pkt_fwd reset_lgw.sh
sudo ./reset_lgw.sh start
sudo ./lora_pkt_fwd -c global_conf_au915.json
# Note “concentrator EUI: 0x...” and stop with Ctrl+C.
cd ..
sudo ./scripts/configure.sh --gateway-id YOUR_16_HEX_DIGIT_EUI
```

Stop any existing packet-forwarder service before accessing the concentrator manually. Use the same gateway ID already registered with your private network if it differs from the concentrator EUI. `AA555A0000000000` is the repository's existing example ID; configure.sh preserves it when no ID is supplied, so explicitly set your actual ID on first installation.

The configuration script:

- Creates `/etc/sensecap-m1/global_conf.json` from the AU915 template on first use.
- Preserves the existing runtime gateway identity, server address, ports and calibration on reruns, while applying the FSB2 receive channel plan. `--gateway-id` deliberately overrides the ID.
- Creates a random API signing secret in `chirpstack-docker/.env` only if that file does not already exist.
- Prepares `chirpstack-docker/data/chirpstack/` for the official image's UID/GID 65534. Data and `.env` are ignored by Git.

Edit `/etc/sensecap-m1/global_conf.json` for user settings (gateway identity, position, server address and antenna gain). Leave checked-in calibration in `packet_forwarder/global_conf_au915.json` alone unless changing hardware. The default destination is localhost:1700. If reusing an older runtime file, check its destination still matches this deployment.

### Validate and install services

```bash
./scripts/check-syntax.sh
sudo ./scripts/install-chirpstack-service.sh
sudo ./scripts/install-lora-service.sh --user "$USER"
```

The stack installer runs Compose validation before installing `chirpstack-compose.service`, starts Docker after networking and starts the four containers. The packet-forwarder installer adds the service user to available `gpio`, `spi` and `dialout` groups, resets the concentrator before each start, and restarts after failures. Rerunning either installer applies its updated unit and restarts the service. `--config /absolute/path/to/config.json` supports a custom runtime file.

Open `http://<m1-ip>:8080`, sign in with **admin / admin** and change the password. Add a gateway using the identical 16-digit gateway ID, in the tenant that owns your devices. Select AU915 / `au915_1` and the device's correct LoRaWAN version and regional parameters revision for device profiles; configure nodes for FSB2 before joining.

UDP 1700 and anonymous MQTT 1883 are published only on host loopback. Containers communicate through their private Compose network. The web UI is available on the LAN. For a remote gateway or external MQTT client, deliberately change bindings and configure access controls first.

```bash
sudo systemctl status chirpstack-compose lora_pkt_fwd
journalctl -u lora_pkt_fwd -f
cd chirpstack-docker
sudo docker compose ps
sudo docker compose logs -f chirpstack chirpstack-gateway-bridge
```

`chirpstack-compose` is a oneshot unit: “active (exited)” means Compose was launched. Use `docker compose ps` and logs to check container health. Docker restarts containers after host restarts. The forwarder retries UDP delivery while the bridge starts.

## Upgrading and backups

### Moving from the original PostgreSQL / AS923 deployment

This is a database backend change, **not an automatic database migration**. SQLite starts as a new network. Before checking out this refactor, stop the old forwarder, back up its JSON and `.env`, export network/device configuration and keys as appropriate, take a PostgreSQL dump, save the old Compose/config files and record the Git revision and image versions. Keep the existing PostgreSQL volume. Never use `docker compose down -v`.

Stop the old stack with its old Compose file (`sudo docker compose down`, without `-v`) before updating the checkout. This also removes the old Basic Station, REST API and PostgreSQL containers while retaining volumes. Configure this fork using the **existing gateway ID**. For custom board calibration, copy the old known-good JSON into `/etc/sensecap-m1/global_conf.json` before running configure.sh; this applies FSB2 without replacing its other hardware or gateway settings. Commented JSON must first be converted to strict JSON. Check the destination is localhost:1700.

Recreate tenants, applications, gateways and devices in SQLite through the UI or gRPC API, or use an explicitly tested export/import procedure. OTAA devices should join again. Plan ABP session/frame-counter migration explicitly before switching live devices. Configure devices for AU915 FSB2; AS923 devices do not become AU915 merely by changing the server. For rollback, stop the new stack, restore the old checkout/configuration and PostgreSQL backup/volume, and reinstall the old forwarder unit.

### Routine SQLite deployment upgrades

Stop both services and the containers before copying data so SQLite (including WAL files) and Redis are consistent. From the repository root:

```bash
sudo systemctl stop lora_pkt_fwd chirpstack-compose
cd chirpstack-docker
sudo docker compose stop
# Redis writes a final snapshot on graceful shutdown.
backup_dir="$HOME/sensecap-backup-$(date +%Y%m%d-%H%M%S)"
mkdir -m 700 "$backup_dir"
sudo tar -czf "$backup_dir/config-and-sqlite.tgz" \
  .env configuration data /etc/sensecap-m1 /etc/systemd/system/lora_pkt_fwd.service \
  /etc/systemd/system/chirpstack-compose.service
redis_volume="$(sudo docker volume ls -q --filter label=com.docker.compose.project="$(basename "$PWD")" --filter label=com.docker.compose.volume=redisdata)"
# If using a custom Compose project name, identify its redisdata volume with docker volume ls.
test -n "$redis_volume"
sudo docker run --rm -v "$redis_volume:/source:ro" \
  -v "$backup_dir:/backup" alpine:3.21 tar -czf /backup/redis.tgz -C /source .
sudo docker compose images > "$backup_dir/images.txt"
cd ..
git pull --ff-only
sudo ./scripts/configure.sh
./scripts/check-syntax.sh
cd chirpstack-docker
sudo docker compose pull
cd ..
sudo ./scripts/install-chirpstack-service.sh
sudo ./scripts/install-lora-service.sh --user "$USER"
```

Keep backups private: they contain device keys and credentials. Back up SQLite and Redis together. Restore with both services stopped: extract the configuration/database archive to its original paths and the Redis archive into the matching `redisdata` volume, preserving ownership (SQLite UID/GID 65534), then start the services. Restore matching configuration and image versions too. Schema upgrades can prevent downgrades; rollback uses the **pre-upgrade backup**, not a newly migrated database.

Images track major versions (`:4`, Redis `:7-alpine`, Mosquitto `:2`). Record deployed digests and pin tested tags/digests for controlled upgrades. Updating this checkout does not overwrite runtime gateway settings or the secret; review template changes and apply required changes to `/etc/sensecap-m1/global_conf.json` deliberately. Changing the API secret invalidates existing tokens.

## Layout and validation

```text
packet_forwarder/global_conf_au915.json       # WM1302 calibration + FSB2 template
packet_forwarder/reset_lgw.sh                # existing board GPIO mapping
chirpstack-docker/docker-compose.yml
chirpstack-docker/configuration/chirpstack/chirpstack.toml
chirpstack-docker/configuration/chirpstack/region_au915_1.toml
scripts/configure.sh                         # runtime JSON, secret, storage setup
scripts/install-chirpstack-service.sh
scripts/install-lora-service.sh
scripts/check-syntax.sh
systemd/                                    # service templates
```

`check-syntax.sh` requires Python 3.11+ and Docker Compose. It checks shell/Python syntax, parses JSON and TOML, verifies FSB2 frequencies/channel masks and matching MQTT prefixes, and runs full `docker compose config` validation. ShellCheck runs when installed and in CI. These checks do not prove SPI/GPIO access, RF performance or successful device joins; verify those on the M1 with gateway events and an OTAA uplink/downlink.
