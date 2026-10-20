"""Prevent a 3D package/version from overwriting the Flutter application."""
from pathlib import Path
import re

root = Path(__file__).resolve().parents[2]
project = (root / 'three_d/project.godot').read_text()
presets = (root / 'three_d/export_presets.cfg').read_text()
version = re.search(r'config/version="([^"]+)"', project)[1]
assert f'version/name="{version}"' in presets
assert 'package/unique_name="com.ajayjasper.wondertail3d"' in presets
assert 'permissions/internet=false' in presets
assert f'## [3D {version}]' in (root / 'CHANGELOG.md').read_text()
assert f'3D version: {version}' in (root / 'README.md').read_text()
assert 'window/handheld/orientation=0' in project
print(f'3D release documentation and isolated Android package match {version}.')
