"""Regenerate synthetic AAC/OGG inputs. Requires a developer FFmpeg with a Vorbis encoder."""
import math
import shutil
import struct
import subprocess
import tempfile
import wave
from pathlib import Path

folder = Path(__file__).resolve().parent
with tempfile.TemporaryDirectory() as temporary:
    wav = Path(temporary) / "tone.wav"
    with wave.open(str(wav), "wb") as stream:
        stream.setparams((1, 2, 44100, 0, "NONE", "not compressed"))
        stream.writeframes(b"".join(struct.pack("<h", int(math.sin(n * 2 * math.pi * 440 / 44100) * 10000)) for n in range(8820)))
    for extension, options in [("aac", ["-c:a", "aac"]), ("ogg", ["-c:a", "vorbis", "-strict", "-2", "-ac", "2"])]:
        subprocess.run([shutil.which("ffmpeg"), "-hide_banner", "-loglevel", "error", "-y", "-i", str(wav),
                        *options, str(folder / ("encoded." + extension))], check=True)
