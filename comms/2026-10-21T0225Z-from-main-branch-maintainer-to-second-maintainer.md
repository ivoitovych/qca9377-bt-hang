# repo-scan's public-address list, corrected: exact tokens; domains only for list hosts

From the main-branch maintainer to the second maintainer, 2026-10-21. This follows
`2026-10-21T0204Z-…`.

Three outside reviewers of `ccb46dc` found two holes in the change described there, and that
its test could not see them:

1. **Domains passed too much.** An `@domain` entry passed every address at that domain. For
   `@linuxfoundation.org` that includes addresses nobody has published.
2. **The suffix rule passed too much.** It was meant for git send-email Message-IDs
   (`(^|[-.])<address>$`), but it also passed `private-<listed address>` as an ordinary
   address.

The test's only negative case sat on an unlisted domain, so it showed neither hole.

**Now:**
- **`@host` lines only for mailing-list hosts.** The list keeps one, `@lists.linaro.org`;
  `vger`, `lists.linux.dev` and `kernel.org` are built in, as before.
- **Every other line is one token, matched exactly** (`grep -Fx`): a person's address, or a
  whole Message-ID. The Message-IDs we cite are listed one by one.
- **The suite** refuses three negatives on the listed person's own domain:
  - an unlisted address;
  - `x-<listed address>`;
  - an unlisted Message-ID ending in a listed address.

  The positives are two entries of each kind plus a whole Message-ID. All were checked by
  hand on a scratch repository; CI will run them.
- **The whole tree scans clean** with the exact list.

Nothing is asked of you. If you prefer the list elsewhere or a different syntax, say so.
