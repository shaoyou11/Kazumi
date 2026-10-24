import importlib.util
import json
from pathlib import Path
import stat
import tempfile
import unittest

spec = importlib.util.spec_from_file_location("build_defines", Path(__file__).with_name("write-build-defines.py"))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class BuildDefinesTests(unittest.TestCase):
    def test_missing_pair_is_rejected_without_disclosing_existing_value(self):
        for values in ({}, {"DANDANAPI_APPID": "test-private-app-id"}, {"DANDANAPI_KEY": "test-private-key"}):
            with self.subTest(keys=list(values)):
                with self.assertRaises(ValueError) as error:
                    module.build_defines(values)
                for value in values.values():
                    self.assertNotIn(value, str(error.exception))

    def test_invalid_credentials_do_not_create_build_file(self):
        output = Path(tempfile.mkdtemp(prefix="kazumit-build-defines-test-")) / "defines.json"
        with self.assertRaises(ValueError):
            module.write_defines({"DANDANAPI_APPID": "test-id", "DANDANAPI_KEY": "line1\nline2"}, output)
        self.assertFalse(output.exists())

    def test_credentials_and_update_configuration_survive_json_round_trip_privately(self):
        output = Path(tempfile.mkdtemp(prefix="kazumit-build-defines-test-")) / "defines.json"
        output.write_text("old configuration")
        output.chmod(0o644)
        values = {"DANDANAPI_APPID": "test-id", "DANDANAPI_KEY": 'test-key-"-\\-测试', "KAZUMIT_UPDATE_URL": "https://example.invalid/update"}
        module.write_defines(values, output)
        self.assertEqual(json.loads(output.read_text()), values)
        self.assertEqual(stat.S_IMODE(output.stat().st_mode), 0o600)
        # Retain isolated test files; never recursively delete directories.


if __name__ == "__main__":
    unittest.main()
