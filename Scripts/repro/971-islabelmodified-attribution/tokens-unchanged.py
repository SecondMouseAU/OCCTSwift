#!/usr/bin/env python3
"""Prove a clang-format reformat changed no code.

Splits a C/C++/ObjC++ translation unit into two streams with a scanner that
understands string and character literals (so a `//` inside a string is not a
comment) and line continuations:

  - the CODE stream: everything outside a comment, with every run of whitespace
    collapsed to a single space and leading/trailing space stripped.
  - the COMMENT stream: the text of every comment, with the leading `//`/`///`
    or `/*`/`*/` markers and per-line `*` prefixes removed, whitespace
    collapsed.

clang-format may reflow comments, so the comment streams are compared after
whitespace collapsing (a reflow moves line breaks, which are whitespace). The
code stream must be byte-identical: any difference is a token that moved,
appeared or vanished, which a formatter must never do.
"""
import re
import sys


def split(src):
    code, comments = [], []
    i, n = 0, len(src)
    while i < n:
        c = src[i]
        if c == '"' or c == "'":
            q = c
            j = i + 1
            while j < n:
                if src[j] == '\\':
                    j += 2
                    continue
                if src[j] == q:
                    j += 1
                    break
                if src[j] == '\n' and q == '"':
                    break  # unterminated; bail out conservatively
                j += 1
            code.append(src[i:j])
            i = j
        elif src.startswith('//', i):
            j = i
            while j < n:
                if src[j] == '\n' and src[j - 1] != '\\':
                    break
                j += 1
            comments.append(src[i + 2:j])
            code.append('\n')
            i = j
        elif src.startswith('/*', i):
            j = src.find('*/', i + 2)
            j = n if j < 0 else j + 2
            comments.append(src[i + 2:j - 2])
            code.append(' ')
            i = j
        else:
            code.append(c)
            i += 1
    return ''.join(code), '\n'.join(comments)


TOKEN = re.compile(r'''
      [A-Za-z_][A-Za-z_0-9]*                 # identifier / keyword
    | (?:\d|\.\d)[A-Za-z_0-9.]*(?:[eEpP][+-]?[A-Za-z_0-9.]*)?   # pp-number
    | "(?:\\.|[^"\\])*"                      # string literal
    | '(?:\\.|[^'\\])*'                      # char literal
    | \S                                     # any other single punctuator char
''', re.X)


def norm_code(s):
    """The token sequence, whitespace discarded entirely.

    Whitespace BETWEEN tokens is formatting, not code: `double *_Nonnull` and
    `double* _Nonnull` are the same three tokens. Collapsing runs of whitespace
    to one space instead of dropping it would report every pointer-star move as
    a code change, which is the opposite of what this is for.
    """
    return '\x1f'.join(TOKEN.findall(s))


def norm_comment(s):
    s = re.sub(r'^[ \t]*[*/]+', '', s, flags=re.M)   # ` * ` and `///` leaders
    return re.sub(r'\s+', ' ', s).strip()


def main(a, b):
    ca, ka = split(open(a, encoding='utf-8').read())
    cb, kb = split(open(b, encoding='utf-8').read())
    na, nb = norm_code(ca), norm_code(cb)
    ma, mb = norm_comment(ka), norm_comment(kb)
    ok = True
    if na == nb:
        print(f'CODE      identical: {len(na)} chars of normalized non-comment text')
    else:
        ok = False
        print('CODE      DIFFERS')
        for k in range(min(len(na), len(nb))):
            if na[k] != nb[k]:
                print(f'  first divergence at char {k}:')
                print(f'    a: ...{na[max(0,k-70):k+70]!r}')
                print(f'    b: ...{nb[max(0,k-70):k+70]!r}')
                break
        else:
            print(f'  one is a prefix of the other: {len(na)} vs {len(nb)} chars')
    if ma == mb:
        print(f'COMMENTS  identical after whitespace collapse: {len(ma)} chars')
    else:
        print('COMMENTS  differ after whitespace collapse (reflow or real edit)')
        for k in range(min(len(ma), len(mb))):
            if ma[k] != mb[k]:
                print(f'  first divergence at char {k}:')
                print(f'    a: ...{ma[max(0,k-90):k+90]!r}')
                print(f'    b: ...{mb[max(0,k-90):k+90]!r}')
                break
        else:
            print(f'  one is a prefix of the other: {len(ma)} vs {len(mb)} chars')
    return 0 if ok else 1


FIXTURE = '''
/// Check if a label is marked as modified (via the TDocStd_Modified attribute on the root label).
bool OCCTDocumentIsLabelModified(OCCTDocumentRef doc, int64_t labelId);

/* a block comment with a // inside it */
const char *_Nonnull OCCTDocumentGetLabelName(OCCTDocumentRef doc, int64_t labelId);
static const char* kSlashSlashInAString = "not // a comment";
'''


def self_test():
    """Prove the detector catches each way a reformat could change code.

    Reformat-shaped edits (whitespace, pointer-star placement, comment reflow)
    must read as unchanged; token-shaped edits (a rename, a deletion, an added
    qualifier) must read as changed. A comparator that reports "identical" for
    both looks exactly like one reporting it for a genuinely clean reformat.
    """
    cases = [
        # (name, mutated fixture, expect code identical?, expect comments identical?)
        ('unchanged', FIXTURE, True, True),
        ('pointer star moved',
         FIXTURE.replace('char *_Nonnull', 'char* _Nonnull'), True, True),
        ('indented and rewrapped',
         FIXTURE.replace('(OCCTDocumentRef doc,', '(OCCTDocumentRef doc,\n    '), True, True),
        ('comment reflowed onto two lines',
         FIXTURE.replace('(via the TDocStd_Modified attribute on the root label).',
                         '(via the TDocStd_Modified\n/// attribute on the root label).'), True, True),
        ('identifier renamed',
         FIXTURE.replace('int64_t labelId', 'int64_t labelID'), False, True),
        ('declaration deleted',
         FIXTURE.replace('bool OCCTDocumentIsLabelModified(OCCTDocumentRef doc, int64_t labelId);',
                         ''), False, True),
        ('qualifier added',
         FIXTURE.replace('bool OCCTDocumentIsLabelModified', 'extern bool OCCTDocumentIsLabelModified'),
         False, True),
        ('comment word changed',
         FIXTURE.replace('marked as modified', 'flagged as modified'), True, False),
        ('a // inside a string literal is not a comment',
         FIXTURE.replace('"not // a comment"', '"not // a comment either"'), False, True),
    ]
    ok = 0
    for name, mutated, want_code, want_comments in cases:
        ca, ka = split(FIXTURE)
        cb, kb = split(mutated)
        got_code = norm_code(ca) == norm_code(cb)
        got_comments = norm_comment(ka) == norm_comment(kb)
        good = (got_code, got_comments) == (want_code, want_comments)
        ok += good
        print(f'  {"ok  " if good else "FAIL"} {name}: '
              f'code {"same" if got_code else "differs"}, '
              f'comments {"same" if got_comments else "differ"}')
    print(f'{ok}/{len(cases)} cases correct')
    return 0 if ok == len(cases) else 1


if __name__ == '__main__':
    if len(sys.argv) == 2 and sys.argv[1] == '--self-test':
        sys.exit(self_test())
    if len(sys.argv) != 3:
        print(__doc__)
        print('usage: tokens-unchanged.py <before.h> <after.h>')
        print('       tokens-unchanged.py --self-test')
        sys.exit(2)
    sys.exit(main(sys.argv[1], sys.argv[2]))
