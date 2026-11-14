# Verification performed 2026-11-12

- macOS ARM64, Python 3.11.15, paddlepaddle 3.2.2, paddleocr 3.3.2. Full transitive package snapshot is recorded in `requirements-macos-arm64.lock.txt`.
- Installed actual packages in task-local ignored `.venv`; downloaded official pretrained PP-OCRv5_server_det and en_PP-OCRv5_mobile_rec weights to ignored `.cache`.
- Ran `generate_fixture.py` then `smoke_inference.py` on the synthetic printed receipt. Actual CPU inference returned 12 blocks and recognized:

```
SYNTHETIC FUEL SHOP
TAX INVOICE
ABN 12 345 678 901
10/11/2026
Unleaded fuel
$60.50
GST included
$5.50
TOTAL AUD
$60.50
PAID VISA
$60.50
```

The captured observed extraction is `fixtures/synthetic_fuel.paddle.json`. This verifies real inference and contract output on one synthetic image. It does not establish real-world receipt accuracy, production readiness classification, correction rate, or superiority over ML Kit. ML Kit native inference had not been run at this initial stage; the 14 November native comparison is recorded below.

- Three Python tests passed: fail-closed auth, invalid/oversized/empty image handling, and false-ready/correction metric behavior.
- Three Flutter mock HTTP tests passed: offline default and missing endpoint, response validation, token/image transmission and failure/timeout propagation.
- Scoped Flutter analysis of the engine and tests passed with no issues.


Root integration verification:
- Flutter PaddleReceiptOcrEngine called the actual authenticated local Python
  HTTP service using the generated image. HTTP 200; merchant/date/currency,
  total 60.50 and GST 5.50 parsed successfully. One HTTP smoke test passed.
- Application-parser benchmark on this **single synthetic** image matched
  all six labeled fields after canonicalizing merchant case and ABN formatting.
  It correctly routed the checksum-invalid synthetic ABN to review. No ready
  predictions, real-receipt accuracy, correction-time result, or native ML Kit
  comparison is available. These limitations are not substituted with estimates.


14 November native comparison:
- Real ML Kit ran on iPhone 17 Pro Max Simulator against the same generated image.
- Native output initially separated label and amount columns. Added visual row
  assembly using line bounds, retaining the original blocks as evidence.
- Reran native integration with assertions for amount 60.50, GST 5.50, currency
  AUD and purchase date 2026-11-10: passed.
- Saved actual native output in fixtures/synthetic_fuel.mlkit.json. Both engines
  match six canonical labeled fields on this one synthetic image. Neither is
  approved for automatic entry because the example ABN fails checksum.
- Additional reading-order and missing-prediction benchmark regressions pass.
  Current Python suite has four tests. No real-world accuracy is inferred.
