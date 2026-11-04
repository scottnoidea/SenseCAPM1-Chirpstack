"""Generate runtime configuration; never rewrite the checked-in radio template."""
import argparse
import json
import os
from pathlib import Path
import re
import secrets
import tempfile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("repo", type=Path)
parser.add_argument("--gateway-id")
args = parser.parse_args()
source = args.repo / "packet_forwarder/global_conf_au915.json"
target = Path("/etc/sensecap-m1/global_conf.json")
config = json.loads(source.read_text())
# Preserve both calibration and gateway settings from a previous installation.
if target.exists():
    config = json.loads(target.read_text())
if args.gateway_id:
    config["gateway_conf"]["gateway_ID"] = args.gateway_id.upper()
if not re.fullmatch(r"[0-9a-fA-F]{16}", config["gateway_conf"]["gateway_ID"]):
    parser.error("gateway ID must contain exactly 16 hexadecimal characters")
# Apply only the FSB2 channel plan to an existing runtime configuration.
radio = config["SX130x_conf"]
radio["radio_0"]["freq"] = 917100000
radio["radio_1"]["freq"] = 917900000
for i in range(8):
    radio[f"chan_multiSF_{i}"].update(enable=True, radio=i // 4, **{"if": -300000 + (i % 4) * 200000})
radio["chan_Lora_std"].update(enable=True, radio=1, **{"if": -400000}, bandwidth=500000, spread_factor=8)
radio["chan_FSK"]["enable"] = False

def atomic_write(path, text, mode):
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=path.parent)
    try:
        with os.fdopen(fd, "w") as out:
            out.write(text)
        os.chmod(tmp, mode)
        os.replace(tmp, path)
    finally:
        if os.path.exists(tmp):
            os.unlink(tmp)

atomic_write(target, json.dumps(config, indent=2) + "\n", 0o644)
stack = args.repo / "chirpstack-docker"
env = stack / ".env"
if not env.exists():
    atomic_write(env, "CHIRPSTACK_API_SECRET=" + secrets.token_hex(32) + "\n", 0o600)
# Official image runs as nobody:nogroup. Do not recursively change existing DBs.
data = stack / "data/chirpstack"
data.mkdir(parents=True, exist_ok=True)
os.chown(data, 65534, 65534)
os.chmod(data, 0o750)
print(f"Configured {target}; gateway ID: {config['gateway_conf']['gateway_ID']}")
print("Preserved existing API secret and runtime hardware/gateway settings.")
