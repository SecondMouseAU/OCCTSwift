#!/usr/bin/env python3
"""Run a probe binary in N fresh processes and tabulate exit codes.

usage: harness.py <runs> <binary> <threads> [warm]
Prints one line: clean, wrong vertex (exit 1), and each signal that killed the process.
Runs 8 processes at a time; the race is within a process, so the concurrency here only adds load.
"""
import collections
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor

runs, binary, *args = sys.argv[1:]


def one(_):
    return subprocess.run([binary, *args], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode


with ThreadPoolExecutor(8) as ex:
    codes = collections.Counter(ex.map(one, range(int(runs))))
sig = {-5: "SIGTRAP", -6: "SIGABRT", -9: "SIGKILL", -10: "SIGBUS", -11: "SIGSEGV"}
parts = [f"clean={codes.pop(0, 0)}", f"wrong-vertex={codes.pop(1, 0)}"]
for c in sorted(codes):
    parts.append(f"{sig.get(c, 'exit ' + str(c))}={codes[c]}")
print(f"threads={args[0]} {' '.join(args[1:]) or 'cold'} runs={runs}: " + " ".join(parts))
sys.exit(0 if len(parts) == 2 and parts[0] != "clean=0" and parts[1] == "wrong-vertex=0" else 1)
