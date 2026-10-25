# #3496: a trim parameter that is not a number

Evidence for carried patch `0075` (`Scripts/patches/README.md` has the write-up).

The reproducer is `Tests/OCCTIOTests/BREP/BREPKernelTrimParameterTests.swift`: a box with one trimmed
curve or surface record added to a table no shape refers to, whose parameters are `nan` or `inf`
(`10 nan nan 0 4` on a cylinder is the case in the issue). Run it with `OCCTSWIFT_LOCAL=1` against a
kernel with and without `0075`; `Scripts/repro/3494/stage.sh` stages a kernel from the patches in a
few seconds.

Without the patch (kernel.7 flags, the three translation units rebuilt from the unpatched source):
the control passes, the periodic test ends the test process (exit -4) and the non-periodic test does
not return in 90 s. With it, all three pass: the reader drops the record and the box reads as before.
