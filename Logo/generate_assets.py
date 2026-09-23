import numpy as np
from PIL import Image
import os

SRC = "logo_base.jpeg"
OUT_DIR = "."

img = Image.open(SRC).convert("RGB")
arr = np.array(img)
h, w, _ = arr.shape
print(f"Source size: {w}x{h}")

# Detect background color by sampling the four corners.
corners = np.array([arr[0,0], arr[0,-1], arr[-1,0], arr[-1,-1]])
bg_color = corners.mean(axis=0)
print(f"Detected background color: {bg_color}")

# Build an alpha mask: pixels close to bg_color -> transparent, else opaque.
dist = np.sqrt(((arr.astype(np.float32) - bg_color) ** 2).sum(axis=2))
# Soft edge: fully transparent below low threshold, fully opaque above high threshold, linear ramp between.
low, high = 12, 40
alpha = np.clip((dist - low) / (high - low), 0, 1)
alpha_u8 = (alpha * 255).astype(np.uint8)

rgba = np.dstack([arr, alpha_u8])
img_rgba = Image.fromarray(rgba, mode="RGBA")
img_rgba.save(os.path.join(OUT_DIR, "logo_full_transparent.png"))
print("Saved logo_full_transparent.png (full wordmark, transparent bg)")

# Find bounding box of opaque content in the LEFT portion of the image (the icon mark),
# by masking out everything right of a cutoff before computing bbox.
cutoff_x = int(w * 0.28)  # icon occupies roughly the left ~28% based on visual inspection
icon_alpha_mask = alpha_u8.copy()
icon_alpha_mask[:, cutoff_x:] = 0
ys, xs = np.where(icon_alpha_mask > 10)
x0, x1 = xs.min(), xs.max()
y0, y1 = ys.min(), ys.max()
print(f"Icon bbox in source: x[{x0},{x1}] y[{y0},{y1}]")

pad = 10
x0 = max(0, x0 - pad); y0 = max(0, y0 - pad)
x1 = min(w, x1 + pad); y1 = min(h, y1 + pad)
icon_crop = img_rgba.crop((x0, y0, x1, y1))
icon_crop.save(os.path.join(OUT_DIR, "icon_crop_transparent.png"))
print(f"Saved icon_crop_transparent.png, size {icon_crop.size}")


def square_pad(im, size, bg=(0, 0, 0, 0)):
    """Resize to fit within size x size, preserving aspect ratio, then pad to a square canvas."""
    im = im.copy()
    im.thumbnail((size, size), Image.LANCZOS)
    canvas = Image.new("RGBA", (size, size), bg)
    ox = (size - im.width) // 2
    oy = (size - im.height) // 2
    canvas.paste(im, (ox, oy), im)
    return canvas


# logo_small: square 120x120, transparent bg
square_pad(icon_crop, 120).save(os.path.join(OUT_DIR, "logo_small.png"))

# mobile_logo: same square icon (per agreed approach)
square_pad(icon_crop, 120).save(os.path.join(OUT_DIR, "mobile_logo.png"))

# large_icon: square >=512, transparent bg
square_pad(icon_crop, 512).save(os.path.join(OUT_DIR, "large_icon.png"))

# favicon: 32x32 PNG, must read at tiny size -> flatten onto white first for max legibility/CDN safety
fav_512 = square_pad(icon_crop, 512)
fav_white_bg = Image.new("RGBA", fav_512.size, (255, 255, 255, 255))
fav_white_bg.paste(fav_512, (0, 0), fav_512)
favicon = fav_white_bg.convert("RGB").resize((32, 32), Image.LANCZOS)
favicon.save(os.path.join(OUT_DIR, "favicon.png"))

# logo: full wordmark, height 120, aspect ratio preserved (source aspect ~5:1, well above 3:1 min)
logo_full = img_rgba.copy()
ratio = 120 / logo_full.height
logo = logo_full.resize((int(logo_full.width * ratio), 120), Image.LANCZOS)
logo.save(os.path.join(OUT_DIR, "logo.png"))
print(f"Saved logo.png, size {logo.size}, aspect ratio {logo.width/logo.height:.2f}:1")

# digest_logo: full wordmark, flattened onto solid white (no SVG, no transparency -- email safety)
digest_bg = Image.new("RGBA", logo.size, (255, 255, 255, 255))
digest_bg.paste(logo, (0, 0), logo)
digest_bg.convert("RGB").save(os.path.join(OUT_DIR, "digest_logo.png"))

print("\nAll assets generated:")
for f in ["logo.png", "logo_small.png", "large_icon.png", "favicon.png", "mobile_logo.png", "digest_logo.png"]:
    p = os.path.join(OUT_DIR, f)
    im = Image.open(p)
    print(f"  {f}: {im.size} {im.mode}")
