import json
from pathlib import Path
from server import infer
root = Path(__file__).parent
result = infer((root / 'fixtures/synthetic_fuel.png').read_bytes())
(root / 'results-smoke.json').write_text(json.dumps(result, indent=2))
assert result['engine'] == 'paddleocr'
assert result['blocks'], 'No OCR text detected'
assert '60.50' in result['text'], result['text']
print(json.dumps({'engine': result['engine'], 'version': result['version'], 'blocks': len(result['blocks']), 'text': result['text']}))
