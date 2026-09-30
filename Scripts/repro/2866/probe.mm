// #2866: what the four buffer-taking TDataStd_*Array attributes do with a reversed or
// exactly-empty range, measured against the pinned kernel rather than read off the headers.
//
// Every Init in this family opens with
//   Standard_RangeError_Raise_if(upper < lower, "TDataStd_<T>Array::Init");
// which is out-of-line and therefore absent from the Release kernel we link
// (okf/policies/occt-validation-is-compiled-out.md). So the range reaches
// NCollection_HArray1 unchecked, and what happens next is per-class arithmetic.
//
// One mode per process, because several of them fault.

#include <BinDrivers.hxx>
#include <NCollection_Array1.hxx>
#include <TDF_Label.hxx>
#include <TDataStd_BooleanArray.hxx>
#include <TDataStd_ByteArray.hxx>
#include <TDataStd_ExtStringArray.hxx>
#include <TDataStd_ReferenceArray.hxx>
#include <TDocStd_Application.hxx>
#include <TDocStd_Document.hxx>
#include <XmlDrivers.hxx>

#include <cstdio>
#include <cstring>

namespace
{

Handle(TDocStd_Application) theApp;

TDF_Label freshLabel(Handle(TDocStd_Document) & doc, int tag)
{
  if (theApp.IsNull())
  {
    theApp = new TDocStd_Application();
    BinDrivers::DefineFormat(theApp);
    XmlDrivers::DefineFormat(theApp);
  }
  theApp->NewDocument("BinOcaf", doc);
  return doc->Main().FindChild(tag, true);
}

// The size NCollection_Array1 would compute for this range, in the same types it uses:
// mySize is a size_t and the expression is evaluated in int, so a reversed range wraps.
void reportSize(const char* what, int lower, int upper)
{
  size_t sz = static_cast<size_t>(upper - lower + 1);
  printf("  %s: lower=%d upper=%d -> int(upper-lower+1)=%d, as size_t=%zu\n",
         what,
         lower,
         upper,
         upper - lower + 1,
         sz);
}

int modeByteArray(int lower, int upper)
{
  Handle(TDocStd_Document) doc;
  TDF_Label                lab = freshLabel(doc, 2);
  reportSize("TDataStd_ByteArray::Init -> NCollection_HArray1<uint8_t>(lower, upper, 0x00)",
             lower,
             upper);
  fflush(stdout);
  Handle(TDataStd_ByteArray) arr = TDataStd_ByteArray::Set(lab, lower, upper);
  printf("  Set returned %s\n", arr.IsNull() ? "null" : "non-null");
  if (!arr.IsNull())
  {
    printf("  Lower=%d Upper=%d Length=%d\n", arr->Lower(), arr->Upper(), arr->Length());
  }
  return 0;
}

int modeBooleanArray(int lower, int upper)
{
  Handle(TDocStd_Document) doc;
  TDF_Label                lab = freshLabel(doc, 2);
  // Init here does NOT hand the caller range to the array: it stores myLower/myUpper and
  // allocates NCollection_HArray1<uint8_t>(0, Length() >> 3, 0).
  int len = upper - lower + 1;
  printf("  TDataStd_BooleanArray::Init -> HArray1<uint8_t>(0, Length()>>3): Length=%d, >>3=%d\n",
         len,
         len >> 3);
  fflush(stdout);
  Handle(TDataStd_BooleanArray) arr = TDataStd_BooleanArray::Set(lab, lower, upper);
  printf("  Set returned %s\n", arr.IsNull() ? "null" : "non-null");
  if (!arr.IsNull())
  {
    printf("  Lower=%d Upper=%d Length=%d\n", arr->Lower(), arr->Upper(), arr->Length());
  }
  return 0;
}

int modeExtStringArray(int lower, int upper)
{
  Handle(TDocStd_Document) doc;
  TDF_Label                lab = freshLabel(doc, 2);
  reportSize("TDataStd_ExtStringArray::Init -> HArray1<TCollection_ExtendedString>(lower, upper)",
             lower,
             upper);
  fflush(stdout);
  Handle(TDataStd_ExtStringArray) arr = TDataStd_ExtStringArray::Set(lab, lower, upper);
  printf("  Set returned %s\n", arr.IsNull() ? "null" : "non-null");
  if (!arr.IsNull())
  {
    printf("  Lower=%d Upper=%d Length=%d\n", arr->Lower(), arr->Upper(), arr->Length());
  }
  return 0;
}

int modeReferenceArray(int lower, int upper)
{
  Handle(TDocStd_Document) doc;
  TDF_Label                lab = freshLabel(doc, 2);
  reportSize("TDataStd_ReferenceArray::Init -> HArray1<TDF_Label>(lower, upper)", lower, upper);
  fflush(stdout);
  Handle(TDataStd_ReferenceArray) arr = TDataStd_ReferenceArray::Set(lab, lower, upper);
  printf("  Set returned %s\n", arr.IsNull() ? "null" : "non-null");
  if (!arr.IsNull())
  {
    printf("  Lower=%d Upper=%d Length=%d\n", arr->Lower(), arr->Upper(), arr->Length());
  }
  return 0;
}

// Does the exactly-empty spelling the four Swift wrappers produce survive a save and a reopen?
// If it does not, "it works today" is only true in memory and shape 1 is the right refusal.
//
// `empty` false is the control: the same document with one-element arrays. Without it, a bad
// reader status says nothing about the empty range.
int modeRoundTrip(const char* format, bool empty)
{
  Handle(TDocStd_Document) doc;
  freshLabel(doc, 1); // creates the application and defines both formats
  theApp->Close(doc);

  const bool  isXml = strcmp(format, "XmlOcaf") == 0;
  const char* file  = empty ? (isXml ? "/tmp/probe-2866-empty.xml" : "/tmp/probe-2866-empty.cbf")
                            : (isXml ? "/tmp/probe-2866-one.xml" : "/tmp/probe-2866-one.cbf");
  TCollection_ExtendedString path(file);

  Handle(TDocStd_Document) doc2;
  theApp->NewDocument(format, doc2);
  // The ranges Document.setByteArray / setBooleanArray / setExtStringArray / setReferenceArray
  // produce for [] and for a one-element array respectively.
  TDataStd_ByteArray::Set(doc2->Main().FindChild(2, true), 0, empty ? -1 : 0);
  TDataStd_BooleanArray::Set(doc2->Main().FindChild(3, true), 1, empty ? 0 : 1);
  TDataStd_ExtStringArray::Set(doc2->Main().FindChild(4, true), 1, empty ? 0 : 1);
  TDataStd_ReferenceArray::Set(doc2->Main().FindChild(5, true), 1, empty ? 0 : 1);
  printf("  four %s arrays created in memory\n", empty ? "exactly-empty" : "one-element");
  fflush(stdout);

  PCDM_StoreStatus st = theApp->SaveAs(doc2, path);
  printf("  SaveAs(%s) status=%d (0 == PCDM_SS_OK)\n", format, (int)st);
  fflush(stdout);
  theApp->Close(doc2); // or Open below answers PCDM_RS_AlreadyRetrieved, which measures nothing

  Handle(TDocStd_Document) back;
  PCDM_ReaderStatus        rs = theApp->Open(path, back);
  printf("  Open status=%d (0 == PCDM_RS_OK)\n", (int)rs);
  if (rs != PCDM_RS_OK || back.IsNull())
  {
    return 1;
  }
  Handle(TDataStd_ByteArray) ba;
  bool found = back->Main().FindChild(2, true).FindAttribute(TDataStd_ByteArray::GetID(), ba);
  printf("  byte array present after reopen: %s\n", found ? "yes" : "no");
  if (found && !ba.IsNull())
  {
    printf("  reopened Lower=%d Upper=%d Length=%d\n", ba->Lower(), ba->Upper(), ba->Length());
  }
  Handle(TDataStd_BooleanArray) bo;
  printf("  boolean array present after reopen: %s\n",
         back->Main().FindChild(3, true).FindAttribute(TDataStd_BooleanArray::GetID(), bo) ? "yes"
                                                                                           : "no");
  Handle(TDataStd_ExtStringArray) es;
  printf("  extstring array present after reopen: %s\n",
         back->Main().FindChild(4, true).FindAttribute(TDataStd_ExtStringArray::GetID(), es)
           ? "yes"
           : "no");
  Handle(TDataStd_ReferenceArray) ra;
  printf("  reference array present after reopen: %s\n",
         back->Main().FindChild(5, true).FindAttribute(TDataStd_ReferenceArray::GetID(), ra)
           ? "yes"
           : "no");
  return 0;
}

} // namespace

int main(int argc, const char* argv[])
{
  const char* mode = argc > 1 ? argv[1] : "";

  // Reversed by more than one: upper - lower + 1 is negative, so the size_t wraps.
  if (strcmp(mode, "byte-reversed") == 0)
    return modeByteArray(10, 1);
  if (strcmp(mode, "boolean-reversed") == 0)
    return modeBooleanArray(10, 1);
  if (strcmp(mode, "extstring-reversed") == 0)
    return modeExtStringArray(10, 1);
  if (strcmp(mode, "reference-reversed") == 0)
    return modeReferenceArray(10, 1);

  // Exactly empty, upper == lower - 1: upper - lower + 1 is 0, which every NCollection_Array1
  // constructor early-returns on. This is the spelling all four Swift wrappers produce for [].
  if (strcmp(mode, "byte-empty") == 0)
    return modeByteArray(0, -1);
  if (strcmp(mode, "boolean-empty") == 0)
    return modeBooleanArray(1, 0);
  if (strcmp(mode, "extstring-empty") == 0)
    return modeExtStringArray(1, 0);
  if (strcmp(mode, "reference-empty") == 0)
    return modeReferenceArray(1, 0);

  // Reversed by exactly two, the first value past the empty spelling.
  if (strcmp(mode, "byte-minus-two") == 0)
    return modeByteArray(1, -1);

  if (strcmp(mode, "roundtrip-bin-one") == 0)
    return modeRoundTrip("BinOcaf", false);
  if (strcmp(mode, "roundtrip-bin-empty") == 0)
    return modeRoundTrip("BinOcaf", true);
  if (strcmp(mode, "roundtrip-xml-one") == 0)
    return modeRoundTrip("XmlOcaf", false);
  if (strcmp(mode, "roundtrip-xml-empty") == 0)
    return modeRoundTrip("XmlOcaf", true);

  fprintf(stderr, "usage: probe <mode>\n");
  return 2;
}
