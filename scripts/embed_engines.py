#!/usr/bin/env python3
"""Copy prepared, self-contained runtimes into an app before its final code signature."""
import argparse
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def embed(app, engines):
    helpers = app / "Contents/Helpers"
    resources = app / "Contents/Resources"
    required = [engines / "bin/ffmpeg", engines / "Licenses", engines / "Sources", engines / "engines.lock.json"]
    required += [engines / "office" / arch / "LibreOffice.app/Contents/MacOS/soffice" for arch in ("arm64", "x86_64")]
    for item in required:
        if not item.exists():
            raise RuntimeError(f"Missing runtime: {item}. Run python3 scripts/prepare_engines.py first.")
    helpers.mkdir(parents=True, exist_ok=True)
    resources.mkdir(parents=True, exist_ok=True)
    shutil.copy2(engines / "bin/ffmpeg", helpers / "ffmpeg")
    for arch in ("arm64", "x86_64"):
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
    shutil.copy2(ROOT / "distribution/THIRD-PARTY-NOTICES.md", resources / "ThirdPartyLicenses/NOTICES.md")
    print(f"Bundled engines: {app}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("app", type=Path)
    parser.add_argument("--engines", type=Path, default=ROOT / "vendor/engines")
    args = parser.parse_args()
    embed(args.app.resolve(), args.engines.resolve())
