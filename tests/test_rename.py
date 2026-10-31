import importlib.util
from pathlib import Path
import struct
import unittest

spec = importlib.util.spec_from_file_location('build_zip', Path(__file__).parents[1] / 'scripts/build_zip.py')
b = importlib.util.module_from_spec(spec)
spec.loader.exec_module(b)

class RenameTests(unittest.TestCase):
    def test_only_uts_release_changes(self):
        prefix = b.OLD_RELEASE + b' SMP preempt mod_unload modversions aarch64\0'
        kernel = prefix + b.OLD_PATTERN + b'APATCH_TEST_PAYLOAD\0' + b.OLD_RELEASE
        changed = b.rename_kernel(kernel)
        self.assertEqual(len(changed), len(kernel))
        self.assertEqual(changed[:len(prefix)], prefix)
        self.assertEqual(changed[len(prefix)+len(b.OLD_PATTERN):], kernel[len(prefix)+len(b.OLD_PATTERN):])
        self.assertIn(b.NEW_PATTERN, changed)

    def test_rejects_missing_or_ambiguous_structure(self):
        for kernel in (b'wrong kernel', b.OLD_PATTERN * 2, b.NEW_PATTERN):
            with self.assertRaises(ValueError):
                b.rename_kernel(kernel)

    def test_boot_parser_bounds_and_architecture(self):
        kernel = bytearray(128)
        kernel[56:60] = b'ARM\x64'
        header = bytearray(4096)
        header[:8] = b'ANDROID!'
        struct.pack_into('<I', header, 8, len(kernel))
        struct.pack_into('<I', header, 40, 3)
        self.assertEqual(b.kernel_from_boot(bytes(header + kernel)), kernel)
        for bad in (bytes(header), b'bad', bytes(header + bytearray(128))):
            with self.assertRaises(ValueError):
                b.kernel_from_boot(bad)

if __name__ == '__main__':
    unittest.main()
