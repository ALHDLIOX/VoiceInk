# App icon

- `AppIcon.svg`: the artwork (one white brush-pen stroke on black). Its `rx` rounded rect is only a preview shape.
- `stroke.py`: generates `AppIcon.svg` and `MenuBarIcon.svg`. The stroke is fitted to measurements of a
  reference stroke (`stroke-cols.txt`); `AMP` sets how tall the wave is. Run `python3 Design/stroke.py`.
- `mask-1024.png`: upstream's 1024 icon, used only for its alpha channel (Apple's continuous-corner squircle).
  macOS 26+ shrinks icons whose shape doesn't match the template and puts them on a grey plate.
- Keep the PNGs non-grayscale: if every pixel is grey, actool stores the icon as Monochrome in
  Assets.car and macOS 26+ puts it on the grey plate even with the right shape. `compose.swift`
  adds 1/255 to the blue channel for that reason. Check with
  `xcrun assetutil --info <app>/Contents/Resources/Assets.car | grep ColorModel` (want RGB).

Regenerate:

```sh
# 1. render AppIcon.svg to a transparent 1024 PNG (e.g. headless Chrome, --default-background-color=00000000)
# 2. take colour from the render, alpha from the mask
swift Design/compose.swift Design/mask-1024.png render-1024.png out-1024.png
# 3. downscale into the asset catalog
for s in 512 256 128 64 32 16; do sips -z $s $s out-1024.png --out VoiceInk/Assets.xcassets/AppIcon.appiconset/$s-mac.png; done
cp out-1024.png VoiceInk/Assets.xcassets/AppIcon.appiconset/1024-mac.png
```

- `MenuBarIcon.svg`: the status-bar template image (same stroke, 1.3× heavier, no background). Render to a transparent
  750×750 PNG into `VoiceInk/Assets.xcassets/menuBarIcon.imageset/menuBarIcon.png`; only alpha matters.
