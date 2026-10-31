#!/usr/bin/env python3
"""Build a TWRP ZIP. Optional --boot personalizes it without recompilation."""
import argparse
import hashlib
from pathlib import Path
import stat
import struct
import zipfile

OLD_RELEASE = b'5.4.295-moto-17290-g91c2dab5855a'
NEW_RELEASE = b'5.4.295-Tecnico-Root-V1'
AK3_COMMIT = '41f04bdb4ee30a44e429c2c1131d5e8bb32b15f1'

def field(value):
    if len(value) >= 65:
        raise ValueError('UTS field exceeds 64 bytes')
    return value.ljust(65, b'\0')

OLD_PATTERN = field(b'Linux') + field(b'(none)') + field(OLD_RELEASE)
NEW_PATTERN = field(b'Linux') + field(b'(none)') + field(NEW_RELEASE)

def rename_kernel(kernel):
    if kernel.count(OLD_PATTERN) != 1:
        raise ValueError('Expected exactly one matching init_uts_ns structure')
    offset = kernel.index(OLD_PATTERN) + 130
    renamed = kernel.replace(OLD_PATTERN, NEW_PATTERN)
    assert len(kernel) == len(renamed)
    assert kernel[:offset] == renamed[:offset]
    assert kernel[offset + 65:] == renamed[offset + 65:]
    return renamed

def kernel_from_boot(boot):
    if boot[:8] != b'ANDROID!' or len(boot) < 4096:
        raise ValueError('Not an Android boot image')
    if struct.unpack_from('<I', boot, 40)[0] != 3:
        raise ValueError('Only the validated boot header v3 is supported')
    size = struct.unpack_from('<I', boot, 8)[0]
    if not size or 4096 + size > len(boot):
        raise ValueError('Invalid kernel size')
    kernel = boot[4096:4096 + size]
    if kernel[56:60] != b'ARM\x64':
        raise ValueError('Expected an uncompressed ARM64 kernel')
    return kernel

def build(ak3, output, boot=None):
    root = Path(__file__).resolve().parents[1]
    template = (root / 'installer/anykernel.sh').read_text()
    template = template.replace('@OLD_PATTERN@', OLD_PATTERN.hex()).replace('@NEW_PATTERN@', NEW_PATTERN.hex())
    files = {}
    for relative in ['META-INF/com/google/android/update-binary',
                     'META-INF/com/google/android/updater-script',
                     'tools/ak3-core.sh', 'tools/busybox', 'tools/magiskboot', 'LICENSE']:
        files[relative] = (ak3 / relative).read_bytes()
    files['anykernel.sh'] = template.encode()
    files['LEIA-ME.txt'] = (root / 'installer/LEIA-ME.txt').read_bytes()
    if boot:
        image = rename_kernel(kernel_from_boot(boot.read_bytes()))
        files['Image'] = image
        files['Image.sha256'] = (hashlib.sha256(image).hexdigest() + '  Image\n').encode()
    files['UPSTREAM.txt'] = ('AnyKernel3 https://github.com/osm0sis/AnyKernel3\nCommit: ' + AK3_COMMIT + '\n').encode()
    output.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(output, 'w', zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for name, data in sorted(files.items()):
            info = zipfile.ZipInfo(name, (2026, 1, 1, 0, 0, 0))
            executable = name.startswith('tools/') or name.endswith('update-binary') or name == 'anykernel.sh'
            info.create_system = 3
            info.external_attr = (stat.S_IFREG | (0o755 if executable else 0o644)) << 16
            info.compress_type = zipfile.ZIP_DEFLATED
            archive.writestr(info, data, compresslevel=9)
    with zipfile.ZipFile(output) as archive:
        assert archive.testzip() is None
    print(f'Created {output.name}: {output.stat().st_size} bytes')

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--anykernel', required=True, type=Path)
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--boot', type=Path, help='Private local boot.img; never commit this file')
    args = parser.parse_args()
    build(args.anykernel, args.output, args.boot)
