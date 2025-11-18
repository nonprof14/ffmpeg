#!/bin/bash
# Test script for the n8n ffmpeg command
# This validates the command works correctly before using in n8n

set -e

echo "=== FFmpeg Command Test Script ==="
echo ""

# Check if test images exist
if [ ! -f "test_bg.jpg" ] || [ ! -f "test_img1.jpg" ] || [ ! -f "test_img2.jpg" ] || [ ! -f "test_img3.jpg" ]; then
    echo "Creating test images..."

    # Create background image (1920x1080)
    ffmpeg -f lavfi -i color=c=blue:s=1920x1080:d=1 -vf "drawtext=text='BACKGROUND':fontsize=100:fontcolor=white:x=(w-text_w)/2:y=(h-text_h)/2" -frames:v 1 test_bg.jpg -y

    # Create foreground test images (various sizes)
    ffmpeg -f lavfi -i color=c=red:s=800x600:d=1 -vf "drawtext=text='IMAGE 1':fontsize=60:fontcolor=white:x=(w-text_w)/2:y=(h-text_h)/2" -frames:v 1 test_img1.jpg -y

    ffmpeg -f lavfi -i color=c=green:s=1200x800:d=1 -vf "drawtext=text='IMAGE 2':fontsize=60:fontcolor=white:x=(w-text_w)/2:y=(h-text_h)/2" -frames:v 1 test_img2.jpg -y

    ffmpeg -f lavfi -i color=c=yellow:s=600x900:d=1 -vf "drawtext=text='IMAGE 3':fontsize=60:fontcolor=white:x=(w-text_w)/2:y=(h-text_h)/2" -frames:v 1 test_img3.jpg -y

    # Create test audio
    ffmpeg -f lavfi -i sine=frequency=1000:duration=15 -f lavfi -i sine=frequency=1500:duration=15 -filter_complex amix=inputs=2:duration=longest test_audio.mp3 -y

    echo "Test files created!"
fi

echo ""
echo "Running OPTION 2 (Simplified - recommended for testing)..."
echo ""

# OPTION 2: Simplified version (no rounded corners for faster testing)
ffmpeg \
  -loop 1 -i test_bg.jpg \
  -loop 1 -t 5 -i test_img1.jpg \
  -loop 1 -t 5 -i test_img2.jpg \
  -loop 1 -t 5 -i test_img3.jpg \
  -i test_audio.mp3 \
  -filter_complex "[0:v]scale=1920:1080:force_original_aspect_ratio=decrease,pad=1920:1080:-1:-1:black,setsar=1,format=yuv420p[bg];[1:v]scale='if(gt(a,16/9),1400,-1)':'if(gt(a,16/9),-1,787)',zoompan=z='min(1.0+0.05*(on/125),1.05)':d=125:s=1400x787:fps=25,setpts=PTS-STARTPTS[fg1];[2:v]scale='if(gt(a,16/9),1400,-1)':'if(gt(a,16/9),-1,787)',zoompan=z='min(1.0+0.05*(on/125),1.05)':d=125:s=1400x787:fps=25,setpts=PTS-STARTPTS[fg2];[3:v]scale='if(gt(a,16/9),1400,-1)':'if(gt(a,16/9),-1,787)',zoompan=z='min(1.0+0.05*(on/125),1.05)':d=125:s=1400x787:fps=25,setpts=PTS-STARTPTS[fg3];[bg][fg1]overlay=(W-w)/2:(H-h)/2:enable='between(t,0,5)'[v1];[v1][fg2]overlay=(W-w)/2:(H-h)/2:enable='between(t,5,10)'[v2];[v2][fg3]overlay=(W-w)/2:(H-h)/2:enable='between(t,10,15)'[v3];[v3]drawbox=x=0:y=0:w=1920:h=80:color=black:t=fill,drawbox=x=0:y=1000:w=1920:h=80:color=black:t=fill[outv]" \
  -map "[outv]" -map 4:a \
  -c:v libx264 -crf 18 -preset medium \
  -c:a aac -b:a 192k \
  -shortest -t 15 \
  test_output.mp4 -y

echo ""
echo "=== SUCCESS! ==="
echo "Output saved to: test_output.mp4"
echo ""
echo "Verify the following:"
echo "✓ Background (blue) visible throughout entire video"
echo "✓ Red image appears 0-5 seconds (centered, zooming)"
echo "✓ Green image appears 5-10 seconds (centered, zooming)"
echo "✓ Yellow image appears 10-15 seconds (centered, zooming)"
echo "✓ Black letterbox bars at top and bottom"
echo "✓ All foreground images maintain aspect ratio (no stretching)"
echo "✓ Smooth zoom effect on foreground images"
echo ""
echo "If all looks good, use the command from n8n_ffmpeg_command.txt in your n8n workflow!"
