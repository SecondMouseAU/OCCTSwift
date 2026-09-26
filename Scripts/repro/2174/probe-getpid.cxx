// #2174: does -lwasi-emulated-getpid have to be on the link line?
//
// docs/WASI_GUARD_SITES.md records this as "genuinely open, with two concrete sites now rather
// than one": OSD_Directory::BuildTemporary() and OSD_Process::ProcessId(). wasi-libc declares
// getpid() unconditionally and, without -D_WASI_EMULATED_GETPID, only marks it deprecated, so both
// COMPILE with a warning and nothing is blocked. The library half could not be checked until
// something linked.
//
// probe.cxx does not answer it, because it pulls neither member: it links clean with no
// -lwasi-emulated-getpid at all. This file calls the site directly, so the member is pulled and the
// question becomes a link that either resolves getpid or does not.
#include <cstdio>

#include <OSD_Process.hxx>

int main()
{
  OSD_Process aProcess;
  std::printf("OSD_Process::ProcessId() = %d\n", aProcess.ProcessId());
  return 0;
}
