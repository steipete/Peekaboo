"""Analyze a local 16-bit PCM WAV without printing paths or source identifiers.

On macOS convert a private CAF locally with: afconvert -f WAVE -d LEI16 INPUT OUTPUT
Prints one-second tone projections and exact integer-PCM nonzero counts. Recordings
need not leave the test host. A tone projection is a finite synthetic control, not
a universal guarantee about audio source isolation or authorization.
"""
import argparse
import hashlib
import io
import json
import math
import struct
import wave


def analyze(path, frequencies):
    if hasattr(path, "read"):
        encoded = path.read()
    else:
        with open(path, "rb") as source:
            encoded = source.read()
    if len(encoded) < 12 or encoded[:4] != b"RIFF" or encoded[8:12] != b"WAVE":
        raise ValueError("Expected RIFF WAV")
    if struct.unpack_from("<I", encoded, 4)[0] + 8 != len(encoded):
        raise ValueError("Incomplete RIFF container")
    offset = 12
    data_sizes = []
    formats = []
    while offset < len(encoded):
        if offset + 8 > len(encoded):
            raise ValueError("Incomplete chunk header")
        size = struct.unpack_from("<I", encoded, offset + 4)[0]
        end = offset + 8 + size
        if end > len(encoded):
            raise ValueError("Incomplete chunk data")
        if encoded[offset:offset + 4] == b"data":
            data_sizes.append(size)
        if encoded[offset:offset + 4] == b"fmt ":
            if size < 16:
                raise ValueError("Incomplete PCM format")
            formats.append(struct.unpack_from("<HHIIHH", encoded, offset + 8))
        offset = end + (size % 2)
    if offset != len(encoded) or len(data_sizes) != 1 or len(formats) != 1:
        raise ValueError("Unsupported chunk layout")
    tag, channels, rate, byte_rate, alignment, bits = formats[0]
    if (tag != 1 or bits != 16 or channels <= 0 or rate <= 0
            or alignment != channels * 2 or byte_rate != rate * alignment):
        raise ValueError("Expected signed 16-bit PCM format")
    with wave.open(io.BytesIO(encoded), "rb") as stream:
        if stream.getsampwidth() != 2 or stream.getcomptype() != "NONE":
            raise ValueError("Expected uncompressed signed 16-bit PCM WAV")
        channels = stream.getnchannels()
        rate = stream.getframerate()
        frames = stream.getnframes()
        if data_sizes[0] != frames * channels * 2:
            raise ValueError("Incomplete PCM frames")
        raw = stream.readframes(frames)
        if len(raw) != frames * channels * 2:
            raise ValueError("Incomplete PCM frames")
    values = struct.unpack("<" + "h" * (len(raw) // 2), raw)
    mono = values[::channels]
    windows = []
    for begin in range(0, len(mono), rate):
        samples = mono[begin:begin + rate]
        if len(samples) < rate // 4:
            continue
        amplitudes = {}
        for frequency in frequencies:
            real = sum(s * math.cos(2 * math.pi * frequency * n / rate) for n, s in enumerate(samples))
            imag = sum(s * math.sin(2 * math.pi * frequency * n / rate) for n, s in enumerate(samples))
            amplitudes[str(frequency)] = 2 * math.hypot(real, imag) / len(samples)
        windows.append({"begin_seconds": begin / rate, "amplitudes_pcm16": amplitudes})
    return {"pcm_sha256": hashlib.sha256(raw).hexdigest(), "frames": len(mono),
            "channels": channels, "sample_rate": rate,
            "nonzero_pcm16_samples": sum(v != 0 for v in values), "windows": windows}


class PrivateArgumentParser(argparse.ArgumentParser):
    def error(self, message):
        self.exit(2, "Invalid arguments; use --help for usage.\n")


if __name__ == "__main__":
    parser = PrivateArgumentParser(description=__doc__)
    parser.add_argument("wav")
    parser.add_argument("--frequencies", nargs="+", type=int, default=[440, 880, 1320])
    args = parser.parse_args()
    if any(f <= 0 for f in args.frequencies):
        parser.error("Frequencies must be positive")
    try:
        result = analyze(args.wav, args.frequencies)
    except (OSError, ValueError, wave.Error, struct.error, EOFError, ArithmeticError):
        parser.exit(1, "Cannot analyze WAV: unreadable or unsupported input.\n")
    print(json.dumps(result, indent=2))
