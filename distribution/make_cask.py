#!/usr/bin/env python3
"""Render a Cask only from a concrete repository, release version, and DMG."""
import argparse
import hashlib
import re
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument("--version", required=True)
parser.add_argument("--dmg", type=Path, required=True)
parser.add_argument("--repository", required=True)
parser.add_argument("--output", type=Path, required=True)
args = parser.parse_args()
if not re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+(?:-[a-zA-Z0-9.]+)?", args.version):
    parser.error("version must be a semantic version")
repository = args.repository.rstrip("/")
if not re.fullmatch(r"https://github\.com/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+", repository):
    parser.error("repository must be an HTTPS GitHub repository URL")
if not args.dmg.is_file():
    parser.error("DMG does not exist")
checksum = hashlib.sha256(args.dmg.read_bytes()).hexdigest()
args.output.parent.mkdir(parents=True, exist_ok=True)
args.output.write_text(f'''cask "quickconvert" do
  version "{args.version}"
  sha256 "{checksum}"

  url "{repository}/releases/download/v#{{version}}/QuickConvert-#{{version}}-universal.dmg"
  name "QuickConvert"
  desc "Offline file conversion from the macOS Finder"
  homepage "{repository}"

  depends_on macos: ">= :ventura"

  app "QuickConvert.app"

  caveats <<~EOS
    Enable QuickConvert Finder in System Settings to use the context menu.
    Audio conversion requires FFmpeg; Office/HTML PDFs require LibreOffice.
    WebP output requires cwebp or FFmpeg with libwebp.
  EOS
end
''')
print(args.output)
