// #2801 sweep: the OCAF integer/real array setters write out of bounds, because every check on
// the path is compiled out of the pinned kernel.
//
// Two links, both out-of-line and therefore absent from libOCCT:
//
//  1. TDataStd_IntegerArray::Init (TDataStd_IntegerArray.cxx:75)
//       Standard_RangeError_Raise_if(upper < lower, "TDataStd_IntegerArray::Init");
//       myValue = new NCollection_HArray1<int>(lower, upper, 0);
//     Reached from TDataStd_IntegerArray::Set(label, lower, upper), which the bridge calls with
//     caller-supplied bounds.  Swift: AssemblyNode.initIntegerArray(lower:upper:).
//
//  2. TDataStd_IntegerArray::SetValue (TDataStd_IntegerArray.cxx:105)
//       if (myValue->Value(index) == value) return;      // OOB READ
//       Backup();
//       myValue->SetValue(index, value);                 // OOB WRITE
//     NCollection_Array1::Value / SetValue do carry Standard_OutOfRange_Raise_if, but they are
//     INLINE members expanded inside TDataStd_IntegerArray.cxx, an OCCT translation unit compiled
//     -DNo_Exception, so both are compiled out AT THAT DEPTH.  aPos is a size_t, so a negative
//     index wraps to a huge offset.
//     Swift: AssemblyNode.setIntegerArrayValue(at:value:), which validates nothing.
//
// The asymmetry is the evidence: OCCTDocumentGetIntegerArrayValue DOES test
// `index < attr->Lower() || index > attr->Upper()` before reading.  The setter twelve lines above
// it does not.  Same file, same attribute, opposite treatment.
//
// This probe drives the OCCT classes directly, in the shape the bridge drives them.
// Build/run: see run.sh.  Each mode runs in its own process.

#include <TDF_Label.hxx>
#include <TDF_Data.hxx>
#include <TDF_Tool.hxx>
#include <TDocStd_Document.hxx>
#include <TDataStd_IntegerArray.hxx>
#include <TDataStd_RealArray.hxx>
#include <NCollection_HArray1.hxx>

#include <cstdio>
#include <cstdlib>

int main(int argc, char** argv)
{
  int mode = (argc > 1) ? atoi(argv[1]) : 0;
  printf("mode %d\n", mode);
  fflush(stdout);

  occ::handle<TDocStd_Document> doc = new TDocStd_Document("BinOcaf");
  TDF_Label                     root = doc->Main();

  if (mode >= 0 && mode <= 5)
  {
    // A well-formed array of 4 ints, exactly as initIntegerArray(lower: 1, upper: 4) makes one.
    occ::handle<TDataStd_IntegerArray> arr = TDataStd_IntegerArray::Set(root, 1, 4);
    printf("  Lower()=%d Upper()=%d\n", arr->Lower(), arr->Upper());
    fflush(stdout);

    int idx = 0;
    switch (mode)
    {
      case 0: idx = 1; break;              // baseline, in range
      case 1: idx = 5; break;              // one past Upper()
      case 2: idx = 0; break;              // one below Lower()
      case 3: idx = 1000000; break;
      case 4: idx = -1000000; break;
      case 5: idx = -2147483647; break;    // index - myLowerBound overflows into a huge size_t
    }
    printf("  SetValue(%d, 424242) ... ", idx);
    fflush(stdout);
    arr->SetValue(idx, 424242);
    printf("returned\n");
    fflush(stdout);
    printf("  read back Value(%d) = %d\n", idx, arr->Value(idx));
    fflush(stdout);
    printf("  in-range contents after the write:");
    for (int i = arr->Lower(); i <= arr->Upper(); ++i)
      printf(" [%d]=%d", i, arr->Value(i));
    printf("\n");
    fflush(stdout);
    printf("mode %d survived\n", mode);
    fflush(stdout);
    return 0;
  }

  if (mode >= 10 && mode <= 13)
  {
    // Init with upper < lower: the Standard_RangeError the header documents is compiled out.
    int lower = 0, upper = 0;
    switch (mode)
    {
      case 10: lower = 1;  upper = 0; break;            // empty by one
      case 11: lower = 10; upper = 1; break;
      case 12: lower = 0;  upper = -1000000; break;
      case 13: lower = 2147483647; upper = -2147483648; break;
    }
    printf("  Set(label, lower=%d, upper=%d) ... ", lower, upper);
    fflush(stdout);
    occ::handle<TDataStd_IntegerArray> arr = TDataStd_IntegerArray::Set(root, lower, upper);
    printf("returned\n");
    fflush(stdout);
    printf("  Lower()=%d Upper()=%d\n", arr->Lower(), arr->Upper());
    fflush(stdout);
    printf("  SetValue(%d, 7) ... ", lower);
    fflush(stdout);
    arr->SetValue(lower, 7);
    printf("returned, Value(%d)=%d\n", lower, arr->Value(lower));
    fflush(stdout);
    printf("mode %d survived\n", mode);
    fflush(stdout);
    return 0;
  }

  if (mode >= 20 && mode <= 22)
  {
    // The same two links for TDataStd_RealArray, whose bridge setter is equally unguarded.
    occ::handle<TDataStd_RealArray> arr = TDataStd_RealArray::Set(root, 1, 4);
    printf("  Lower()=%d Upper()=%d\n", arr->Lower(), arr->Upper());
    fflush(stdout);
    int idx = (mode == 20) ? 1 : (mode == 21 ? 1000000 : -2147483647);
    printf("  SetValue(%d, 3.5) ... ", idx);
    fflush(stdout);
    arr->SetValue(idx, 3.5);
    printf("returned, Value(%d)=%g\n", idx, arr->Value(idx));
    fflush(stdout);
    printf("mode %d survived\n", mode);
    fflush(stdout);
    return 0;
  }

  printf("unknown mode\n");
  return 2;
}
