# SenseCAP M1 → ChirpStack

> **กล่องขุด HNT ที่เคยฝันว่าจะรวย… ตอนนี้กลายเป็น RPi4 + วิทยุ LoRa ที่ยังใช้ได้อยู่**  
> ถ้า seed ยังอยู่ ไปขุดต่อได้เลยครับ รีโปนี้ไม่ใช่สำหรับคุณ  
> ถ้า seed หาย — ยินดีต้อนรับสู่สโมสร “ฮาร์ดแวร์แพง อารมณ์พัง ยัง salvage ได้”

เอา **Seeed SenseCAP M1** (Raspberry Pi 4 + WM1302/WM1303) มาเปิดเป็นเกตเวย์ + [ChirpStack](https://www.chirpstack.io) LNS ส่วนตัว  
ไม่ต้องอ้อน blockchain ไม่ต้องเช็คราคา token ก่อนนอน

| Branch | สำหรับใคร |
|--------|-----------|
| **`main`** (อันนี้) | **Raspberry Pi OS Debian 13 Trixie** — ของใหม่ ใช้ตัวนี้ |
| [`bookworm`](https://github.com/hereismeaw/SenseCAPM1-Chirpstack/tree/bookworm) | ยังติด Bookworm (Debian 12) อยู่ — เราไม่ทิ้งคุณ แต่ก็ไม่อัพเกรดให้ฟรีด้วย |

**ฮาร์ดแวร์ในกล่อง:** RPi4 + Semtech SX1302 (WM1302) หรือ SX1303 (WM1303) ต่อ SPI  
ใช่ครับ ข้างในคือ Raspberry Pi ที่ห่อพลาสติกแพงๆ มา — ข่าวดีคือมัน *ยังเป็นคอมพิวเตอร์*

---

## เสีย seed Helium แล้วใช่ไหม

**กู้ไม่ได้**  
ไม่ใช่ “ลองติดต่อซัพพอร์ต” ไม่ใช่ “อาจมี backdoor” ไม่ใช่ “เดี๋ยวทีมงานช่วย”  
คือ **จบ** — แอปบอกชัด กล่องการ์ดก็ให้มาเขียน ถ้าเขียนแล้วเอากล่องไปรองแก้ว… นั่นคุณเอง

อ่านกล่องเหลืองของทางการก่อนจะมาด่าจักรวาล:  
https://docs.helium.com/wallets/wallet-seed-phrase

ข่าวดี (แบบประชด):  
ตัวเกตเวย์ยังมี SPI, ยังมี concentrator, ยังบูต Linux ได้  
HNT อาจจากไปแล้ว แต่ **LoRaWAN ยังอยู่** — และคราวนี้คุณเป็นเจ้าของ LNS เอง ไม่ใช่แค่ “node ในเครือข่ายที่ใครก็ไม่รู้”

### ของที่ต้องมีก่อนเริ่มบ่น

1. SenseCAP M1 ที่ seed หาย / เลิกขุดแล้ว / อยากใช้จริงจัง  
2. พอใช้ Linux CLI ได้ (copy-paste เป็นก็รอด)  
3. เครื่องอ่าน microSD  
4. SD คุณภาพดี — ซื้อถูกสุดในตลาดนัดแล้วมาโวยว่า filesystem corrupt อย่านะ  
5. เวลา + กาแฟ + การยอมรับความจริง

---

## 1. แฟลช OS — ยุค Trixie แล้ว อย่าเอาภาพเก่าจากหีบ

โหลด [Raspberry Pi Imager](https://www.raspberrypi.com/software/)

1. บอร์ด: **Raspberry Pi 4**  
2. OS: **Raspberry Pi OS (64-bit)** — คำอธิบายต้องมีคำว่า **Debian Trixie**  
   - Lite ก็ได้ (headless สายลุย)  
   - Desktop ก็ได้ (สายอยากมีปุ่มกด)  
3. ตั้งค่าใน Imager:  
   - username / password  
   - Wi-Fi (ถ้าจะไร้สาย)  
   - **เปิด SSH** — ลืมอันนี้ = นั่งมองกล่องเงียบๆ  
4. เขียนเสร็จ → ยัด SD เข้า SenseCAP → เปิดเครื่อง

SSH เข้าไปด้วยตัวโปรด: Termius, PuTTY, OpenSSH, หรืออะไรก็ได้ที่ไม่ใช่ “เดี๋ยวใช้จอ” แล้วไม่มีจอ

> ยัง Bookworm อยู่? อย่าฝืนทำตาม `main` แล้วมาเปิด issue ว่า GPIO พัง  
> ใช้ branch [`bookworm`](https://github.com/hereismeaw/SenseCAPM1-Chirpstack/tree/bookworm)

---

## 2. เปิดอินเทอร์เฟซ + อย่าให้เครื่องอึดอัด

### raspi-config — เปิดของที่วิทยุต้องการ

```bash
sudo raspi-config
```

เข้า **Interface Options** แล้วเปิด:

- **SPI** ← ปิดอันนี้ = วิทยุกลายเป็นอิฐราคาแพง  
- **I2C**  
- **Serial Port** (login shell: No / serial hardware: Yes ถ้ามีให้เลือก)  
- **VNC** (ถ้าลง Desktop แล้วอยากยื่นเมาส์จากระยะไกล)

ยังไม่รีบูต ถ้ายังมีงานค้างด้านล่าง — รีบูตทีเดียวจบ อย่ารีบูตเป็นงานอดิเรก

### EEPROM — ของฟรีที่คนขี้เกียจข้าม

```bash
sudo rpi-eeprom-update -a
```

### Swap ยุค Trixie: บอกลา `dphys-swapfile`

Trixie โยนของเก่าทิ้ง ใช้ **`rpi-swap`** แทน  
ค่า default ส่วนใหญ่พอใช้ ถ้าจะรัน Docker เพียบแล้วอยากได้ swap ไฟล์ **2 GiB**:

```bash
sudo mkdir -p /etc/rpi/swap.conf.d
sudo tee /etc/rpi/swap.conf.d/80-swapfile-2g.conf >/dev/null <<'EOF'
[Main]
Mechanism=swapfile

[File]
FixedSizeMiB=2048
EOF
```

มีผลหลังรีบูต (รายละเอียด: `man swap.conf`)  
ใช่ครับ โลกหมุนไปแล้ว — config path เดิมใช้ไม่ได้ โทษ Debian ไม่ใช่โทษเรา

### แพ็กเกจพื้นฐาน

```bash
sudo apt update && sudo apt full-upgrade -y
sudo apt install -y gpiod git curl ca-certificates
```

`gpiod` = เครื่องมือยุคใหม่หลัง sysfs GPIO ถูกฆ่าทิ้ง  
บน Trixie เป็น **libgpiod 2.x** — syntax เปลี่ยน สคริปต์ในรีโปนี้เผื่อทั้ง 1.x และ 2.x ให้แล้ว อย่าไปก็อป `gpioset` จากบล็อกปี 2019

### Docker — เพราะคุณไม่ได้เกิดมาเพื่อ compile ทุกอย่างด้วยมือ

```bash
curl -sSL https://get.docker.com | sh
sudo usermod -aG docker "$USER"
sudo usermod -aG gpio,spi,dialout "$USER"
sudo reboot
```

หลังตื่น:

```bash
sudo apt autoremove -y
docker version   # ถ้ายังต้อง sudo = ยังไม่ได้ login ใหม่ โทษคุณ
```

---

## 3. ดึงรีโปนี้ลงเครื่อง

```bash
cd ~
git clone https://github.com/hereismeaw/SenseCAPM1-Chirpstack.git
cd SenseCAPM1-Chirpstack
```

`main` = Trixie  
Bookworm:

```bash
git clone -b bookworm https://github.com/hereismeaw/SenseCAPM1-Chirpstack.git
```

---

## 4. Packet forwarder — หัวใจวิทยุ อย่าทำพลาดตรงนี้

GPIO แบบ `/sys/class/gpio` ตายไปแล้ว  
`reset_lgw.sh` ในนี้ใช้ **libgpiod** และเดาเวอร์ชันเอง:

- **v2** → Trixie  
- **v1** → Bookworm  

### ใส่สิทธิ์ execute

```bash
cd ~/SenseCAPM1-Chirpstack/packet_forwarder
chmod +x reset_lgw.sh lora_pkt_fwd spectral_scan
```

### อ่าน Concentrator EUI (ตัวตนจริงของชิป อย่ามโน)

WM1302 (SX1302) — คอนฟิก AS923 ไทยในรีโป:

```bash
./lora_pkt_fwd -c global_conf_as923_th.json
```

WM1303 (SX1303):

```bash
./lora_pkt_fwd -c global_conf_as923_th_sx1303.json
```

มองหาประมาณนี้ แล้ว**จด** — อย่าแค่มองแล้วพยัก:

```text
INFO: concentrator EUI: 0xXXXXXXXXYYYYYYYY
```

`Ctrl+C` หยุดได้

### ยัด EUI ลง config

```bash
nano global_conf_as923_th.json   # หรือไฟล์ sx1303
```

หา `gateway_ID` ใต้ `gateway_conf`  
ใส่ EUI **ตัด `0x` ออก** เหลือ 16 ตัว hex:

```json
"gateway_ID": "XXXXXXXXYYYYYYYY",
```

เซฟ ออก  
ใส่เลขผิด = ChirpStack มองไม่เห็นเกตเวย์ แล้วคุณจะมาด่า “ขึ้นไม่ติด” ทั้งที่พิมพ์เลขเองผิด

> ไบนารี `lora_pkt_fwd` มาเป็น aarch64 สำหรับ RPi4  
> ตัว build บน Bookworm ปกติวิ่งบน Trixie ได้ (glibc ใหม่กว่า)  
> ถ้า loader โวยเรื่อง glibc — ไป build เองจาก [sx1302_hal](https://github.com/Lora-net/sx1302_hal) บนเครื่องจริง อย่าแท็ก issue ว่า “binary หลอน” ก่อนลอง

### ลงเป็น systemd (แนะนำ — รีบูตแล้วต้องลุกเอง)

```bash
cd ~/SenseCAPM1-Chirpstack
sudo ./scripts/install-lora-service.sh
```

WM1303:

```bash
sudo ./scripts/install-lora-service.sh --config global_conf_as923_th_sx1303.json
```

user คนละชื่อ:

```bash
sudo ./scripts/install-lora-service.sh --user youruser --config global_conf_as923_th.json
```

เช็คว่ายังหายใจ:

```bash
sudo systemctl status lora_pkt_fwd.service
journalctl -u lora_pkt_fwd -f
```

อยากลงมือเอง: ดู template ที่ [`systemd/lora_pkt_fwd.service`](systemd/lora_pkt_fwd.service)

---

## 5. ChirpStack — LNS ที่คุณ *เป็นเจ้าของ* จริงๆ

สแต็กนี้เซ็ต **AS923 (ไทย)** ไว้ให้แล้ว  
โซนอื่น: ไปแก้ topic ใน `chirpstack-docker/docker-compose.yml` กับไฟล์ region เอง อย่ารอให้ใครมา fork ให้ฟรี

### ChirpStack คืออะไร (เวอร์ชันสั้น ไม่มีสไลด์ขายของ)

[ChirpStack](https://www.chirpstack.io) = LoRaWAN Network Server โอเพนซอร์ส  
มีเว็บ จัดการเกตเวย์/อุปกรณ์/tenant/integration + gRPC API  
ไม่มี token ให้เชียร์ ไม่มี “epoch” ให้รีเฟรชทุกชั่วโมง — สงบดี

### สตาร์ท

```bash
cd ~/SenseCAPM1-Chirpstack/chirpstack-docker
docker compose up -d
```

รอ 1–3 นาที (postgres กับเพื่อนๆ กำลังจัดแถว) แล้วเปิด:

```text
http://<ip-ของ-m1>:8080
```

ล็อกอินเริ่มต้น: **admin / admin**  
ถ้าเปิดทิ้งไว้บนเน็ตสาธารณะด้วยรหัสนี้ — นั่นไม่ใช่ “แฮ็ก” นั่นคือ “เชิญเข้าบ้านแล้ววางกุญแจไว้หน้าประตู”

### ลงทะเบียนเกตเวย์

1. เมนูซ้าย → **Gateways** → เพิ่ม  
2. **Gateway ID** = EUI เดียวกับใน packet forwarder  
   (คนละเลข = นั่งมองกราฟว่างเปล่า)

### (ทางเลือก) ดึง device profile จาก lorawan-devices

```bash
cd ~/SenseCAPM1-Chirpstack/chirpstack-docker
sudo apt install -y make
make import-lorawan-devices
```

เอกสารยาวๆ ไปที่: https://www.chirpstack.io/docs/

---

## 6. Node-RED (ถ้าอยากลากเส้นมากกว่าเขียนโค้ด)

```bash
cd ~
bash <(curl -sL https://raw.githubusercontent.com/node-red/linux-installers/master/deb/update-nodejs-and-nodered)
```

ตอบตามใจ (Pi nodes ก็ได้) แล้ว:

```bash
sudo systemctl enable --now nodered.service
```

เปิด: `http://<ip>:1880`  
เอาไว้ต่อ MQTT / แจ้งเตือน / dashboard — จะทำ “smart farm” หรือแค่โชว์เพื่อนว่า “ยังใช้กล่องนี้ได้อยู่” ก็เรื่องของคุณ

---

## 7. สายโหด: ยิงแพ็กเก็ตไปหลาย LNS พร้อมกัน

[ChirpStack Packet Multiplexer](https://github.com/chirpstack/chirpstack-packet-multiplexer)  
ตัวกลางรับ UDP จาก packet forwarder แล้วกระจายไปหลายเซิร์ฟเวอร์  
เช่น ChirpStack บ้านตัวเอง + TTN — แบบไม่ต้องมีเกตเวย์สองเครื่อง

### ติดตั้ง (repo 4.x — เลิกใช้ `apt-key` ซะที มัน deprecate มานานแล้ว)

```bash
sudo apt install -y gpg wget apt-transport-https
sudo mkdir -p /etc/apt/keyrings
sudo sh -c 'wget -q -O - https://artifacts.chirpstack.io/packages/chirpstack.key | gpg --dearmor -o /etc/apt/keyrings/chirpstack.gpg'
echo "deb [signed-by=/etc/apt/keyrings/chirpstack.gpg] https://artifacts.chirpstack.io/packages/4.x/deb stable main" | sudo tee /etc/apt/sources.list.d/chirpstack.list
sudo apt update
sudo apt install -y chirpstack-packet-multiplexer
```

### คอนฟิก

เทมเพลต v4 อยู่ในรีโป:

```bash
sudo mkdir -p /etc/chirpstack-packet-multiplexer
sudo cp ~/SenseCAPM1-Chirpstack/chirpstack-packet-multiplexer.toml \
  /etc/chirpstack-packet-multiplexer/chirpstack-packet-multiplexer.toml
sudo nano /etc/chirpstack-packet-multiplexer/chirpstack-packet-multiplexer.toml
```

ค่าเริ่มต้น bind **`:17000`** — ไม่ชน Gateway Bridge ที่ **`:1700`**  
ใช้ mux แล้วให้ packet forwarder ชี้ `serv_port_up` / `serv_port_down` ไป **17000**

```bash
sudo systemctl enable --now chirpstack-packet-multiplexer
sudo systemctl status chirpstack-packet-multiplexer
```

---

## 8. โบนัส: Mysterium — ถ้ายังอยากให้กล่อง “หาเงิน” แบบอื่น

```bash
sudo -E bash -c "$(curl -s https://raw.githubusercontent.com/mysteriumnetwork/node/master/install.sh)"
sudo reboot
```

รอ 5–10 นาที แล้วลอง: `http://<ip>:4449`  
ไม่การันตีรวย แค่บอกว่ากล่องยังมีประโยชน์หลายหน้า — ไม่ต้องเป็นอนุสรณ์ HNT อย่างเดียว

---

## Desktop / VNC

ลง Desktop มา? ใช้ VNC หรือ Raspberry Pi Connect ก็ได้  
สาย Lite ไม่ต้องอ่านหัวข้อนี้ ไปนั่ง SSH ต่อ

---

## ย้ายจาก Bookworm → Trixie (สรุปแบบไม่อวย)

| เรื่อง | Bookworm | Trixie (`main`) |
|--------|----------|-----------------|
| ฐาน | Debian 12 | Debian 13 |
| Swap | `dphys-swapfile` | `rpi-swap` |
| GPIO CLI | libgpiod **1.x** | libgpiod **2.x** |
| `reset_lgw.sh` | โบราณกว่า | เดา v1/v2 เอง |
| Multiplexer apt | 3.x + `apt-key` ซาก | **4.x** + keyring |
| Compose | ยังมีคนใส่ `version:` | ไม่ต้องแล้ว |
| รูป Docker | postgres 14 / `latest` ลอยๆ | postgres **16** / ChirpStack **4** |

สรุป: ของเก่าพังไม่ใช่เพราะ “คุณโชคร้าย” — เพราะโลกอัปเดต แล้วรีโปนี้ตามทันบน `main`

---

## โครงรีโป (สำหรับคนขี้เกียจคลิกทีละโฟลเดอร์)

```text
SenseCAPM1-Chirpstack/
├── packet_forwarder/     # วิทยุ + conf + reset
├── chirpstack-docker/    # LNS ทั้งก้อนใน Compose
├── scripts/              # ลง service + ตรวจ syntax
├── systemd/              # unit ตัวอย่าง
├── .github/workflows/    # CI กัน script พังเงียบๆ
└── chirpstack-packet-multiplexer.toml
```

## CI — กัน “กูแก้ script แล้วลืม semicolon”

Push/PR ไป `main` / `bookworm` แล้ว Actions จะรัน:

- `bash -n` / `sh -n`
- ShellCheck
- `py_compile`
- `docker compose config`
- เช็คโครง systemd คร่าวๆ

รันเองบนเครื่อง:

```bash
./scripts/check-syntax.sh
```

---

## ท้ายเรื่อง

เคยซื้อกล่องมาเพราะกราฟเขียว  
ตอนนี้อาจเหลือแค่กล่องกับบทเรียนเรื่อง seed phrase  

อย่างน้อยหลังทำตามนี้ กล่องจะได้ทำงานอีกครั้ง —  
ส่งแพ็กเก็ต LoRaWAN จริง ไม่ใช่แค่นั่งเป็นอนุสาวรีย์ “ช่วงนั้นฉันก็ขุดเหมือนกัน”

**Made in Phatthalung, Thailand.**  
ยังกวนได้ ยัง salvage ได้ ยังไม่ทิ้งฮาร์ดแวร์ดีๆ แค่เพราะ token ไม่เล่นด้วย
