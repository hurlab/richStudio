#!/usr/bin/env python3
"""Export or verify a nonsecret allowlisted canonical policy dependency closure."""
import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import tempfile
import unittest
import yaml

SECTIONS = tuple(f".moai/config/sections/{name}.yaml" for name in
                 ("quality", "harness", "gate", "security", "lsp"))
RULE_ROOT = ".moai/config/astgrep-rules"
PROFILE_ROOT = ".moai/config/evaluator-profiles"


def digest(content):
    return hashlib.sha256(content.encode("utf-8")).hexdigest()


def safe_relative(value):
    path = PurePosixPath(value)
    if not isinstance(value, str) or not value or path.is_absolute() or ".." in path.parts or "\\" in value or str(path) != value:
        raise ValueError(f"Unsafe policy path: {value}")
    if value not in SECTIONS and not (value.startswith(RULE_ROOT + "/") and path.suffix in (".yml", ".yaml")) and not (value.startswith(PROFILE_ROOT + "/") and path.suffix == ".md"):
        raise ValueError(f"Policy path outside allowlist: {value}")
    return path


def read_asset(root, relative):
    path = root / safe_relative(relative)
    for parent in (path, *path.parents):
        if parent == root:
            break
        if parent.is_symlink():
            raise ValueError(f"Symlink policy asset: {relative}")
    if not path.is_file() or not path.resolve().is_relative_to(root.resolve()):
        raise ValueError(f"Missing or outside-root policy asset: {relative}")
    return path.read_text(encoding="utf-8")


def closure(content):
    """Recompute dependencies using bundle bytes, never the ambient checkout."""
    required = set(SECTIONS)
    optional = []
    profiles = set()

    def walk(node, enabled=True):
        if isinstance(node, dict):
            enabled = enabled and node.get("enabled", True) is not False
            if enabled:
                for key, value in node.items():
                    if key == "rules_dir":
                        if value != RULE_ROOT:
                            raise ValueError("Enabled rules_dir outside production allowlist")
                        required.add(value + "/sgconfig.yml")
                    if key in ("default_profile", "evaluator_profile"):
                        profiles.add(f"{PROFILE_ROOT}/{value}.md")
                    if key.endswith(("_path", "_file")) and isinstance(value, str) and value.startswith(".moai/config/"):
                        required.add(str(safe_relative(value)))
            for value in node.values():
                walk(value, enabled)
        elif isinstance(node, list):
            for value in node:
                walk(value, enabled)

    for section in SECTIONS:
        if section not in content:
            raise ValueError(f"Missing required policy: {section}")
        walk(yaml.safe_load(content[section]))
    required |= profiles
    config_path = RULE_ROOT + "/sgconfig.yml"
    if config_path in required:
        if config_path not in content:
            raise ValueError("Missing required sgconfig")
        config = yaml.safe_load(content[config_path])
        directories = config.get("ruleDirs")
        if not isinstance(directories, list) or not directories:
            raise ValueError("Empty production ruleDirs")
        for directory in directories:
            prefix = str(safe_relative(f"{RULE_ROOT}/{directory}/placeholder.yml")).rsplit("/", 1)[0] + "/"
            assets = {path for path in content if path.startswith(prefix) and path.endswith((".yml", ".yaml"))}
            if not assets:
                raise ValueError(f"Missing production rules: {directory}")
            required |= assets
        for test_config in config.get("testConfigs", []):
            optional.append({"source": config_path, "reference": test_config["testDir"],
                             "classification": "optional-rule-self-test-fixtures-not-required-by-scan"})
    missing = required - content.keys()
    if missing:
        raise ValueError(f"Missing required dependencies: {sorted(missing)}")
    # Rule YAML may reference external utility/config files. Reject any unhandled
    # path-bearing production dependency rather than silently exporting an open graph.
    for path in required:
        if path.startswith(RULE_ROOT) and path != config_path:
            for document in yaml.safe_load_all(content[path]):
                def check(node):
                    if isinstance(node, dict):
                        for key, value in node.items():
                            if key in ("extends", "config", "ruleFile", "utilsFile"):
                                raise ValueError(f"Unresolved production dependency {path}: {key}={value}")
                            check(value)
                    elif isinstance(node, list):
                        for value in node:
                            check(value)
                check(document)
    return sorted(required), optional


def export(root):
    root = root.resolve(strict=True)
    content = {path: read_asset(root, path) for path in SECTIONS}
    rules = root / RULE_ROOT
    if rules.is_symlink():
        raise ValueError("Symlink rules root")
    # Discover all allowlisted assets before resolving enabled dependencies. Only
    # required members survive the export; unrelated content never enters it.
    for path in sorted(rules.rglob("*")):
        if path.is_symlink():
            raise ValueError("Symlink in production rules")
        if path.is_file() and path.suffix in (".yml", ".yaml"):
            relative = path.relative_to(root).as_posix()
            content[relative] = read_asset(root, relative)
    for profile in sorted((root / PROFILE_ROOT).glob("*.md")):
        relative = profile.relative_to(root).as_posix()
        content[relative] = read_asset(root, relative)
    inventory, optional = closure(content)
    return {"schema_version": 1, "source": "canonical-primary-allowlisted-policy-snapshot",
            "inventory": inventory, "optional_dependencies": optional,
            "dependency_edges": dependency_edges({path: content[path] for path in inventory}),
            "assets": [{"path": path, "sha256": digest(content[path]), "content": content[path]} for path in inventory]}


def dependency_edges(content):
    config_path = RULE_ROOT + "/sgconfig.yml"
    if config_path not in content:
        return []
    config = yaml.safe_load(content[config_path])
    edges = []
    for directory in config["ruleDirs"]:
        prefix = f"{RULE_ROOT}/{directory}/"
        edges.append({"source": config_path, "source_sha256": digest(content[config_path]),
                      "reference": directory,
                      "required_assets": sorted(path for path in content if path.startswith(prefix))})
    return edges


def verify(bundle):
    if bundle.get("schema_version") != 1 or not isinstance(bundle.get("assets"), list):
        raise ValueError("Invalid policy bundle schema")
    content = {}
    for asset in bundle["assets"]:
        path = str(safe_relative(asset["path"]))
        if path in content or digest(asset["content"]) != asset["sha256"]:
            raise ValueError(f"Duplicate or digest mismatch: {path}")
        content[path] = asset["content"]
    inventory, optional = closure(content)
    if dependency_edges(content) != bundle.get("dependency_edges"):
        raise ValueError("Required dependency edge member missing or changed")
    if inventory != bundle["inventory"] or inventory != sorted(content) or optional != bundle["optional_dependencies"]:
        raise ValueError("Policy dependency inventory mismatch")
    return content


def materialize(bundle, destination):
    content = verify(bundle)
    destination.mkdir(parents=True, exist_ok=False)
    for relative, value in content.items():
        path = destination / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(value, encoding="utf-8")
    return destination


class NegativePreparationTests(unittest.TestCase):
    def setUp(self):
        self.bundle = json.loads(Path(__file__).resolve().parents[1].joinpath("docs/quality/workspace-policy-bundle.json").read_text())

    def test_complete_closure_materializes_without_primary_assets(self):
        with tempfile.TemporaryDirectory() as tmp:
            target = Path(tmp) / "isolated"
            materialize(self.bundle, target)
            for asset in self.bundle["assets"]:
                self.assertEqual(digest(read_asset(target, asset["path"])), asset["sha256"])

    def test_missing_rule_fails_even_with_updated_inventory(self):
        rule = next(a for a in self.bundle["assets"] if "/security/" in a["path"])
        self.bundle["assets"].remove(rule)
        self.bundle["inventory"].remove(rule["path"])
        with self.assertRaisesRegex(ValueError, "dependency edge"):
            verify(self.bundle)

    def test_corrupted_digest_fails(self):
        self.bundle["assets"][0]["content"] += "tampered"
        with self.assertRaises(ValueError):
            verify(self.bundle)

    def test_escape_and_symlink_fail(self):
        for path in ("../outside.yml", "/etc/passwd", RULE_ROOT + "/../outside.yml"):
            with self.assertRaises(ValueError):
                safe_relative(path)
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            path = root / SECTIONS[0]
            path.parent.mkdir(parents=True)
            path.symlink_to("/etc/passwd")
            with self.assertRaises(ValueError):
                read_asset(root, SECTIONS[0])

    def test_missing_sgconfig_and_outside_rule_reference_fail(self):
        content = verify(self.bundle)
        del content[RULE_ROOT + "/sgconfig.yml"]
        with self.assertRaises(ValueError):
            closure(content)
        content = verify(self.bundle)
        content[RULE_ROOT + "/sgconfig.yml"] = "ruleDirs: [../../outside]\n"
        with self.assertRaises(ValueError):
            closure(content)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-root", type=Path)
    parser.add_argument("--bundle", type=Path, default=Path(__file__).resolve().parents[1] / "docs/quality/workspace-policy-bundle.json")
    parser.add_argument("--materialize", type=Path)
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        unittest.main(argv=[__file__], exit=True)
    if args.source_root:
        bundle = export(args.source_root)
        verify(bundle)
        args.bundle.write_text(json.dumps(bundle, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    else:
        bundle = json.loads(args.bundle.read_text(encoding="utf-8"))
        verify(bundle)
    if args.materialize:
        materialize(bundle, args.materialize)
    print(json.dumps({"bundle_sha256": hashlib.sha256(args.bundle.read_bytes()).hexdigest(), "required_assets": len(bundle["inventory"]), "inventory": bundle["inventory"], "optional_dependencies": bundle["optional_dependencies"]}, indent=2))


if __name__ == "__main__":
    main()
