#!/usr/bin/env python3
"""Download pages into the threads directory and print their text.

Usage: fetch.py <prefix> <url>...
Each page is saved as threads/<prefix>-<last path part>, then printed as text
(with the link list) through html2txt.py's logic.
"""
import os
import subprocess
import sys
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(os.path.dirname(HERE), "threads")


def main():
    args = sys.argv[1:]
    mode = "--links"
    if args and args[0] == "--trim":
        mode = "--trim"
        args = args[1:]
    prefix = args[0]
    for url in args[1:]:
        name = prefix + "-" + url.rstrip("/").split("/")[-1].replace("?", "_")
        if not name.endswith(".html"):
            name += ".html"
        path = os.path.join(OUT, name)
        req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
        try:
            with urllib.request.urlopen(req, timeout=60) as r:
                data = r.read()
        except Exception as e:  # report and go on
            print("==== FAILED", url, e)
            continue
        with open(path, "wb") as f:
            f.write(data)
        print("==== ", url, "->", path)
        sys.stdout.flush()
        subprocess.run([sys.executable, "-I", os.path.join(HERE, "html2txt.py"), path, mode])


if __name__ == "__main__":
    main()
