# Changelog

## Unreleased — Australian private network

- Target AU915 FSB2 (channels 8–15 and 65) throughout the WM1302 packet forwarder, ChirpStack and UDP Gateway Bridge.
- Preserve gateway identity, radio calibration, TX gain table and board reset mapping.
- Use the official ChirpStack SQLite image with persistent storage, Redis and Mosquitto; remove PostgreSQL, Basic Station, REST API and unused regional templates.
- Add idempotent runtime configuration and Docker Compose systemd installers.
- Validate JSON, TOML, Compose and channel/topic consistency; document installation, backups and database migration.

All notable changes to this project are documented here.

## [2.0.0] — 2026-08-07

Major update: target platform moves to **Raspberry Pi OS (Debian 13 Trixie)**.  
Bookworm-era docs and assumptions are preserved on the **`bookworm`** branch.

### Highlights

- **Trixie-first `main` branch** with a frozen **`bookworm`** branch for Debian 12 hosts
- **libgpiod 1.x + 2.x** compatible concentrator reset script
- **ChirpStack v4** Docker stack with pinned major image tags
- **Packet Multiplexer v4** apt install path and TOML template
- **systemd install helper** and CI syntax checks
- README rewritten in English with a clearer, calmer tone

### Added

- Branch strategy: `main` (Trixie) / `bookworm` (legacy)
- `scripts/install-lora-service.sh` — generate and enable `lora_pkt_fwd.service`
- `scripts/check-syntax.sh` — local syntax / ShellCheck / compose checks
- `systemd/lora_pkt_fwd.service` — unit template
- `.github/workflows/ci.yml` — GitHub Actions on push/PR
- `.gitignore` for Python cache artifacts
- `CHANGELOG.md`

### Changed

- `packet_forwarder/reset_lgw.sh` auto-detects libgpiod v1 vs v2 CLI
- Swap guidance: `dphys-swapfile` → **`rpi-swap`** (`/etc/rpi/swap.conf.d`)
- ChirpStack Packet Multiplexer install: **4.x** repo + signed-by keyring (no `apt-key`)
- `chirpstack-packet-multiplexer.toml` updated to v4 schema  
  (`[multiplexer]` / `[[multiplexer.server]]`, default bind `:17000`)
- `chirpstack-docker/docker-compose.yml`:
  - drop obsolete Compose `version:` key
  - ChirpStack / Gateway Bridge / REST API → major tag **`4`**
  - PostgreSQL → **`16-alpine`**
  - Mosquitto → **`2`**
- Mosquitto config notes for 2.x lab use
- README: English, Trixie-focused, less snark, same install path

### Migration notes (1.x / Bookworm → 2.0 / Trixie)

1. Prefer a **fresh Trixie image** (in-place Bookworm→Trixie upgrades are unsupported by Raspberry Pi OS).
2. Use `main` on Trixie; keep using `bookworm` branch if you stay on Debian 12.
3. Re-apply swap settings under `/etc/rpi/swap.conf.d/` if you previously used `dphys-swapfile`.
4. Reinstall packet multiplexer from the **4.x** apt repo and replace the config with the new TOML shape.
5. Existing Docker volumes created under Postgres 14 are **not** automatically upgraded to 16 — plan a dump/restore or a fresh volume if you migrate the stack.
6. Re-run `scripts/install-lora-service.sh` (or update your unit) so paths/user/groups match the new layout.

### Known limitations

- Prebuilt `lora_pkt_fwd` / `spectral_scan` binaries are provided for aarch64 RPi 4; rebuild from upstream if glibc/loader issues appear.
- Default region wiring remains **AS923 (Thailand)**; other regions need manual topic/region edits.
- `global_conf_*.json` files intentionally use comment-style annotations for the packet forwarder (not strict RFC JSON).

---

## [1.0.0] — prior

Initial public guide for SenseCAP M1 → ChirpStack on **Raspberry Pi OS Bookworm**:

- Semtech UDP packet forwarder configs (AS923 Thailand and related)
- ChirpStack Docker Compose stack
- Basic multiplexer notes and optional Node-RED / Mysterium extras

Tag: `1.0` (historical). From 2.0 onward, Bookworm content lives on branch `bookworm`.
