#!/bin/bash
# #3139 reproduction. From the repo root: runs the regression suite against the pinned kernel.
# Before the fix: every revolve test fails (Shell, 0 solids, hole a silent no-op).
# measured-before-fix.txt is that failing run (main at 805defec6).
exec swift test --filter Issue3139
