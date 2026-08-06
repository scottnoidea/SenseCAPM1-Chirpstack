# SenseCAP M1 → ChirpStack (Raspberry Pi OS Trixie)

Turn a **Seeed SenseCAP M1** (Raspberry Pi 4 + WM1302/WM1303 LoRa concentrator) into a private [ChirpStack](https://www.chirpstack.io) LoRaWAN Network Server gateway.

| Branch | Target OS |
|--------|-----------|
| **`main`** (this branch) | **Raspberry Pi OS based on Debian 13 Trixie** (current) |
| [`bookworm`](https://github.com/hereismeaw/SenseCAPM1-Chirpstack/tree/bookworm) | Raspberry Pi OS Bookworm (Debian 12) — legacy |

> **Hardware:** SenseCAP M1 = RPi 4 + Semtech SX1302 (WM1302) or SX1303 (WM1303) SPI module.

---

## If you lost your Helium seed phrase

There is **no recovery**. The Helium app is explicit about this during setup — that is why it ships with a write-down card. See the official warning: https://docs.helium.com/wallets/wallet-seed-phrase

### Requirements

1. SenseCAP M1 (lost Helium keys / re-purposing as ChirpStack gateway)
2. Basic Linux command line
3. Micro SD card reader
4. Good quality SD card (A2 / high endurance recommended)
5. Time

---

## 1. Flash Raspberry Pi OS (Trixie)

Download [Raspberry Pi Imager](https://www.raspberrypi.com/software/).

1. Choose board: **Raspberry Pi 4**
2. Choose OS: **Raspberry Pi OS (64-bit)** — description should say **Debian Trixie**  
   (Lite or Desktop is fine; Lite is enough for headless gateways)
3. In OS customisation:
   - Set username & password
   - Configure Wi-Fi (if needed)
   - **Enable SSH**
4. Write the image, then insert the SD card into the SenseCAP M1 and power on

SSH in with your favourite client (Termius, PuTTY, OpenSSH, etc.).

> Need the older Bookworm guide? Use branch [`bookworm`](https://github.com/hereismeaw/SenseCAPM1-Chirpstack/tree/bookworm).

---

## 2. Board interfaces & firmware

### Enable interfaces

```bash
sudo raspi-config
```

Under **Interface Options**, enable:

- **SPI** (required for WM1302/WM1303)
- **I2C**
- **Serial Port** (login shell: No, serial hardware: Yes — if offered)
- **VNC** (optional, Desktop only)

Do **not** reboot yet if you still have more setup steps below.

### Update EEPROM (recommended)

```bash
sudo rpi-eeprom-update -a
```

### Swap on Trixie (`rpi-swap`)

Trixie replaces `dphys-swapfile` with **`rpi-swap`**. Default hybrid zram+file is usually fine. To force a **2 GiB swap file** (useful when building or running many containers):

```bash
sudo mkdir -p /etc/rpi/swap.conf.d
sudo tee /etc/rpi/swap.conf.d/80-swapfile-2g.conf >/dev/null <<'EOF'
[Main]
Mechanism=swapfile

[File]
FixedSizeMiB=2048
EOF
```

Changes apply on the next reboot (`man swap.conf`).

### System packages

```bash
sudo apt update && sudo apt full-upgrade -y
sudo apt install -y gpiod git curl ca-certificates
```

`gpiod` provides `gpioset` / `gpiodetect` used by the concentrator reset script (**libgpiod 2.x** on Trixie).

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

Default branch `main` = **Trixie**. For Bookworm hosts:

```bash
git clone -b bookworm https://github.com/hereismeaw/SenseCAPM1-Chirpstack.git
```

---

## 4. Packet forwarder (WM1302 / WM1303)

On modern Raspberry Pi OS, **sysfs GPIO is gone**. This repo’s `reset_lgw.sh` uses **libgpiod** and auto-detects:

- **v2** CLI → Trixie  
- **v1** CLI → Bookworm  

### Make binaries executable

```bash
cd ~/SenseCAPM1-Chirpstack/packet_forwarder
chmod +x reset_lgw.sh lora_pkt_fwd spectral_scan
```

### Read concentrator EUI

WM1302 (SX1302) default config (AS923 Thailand):

```bash
./lora_pkt_fwd -c global_conf_as923_th.json
```

WM1303 (SX1303):

```bash
./lora_pkt_fwd -c global_conf_as923_th_sx1303.json
```

Watch for:

```text
INFO: concentrator EUI: 0xXXXXXXXXYYYYYYYY
```

Note that EUI, then stop with `Ctrl+C`.

### Set Gateway ID in config

```bash
nano global_conf_as923_th.json   # or the sx1303 file
```

Find `gateway_ID` (under `gateway_conf`) and set it to your concentrator EUI **without** the `0x` prefix, 16 hex chars, e.g.:

```json
"gateway_ID": "XXXXXXXXYYYYYYYY",
```

Save and exit.

> Pre-built `lora_pkt_fwd` is for aarch64 RPi 4. Binaries built against Bookworm glibc normally run on Trixie (newer glibc). If you ever see loader/glibc errors, rebuild from [Lora-net/sx1302_hal](https://github.com/Lora-net/sx1302_hal) on the Pi.

### Install as a systemd service (recommended)

```bash
cd ~/SenseCAPM1-Chirpstack
sudo ./scripts/install-lora-service.sh
```

WM1303:

```bash
sudo ./scripts/install-lora-service.sh --config global_conf_as923_th_sx1303.json
```

Custom Linux user:

```bash
sudo ./scripts/install-lora-service.sh --user youruser --config global_conf_as923_th.json
```

Check status / logs:

```bash
sudo systemctl status lora_pkt_fwd.service
journalctl -u lora_pkt_fwd -f
```

Manual install template: [`systemd/lora_pkt_fwd.service`](systemd/lora_pkt_fwd.service).

---

## 5. ChirpStack (Docker Compose)

This stack is pre-tuned for **AS923** (Thailand) MQTT topic prefixes. Other regions: edit topic templates in `chirpstack-docker/docker-compose.yml` and region files under `configuration/`.

### What is ChirpStack?

[ChirpStack](https://www.chirpstack.io) is an open-source LoRaWAN Network Server with a web UI for gateways, devices, tenants, and integrations, plus a gRPC API.

### Start the stack

```bash
cd ~/SenseCAPM1-Chirpstack/chirpstack-docker
docker compose up -d
```

Wait 1–3 minutes, then open:

```text
http://<sensecap-ip>:8080
```

Default login: **admin / admin** — change this immediately on any network that is not fully trusted.

### Register the gateway

1. Left menu → **Gateways** → add gateway  
2. **Gateway ID** = same EUI as in the packet-forwarder config  

### (Optional) Import device profiles from lorawan-devices

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

Answer the prompts (install Pi-specific nodes if you want). Then:

```bash
sudo systemctl enable --now nodered.service
```

UI: `http://<sensecap-ip>:1880`

---

## 7. Advanced: multi-LNS with Packet Multiplexer

[ChirpStack Packet Multiplexer](https://github.com/chirpstack/chirpstack-packet-multiplexer) forwards Semtech UDP packet-forwarder traffic to **multiple** network servers (private ChirpStack + TTN, etc.).

### Install (ChirpStack 4.x apt repo — Trixie-safe, no `apt-key`)

```bash
sudo apt install -y gpg wget apt-transport-https
sudo mkdir -p /etc/apt/keyrings
sudo sh -c 'wget -q -O - https://artifacts.chirpstack.io/packages/chirpstack.key | gpg --dearmor -o /etc/apt/keyrings/chirpstack.gpg'
echo "deb [signed-by=/etc/apt/keyrings/chirpstack.gpg] https://artifacts.chirpstack.io/packages/4.x/deb stable main" | sudo tee /etc/apt/sources.list.d/chirpstack.list
sudo apt update
sudo apt install -y chirpstack-packet-multiplexer
```

### Configure

Template in this repo (v4 TOML format):

```bash
sudo mkdir -p /etc/chirpstack-packet-multiplexer
sudo cp ~/SenseCAPM1-Chirpstack/chirpstack-packet-multiplexer.toml \
  /etc/chirpstack-packet-multiplexer/chirpstack-packet-multiplexer.toml
sudo nano /etc/chirpstack-packet-multiplexer/chirpstack-packet-multiplexer.toml
```

Default template binds on **`:17000`** so it does not clash with Gateway Bridge on **`:1700`**. Point the packet forwarder `serv_port_up` / `serv_port_down` to **17000** when using the multiplexer.

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

After 5–10 minutes: `http://<sensecap-ip>:4449`

---

## Desktop / VNC

If you installed Desktop, use any VNC client (or Raspberry Pi Connect, where available) to control the UI remotely.

---

## Trixie migration notes (from Bookworm)

| Area | Bookworm | Trixie (`main`) |
|------|----------|-----------------|
| Base OS | Debian 12 | Debian 13 |
| Swap | `dphys-swapfile` / `/etc/dphys-swapfile` | `rpi-swap` / `/etc/rpi/swap.conf(.d)` |
| GPIO tools | libgpiod **1.x** (`gpioset -m time …`) | libgpiod **2.x** (`gpioset -c … --hold-period … -t0`) |
| Reset script | v1 syntax only | Auto-detects v1 and v2 |
| Packet multiplexer apt | 3.x + deprecated `apt-key` | **4.x** + `/etc/apt/keyrings` |
| Multiplexer config | `[packet_multiplexer]` / `backend` | `[multiplexer]` / `[[multiplexer.server]]` |
| Docker Compose | optional `version:` key | Compose Spec (no `version`) |
| Images | postgres 14, floating `latest` | postgres **16**, ChirpStack major **4** tags |

---

## Repo layout

```text
SenseCAPM1-Chirpstack/
├── packet_forwarder/          # Semtech UDP PF + global_conf + reset_lgw.sh
├── chirpstack-docker/         # ChirpStack v4 Docker Compose stack
├── scripts/install-lora-service.sh
├── systemd/lora_pkt_fwd.service
└── chirpstack-packet-multiplexer.toml
```

---

## Made in Phatthalung, Thailand.
