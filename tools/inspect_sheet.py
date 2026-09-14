from collections import Counter
from PIL import Image

src = r"C:\Users\guohongzhi\.cursor\projects\d-idea-project-liudian-xiaban\assets\c__Users_guohongzhi_AppData_Roaming_Cursor_User_workspaceStorage_dfeb0a65593a9636ce8899de1c8232bd_images_75a05f2d-7b34-40b6-aea1-7fed4da09875-d1aa96c4-a184-4f70-8b73-79776aa52c23.jpg"
im = Image.open(src)
w, h = im.size
px = im.load()
print("size", w, h)

c = Counter()
for y in range(0, h, 2):
    for x in range(0, w, 2):
        p = px[x, y]
        if p[0] + p[1] + p[2] > 40:
            c[p] += 1
print("non-dark unique", len(c))
print("top", c.most_common(12))

cyans = []
whites = []
for y in range(h):
    for x in range(w):
        r, g, b = px[x, y]
        if b > 120 and g > 140 and r < 90:
            cyans.append((x, y))
        if r > 200 and g > 200 and b > 200:
            whites.append((x, y))
print("cyan", len(cyans), "white", len(whites))
if cyans:
    xs = [p[0] for p in cyans]
    ys = [p[1] for p in cyans]
    print("cyan bbox", min(xs), min(ys), max(xs), max(ys))

# brightness map rows to find card bands
for y in range(0, h, 8):
    s = 0
    for x in range(0, w, 4):
        p = px[x, y]
        s += p[0] + p[1] + p[2]
    print(f"row {y:3d} bright {s}")
