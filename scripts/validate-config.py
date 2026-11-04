"""Parse configs and verify the end-to-end AU915 FSB2 channel/topic contract."""
import json
from pathlib import Path
import re
import tomllib

root = Path(__file__).resolve().parent.parent
for path in (root / "packet_forwarder").glob("*.json"):
    json.loads(path.read_text())
for path in root.rglob("*.toml"):
    if ".git" not in path.parts:
        tomllib.loads(path.read_text())
base = root / "chirpstack-docker/configuration"
cs = tomllib.loads((base / "chirpstack/chirpstack.toml").read_text())
region, = tomllib.loads((base / "chirpstack/region_au915_1.toml").read_text())["regions"]
bridge = tomllib.loads((base / "chirpstack-gateway-bridge/chirpstack-gateway-bridge.toml").read_text())
pf = json.loads((root / "packet_forwarder/global_conf_au915.json").read_text())
radio = pf["SX130x_conf"]
expected = list(range(916800000, 918200001, 200000))
actual = []
for i in range(8):
    channel = radio[f"chan_multiSF_{i}"]
    assert channel["enable"]
    actual.append(radio[f"radio_{channel['radio']}"]["freq"] + channel["if"])
assert actual == expected, actual
std = radio["chan_Lora_std"]
assert std["enable"] and std["bandwidth"] == 500000 and std["spread_factor"] == 8
assert radio[f"radio_{std['radio']}"]["freq"] + std["if"] == 917500000
assert not radio["chan_FSK"]["enable"]
assert cs["network"]["enabled_regions"] == ["au915_1"]
assert "sqlite" in cs and "postgresql" not in cs
assert region["id"] == region["gateway"]["backend"]["mqtt"]["topic_prefix"] == "au915_1"
assert region["network"]["enabled_uplink_channels"] == [*range(8, 16), 65]
assert [c["frequency"] for c in region["gateway"]["channels"]] == expected + [917500000]
assert region["network"]["max_dr"] == 6
for key in ("event_topic_template", "state_topic_template", "command_topic_template"):
    assert bridge["integration"]["mqtt"][key].startswith("au915_1/gateway/")
assert re.fullmatch(r"[0-9A-Fa-f]{16}", pf["gateway_conf"]["gateway_ID"])
print("JSON / TOML parsing and AU915 FSB2 channel and MQTT checks passed")
