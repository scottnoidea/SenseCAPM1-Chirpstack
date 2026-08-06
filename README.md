# SenseCAP M1 → ChirpStack

Repurpose a **Seeed SenseCAP M1** (Raspberry Pi 4 + WM1302/WM1303 LoRa concentrator) as a private [ChirpStack](https://www.chirpstack.io) LoRaWAN gateway and network server.

Built for people who still have the hardware, but not the Helium wallet keys — and would rather run real LoRaWAN than leave a good radio in a drawer.

| Branch | Target OS |
|--------|-----------|
| **`main`** (this branch) | **Raspberry Pi OS on Debian 13 Trixie** (recommended) |
| [`bookworm`](https://github.com/hereismeaw/SenseCAPM1-Chirpstack/tree/bookworm) | Raspberry Pi OS Bookworm (Debian 12) — legacy |

**Hardware:** SenseCAP M1 = RPi 4 + Semtech SX1302 (WM1302) or SX1303 (WM1303) over SPI.

**Current release:** [**v2.0.0**](https://github.com/hereismeaw/SenseCAPM1-Chirpstack/releases/tag/v2.0.0) — Trixie support, ChirpStack 4, CI, install helpers. See [CHANGELOG.md](CHANGELOG.md).

---

## Lost Helium seed phrase?

**There is no recovery.**  
The Helium app is explicit about this during setup, which is why it ships with a write-down card. If those words are gone, the wallet is gone.

Official warning: https://docs.helium.com/wallets/wallet-seed-phrase

The good news: the gateway hardware is still useful. SPI, the concentrator, and Linux all still work. HNT may be out of reach, but **LoRaWAN is not** — and with ChirpStack, you run the network server yourself.

### Requirements

1. SenseCAP M1 (lost keys, retired miner, or intentional repurpose)
2. Basic Linux command line
3. Micro SD card reader
4. Decent quality SD card (A2 / high endurance recommended)
5. A bit of time

---

## 1. Flash Raspberry Pi OS (Trixie)

Download [Raspberry Pi Imager](https://www.raspberrypi.com/software/).

1. Board: **Raspberry Pi 4**
2. OS: **Raspberry Pi OS (64-bit)** — description should mention **Debian Trixie**  
   - Lite is enough for headless gateways  
   - Desktop is fine if you want a GUI
3. In OS customisation:
   - Set username and password
   - Configure Wi-Fi if needed
   - **Enable SSH**
4. Write the image, insert the SD into the M1, power on

SSH in with Termius, PuTTY bla bla.

> Still on Bookworm? Use branch [`bookworm`](https://github.com/hereismeaw/SenseCAPM1-Chirpstack/tree/bookworm) instead of following `main`.

---

## 2. Board setup

### Enable interfaces

```bash
sudo raspi-config
```

Under **Interface Options**, enable:

- **SPI** (required for WM1302/WM1303)
- **I2C**
- **Serial Port** (login shell: No / hardware serial: Yes, if asked)
- **VNC** (optional, Desktop only)

Finish the steps below before rebooting.

### Update EEPROM (recommended)

```bash
sudo rpi-eeprom-update -a
```

### Swap on Trixie (`rpi-swap`)

Trixie uses **`rpi-swap`** instead of `dphys-swapfile`. Defaults are fine for many installs. For a fixed **2 GiB** swap file (helpful with Docker):

```bash
sudo mkdir -p /etc/rpi/swap.conf.d
sudo tee /etc/rpi/swap.conf.d/80-swapfile-2g.conf >/dev/null <<'EOF'
[Main]
Mechanism=swapfile

[File]
FixedSizeMiB=2048
EOF
```

Applies after reboot (`man swap.conf`).

### Base packages

```bash
sudo apt update && sudo apt full-upgrade -y
sudo apt install -y gpiod git curl ca-certificates
```

`gpiod` provides the modern GPIO tools. Trixie ships **libgpiod 2.x** (different CLI from Bookworm’s 1.x). This repo’s reset script supports both.

### Docker

```bash
curl -sSL https://get.docker.com | sh
sudo usermod -aG docker "$USER"
sudo usermod -aG gpio,spi,dialout "$USER"
sudo reboot
```

After reboot:

```bash
sudo apt autoremove -y
docker version   # should work without sudo after re-login
```

---

## 3. Clone this repo

```bash
cd ~
git clone https://github.com/hereismeaw/SenseCAPM1-Chirpstack.git
cd SenseCAPM1-Chirpstack
```

`main` = Trixie. For Bookworm:

```bash
git clone -b bookworm https://github.com/hereismeaw/SenseCAPM1-Chirpstack.git
```

---

## 4. Packet forwarder (WM1302 / WM1303)

Sysfs GPIO is gone on modern Raspberry Pi OS.  
`reset_lgw.sh` uses **libgpiod** and auto-detects:

- **v2** → Trixie  
- **v1** → Bookworm  

### Make binaries executable

```bash
cd ~/SenseCAPM1-Chirpstack/packet_forwarder
chmod +x reset_lgw.sh lora_pkt_fwd spectral_scan
```

### Read concentrator EUI

WM1302 (SX1302), AS923 Thailand config:

```bash
./lora_pkt_fwd -c global_conf_as923_th.json
```

WM1303 (SX1303):

```bash
./lora_pkt_fwd -c global_conf_as923_th_sx1303.json
```

Note the line:

```text
INFO: concentrator EUI: 0xXXXXXXXXYYYYYYYY
```

Then stop with `Ctrl+C`.

### Set Gateway ID

```bash
nano global_conf_as923_th.json   # or the sx1303 file
```

Under `gateway_conf`, set `gateway_ID` to the EUI **without** the `0x` prefix (16 hex characters):

```json
"gateway_ID": "XXXXXXXXYYYYYYYY",
```

> Prebuilt `lora_pkt_fwd` is aarch64 for RPi 4. Bookworm-built binaries usually run on Trixie. If you hit glibc/loader errors, rebuild from [sx1302_hal](https://github.com/Lora-net/sx1302_hal) on the Pi.

### Install as a systemd service (recommended)

```bash
cd ~/SenseCAPM1-Chirpstack
sudo ./scripts/install-lora-service.sh
```

WM1303:

```bash
sudo ./scripts/install-lora-service.sh --config global_conf_as923_th_sx1303.json
```

Custom user:

```bash
sudo ./scripts/install-lora-service.sh --user youruser --config global_conf_as923_th.json
```

Status / logs:

```bash
sudo systemctl status lora_pkt_fwd.service
journalctl -u lora_pkt_fwd -f
```

Manual template: [`systemd/lora_pkt_fwd.service`](systemd/lora_pkt_fwd.service).

---

## 5. ChirpStack (Docker Compose)

Pre-configured for **AS923 (Thailand)**. For other regions, edit MQTT topic templates in `chirpstack-docker/docker-compose.yml` and the region files under `configuration/`.

### What is ChirpStack?

[ChirpStack](https://www.chirpstack.io) is an open-source LoRaWAN Network Server with a web UI for gateways, devices, tenants, and integrations, plus a gRPC API.

### Start the stack

```bash
cd ~/SenseCAPM1-Chirpstack/chirpstack-docker
docker compose up -d
```

Wait 1–3 minutes, then open:

```text
http://<m1-ip>:8080
```

Default login: **admin / admin** — change this if the host is reachable beyond a trusted LAN.

### Register the gateway

1. Left menu → **Gateways** → add  
2. **Gateway ID** = same EUI as in the packet-forwarder config  

### (Optional) Import device profiles

```bash
cd ~/SenseCAPM1-Chirpstack/chirpstack-docker
sudo apt install -y make
make import-lorawan-devices
```

Docs: https://www.chirpstack.io/docs/

---

## 6. Node-RED (optional)

```bash
cd ~
bash <(curl -sL https://raw.githubusercontent.com/node-red/linux-installers/master/deb/update-nodejs-and-nodered)
```

Answer the prompts (Pi-specific nodes if you want), then:

```bash
sudo systemctl enable --now nodered.service
```

UI: `http://<ip>:1880`

---

## 7. Advanced: multiple LNS with Packet Multiplexer

[ChirpStack Packet Multiplexer](https://github.com/chirpstack/chirpstack-packet-multiplexer) forwards Semtech UDP traffic to several backends (e.g. private ChirpStack + TTN).

### Install (ChirpStack 4.x apt repo)

```bash
sudo apt install -y gpg wget apt-transport-https
sudo mkdir -p /etc/apt/keyrings
sudo sh -c 'wget -q -O - https://artifacts.chirpstack.io/packages/chirpstack.key | gpg --dearmor -o /etc/apt/keyrings/chirpstack.gpg'
echo "deb [signed-by=/etc/apt/keyrings/chirpstack.gpg] https://artifacts.chirpstack.io/packages/4.x/deb stable main" | sudo tee /etc/apt/sources.list.d/chirpstack.list
sudo apt update
sudo apt install -y chirpstack-packet-multiplexer
```

### Configure

```bash
sudo mkdir -p /etc/chirpstack-packet-multiplexer
sudo cp ~/SenseCAPM1-Chirpstack/chirpstack-packet-multiplexer.toml \
  /etc/chirpstack-packet-multiplexer/chirpstack-packet-multiplexer.toml
sudo nano /etc/chirpstack-packet-multiplexer/chirpstack-packet-multiplexer.toml
```

Default template binds on **`:17000`** so it does not clash with Gateway Bridge on **`:1700`**.  
When using the multiplexer, point packet-forwarder `serv_port_up` / `serv_port_down` to **17000**.

```bash
sudo systemctl enable --now chirpstack-packet-multiplexer
sudo systemctl status chirpstack-packet-multiplexer
```

---

## 8. Bonus: Mysterium node

```bash
sudo -E bash -c "$(curl -s https://raw.githubusercontent.com/mysteriumnetwork/node/master/install.sh)"
sudo reboot
```

After 5–10 minutes: `http://<ip>:4449`

---

## Desktop / VNC

If you installed Desktop, use a VNC client or Raspberry Pi Connect for remote GUI access.

---

## Bookworm → Trixie migration notes

| Topic | Bookworm | Trixie (`main`) |
|-------|----------|-----------------|
| Base OS | Debian 12 | Debian 13 |
| Swap | `dphys-swapfile` | `rpi-swap` |
| GPIO CLI | libgpiod **1.x** | libgpiod **2.x** |
| `reset_lgw.sh` | v1-oriented | auto-detects v1 and v2 |
| Multiplexer apt | 3.x + deprecated `apt-key` | **4.x** + `/etc/apt/keyrings` |
| Multiplexer config | v3 TOML shape | v4 `[multiplexer]` / `[[multiplexer.server]]` |
| Docker Compose | optional `version:` key | Compose Spec (no `version`) |
| Images | postgres 14 / floating `latest` | postgres **16** / ChirpStack major **4** |

---

## Repo layout

```text
SenseCAPM1-Chirpstack/
├── packet_forwarder/          # Semtech UDP PF + configs + reset
├── chirpstack-docker/         # ChirpStack v4 Compose stack
├── scripts/
│   ├── install-lora-service.sh
│   └── check-syntax.sh
├── systemd/lora_pkt_fwd.service
├── .github/workflows/ci.yml
├── CHANGELOG.md
└── chirpstack-packet-multiplexer.toml
```

## CI / local checks

GitHub Actions runs on push/PR to `main` and `bookworm`:

- `bash -n` / `sh -n` on shell scripts  
- ShellCheck  
- `python -m py_compile`  
- `docker compose config`  
- basic systemd unit layout check  

Run locally:

```bash
./scripts/check-syntax.sh
```

---

## Closing

If the miner chapter is over, the hardware chapter doesn’t have to be.  
This guide turns the M1 back into a working LoRaWAN gateway, your network, your rules.

**Made in Phatthalung, Thailand.**
