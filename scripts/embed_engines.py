#!/usr/bin/env python3
"""Copy prepared, self-contained runtimes into an app before its final code signature."""
import argparse
import json
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def embed(app, engines, architecture):
    helpers = app / "Contents/Helpers"
    resources = app / "Contents/Resources"
    required = [engines / "bin" / architecture / "ffmpeg", engines / "Licenses", engines / "Sources", engines / "engines.lock.json",
                engines / "office" / architecture / "LibreOffice.app/Contents/MacOS/soffice"]
    for item in required:
        if not item.exists():
            raise RuntimeError(f"Missing runtime: {item}. Run python3 scripts/prepare_engines.py first.")
    helpers.mkdir(parents=True, exist_ok=True)
    resources.mkdir(parents=True, exist_ok=True)
    shutil.copy2(engines / "bin" / architecture / "ffmpeg", helpers / "ffmpeg")
    for previous in helpers.glob("LibreOffice-*.app"):
        shutil.rmtree(previous)
    for arch in (architecture,):
        destination = helpers / f"LibreOffice-{arch}.app"
        if destination.exists():
            shutil.rmtree(destination)
        subprocess.run(["ditto", str(engines / "office" / arch / "LibreOffice.app"), str(destination)], check=True)
    for name in ("Licenses", "Sources"):
        destination = resources / f"ThirdParty{name}"
        if destination.exists():
            shutil.rmtree(destination)
        shutil.copytree(engines / name, destination)
    shutil.copy2(engines / "engines.lock.json", resources / "engines.lock.json")
    (resources / "runtime-manifest.json").write_text(json.dumps({"architecture": architecture, "formatVersion": 1}, indent=2) + "\n")
    shutil.copy2(ROOT / "distribution/THIRD-PARTY-NOTICES.md", resources / "ThirdPartyLicenses/NOTICES.md")
    print(f"Bundled engines: {app}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("app", type=Path)
    parser.add_argument("--engines", type=Path, default=ROOT / "vendor/engines")
    parser.add_argument("--architecture", choices=("arm64", "x86_64"), required=True)
    args = parser.parse_args()
    embed(args.app.resolve(), args.engines.resolve(), args.architecture)
