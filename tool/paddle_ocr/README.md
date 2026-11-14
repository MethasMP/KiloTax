# Optional self-hosted PaddleOCR

ML Kit remains the default offline mobile provider. Paddle requires a separate server and an explicit user action consenting to send the selected receipt to the configured server. This is not on-device Paddle. No paid API or custom training is used.

## Run locally (Python 3.11)

```sh
python3.11 -m venv tool/paddle_ocr/.venv
tool/paddle_ocr/.venv/bin/pip install -r tool/paddle_ocr/requirements.txt
export PADDLE_OCR_TOKEN='choose-a-long-random-secret'
export PADDLE_PDX_CACHE_HOME="$PWD/tool/paddle_ocr/.cache"
tool/paddle_ocr/.venv/bin/uvicorn server:app --app-dir tool/paddle_ocr --host 127.0.0.1 --port 8765
```

Initial inference downloads the public pretrained PP-OCRv5 models. Model weights and environments are ignored. Subsequent inference runs locally. Set `PADDLE_CORS_ORIGINS` to an explicit comma-separated origin list only if browser access is needed; no CORS origins are enabled by default. Remote deployments need HTTPS and a private, access-controlled host. One worker serializes model calls; deploy behind request/concurrency limits for public exposure. Token is mandatory for inference. Do not embed a privileged shared server token in a publicly distributed app.

Configure Flutter with `--dart-define=PADDLE_OCR_URL=https://your-host/ocr` and optionally `--dart-define=PADDLE_OCR_TOKEN=...`. Configuration alone does not enable uploading: call `ReceiptOcrEngineFactory.create(usePaddle: true)` only following the user's explicit action. An empty endpoint throws before reading/uploading. Default factory creates ML Kit.

`POST /ocr`: raw image bytes, `Content-Type: application/octet-stream`, `Authorization: Bearer ...`. Supports single-frame decodable images, max 12 MiB and 24 megapixels. Response: `{text, blocks:[{page:1,text,bounds:[left,top,right,bottom],score:0..1}], engine:"paddleocr", version, extractedAt:ISO8601}`. Bounds are image pixels. `GET /health` reports process status and whether a model has loaded; it does not claim successful inference before the first call. Images are held in memory and never persisted by this server. Errors omit receipt content.

## Actual inference smoke test

```sh
export PADDLE_PDX_CACHE_HOME="$PWD/tool/paddle_ocr/.cache"
tool/paddle_ocr/.venv/bin/python tool/paddle_ocr/generate_fixture.py
tool/paddle_ocr/.venv/bin/python tool/paddle_ocr/smoke_inference.py
```

This generated receipt is synthetic. Passing a smoke test only verifies model/runtime plumbing and selected printed content, not production field accuracy.

## Labeled benchmark

`fixtures/manifest.json` labels each example as `synthetic` or `real`, carries expected parser fields and expected readiness. Real receipts require consent and independent human labels; none are supplied here. Compare engines using the same images and parser/validator. Export predictions as JSON list entries `{id,engine,fields:{merchant,amount,gstAmount,currency,date,abn},ready,corrections}` and run `python tool/paddle_ocr/benchmark.py predictions.json`. Missing fields count as errors; omitted correction counts remain unknown. Results separate synthetic and real groups, report exact field match, false-ready among ready predictions, and observed correction counts. No real accuracy is inferred from synthetic samples.

Official model/API reference: [PaddleOCR 3.3.2 OCR pipeline](https://www.paddleocr.ai/v3.3.2/en/version3.x/pipeline_usage/OCR.html). Uses `PaddleOCR(...).predict()` and pretrained PP-OCRv5, not an OCR stub. Direct package versions are pinned in requirements; `requirements-macos-arm64.lock.txt` captures the tested transitive Python 3.11 macOS ARM environment. Use the direct requirements on other platforms and capture a platform-specific lock.


## App benchmark and UI

Open Receipt inbox → OCR connection to enter a service URL and a session token.
Each receipt has an explicit Read with PaddleOCR action; nothing is uploaded just
because a connection was configured. The connection is session-only. Use HTTPS
for a phone connecting to another machine. Loopback HTTP is only for local tests.

After collecting the same image through ML Kit/Paddle, save engine outputs next
to the fixture as `<image-name>.mlkit.json` and `<image-name>.paddle.json`.
Run `flutter test tool/paddle_ocr/benchmark_app_test.dart` to feed saved engine
outputs through the **application parser and review policy**, then
`python3 tool/paddle_ocr/benchmark.py tool/paddle_ocr/predictions.json`.
Merchant case/whitespace and ABN formatting are canonicalized; absent fields
remain errors. The example ABN is deliberately checksum-invalid, so the
synthetic fixture's expectedReady is false even if all printed fields are read.

`http_smoke_test.dart` is disabled by default. To repeat the actual HTTP/provider
smoke, run the local server with the disposable test token
`receipt-local-smoke-only`, then
`flutter test --dart-define=RUN_PADDLE_HTTP=true tool/paddle_ocr/http_smoke_test.dart`.
Use a different private token outside local smoke testing.

## Managed Mac test service

The simplest setup on the development Mac (with the existing `.venv`) is:

```sh
python3 tool/paddle_ocr/manage.py start
python3 tool/paddle_ocr/manage.py check
python3 tool/paddle_ocr/manage.py status
python3 tool/paddle_ocr/manage.py connection
python3 tool/paddle_ocr/manage.py stop
```

`start` creates a private random token and starts a background process bound only
to 127.0.0.1:8765. Repeating it reuses the same running instance. `check` performs
real inference on the supplied synthetic image, warming the model. A successful
health response alone does not mean a model has loaded.

`connection` prints the path to a private `.runtime/connection.txt` containing
the URL and token. Enter these in Receipt inbox → OCR connection on the iPhone
Simulator. Runtime files, tokens and logs are ignored by Git. Do not copy the
token into source code or commits. `stop` terminates only a process whose command
matches this service; it does not kill unrelated processes on the same port.

This setup is for this Mac and its iPhone Simulator. A physical phone cannot
reach the Mac through its own localhost. It requires a separately configured
private HTTPS endpoint, which is outside this local-only setup. The service is
not installed as a login daemon and must be started again after restarting the
Mac. Keep ML Kit as the offline default until that endpoint is available.
