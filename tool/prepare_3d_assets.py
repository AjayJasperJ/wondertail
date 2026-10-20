"""Rebuild a compact, reproducible runtime subset from the preserved user uploads."""
from pathlib import Path
import hashlib
import json
import struct
import zipfile

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'source_assets'
OUTPUT = ROOT / 'three_d/assets/models'
KEEP = {'Idle', 'Idle_Neutral', 'Walk', 'Run', 'Sword_Slash', 'Gun_Shoot', 'HitRecieve',
        'Flying_Idle', 'Fast_Flying', 'Bite_Front', 'Headbutt', 'HitReact', 'Punch'}
SELECTION = [
 ('characters/adventurer.glb', None, 'characters/adventurer.glb'),
 ('characters/hooded_adventurer.glb', None, 'characters/hooded_adventurer.glb'),
 ('packs/ultimate_modular_men_glb.zip', 'Farmer.glb', 'characters/farmer.glb'),
 ('packs/ultimate_monsters_glb.zip', 'Mushnub.glb', 'creatures/mushnub.glb'),
 ('packs/ultimate_monsters_glb.zip', 'Cactoro.glb', 'creatures/cactoro.glb'),
 ('packs/ultimate_monsters_glb.zip', 'Yeti.glb', 'creatures/yeti.glb'),
 ('packs/ultimate_monsters_glb.zip', 'Goleling Evolved.glb', 'creatures/goleling.glb'),
]


def compact(raw):
    assert raw[:4] == b'glTF' and struct.unpack_from('<I', raw, 4)[0] == 2
    length, kind = struct.unpack_from('<II', raw, 12)
    assert kind == 0x4E4F534A
    doc = json.loads(raw[20:20+length])
    assert len(doc['buffers']) == 1 and not any('sparse' in a for a in doc['accessors'])
    binary_size, binary_kind = struct.unpack_from('<II', raw, 20+length)
    assert binary_kind == 0x004E4942
    binary = raw[28+length:28+length+binary_size]
    doc['animations'] = [a for a in doc.get('animations', []) if a['name'].split('|')[-1] in KEEP]
    used = set()
    for mesh in doc['meshes']:
        for primitive in mesh['primitives']:
            used.update(primitive['attributes'].values())
            if 'indices' in primitive:
                used.add(primitive['indices'])
            for target in primitive.get('targets', []):
                used.update(target.values())
    for skin in doc.get('skins', []):
        if 'inverseBindMatrices' in skin:
            used.add(skin['inverseBindMatrices'])
    for animation in doc['animations']:
        for sampler in animation['samplers']:
            used.update([sampler['input'], sampler['output']])
    access_map = {old: new for new, old in enumerate(sorted(used))}
    accessors = [doc['accessors'][i] for i in sorted(used)]
    views = {a['bufferView'] for a in accessors if 'bufferView' in a}
    views.update(image['bufferView'] for image in doc.get('images', []) if 'bufferView' in image)
    view_map = {old: new for new, old in enumerate(sorted(views))}
    packed = bytearray()
    new_views = []
    for i in sorted(views):
        view = dict(doc['bufferViews'][i])
        packed.extend(b'\0' * (-len(packed) % 4))
        start = view.get('byteOffset', 0)
        view['byteOffset'] = len(packed)
        packed.extend(binary[start:start+view['byteLength']])
        new_views.append(view)
    for accessor in accessors:
        if 'bufferView' in accessor:
            accessor['bufferView'] = view_map[accessor['bufferView']]
    for mesh in doc['meshes']:
        for primitive in mesh['primitives']:
            primitive['attributes'] = {k: access_map[v] for k,v in primitive['attributes'].items()}
            if 'indices' in primitive:
                primitive['indices'] = access_map[primitive['indices']]
            for target in primitive.get('targets', []):
                target.update({k: access_map[v] for k,v in target.items()})
    for skin in doc.get('skins', []):
        if 'inverseBindMatrices' in skin:
            skin['inverseBindMatrices'] = access_map[skin['inverseBindMatrices']]
    for animation in doc['animations']:
        for sampler in animation['samplers']:
            for key in ['input', 'output']:
                sampler[key] = access_map[sampler[key]]
    for image in doc.get('images', []):
        if 'bufferView' in image:
            image['bufferView'] = view_map[image['bufferView']]
    doc['accessors'] = accessors
    doc['bufferViews'] = new_views
    doc['buffers'] = [{'byteLength': len(packed)}]
    encoded = json.dumps(doc, separators=(',', ':')).encode()
    encoded += b' ' * (-len(encoded) % 4)
    packed.extend(b'\0' * (-len(packed) % 4))
    total = 12 + 8 + len(encoded) + 8 + len(packed)
    result = struct.pack('<4sII', b'glTF', 2, total) + struct.pack('<II',len(encoded),0x4E4F534A) + encoded + struct.pack('<II',len(packed),0x004E4942) + packed
    return result, [a['name'] for a in doc['animations']]


def main():
    records = []
    for source, member, destination in SELECTION:
        if member:
            with zipfile.ZipFile(SOURCE / source) as archive:
                raw = archive.read(member)
        else:
            raw = (SOURCE / source).read_bytes()
        packed, animations = compact(raw)
        target = OUTPUT / destination
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(packed)
        records.append({'runtime': str(target.relative_to(ROOT)), 'source': source,
                        'archive_member': member, 'source_sha256': hashlib.sha256(raw).hexdigest(),
                        'runtime_sha256': hashlib.sha256(packed).hexdigest(),
                        'source_bytes': len(raw), 'runtime_bytes': len(packed), 'animations': animations})
        print(destination, len(raw), '->', len(packed))
    (ROOT / 'three_d/assets/manifest.json').write_text(json.dumps(records, indent=2)+'\n')


if __name__ == '__main__':
    main()
