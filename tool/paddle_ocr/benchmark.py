"""Score the same labeled images with application-parser outputs from each engine.
Missing fields AND missing predictions count as errors. Synthetic/real stay separate.
"""
import argparse
import json
import re
from pathlib import Path


def canonical(key, value):
    if value is None:
        return None
    if key == 'merchant':
        return ' '.join(str(value).casefold().split())
    if key == 'abn':
        return re.sub(r'\D', '', str(value))
    return value


def score(manifest, predictions):
    labels = {f['id']: f for f in manifest['fixtures']}
    indexed = {}
    engines = set(manifest.get('engines', []))
    for item in predictions:
        if item['id'] not in labels:
            raise ValueError('Prediction has no corresponding label')
        key = (item['engine'], item['id'])
        if key in indexed:
            raise ValueError('Duplicate engine/image prediction')
        indexed[key] = item
        engines.add(item['engine'])
    reports = []
    for engine in sorted(engines):
        for kind in sorted({f['kind'] for f in labels.values()}):
            group = dict(samples=0, predictionsMissing=0, fields=0, correctFields=0,
                         falseReady=0, readyPredictions=0, corrections=0,
                         correctionSamples=0, fieldResults={})
            for label in labels.values():
                if label['kind'] != kind:
                    continue
                item = indexed.get((engine, label['id']))
                group['samples'] += 1
                group['predictionsMissing'] += item is None
                all_correct = item is not None
                for key, expected in label['expected'].items():
                    actual = (item or {}).get('fields', {}).get(key)
                    correct = item is not None and canonical(key, actual) == canonical(key, expected)
                    group['fields'] += 1
                    group['correctFields'] += correct
                    field = group['fieldResults'].setdefault(key, {'correct': 0, 'total': 0})
                    field['correct'] += correct
                    field['total'] += 1
                    all_correct = all_correct and correct
                if item and 'ready' in item:
                    group['readyPredictions'] += bool(item['ready'])
                    group['falseReady'] += bool(item['ready']) and (not label['expectedReady'] or not all_correct)
                if item and 'corrections' in item:
                    group['corrections'] += item['corrections']
                    group['correctionSamples'] += 1
            reports.append({**group, 'engine': engine, 'kind': kind,
                            'fieldExactMatch': group['correctFields'] / group['fields'] if group['fields'] else None,
                            'falseReadyRate': group['falseReady'] / group['readyPredictions'] if group['readyPredictions'] else None,
                            'meanCorrections': group['corrections'] / group['correctionSamples'] if group['correctionSamples'] else None})
    return reports


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('predictions', type=Path)
    parser.add_argument('--manifest', type=Path, default=Path(__file__).parent / 'fixtures/manifest.json')
    args = parser.parse_args()
    print(json.dumps(score(json.loads(args.manifest.read_text()), json.loads(args.predictions.read_text())), indent=2))
