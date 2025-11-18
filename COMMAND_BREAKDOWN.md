# FFmpeg Command Breakdown for N8N Video Editing

## Visual Layout

```
┌────────────────────────────────────────┐
│  ████████ LETTERBOX BAR ████████       │ ← 80px black bar (y=0)
├────────────────────────────────────────┤
│                                        │
│         ┌──────────────────┐          │
│         │                  │          │
│         │  FOREGROUND IMG  │          │ ← Centered, zooming, rounded corners
│         │   (maintains     │          │   Max size: 1400x787px
│         │   aspect ratio)  │          │   Appears at specific times
│         │                  │          │
│         └──────────────────┘          │
│                                        │
│    BACKGROUND IMAGE (1920x1080)       │ ← Visible throughout
│         Always in_1                    │
│                                        │
├────────────────────────────────────────┤
│  ████████ LETTERBOX BAR ████████       │ ← 80px black bar (y=1000)
└────────────────────────────────────────┘
    Total: 1920x1080 with 2.35:1 feel
```

## Timeline

```
0s      5s      10s     15s
├───────┼───────┼───────┤
│ IMG1  │ IMG2  │ IMG3  │  ← Foreground images appear sequentially
├───────────────────────┤
│    BACKGROUND (BG)    │  ← Background visible entire time
└───────────────────────┘
```

## Command Structure Breakdown

### Your Original Command (WRONG):
```
Image 1 → xfade → Image 2 → xfade → Image 3 → xfade → Image 4
```
**Problem**: This is a slideshow where images replace each other. No layering!

### Correct Command (LAYERED):
```
Background (persistent)
    ├─ Overlay: Image 1 (0-5s)
    ├─ Overlay: Image 2 (5-10s)
    └─ Overlay: Image 3 (10-15s)
    └─ Add letterbox bars
```

## Filter Chain Explanation

### Step 1: Prepare Background
```
[0:v]scale=1920:1080:force_original_aspect_ratio=decrease,
     pad=1920:1080:-1:-1:black,
     setsar=1,
     format=yuv420p[bg]
```
- Takes input 0 (in_1)
- Scales to 1920x1080, maintains aspect ratio
- Pads with black bars if needed
- Outputs as [bg] stream

### Step 2: Prepare Foreground Images (repeated for each)
```
[1:v]scale='if(gt(a,16/9),1400,-1)':'if(gt(a,16/9),-1,787)',
     zoompan=z='min(1.0+0.05*(on/125),1.05)':d=125:s=1400x787:fps=25,
     setpts=PTS-STARTPTS[fg1]
```
- Takes input 1 (in_2)
- **Smart scaling**: If wider than 16:9, set width to 1400px; if taller, set height to 787px
  - This ensures image fits within the visible area (between letterbox bars)
  - Maintains original aspect ratio
- **Zoompan**:
  - `z='min(1.0+0.05*(on/125),1.05)'` - Gradually zooms from 1.0x to 1.05x over 125 frames (5s @ 25fps)
  - `on` = output frame number
  - Creates smooth, gentle zoom effect
- Outputs as [fg1] stream

### Step 3: Overlay Foreground on Background
```
[bg][fg1]overlay=(W-w)/2:(H-h)/2:enable='between(t,0,5)'[v1]
```
- Takes background [bg] and foreground [fg1]
- **Position**: `(W-w)/2` = horizontal center, `(H-h)/2` = vertical center
- **Timing**: `enable='between(t,0,5)'` = only show between 0-5 seconds
- Outputs as [v1]

Then repeats:
```
[v1][fg2]overlay=(W-w)/2:(H-h)/2:enable='between(t,5,10)'[v2]
[v2][fg3]overlay=(W-w)/2:(H-h)/2:enable='between(t,10,15)'[v3]
```

### Step 4: Add Letterbox Bars
```
[v3]drawbox=x=0:y=0:w=1920:h=80:color=black:t=fill,
    drawbox=x=0:y=1000:w=1920:h=80:color=black:t=fill[outv]
```
- First drawbox: Top bar (x=0, y=0, width=1920, height=80)
- Second drawbox: Bottom bar (x=0, y=1000, width=1920, height=80)
- Creates cinematic 2.35:1 appearance on 16:9 canvas

### Step 5: Map Output
```
-map "[outv]" -map 4:a
```
- Map filtered video stream [outv]
- Map audio from input 4 (in_audio)

### Step 6: Encode
```
-c:v libx264 -crf 18 -preset medium -c:a aac -b:a 192k -shortest -t 15
```
- H.264 video codec, CRF 18 (high quality)
- Medium preset (balanced speed/quality)
- AAC audio, 192k bitrate
- Duration: 15 seconds (or shortest input)

## Rounded Corners (Option 1 Only)

```
geq=lum='lum(X,Y)':a='if(lt(min(min(X,W-X),min(Y,H-Y)),40),
                          if(lte(hypot(40-min(X,W-X),40-min(Y,H-Y)),40),255,0),
                          255)'
```
- Uses GEQ (Generic Equation) filter to create alpha channel
- Logic:
  1. Find distance from nearest edge: `min(min(X,W-X),min(Y,H-Y))`
  2. If within 40px of edge, check if within 40px radius circle
  3. If inside circle, alpha=255 (opaque); outside=0 (transparent)
- Creates 40px rounded corners on all four corners

**Note**: This is computationally expensive! Use Option 2 for faster rendering.

## Key Differences from Your Original

| Aspect | Your Command | Correct Command |
|--------|--------------|-----------------|
| Structure | Sequential xfade transitions | Layered overlay composition |
| Background | No dedicated background | in_1 as persistent background |
| Images | Replace each other | Appear on top of background |
| Zoom | ❌ None | ✅ Gentle 5% zoom |
| Rounded Corners | ❌ None | ✅ 40px radius (Option 1) |
| Letterbox | ❌ None | ✅ 80px top/bottom bars |
| Centering | ✅ Centered (but wrong approach) | ✅ Centered on background |
| Aspect Ratio | ✅ Maintained | ✅ Maintained |
| Timing | Sequential cuts | Timed overlays |

## Customization Guide

### Change Zoom Amount
```
zoompan=z='min(1.0+0.1*(on/125),1.1)'  # 10% zoom instead of 5%
```

### Change Letterbox Size
```
drawbox=x=0:y=0:w=1920:h=100        # 100px bars instead of 80px
drawbox=x=0:y=1000-100:w=1920:h=100 # Adjust y position accordingly
```

### Change Foreground Size
```
scale='if(gt(a,16/9),1600,-1)':'if(gt(a,16/9),-1,900)'  # Larger foreground
zoompan=... :s=1600x900:...                               # Match zoompan size
```

### Change Timing
```
# Image 1: 0-8 seconds
-loop 1 -t 8 -i {{in_2}}
enable='between(t,0,8)'

# Image 2: 8-16 seconds
-loop 1 -t 8 -i {{in_3}}
enable='between(t,8,16)'

# Image 3: 16-24 seconds
-loop 1 -t 8 -i {{in_4}}
enable='between(t,16,24)'

# Adjust total duration
-t 24
```

### Add Fade In/Out to Foreground
```
[1:v]scale=...,zoompan=...,fade=t=in:st=0:d=0.5,fade=t=out:st=4.5:d=0.5[fg1]
```

## Testing Checklist

After running the test script, verify:
- [ ] Background visible throughout entire video
- [ ] Each foreground image appears at correct time
- [ ] Foreground images are centered horizontally
- [ ] Foreground images are centered vertically
- [ ] Gentle zoom effect on foreground images
- [ ] Black letterbox bars at top (80px)
- [ ] Black letterbox bars at bottom (80px)
- [ ] Foreground images maintain aspect ratio (no squishing)
- [ ] Rounded corners on foreground images (Option 1 only)
- [ ] Audio plays correctly
- [ ] Total duration is correct (15s for 3x5s images)

## N8N Integration

In your n8n HTTP Request node:

1. **Method**: POST (or whatever your video processing API uses)
2. **Body Content Type**: JSON
3. **Body**:
```json
{
  "command": "-loop 1 -i \\{\\{in_1\\}\\} -loop 1 -t 5 -i \\{\\{in_2\\}\\} ...",
  "inputs": {
    "in_1": "path/to/background.jpg",
    "in_2": "path/to/image1.jpg",
    "in_3": "path/to/image2.jpg",
    "in_4": "path/to/image3.jpg",
    "in_audio": "path/to/audio.mp3"
  },
  "output": "path/to/output.mp4"
}
```

The `\\{\\{` escaping is correct - n8n will replace it with actual paths.

## Performance Notes

- **Option 1** (with rounded corners): Slower due to GEQ filter, higher quality
- **Option 2** (without rounded corners): Faster, still professional
- **Preset**:
  - `medium` = balanced (recommended)
  - `fast` = quicker encoding, slightly larger file
  - `slow` = better compression, takes longer
- **CRF**:
  - `18` = high quality (recommended)
  - `23` = medium quality, smaller file
  - Lower number = better quality, larger file
