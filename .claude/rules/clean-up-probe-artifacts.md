# Agents clean up what they plant

An agent asked to prove a boundary holds will plant things designed to escape it. Examples are a
symlink out of a sandbox, a file outside a jail, and a probe script on the host. Each one is a
live hazard to every later process on the machine, including the next review cycle.

## The rule

1. **The run that plants an artifact removes it.** A dispatch that asks an agent to probe a
   boundary also requires cleanup, and the caller checks it at the checkpoint.
2. **No destructive sweep follows symlinks.** Never combine `find -L` with deletion. Plain `find`
   does not follow links, and `-type l` unlinks a link itself. A check that must resolve links
   does not get to delete anything.
3. **Bound the blast radius.** When a reviewer must run on the host, the dispatch names the exact
   paths it may write to and forbids deletion outside them. A sandbox is better still.
4. **Namespace probe directories per cycle**, for example `$TMPDIR/review-<cycle>/`, and remove
   the previous cycle's directory before the next dispatch.

## Why

In the maintainer's own use, a review series planted a symlink to `/` to prove a sandbox held,
and nobody removed it. Eight cycles later, a fix for an unrelated bug ran a `find -L` sweep over
that directory. The sweep followed the link and destroyed six credential files on the host. Each
step looked reasonable on its own, and the series as a whole was careless.
