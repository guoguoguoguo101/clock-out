from PIL import Image

src = r"C:\Users\guohongzhi\.cursor\projects\d-idea-project-liudian-xiaban\assets\c__Users_guohongzhi_AppData_Roaming_Cursor_User_workspaceStorage_dfeb0a65593a9636ce8899de1c8232bd_images_75a05f2d-7b34-40b6-aea1-7fed4da09875-d1aa96c4-a184-4f70-8b73-79776aa52c23.jpg"
im = Image.open(src).convert("RGB")
w, h = im.size
px = im.load()

def col_profile(y0, y1):
    vals = []
    for x in range(w):
        s = 0
        for y in range(y0, y1):
            p = px[x, y]
            s += p[0] + p[1] + p[2]
        vals.append(s)
    # find rises
    thresh = max(vals) * 0.08
    inside = False
    spans = []
    start = 0
    for x, v in enumerate(vals):
        if v > thresh and not inside:
            inside = True
            start = x
        if v <= thresh and inside:
            inside = False
            if x - start > 8:
                spans.append((start, x, x - start))
    if inside:
        spans.append((start, w - 1, w - 1 - start))
    return spans, max(vals)

for y0, y1, name in [
    (18, 40, "titles"),
    (48, 300, "top_cards"),
    (80, 260, "top_inner"),
    (318, 470, "mid"),
    (500, 650, "bot"),
]:
    spans, mx = col_profile(y0, y1)
    print(name, "max", mx, "spans", spans)
