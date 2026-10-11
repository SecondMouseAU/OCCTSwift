// #2757: setjmp lowering plus wasm exceptions emits a module that fails validation.
//
// No OCCT, no libc++ headers beyond <setjmp.h>. Every declaration below is external, so the
// translation unit only has to COMPILE; nothing here has to link or run.
//
// Compile with the standardised exception encoding and the SjLj lowering:
//
//   clang++ --target=wasm32-unknown-wasip1 --sysroot=<WASI.sdk> -O2 \
//       -fwasm-exceptions -mllvm -wasm-use-legacy-eh=false -mllvm -wasm-enable-sjlj \
//       -c sjlj-br-table.cpp
//
// then link with `wasm-ld --no-entry --allow-undefined --no-gc-sections --export-all` and validate
// (V8 does: `new WebAssembly.Module(bytes)`). `f()` carries a `br_table` inside a
// `try_table (catch ...)` whose targets disagree on their label types, and V8 reports
//
//   Compiling function #9:"f()" failed: br_table: label arity inconsistent with previous arity 0
//
// Measured on the pair, not on either half: delete `setjmp` and the module is valid, drop
// `-wasm-enable-sjlj` and it does not link, switch to the legacy EH encoding and it is valid.
// `run.sh` in this directory builds and checks every one of those, with the exact command lines.

#include <setjmp.h>

jmp_buf& lab();  // NOT noexcept, NOT a plain global buffer: both of those validate (see README)
void a();
bool more();

void f()
{
  while (more())
  {
    while (more())
    {
      try
      {
        if (setjmp(lab()))
        {
          a();
        }
      }
      catch (...)
      {
      }
    }
  }
}
