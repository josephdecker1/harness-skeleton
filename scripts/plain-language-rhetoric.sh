#!/usr/bin/env bash
# Exits 1 when a banned device appears. Portable ERE, no lookahead, no grep -P.
RHETORIC="not un(like|expected|common|usual|reasonable|important|familiar|heard)\
|no small([^-[:alnum:]]|$)|far from ideal|by no means|hardly surprising\
|(the point is|(here'?s|here is) the thing|needless to say|(it'?s|it is) worth noting)\
|at the end of the day\
|genuinely|honestly|frankly|truly([^-[:alnum:]]|$)|to be honest\
|very, very|really, really\
|not just a|not only .* but|n'?t (just|merely)|(is|are|was|were) not (just|merely)"

if [ "$#" -eq 0 ]; then
    echo "plain-language: no files given."
    exit 0
fi

grep -nEi "$RHETORIC" "$@"
status=$?
if [ "$status" -eq 0 ]; then
    echo "plain-language: rhetorical device found. Rewrite the line."
    exit 1
fi
if [ "$status" -gt 1 ]; then
    echo "plain-language: grep failed with exit $status. Check the file list."
    exit 2
fi
exit 0
