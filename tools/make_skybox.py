"""Режет панораму 360° (картинка 2:1) на 6 сторон неба для Roblox.

Запуск:  python3 tools/make_skybox.py panorama.jpg
Результат: assets/sky/Bk.png, Dn.png, Ft.png, Lf.png, Rt.png, Up.png (1024x1024)
Загрузи их в Creator Hub -> Decals и впиши номера в Config.TEXTURES.Sky.
"""

import math
import os
import sys

from PIL import Image

SIZE = 1024
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "sky")

# Направление взгляда для каждого пикселя грани: (вперёд, вправо, вверх) в мире Roblox
FACES = {
    "Ft": lambda a, b: (a, -b, -1.0),
    "Bk": lambda a, b: (-a, -b, 1.0),
    "Rt": lambda a, b: (1.0, -b, a),
    "Lf": lambda a, b: (-1.0, -b, -a),
    "Up": lambda a, b: (a, 1.0, b),
    "Dn": lambda a, b: (a, -1.0, -b),
}


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        return
    pano = Image.open(sys.argv[1]).convert("RGB")
    pw, ph = pano.size
    src = pano.load()
    os.makedirs(OUT, exist_ok=True)
    for name, direction in FACES.items():
        face = Image.new("RGB", (SIZE, SIZE))
        dst = face.load()
        for j in range(SIZE):
            b = 2 * (j + 0.5) / SIZE - 1
            for i in range(SIZE):
                a = 2 * (i + 0.5) / SIZE - 1
                x, y, z = direction(a, b)
                lon = math.atan2(x, -z)
                lat = math.atan2(y, math.hypot(x, z))
                u = (lon / (2 * math.pi) + 0.5) * (pw - 1)
                v = (0.5 - lat / math.pi) * (ph - 1)
                dst[i, j] = src[int(u), int(v)]
        face.save(os.path.join(OUT, name + ".png"))
        print("готово:", name)


if __name__ == "__main__":
    main()
