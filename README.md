# SenseCAP M1 → ChirpStack

> **That HNT mining box you bought in the boom years?**  
> Under the plastic it’s still a Raspberry Pi 4 + a perfectly good LoRa concentrator.  
> If your seed is safe, go mine (or don’t). This repo isn’t for you.  
> If the seed is gone — welcome to the “expensive brick, salvageable radio” club.

Turn a **Seeed SenseCAP M1** (RPi 4 + WM1302/WM1303) into a private [ChirpStack](https://www.chirpstack.io) LoRaWAN gateway + network server.  
No token charts. No epoch anxiety. Just packets you actually own.

| Branch | Who it’s for |
|--------|----------------|
| **`main`** (you are here) | **Raspberry Pi OS on Debian 13 Trixie** — use this |
| [`bookworm`](https://github.com/hereismeaw/SenseCAPM1-Chirpstack/tree/bookworm) | Still on Bookworm (Debian 12) — we didn’t ghost you, we just stopped living there |

**What’s in the tin:** RPi 4 + Semtech SX1302 (WM1302) or SX1303 (WM1303) on SPI.  
Yes, you paid “gateway money” for a Pi in a nicer shell. The upside: **it still boots Linux.**

---

## You lost the Helium seed phrase

**There is no recovery.**  
Not “open a ticket.” Not “maybe support has a backdoor.” Not “my cousin knows a guy.”  
The app was loud about this. They even shipped a card so you’d write the words down.  
If that card is now a coaster — that’s on you.

Official yellow warning box (read it, then stop bargaining with the universe):  
https://docs.helium.com/wallets/wallet-seed-phrase

Silver lining (the snarky kind):  
SPI still works. The concentrator still works. Linux still works.  
HNT might have left the chat, but **LoRaWAN didn’t** — and this time *you* run the LNS.

### What you need before the complaining starts

1. A SenseCAP M1 (lost keys / retired miner / “I want a real gateway”)  
2. Basic Linux CLI (copy-paste counts)  
3. A microSD reader  
4. A decent SD card — buy the cheapest flea-market special and cry about corruption later if you insist  
5. Time, coffee, and a mild acceptance of consequences  

---

## 1. Flash the OS — it’s Trixie now; stop hoarding 2023 images

Grab [Raspberry Pi Imager](https://www.raspberrypi.com/software/).

1. Board: **Raspberry Pi 4**  
2. OS: **Raspberry Pi OS (64-bit)** — the description should say **Debian Trixie**  
   - Lite = headless, fewer distractions  
   - Desktop = buttons and a mouse, if that’s your love language  
3. In OS customisation:  
   - username / password  
   - Wi-Fi if needed  
   - **Enable SSH** — forget this and you’ll be staring at a silent brick  
4. Write → SD into the M1 → power on  

SSH in with whatever you like: Termius, PuTTY, OpenSSH, muscle memory.

> Still on Bookworm? Don’t follow `main` and open an issue titled “GPIO broken.”  
> Use branch [`bookworm`](https://github.com/hereismeaw/SenseCAPM1-Chirpstack/tree/bookworm).

---

## 2. Interfaces, firmware, and not strangling the Pi

### raspi-config — flip the switches the radio cares about

```bash
sudo raspi-config
```

Under **Interface Options**, enable:

- **SPI** ← off = expensive paperweight with antennas  
- **I2C**  
- **Serial Port** (login shell: No / hardware serial: Yes, if asked)  
- **VNC** (Desktop only, optional)

Don’t reboot for sport. Finish the steps below, then reboot once like an adult.

### EEPROM — free maintenance people skip

```bash
sudo rpi-eeprom-update -a
```

### Swap on Trixie: `dphys-swapfile` left the building

Trixie uses **`rpi-swap`**. Defaults are fine for many boxes. Want a hard **2 GiB swap file** for Docker-heavy days:

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
Yes, the old path is dead. Blame the distro timeline, not this README.

### Base packages

```bash
sudo apt update && sudo apt full-upgrade -y
sudo apt install -y gpiod git curl ca-certificates
```

`gpiod` is what you use after sysfs GPIO got cancelled.  
Trixie ships **libgpiod 2.x** — CLI syntax changed. This repo’s reset script speaks both 1.x and 2.x. Stop pasting `gpioset` snippets from 2019 Stack Overflow.

### Docker — because you didn’t buy this box to compile the universe by hand

```bash
curl -sSL https://get.docker.com | sh
sudo usermod -aG docker "$USER"
sudo usermod -aG gpio,spi,dialout "$USER"
sudo reboot
```

After it comes back:

```bash
sudo apt autoremove -y
docker version   # still need sudo? you didn’t re-login. that’s a you problem
```

---

## 3. Clone the repo

```bash
cd ~
git clone https://github.com/hereismeaw/SenseCAPM1-Chirpstack.git
cd SenseCAPM1-Chirpstack
```

`main` = Trixie. Bookworm:

```bash
git clone -b bookworm https://github.com/hereismeaw/SenseCAPM1-Chirpstack.git
```

---

## 4. Packet forwarder — the radio’s heartbeat; don’t half-ass this

`/sys/class/gpio` is gone.  
`reset_lgw.sh` here uses **libgpiod** and auto-detects:

- **v2** → Trixie  
- **v1** → Bookworm  

### Executable bits

```bash
cd ~/SenseCAPM1-Chirpstack/packet_forwarder
chmod +x reset_lgw.sh lora_pkt_fwd spectral_scan
```

### Read the concentrator EUI (the chip’s real ID — don’t invent one)

WM1302 (SX1302), AS923 Thailand config in-repo:

```bash
./lora_pkt_fwd -c global_conf_as923_th.json
```

WM1303 (SX1303):

```bash
./lora_pkt_fwd -c global_conf_as923_th_sx1303.json
```

Look for something like this, **write it down**, then stop romanticizing the log:

```text
INFO: concentrator EUI: 0xXXXXXXXXYYYYYYYY
```

`Ctrl+C` when you’re done staring.

### Put the EUI in the config

```bash
nano global_conf_as923_th.json   # or the sx1303 file
```

Find `gateway_ID` under `gateway_conf`.  
Paste the EUI **without** the `0x` — 16 hex chars:

```json
"gateway_ID": "XXXXXXXXYYYYYYYY",
```

Save. Exit.  
Wrong ID = ChirpStack ghosts your gateway while you swear the software is broken.

> Prebuilt `lora_pkt_fwd` is aarch64 for RPi 4.  
> Bookworm-built binaries usually run on Trixie (newer glibc).  
> Loader/glibc errors? Rebuild from [sx1302_hal](https://github.com/Lora-net/sx1302_hal) on the Pi before filing “binary haunted” issues.

### systemd (recommended — reboots shouldn’t need a ritual)

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

Is it alive:

```bash
sudo systemctl status lora_pkt_fwd.service
journalctl -u lora_pkt_fwd -f
```

DIY unit template: [`systemd/lora_pkt_fwd.service`](systemd/lora_pkt_fwd.service).

---

## 5. ChirpStack — an LNS you actually *own*

Stack is pre-wired for **AS923 (Thailand)**.  
Other regions: edit MQTT topic templates in `chirpstack-docker/docker-compose.yml` and the region files. Nobody’s shipping you a personal fork for free.

### What is ChirpStack (short version, no pitch deck)

[ChirpStack](https://www.chirpstack.io) is an open-source LoRaWAN Network Server: web UI for gateways/devices/tenants/integrations, plus a gRPC API.  
No token to cheer for. No hourly “did the economics change” spiral. Bliss.

### Start it

```bash
cd ~/SenseCAPM1-Chirpstack/chirpstack-docker
docker compose up -d
```

Wait 1–3 minutes (Postgres and friends are finding their chairs), then:

```text
http://<m1-ip>:8080
```

Default login: **admin / admin**  
Leave that on a public network and you’re not “getting hacked” — you’re holding the door open with a welcome mat.

### Register the gateway

1. Left menu → **Gateways** → add  
2. **Gateway ID** = same EUI as the packet forwarder  
   (Mismatch = empty charts and a long evening of self-inflicted debugging)

### (Optional) Import lorawan-devices profiles

```bash
cd ~/SenseCAPM1-Chirpstack/chirpstack-docker
sudo apt install -y make
make import-lorawan-devices
```

Docs for people who like reading: https://www.chirpstack.io/docs/

---

## 6. Node-RED (optional — drag wires, feel productive)

```bash
cd ~
bash <(curl -sL https://raw.githubusercontent.com/node-red/linux-installers/master/deb/update-nodejs-and-nodered)
```

Answer the prompts (Pi nodes if you want), then:

```bash
sudo systemctl enable --now nodered.service
```

UI: `http://<ip>:1880`  
MQTT bridges, dashboards, “look it still does something” demos — your call.

---

## 7. Advanced: shoot packets at multiple LNS at once

[ChirpStack Packet Multiplexer](https://github.com/chirpstack/chirpstack-packet-multiplexer) sits in front of Semtech UDP and fans out to several backends — private ChirpStack + TTN, etc. One radio, several networks. Fancy.

### Install (4.x apt repo — `apt-key` is a fossil, stop using it)

```bash
sudo apt install -y gpg wget apt-transport-https
sudo mkdir -p /etc/apt/keyrings
sudo sh -c 'wget -q -O - https://artifacts.chirpstack.io/packages/chirpstack.key | gpg --dearmor -o /etc/apt/keyrings/chirpstack.gpg'
echo "deb [signed-by=/etc/apt/keyrings/chirpstack.gpg] https://artifacts.chirpstack.io/packages/4.x/deb stable main" | sudo tee /etc/apt/sources.list.d/chirpstack.list
sudo apt update
sudo apt install -y chirpstack-packet-multiplexer
```

### Configure

v4 template ships in this repo:

```bash
sudo mkdir -p /etc/chirpstack-packet-multiplexer
sudo cp ~/SenseCAPM1-Chirpstack/chirpstack-packet-multiplexer.toml \
  /etc/chirpstack-packet-multiplexer/chirpstack-packet-multiplexer.toml
sudo nano /etc/chirpstack-packet-multiplexer/chirpstack-packet-multiplexer.toml
```

Default bind is **`:17000`** so it doesn’t fistfight Gateway Bridge on **`:1700`**.  
Using the mux? Point packet-forwarder `serv_port_up` / `serv_port_down` at **17000**.

```bash
sudo systemctl enable --now chirpstack-packet-multiplexer
sudo systemctl status chirpstack-packet-multiplexer
```

---

## 8. Bonus: Mysterium — if the box still wants a side hustle

```bash
sudo -E bash -c "$(curl -s https://raw.githubusercontent.com/mysteriumnetwork/node/master/install.sh)"
sudo reboot
```

After 5–10 minutes: `http://<ip>:4449`  
Not a get-rich scheme. Just proof the hardware can wear more than one hat — it doesn’t have to be an HNT memorial forever.

---

## Desktop / VNC

Installed Desktop? Use a VNC client or Raspberry Pi Connect.  
Lite users: skip this heading, go back to SSH, you’re fine.

---

## Bookworm → Trixie (no marketing, just scars)

| Topic | Bookworm | Trixie (`main`) |
|-------|----------|-----------------|
| Base | Debian 12 | Debian 13 |
| Swap | `dphys-swapfile` | `rpi-swap` |
| GPIO CLI | libgpiod **1.x** | libgpiod **2.x** |
| `reset_lgw.sh` | older | auto v1/v2 |
| Multiplexer apt | 3.x + dead `apt-key` | **4.x** + keyring |
| Compose | people still paste `version:` | not required |
| Images | postgres 14 / floaty `latest` | postgres **16** / ChirpStack **4** |

If old recipes break, it’s not cosmic punishment — the platform moved. `main` moved with it.

---

## Repo layout (for people who hate clicking)

```text
SenseCAPM1-Chirpstack/
├── packet_forwarder/     # radio + conf + reset
├── chirpstack-docker/    # full LNS stack
├── scripts/              # service install + syntax checks
├── systemd/              # unit template
├── .github/workflows/    # CI so scripts don’t silently rot
└── chirpstack-packet-multiplexer.toml
```

## CI — because “I only changed one line” is a famous last sentence

On push/PR to `main` / `bookworm`, Actions runs:

- `bash -n` / `sh -n`
- ShellCheck
- `py_compile`
- `docker compose config`
- basic systemd unit shape check

Same suite locally:

```bash
./scripts/check-syntax.sh
```

---

## Closing rant

You might have bought the box because a chart was green.  
You might be left with hardware and a TED Talk’s worth of seed-phrase trauma.

At least after this, the box works again —  
real LoRaWAN packets, your network, your rules —  
not a dusty shrine to “yeah, I mined for a bit too.”

**Made in Phatthalung, Thailand.**  
Still snarky. Still salvageable. Still too good a radio to landfill over a missing 12 words.
