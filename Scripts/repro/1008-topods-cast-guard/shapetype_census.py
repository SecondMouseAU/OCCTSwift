#!/usr/bin/env python3
"""Bridge functions that read ShapeType() off a caller-supplied shape with no IsNull() anywhere.

TopoDS_Shape::ShapeType() is `myTShape->ShapeType()` with no null test, so on a Shape wrapping a
null TopoDS_Shape (which Shape.nullified returns by construction) it is a SIGSEGV that no
catch (...) can absorb.
"""
import re
import sys
from pathlib import Path

SRC = Path(sys.argv[1])
SIG = re.compile(r'^[A-Za-z_][\w:<>,\* ]*\s[\*&]?\s*(OCCT[A-Za-z0-9_]*)\s*\(')

hits = []
total = 0
for path in sorted(SRC.glob('*.mm')):
    lines = path.read_text().splitlines()
    i = 0
    while i < len(lines):
        m = SIG.match(lines[i])
        if not m:
            i += 1
            continue
        name = m.group(1)
        j = i
        while j < len(lines) and '{' not in lines[j]:
            j += 1
        depth = 0
        body = []
        started = False
        while j < len(lines):
            depth += lines[j].count('{') - lines[j].count('}')
            body.append(lines[j])
            if lines[j].count('{'):
                started = True
            if started and depth <= 0:
                break
            j += 1
        text = '\n'.join(body)
        if re.search(r'->shape\.ShapeType\(\)', text):
            total += 1
            if 'IsNull()' not in text:
                hits.append((path.name, i + 1, name))
        i = j + 1

print(f'{total} bridge functions read ShapeType() off a caller-supplied shape')
print(f'{len(hits)} of them contain no IsNull() anywhere in the body\n')
for name, line, fn in hits:
    print(f'{name}:{line}  {fn}')
