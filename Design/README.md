# App icon

- `AppIcon.svg`: the artwork (white waveform on black). Its `rx` rounded rect is only a preview shape.
- `mask-1024.png`: upstream's 1024 icon, used only for its alpha channel (Apple's continuous-corner squircle).
  macOS 26+ shrinks icons whose shape doesn't match the template and puts them on a grey plate.

Regenerate:

```sh
# 1. render AppIcon.svg to a transparent 1024 PNG (e.g. headless Chrome, --default-background-color=00000000)
# 2. take colour from the render, alpha from the mask
swift Design/compose.swift Design/mask-1024.png render-1024.png out-1024.png
# 3. downscale into the asset catalog
for s in 512 256 128 64 32 16; do sips -z $s $s out-1024.png --out VoiceInk/Assets.xcassets/AppIcon.appiconset/$s-mac.png; done
cp out-1024.png VoiceInk/Assets.xcassets/AppIcon.appiconset/1024-mac.png
```
