import sys

# strip-lines.py <file> <first> <last> [<first> <last> ...]: delete the 1-based inclusive line ranges
path = sys.argv[1]
nums = [int(x) for x in sys.argv[2:]]
ranges = list(zip(nums[0::2], nums[1::2]))
lines = open(path).read().split("\n")
keep = [l for i, l in enumerate(lines, 1) if not any(a <= i <= b for a, b in ranges)]
open(path, "w").write("\n".join(keep))
