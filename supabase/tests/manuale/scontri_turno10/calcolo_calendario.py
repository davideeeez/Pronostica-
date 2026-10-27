#!/usr/bin/env python3
"""Calendario atteso delle leghe a scontri, calcolato SENZA le funzioni h2h_* del database.

Metodo del cerchio (round-robin) scritto qui da zero a partire dalla regola in CLAUDE.md:
- membri ordinati per (joined_at, user_id);
- con N dispari si aggiunge un membro fantasma (None): chi lo incontra riposa;
- ciclo di (N + N%2 - 1) turni, poi si riparte dal primo abbinamento;
- dal turno di partenza al turno 38.

Uso:
  calcolo_calendario.py --selftest
  calcolo_calendario.py --start 10 membri.csv     # righe "joined_at,user_id" (anche senza intestazione)

Convenzione di rotazione (quale coppia cade in quale turno): fisso il primo membro e ruoto gli altri
di una posizione a destra a ogni turno. È la stessa del codice SQL, quindi QUESTO punto non è una verifica
indipendente; lo sono le proprietà controllate da check_properties().
"""
import csv
import itertools
import sys


def calendar(members, start_round, last_round=38):
    """members: lista di id già ordinata. Ritorna {turno: [(a, b)]}, b=None se a riposa."""
    n = len(members)
    if n < 2:
        return {}
    size = n + (n % 2)
    cycle = size - 1
    base = list(members) + ([None] if n % 2 else [])
    first, rest = base[0], base[1:]
    out = {}
    for k in range(last_round - start_round + 1):
        c = k % cycle
        rot = rest[-c:] + rest[:-c] if c else rest[:]
        arr = [first] + rot
        pairs = []
        for j in range(size // 2):
            a, b = arr[j], arr[size - 1 - j]
            pairs.append((a if a is not None else b, None if (a is None or b is None) else b))
        out[start_round + k] = pairs
    return out


def check_properties(members, cal, start_round):
    """Proprietà del round-robin, indipendenti da qualsiasi convenzione di rotazione."""
    n = len(members)
    size = n + (n % 2)
    cycle = size - 1
    errors = []
    for rnd, pairs in cal.items():
        seen = [x for p in pairs for x in p if x is not None]
        if sorted(seen) != sorted(members):
            errors.append(f"turno {rnd}: non tutti i membri compaiono esattamente una volta")
        rests = [p for p in pairs if p[1] is None]
        if len(rests) != (n % 2):
            errors.append(f"turno {rnd}: riposi {len(rests)}, attesi {n % 2}")
    for k in range(0, len(cal) - cycle):
        if [frozenset(p) for p in cal[start_round + k]] != [frozenset(p) for p in cal[start_round + k + cycle]]:
            errors.append(f"turno {start_round + k}: non ripete il turno {start_round + k + cycle}")
    meets = {}
    for rnd in range(start_round, start_round + cycle):
        for a, b in cal[rnd]:
            if b is not None:
                meets[frozenset((a, b))] = meets.get(frozenset((a, b)), 0) + 1
    for pair in itertools.combinations(members, 2):
        if meets.get(frozenset(pair), 0) != 1:
            errors.append(f"coppia {pair}: si incontra {meets.get(frozenset(pair), 0)} volte nel ciclo")
    if n % 2:
        resters = [p[0] for rnd in range(start_round, start_round + cycle) for p in cal[rnd] if p[1] is None]
        if sorted(resters) != sorted(members):
            errors.append("nel primo ciclo ognuno deve riposare esattamente una volta")
    return errors


def selftest():
    # tabelle derivate a mano per il turno 10, 11, 12 (m1..m4 = membri in ordine di ingresso)
    c4 = calendar(["m1", "m2", "m3", "m4"], 10)
    assert c4[10] == [("m1", "m4"), ("m2", "m3")], c4[10]
    assert c4[11] == [("m1", "m3"), ("m4", "m2")], c4[11]
    assert c4[12] == [("m1", "m2"), ("m3", "m4")], c4[12]
    assert c4[13] == c4[10]
    c3 = calendar(["m1", "m2", "m3"], 10)
    assert c3[10] == [("m1", None), ("m2", "m3")], c3[10]
    assert c3[11] == [("m1", "m3"), ("m2", None)], c3[11]
    assert c3[12] == [("m1", "m2"), ("m3", None)], c3[12]
    assert c3[13] == c3[10]
    for n in range(2, 9):
        ms = [f"m{i}" for i in range(1, n + 1)]
        errs = check_properties(ms, calendar(ms, 10), 10)
        assert not errs, (n, errs)
    print("selftest ok: tabelle a 3 e 4 membri, proprietà per N=2..8")


def main(argv):
    if "--selftest" in argv:
        selftest()
        return
    start = int(argv[argv.index("--start") + 1])
    path = argv[-1]
    rows = [r for r in csv.reader(open(path)) if r and not r[0].lower().startswith("joined")]
    members = [uid.strip() for _, uid in sorted((r[0].strip(), r[1].strip()) for r in rows)]
    cal = calendar(members, start)
    errs = check_properties(members, cal, start)
    for rnd, pairs in cal.items():
        for slot, (a, b) in enumerate(pairs):
            print(f"{rnd},{slot},{a},{b if b else ''}")
    if errs:
        print("PROPRIETA' VIOLATE:", *errs, sep="\n", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main(sys.argv[1:])
