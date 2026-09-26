/* #2173: what wasi-libc's emulated mmap() does with the call Standard_MMgrOpt actually makes.
 *
 * Standard_MMgrOpt.cxx defines MMAP_FLAGS as (MAP_PRIVATE) for every platform its #elif chain does
 * not name, WASI included, and Initialize() leaves myMMap at -1 for those same platforms. So the
 * call the memory manager makes carries no MAP_ANON and a file descriptor of -1. The control below
 * is the mapping wasi-libc's emulation does serve, so a failure here is a statement about OCCT's
 * flags rather than about mmap() being absent.
 */
#include <errno.h>
#include <stdio.h>
#include <string.h>
#include <sys/mman.h>

#define MMAP_BASE_ADDRESS 0x60000000
#define MMAP_FLAGS (MAP_PRIVATE)

int main(void)
{
  const size_t aSize = 65536;

  errno       = 0;
  void* aBlock = mmap((char*)MMAP_BASE_ADDRESS, aSize, PROT_READ | PROT_WRITE, MMAP_FLAGS, -1, 0);
  printf("  Standard_MMgrOpt's call  mmap(0x%x, %zu, PROT_READ|PROT_WRITE, MAP_PRIVATE, fd=-1) -> %s"
         " (errno %d, %s)\n",
         MMAP_BASE_ADDRESS,
         aSize,
         aBlock == MAP_FAILED ? "MAP_FAILED" : "ok",
         errno,
         strerror(errno));

  errno          = 0;
  void* aControl = mmap(NULL, aSize, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANON, -1, 0);
  printf("  control                  mmap(NULL, %zu, PROT_READ|PROT_WRITE, MAP_PRIVATE|MAP_ANON,"
         " fd=-1) -> %s (errno %d, %s)\n",
         aSize,
         aControl == MAP_FAILED ? "MAP_FAILED" : "ok",
         errno,
         strerror(errno));

  if (aBlock == MAP_FAILED && aControl != MAP_FAILED)
  {
    printf("  VERDICT: the emulation works and refuses OCCT's flags. -D_WASI_EMULATED_MMAN would\n"
           "           compile Standard_MMgrOpt.cxx and leave AllocMemory() throwing\n"
           "           Standard_OutOfMemory on every large block whenever MMGT_OPT=1 is set.\n");
    return 0;
  }
  printf("  VERDICT: NOT the measured result. Re-read wasi-standard-mmgropt.patch's header.\n");
  return 1;
}
