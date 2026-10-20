"""Prepare a cache-safe, project-path-safe Godot web preview."""
import configparser
import json
import re
import sys
from pathlib import Path

directory = Path(sys.argv[1])
revision = sys.argv[2]
if not re.fullmatch(r"[0-9a-f]{40}", revision):
    raise SystemExit("Expected a complete Git commit SHA")
basename = f"play-{revision}"
entry = directory / f"{basename}.html"
if not entry.is_file():
    raise SystemExit(f"Missing exported game: {entry}")
# Copy the engine's own HTML: its relative JS/WASM/PCK references stay valid
# under /wondertail/, while every game build has different resource URLs.
page = entry.read_text()
for extension in ("js", "wasm", "pck"):
    asset = directory / f"{basename}.{extension}"
    if not asset.is_file() or asset.stat().st_size == 0:
        raise SystemExit(f"Missing or empty exported resource: {asset}")
if basename not in page:
    raise SystemExit("Export HTML does not reference the versioned game")
config_match = re.search(r"const GODOT_CONFIG = (\{[^\n]+\});", page)
if not config_match:
    raise SystemExit("Could not validate Godot's web configuration")
config = json.loads(config_match.group(1))
if config.get("executable") != basename:
    raise SystemExit("Web executable does not match this build")
presets = configparser.ConfigParser()
presets.read(Path(__file__).resolve().parents[1] / "three_d/export_presets.cfg")
web_options = next(presets[s + ".options"] for s in presets.sections()
                   if s.endswith(".options") is False and presets[s].get("platform") == '"Web"')
if web_options.getboolean("variant/thread_support", fallback=True):
    raise SystemExit("Pages requires the non-threaded web template")
if web_options.getboolean("progressive_web_app/enabled", fallback=True):
    raise SystemExit("Preview must not install a stale offline service worker")
if (directory / f"{basename}.service.worker.js").exists():
    raise SystemExit("Preview must not install a stale offline service worker")
(directory / "index.html").write_text(page + f"\n<!-- Wondertail build {revision} -->\n")
(directory / "version.json").write_text(json.dumps({"commit": revision}) + "\n")
(directory / ".nojekyll").touch()
print(f"Web preview validated: {revision}")
