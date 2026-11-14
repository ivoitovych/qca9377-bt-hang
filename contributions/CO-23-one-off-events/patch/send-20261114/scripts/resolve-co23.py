"""resolve-co23.py : resolve the two conflicts of the co23 test patch against master by keeping both sides
(master's new reconnect test first, then ours) and one merged import block."""
B = "/root/exp/agent-work/lane2-sco-20261114/bluez/"


def keep_both(text, sep_blank):
    out = []
    for line in text.split("\n"):
        if line.startswith("<<<<<<< "):
            continue
        if line == "=======":
            out.append("")
            out.append("") if sep_blank == 2 else None
            continue
        if line.startswith(">>>>>>> "):
            continue
        out.append(line)
    return "\n".join(out)


doc = open(B + "doc/functional-a2dp.rst").read()
open(B + "doc/functional-a2dp.rst", "w").write(keep_both(doc, 1))

py = open(B + "test/functional/test_a2dp.py").read()
first = "<<<<<<< HEAD\nimport signal\nimport subprocess\n=======\nimport logging\nimport signal\n>>>>>>> test: Cover A2DP endpoint switch while Close is pending\n"
assert first in py
py = py.replace(first, "import logging\nimport signal\nimport subprocess\n")
open(B + "test/functional/test_a2dp.py", "w").write(keep_both(py, 2))
