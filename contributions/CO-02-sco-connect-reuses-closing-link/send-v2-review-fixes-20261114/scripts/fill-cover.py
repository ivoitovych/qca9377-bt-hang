"""fill-cover.py <cover mail> <subject (with [PATCH ...] prefix)> <body file>
Replaces the generated '*** SUBJECT HERE ***' / '*** BLURB HERE ***' of a format-patch cover letter."""
import sys

path, subject, body_path = sys.argv[1], sys.argv[2], sys.argv[3]
text = open(path).read()
body = open(body_path).read().rstrip("\n")
lines = text.split("\n")
out = []
for line in lines:
    if line.startswith("Subject: ") and "SUBJECT HERE" in line:
        # keep the generated "[PATCH ... 0/N]" prefix
        prefix = line[len("Subject: "):].split("]")[0] + "]"
        line = "Subject: " + prefix + " " + subject.split("] ", 1)[1]
    out.append(line)
text = "\n".join(out)
if "*** BLURB HERE ***" not in text:
    sys.exit("no blurb marker")
text = text.replace("*** BLURB HERE ***", body)
open(path, "w").write(text)
