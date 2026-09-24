// The slice of OCCT this proof needs, for real. Nothing here is a mock of the bridge: the bridge
// translation unit under test is the repo's own, compiled unmodified.
#include <cstdlib>

#include <Standard_Failure.hxx>

int g_bridgeCatchBodyRuns = 0;

// The bridge's diagnostics sink (OCCTBridge.mm's, which this proof does not link). Counting the
// calls is what proves the catch BODY ran, rather than only that a value came back.
void occtRecordCaughtException(const char* theContext)
{
  (void)theContext;
  ++g_bridgeCatchBodyRuns;
}

void* Standard::Allocate(size_t theSize)
{
  return std::malloc(theSize);
}

void* Standard::AllocateOptimal(size_t theSize)
{
  return std::malloc(theSize);
}

void Standard::Free(void* thePtr)
{
  std::free(thePtr);
}

// Standard_Failure, enough of it to be thrown, unwound and destroyed. Its typeinfo is emitted here
// because this translation unit defines its key function.
Standard_Failure::Standard_Failure(const char* theMessage)
    : myMessage(nullptr),
      myStackTrace(nullptr)
{
  (void)theMessage;
}

Standard_Failure::~Standard_Failure() {}

const char* Standard_Failure::what() const noexcept
{
  return "Standard_Failure";
}

// Geom_Line's constructor, by its mangled name rather than its declaration: defining it as a
// member would emit its vtable here and pull in the whole Geom_Geometry hierarchy. It is not
// reached on the raising path; it is here so the link is complete rather than partial.
extern "C" void* _ZN9Geom_LineC1ERK6gp_PntRK6gp_Dir(void* theThis, const void*, const void*)
{
  (void)theThis;
  std::abort();
}
