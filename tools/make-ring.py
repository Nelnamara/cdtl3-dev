# Writes Media/ring.tga: the 128 x 128 white ring IconFx.lua's Finish effect "Gold ring" grows and fades
# (a ring about 7 percent of the width thick, soft edges). White, so the gold comes from SetVertexColor.
# Standard library only.
#   python tools/make-ring.py
import math
import os
import struct

SIZE = 128
OUTER = 63.0
INNER = 54.0		# 9 px thick of 128

rows = []
for y in range(SIZE):
	row = bytearray()
	for x in range(SIZE):
		# four samples a pixel, so the edges are smooth
		hit = 0
		for sy in (0.25, 0.75):
			for sx in (0.25, 0.75):
				d = math.hypot(x + sx - SIZE / 2, y + sy - SIZE / 2)
				if INNER <= d <= OUTER:
					hit += 1
		row += bytes((255, 255, 255, round(255 * hit / 4)))	# B G R A
	rows.append(bytes(row))

# 32-bit uncompressed true-colour TGA, top-left origin (descriptor 0x28: 8 alpha bits + top-to-bottom)
header = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, SIZE, SIZE, 32, 0x28)
out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "Media", "ring.tga")
with open(out, "wb") as f:
	f.write(header)
	for r in rows:
		f.write(r)
print("wrote", os.path.normpath(out))
