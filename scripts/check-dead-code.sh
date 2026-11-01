#!/bin/sh
# Fails when a source file defines a static function that nothing in it calls. The tweak builds with
# -Werror, so such a function fails the build a minute in with "-Wunused-function", and it is almost always
# what a cut feature left behind: removing the call is easy, remembering the definition is not. Run from
# tweak/Makefile before every build, beside check-layers.sh.
#   scripts/check-dead-code.sh [path to tweak/Sources]
#
# The scan is per line, so a definition whose brace is on a later line is read by its first line, and a name
# is a function only when it is preceded by whitespace or `*` and followed by `(`. Type macros of the shape
# `_Atomic(...)` and blocks (`static void (^name)(void)`) are skipped by their leading `_` and `^`.
SOURCES=${1:-"$(dirname "$0")/../tweak/Sources"}
cd "$SOURCES" || exit 1

dead=""
for file in $(find . -type f \( -name '*.m' -o -name '*.x' \) | sort); do
    # The name is the identifier right before the first `(`: everything up to it is the return type, which
    # cannot hold a paren. A greedy read of the line instead would take the last call in the body, which is
    # how this check first failed on `NS_FORMAT_FUNCTION(1, 2)` and on a one-line body.
    names=$(sed -nE 's/^static[[:space:]]+[^()]*[[:space:]*]([A-Za-z_][A-Za-z0-9_]*)[[:space:]]*\(.*/\1/p' "$file")
    for name in $names; do
        # Only a real identifier: the scan is textual, and a type macro or a block would otherwise be read
        # as one.
        case "$name" in
            _*|void|int|BOOL|char|const|static) continue ;;
            ""|*[!A-Za-z0-9_]*) continue ;;
        esac
        uses=$(grep -oE "(^|[^A-Za-z0-9_])${name}([^A-Za-z0-9_]|$)" "$file" | wc -l | tr -d ' ')
        if [ "$uses" -le 1 ]; then
            dead="${dead}${file}: ${name} is defined and never called
"
        fi
    done
done

if [ -n "$dead" ]; then
    echo "dead code: a static function nothing calls (the build would fail with -Wunused-function):" >&2
    printf '%s' "$dead" >&2
    echo "delete it, or the call that went away with the feature it was for." >&2
    exit 1
fi
exit 0
