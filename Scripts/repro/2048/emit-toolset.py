#!/usr/bin/env python3
"""Writes one toolset file for Scripts/repro/2048/run.sh.

A toolset is the CONSUMER's file. It is where a flag with no safe manifest spelling can live
without making the package it applies to unresolvable, which is the whole of #2048's question.

Arguments: <out> <eh-library-dir> <checkout-library-dir> <count of cxx options> <cxx...> <cc...>
"""
import json
import sys


def main() -> int:
    out, eh_dir, lib_dir, n_cxx = sys.argv[1], sys.argv[2], sys.argv[3], int(sys.argv[4])
    rest = sys.argv[5:]
    cxx, cc = rest[:n_cxx], rest[n_cxx:]
    # A tool with an empty extraCLIOptions is refused outright ("Toolset configuration ... has at
    # least one tool with no properties"), so a tool with nothing to say is left out of the file
    # rather than written empty.
    toolset = {
        "schemaVersion": "1.0",
        "linker": {"extraCLIOptions": ["-L" + eh_dir, "-L" + lib_dir]},
    }
    if cc:
        toolset["cCompiler"] = {"extraCLIOptions": cc}
    if cxx:
        toolset["cxxCompiler"] = {"extraCLIOptions": cxx}
    with open(out, "w") as handle:
        json.dump(toolset, handle, indent=2)
    return 0


if __name__ == "__main__":
    sys.exit(main())
