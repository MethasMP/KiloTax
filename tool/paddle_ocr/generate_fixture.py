"""Generate a synthetic receipt; this is not a real-world accuracy corpus."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
root = Path(__file__).parent / 'fixtures'
image = Image.new('RGB', (1100, 1000), 'white')
font = ImageFont.truetype('/System/Library/Fonts/Menlo.ttc', 42) if Path('/System/Library/Fonts/Menlo.ttc').exists() else ImageFont.load_default(size=42)
draw = ImageDraw.Draw(image)
for n, line in enumerate(['SYNTHETIC FUEL SHOP', 'TAX INVOICE', 'ABN 12 345 678 901', '10/11/2026', 'Unleaded fuel  $60.50', 'GST included    $5.50', 'TOTAL AUD      $60.50', 'PAID VISA      $60.50']):
    draw.text((55, 60 + n * 100), line, fill='black', font=font)
image.save(root / 'synthetic_fuel.png')
