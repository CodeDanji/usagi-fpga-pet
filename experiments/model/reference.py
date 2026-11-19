"""Integer reference, stimulus generator, RTL comparator; standard library only.

This is a deliberately small associative circuit, not a validated biological model.
One step = 0.25 ms model time. Hardware clock frequency is independent of dt.
"""
from pathlib import Path
import argparse
import csv
import json

ROOT = Path(__file__).resolve().parents[1]
Q = 65536
FIELDS = ('pre_v pre_u pre_spike control_v control_u control_spike '
          'post_v post_u post_spike weight control_weight syn_current '
          'pre_trace control_trace clipped').split()


def neuron(v, u, current):
    v2 = (v * v) >> 16
    dv = ((v2 * 2621) >> 16) + 5 * v + 140 * Q - u + current
    du = (1311 * (((13107 * v) >> 16) - u)) >> 16
    vn, un = v + (dv >> 2), u + (du >> 2)
    spike = int(vn >= 30 * Q)
    if spike:
        vn, un = -65 * Q, un + 8 * Q
    clip = int(not (-120 * Q <= vn <= 120 * Q and -120 * Q <= un <= 120 * Q))
    return max(-120 * Q, min(120 * Q, vn)), max(-120 * Q, min(120 * Q, un)), spike, clip


def protocol():
    rows = []
    def phase(name, n, card=0, control=0, food=0, learn=0):
        rows.extend((name, card, control, food, learn) for _ in range(n))
    phase('settle', 1200)
    phase('before_card', 800, card=1)
    phase('rest', 2400)
    for _ in range(8):
        phase('pair_card', 400, card=1, learn=1)
        phase('pair_food', 400, card=1, food=1, learn=1)
        phase('rest', 2400)
    phase('after_card', 800, card=1)
    phase('rest', 2400)
    phase('control_card', 800, control=1)
    phase('rest', 2400)
    phase('after_card_repeat', 800, card=1)
    phase('rest', 2400)
    return rows


def simulate(stim):
    cells = [(-65*Q, -13*Q, 0, 0)] * 3
    w, wc, syn, trace, tc = 0, 0, 0, 0, 0
    output = []
    for phase, card, control, food, learn in stim:
        old_pre, old_control, old_post = [n[2] for n in cells]
        nxt = [neuron(*cells[0][:2], card*20*Q),
               neuron(*cells[1][:2], control*20*Q),
               neuron(*cells[2][:2], syn+food*24*Q)]
        sn = min(64*Q, syn-(syn >> 6)+old_pre*w+old_control*wc)
        if learn and food and old_post:
            if trace or old_pre:
                w = min(24*Q, w+Q)
            if tc or old_control:
                wc = min(24*Q, wc+Q)
        trace = 2000 if old_pre else max(0, trace-1)
        tc = 2000 if old_control else max(0, tc-1)
        cells, syn = nxt, sn
        row = [*cells[0][:3], *cells[1][:3], *cells[2][:3], w, wc, syn,
               trace, tc, int(any(n[3] for n in cells))]
        output.append(dict(zip(FIELDS, row)))
    return output


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--compare', type=Path)
    args = ap.parse_args()
    dest = ROOT/'results'
    dest.mkdir(exist_ok=True)
    stim = protocol()
    rows = simulate(stim)
    # Hex flags: bit0 card, bit1 control, bit2 food, bit3 learning.
    (dest/'stimulus.mem').write_text(''.join(f'{c | (cc<<1) | (f<<2) | (l<<3):x}\n'
        for _, c, cc, f, l in stim), encoding='ascii')
    rom=ROOT.parent/'final.srcs'/'sources_1'/'rom'/'conditioning_stimulus.mem'
    rom.parent.mkdir(parents=True,exist_ok=True)
    rom.write_text((dest/'stimulus.mem').read_text(encoding='ascii'),encoding='ascii')
    with (dest/'reference.csv').open('w', newline='', encoding='ascii') as f:
        writer = csv.writer(f)
        writer.writerow(['step', 'phase', *FIELDS])
        for i, (s, r) in enumerate(zip(stim, rows)):
            writer.writerow([i, s[0], *(r[k] for k in FIELDS)])
    phases = ('before_card', 'after_card', 'control_card', 'after_card_repeat')
    counts = {p: sum(r['post_spike'] for s, r in zip(stim, rows) if s[0] == p) for p in phases}
    checks = {
        'untrained_no_response': counts['before_card'] == 0,
        'trained_response': counts['after_card'] > counts['before_card'],
        'control_no_response': counts['control_card'] == 0,
        'retained_response': counts['after_card_repeat'] > 0,
        'control_weight_unchanged': rows[-1]['control_weight'] == 0,
        'no_numeric_clipping': not any(r['clipped'] for r in rows),
        'weights_frozen_in_test': len({r['weight'] for s,r in zip(stim,rows)
            if s[0] in phases[1:]}) == 1,
    }
    report = {'steps': len(stim), 'dt_ms': 0.25, 'test_duration_ms': 200,
              'post_spike_counts': counts, 'final_weight': rows[-1]['weight']/Q,
              'checks': checks}
    if args.compare:
        with args.compare.open(newline='', encoding='ascii') as f:
            actual = list(csv.DictReader(f))
        if len(actual) != len(rows):
            raise AssertionError(f'RTL rows {len(actual)} != expected {len(rows)}')
        for i,(a,r) in enumerate(zip(actual,rows)):
            if int(a['step']) != i:
                raise AssertionError(f'RTL step ordering mismatch at {i}')
            for k in FIELDS:
                if int(a[k]) != r[k]:
                    raise AssertionError(f'step {i}, {k}: RTL={a[k]} reference={r[k]}')
        report['rtl_match'] = f'{len(rows)} steps, all {len(FIELDS)} fields bit-exact'
    (dest/'conditioning_summary.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(report,indent=2))
    if not all(checks.values()):
        raise AssertionError('Associative learning acceptance check failed')


if __name__ == '__main__':
    main()
