"""Convert XSim P3 screen captures to PNG, using only the standard library."""
from pathlib import Path
import struct
import zlib


def chunk(kind, data):
    return struct.pack('>I', len(data)) + kind + data + struct.pack('>I', zlib.crc32(kind+data))


def convert(path):
    fields = path.read_text(encoding='ascii').split()
    if fields[0] != 'P3' or fields[3] != '255':
        raise ValueError(f'Unsupported preview format: {path}')
    w, h = map(int, fields[1:3])
    pixels = bytes(map(int, fields[4:]))
    if len(pixels) != w*h*3:
        raise ValueError('Incomplete framebuffer capture')
    scan = b''.join(b'\x00'+pixels[y*w*3:(y+1)*w*3] for y in range(h))
    png = b'\x89PNG\r\n\x1a\n'
    png += chunk(b'IHDR', struct.pack('>IIBBBBB', w,h,8,2,0,0,0))
    png += chunk(b'IDAT', zlib.compress(scan)) + chunk(b'IEND', b'')
    path.with_suffix('.png').write_bytes(png)
    print(path.with_suffix('.png'))


if __name__ == '__main__':
    root=Path(__file__).resolve().parents[1]
    for name in ('display_neutral.ppm','display_happy.ppm'):
        convert(root/'results'/name)
