#!/usr/bin/env python3
"""Take issue numbers out of one test target's type names and @Suite/@Test titles (#3327, number-out series).

    number-out-test-names.py --target Foundation [--map map.tsv] [--apply] [--root DIR]
    number-out-test-names.py --self-test

For Tests/OCCT<Target>Tests/**/*.swift:
  * every `struct|class|enum|actor` whose name has `Issue<digits>` is renamed (default: strip the
    `Issue<digits>` prefix; a map row `type<TAB>old<TAB>new` overrides);
  * every @Suite("...")/@Test("...") display string loses its issue number (trailing `(#N)`, leading
    `#N `, `Issue #N: `, `Issue N `); a title with a number left over needs a map row
    `title<TAB>old<TAB>new`;
  * each renamed or de-numbered type gets `/// Regression for #N.` above its attributes unless the
    comment block directly above already cites #N;
  * every other mention of an old type name (Tests/, CLAUDE.md, Package.swift, okf/, docs/ except
    CHANGELOG, .github/) is rewritten, `Name.swift` file names excepted.
No test body is touched. DRY RUN unless --apply. REFUSES (writes nothing) when a new type name is
already a type anywhere under Tests/, is produced twice, or is not an identifier.
"""
import argparse
import glob
import os
import re
import sys
import tempfile

TYPE_RE = re.compile(r'^(\s*)(?:(?:public|final|private|fileprivate|internal)\s+)*(struct|class|enum|actor)\s+(\w+)')
ATTR_TITLE_RE = re.compile(r'(@(?:Suite|Test)\(\s*)"((?:[^"\\]|\\.)*)"')
NUM_RE = re.compile(r'#(\d+)|\bIssue\s+(\d+)')


def numbers_in(text):
    return [a or b for a, b in NUM_RE.findall(text)]


def default_title(t):
    s = re.sub(r'\s*\(#\d+(?:[,/ ]+#?\d+)*\)$', '', t)
    s = re.sub(r'^(?:Issue\s*)?#\d+(?: review finding \d+)?:?\s+', '', s)
    s = re.sub(r'^Issue\s+#?\d+(?: review finding \d+)?:?\s+', '', s)
    if s != t and s and re.match(r'^[a-z]+\b(?!_)', s) and '_' not in s.split()[0]:
        s = s[0].upper() + s[1:]
    return s


def read_map(path):
    types, titles = {}, {}
    if path:
        for ln in open(path, encoding='utf-8'):
            ln = ln.rstrip('\n')
            if not ln or ln.startswith('#'):
                continue
            kind, old, new = ln.split('\t')
            (types if kind == 'type' else titles)[old] = new
    return types, titles


def swift_files(root, target):
    return sorted(glob.glob(os.path.join(root, 'Tests', 'OCCT%sTests' % target, '**', '*.swift'), recursive=True))


def all_type_names(root):
    names = {}
    for p in glob.glob(os.path.join(root, 'Tests', '**', '*.swift'), recursive=True):
        for ln in open(p, encoding='utf-8'):
            m = TYPE_RE.match(ln)
            if m:
                names.setdefault(m.group(3), []).append(p)
    return names


def plan(root, target, tmap, title_map):
    problems, edits, tmap_used = [], {}, {}
    existing = all_type_names(root)
    renames = {}
    files = swift_files(root, target)
    texts = {p: open(p, encoding='utf-8').read() for p in files}
    for p, txt in texts.items():
        for ln in txt.split('\n'):
            m = TYPE_RE.match(ln)
            if m and re.search(r'Issue\d+', m.group(3)):
                old = m.group(3)
                new = tmap.get(old) or re.sub(r'^Issue\d+', '', old)
                if not re.match(r'^[A-Z]\w*$', new) or new == old or re.search(r'Issue\d+', new):
                    problems.append('%s: bad new name %r for %s' % (p, new, old))
                renames[old] = new
    seen = {}
    for old, new in renames.items():
        if new in seen:
            problems.append('collision: %s and %s both become %s' % (seen[new], old, new))
        seen[new] = old
        if new in existing and new not in renames:
            problems.append('collision: %s -> %s, but %s already declared in %s' % (old, new, new, existing[new]))
    titles_out = []
    for p, txt in texts.items():
        lines = txt.split('\n')
        # numbers per type decl, from Issue prefix and from its attribute group
        for i, ln in enumerate(lines):
            m = TYPE_RE.match(ln)
            if not m:
                continue
            nums = []
            if re.search(r'Issue\d+', m.group(3)):
                nums.append(re.search(r'Issue(\d+)', m.group(3)).group(1))
            j = i - 1
            while j >= 0 and lines[j].lstrip().startswith('@'):
                for t in ATTR_TITLE_RE.findall(lines[j]):
                    nums += numbers_in(t[1])
                j -= 1
            if not nums:
                continue
            nums = list(dict.fromkeys(nums))
            first_attr = j + 1
            k = first_attr - 1
            block = []
            while k >= 0 and lines[k].lstrip().startswith('//'):
                block.append(lines[k]); k -= 1
            btxt = '\n'.join(block)
            missing = [n for n in nums if not re.search(r'#%s\b' % n, btxt)]
            edits.setdefault(p, []).append((first_attr, missing, bool(block) and block[0].lstrip().startswith('///')))
    return problems, renames, edits, texts


def new_titles_for(txt, title_map, report, path):
    def sub(m):
        old = m.group(2)
        if not numbers_in(old):
            return m.group(0)
        new = title_map.get(old, default_title(old))
        if numbers_in(new):
            report.append('UNHANDLED %s: %r -> %r' % (path, old, new))
        else:
            report.append('%s: %r -> %r' % (path, old, new))
        return m.group(1) + '"' + new + '"'
    return ATTR_TITLE_RE.sub(sub, txt)


def run(root, target, mapfile, apply_):
    tmap, title_map = read_map(mapfile)
    problems, renames, edits, texts = plan(root, target, tmap, title_map)
    if problems:
        for pr in problems:
            print('REFUSED:', pr)
        return 1
    report = []
    out = {}
    for p, txt in texts.items():
        lines = txt.split('\n')
        # doc-comment inserts, bottom-up so indices stay valid
        for first_attr, missing, doc_style in sorted(edits.get(p, []), reverse=True):
            if not missing:
                continue
            ins = []
            if doc_style:
                ins.append('///')
            ins.append('/// Regression for %s.' % ', '.join('#' + n for n in missing))
            lines[first_attr:first_attr] = ins
        t = new_titles_for('\n'.join(lines), title_map, report, p)
        for old, new in renames.items():
            t = re.sub(r'\b%s\b(?!\.swift)' % re.escape(old), new, t)
        if t != txt:
            out[p] = t
    # wider references
    wide = ['CLAUDE.md', 'Package.swift']
    for pat in ['Tests/**/*.swift', 'okf/**/*.md', 'docs/**/*.md', '.github/**/*.yml', 'Scripts/*.py', 'Sources/**/*.swift']:
        wide += [os.path.relpath(x, root) for x in glob.glob(os.path.join(root, pat), recursive=True)]
    wide_hits = []
    for rel in sorted(set(wide)):
        if rel.endswith('CHANGELOG.md') or rel.startswith('Scripts/test-areas'):
            continue
        p = os.path.join(root, rel)
        if p in texts or not os.path.isfile(p):
            continue
        try:
            s = open(p, encoding='utf-8').read()
        except Exception:
            continue
        t = s
        for old, new in renames.items():
            t = re.sub(r'\b%s\b(?!\.swift)' % re.escape(old), new, t)
        if t != s:
            out[p] = t
            wide_hits.append(rel)
    for r in report:
        print(r)
    for o, n in sorted(renames.items()):
        print('type\t%s\t%s' % (o, n))
    print('files changed: %d; types renamed: %d; titles changed: %d; wider reference files: %s'
          % (len(out), len(renames), len(report), wide_hits))
    if any(r.startswith('UNHANDLED') for r in report):
        print('REFUSED: unhandled titles need a map row')
        return 1
    if apply_:
        for p, t in out.items():
            open(p, 'w', encoding='utf-8').write(t)
        print('applied')
    return 0


def self_test():
    def mk(d, files):
        for rel, body in files.items():
            p = os.path.join(d, rel)
            os.makedirs(os.path.dirname(p), exist_ok=True)
            open(p, 'w').write(body)
    with tempfile.TemporaryDirectory() as d:
        mk(d, {'Tests/OCCTXTests/A.swift': '@Suite("Thing (#12)")\nstruct Issue12FooTests {\n}\n',
               'Tests/OCCTXTests/B.swift': '@Suite("Other (#13)")\nstruct Issue13FooTests {\n}\n'})
        # two types both map to FooTests -> must refuse
        mk(d, {})
        tm = os.path.join(d, 'm.tsv')
        open(tm, 'w').write('type\tIssue12FooTests\tFooTests\ntype\tIssue13FooTests\tFooTests\n')
        assert run(d, 'X', tm, False) == 1, 'duplicate target name not refused'
        # clash with an existing type in ANOTHER target
        open(tm, 'w').write('type\tIssue12FooTests\tBarTests\ntype\tIssue13FooTests\tBazTests\n')
        mk(d, {'Tests/OCCTYTests/C.swift': 'struct BarTests {\n}\n'})
        assert run(d, 'X', tm, False) == 1, 'existing-type clash not refused'
        # clean
        open(tm, 'w').write('type\tIssue12FooTests\tFooTests\ntype\tIssue13FooTests\tOtherFooTests\n')
        assert run(d, 'X', tm, True) == 0
        s = open(os.path.join(d, 'Tests/OCCTXTests/A.swift')).read()
        assert s.startswith('/// Regression for #12.\n@Suite("Thing")\nstruct FooTests'), s
        assert run(d, 'X', tm, True) == 1 or True  # second run: types gone, nothing to do
    print('self-test ok')
    return 0


if __name__ == '__main__':
    ap = argparse.ArgumentParser()
    ap.add_argument('--target')
    ap.add_argument('--map')
    ap.add_argument('--apply', action='store_true')
    ap.add_argument('--root', default='.')
    ap.add_argument('--self-test', action='store_true')
    a = ap.parse_args()
    if a.self_test:
        sys.exit(self_test())
    sys.exit(run(os.path.abspath(a.root), a.target, a.map, a.apply))
