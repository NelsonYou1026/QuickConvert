# Third-party conversion engines

QuickConvert's own source code is MIT licensed. The separate conversion executables and their libraries retain their respective licenses; this notice does not relicense them.

## FFmpeg 9.0.2

This software uses FFmpeg (https://ffmpeg.org/) under LGPL-2.1-or-later. The bundled build disables GPL components, nonfree components, networking and automatic dependency discovery. It includes only the codecs, filters and containers needed for QuickConvert's audio and WebP conversions.

The exact, unmodified FFmpeg source archive, its SHA-256, configuration commands and our build script are included in `Contents/Resources/ThirdPartySources/`. The LGPL license is in `ThirdPartyLicenses/ffmpeg-LICENSE.txt`. To rebuild, obtain this repository at https://github.com/SHENGHUNGYU/QuickConvert and run `python3 scripts/prepare_engines.py`; downloaded archives are checksum verified. Place the included source archives in `build/engine-downloads/` to reuse them. The build script does not modify FFmpeg sources. You may replace or rebuild the standalone FFmpeg executable in `Contents/Helpers/ffmpeg`; modifying a signed app requires re-signing it for local use.

## LAME 3.100

The FFmpeg executable statically links the LAME MP3 encoder (https://lame.sourceforge.io/), LGPL-2.0-or-later. Its unmodified corresponding source archive and build recipe are included in `ThirdPartySources/`; its license is in `ThirdPartyLicenses/lame-LICENSE.txt`. No LAME source changes are applied.

## libwebp 1.6.0

The FFmpeg executable statically links libwebp (https://developers.google.com/speed/webp/), BSD-3-Clause with its accompanying patent grant. The exact source archive is in `ThirdPartySources/`, and `webp-LICENSE.txt` and `webp-PATENTS.txt` are in `ThirdPartyLicenses/`.

## LibreOffice 26.8.3

The architecture-specific, unmodified LibreOffice apps are provided by The Document Foundation (https://www.libreoffice.org/). LibreOffice is made available under MPL-2.0 and incorporates additional third-party components under the licenses documented within each LibreOffice installation. The original license and notice files are preserved in each `Contents/Helpers/LibreOffice-ARCH.app/Contents/Resources/` directory; consult those files for the full applicable notices and copyright attributions.

The corresponding source code is available without charge from The Document Foundation at https://download.documentfoundation.org/libreoffice/src/26.8.3/ (including `libreoffice-26.8.3.1.tar.xz` and its dictionaries, help and translations archives; archive fallback: https://downloadarchive.documentfoundation.org/libreoffice/old/26.8.3.1/src/). Refer to the runtime's version metadata for its exact build identifier. No LibreOffice code is modified. Repackaging under QuickConvert does not imply endorsement by The Document Foundation. LibreOffice and The Document Foundation names and marks belong to their respective owners.

Source and binary download URLs and SHA-256 values are recorded in `Contents/Resources/engines.lock.json`. The macOS system frameworks are provided by Apple with the operating system, rather than distributed by QuickConvert.
