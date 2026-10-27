#!/usr/bin/env python3
# harness.py - runs INSIDE the kernel CI bot's own Docker image (scripts/bot-ci-local.sh builds it from
# github.com/bluez/action-ci) and runs the bot's own check code, unchanged, on local mail files.
#
# The bot's ci.py takes its series from patchwork and its tree from a GitHub pull request. Here the
# series is read from the mails given on the command line, and the tree is a local clone prepared
# like the bot's checkout (origin/master = the base; for the patched side HEAD is a merge commit
# whose second parent is the series, as refs/pull/N/merge). Everything else is the bot's: the test
# list comes from its create_test_list_kernel() (so its file-mapping picks the testers), each test's
# run()/post_run() is its own, dry_run=True as its "localci" task, and post_check() raises if ever
# reached. Nothing is sent anywhere.
#
#   harness.py --side patched|base [--space kernel|user] --src DIR [--bluez DIR] --ell DIR
#              --patch-root DIR --out DIR [--kernel-image FILE] [--jobs N] [--only NAME,...] <mail>...
#
# --space user runs the bot's create_test_list_user() with the BlueZ tree as --src (no --bluez);
# --kernel-image puts a bzImage where TestFunctional looks for one (else it builds bluetooth-next).
#
# --side base runs only the checks that are a property of a tree (the builds, TestRunnerSetup and
# the testers) on the base, for the base-vs-patched comparison; the patch-level checks need the
# series. Output in --out: <test>.log per test (the raw command output), report.txt in the bot's
# e-mail layout, verdicts.json. Exit status: the number of tests whose verdict is not PASS.
import argparse
import importlib.util
import json
import logging
import os
import re
import shutil
import sys
import traceback
import types

sys.path.insert(0, '/')
import libs                     # noqa: E402  (the bot's libs/)
from libs import init_logger, RepoTool   # noqa: E402
import ci                       # noqa: E402  (the bot's ci/ package)

PATCH_LEVEL = {'CheckPatch', 'VerifyFixes', 'VerifySignedoff', 'GitLint', 'SubjectPrefix',
               'IncrementalBuild'}


def pw_name(subject):
    """patchwork's name of a patch: "[PATCH 1/3] x" -> "[1/3] x" """
    m = re.match(r'^\[([^\]]*)\]\s*(.*)$', subject)
    if not m:
        return subject
    tags = [t for t in re.split(r'[\s,]+', m.group(1)) if t and t.upper() != 'PATCH']
    return ('[' + ','.join(tags) + '] ' if tags else '') + m.group(2)


def read_mail(path, pid):
    text = open(path, encoding='utf-8').read()
    head, _, rest = text.partition('\n\n')
    headers = {}
    key = None
    for line in head.splitlines():
        if line[:1] in (' ', '\t') and key:
            headers[key] += ' ' + line.strip()
        elif ':' in line:
            key, _, val = line.partition(':')
            key = key.strip().lower()
            headers[key] = val.strip()
    i = rest.find('\ndiff --git ')
    content = rest if i < 0 else rest[:i + 1]
    diff = '' if i < 0 else rest[i + 1:]
    j = diff.rfind('\n-- \n')
    if j >= 0:
        diff = diff[:j + 1]
    frm = headers.get('from', '')
    m = re.search(r'<([^>]+)>', frm)
    return {'id': pid, 'name': pw_name(headers.get('subject', '')), 'content': content,
            'diff': diff, 'msgid': headers.get('message-id', ''), 'path': os.path.abspath(path),
            'submitter': {'name': frm.split('<')[0].strip().strip('"'),
                          'email': m.group(1) if m else frm}}


class LocalPatchwork:
    """The calls the check code makes on libs.Patchwork, answered from the mails."""

    def __init__(self, patches):
        self._p = {p['id']: p for p in patches}

    def get_patch(self, pid):
        return self._p[pid]

    def get_patch_mbox(self, pid):
        return open(self._p[pid]['path'], encoding='utf-8').read()

    def save_patch_mbox(self, pid, filename):
        shutil.copyfile(self._p[pid]['path'], filename)
        return filename

    def save_patch_msg(self, pid, filename):
        with open(filename, 'w') as f:
            f.write(self._p[pid]['name'])
            f.write('\n\n')
            f.write(self._p[pid]['content'])
        return filename

    def post_check(self, *args, **kwargs):
        raise RuntimeError('post_check reached in a local run (dry_run must be set)')


class RawFormatter(logging.Formatter):
    """A command's output line as it was printed ("> " is the bot's logger prefix)."""

    def format(self, record):
        msg = record.getMessage()
        return msg[2:] if msg.startswith('> ') else '#ci ' + msg


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--side', choices=['patched', 'base'], required=True)
    ap.add_argument('--space', choices=['kernel', 'user'], default='kernel')
    ap.add_argument('--src', required=True)
    ap.add_argument('--bluez', default=None)
    ap.add_argument('--kernel-image', default=None)
    ap.add_argument('--ell', required=True)
    ap.add_argument('--patch-root', required=True)
    ap.add_argument('--out', required=True)
    # the bot's real runs: entrypoint.sh's "ci" task passes no -j, so ci.py's default "4" (only its
    # "localci" task passes "auto"); ELL's certificate generation failed with 16 (2026-10-27)
    ap.add_argument('--jobs', type=int, default=4)
    ap.add_argument('--only', default='')
    ap.add_argument('mails', nargs='+')
    args = ap.parse_args()

    os.makedirs(args.out, exist_ok=True)
    os.makedirs(args.patch_root, exist_ok=True)
    init_logger('Bluez_CI', verbose=True)
    lg = logging.getLogger('Bluez_CI')

    patches = [read_mail(p, 1000 + n) for n, p in enumerate(args.mails, 1)]
    series = {'id': 0, 'name': patches[0]['name'], 'patches': patches,
              'submitter': patches[0]['submitter'], 'web_url': '(local)'}

    config = json.load(open('/config.json'))
    if args.space == 'kernel':
        config.update(bluez_dir=os.path.abspath(args.bluez), kernel_dir=os.path.abspath(args.src))
    else:
        # user space: the source tree is BlueZ itself (entrypoint.sh: -z src, no -k)
        config.update(bluez_dir=os.path.abspath(args.src), kernel_dir=None)
        if args.kernel_image:
            # TestFunctional boots <src>/arch/x86/boot/bzImage if present, else has pytest-bluezenv
            # clone and build bluetooth-next; a bzImage built from the same tree and config saves that
            kdir = os.path.join(args.src, 'arch', 'x86', 'boot')
            os.makedirs(kdir, exist_ok=True)
            shutil.copyfile(args.kernel_image, os.path.join(kdir, 'bzImage'))
    config.update(dry_run=True, ell_dir=os.path.abspath(args.ell), space=args.space,
                  jobs=args.jobs, branch='master', pr_num=0)
    src_repo = RepoTool(os.path.basename(os.path.abspath(args.src)), args.src)
    ci_data = types.SimpleNamespace(config=config, pw=LocalPatchwork(patches), gh=None, email=None,
                                    src_repo=src_repo, src_dir=src_repo.path(),
                                    patch_root=os.path.abspath(args.patch_root),
                                    series=series, patch_1=patches[0])

    # the bot's ci.py, loaded under another name (its "import ci" still finds the ci/ package)
    spec = importlib.util.spec_from_file_location('bot_ci_main', '/ci.py')
    bot = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(bot)
    if args.space == 'kernel':
        tests = bot.create_test_list_kernel(ci_data)
    else:
        tests = bot.create_test_list_user(ci_data)
    if args.side == 'base':
        tests = [t for t in tests if t.name not in PATCH_LEVEL]
    if args.only:
        only = set(args.only.split(','))
        tests = [t for t in tests if t.name in only or t.name == 'TestRunnerSetup'
                 and any(o.startswith('TestRunner_') for o in only)]
    lg.info('test list (%s): %s', args.side, [t.name for t in tests])

    for t in tests:
        fh = logging.FileHandler(os.path.join(args.out, f'{t.name}.log'), mode='w')
        fh.setFormatter(RawFormatter())
        lg.addHandler(fh)
        lg.info('## CI: %s', t.name)
        try:
            t.run()
        except ci.EndTest:
            lg.error('Test Ended(Failure): %s:%s', t.name, t.verdict.name)
        except Exception as e:
            lg.error('Test Ended(Exception): %s: %s\n%s', t.name, e.__class__,
                     traceback.format_exc())
        finally:
            t.post_run()
        lg.info('## verdict: %s %s', t.name, t.verdict.name)
        lg.removeHandler(fh)
        fh.close()

    # the bot's e-mail layout (ci.py report_ci)
    line = '{name:<30}{result:<10}{elapsed:.2f} seconds\n'
    summary, details = 'Test Summary:\n', ''
    for t in tests:
        result = 'PASS' if t.verdict == ci.Verdict.PASS else t.verdict.name
        summary += line.format(name=t.name, result=result, elapsed=t.elapsed())
        if t.verdict != ci.Verdict.PASS:
            details += '##############################\n'
            details += f'Test: {t.name} - {result}\nDesc: {t.desc}\nOutput:\n{t.output}\n'
    with open(os.path.join(args.out, 'report.txt'), 'w') as f:
        f.write(summary + '\n' + ('Details\n' + details if details else ''))
    with open(os.path.join(args.out, 'verdicts.json'), 'w') as f:
        json.dump({t.name: t.verdict.name for t in tests}, f, indent=1)
    print(summary)
    return sum(1 for t in tests if t.verdict != ci.Verdict.PASS)


if __name__ == '__main__':
    sys.exit(main())
