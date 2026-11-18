#!/usr/bin/env python3
"""Exercise a relocated app with system-only PATH and strict bundled-only dependency resolution."""
import argparse
import json
import math
import os
import shutil
import struct
import subprocess
import tempfile
import wave
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def smoke(app, architecture=None):
    with tempfile.TemporaryDirectory(prefix="QuickConvert smoke 中文 ") as temporary:
        root = Path(temporary)
        relocated = root / "Quick Convert 離線.app"
        # APFS clone keeps this full-runtime relocation check fast without depending on the build path.
        subprocess.run(["/bin/cp", "-cR", str(app.resolve()), str(relocated)], check=True)
        executable = relocated / "Contents/Helpers/quickconvert"
        prefix = ["/usr/bin/arch", "-" + architecture] if architecture else []
        environment = {"PATH": "/usr/bin:/bin", "HOME": os.path.expanduser("~"), "TMPDIR": str(root), "LC_ALL": "C"}

        def convert(*arguments):
            result = subprocess.run(prefix + [str(executable), "--bundled-only", *arguments], env=environment,
                                    capture_output=True, text=True, timeout=120)
            if result.returncode:
                raise RuntimeError(f"{arguments}: {result.stdout}\n{result.stderr}")
            return result.stdout.strip()

        status = convert("--check")
        if "Self-contained: yes" not in status or str(relocated) not in status:
            raise RuntimeError(f"Relocation/dependency lookup failed: {status}")
        inputs = root / "inputs with spaces & 中文"
        inputs.mkdir()
        pcm = b"".join(struct.pack("<h", int(math.sin(sample * 2 * math.pi * 440 / 44100) * 10000)) for sample in range(8820))
        wav = inputs / "tone.wav"
        with wave.open(str(wav), "wb") as stream:
            stream.setparams((1, 2, 44100, 0, "NONE", "not compressed"))
            stream.writeframes(pcm)
        outputs = []
        for target in ("mp3", "m4a", "flac"):
            output = Path(convert("--to", target, str(wav)))
            outputs.append(str(output.name))
            outputs.append(Path(convert("--to", "wav", str(output))).name)
        # Synthetic sine-wave fixtures exercise the remaining input demuxers without an external encoder.
        for name in ("encoded.aac", "encoded.ogg"):
            source = inputs / name
            shutil.copy2(ROOT / "Tests/QuickConvertCoreTests/Fixtures" / name, source)
            outputs.append(Path(convert("--to", "mp3", str(source))).name)
        # Browser recordings can be WebM/Opus with a misleading .wav suffix.
        browser = inputs / "瀏覽器錄音.wav"
        shutil.copy2(ROOT / "Tests/QuickConvertCoreTests/Fixtures/browser-recording.webm", browser)
        outputs.append(Path(convert("--to", "mp3", str(browser))).name)
        png = inputs / "透明圖片.png"
        def chunk(kind, data):
            return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data))
        png.write_bytes(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", 4, 3, 8, 6, 0, 0, 0))
                        + chunk(b"IDAT", zlib.compress((b"\x00" + bytes([20, 120, 180, 128]) * 4) * 3)) + chunk(b"IEND", b""))
        for target in ("jpg", "webp", "pdf"):
            outputs.append(Path(convert("--to", target, str(png))).name)
        outputs.append(Path(convert("--to", "png", str(inputs / "透明圖片.webp"))).name)
        text = inputs / "notes.md"
        text.write_text("# QuickConvert\n\nOffline PDF · 中文文字\n")
        outputs.append(Path(convert("--to", "pdf", str(text))).name)
        for name in ("document.docx", "workbook.xlsx", "presentation.pptx", "page.html"):
            source = inputs / name
            shutil.copy2(ROOT / "Tests/QuickConvertCoreTests/Fixtures" / name, source)
            output = Path(convert("--to", "pdf", str(source)))
            if not output.read_bytes().startswith(b"%PDF-"):
                raise RuntimeError(f"Invalid PDF: {name}")
            outputs.append(output.name)
        if any(not (inputs / name).is_file() or (inputs / name).stat().st_size == 0 for name in outputs):
            raise RuntimeError("An expected conversion output is missing/empty")
        print(json.dumps({"architecture": architecture or "native", "relocated": True, "PATH": environment["PATH"],
                          "bundled_only": True, "outputs": outputs, "conversions": len(outputs)}, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("app", type=Path)
    parser.add_argument("--architecture", choices=("arm64", "x86_64"))
    args = parser.parse_args()
    smoke(args.app, args.architecture)
