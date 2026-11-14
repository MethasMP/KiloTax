# PaddleOCR on the development Mac

This component runs pretrained PaddleOCR on the Mac. It has no per-receipt API
fee and does not send images to a third-party inference API. It is a local test
service, not an internet deployment or on-device mobile model.

## Start / verify / stop

From the repository root:

```sh
python3.11 -m venv tool/paddle_ocr/.venv
 tool/paddle_ocr/.venv/bin/pip install -r tool/paddle_ocr/requirements.txt
python3 tool/paddle_ocr/manage.py start
python3 tool/paddle_ocr/manage.py check
python3 tool/paddle_ocr/manage.py status
python3 tool/paddle_ocr/manage.py connection
python3 tool/paddle_ocr/manage.py stop
```

The environment is already installed on the current Mac. `start` launches a
background process on 127.0.0.1:8765 and reuses an existing managed instance.
`check` performs real inference on the synthetic fixture and warms the model.
Model weights download on first use; later starts use the local cache.

`connection` prints a path to a private `.runtime/connection.txt` with the URL
and random token. Enter these in Receipt inbox → OCR connection on this Mac's
iPhone Simulator, then choose Read with PaddleOCR for a receipt. Credentials are
not printed by the status/check commands. Runtime files have private permissions
and are ignored by Git. Never add them to a commit.

The service continues after the terminal closes, but does not start automatically
after a Mac restart. Use `start` again. Mac sleep/network availability can interrupt
requests. The model loads on `check` or the first actual request, not on a health
probe alone.

A physical phone's localhost is the phone itself, not this Mac. A phone requires
a separately configured private HTTPS endpoint. This local-only setup deliberately
does not expose the port to the network or install a login daemon.

## Verify this standalone component

```sh
tool/paddle_ocr/.venv/bin/python -m unittest discover -s tool/paddle_ocr -p 'test_*.py'
python3 tool/paddle_ocr/manage.py check
```

Seven Python tests cover authentication, invalid/oversized input, benchmark missing
predictions, private runtime files, idempotent start and safe process ownership.
`check` uses real pretrained inference, not a mocked OCR response.

The Flutter integration is a separate application change. The service component
can be reviewed/committed independently; its green tests do not imply the entire
application is ready to merge or deploy.
