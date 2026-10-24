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
CUSTOM_KEEP = KEEP | {'Death', 'Idle_Gun', 'Idle_Gun_Pointing', 'Idle_Gun_Shoot',
                      'Interact', 'Roll', 'Run_Shoot'}
SELECTION = [
 ('characters/adventurer.glb', None, 'characters/adventurer.glb'),
 ('characters/hooded_adventurer.glb', None, 'characters/hooded_adventurer.glb'),
 ('packs/ultimate_modular_men_glb.zip', 'Farmer.glb', 'characters/farmer.glb'),
 ('packs/ultimate_monsters_glb.zip', 'Mushnub.glb', 'creatures/mushnub.glb'),
 ('packs/ultimate_monsters_glb.zip', 'Cactoro.glb', 'creatures/cactoro.glb'),
 ('packs/ultimate_monsters_glb.zip', 'Yeti.glb', 'creatures/yeti.glb'),
 ('packs/ultimate_monsters_glb.zip', 'Goleling Evolved.glb', 'creatures/goleling.glb'),
 ('packs/ultimate_guns_glb.zip', 'Pistol.glb', 'equipment/pistol.glb'),
]


def compact(raw, allowed=None):
    assert raw[:4] == b'glTF' and struct.unpack_from('<I', raw, 4)[0] == 2
    length, kind = struct.unpack_from('<II', raw, 12)
    assert kind == 0x4E4F534A
    doc = json.loads(raw[20:20+length])
    assert len(doc['buffers']) == 1 and not any('sparse' in a for a in doc['accessors'])
    binary_size, binary_kind = struct.unpack_from('<II', raw, 20+length)
    assert binary_kind == 0x004E4942
    binary = raw[28+length:28+length+binary_size]
    doc['animations'] = [a for a in doc.get('animations', [])
                         if a['name'].split('|')[-1] in (KEEP if allowed is None else allowed)]
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




def external_textures(raw):
    length = struct.unpack_from('<I', raw, 12)[0]
    doc = json.loads(raw[20:20+length])
    size = struct.unpack_from('<I', raw, 20+length)[0]
    binary = raw[28+length:28+length+size]
    shared = OUTPUT / 'shared'
    shared.mkdir(parents=True, exist_ok=True)
    for image in doc.get('images', []):
        if 'bufferView' not in image:
            continue
        view = doc['bufferViews'][image.pop('bufferView')]
        start = view.get('byteOffset', 0)
        data = binary[start:start+view['byteLength']]
        extension = '.jpg' if image.get('mimeType') == 'image/jpeg' else '.png'
        name = hashlib.sha256(data).hexdigest() + extension
        (shared / name).write_bytes(data)
        image['uri'] = '../shared/' + name
        image.pop('mimeType', None)
    encoded = json.dumps(doc, separators=(',', ':')).encode()
    encoded += b' ' * (-len(encoded) % 4)
    return struct.pack('<4sII', b'glTF', 2, 28+len(encoded)+len(binary)) + struct.pack('<II',len(encoded),0x4E4F534A) + encoded + struct.pack('<II',len(binary),0x004E4942) + binary

def isolate(raw, name):
    length = struct.unpack_from('<I', raw, 12)[0]
    doc = json.loads(raw[20:20+length])
    node = dict(next(n for n in doc['nodes'] if n.get('name') == name))
    mesh = doc['meshes'][node['mesh']]
    node['mesh'] = 0
    node.pop('children', None)
    node.pop('skin', None)
    doc['nodes'] = [node]
    doc['meshes'] = [mesh]
    doc['scenes'] = [{'nodes': [0]}]
    doc['scene'] = 0
    doc.pop('skins', None)
    doc.pop('animations', None)
    binary_size = struct.unpack_from('<I', raw, 20+length)[0]
    binary = raw[28+length:28+length+binary_size]
    encoded = json.dumps(doc, separators=(',', ':')).encode()
    encoded += b' ' * (-len(encoded) % 4)
    total = 28 + len(encoded) + len(binary)
    return struct.pack('<4sII', b'glTF', 2, total) + struct.pack('<II',len(encoded),0x4E4F534A) + encoded + struct.pack('<II',len(binary),0x004E4942) + binary


NATURE_SELECTION = [
    ('Trees.glb', 'NormalTree_1', 'tree_oak'),
    ('Trees.glb', 'NormalTree_3', 'tree_oak_b'),
    ('Pine Trees.glb', 'PineTree_1', 'tree_pine'),
    ('Pine Trees.glb', 'PineTree_3', 'tree_pine_b'),
    ('Rocks.glb', 'Rock_1', 'rock'),
    ('Rocks.glb', 'Rock_3', 'rock_b'),
]


def extra_assets(records):
    archive_path = SOURCE / 'packs/Ultimate Stylized Nature Pack-glb.zip'
    with zipfile.ZipFile(archive_path) as archive:
        for member, node, destination in NATURE_SELECTION:
            raw = archive.read(member)
            packed, animations = compact(external_textures(isolate(raw, node)))
            target = OUTPUT / ('nature/' + destination + '.glb')
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(packed)
            records.append({'runtime': str(target.relative_to(ROOT)), 'source': str(archive_path.relative_to(SOURCE)), 'archive_member': member, 'selected_node': node, 'runtime_sha256': hashlib.sha256(packed).hexdigest(), 'runtime_bytes': len(packed), 'source_sha256': hashlib.sha256(raw).hexdigest()})
    raw = (SOURCE / 'characters/hooded_adventurer.glb').read_bytes()
    packed, _ = compact(external_textures(isolate(raw, 'Sword')))
    target = OUTPUT / 'equipment/sword.glb'
    target.write_bytes(packed)
    records.append({'runtime': str(target.relative_to(ROOT)), 'source': 'characters/hooded_adventurer.glb', 'selected_node': 'Sword', 'runtime_sha256': hashlib.sha256(packed).hexdigest(), 'runtime_bytes': len(packed), 'source_sha256': hashlib.sha256(raw).hexdigest()})

def main():
    records = []
    # The custom explorer is a deliberately hand-packed lobby preview. Keep its
    # committed GLB and manifest record intact; the compacting pass is reserved
    # for the reproducible gameplay subset above.
    previous_manifest = ROOT / 'three_d/assets/manifest.json'
    custom_record = None
    if previous_manifest.exists():
        try:
            custom_record = next(
                item for item in json.loads(previous_manifest.read_text())
                if item.get('runtime') == 'three_d/assets/models/characters/custom_explorer.glb'
            )
        except (StopIteration, json.JSONDecodeError):
            custom_record = None
    for source, member, destination in SELECTION:
        if member:
            with zipfile.ZipFile(SOURCE / source) as archive:
                raw = archive.read(member)
        else:
            raw = (SOURCE / source).read_bytes()
        allowed = CUSTOM_KEEP if destination == 'characters/custom_explorer.glb' else None
        packed, animations = compact(external_textures(raw) if destination.startswith("equipment/") else raw, allowed)
        target = OUTPUT / destination
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(packed)
        records.append({'runtime': str(target.relative_to(ROOT)), 'source': source,
                        'archive_member': member, 'source_sha256': hashlib.sha256(raw).hexdigest(),
                        'runtime_sha256': hashlib.sha256(packed).hexdigest(),
                        'source_bytes': len(raw), 'runtime_bytes': len(packed), 'animations': animations})
        print(destination, len(raw), '->', len(packed))
    extra_assets(records)
    if custom_record is not None:
        records.insert(2, custom_record)
    for target in sorted((OUTPUT / 'shared').glob('*')):
        if target.suffix not in ['.png', '.jpg']:
            continue
        raw = target.read_bytes()
        records.append({'runtime': str(target.relative_to(ROOT)), 'runtime_sha256': hashlib.sha256(raw).hexdigest(), 'runtime_bytes': len(raw), 'source': 'shared embedded textures from selected uploaded GLBs'})
    (ROOT / 'three_d/assets/manifest.json').write_text(json.dumps(records, indent=2)+'\n')


if __name__ == '__main__':
    main()

