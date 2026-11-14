import sys
# trim.py <mgmt-tester.c> - keep the advertising-timeout helpers and only the "Instance 2 listed alone" case
p = sys.argv[1]
L = open(p).read().split("\n")
def idx(prefix, start=0):
    for i in range(start, len(L)):
        if L[i].startswith(prefix):
            return i
    sys.exit("not found: " + prefix)
# case definitions: from the macro to the blank line before the list_2 comment
a = idx("#define ADV_TIMEOUT_TEST(")
b = idx("/* Once instance 1 has expired")
del L[a:b]
# registrations: from the comment to the list_2 registration
c = idx("\t/* The timeout is passed to the controller as the Duration of the")
d = idx('\ttest_bredrle50_full("Add Ext Advertising - Instance 2 listed alone"')
del L[c:d]
open(p, "w").write("\n".join(L))
