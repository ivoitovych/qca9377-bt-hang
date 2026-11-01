#!/usr/bin/env python3
"""
Summarize CO-36 results jsonl files of agent-work/co36/results: one line
per recorded test run, and the T233 ledger comparison (AG sent vs HF
received), with every sanitizer line the ledger saw.

Usage: python3 -I summarize.py <out file> <results.jsonl>...
"""
import json
import sys
from collections import defaultdict


def frames(lst):
    return " ".join(f"{f['frame']}@{f['ms']}" + (f":{f['value']}" if "value" in f else "") for f in lst or [])


def link_line(r):
    return (
        f"codec={r.get('codec')} down={r.get('down_ms')} next_up={r.get('next_up_ms')} "
        f"imm=[{frames(r.get('immediate'))}] active=[{frames(r.get('while_active'))}] "
        f"after_down=[{frames(r.get('after_down'))}]"
    )


def classify(r):
    """leak/clean/out-of-window for one link report"""
    if r.get("down_ms") is None:
        return "no-end"
    if r["down_ms"] >= 1500:
        resent = {f["frame"] for f in r.get("while_active") or []}
        late = [f for f in r.get("after_down") or []]
        return "long:resend-while-up" if resent == {"VGS", "VGM"} and not late else f"long:other({frames(late)})"
    if r.get("next_up_ms") is not None and r["next_up_ms"] < 1500:
        return "re-armed"
    late_vgm = [f for f in r.get("after_down") or [] if f["frame"] == "VGM"]
    return "short:LEAK" if late_vgm else "short:clean"


def main():
    out = open(sys.argv[1], "w")
    by_test = defaultdict(list)
    ledgers = []
    for path in sys.argv[2:]:
        for line in open(path):
            e = json.loads(line)
            e["_file"] = path.rsplit("/", 1)[-1]
            if e["test"] == "ledger":
                ledgers.append(e)
            else:
                by_test[e["test"]].append(e)

    for name in sorted(by_test):
        out.write(f"\n== {name} ({len(by_test[name])} records)\n")
        counts = defaultdict(int)
        for e in by_test[name]:
            head = f"  [{e['_file']} rep={e.get('rep')}]"
            if "links" in e:
                cls = [classify(r) for r in e["links"]]
                for c in cls:
                    counts[c] += 1
                out.write(f"{head} links={len(e['links'])} " + ", ".join(cls) + "\n")
                for r in e["links"]:
                    out.write("      " + link_line(r) + "\n")
            elif "first" in e and "second" in e:
                for key in ("first", "second"):
                    c = classify(e[key])
                    counts[f"{key}:{c}"] += 1
                    out.write(f"{head} {key}: {c} {link_line(e[key])}\n")
            elif "down_ms" in e:
                c = classify(e)
                counts[c] += 1
                extra = {
                    k: e[k]
                    for k in (
                        "sleep_s", "bcs_ms", "change_from_up_ms", "valid_window",
                        "ag_received_ms", "restart_requested_ms", "pipewire_running",
                        "write_errors",
                    )
                    if k in e
                }
                out.write(f"{head} {c} {link_line(e)} {json.dumps(extra)}\n")
                if "change" in e:
                    ch = e["change"]
                    out.write(f"      change: want={ch['want']} first_ms={ch['first_ms']} first_value={ch['first_value']}\n")
                if "frames_from_up" in e:
                    out.write(f"      frames_from_up: {frames(e['frames_from_up'])}\n")
            else:
                keys = [k for k in e if k not in ("test", "build", "run", "rep", "nodeid", "_file")]
                out.write(f"{head} keys={keys}\n")
                for k in ("no_link_speaker", "no_link_mic", "during_link_speaker"):
                    if k in e:
                        s = e[k]
                        out.write(f"      {k}: want={s['want']} first_ms={s['first_ms']} first_value={s['first_value']} rc={s['cli']['rc']}\n")
                for k in ("hf_volume_changed", "blocked", "a_up_ms", "a_down_ms", "b_down_ms",
                          "hf_a_last_gap_ms", "hf_b_last_gap_ms", "mic_quirk_lines", "hw_volume_lines"):
                    if k in e:
                        out.write(f"      {k}: {e[k]}\n")
                if "all_frames_ms_from_boot" in e:
                    out.write(f"      all AG frames: {len(e['all_frames_ms_from_boot'])} "
                              f"[{' '.join(f['frame'] + ':' + str(f['value']) for f in e['all_frames_ms_from_boot'])}]\n")
                if "ag_frames_from_b_up" in e:
                    out.write(f"      AG frames from B up: {frames(e['ag_frames_from_b_up'])}\n")
                    out.write(f"      HF A: {frames(e['hf_a_frames'])}\n")
                    out.write(f"      HF B: {frames(e['hf_b_frames'])}\n")
                for k in ("first", "second"):
                    if k in e:
                        out.write(f"      {k}: {classify(e[k])} {link_line(e[k])}\n")
        out.write("  counts: " + json.dumps(dict(counts)) + "\n")

    out.write("\n== T233 ledger: AG sent vs HF received, per test run\n")
    mism = 0
    for e in ledgers:
        for idx, got in e["hf_received"].items():
            same = got == e["ag_sent"]
            if not same:
                mism += 1
            out.write(
                f"  {'same' if same else 'DIFF'} [{e['_file']}] {e['nodeid'].split('::')[-1]} hf{idx}: "
                f"sent={len(e['ag_sent'])} got={len(got)}"
                + ("" if same else f" sent={e['ag_sent']} got={got}")
                + "\n"
            )
        if e.get("sanitizer_lines"):
            out.write(f"    SANITIZER: {e['sanitizer_lines']}\n")
    out.write(f"  ledgers={len(ledgers)} mismatches={mism}\n")
    out.close()


if __name__ == "__main__":
    main()
