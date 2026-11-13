# Writes Media/zone-stripes.tga: the 32 x 32 diagonal stripe tile that IconFx.lua tiles over the burst window
# and refresh zone (looks-icons.html, ".zone": 135 degree stripes, 6 px at alpha .55 then 6 px at .28).
# White, so the zone's colour comes from SetVertexColor. Standard library only.
#   python tools/make-stripes.py
import os
import struct

SIZE = 32
PERIOD = 16		# stripes repeat every 16 along x+y, so the 32 px tile repeats without a seam: 8 bright, 8 dim
BRIGHT, DIM = round(0.55 * 255), round(0.28 * 255)

rows = []
for y in range(SIZE):
	row = bytearray()
	for x in range(SIZE):
		a = BRIGHT if ((x + y) % PERIOD) < PERIOD // 2 else DIM
		row += bytes((255, 255, 255, a))	# B G R A
	rows.append(bytes(row))

# 32-bit uncompressed true-colour TGA, top-left origin (descriptor 0x28: 8 alpha bits + top-to-bottom)
header = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, SIZE, SIZE, 32, 0x28)
out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "Media", "zone-stripes.tga")
with open(out, "wb") as f:
	f.write(header)
	for r in rows:
		f.write(r)
print("wrote", os.path.normpath(out))
