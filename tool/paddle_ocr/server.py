"""Explicitly self-hosted CPU OCR. Never sends receipt images to another service."""
import asyncio
import hmac
import io
import os
from datetime import datetime, timezone
from importlib.metadata import version
from threading import Lock

from fastapi import FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from PIL import Image, UnidentifiedImageError

MAX_BYTES = 12 * 1024 * 1024
MAX_PIXELS = 24_000_000
Image.MAX_IMAGE_PIXELS = MAX_PIXELS
app = FastAPI()
origins = [s.strip() for s in os.environ.get('PADDLE_CORS_ORIGINS', '').split(',') if s.strip()]
if origins:
    app.add_middleware(CORSMiddleware, allow_origins=origins, allow_methods=['POST', 'GET'], allow_headers=['Authorization', 'Content-Type'])
_model = None
_lock = Lock()


def infer(data):
    import numpy as np
    global _model
    with Image.open(io.BytesIO(data)) as source:
        if source.width * source.height > MAX_PIXELS or getattr(source, 'n_frames', 1) != 1:
            raise ValueError('Only single-frame images up to 24 megapixels are supported')
        image = np.array(source.convert('RGB'))
    from paddleocr import PaddleOCR
    # Paddle predictor instances are serialized; one process owns one model.
    with _lock:
        if _model is None:
            _model = PaddleOCR(lang='en', ocr_version='PP-OCRv5', device='cpu', use_doc_orientation_classify=False, use_doc_unwarping=False, use_textline_orientation=False)
        blocks = []
        for page, result in enumerate(_model.predict(image), 1):
            for text, score, polygon in zip(result['rec_texts'], result['rec_scores'], result['rec_polys']):
                points = np.asarray(polygon)
                blocks.append(dict(page=page, text=str(text), score=float(score), bounds=[float(points[:, 0].min()), float(points[:, 1].min()), float(points[:, 0].max()), float(points[:, 1].max())]))
    return dict(text='\n'.join(b['text'] for b in blocks), blocks=blocks, engine='paddleocr', version=f"{version('paddleocr')}/PP-OCRv5/en", extractedAt=datetime.now(timezone.utc).isoformat())


@app.get('/health')
def health():
    return {'status': 'ok', 'modelLoaded': _model is not None, 'engine': 'paddleocr', 'version': version('paddleocr')}


@app.post('/ocr')
async def ocr(request: Request):
    token = os.environ.get('PADDLE_OCR_TOKEN', '')
    if not token:
        raise HTTPException(503, 'Server token is not configured')
    if not hmac.compare_digest(request.headers.get('authorization', ''), 'Bearer ' + token):
        raise HTTPException(401, 'Invalid token')
    data = bytearray()
    async for chunk in request.stream():
        data.extend(chunk)
        if len(data) > MAX_BYTES:
            raise HTTPException(413, 'Image exceeds 12 MiB')
    if not data:
        raise HTTPException(400, 'Empty image')
    try:
        return await asyncio.to_thread(infer, bytes(data))
    except (UnidentifiedImageError, Image.DecompressionBombError, Image.DecompressionBombWarning, ValueError) as error:
        raise HTTPException(422, 'Invalid or unsupported image') from error
    except Exception as error:
        # Do not disclose file paths, model cache details or receipt contents.
        raise HTTPException(503, 'OCR inference unavailable') from error
