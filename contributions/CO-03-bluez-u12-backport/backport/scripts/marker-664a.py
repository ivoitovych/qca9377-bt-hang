#!/usr/bin/env python3
"""Count "if (setup->reconfigure)\\n\\t\\tgoto failed;" (the code
664a5d3785a1 adds) in a2dp.c at upstream 5.72 and master."""
import re
import subprocess

U = "/root/exp/qca9377-bt-hang/cache/bluez-upstream"
for ref in ("5.72", "origin/master"):
    a = subprocess.run(["git", "-C", U, "show", f"{ref}:profiles/audio/a2dp.c"],
                       stdout=subprocess.PIPE, encoding="utf-8", check=True).stdout
    print(ref, len(re.findall(r"if \(setup->reconfigure\)\n\t\tgoto failed;", a)))
