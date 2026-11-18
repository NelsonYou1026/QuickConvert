# Test fixtures

## Browser recording regression

`browser-recording.webm` contains a synthetic one-second, 440 Hz sine wave encoded as mono Opus in a live WebM container. It contains no microphone recording or user data.

It was generated from a 44.1 kHz, signed 16-bit PCM sine-wave WAV with:

```sh
ffmpeg -nostdin -hide_banner -loglevel error -n -i tone.wav \
  -c:a libopus -b:a 32k -f webm -live 1 browser-recording.webm
```

Tests copy it to a Chinese `.wav` filename to reproduce browser recordings whose extension differs from their actual container. Conversion must probe WebM/Opus, produce a decodable MP3 of the expected duration, and preserve the original bytes. The relocated bundled-app smoke test uses the same fixture without requiring an external fixture encoder.

## Native scheduling probe

`priority-probe.c` is a test-only C program compiled for the test process architecture. It records its own Darwin `getpriority` value without a shell or interpreter launching another child. This measures the process started by `ProcessRunner` directly and avoids launcher-dependent scheduling observations in CI. It is not bundled with the application.
