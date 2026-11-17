#!/usr/bin/env python3
"""Build a universal audio/WebP FFmpeg and stage official, architecture-specific Office runtimes.

All downloads are locked by SHA-256. Only developers run this script; the app never downloads tools.
Build requirements: Xcode command-line tools, Python 3, make and pkg-config (build only).
"""
import argparse
import concurrent.futures
import hashlib
import json
import os
import plistlib
import shutil
import subprocess
import tarfile
import tempfile
from pathlib import Path
from urllib.parse import urlparse

ROOT = Path(__file__).resolve().parents[1]
LOCK_PATH = ROOT / "distribution/engines.lock.json"
LOCK = json.loads(LOCK_PATH.read_text())
BUILD = ROOT / "build/engines"
DOWNLOADS = ROOT / "build/engine-downloads"
OUTPUT = ROOT / "vendor/engines"
ARCHITECTURES = ("arm64", "x86_64")


def digest(path):
    result = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            result.update(block)
    return result.hexdigest()


def download(entry):
    DOWNLOADS.mkdir(parents=True, exist_ok=True)
    destination = DOWNLOADS / Path(urlparse(entry["url"]).path).name
    if destination.exists() and digest(destination) == entry["sha256"]:
        return destination
    temporary = destination.with_suffix(destination.suffix + ".download")
    print(f"Downloading {destination.name}", flush=True)
    subprocess.run(["/usr/bin/curl", "--fail", "--location", "--silent", "--show-error",
                    "--retry", "3", "--connect-timeout", "30", "--max-time", "1200",
                    "--output", str(temporary), entry["url"]], check=True)
    if digest(temporary) != entry["sha256"]:
        temporary.unlink()
        raise RuntimeError(f"SHA-256 mismatch: {destination.name}")
    temporary.replace(destination)
    return destination


def run(arguments, *, cwd=None, env=None, log="build"):
    logs = BUILD / "logs"
    logs.mkdir(parents=True, exist_ok=True)
    path = logs / f"{log}.log"
    with path.open("ab") as stream:
        stream.write(("\n" + repr([str(a) for a in arguments]) + "\n").encode())
        result = subprocess.run([str(a) for a in arguments], cwd=cwd, env=env,
                                stdout=stream, stderr=subprocess.STDOUT)
    if result.returncode:
        raise RuntimeError(f"Command failed; see {path}\n{path.read_text(errors='replace')[-4000:]}")


def unpack(archive, destination):
    if destination.exists():
        shutil.rmtree(destination)
    destination.mkdir(parents=True)
    with tarfile.open(archive) as source:
        # The pinned source archives are trusted; still reject traversal and escaping symlinks.
        for member in source.getmembers():
            resolved = (destination / member.name).resolve()
            if not resolved.is_relative_to(destination.resolve()):
                raise RuntimeError("Archive path escapes extraction directory")
            if member.issym() and not (resolved.parent / member.linkname).resolve().is_relative_to(destination.resolve()):
                raise RuntimeError("Archive symlink escapes extraction directory")
        source.extractall(destination)
    return next(p for p in destination.iterdir() if p.is_dir())


def build_ffmpeg(archives):
    sdk = subprocess.check_output(["xcrun", "--show-sdk-path"], text=True).strip()
    compiler = subprocess.check_output(["xcrun", "--find", "clang"], text=True).strip()
    pkgconfig = shutil.which("pkg-config")
    if not pkgconfig:
        raise RuntimeError("pkg-config is a developer build dependency (brew install pkgconf)")
    outputs = []
    recipes = {}
    for arch in ARCHITECTURES:
        work = BUILD / arch
        prefix = work / "prefix"
        marker = work / "source-lock.sha256"
        lock_hash = hashlib.sha256(LOCK_PATH.read_bytes() + Path(__file__).read_bytes()).hexdigest()
        binary = prefix / "bin/ffmpeg"
        if binary.exists() and marker.exists() and marker.read_text() == lock_hash:
            outputs.append(binary)
            recipes[arch] = json.loads((work / "recipe.json").read_text())
            continue
        prefix.mkdir(parents=True, exist_ok=True)
        flags = f"-arch {arch} -isysroot {sdk} -mmacosx-version-min=13.0 -O2"
        environment = dict(os.environ, CC=compiler, CFLAGS=flags, CPPFLAGS=flags, LDFLAGS=flags, SDKROOT=sdk,
                           MACOSX_DEPLOYMENT_TARGET="13.0", LC_ALL="C",
                           PKG_CONFIG_LIBDIR=str(prefix / "lib/pkgconfig"), PKG_CONFIG_PATH="")
        host = "aarch64-apple-darwin" if arch == "arm64" else "x86_64-apple-darwin"
        jobs = str(min(os.cpu_count() or 2, 8))
        print(f"Building native codecs for {arch}; logs in {BUILD / 'logs'}", flush=True)
        recipes[arch] = {}
        for name in ("lame", "webp"):
            source = unpack(archives[name], work / name)
            options = [str(source / "configure"), f"--prefix={prefix}", f"--host={host}",
                       "--enable-static", "--disable-shared", "--disable-dependency-tracking"]
            if name == "lame":
                options += ["--disable-frontend", "--disable-decoder", "--disable-analyzer-hooks", "--disable-nasm"]
            else:
                options += ["--disable-png", "--disable-jpeg", "--disable-tiff", "--disable-gif",
                            "--disable-gl", "--disable-sdl", "--disable-libwebpdemux", "--disable-libwebpmux"]
            recipes[arch][name] = {"configure": options, "CFLAGS": flags}
            run(options, cwd=source, env=environment, log=f"{arch}-{name}")
            run(["make", "-j", jobs], cwd=source, env=environment, log=f"{arch}-{name}")
            run(["make", "install"], cwd=source, env=environment, log=f"{arch}-{name}")
        source = unpack(archives["ffmpeg"], work / "ffmpeg")
        options = [str(source / "configure"), f"--prefix={prefix}", "--target-os=darwin", f"--arch={arch}",
                   "--enable-cross-compile", f"--cc={compiler}", f"--extra-cflags={flags} -I{prefix / 'include'}",
                   f"--extra-ldflags={flags} -L{prefix / 'lib'}", f"--pkg-config={pkgconfig}", "--pkg-config-flags=--static",
                   "--disable-everything", "--disable-autodetect", "--disable-network", "--disable-x86asm",
                   "--disable-gpl", "--disable-nonfree", "--disable-shared", "--enable-static",
                   "--disable-doc", "--disable-debug", "--disable-ffplay", "--disable-ffprobe", "--enable-ffmpeg",
                   "--enable-avcodec", "--enable-avformat", "--enable-avfilter", "--enable-swresample", "--enable-swscale",
                   "--enable-libmp3lame", "--enable-libwebp", "--enable-zlib", "--enable-protocol=file,pipe",
                   "--enable-demuxer=mp3,wav,flac,mov,aac,ogg,image2,png_pipe",
                   "--enable-decoder=mp3,mp3float,flac,aac,vorbis,opus,alac,pcm_s16le,pcm_s24le,pcm_s32le,pcm_f32le,pcm_f64le,pcm_s16be,pcm_s24be,pcm_s32be,pcm_u8,png",
                   "--enable-parser=aac,mpegaudio,flac,vorbis,opus,png",
                   "--enable-encoder=libmp3lame,pcm_s16le,aac,flac,libwebp",
                   "--enable-muxer=mp3,wav,ipod,flac,webp",
                   "--enable-filter=aresample,anull,aformat,format,scale,null"]
        recipes[arch]["ffmpeg"] = {"configure": options, "CFLAGS": flags}
        run(options, cwd=source, env=environment, log=f"{arch}-ffmpeg")
        run(["make", "-j", jobs], cwd=source, env=environment, log=f"{arch}-ffmpeg")
        run(["make", "install"], cwd=source, env=environment, log=f"{arch}-ffmpeg")
        (work / "recipe.json").write_text(json.dumps(recipes[arch], indent=2))
        marker.write_text(lock_hash)
        outputs.append(binary)
    binary = OUTPUT / "bin/ffmpeg"
    binary.parent.mkdir(parents=True, exist_ok=True)
    run(["lipo", "-create", *outputs, "-output", binary])
    run(["lipo", binary, "-verify_arch", *ARCHITECTURES])
    run(["codesign", "--force", "--sign", "-", binary])
    sources = OUTPUT / "Sources"
    licenses = OUTPUT / "Licenses"
    sources.mkdir(parents=True, exist_ok=True)
    licenses.mkdir(parents=True, exist_ok=True)
    for name, archive in archives.items():
        shutil.copy2(archive, sources / archive.name)
        source = next(p for p in (BUILD / "arm64" / name).iterdir() if p.is_dir())
        license_name = {"ffmpeg": "COPYING.LGPLv2.1", "lame": "COPYING", "webp": "COPYING"}[name]
        shutil.copy2(source / license_name, licenses / f"{name}-LICENSE.txt")
        if name == "webp":
            shutil.copy2(source / "PATENTS", licenses / "webp-PATENTS.txt")
    shutil.copy2(__file__, sources / "prepare_engines.py")
    shutil.copy2(LOCK_PATH, sources / LOCK_PATH.name)
    # Build paths are informative, not runtime paths; replacing ROOT makes the receipt shareable.
    receipt = json.dumps(recipes, indent=2).replace(str(ROOT), "${PROJECT_ROOT}")
    (sources / "build-recipes.json").write_text(receipt)
    return binary


def stage_office(arch, image):
    destination = OUTPUT / "office" / arch / "LibreOffice.app"
    marker = destination.parent / "sha256.txt"
    if destination.exists() and marker.exists() and marker.read_text().strip() == LOCK["office"][arch]["sha256"]:
        return
    print(f"Staging LibreOffice {LOCK['office']['version']} for {arch}", flush=True)
    with tempfile.TemporaryDirectory(prefix="quickconvert-office-") as temporary:
        mount = Path(temporary) / "mount"
        mount.mkdir()
        subprocess.run(["hdiutil", "attach", "-nobrowse", "-readonly", "-mountpoint", str(mount), str(image)],
                       check=True, stdout=subprocess.DEVNULL)
        try:
            app = mount / "LibreOffice.app"
            with (app / "Contents/Info.plist").open("rb") as stream:
                info = plistlib.load(stream)
            minimum = tuple(int(part) for part in info.get("LSMinimumSystemVersion", "0").split("."))
            if minimum > (13, 0):
                raise RuntimeError(f"Office runtime requires macOS {minimum}; QuickConvert supports 13.0")
            run(["codesign", "--verify", "--deep", "--strict", app], log=f"{arch}-office")
            if destination.exists():
                shutil.rmtree(destination)
            destination.parent.mkdir(parents=True, exist_ok=True)
            run(["ditto", app, destination], log=f"{arch}-office")
            run(["lipo", destination / "Contents/MacOS/soffice", "-verify_arch", arch], log=f"{arch}-office")
            marker.write_text(LOCK["office"][arch]["sha256"] + "\n")
        finally:
            subprocess.run(["hdiutil", "detach", str(mount)], check=True, stdout=subprocess.DEVNULL)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--media-only", action="store_true", help="Build audio/WebP engines without Office runtimes")
    args = parser.parse_args()
    entries = list(LOCK["sources"].items())
    if not args.media_only:
        entries += [("office-" + arch, LOCK["office"][arch]) for arch in ARCHITECTURES]
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        futures = {name: pool.submit(download, entry) for name, entry in entries}
        archives = {name: future.result() for name, future in futures.items()}
    build_ffmpeg({name: archives[name] for name in LOCK["sources"]})
    if not args.media_only:
        for arch in ARCHITECTURES:
            stage_office(arch, archives["office-" + arch])
    shutil.copy2(LOCK_PATH, OUTPUT / "engines.lock.json")
    print(f"Engines ready: {OUTPUT}", flush=True)


if __name__ == "__main__":
    main()
