#!/usr/bin/env python3
"""Reject incomplete runtimes, external dylib paths, escaping links and unsigned payloads."""
import argparse
import json
import os
import plistlib
import re
import subprocess
from pathlib import Path

MACHO_MAGICS = {bytes.fromhex(value) for value in ("cffaedfe", "cefaedfe", "feedfacf", "feedface", "cafebabe", "bebafeca", "cafebabf", "bfbafeca")}
# The pinned, unmodified upstream Office app has this unresolved load path in its optional
# Firebird database intl plugin. Base/database operations are outside QuickConvert's format matrix.
# Keep this exact exception visible; do not treat arbitrary missing Office libraries as acceptable.
OPTIONAL_VENDOR_LOADS = {
    ("Contents/Frameworks/intl/libfbintl.dylib", "@rpath/lib/libfbclient.dylib")
}


def run(arguments, **kwargs):
    return subprocess.check_output([str(value) for value in arguments], text=True, stderr=subprocess.STDOUT, **kwargs)


def verify(app, architecture=None):
    app = app.resolve()
    helpers = app / "Contents/Helpers"
    resources = app / "Contents/Resources"
    manifest = json.loads((resources / "runtime-manifest.json").read_text())
    declared = manifest["architecture"]
    if declared not in ("arm64", "x86_64") or (architecture is not None and declared != architecture):
        raise RuntimeError(f"Runtime architecture mismatch: {declared} (expected {architecture})")
    architecture = declared
    extension = app / "Contents/PlugIns/QuickConvertFinder.appex"
    entitlements_data = subprocess.check_output(["codesign", "--display", "--entitlements", "-", "--xml", str(extension)], stderr=subprocess.PIPE)
    try:
        entitlements = plistlib.loads(entitlements_data)
    except plistlib.InvalidFileException as error:
        raise RuntimeError("Finder extension has no readable entitlements; macOS will refuse registration") from error
    if entitlements.get("com.apple.security.app-sandbox") is not True:
        raise RuntimeError("Finder extension lacks its required App Sandbox entitlement; macOS will refuse registration")
    for binary in (helpers / "ffmpeg", helpers / "quickconvert", app / "Contents/MacOS/QuickConvert",
                   app / "Contents/PlugIns/QuickConvertFinder.appex/Contents/MacOS/QuickConvertFinder"):
        if not binary.is_file() or not os.access(binary, os.X_OK):
            raise RuntimeError(f"Missing executable: {binary}")
        if run(["lipo", "-archs", binary]).strip().split() != [architecture]:
            raise RuntimeError(f"Expected a thin {architecture} executable: {binary}")
    expected_office = f"LibreOffice-{architecture}.app"
    if sorted(path.name for path in helpers.glob("LibreOffice-*.app")) != [expected_office]:
        raise RuntimeError("Package must contain exactly one matching Office runtime")
    for arch in (architecture,):
        office = helpers / f"LibreOffice-{arch}.app"
        run(["lipo", office / "Contents/MacOS/soffice", "-verify_arch", arch])
        run(["codesign", "--verify", "--deep", "--strict", office])
    lock = json.loads((resources / "engines.lock.json").read_text())
    for entry in lock["sources"].values():
        archive = resources / "ThirdPartySources" / Path(entry["url"]).name
        from prepare_engines import digest
        if digest(archive) != entry["sha256"]:
            raise RuntimeError(f"Missing/mismatched corresponding source: {archive}")
    for name in ("ffmpeg-LICENSE.txt", "lame-LICENSE.txt", "webp-LICENSE.txt", "webp-PATENTS.txt", "NOTICES.md"):
        if not (resources / "ThirdPartyLicenses" / name).is_file():
            raise RuntimeError(f"Missing license: {name}")
    paths = list(app.rglob("*"))
    real_paths = {str(path.resolve()) for path in paths if path.is_file()}
    checked = set()
    optional_vendor_loads = []
    for path in paths:
        if path.is_symlink() and not path.resolve().is_relative_to(app):
            raise RuntimeError(f"Symlink escapes app: {path}")
        if not path.is_file() or path.resolve() in checked:
            continue
        checked.add(path.resolve())
        with path.open("rb") as stream:
            header = stream.read(8)
            magic = header[:4]
            if magic not in MACHO_MAGICS:
                continue
            if magic in {bytes.fromhex(value) for value in ("cafebabe", "bebafeca", "cafebabf", "bfbafeca")}:
                count = int.from_bytes(header[4:8], "big" if magic[:1] == b"\xca" else "little")
                # Java .class files share CAFEBABE but have a class version where Mach-O has nfat_arch.
                if not 0 < count <= 8:
                    continue
        # A dylib's own LC_ID_DYLIB is an identifier, not a library dependency.
        # LibreOffice retains build placeholders in some IDs while all load commands use relative paths.
        own_ids = {line.strip() for line in run(["otool", "-D", path]).splitlines() if line and not line.endswith(":")}
        for line in run(["otool", "-L", path]).splitlines():
            if not line.startswith("\t"):
                continue
            dependency = line.strip().split(" (compatibility version", 1)[0]
            if dependency in own_ids:
                continue
            office_owner = next((parent for parent in path.parents if parent.name.startswith("LibreOffice-") and parent.suffix == ".app"), None)
            if office_owner and (str(path.relative_to(office_owner)), dependency) in OPTIONAL_VENDOR_LOADS:
                optional_vendor_loads.append(str(path.relative_to(app)) + ": " + dependency)
                continue
            if dependency.startswith(("/System/Library/", "/usr/lib/")):
                continue
            if dependency.startswith("@loader_path/"):
                resolved = (path.parent / dependency[len("@loader_path/"):]).resolve()
                if resolved.is_relative_to(app) and resolved.exists():
                    continue
            elif dependency.startswith("@executable_path/"):
                owner = next(parent for parent in path.parents if parent.suffix == ".app")
                for executable_directory in (path.parent, owner / "Contents/MacOS"):
                    resolved = (executable_directory / dependency[len("@executable_path/"):]).resolve()
                    if resolved.is_relative_to(app) and resolved.exists():
                        break
                else:
                    raise RuntimeError(f"Unresolved {dependency} in {path}")
                continue
            elif dependency.startswith("@rpath/"):
                suffix = dependency[len("@rpath/"):]
                # Swift overlays are supplied by supported macOS versions, often only in the dyld cache.
                if suffix.startswith("libswift") or any(value.endswith("/" + suffix) for value in real_paths):
                    continue
            raise RuntimeError(f"External or unresolved library {dependency} in {path}")
    environment = {"PATH": "/usr/bin:/bin", "HOME": os.path.expanduser("~"), "LC_ALL": "C"}
    protocols = run([helpers / "ffmpeg", "-hide_banner", "-protocols"], env=environment)
    enabled = {match[1] for line in protocols.splitlines() if (match := re.fullmatch(r"\s+([a-z][a-z0-9_]+)\s*", line))}
    if enabled != {"file", "pipe"}:
        raise RuntimeError(f"Unexpected FFmpeg protocols: {enabled}")
    encoders = run([helpers / "ffmpeg", "-hide_banner", "-encoders"], env=environment)
    for encoder in ("libmp3lame", "aac", "flac", "pcm_s16le", "libwebp"):
        if not re.search(r"\b" + encoder + r"\b", encoders):
            raise RuntimeError(f"Missing encoder: {encoder}")
    demuxers = run([helpers / "ffmpeg", "-hide_banner", "-demuxers"], env=environment)
    if not re.search(r"\bmatroska\b", demuxers):
        raise RuntimeError("Missing WebM/Matroska demuxer for browser recordings with .wav filenames")
    decoders = run([helpers / "ffmpeg", "-hide_banner", "-decoders"], env=environment)
    if not re.search(r"\bopus\b", decoders):
        raise RuntimeError("Missing Opus decoder for browser recordings")
    configuration = run([helpers / "ffmpeg", "-hide_banner", "-buildconf"], env=environment)
    if "--enable-gpl" in configuration or "--enable-nonfree" in configuration:
        raise RuntimeError("Unexpected GPL/nonfree FFmpeg build")
    status = run([helpers / "quickconvert", "--bundled-only", "--check"], env=environment)
    if "Self-contained: yes" not in status:
        raise RuntimeError(status)
    run(["codesign", "--verify", "--deep", "--strict", app])
    print(f"Verified self-contained bundle: {app}\n{status.strip()}")
    for item in optional_vendor_loads:
        print(f"Upstream optional database plugin (outside supported conversions): {item}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("app", type=Path)
    parser.add_argument("--architecture", choices=("arm64", "x86_64"))
    args = parser.parse_args()
    verify(args.app, args.architecture)
