// Regression probe for #2170: the six std threading names the wasip1 libc++ removes.
//
// Every construct below is copied from a site that OCCT (or one of our carried patches)
// actually compiles, so a shim that takes this file to zero errors covers the usage shapes
// the kernel build presents. The shapes and where they come from:
//
//   static std::recursive_mutex + std::lock_guard<std::recursive_mutex>
//       Units/Units.cxx:51, and carried patch 0033's Interface_Static StaticsMutex().
//   static std::shared_mutex + std::shared_lock + std::unique_lock<std::shared_mutex>
//       Plugin/Plugin.cxx:41-58.
//   std::unique_ptr<std::shared_mutex> via std::make_unique
//       NCollection/NCollection_IncAllocator.cxx:74.
//   std::lock over two deferred std::unique_lock<std::shared_mutex>
//       BRepGraph/BRepGraph_CacheRegistry.cxx:47 and BRepGraph/BRepGraph_LayerRegistry.cxx:54.
//   std::mutex + std::lock_guard<std::mutex>
//       carried patches 0014 (CDF driver reentrancy) and 0015 (CDM_Application metadata).
//   std::unique_lock<std::mutex> with std::defer_lock, then .lock()/.unlock()
//       the deferred-acquire shape used across the kernel's cache classes.
//   std::condition_variable with notify_all / wait(pred) / wait_for(pred)
//       Standard/Standard_Condition.hxx:36-101, in full.
//   std::this_thread::yield()
//       not used by the four modules this build compiles (measured: zero occurrences),
//       but named in #2170's missing list, so the shim supplies it and the probe exercises it.
//
// Build it two ways; see README.md.

#include <atomic>
#include <chrono>
#include <condition_variable>
#include <memory>
#include <mutex>
#include <shared_mutex>
#include <thread>

#include <cstdio>

// --- Units.cxx / patch 0033 -------------------------------------------------------------------

static std::recursive_mutex THE_UNITS_MUTEX;

static int recursiveInner()
{
  std::lock_guard<std::recursive_mutex> aLock(THE_UNITS_MUTEX);
  return 1;
}

static int recursiveOuter()
{
  // The second acquisition on the same thread is the whole point: this is what a spinlock
  // substitute (closed PR #2076) turns into a hang.
  std::lock_guard<std::recursive_mutex> aLock(THE_UNITS_MUTEX);
  return recursiveInner() + 1;
}

// --- Plugin.cxx ------------------------------------------------------------------------------

static int pluginMapLookup(bool theWrite)
{
  static std::shared_mutex aMapMutex;
  {
    std::shared_lock<std::shared_mutex> aReadLock(aMapMutex);
    // A reader lock taken twice is ordinary and expected, and is the second shape a
    // non-recursive substitute deadlocks on.
    std::shared_lock<std::shared_mutex> aNestedReadLock(aMapMutex);
    if (!theWrite)
    {
      return 0;
    }
  }
  std::unique_lock<std::shared_mutex> aWriteLock(aMapMutex);
  return 1;
}

// --- NCollection_IncAllocator.cxx --------------------------------------------------------------

static int allocatorMutex()
{
  std::unique_ptr<std::shared_mutex> aMutex = std::make_unique<std::shared_mutex>();
  aMutex->lock_shared();
  aMutex->unlock_shared();
  aMutex->lock();
  aMutex->unlock();
  return aMutex->try_lock() ? 1 : 0;
}

// --- BRepGraph_CacheRegistry.cxx / BRepGraph_LayerRegistry.cxx ---------------------------------

static int multiLock()
{
  std::shared_mutex                   aThisMutex;
  std::shared_mutex                   anOtherMutex;
  std::unique_lock<std::shared_mutex> aThisLock(aThisMutex, std::defer_lock);
  std::unique_lock<std::shared_mutex> anOtherLock(anOtherMutex, std::defer_lock);
  std::lock(aThisLock, anOtherLock);
  return aThisLock.owns_lock() && anOtherLock.owns_lock() ? 1 : 0;
}

// --- patches 0014 / 0015 -----------------------------------------------------------------------

static std::mutex THE_DRIVER_MUTEX;

static int plainMutex()
{
  std::lock_guard<std::mutex> aLock(THE_DRIVER_MUTEX);
  return 1;
}

static int deferredMutex()
{
  std::mutex                   aMutex;
  std::unique_lock<std::mutex> aLock(aMutex, std::defer_lock);
  aLock.lock();
  aLock.unlock();
  return aLock.try_lock() ? 1 : 0;
}

// --- Standard_Condition.hxx --------------------------------------------------------------------

class ProbeCondition
{
public:
  ProbeCondition(bool theIsSet = false)
      : myFlag(theIsSet)
  {
  }

  void Set()
  {
    {
      std::lock_guard<std::mutex> aLock(myMutex);
      myFlag.store(true);
    }
    myCondition.notify_all();
  }

  void Reset()
  {
    std::lock_guard<std::mutex> aLock(myMutex);
    myFlag.store(false);
  }

  void Wait()
  {
    std::unique_lock<std::mutex> aLock(myMutex);
    myCondition.wait(aLock, [this] { return myFlag.load(); });
  }

  bool Wait(int theTimeMilliseconds)
  {
    const std::chrono::milliseconds aTimeout(theTimeMilliseconds);
    std::unique_lock<std::mutex>    aLock(myMutex);
    return myCondition.wait_for(aLock, aTimeout, [this] { return myFlag.load(); });
  }

  bool Check()
  {
    std::lock_guard<std::mutex> aLock(myMutex);
    return myFlag.load();
  }

private:
  std::atomic<bool>       myFlag;
  std::mutex              myMutex;
  std::condition_variable myCondition;
};

// --- names that must NOT be redefined ----------------------------------------------------------
//
// The shim adds to namespace std, so a redefinition of anything libc++ still provides is a hard
// error rather than a subtle one. Touching each survivor here is how that stays true.

static std::once_flag  THE_ONCE;
static std::atomic_flag THE_FLAG = ATOMIC_FLAG_INIT;

static int survivors()
{
  int aValue = 0;
  std::call_once(THE_ONCE, [&aValue] { aValue = 1; });
  THE_FLAG.clear();
  return aValue + (THE_FLAG.test_and_set() ? 1 : 0);
}

int main()
{
  int aSum = 0;
  aSum += recursiveOuter();          // 2: proves the recursive acquire returns rather than hangs
  aSum += pluginMapLookup(true);     // 1
  aSum += allocatorMutex();          // 1
  aSum += multiLock();               // 1
  aSum += plainMutex();              // 1
  aSum += deferredMutex();           // 1
  aSum += survivors();               // 1

  ProbeCondition aCondition;
  aCondition.Set();
  aCondition.Wait();                 // predicate already true
  aSum += aCondition.Wait(1) ? 1 : 0;
  aSum += aCondition.Check() ? 1 : 0;
  aCondition.Reset();
  aSum += aCondition.Wait(1) ? 0 : 1; // wait_for reports the predicate, which is now false

  std::this_thread::yield();

  std::printf("probe: %d\n", aSum);
  return aSum == 11 ? 0 : 1;
}
