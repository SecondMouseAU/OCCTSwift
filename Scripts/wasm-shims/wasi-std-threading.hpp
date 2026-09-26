// wasi-std-threading.hpp
//
// Single-threaded stand-ins for the std threading names the Swift wasip1 SDK's libc++ removes.
//
// This is NOT an OCCT source file and there is NO patch for it. Scripts/build-occt-wasm.sh
// force-includes it into every C++ translation unit with `-include`, which is the whole mechanism:
// no OCCT source is edited for the threading class, at any site, ever. The reasoning is in
// docs/WASI_GUARD_SITES.md and Scripts/patches-wasi/README.md, and the short form is that patching
// per site does not terminate. 75 files across the four modules this build compiles use these
// names, fifteen of them files our own carried thread-safety patches modify, and upstream keeps
// converting more internals to std::mutex at every kernel bump.
//
// ---------------------------------------------------------------------------------------------
// This adds names to namespace std, which is formally undefined behaviour.
// ---------------------------------------------------------------------------------------------
//
// [namespace.std] reserves namespace std: a program that adds a declaration to it is ill-formed,
// no diagnostic required. That is a rule about programs that must work against ANY conforming
// implementation. This file is not such a program. It targets exactly one libc++, the one in the
// Swift SDK pinned by Scripts/wasm-toolchain-versions.txt, and it checks that libc++'s
// configuration at build time rather than assuming it: the checks below fail the compile if
// _LIBCPP_HAS_THREADS is missing or non-zero, and Scripts/build-occt-wasm.sh runs that check as a
// preflight before CMake starts so the failure is legible rather than buried in CMakeError.log.
// On the configuration this build actually uses, every name declared below is absent from every
// libc++ header, so nothing is redefined and no diagnostic is possible in practice.
//
// The alternative libc++ sanctions, _LIBCPP_HAS_THREAD_API_EXTERNAL, needs __config_site changed,
// and the sysroot's include/c++/v1 is searched ahead of any user -I, so reaching it would mean
// editing the installed SDK. Measured and rejected in #2170.
//
// ---------------------------------------------------------------------------------------------
// Why a no-op lock is sound here, and why a spinlock is not.
// ---------------------------------------------------------------------------------------------
//
// wasm32-unknown-wasip1 is single-threaded: no pthreads, one linear memory, one instance. TBB is
// off in this build, and the Swift bridge serialises every OCCT call through one recursive mutex
// of its own. There is no second thread for any of these locks to exclude, so keeping the types
// and dropping the enforcement changes no observable behaviour.
//
// Dropping the enforcement is not the same as substituting a weaker primitive. Closed PR #2076
// replaced std::recursive_mutex and std::shared_mutex with hand-written spinlocks at six sites.
// A spinlock cannot stand in for a recursive mutex: the second acquisition on the same thread
// spins on a flag only that thread could clear, and single-threaded, nothing ever will. The same
// argument retires the shared_mutex sites, where a reader lock taken twice is ordinary. Every
// lock() below returns immediately, and every try_lock() below returns true, so re-entrancy is
// safe by construction rather than by counting. Do not add a flag, a counter or an owner field to
// any of these: the moment one of them can fail to acquire, a real OCCT call path hangs.
//
// ---------------------------------------------------------------------------------------------
// What is here, and what deliberately is not.
// ---------------------------------------------------------------------------------------------
//
// Measured against the pinned sysroot by syntax-only compile, #2170's six missing names are
// std::mutex, std::recursive_mutex, std::shared_mutex, std::shared_lock,
// std::condition_variable and std::this_thread::yield. Two more are here for reasons #2170 did
// not anticipate, and both were found by compiling the real files rather than by grepping for
// the six:
//
//   std::cv_status, which is condition_variable's return type, so the interface cannot do
//       without it.
//   std::lock, the variadic deadlock-avoiding multi-lock. It lives in <mutex> and goes with the
//       rest of that header's threading half. BRepGraph_CacheRegistry.cxx:47 and
//       BRepGraph_LayerRegistry.cxx:54 both call it on two deferred unique_locks, and neither
//       file names any of the six in that statement, so the issue's grep could not have seen it.
//
// std::try_lock, std::timed_mutex, std::shared_timed_mutex, std::condition_variable_any,
// std::thread and std::notify_all_at_thread_exit are equally absent from this libc++ and are
// deliberately NOT supplied: the four modules this build compiles use none of them, measured at
// zero occurrences. If a kernel bump introduces one, the compile says so by name and it gets
// added here, which is the intended way this file grows.
//
// These names SURVIVE in the pinned libc++ and must never be declared below, because a
// redefinition in namespace std is a hard error rather than a subtle one: std::lock_guard,
// std::unique_lock, std::once_flag, std::call_once, std::defer_lock, std::try_to_lock,
// std::adopt_lock, std::atomic, std::atomic_flag. Scripts/repro/2170/probe.cxx touches each of
// them, so the probe fails if one is ever shadowed here.
//
// The regression test is Scripts/repro/2170/probe.cxx, which reproduces the usage shape of every
// carried patch and of Standard_Condition.hxx; see Scripts/repro/2170/README.md.

#ifndef OCCT_WASI_STD_THREADING_SHIM_HPP
#define OCCT_WASI_STD_THREADING_SHIM_HPP

// Force-included, so this file is the first thing in the translation unit and _LIBCPP_HAS_THREADS
// is not defined yet. <version> is the cheapest standard header that pulls in libc++'s __config
// and, through it, the sysroot's __config_site.
#include <version>

#if !defined(_LIBCPP_VERSION) || !defined(_LIBCPP_HAS_THREADS)
#error "wasi-std-threading.hpp expects the libc++ pinned by Scripts/wasm-toolchain-versions.txt, \
which defines _LIBCPP_HAS_THREADS in __config_site. A standard library that does not define that \
macro has not been checked against this shim, and the shim asserts a configuration it can no \
longer see. Establish what the new standard library provides before force-including this."
#endif

// The shim disappears rather than conflicts against a libc++ that has threads: the definitions
// below are compiled out, and this assertion is the one diagnostic, instead of a redefinition
// cascade with no explanation in it. Measured: force-included into a host macOS compile, where
// _LIBCPP_HAS_THREADS is 1, this produces exactly one error and it is the one below.
static_assert(_LIBCPP_HAS_THREADS == 0,
              "wasi-std-threading.hpp does not apply to this libc++: it has threads, so it already "
              "supplies the names this shim replaces and the shim is a redefinition rather than a "
              "convenience. Either the sysroot is not the one Scripts/wasm-toolchain-versions.txt "
              "pins (wasi-sdk 34.0's own wasm32-wasip1 sysroot is in this category, and that "
              "mismatch is #2172's to settle), or the pinned SDK gained threads and the shim has "
              "served its purpose. Scripts/build-occt-wasm.sh's preflight tells the two apart and "
              "says what each one wants. Do not relax this assertion: adding to namespace std is "
              "only defensible while the names are absent.");

#if !_LIBCPP_HAS_THREADS

#include <chrono>
// <mutex> supplies lock_guard, unique_lock, once_flag, call_once and the lock tag types, all of
// which survive; including it here means the definitions below can name them, and means a later
// #include <mutex> in an OCCT source file is a no-op rather than a second chance to disagree.
#include <mutex>

namespace std
{

//! Stands in for std::mutex. Every operation succeeds immediately; see the header comment for why
//! that is the only safe choice single-threaded.
class mutex
{
public:
  constexpr mutex() noexcept = default;
  ~mutex()                   = default;

  mutex(const mutex&)            = delete;
  mutex& operator=(const mutex&) = delete;

  void lock() noexcept {}

  bool try_lock() noexcept { return true; }

  void unlock() noexcept {}
};

//! Stands in for std::recursive_mutex. Re-entrant because acquiring is a no-op, not because a
//! count is kept: Units.cxx and carried patch 0033 both take this lock again from under itself.
class recursive_mutex
{
public:
  constexpr recursive_mutex() noexcept = default;
  ~recursive_mutex()                   = default;

  recursive_mutex(const recursive_mutex&)            = delete;
  recursive_mutex& operator=(const recursive_mutex&) = delete;

  void lock() noexcept {}

  bool try_lock() noexcept { return true; }

  void unlock() noexcept {}
};

//! Stands in for std::shared_mutex. Both the exclusive and the shared side are no-ops, so a reader
//! lock taken twice, which Plugin.cxx and NCollection_IncAllocator.cxx both do, returns.
class shared_mutex
{
public:
  constexpr shared_mutex() noexcept = default;
  ~shared_mutex()                   = default;

  shared_mutex(const shared_mutex&)            = delete;
  shared_mutex& operator=(const shared_mutex&) = delete;

  void lock() noexcept {}

  bool try_lock() noexcept { return true; }

  void unlock() noexcept {}

  void lock_shared() noexcept {}

  bool try_lock_shared() noexcept { return true; }

  void unlock_shared() noexcept {}
};

//! Stands in for std::shared_lock. Unlike the mutexes, this one tracks ownership honestly, because
//! owns_lock() and operator bool are queries a caller can branch on, and answering them wrongly
//! would change behaviour rather than only drop enforcement. It never throws: the standard's
//! error cases are all misuse, and in a single-threaded runtime refusing is worse than obliging.
template <class Mutex>
class shared_lock
{
public:
  using mutex_type = Mutex;

  shared_lock() noexcept
      : myMutex(nullptr),
        myOwns(false)
  {
  }

  explicit shared_lock(mutex_type& theMutex)
      : myMutex(&theMutex),
        myOwns(true)
  {
    theMutex.lock_shared();
  }

  shared_lock(mutex_type& theMutex, defer_lock_t) noexcept
      : myMutex(&theMutex),
        myOwns(false)
  {
  }

  shared_lock(mutex_type& theMutex, try_to_lock_t)
      : myMutex(&theMutex),
        myOwns(theMutex.try_lock_shared())
  {
  }

  shared_lock(mutex_type& theMutex, adopt_lock_t) noexcept
      : myMutex(&theMutex),
        myOwns(true)
  {
  }

  ~shared_lock()
  {
    if (myOwns && myMutex != nullptr)
    {
      myMutex->unlock_shared();
    }
  }

  shared_lock(const shared_lock&)            = delete;
  shared_lock& operator=(const shared_lock&) = delete;

  shared_lock(shared_lock&& theOther) noexcept
      : myMutex(theOther.myMutex),
        myOwns(theOther.myOwns)
  {
    theOther.myMutex = nullptr;
    theOther.myOwns  = false;
  }

  shared_lock& operator=(shared_lock&& theOther) noexcept
  {
    if (this != &theOther)
    {
      if (myOwns && myMutex != nullptr)
      {
        myMutex->unlock_shared();
      }
      myMutex          = theOther.myMutex;
      myOwns           = theOther.myOwns;
      theOther.myMutex = nullptr;
      theOther.myOwns  = false;
    }
    return *this;
  }

  void lock()
  {
    if (myMutex != nullptr)
    {
      myMutex->lock_shared();
      myOwns = true;
    }
  }

  bool try_lock()
  {
    myOwns = myMutex != nullptr && myMutex->try_lock_shared();
    return myOwns;
  }

  void unlock()
  {
    if (myOwns && myMutex != nullptr)
    {
      myMutex->unlock_shared();
    }
    myOwns = false;
  }

  void swap(shared_lock& theOther) noexcept
  {
    mutex_type* aMutex = myMutex;
    const bool  anOwns = myOwns;
    myMutex            = theOther.myMutex;
    myOwns             = theOther.myOwns;
    theOther.myMutex   = aMutex;
    theOther.myOwns    = anOwns;
  }

  mutex_type* release() noexcept
  {
    mutex_type* aMutex = myMutex;
    myMutex            = nullptr;
    myOwns             = false;
    return aMutex;
  }

  mutex_type* mutex() const noexcept { return myMutex; }

  bool owns_lock() const noexcept { return myOwns; }

  explicit operator bool() const noexcept { return myOwns; }

private:
  mutex_type* myMutex;
  bool        myOwns;
};

template <class Mutex>
inline void swap(shared_lock<Mutex>& theLeft, shared_lock<Mutex>& theRight) noexcept
{
  theLeft.swap(theRight);
}

//! The return type of condition_variable's untimed-predicate waits. Absent from this libc++ for
//! the same reason condition_variable is, so it comes with it.
enum class cv_status
{
  no_timeout,
  timeout
};

//! Stands in for std::condition_variable, as used by Standard_Condition.hxx.
//!
//! Every wait returns at once. Single-threaded, no other thread exists to notify, so a wait whose
//! predicate is false can never be satisfied and blocking would be an unconditional hang; a wait
//! whose predicate is already true returns immediately on a real implementation too, which is the
//! only case Standard_Condition's callers reach with one thread. The predicate overloads report
//! the predicate, which is what the standard requires of wait_for and wait_until after a timeout,
//! so those two are exactly conforming rather than merely harmless.
class condition_variable
{
public:
  condition_variable()  = default;
  ~condition_variable() = default;

  condition_variable(const condition_variable&)            = delete;
  condition_variable& operator=(const condition_variable&) = delete;

  void notify_one() noexcept {}

  void notify_all() noexcept {}

  void wait(unique_lock<mutex>&) {}

  template <class Predicate>
  void wait(unique_lock<mutex>&, Predicate)
  {
  }

  template <class Rep, class Period>
  cv_status wait_for(unique_lock<mutex>&, const chrono::duration<Rep, Period>&)
  {
    return cv_status::timeout;
  }

  template <class Rep, class Period, class Predicate>
  bool wait_for(unique_lock<mutex>&, const chrono::duration<Rep, Period>&, Predicate thePredicate)
  {
    return static_cast<bool>(thePredicate());
  }

  template <class Clock, class Duration>
  cv_status wait_until(unique_lock<mutex>&, const chrono::time_point<Clock, Duration>&)
  {
    return cv_status::timeout;
  }

  template <class Clock, class Duration, class Predicate>
  bool wait_until(unique_lock<mutex>&,
                  const chrono::time_point<Clock, Duration>&,
                  Predicate thePredicate)
  {
    return static_cast<bool>(thePredicate());
  }
};

//! Stands in for the variadic std::lock, as used by BRepGraph_CacheRegistry.cxx and
//! BRepGraph_LayerRegistry.cxx on two deferred unique_locks.
//!
//! The real one exists to acquire several mutexes without deadlocking, by backing off and
//! retrying rather than taking them in a fixed order. With no-op mutexes no acquisition can
//! fail, so locking left to right is the whole algorithm and there is nothing to back off from.
template <class Lockable1, class Lockable2, class... LockableN>
inline void lock(Lockable1& theFirst, Lockable2& theSecond, LockableN&... theRest)
{
  theFirst.lock();
  theSecond.lock();
  (theRest.lock(), ...); // C++17 fold; the build pins -DCMAKE_CXX_STANDARD=17
}

namespace this_thread
{

//! Stands in for std::this_thread::yield. Nothing to yield to.
//!
//! No file in the four modules this build compiles calls it (measured at zero occurrences); it is
//! here because #2170 counts it among the eight names the SDK removes, and because a kernel bump
//! adding one call should not reopen this question.
inline void yield() noexcept {}

} // namespace this_thread

} // namespace std

#endif // !_LIBCPP_HAS_THREADS

#endif // OCCT_WASI_STD_THREADING_SHIM_HPP
