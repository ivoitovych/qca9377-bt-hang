# Review request: an Ubuntu 24.04 stable-update request for two journalctl commits

Below is a request to Ubuntu, not yet filed, to add two upstream systemd commits from v256 to noble's
systemd 255.4. They remove an fstat() on every open journal file for every entry read. The request
consists of:
- the bug text (stable-update template);
- the measurements;
- a reproducer and its reference output;
- [OPEN: the patches and the debdiff, still being built and tested].

Please review it as the Ubuntu SRU team and the systemd package maintainers would. Hard objections
first, then weaker ones. For each point, say what to change.

## Questions

1. **Does the Impact justify a stable update?** The SRU policy limits updates to high-impact bugs. It
   does not name performance-only fixes. What would the SRU team object to, and what argument or
   data is missing?
2. **Where problems could occur.** Is anything missing or wrong? In particular:
   - journal files from an older journald, without the `tail_entry_offset` header field;
   - files written while being read (`-f`, the active system and user files);
   - files from systemd-journal-remote;
   - `--merge`, `--file=` on another machine's files, and journal namespaces;
   - libsystemd0 consumers other than journalctl;
   - the new `-EBADMSG` path of the second commit.
3. **The two patches on 255.4.** Do you see a correctness problem? Are there upstream commits that
   these two need on 255.4 but that are not included? PR #30209 had four more:
   - bd1af1d5fb SD_JOURNAL_ASSUME_IMMUTABLE;
   - f7f062bf9f, its use;
   - cb2b0326ee, Hashmap to array;
   - 63d2c7554e, logs-show reads the timestamp only when needed.
4. **The Test Plan.** Can a verifier who did not write it follow it on an ordinary noble machine? Is
   the "same output" step (a hash of `-o export` over the archived files with `--until`) sound, or can
   archived files change between the two runs?
5. **The numbers.** Is any figure or comparison misleading? Is the statement about default installs
   right: `SystemMaxFiles=100`, so up to about 100 archived files plus the active ones? Should the
   container figures be dropped entirely?
6. **The route.** Is a merge proposal against `ubuntu-noble` or a debdiff for `ubuntu-sponsors` the
   better first step for an outside contributor? Should it wait until 8.19 is released?
7. **Length and tone.** What can be cut without losing the case?

Below are the files, each under its path.
