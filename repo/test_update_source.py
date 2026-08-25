import copy
import json
import unittest
from pathlib import Path

from repo.update_source import apply_source_identity, load_config


class SourceIdentityTest(unittest.TestCase):
    def test_source_and_app_match_mangatan_bundle(self) -> None:
        root = Path(__file__).resolve().parent.parent
        config = load_config(str(root / "repo" / "config.json"))
        with (root / "repo" / "source.json").open(encoding="utf-8") as source:
            data = json.load(source)

        updated = copy.deepcopy(data)
        apply_source_identity(updated, config)

        self.assertEqual(updated, data)
        self.assertEqual(data["identifier"], "com.selxo.mangatan")
        self.assertEqual(
            data["apps"][0]["bundleIdentifier"],
            "com.selxo.mangatan",
        )
        self.assertEqual(data["apps"][0]["name"], "Mangatan")
        self.assertNotIn("kodjodevf/mangayomi", json.dumps(data).lower())


if __name__ == "__main__":
    unittest.main()
