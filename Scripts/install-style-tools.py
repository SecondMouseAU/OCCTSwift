#!/usr/bin/env python3
"""Install the pinned SwiftLint and swift-format, independent of Homebrew's current formula.

    Scripts/install-style-tools.py --dest ~/.local/bin               # both
    Scripts/install-style-tools.py --tool swiftlint --dest DIR
    Scripts/install-style-tools.py --tool swift-format --dest DIR --workdir DIR2

SwiftLint: downloads the release's portable_swiftlint.zip from GitHub, verifies the sha256 recorded
in Scripts/swiftlint-version.txt, unpacks the binary.
swift-format: publishes no binaries, so this clones the release tag, verifies HEAD is the commit
recorded in Scripts/swift-format-version.txt, and builds `swift-format` in release mode with the
toolchain on PATH (minutes on a cold run; CI caches the result by pin). Requires git and swift.

After either install the binary is run and must report the pinned version, so a wrong download is a
failure here and not a lint diff later. Standard library only.
"""

import argparse
import hashlib
import io
import os
import pathlib
import shutil
import stat
import subprocess
import sys
import tempfile
import urllib.request
import zipfile

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import style_tool_pins as pins  # noqa: E402

SWIFTLINT_URL = 'https://github.com/realm/SwiftLint/releases/download/{v}/portable_swiftlint.zip'
SWIFT_FORMAT_REPO = 'https://github.com/swiftlang/swift-format.git'


def die(msg):
    sys.exit(f'install-style-tools: {msg}')


def put(source, dest_dir, name):
    """Write bytes or copy a file to dest_dir/name via a staging file, executable."""
    dest_dir.mkdir(parents=True, exist_ok=True)
    dest = dest_dir / name
    staging = dest_dir / (name + '.partial')
    if isinstance(source, (bytes, bytearray)):
        staging.write_bytes(source)
    else:
        shutil.copyfile(source, staging)
    staging.chmod(staging.stat().st_mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)
    os.replace(staging, dest)
    return dest


def install_swiftlint(dest_dir):
    version, sha256 = pins.read_pin('swiftlint')
    with urllib.request.urlopen(SWIFTLINT_URL.format(v=version)) as response:
        payload = response.read()
    actual = hashlib.sha256(payload).hexdigest()
    if actual != sha256:
        die(f'swiftlint {version} sha256 mismatch, refusing to install.\n'
            f'  expected {sha256}\n  got      {actual}')
    with zipfile.ZipFile(io.BytesIO(payload)) as archive:
        if 'swiftlint' not in archive.namelist():
            die('swiftlint not in portable_swiftlint.zip: ' + ', '.join(archive.namelist()))
        data = archive.read('swiftlint')
    return put(data, dest_dir, 'swiftlint')


def install_swift_format(dest_dir, workdir):
    version, commit = pins.read_pin('swift-format')
    for tool in ('git', 'swift'):
        if shutil.which(tool) is None:
            die(f'{tool} is required to build swift-format {version} and is not on PATH')
    work = pathlib.Path(workdir or tempfile.mkdtemp(prefix='swift-format-build-'))
    src = work / f'swift-format-{version}'
    if not src.exists():
        work.mkdir(parents=True, exist_ok=True)
        subprocess.run(['git', 'clone', '--quiet', '--depth', '1', '--branch', version,
                        SWIFT_FORMAT_REPO, str(src)], check=True)
    head = subprocess.run(['git', '-C', str(src), 'rev-parse', 'HEAD'],
                          capture_output=True, text=True, check=True).stdout.strip()
    if head != commit:
        die(f'swift-format tag {version} resolves to {head}, the pin says {commit}, '
            'refusing to build.')
    subprocess.run(['swift', 'build', '-c', 'release', '--product', 'swift-format',
                    '--package-path', str(src)], check=True)
    bin_path = subprocess.run(
        ['swift', 'build', '-c', 'release', '--package-path', str(src), '--show-bin-path'],
        capture_output=True, text=True, check=True).stdout.strip()
    return put(pathlib.Path(bin_path) / 'swift-format', dest_dir, 'swift-format')


def verify(tool, path):
    version = pins.read_pin(tool)[0]
    out = subprocess.run([str(path)] + pins.TOOLS[tool]['cmd'][1:],
                         capture_output=True, text=True).stdout
    if pins.parse_version(out) != version:
        die(f'installed {path} but it reports {out.strip()!r}, not {version}')
    print(f'install-style-tools: {tool} {version}  ->  {path}')


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument('--tool', choices=['swiftlint', 'swift-format', 'all'], default='all')
    ap.add_argument('--dest', required=True, help='directory to place the binaries in')
    ap.add_argument('--workdir', default=None, help='swift-format checkout/build dir (cacheable)')
    args = ap.parse_args()
    dest = pathlib.Path(args.dest).expanduser()
    if args.tool in ('swiftlint', 'all'):
        verify('swiftlint', install_swiftlint(dest))
    if args.tool in ('swift-format', 'all'):
        verify('swift-format', install_swift_format(dest, args.workdir))
    if str(dest.resolve()) not in os.environ.get('PATH', '').split(os.pathsep):
        print(f'install-style-tools: note: {dest} is not on PATH in this shell.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
