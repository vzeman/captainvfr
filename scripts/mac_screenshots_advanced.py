#!/usr/bin/env python3

"""
Mac App Store Screenshot Generator
Captures and resizes screenshots for Mac App Store submission
"""

import os
import sys
import time
import subprocess
from pathlib import Path
from PIL import Image
import argparse

# Apple Store required sizes
APPLE_SIZES = [
    (1280, 800),
    (1440, 900),
    (2560, 1600),
    (2880, 1800)
]

class ScreenshotGenerator:
    def __init__(self, output_dir="macos_screenshots"):
        self.output_dir = Path(output_dir)
        self.output_dir.mkdir(exist_ok=True)
        
    def take_screenshot(self, filename, window_only=False, delay=3):
        """Take a screenshot using macOS screencapture command"""
        print(f"\n📸 Taking screenshot in {delay} seconds...")
        print("Position your app window as desired")
        
        for i in range(delay, 0, -1):
            print(f"  {i}...")
            time.sleep(1)
        
        cmd = ["screencapture", "-x"]  # -x removes screenshot sound
        if window_only:
            cmd.append("-w")  # -w captures specific window (click to select)
            print("Click on the window you want to capture...")
        
        cmd.append(str(filename))
        
        subprocess.run(cmd)
        print(f"✅ Screenshot saved: {filename}")
        return filename
    
    def resize_image(self, input_path, output_size, mode='fit', background_color='white'):
        """
        Resize image to specified dimensions
        
        Modes:
        - 'fit': Fit within dimensions, maintain aspect ratio (may have bars)
        - 'fill': Fill entire dimensions (may crop)
        - 'stretch': Stretch to exact dimensions (may distort)
        """
        img = Image.open(input_path)
        
        if mode == 'fit':
            # Calculate scaling to fit within bounds
            img.thumbnail(output_size, Image.Resampling.LANCZOS)
            
            # Create new image with exact dimensions and paste resized image centered
            new_img = Image.new('RGB', output_size, background_color)
            x = (output_size[0] - img.width) // 2
            y = (output_size[1] - img.height) // 2
            new_img.paste(img, (x, y))
            return new_img
            
        elif mode == 'fill':
            # Calculate scaling to fill entire area (may crop)
            img_ratio = img.width / img.height
            target_ratio = output_size[0] / output_size[1]
            
            if img_ratio > target_ratio:
                # Image is wider - scale by height
                new_height = output_size[1]
                new_width = int(new_height * img_ratio)
            else:
                # Image is taller - scale by width
                new_width = output_size[0]
                new_height = int(new_width / img_ratio)
            
            img = img.resize((new_width, new_height), Image.Resampling.LANCZOS)
            
            # Crop to center
            left = (img.width - output_size[0]) // 2
            top = (img.height - output_size[1]) // 2
            right = left + output_size[0]
            bottom = top + output_size[1]
            
            return img.crop((left, top, right, bottom))
            
        elif mode == 'stretch':
            # Stretch to exact dimensions (may distort)
            return img.resize(output_size, Image.Resampling.LANCZOS)
    
    def process_screenshot(self, input_path, modes=['fit', 'fill']):
        """Process a screenshot into all required Apple sizes"""
        input_path = Path(input_path)
        base_name = input_path.stem
        
        print(f"\n🔄 Processing: {input_path.name}")
        
        # Get original dimensions
        with Image.open(input_path) as img:
            print(f"Original dimensions: {img.width}x{img.height}")
        
        results = []
        
        for width, height in APPLE_SIZES:
            for mode in modes:
                output_name = f"{base_name}_{width}x{height}_{mode}.png"
                output_path = self.output_dir / output_name
                
                try:
                    resized = self.resize_image(input_path, (width, height), mode)
                    resized.save(output_path, 'PNG', optimize=True)
                    print(f"✅ Created: {output_name}")
                    results.append(output_path)
                except Exception as e:
                    print(f"❌ Failed to create {output_name}: {e}")
        
        return results
    
    def add_device_frame(self, screenshot_path, output_path):
        """Add a device frame around the screenshot (requires additional setup)"""
        # This is a placeholder - you'd need to download device frames
        # from Apple or use a tool like Fastlane frameit
        print("ℹ️  Device frames require additional setup.")
        print("   Consider using Fastlane frameit for professional device frames.")
        return screenshot_path
    
    def generate_marketing_images(self, screenshots):
        """Generate marketing images with text overlays"""
        print("\n🎨 Generating marketing versions...")
        
        for screenshot in screenshots:
            # This is where you could add text overlays, logos, etc.
            # For now, we'll just copy the best versions
            if "_2880x1800_" in str(screenshot):
                marketing_path = self.output_dir / f"marketing_{screenshot.name}"
                subprocess.run(["cp", str(screenshot), str(marketing_path)])
                print(f"✅ Created marketing version: {marketing_path.name}")

def main():
    parser = argparse.ArgumentParser(description='Generate Mac App Store screenshots')
    parser.add_argument('--capture', type=int, help='Number of screenshots to capture')
    parser.add_argument('--process', nargs='+', help='Process existing image files')
    parser.add_argument('--window', action='store_true', help='Capture window only (not full screen)')
    parser.add_argument('--modes', nargs='+', default=['fit', 'fill'], 
                       choices=['fit', 'fill', 'stretch'],
                       help='Resize modes to use')
    parser.add_argument('--output', default='macos_screenshots', help='Output directory')
    
    args = parser.parse_args()
    
    generator = ScreenshotGenerator(args.output)
    
    screenshots = []
    
    # Capture new screenshots
    if args.capture:
        print(f"📸 Capturing {args.capture} screenshots...")
        for i in range(1, args.capture + 1):
            filename = generator.output_dir / f"screenshot_{i:02d}.png"
            generator.take_screenshot(filename, window_only=args.window)
            screenshots.append(filename)
    
    # Process existing files
    elif args.process:
        screenshots = [Path(f) for f in args.process if Path(f).exists()]
        if not screenshots:
            print("❌ No valid image files provided")
            return 1
    
    # If no arguments, look for images in output directory
    else:
        print(f"\n📁 Looking for images in {generator.output_dir}...")
        screenshots = list(generator.output_dir.glob("*.png"))
        screenshots = [s for s in screenshots if not any(size in s.name for size in ['1280x800', '1440x900', '2560x1600', '2880x1800'])]
        
        if not screenshots:
            print("\n❌ No screenshots found. Use --capture or --process options.")
            return 1
    
    # Process all screenshots
    all_results = []
    for screenshot in screenshots:
        results = generator.process_screenshot(screenshot, modes=args.modes)
        all_results.extend(results)
    
    # Generate marketing versions
    generator.generate_marketing_images(all_results)
    
    # Summary
    print("\n" + "="*50)
    print("✅ Screenshot generation complete!")
    print(f"📁 Output directory: {generator.output_dir}")
    print(f"📸 Total images created: {len(all_results)}")
    print("\n🎯 Next steps:")
    print("1. Review the generated screenshots")
    print("2. Choose between 'fit' (shows entire app) or 'fill' (exact dimensions)")
    print("3. Upload to App Store Connect")
    print("4. Consider using Fastlane for automated deployment")
    
    return 0

if __name__ == "__main__":
    sys.exit(main())