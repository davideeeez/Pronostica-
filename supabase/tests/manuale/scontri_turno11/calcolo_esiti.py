#!/usr/bin/env python3
"""Calcolo indipendente di punti, esiti 3/1/0 e classifica degli scontri, SENZA funzioni h2h_*/prediction_* del database.

Parte SOLO dalle tabelle base esportate con SELECT:
  matches.csv      match_id,round,status,home_goals,away_goals
  predictions.csv  user_id,match_id,home_goals,away_goals           (solo i membri delle leghe)
  membri_lega{3,4}.csv  joined_at,user_id                           (gia' nel repo)
  calendario_atteso_concreto_lega{3,4}.csv  round,slot,user_a,user_b (gia' nel repo)
e confronta, riga per riga, con l'output delle funzioni del database esportato in:
  db_results_lega{N}.csv    round,slot,user_a,user_b,is_rest,round_state,prov_a,prov_b,final_a,final_b,h2h_a,h2h_b
  db_standings_lega{N}.csv  user_id,pt_scontri,giocati,vinti,pareggiati,persi,riposi,pt_totali,esatti,esiti,winner_ok,scorer_ok,rank,tied,is_final
  db_detail_lega{N}.csv     slot,match_id,match_status,actual_home,actual_away,pred_home_a,pred_away_a,points_a,points_final_a,pred_home_b,pred_away_b,points_b,points_final_b
(campo vuoto = NULL).

Regole (da CLAUDE.md, riscritte qui):
- punti partita: 3 risultato esatto, 1 stesso esito (1/X/2), 0 altrimenti; pronostico mancante = 0 (partita finita) o nessun punto (non finita);
- provvisori: partite in_corso e finita; definitivi: solo finita;
- turno concluso: 10 partite tutte finita. Esito scontro solo a turno concluso: piu' punti 3-0, pari 1-1, riposo 0 e non giocato;
- classifica: pt_scontri, pt_totali (punti definitivi dei turni conclusi, riposo incluso), poi vincitrice/capocannoniere (assenti = falsi),
  esatti, esiti; rank() standard e tied se il gruppo ha piu' di un membro.

Uso:  calcolo_esiti.py --dir DIR [--round 11] [--lega 3 --lega 4]     |     calcolo_esiti.py --selftest
"""
import csv
import os
import sys


def sign(a, b):
    return (a > b) - (a < b)


def match_points(pred, actual):
    if pred is None:
        return None
    (ph, pa), (ah, aa) = pred, actual
    if (ph, pa) == (ah, aa):
        return 3
    return 1 if sign(ph, pa) == sign(ah, aa) else 0


def toint(x):
    return None if x in ("", None) else int(x)


def load(path):
    return list(csv.reader(open(path))) if os.path.exists(path) else []


def compute(rnd, matches, preds, pairings, members):
    """matches: {id: (status, hg, ag)}; preds: {(user, match): (h, a)}; pairings: [(slot, a, b|None)]."""
    played = {m: v for m, v in matches.items() if v[0] in ("in_corso", "finita")}
    concluded = len(matches) == 10 and all(v[0] == "finita" for v in matches.values())

    def pts(u, m):
        st, hg, ag = matches[m]
        p = preds.get((u, m))
        pp = match_points(p, (hg, ag)) if st in ("in_corso", "finita") else None
        if st == "finita":
            return (pp or 0, pp or 0)          # finita: provvisori e definitivi, mancante = 0
        if st == "in_corso":
            return (pp, None)                  # in corso: solo provvisori; senza pronostico NULL
        return (None, None)

    totals = {}
    for u in members:
        prov = sum((pts(u, m)[0] or 0) for m in played)
        fin = sum((pts(u, m)[1] or 0) for m in matches if matches[m][0] == "finita")
        ex = sum(1 for m in matches if matches[m][0] == "finita" and (pts(u, m)[1] or 0) == 3)
        es = sum(1 for m in matches if matches[m][0] == "finita" and (pts(u, m)[1] or 0) == 1)
        totals[u] = dict(prov=prov, fin=fin, ex=ex, es=es)
    results = []
    stand = {u: dict(pt=0, g=0, v=0, p=0, s=0, r=0) for u in members}
    for slot, a, b in pairings:
        if b is None:
            ha, hb = (0, None) if concluded else (None, None)
            if concluded:
                stand[a]["r"] += 1
        elif concluded:
            fa, fb = totals[a]["fin"], totals[b]["fin"]
            ha, hb = (3, 0) if fa > fb else ((1, 1) if fa == fb else (0, 3))
            for u, h in ((a, ha), (b, hb)):
                stand[u]["pt"] += h
                stand[u]["g"] += 1
                stand[u]["v" if h == 3 else ("p" if h == 1 else "s")] += 1
        else:
            ha = hb = None
        results.append(dict(slot=slot, a=a, b=b, state="concluso" if concluded else "in_corso",
                            prov_a=totals[a]["prov"], prov_b=None if b is None else totals[b]["prov"],
                            fin_a=totals[a]["fin"], fin_b=None if b is None else totals[b]["fin"], h_a=ha, h_b=hb))
    rows = []
    for u in members:
        t = totals[u]
        rows.append(dict(user=u, pt=stand[u]["pt"], g=stand[u]["g"], v=stand[u]["v"], p=stand[u]["p"], s=stand[u]["s"], r=stand[u]["r"],
                         tot=t["fin"] if concluded else 0, ex=t["ex"] if concluded else 0, es=t["es"] if concluded else 0))
    key = lambda r: (-r["pt"], -r["tot"], -r["ex"], -r["es"])   # winner_ok/scorer_ok assenti = uguali per tutti
    rows.sort(key=key)
    for r in rows:
        r["rank"] = 1 + sum(1 for x in rows if key(x) < key(r))
        r["tied"] = sum(1 for x in rows if key(x) == key(r)) > 1
    detail = {}
    for slot, a, b in pairings:
        det = []
        for m in sorted(matches, key=lambda x: x):
            st, hg, ag = matches[m]
            pa_, pfa = pts(a, m)
            pb_, pfb = (None, None) if b is None else pts(b, m)
            pr_a = preds.get((a, m)); pr_b = None if b is None else preds.get((b, m))
            det.append(dict(m=m, st=st, hg=hg, ag=ag, pra=pr_a, pa=pa_, pfa=pfa, prb=pr_b, pb=pb_, pfb=pfb))
        detail[slot] = det
    return concluded, results, rows, detail


def cmp(label, db, exp):
    ok = str(db) == str(exp)
    return ("OK  " if ok else "DIFF") + f" {label}: db={db!r} atteso={exp!r}"


def n(x):
    return "" if x is None else str(x)


def run(d, rnd, leghe):
    matches = {r[0]: (r[2], toint(r[3]), toint(r[4])) for r in load(d + "/matches.csv") if r and int(r[1]) == rnd}
    preds = {(r[0], r[1]): (int(r[2]), int(r[3])) for r in load(d + "/predictions.csv") if r}
    bad = 0
    for L in leghe:
        members = [r[1] for r in load(f"{d}/membri_lega{L}.csv")]
        names = {}
        pairings = [(int(r[1]), r[2], r[3] or None) for r in load(f"{d}/calendario_atteso_concreto_lega{L}.csv") if r and int(r[0]) == rnd]
        concluded, results, rows, detail = compute(rnd, matches, preds, pairings, members)
        print(f"\n=== LEGA {L} — turno {rnd} — {'CONCLUSO' if concluded else 'NON concluso'} ===")
        print("-- abbinamenti/esiti (h2h_results)")
        dbr = {int(r[1]): r for r in load(f"{d}/db_results_lega{L}.csv") if r and int(r[0]) == rnd}
        for x in results:
            r = dbr.get(x["slot"])
            if r is None:
                print(f"DIFF slot {x['slot']}: riga assente nel db"); bad += 1; continue
            checks = [("user_a", r[2], x["a"]), ("user_b", r[3], n(x["b"])), ("is_rest", r[4], "t" if x["b"] is None else "f"),
                      ("round_state", r[5], x["state"]), ("prov_a", r[6], n(x["prov_a"])), ("prov_b", r[7], n(x["prov_b"])),
                      ("final_a", r[8], n(x["fin_a"])), ("final_b", r[9], n(x["fin_b"])), ("h2h_a", r[10], n(x["h_a"])), ("h2h_b", r[11], n(x["h_b"]))]
            for name, dbv, ev in checks:
                line = cmp(f"slot {x['slot']} {name}", dbv, ev)
                print(line); bad += line.startswith("DIFF")
        print("-- classifica (h2h_standings)")
        dbs = {r[0]: r for r in load(f"{d}/db_standings_lega{L}.csv") if r}
        for x in rows:
            r = dbs.get(x["user"])
            if r is None:
                print(f"DIFF utente {x['user']}: assente nel db"); bad += 1; continue
            for name, idx, ev in [("pt_scontri", 1, x["pt"]), ("giocati", 2, x["g"]), ("vinti", 3, x["v"]), ("pareggiati", 4, x["p"]), ("persi", 5, x["s"]),
                                  ("riposi", 6, x["r"]), ("pt_totali", 7, x["tot"]), ("esatti", 8, x["ex"]), ("esiti", 9, x["es"]),
                                  ("winner_ok", 10, "f"), ("scorer_ok", 11, "f"), ("rank", 12, x["rank"]), ("tied", 13, "t" if x["tied"] else "f"), ("is_final", 14, "f")]:
                line = cmp(f"{x['user'][:8]} {name}", r[idx], ev)
                print(line); bad += line.startswith("DIFF")
        print("-- dettaglio per partita (h2h_match_detail)")
        dbd = {(int(r[0]), r[1]): r for r in load(f"{d}/db_detail_lega{L}.csv") if r}
        for slot, det in detail.items():
            for m in det:
                r = dbd.get((slot, m["m"]))
                if r is None:
                    print(f"DIFF slot {slot} {m['m']}: riga assente nel db"); bad += 1; continue
                pa = m["pra"] or (None, None); pb = m["prb"] or (None, None)
                checks = [("stato", r[2], m["st"]), ("gol", f"{r[3]}-{r[4]}", f"{n(m['hg'])}-{n(m['ag'])}"),
                          ("pred_a", f"{r[5]}-{r[6]}", f"{n(pa[0])}-{n(pa[1])}"), ("punti_a", r[7], n(m["pa"])), ("punti_fin_a", r[8], n(m["pfa"])),
                          ("pred_b", f"{r[9]}-{r[10]}", f"{n(pb[0])}-{n(pb[1])}"), ("punti_b", r[11], n(m["pb"])), ("punti_fin_b", r[12], n(m["pfb"]))]
                for name, dbv, ev in checks:
                    line = cmp(f"slot {slot} {m['m']} {name}", dbv, ev)
                    print(line); bad += line.startswith("DIFF")
    print(f"\nRIGHE DIVERSE: {bad}")
    return bad


def selftest():
    # scenario come ST12: D pronostica 1-0 su tutte, risultati 1-0 su 9 partite + 1 in corso; E 0-1 su 7 partite
    ms = {f"m{i}": ("finita", 1, 0) for i in range(1, 10)}
    ms["m10"] = ("in_corso", 1, 0)
    pr = {("D", f"m{i}"): (1, 0) for i in range(1, 11)}
    pr.update({("E", f"m{i}"): (0, 1) for i in range(3, 10)})
    c, res, rows, det = compute(11, ms, pr, [(0, "D", "E"), (1, "A", None)], ["D", "E", "A"])
    assert not c and res[0]["prov_a"] == 30 and res[0]["fin_a"] == 27 and res[0]["prov_b"] == 0 and res[0]["h_a"] is None
    assert [d["pa"] for d in det[0] if d["m"] == "m10"] == [3] and [d["pb"] for d in det[0] if d["m"] == "m10"] == [None]
    assert [d["pfb"] for d in det[0] if d["m"] == "m1"] == [0]
    ms["m10"] = ("finita", 1, 0)
    c, res, rows, det = compute(11, ms, pr, [(0, "D", "E"), (1, "A", None)], ["D", "E", "A"])
    assert c and (res[0]["h_a"], res[0]["h_b"]) == (3, 0) and res[1]["h_a"] == 0 and res[1]["h_b"] is None
    by = {r["user"]: r for r in rows}
    assert (by["D"]["pt"], by["D"]["tot"], by["D"]["ex"], by["D"]["rank"], by["D"]["tied"]) == (3, 30, 10, 1, False)
    assert (by["E"]["pt"], by["E"]["g"], by["E"]["s"], by["E"]["tot"]) == (0, 1, 1, 0)
    assert (by["A"]["g"], by["A"]["r"], by["A"]["pt"]) == (0, 1, 0)
    assert by["E"]["rank"] == by["A"]["rank"] == 2 and by["E"]["tied"] and by["A"]["tied"]
    assert match_points((2, 2), (1, 1)) == 1 and match_points((1, 0), (0, 1)) == 0 and match_points((3, 0), (2, 1)) == 1
    print("selftest ok (stessi numeri di ST12: provvisori 30/27, D batte E 3-0, riposo 0, E e A pari al 2o posto)")


if __name__ == "__main__":
    a = sys.argv[1:]
    if "--selftest" in a:
        selftest()
    else:
        d = a[a.index("--dir") + 1]
        rnd = int(a[a.index("--round") + 1]) if "--round" in a else 11
        leghe = [a[i + 1] for i, x in enumerate(a) if x == "--lega"] or ["3", "4"]
        sys.exit(1 if run(d, rnd, leghe) else 0)
