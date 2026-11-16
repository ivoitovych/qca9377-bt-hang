import sys, time
tag, n, gap = sys.argv[1], int(sys.argv[2]), float(sys.argv[3])
pad = "x" * 180
for i in range(n):
    print(f"MARK {tag} {i:06d} {pad}", flush=True)
    time.sleep(gap)
