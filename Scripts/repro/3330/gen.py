# Generates the corrupt-file corpus for Scripts/repro/3330/probe.mm (#3330).
# Usage: WORK=<dir containing the built probe> python3 gen.py   -> <WORK>/fuzz/*, <WORK>/list.txt
# XML garbage-appended and byte-flipped files are left out of the list the SIGSEGV count uses:
# they spin LDOM (the #3318 hang), which is a different defect.
import os, random, subprocess, sys
W = os.environ.get('WORK', '.')
D = os.path.join(W, 'fuzz')
os.makedirs(D, exist_ok=True)
probe = os.path.join(W, 'probe')  # the probe built from probe.mm, either kernel
fmts = {'BinOcaf': 'xbf', 'BinXCAF': 'xbf', 'XmlOcaf': 'xml', 'XmlXCAF': 'xml'}
out = []
rnd = random.Random(3330)
def emit(name, data):
    p = os.path.join(D, name)
    open(p, 'wb').write(data)
    out.append(p)
for f, ext in fmts.items():
    src = os.path.join(D, 'src_' + f + '.' + ext)
    subprocess.run([probe, src, f], check=True, capture_output=True)
    import glob
    real = [g for g in glob.glob(src + '*') if g != src][0] if not os.path.exists(src) else src
    full = open(real, 'rb').read()
    print(f, os.path.basename(real), len(full))
    n = len(full)
    lens = set(range(0, min(n, 400))) | set(range(0, n, max(1, n // 60)))
    # a prefix that ends inside the XML declaration spins LDOM forever (the #3318 hang, not this issue)
    decl = full.find(b'?>') + 2 if ext == 'xml' else 0
    for L in sorted(lens):
        if ext == 'xml' and 0 < L < decl:
            continue
        emit(f'{f}_trunc{L}.{ext}', full[:L])
    for L in (8, 16, 24, 40, 64, 100):
        if L < n:
            if ext == 'xbf':
                emit(f'{f}_garb{L}.{ext}', full[:L] + b'\xff' * 200)
                emit(f'{f}_zero{L}.{ext}', full[:L] + b'\x00' * 200)
    for i in range(60 if ext == 'xbf' else 0):
        b = bytearray(full)
        for _ in range(rnd.randint(1, 4)):
            b[rnd.randrange(0, min(n, 300))] = rnd.randrange(256)
        emit(f'{f}_flip{i}.{ext}', bytes(b))
    # wrong format: this content under the other extension, and as .cbf/.dat/.xcaf
    for e2 in ('xbf', 'xml', 'cbf', 'dat'):
        emit(f'{f}_as.{e2}', full)
emit('empty.xbf', b'')
emit('empty.xml', b'')
emit('empty.cbf', b'')
emit('text.xbf', b'hello, this is not OCAF\n')
emit('text.xml', b'hello, this is not OCAF\n')
emit('binfile.xbf', b'BINFILE')
emit('xmlbinformat.xml', b'<?xml version="1.0"?>\n<document format="BinOcaf"><label tag="0"/></document>')
emit('xmlnoformat.xml', b'<?xml version="1.0"?>\n<document></document>')
emit('xmlunk.xml', b'<?xml version="1.0"?>\n<document format="Nope"></document>')
emit('magic_garbage.xbf', b'BINFILE' + bytes(range(256)))
emit('magic_garbage2.xbf', b'BINFILE\n' + b'\xff' * 500)
emit('ffs.xbf', b'\xff' * 400)
emit('zeros.xbf', b'\x00' * 400)
open(os.path.join(W, 'list.txt'), 'w').write('\n'.join(out) + '\n')
print(len(out))
