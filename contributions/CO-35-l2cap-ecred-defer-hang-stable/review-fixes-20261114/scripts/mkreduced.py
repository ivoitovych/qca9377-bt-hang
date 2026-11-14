import sys

# mkreduced.py <kernel tree> <annotations 0|1>
# Insert only the two locking helpers of mainline 608e0b7a675b (l2cap_chan_lock_conn() and the
# l2cap_chan_unlock_conn() macro) into include/net/bluetooth/l2cap.h and net/bluetooth/l2cap_core.c,
# text as upstream. annotations=0: the lines without the context-analysis annotations (6.x lines), as the
# package's backports of the full commit.
tree, ann = sys.argv[1], sys.argv[2] == "1"

H_DECL_ANN = (
    "bool l2cap_chan_lock_conn(struct l2cap_chan *chan)\n"
    "\t__acquires(&chan->lock) __cond_acquires(true, &chan->conn->lock);\n"
)
H_DECL_PLAIN = (
    "bool l2cap_chan_lock_conn(struct l2cap_chan *chan)\n"
    "\t__acquires(&chan->lock);\n"
)
H_MACRO = (
    "\n"
    "/* Release macro for l2cap_chan_lock_conn, so context analysis understands it */\n"
    "#define l2cap_chan_unlock_conn(chan, conn_locked)\t\t\t\\\n"
    "\t({\t\t\t\t\t\t\t\t\\\n"
    "\t\tstruct l2cap_chan *__chan = (chan);\t\t\t\\\n"
    "\t\tstruct l2cap_conn *__conn = __chan->conn;\t\t\\\n"
    "\t\tl2cap_chan_unlock(__chan);\t\t\t\t\\\n"
    "\t\tif (conn_locked) {\t\t\t\t\t\\\n"
    "\t\t\tmutex_unlock(&__conn->lock);\t\t\t\\\n"
    "\t\t\tl2cap_conn_put(__conn);\t\t\t\t\\\n"
    "\t\t}\t\t\t\t\t\t\t\\\n"
    "\t})\n"
)
C_FUNC_HEAD = (
    "/* Take chan->lock. If chan->conn is non-NULL, take new reference on it, take\n"
    " * chan->conn->lock, and return true. Otherwise return false.\n"
    " */\n"
    "bool l2cap_chan_lock_conn(struct l2cap_chan *chan)\n"
)
C_FUNC_ANN = "\t__context_unsafe(/* conditional locking */)\n"
C_FUNC_BODY = (
    "{\n"
    "\t/* Handle conn->lock > chan->lock ordering + race on chan->conn */\n"
    "\tfor (;;) {\n"
    "\t\tstruct l2cap_conn *conn;\n"
    "\n"
    "\t\tl2cap_chan_lock(chan);\n"
    "\t\tconn = chan->conn;\n"
    "\t\tif (conn)\n"
    "\t\t\tl2cap_conn_get(conn);\n"
    "\t\tl2cap_chan_unlock(chan);\n"
    "\n"
    "\t\tif (conn)\n"
    "\t\t\tmutex_lock(&conn->lock);\n"
    "\n"
    "\t\tl2cap_chan_lock(chan);\n"
    "\n"
    "\t\tif (chan->conn != conn) {\n"
    "\t\t\tl2cap_chan_unlock(chan);\n"
    "\t\t\tif (conn) {\n"
    "\t\t\t\tmutex_unlock(&conn->lock);\n"
    "\t\t\t\tl2cap_conn_put(conn);\n"
    "\t\t\t}\n"
    "\t\t\tschedule();\n"
    "\t\t\tcontinue;\n"
    "\t\t}\n"
    "\n"
    "\t\treturn chan->conn;\n"
    "\t}\n"
    "}\n"
    "\n"
)

hp = f"{tree}/include/net/bluetooth/l2cap.h"
h = open(hp).read()
anchor_h = "\n#endif /* __L2CAP_H */"
assert h.count(anchor_h) == 1
decl = H_DECL_ANN if ann else H_DECL_PLAIN
h = h.replace(anchor_h, "\n" + decl + H_MACRO + anchor_h)
open(hp, "w").write(h)

cp = f"{tree}/net/bluetooth/l2cap_core.c"
c = open(cp).read()
anchor_c = "EXPORT_SYMBOL(l2cap_chan_close);\n\n"
assert c.count(anchor_c) == 1
func = C_FUNC_HEAD + (C_FUNC_ANN if ann else "") + C_FUNC_BODY
c = c.replace(anchor_c, anchor_c + func)
open(cp, "w").write(c)
print("inserted helpers into", hp, "and", cp)
