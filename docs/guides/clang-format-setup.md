# Getting the right clang-format

The `OCCTBridge` C++ layer is formatted with **one pinned clang-format version**, recorded in
[`Scripts/clang-format-version.txt`](../../Scripts/clang-format-version.txt). Everything below is
about getting that exact version onto a machine: a laptop, a CI runner, or a container image for a
cloud review agent.

If you only want to know what to run day to day, it is
[`Scripts/format-bridge.sh`](../../Scripts/format-bridge.sh), and
[`okf/policies/code-style.md`](../../okf/policies/code-style.md) is the policy.

## Why the version is pinned

clang-format's output changes between **major** versions. Measured on this tree: clang-format
21.1.8 and 22.1.8 produce different output on **10 of the 33** enforced bridge files. So an
environment that installs "whatever is current" will eventually report violations in code nobody
touched, and two contributors on different majors cannot agree on what a formatted file looks like.
OCCT's own CI pins for the same reason and hard-fails a mismatch.

The pinned version is the *binary*. The *config* is OCCT's own, checked in at
`Sources/OCCTBridge/.clang-format` and byte-identical to `Libraries/occt-src/.clang-format`. There
is nothing to install for the config: a checkout has it.

## Installing it

Pick the first route that works in your environment. All three land the same binary.

### Route 1: `Scripts/install-clang-format.py` (works where the others do not)

```bash
Scripts/install-clang-format.py                             # -> /usr/local/bin/clang-format
Scripts/install-clang-format.py --dest ~/.local/bin/clang-format
```

Standard library only: no pip, no venv, no curl, no unzip, no apt. It reads the pin, resolves this
host's wheel from PyPI, verifies its sha256, unpacks the single static binary inside, and then runs
it to confirm it reports the version asked for. Prefix with `sudo` if the destination is not
writable.

Outside a checkout there is no pin to read, so pass the version:

```bash
Scripts/install-clang-format.py --version 22.1.8
```

**One self-contained line**, for a container build step that runs before (or without) a checkout:

```bash
python3 -c 'import json,os,platform,sys,urllib.request,zipfile,io,hashlib;v,dest=sys.argv[1],sys.argv[2];m=platform.machine();k="manylinux" if sys.platform.startswith("linux") else "macosx";e=[x for x in json.load(urllib.request.urlopen("https://pypi.org/pypi/clang-format/%s/json"%v))["urls"] if k in x["filename"] and m in x["filename"]][0];b=urllib.request.urlopen(e["url"]).read();assert hashlib.sha256(b).hexdigest()==e["digests"]["sha256"];open(dest,"wb").write(zipfile.ZipFile(io.BytesIO(b)).read("clang_format/data/bin/clang-format"));os.chmod(dest,0o755)' 22.1.8 /usr/local/bin/clang-format && clang-format --version
```

Keep the literal version in that line in step with `Scripts/clang-format-version.txt`. It is the one
place in this repo where the pin is duplicated, and it is duplicated on purpose: a setup step that
has to clone the repo before it can find out what to install is a worse trade than a number to keep
in sync.

### Route 2: pip

```bash
pip install "clang-format==$(awk '!/^#/ && NF {print; exit}' Scripts/clang-format-version.txt)"
```

Fine on a developer machine with a working pip. On a distro with PEP 668 this refuses to touch the
system environment; use `--user`, a venv, or Route 1.

### Route 3: Homebrew (macOS, only when it happens to match)

`brew install clang-format` takes whatever is current, which is a pin only by luck. Check it with
`Scripts/format-bridge.sh --print-version` and fall back to Route 1 when it has moved on. CI
deliberately does **not** use this.

## When venv or pip is missing

The failure that sends people here is Debian/Ubuntu:

```
The virtual environment was not created successfully because ensurepip is not
available.  On Debian/Ubuntu systems, you need to install the python3-venv
package using the following command.

    apt install python3.10-venv
```

Debian and Ubuntu split `ensurepip` out of `python3` into a versioned `python3.N-venv` package. Two
things go wrong from there:

- `apt install python3-venv` (the unversioned name, which is what most people type) can answer
  `Package 'python3-venv' has no installation candidate` on a minimal image whose apt sources do not
  carry the metapackage. The message quotes the **versioned** name for a reason: match your
  interpreter, `python3.10-venv` for Python 3.10.
- Even with the package, a newer distro adds PEP 668, so a plain `pip install` into the system
  environment is refused separately.

**Use Route 1.** It needs neither, which is why it exists. Do not add an `apt install` to an image
build for this.

## Verifying

```bash
Scripts/format-bridge.sh --print-version   # pinned vs resolved, exits 2 on a wrong major
Scripts/format-bridge.sh --check           # the full check CI and the pre-commit hook run
Scripts/format-bridge.sh --self-test       # proves the checker is not blind
```

`--check` is the one to put in an image build after installing, because it verifies three separate
things at once: the version, that `-style=file` actually resolved to
`Sources/OCCTBridge/.clang-format`, and that the tree is clean. The middle one matters more than it
looks: **clang-format does not fail when it finds no config**, it silently falls back to LLVM style,
so a misconfigured environment reports violations in correct code and looks exactly like a real
finding. On success `--check` prints the resolved config path, the version, and the file count:

```
format-bridge: checked 33 file(s) against Sources/OCCTBridge/.clang-format with clang-format 22.1.8.
```

## What CI does

`.github/workflows/code-style.yml` installs the pinned version from PyPI into a throwaway venv,
prepends it to `PATH`, and asserts it with `Scripts/format-bridge.sh --print-version` before any
check runs. It uses a venv rather than Route 1 only because the GitHub `macos-15` image has a
working one; on an image that does not, Route 1 is the drop-in replacement.

## Bumping the pin

Change the version in `Scripts/clang-format-version.txt`, run `Scripts/format-bridge.sh` to
reformat the bridge, and commit the reformat **in the same PR**. A bump with no reformat diff means
the new version agrees with the old one, which is worth saying in the PR body rather than leaving
unexplained. Update the literal in the one-liner above at the same time.
