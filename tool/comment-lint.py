"""Comment lint: every comment in the Dart sources must read to a stranger.

The repository is public, and a comment is written for whoever opens the
file next -- someone who was not in the conversations the code came from.
This fails (exit 1) when a comment in apps/ or packages/:

  * contains Arabic script. Comments are English; Arabic belongs in the
    translations (.arb) and in test data, never in an explanation.
    Private plan references ("م-73", "ع-1") are caught by this too: the
    plan lives in docs/plan, which is not published.
  * says TODO / FIXME / XXX / HACK without an issue number (#123) or a
    link, so a note-to-self cannot outlive the person who wrote it.
  * is code that was switched off rather than deleted. Git keeps history;
    a commented-out line only makes the reader wonder whether it matters.

Only comments are read. The file is tokenised, so an Arabic title in a
test, or "//" inside a URL string, is not mistaken for a comment.
Generated files are skipped.

Usage:  python tool/comment-lint.py            (from the repository root)
"""

import re
import subprocess
import sys

ARABIC = re.compile(r"[؀-ۿݐ-ݿﭐ-﷿ﹰ-﻿]")
MARKER = re.compile(r"\b(TODO|FIXME|XXX|HACK)\b")
TRACKED = re.compile(r"#\d+|https?://")
# A line of Dart that was switched off: a statement, a declaration, or a
# lone brace -- not a sentence that happens to end in a colon.
CODE = re.compile(
    r"^\s*(?:"
    r"(?:final|var|const|late|await|return|throw|import|export)\b.*[;{]"
    r"|(?:if|for|while|switch)\s*\(.*"
    r"|[A-Za-z_$][\w$.<>?\[\]]*\s*(?:=|\+=|-=)\s*[^=].*;"
    r"|[A-Za-z_$][\w$.]*\(.*\)\s*;"
    r"|[{}]\s*[;,)]?"
    r")\s*$"
)


def comments(source):
    """Yields (line, text, is_doc) for every comment, skipping strings.

    Dart strings may be raw (r'...'), triple-quoted, and interpolated with
    ${...} that itself holds strings, so a stack tracks where each
    interpolation's braces close.
    """
    i, n, line = 0, len(source), 1
    stack = []  # open strings: (quote, raw); interpolations push None

    def count(text):
        return text.count("\n")

    while i < n:
        top = stack[-1] if stack else None
        if top is not None and top[0] != "{":
            quote, raw = top
            if source.startswith(quote, i):
                stack.pop()
                i += len(quote)
                continue
            c = source[i]
            if not raw and c == "\\":
                line += count(source[i : i + 2])
                i += 2
                continue
            if not raw and source.startswith("${", i):
                stack.append(("{", 0))
                i += 2
                continue
            line += c == "\n"
            i += 1
            continue

        c = source[i]
        if source.startswith("//", i):
            end = source.find("\n", i)
            end = n if end < 0 else end
            text = source[i:end]
            yield line, text, text.startswith("///")
            i = end
            continue
        if source.startswith("/*", i):
            depth, j = 1, i + 2
            while j < n and depth:
                if source.startswith("/*", j):
                    depth, j = depth + 1, j + 2
                elif source.startswith("*/", j):
                    depth, j = depth - 1, j + 2
                else:
                    j += 1
            text = source[i:j]
            yield line, text, text.startswith("/**")
            line += count(text)
            i = j
            continue
        if top is not None and top[0] == "{":
            if c == "{":
                stack[-1] = ("{", top[1] + 1)
            elif c == "}":
                if top[1] == 0:
                    stack.pop()
                    i += 1
                    continue
                stack[-1] = ("{", top[1] - 1)
        raw = False
        start = i
        if c in "rR" and i + 1 < n and source[i + 1] in "'\"" and (
            i == 0 or not (source[i - 1].isalnum() or source[i - 1] in "_$")
        ):
            raw, start = True, i + 1
        if source[start] in "'\"":
            q = source[start]
            quote = q * 3 if source.startswith(q * 3, start) else q
            stack.append((quote, raw))
            i = start + len(quote)
            continue
        line += c == "\n"
        i += 1


def check(path, source):
    found = []
    for line, text, is_doc in comments(source):
        for offset, row in enumerate(text.split("\n")):
            at = f"{path}:{line + offset}"
            body = re.sub(r"^\s*(?:/{2,3}|/\*+|\*+/?)", "", row).strip()
            if ARABIC.search(row):
                found.append(f"{at}: Arabic in a comment: {body[:90]}")
            if MARKER.search(row) and not TRACKED.search(row):
                found.append(f"{at}: untracked marker: {body[:90]}")
            if not is_doc and text.startswith("//") and CODE.match(body):
                found.append(f"{at}: commented-out code: {body[:90]}")
    return found


def main():
    files = subprocess.run(
        ["git", "ls-files", "apps/*.dart", "packages/*.dart"],
        capture_output=True, text=True, encoding="utf-8", check=True,
    ).stdout.split()
    files = [f for f in files if "/generated/" not in f and not f.endswith(".g.dart")]
    problems = []
    for path in files:
        with open(path, encoding="utf-8") as handle:
            problems += check(path, handle.read())
    for problem in problems:
        print(problem)
    print(f"comments: {len(files)} files - problems: {len(problems)}")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
