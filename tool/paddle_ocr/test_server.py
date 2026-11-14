import asyncio
import os
import unittest
from unittest.mock import patch
from fastapi import HTTPException
from server import ocr
from benchmark import score

class Request:
    def __init__(self, data, authorization='Bearer unit-secret'):
        self.headers = {'authorization': authorization}
        self.data = data
    async def stream(self):
        yield self.data

class SafetyTests(unittest.TestCase):
    def test_auth_empty_and_invalid_image(self):
        with patch.dict(os.environ, {'PADDLE_OCR_TOKEN': 'unit-secret'}):
            for request, status in [(Request(b'bad', 'Bearer wrong'), 401), (Request(b''), 400), (Request(b'bad'), 422), (Request(b'a' * (12 * 1024 * 1024 + 1)), 413)]:
                with self.assertRaises(HTTPException) as caught:
                    asyncio.run(ocr(request))
                self.assertEqual(caught.exception.status_code, status)
    def test_missing_token_fails_closed(self):
        with patch.dict(os.environ, {'PADDLE_OCR_TOKEN': ''}):
            with self.assertRaises(HTTPException) as caught:
                asyncio.run(ocr(Request(b'bad')))
            self.assertEqual(caught.exception.status_code, 503)
    def test_benchmark_false_ready_and_unknown_corrections(self):
        manifest = {'fixtures': [{'id': 'a', 'kind': 'synthetic', 'expected': {'amount': 10}, 'expectedReady': True}]}
        result = score(manifest, [{'id': 'a', 'engine': 'paddleocr', 'fields': {'amount': 20}, 'ready': True}])[0]
        self.assertEqual(result['falseReadyRate'], 1)
        self.assertEqual(result['fieldExactMatch'], 0)
        self.assertIsNone(result['meanCorrections'])

    def test_missing_image_prediction_counts_as_errors(self):
        manifest = {'engines': ['mlkit', 'paddleocr'], 'fixtures': [
            {'id': 'a', 'kind': 'real', 'expected': {'amount': 10}, 'expectedReady': True},
            {'id': 'b', 'kind': 'real', 'expected': {'amount': 20}, 'expectedReady': True}]}
        result = score(manifest, [{'id': 'a', 'engine': 'paddleocr', 'fields': {'amount': 10}, 'ready': True}])
        by_engine = {r['engine']:r for r in result}
        self.assertEqual(by_engine['paddleocr']['fieldExactMatch'], .5)
        self.assertEqual(by_engine['paddleocr']['predictionsMissing'], 1)
        self.assertEqual(by_engine['mlkit']['predictionsMissing'], 2)

if __name__ == '__main__':
    unittest.main()
