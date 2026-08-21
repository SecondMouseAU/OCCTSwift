"""Replace every em-dash with ordinary punctuation, per okf/policies/writing-style.md.

Rules, in order, from the measured distribution (97.6% spaced `, `; 1761 lines match the
labelled-term template; 909 dashes are followed by a capitalised word):

  COLON   the dash follows a labelled term at the head of a line, list item or table cell.
          That is the `- `param`, description` template docs/reference/ is built on.
  PERIOD  the line carries exactly ONE dash, the next word is capitalised, and the dash is
          NOT inside a code span or an unclosed parenthesis. Both exclusions are measured
          failures of an earlier draft, which produced `contains(uid:). GraphUID` inside
          backticks and a sentence break inside an aside.
  COMMA   everywhere else, including every paired (parenthetical) dash.

A dash following terminal punctuation is dropped rather than doubled; a trailing ` em-dash`
becomes a comma.
"""
import re, subprocess

LABEL = re.compile(r'(^\s*(?:[-*+]\s+|\|\s*|\d+\.\s+|>\s+)?(?:\*\*`[^`]+`\*\*|\*\*[^*\n]+\*\*|`[^`\n]+`)\s*)—\s')
TERMINAL = set(',;:.!?')

def protected(l, i):
    """Inside a code span, or inside an unclosed paren/bracket, at offset i."""
    head = l[:i]
    return (head.count('`') % 2 == 1
            or head.count('(') > head.count(')')
            or head.count('[') > head.count(']'))

def fix_line(l):
    if '—' not in l:
        return l
    l = LABEL.sub(lambda m: m.group(1).rstrip() + ': ', l, count=1)
    if '—' not in l:
        return re.sub(r'[ \t]+$', '', l) if l.strip() else l
    l = re.sub(r'\s+—\s*$', ',', l)
    single = l.count('—') == 1
    out = []
    while '—' in l:
        m = re.search(r'(.?)\s—\s(\S)', l)
        if not m:
            l = l.replace('—', ', '); break
        b = m.group(1).rstrip(); after = m.group(2)
        if b and b[-1] in TERMINAL:
            rep = b + ' ' + after
        elif single and after[:1].isalpha() and after[:1].isupper() and not protected(l, m.start()):
            rep = b + '. ' + after
        else:
            rep = b + ', ' + after
        l = l[:m.start()] + rep + l[m.end():]
    l = re.sub(r'([,:.])\s*,', r'\1', l)
    l = re.sub(r'::+', ':', l) if '::' in l and '`' not in l else l
    l = re.sub(r'\s+,', ',', l)
    return re.sub(r'[ \t]+$', '', l) if l.strip() else l

man = set()
for _m in ("Scripts/style-manifest-swift.txt", "Scripts/style-manifest-bridge.txt"):
    man |= {l.strip() for l in open(_m) if l.strip() and not l.startswith("#")}

# Manifest files are skipped: the ratchet would require bringing each fully lint-clean in the same
# PR, and 7 of the surviving violations are AlwaysUseLowerCamelCase on public enum cases, so that
# is a source-breaking rename. See this directory's README.
files = [f for f in subprocess.run(["git","ls-files"],capture_output=True,text=True).stdout.split("\n")
         if f and not f.startswith("Libraries/") and f not in man]
tot = touched = 0
for f in files:
    try: src = open(f, errors="strict").read()
    except Exception: continue
    if '—' not in src: continue
    n = src.count('—')
    new = "\n".join(fix_line(x) for x in src.split("\n"))
    if new != src:
        open(f, "w").write(new); tot += n; touched += 1
print(f"{tot} replaced across {touched} files; remaining {sum(open(f,errors='ignore').read().count(chr(8212)) for f in files if f)}")
