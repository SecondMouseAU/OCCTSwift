// Does libmalloc itself survive MallocScribble with concurrent medium-sized allocations?
// No OCCT, no Swift. Every thread keeps a ring of live blocks between 1 KB and 120 KB, writes
// only inside the block it owns, and frees them in rotation. A crash here is the allocator's,
// not a program's.
//
// Usage: malloc_scribble_probe <threads> <seconds> [maxBytes] [mix]
//   mix=0 malloc/free only. mix=1 also calloc, realloc (grow and shrink) and posix_memalign.
// Run under: MallocScribble=1 [MallocPreScribble=1 MallocGuardEdges=1 MallocErrorAbort=1]

#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

static int    gSeconds = 20;
static size_t gMax     = 120 * 1024;
static int    gMix     = 0;

static void* worker(void* arg)
{
  unsigned seed = (unsigned)(size_t)arg * 2654435761u;
  enum { RING = 64 };
  void*  ring[RING] = {0};
  size_t size[RING] = {0};
  time_t end        = time(NULL) + gSeconds;
  unsigned long n   = 0;
  while (time(NULL) < end)
  {
    for (int k = 0; k < 2000; ++k)
    {
      int i = rand_r(&seed) % RING;
      size_t want = 1024 + (size_t)rand_r(&seed) % (gMax - 1024);
      int    op   = gMix ? rand_r(&seed) % 5 : 0;
      if (ring[i] && op == 3)
      {
        // realloc grow or shrink, keeping the live prefix
        void* p = realloc(ring[i], want);
        if (!p)
          abort();
        ring[i] = p;
        size[i] = want;
        ((char*)ring[i])[size[i] - 1] = 2;
        ++n;
        continue;
      }
      if (ring[i])
      {
        ((char*)ring[i])[size[i] - 1] = 1; // touch the last byte we own, then free
        free(ring[i]);
        ring[i] = NULL;
      }
      size[i] = want;
      if (op == 1)
        ring[i] = calloc(1, want);
      else if (op == 2)
      {
        void* p = NULL;
        if (posix_memalign(&p, 64, want) != 0)
          abort();
        ring[i] = p;
      }
      else
        ring[i] = malloc(want);
      if (!ring[i])
        abort();
      memset(ring[i], 0xA5, want < 256 ? want : 256);
      ++n;
    }
  }
  for (int i = 0; i < RING; ++i)
    free(ring[i]);
  return (void*)n;
}

int main(int argc, char** argv)
{
  int threads = argc > 1 ? atoi(argv[1]) : 8;
  gSeconds    = argc > 2 ? atoi(argv[2]) : 20;
  if (argc > 3)
    gMax = (size_t)atol(argv[3]);
  if (argc > 4)
    gMix = atoi(argv[4]);
  pthread_t t[64];
  for (long i = 0; i < threads; ++i)
    pthread_create(&t[i], NULL, worker, (void*)(i + 1));
  unsigned long total = 0;
  for (int i = 0; i < threads; ++i)
  {
    void* r;
    pthread_join(t[i], &r);
    total += (unsigned long)r;
  }
  printf("ok threads=%d seconds=%d mix=%d allocations=%lu\n", threads, gSeconds, gMix, total);
  return 0;
}
