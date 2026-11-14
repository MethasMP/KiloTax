#!/usr/bin/env python3
"""Manage a private loopback-only PaddleOCR development service on this Mac.
Secrets and runtime data are written privately under ignored .runtime/.
"""
import argparse
import fcntl
import json
import os
from pathlib import Path
import secrets
import signal
import socket
import subprocess
import sys
import time
import urllib.error
import urllib.request

BASE = Path(__file__).resolve().parent
RUNTIME = BASE / '.runtime'
HOST = '127.0.0.1'
PORT = 8765


def initialize():
    RUNTIME.mkdir(mode=0o700, exist_ok=True)
    RUNTIME.chmod(0o700)


def private_write(path, value):
    descriptor = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(descriptor, 'w') as output:
        output.write(value)
    path.chmod(0o600)


def owned_process():
    try:
        pid = int((RUNTIME / 'pid').read_text().strip())
        if pid < 2:
            return None
        result = subprocess.run(['ps', '-p', str(pid), '-o', 'args='], capture_output=True, text=True)
        command = result.stdout
        if result.returncode == 0 and str(BASE) in command and 'uvicorn' in command and 'server:app' in command:
            return pid
    except (OSError, ValueError):
        pass
    return None


def health():
    with urllib.request.urlopen(f'http://{HOST}:{PORT}/health', timeout=2) as response:
        value = json.load(response)
    if value.get('engine') != 'paddleocr':
        raise RuntimeError('Port is occupied by a different service')
    return value


def start():
    if owned_process():
        print(json.dumps({'running': True, **health()}))
        return
    executable = BASE / '.venv/bin/python'
    if not executable.exists():
        raise RuntimeError('Install the pinned dependencies in .venv first; see README.md')
    # Do not claim another process on this port or kill it.
    with socket.socket() as probe:
        try:
            probe.bind((HOST, PORT))
        except OSError as error:
            raise RuntimeError('Port 8765 is occupied; existing service was left untouched') from error
    token_path = RUNTIME / 'token'
    if not token_path.exists():
        private_write(token_path, secrets.token_urlsafe(36))
    token = token_path.read_text().strip()
    if not token:
        raise RuntimeError('Runtime token is empty')
    token_path.chmod(0o600)
    environment = {**os.environ, 'PADDLE_OCR_TOKEN': token,
                   'PADDLE_PDX_CACHE_HOME': str(BASE / '.cache'), 'PYTHONUNBUFFERED': '1'}
    log_path = RUNTIME / 'server.log'
    descriptor = os.open(log_path, os.O_WRONLY | os.O_CREAT | os.O_APPEND, 0o600)
    with os.fdopen(descriptor, 'ab') as log:
        process = subprocess.Popen([str(executable), '-m', 'uvicorn', 'server:app',
                                    '--app-dir', str(BASE), '--host', HOST, '--port', str(PORT)],
                                   cwd=BASE, env=environment, stdout=log,
                                   stderr=subprocess.STDOUT, stdin=subprocess.DEVNULL,
                                   start_new_session=True)
    private_write(RUNTIME / 'pid', str(process.pid))
    for _ in range(100):
        if process.poll() is not None:
            raise RuntimeError('Service exited; inspect the private .runtime/server.log')
        try:
            result = health()
            connection()
            print(json.dumps({'running': True, 'url': f'http://localhost:{PORT}/ocr', **result}))
            return
        except (OSError, ValueError):
            time.sleep(.1)
    raise RuntimeError('Startup is still pending; use status to inspect before retrying')


def connection():
    token_path = RUNTIME / 'token'
    if not token_path.exists():
        raise RuntimeError('Start the service before preparing connection details')
    private_write(RUNTIME / 'connection.txt',
                  'For iPhone Simulator on this Mac only.\n'
                  'Receipt inbox → OCR connection\n'
                  f'Service address: http://localhost:{PORT}/ocr\n'
                  f'Access token: {token_path.read_text().strip()}\n\n'
                  'This is loopback-only. A physical phone needs a separate private HTTPS endpoint.\n'
                  'Do not commit or share this access token.\n')
    return RUNTIME / 'connection.txt'


def check():
    if not owned_process():
        raise RuntimeError('Start the managed service first')
    token = (RUNTIME / 'token').read_text().strip()
    request = urllib.request.Request(f'http://{HOST}:{PORT}/ocr',
        data=(BASE / 'fixtures/synthetic_fuel.png').read_bytes(),
        headers={'Content-Type': 'application/octet-stream', 'Authorization': 'Bearer ' + token}, method='POST')
    with urllib.request.urlopen(request, timeout=240) as response:
        result = json.load(response)
    if result.get('engine') != 'paddleocr' or not result.get('blocks'):
        raise RuntimeError('Inference returned no recognized blocks')
    print(json.dumps({'inference': 'passed', 'fixture': 'synthetic_fuel',
                      'engine': result['engine'], 'version': result['version'],
                      'blockCount': len(result['blocks']), 'modelLoaded': health()['modelLoaded']}))


def stop():
    pid = owned_process()
    if pid is None:
        print(json.dumps({'running': False, 'message': 'No managed process to stop'}))
        return
    os.kill(pid, signal.SIGTERM)
    for _ in range(100):
        if owned_process() is None:
            (RUNTIME / 'pid').unlink(missing_ok=True)
            print(json.dumps({'running': False}))
            return
        time.sleep(.1)
    raise RuntimeError('Shutdown is still pending; no force-kill was sent')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=['start', 'status', 'stop', 'check', 'connection'])
    args = parser.parse_args()
    initialize()
    with (RUNTIME / 'manage.lock').open('a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        if args.action == 'start': start()
        elif args.action == 'stop': stop()
        elif args.action == 'check': check()
        elif args.action == 'connection': print(connection())
        else:
            print(json.dumps({'running': bool(owned_process()), **(health() if owned_process() else {})}))


if __name__ == '__main__':
    try:
        main()
    except (OSError, RuntimeError, ValueError) as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)
