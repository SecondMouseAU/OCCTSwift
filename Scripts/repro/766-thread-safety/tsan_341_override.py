#!/usr/bin/env python3
"""#341 race-level Red: link the 341 TSan harness against the TSan kernel with three of patch 0011's four
TUs replaced by their pre-0011 (vanilla V8_0_1) versions. Prints the commands it runs."""
import os, re, shutil, subprocess, sys, glob
# Run from the repo root: python3 Scripts/repro/766-thread-safety/tsan_341_override.py prep|patched|vanilla
# LIBRARIES points at the checkout holding occt-src (patched) and occt-install-tsan
# (Scripts/tsan-stress.sh build); a linked worktree has neither, so pass the main checkout's.
WT = os.getcwd()
LIB = os.environ.get("LIBRARIES", WT + "/Libraries")
SRC = LIB + "/occt-src"
INST = LIB + "/occt-install-tsan"
O = os.environ.get("OUT", "/tmp/occt766-341-override")
PATCH = WT + "/Scripts/patches/0011-XCAFDoc_ShapeTool-AutoNamingScope-341.patch"

def run(cmd, **kw):
    print("+", " ".join(cmd) if isinstance(cmd, list) else cmd, flush=True)
    return subprocess.run(cmd, **kw)

stage = sys.argv[1]
# The glTF reader is also in patch 0011 but TKDEGLTF is not in the minimal TSan build, and the OBJ
# harness never reaches it, so only the other three TUs are replaced.
sdk = subprocess.check_output(["xcrun", "--sdk", "macosx", "--show-sdk-path"], text=True).strip()
cxx = subprocess.check_output(["xcrun", "--find", "clang++"], text=True).strip()
inc = INST + "/include/opencascade"
if not os.path.isdir(inc):
    inc = INST + "/include"
libs = sorted(glob.glob(INST + "/lib/libTK*.a"))
libflags = ["-l" + os.path.basename(l)[3:-2] for l in libs]

if stage == "prep":
    files = re.findall(r"^\+\+\+ b/(\S+)", open(PATCH).read(), re.M)
    shutil.rmtree(O, ignore_errors=True)
    for f in files:
        os.makedirs(os.path.join(O, os.path.dirname(f)), exist_ok=True)
        shutil.copy(os.path.join(SRC, f), os.path.join(O, f))
    r = run(["patch", "-R", "-p1", "-i", PATCH], cwd=O)
    os.makedirs(O + "/vinc", exist_ok=True)
    for f in files:
        if f.endswith(".hxx"):
            shutil.copy(os.path.join(O, f), O + "/vinc/")
    objs = []
    for f in files:
        if f.endswith(".cxx") and "RWGltf" not in f:
            ob = O + "/" + os.path.basename(f)[:-4] + ".o"
            r = run([cxx, "-std=c++17", "-fsanitize=thread", "-g", "-O1", "-w", "-isysroot", sdk,
                     "-I" + O + "/vinc", "-I" + inc, "-c", os.path.join(O, f), "-o", ob])
            if r.returncode: sys.exit(r.returncode)
            objs.append(ob)
    print("objects:", objs)
elif stage in ("vanilla", "patched"):
    h = WT + "/Scripts/repro/341-meshcaf/occt_341_stress.cpp"
    extra = sorted(glob.glob(O + "/*.o")) if stage == "vanilla" else []
    incs = (["-I" + O + "/vinc"] if stage == "vanilla" else []) + ["-I" + inc]
    out = O + "/h341_" + stage
    r = run([cxx, "-std=c++17", "-fsanitize=thread", "-g", "-O1", "-w", "-isysroot", sdk] + incs +
            [h] + extra + ["-L" + INST + "/lib", "-o", out] + libflags + ["-lz", "-lc++", "-framework", "Foundation"])
    if r.returncode: sys.exit(r.returncode)
    os.makedirs(O + "/scratch-" + stage, exist_ok=True)
    env = dict(os.environ, MMGT_OPT="0",
               TSAN_OPTIONS="halt_on_error=0:exitcode=66:suppressions=" + WT + "/Scripts/tsan.supp")
    log = O + "/h341_" + stage + ".log"
    with open(log, "w") as fp:
        r = run([out, "obj_roundtrip_unique", "8", "25", O + "/scratch-" + stage], env=env,
                stdout=fp, stderr=subprocess.STDOUT)
    txt = open(log).read()
    print(stage, "exit", r.returncode, "tsan warnings", txt.count("WARNING: ThreadSanitizer"))
    for s in sorted(set(re.findall(r"SUMMARY: ThreadSanitizer: .*", txt)))[:8]:
        print("  ", s)
