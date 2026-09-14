from PIL import Image, ImageDraw, ImageFilter
import os

src = r"C:\Users\guohongzhi\.cursor\projects\d-idea-project-liudian-xiaban\assets\c__Users_guohongzhi_AppData_Roaming_Cursor_User_workspaceStorage_dfeb0a65593a9636ce8899de1c8232bd_images_75a05f2d-7b34-40b6-aea1-7fed4da09875-d1aa96c4-a184-4f70-8b73-79776aa52c23.jpg"
im = Image.open(src).convert("RGB")
w, h = im.size
px = im.load()
mask = Image.new("L", (w, h), 0)
mp = mask.load()
for y in range(h):
    for x in range(w):
        r, g, b = px[x, y]
        v = (r + g + b) / 3
        if 8 <= v <= 28:
            mp[x, y] = 255
mask = mask.filter(ImageFilter.MedianFilter(5))
# find bounding boxes of cards via scan
visited = [[False] * w for _ in range(h)]
mp = mask.load()
boxes = []

def flood(sx, sy):
    stack = [(sx, sy)]
    visited[sy][sx] = True
    minx = maxx = sx
    miny = maxy = sy
    n = 0
    while stack:
        x, y = stack.pop()
        n += 1
        if x < minx: minx = x
        if x > maxx: maxx = x
        if y < miny: miny = y
        if y > maxy: maxy = y
        for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if 0 <= nx < w and 0 <= ny < h and not visited[ny][nx] and mp[nx, ny] > 128:
                visited[ny][nx] = True
                stack.append((nx, ny))
    return minx, miny, maxx, maxy, n

for y in range(0, h, 2):
    for x in range(0, w, 2):
        if mp[x, y] > 128 and not visited[y][x]:
            box = flood(x, y)
            if box[4] > 800:
                boxes.append(box)

boxes.sort(key=lambda b: (b[1] // 20, b[0]))
print("cards", len(boxes))
for i, b in enumerate(boxes):
    print(i, b[0], b[1], b[2], b[3], "w", b[2]-b[0], "h", b[3]-b[1], "n", b[4])
