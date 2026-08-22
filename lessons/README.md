# lessons/ — what this project cost to learn, written down once

`reviews/` says what the code was like on a date. `comms/` says what one person
told another. **This directory says what we now know that we did not know
before, and what it cost to find out.**

The distinction is the whole point and it is easy to lose. A work log says *what
happened*. A lessons document says *what would have to change about how you
work* — and it earns a place here only if someone could have done something
differently, and will next time.

## Naming

```
lessons/<UTC timestamp>-<role>.md
lessons/2026-08-22T1101Z-test-suite-maintainer.md
```

Same `YYYY-MM-DDTHHMMZ` shape as `reviews/` and `comms/`. One document per
maintainer per milestone, written from that maintainer's own vantage — nobody
here sees the whole project, and a document that pretends otherwise is worth
less than three honest partial ones.

## What belongs

Each entry carries three things, and an entry missing the second is not a
lesson:

1. **The rule**, stated so it can be applied to something else.
2. **The instance that taught it** — what actually went wrong, with the command
   or the commit. A rule with no instance is an opinion someone had.
3. **What it cost**, when the cost is known. Hours, a destroyed controller, a
   withdrawn claim, a wrong number in a public report.

## What does not

- Anything that was already obvious before the incident. If it needed no
  incident, it needed no document.
- Restatements of the code. The code is in the repository and it is better at
  describing itself than a summary is.
- Successes with no surprise in them. "The tests caught a bug" is the tests
  working, not a lesson.
- Anything you cannot point at. Every claim here follows the same rule as
  everywhere else in this repository: it ships with the command that produced
  it, or it does not ship.

## The part people skip

**Write down what you got wrong, at least as carefully as what you got right.**
Every maintainer here has withdrawn a claim inside a day. A lessons document
listing only other people's mistakes is a document nobody will trust, including
its author in six months.
