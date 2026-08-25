#!/usr/bin/env python3
"""Install the pinned clang-format binary, using nothing but the Python standard library.

Why this exists rather than `pip install clang-format==<pin>`: a container image is not guaranteed
to have pip, venv or ensurepip, and the failure is not obvious when it happens. Debian and Ubuntu
ship a `python3` whose `ensurepip` is split into a separate `python3.N-venv` package, so
`python3 -m venv` fails with "ensurepip is not available", and the fix it suggests
(`apt install python3-venv`) can itself have no installation candidate depending on the image's apt
sources. Newer distros add PEP 668 on top, which makes a plain `pip install` refuse to touch the
system environment at all.

This script sidesteps all of it. A clang-format wheel on PyPI is a zip holding one static binary at
`clang_format/data/bin/clang-format`; `urllib` fetches it and `zipfile` unpacks it, both stdlib. No
pip, no venv, no curl, no unzip, no apt, and the artifact is the same one CI installs.

    Scripts/install-clang-format.py                          # -> /usr/local/bin/clang-format
    Scripts/install-clang-format.py --dest ~/.local/bin/clang-format
    Scripts/install-clang-format.py --version 22.1.8         # outside a checkout
    Scripts/install-clang-format.py --print-url              # resolve only, download nothing

The version comes from Scripts/clang-format-version.txt unless --version overrides it, so a bump to
the pin reaches every environment that runs this without anyone editing a second copy. See
docs/guides/clang-format-setup.md for the other routes and when to prefer them.
"""

import argparse
import hashlib
import io
import json
import os
import platform
import stat
import subprocess
import sys
import urllib.request
import zipfile

BINARY_IN_WHEEL = "clang_format/data/bin/clang-format"
PYPI = "https://pypi.org/pypi/clang-format/{version}/json"


def pinned_version(repo_root):
    """Read Scripts/clang-format-version.txt: comments and blank lines out, first line left."""
    path = os.path.join(repo_root, "Scripts", "clang-format-version.txt")
    if not os.path.exists(path):
        return None
    with open(path) as handle:
        for line in handle:
            line = line.strip()
            if line and not line.startswith("#"):
                return line
    return None


def repo_root():
    try:
        out = subprocess.run(
            ["git", "rev-parse", "--show-toplevel"],
            capture_output=True, text=True, check=True,
        )
        return out.stdout.strip()
    except (subprocess.CalledProcessError, FileNotFoundError):
        return None


def platform_tag():
    """The (wheel-family, machine) pair identifying this host's wheel.

    musl matters because a manylinux binary is dynamically linked against glibc and simply will not
    run on Alpine; the failure is an exec-format or missing-loader error at first use, well after
    install, so it is worth getting right here.
    """
    machine = platform.machine()
    if sys.platform == "darwin":
        return "macosx", machine
    if sys.platform.startswith("linux"):
        family = "musllinux" if os.path.exists("/etc/alpine-release") else "manylinux"
        return family, machine
    if sys.platform.startswith("win"):
        return "win", "amd64" if machine in ("AMD64", "x86_64") else machine
    sys.exit(f"install-clang-format: unsupported platform {sys.platform!r}")


def resolve(version):
    """Pick this host's wheel out of the release, and return (url, sha256, filename)."""
    with urllib.request.urlopen(PYPI.format(version=version)) as response:
        release = json.load(response)

    family, machine = platform_tag()
    matches = [
        entry for entry in release["urls"]
        if family in entry["filename"] and machine in entry["filename"]
    ]
    if not matches:
        available = sorted(entry["filename"] for entry in release["urls"])
        sys.exit(
            f"install-clang-format: no clang-format {version} wheel for {family}/{machine}.\n"
            "Available:\n  " + "\n  ".join(available)
        )
    if len(matches) > 1:
        # Never seen in practice: one wheel per (family, machine) across every version checked.
        # Reported rather than silently taking [0], since picking the wrong one here installs a
        # binary that runs and formats differently.
        sys.exit(
            f"install-clang-format: {len(matches)} candidate wheels for {family}/{machine}, "
            "cannot choose:\n  " + "\n  ".join(m["filename"] for m in matches)
        )
    entry = matches[0]
    return entry["url"], entry["digests"]["sha256"], entry["filename"]


def install(url, sha256, dest):
    with urllib.request.urlopen(url) as response:
        payload = response.read()

    actual = hashlib.sha256(payload).hexdigest()
    if actual != sha256:
        sys.exit(
            "install-clang-format: sha256 mismatch, refusing to install.\n"
            f"  expected {sha256}\n  got      {actual}"
        )

    with zipfile.ZipFile(io.BytesIO(payload)) as wheel:
        if BINARY_IN_WHEEL not in wheel.namelist():
            sys.exit(
                f"install-clang-format: {BINARY_IN_WHEEL} not in the wheel; its layout changed.\n"
                "Contents:\n  " + "\n  ".join(wheel.namelist())
            )
        binary = wheel.read(BINARY_IN_WHEEL)

    parent = os.path.dirname(os.path.abspath(dest))
    os.makedirs(parent, exist_ok=True)
    # Write then rename, so a half-written file can never be found on PATH and executed.
    staging = dest + ".partial"
    with open(staging, "wb") as handle:
        handle.write(binary)
    os.chmod(staging, os.stat(staging).st_mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)
    os.replace(staging, dest)


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--dest", default="/usr/local/bin/clang-format",
                        help="where to write the binary (default: %(default)s)")
    parser.add_argument("--version", default=None,
                        help="override Scripts/clang-format-version.txt (needed outside a checkout)")
    parser.add_argument("--print-url", action="store_true",
                        help="resolve and print the wheel URL, install nothing")
    args = parser.parse_args()

    version = args.version
    if version is None:
        root = repo_root()
        version = pinned_version(root) if root else None
    if not version:
        sys.exit(
            "install-clang-format: no version. Run this from an OCCTSwift checkout so it can read\n"
            "Scripts/clang-format-version.txt, or pass --version X.Y.Z explicitly."
        )

    url, sha256, filename = resolve(version)
    if args.print_url:
        print(url)
        return 0

    install(url, sha256, args.dest)

    # Prove the thing we just installed actually runs and reports the version asked for. An
    # installer that reports success without doing this is how a wrong-architecture binary reaches
    # a PATH and fails much later, somewhere less obvious.
    try:
        out = subprocess.run([args.dest, "--version"], capture_output=True, text=True, check=True)
    except (subprocess.CalledProcessError, OSError) as exc:
        sys.exit(f"install-clang-format: installed {args.dest} but it will not run: {exc}")
    reported = out.stdout.strip()
    if version not in reported:
        sys.exit(f"install-clang-format: installed {filename} but it reports {reported!r}")

    print(f"install-clang-format: {reported}  ->  {args.dest}")
    if os.path.dirname(os.path.abspath(args.dest)) not in os.environ.get("PATH", "").split(os.pathsep):
        print(f"install-clang-format: note: {os.path.dirname(os.path.abspath(args.dest))} "
              "is not on PATH in this shell.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
