#include <execinfo.h>
#include <signal.h>
#include <unistd.h>
static void h(int s){ void* b[64]; int n=backtrace(b,64); backtrace_symbols_fd(b,n,2); _exit(139);}
__attribute__((constructor)) static void init(){ signal(SIGSEGV,h); signal(SIGBUS,h);}
