// #1022 reproducer: XCAFDoc_Datum::GetObject builds the datum point's X from the annotation
// plane's array instead of the point's own.
//
// XCAFDoc_Datum.cxx's ChildLab_Pnt block:
//
//   gp_Pnt aP(aLoc->Value(aPnt->Lower()),        <-- aLoc, the plane location array
//             aPnt->Value(aPnt->Lower() + 1),
//             aPnt->Value(aPnt->Lower() + 2));
//
// against the same block in XCAFDoc_GeomTolerance.cxx, which reads aPnt->Value(aPnt->Lower()).
// aLoc is declared before the ChildLab_PlaneLoc block and assigned only by a successful
// FindAttribute there, so it is a null handle whenever the datum has no annotation plane.
//
// Sections:
//   A. plane + point: the wrong value. The stored point is not recoverable.
//   B. plane, no point: control. The point block does not run, nothing is wrong.
//   C. point, no plane: null Handle dereference. SIGSEGV, caught here by a handler so the
//      transcript reads rather than the process dying silently.
//   D. the same point-only datum saved to an OCAF file and reloaded into a fresh application,
//      then read exactly as OCCTDocumentGetDatumInfo reads it. This is the reachability question:
//      whether the crashing shape survives persistence, and therefore whether a document authored
//      by any other OCCT-based writer reaches it through Document.datums.
//
// C and D each abort their process, so the probe takes a section selector and run.sh invokes it
// once per section. With no argument it runs A and B, the two that return normally.

#include <TDF_Label.hxx>
#include <TDF_LabelSequence.hxx>
#include <TDocStd_Application.hxx>
#include <TDocStd_Document.hxx>
#include <XCAFApp_Application.hxx>
#include <XCAFDimTolObjects_DatumObject.hxx>
#include <XCAFDoc_Datum.hxx>
#include <XCAFDoc_DimTolTool.hxx>
#include <XCAFDoc_DocumentTool.hxx>
#include <BinXCAFDrivers.hxx>
#include <TCollection_ExtendedString.hxx>
#include <TCollection_HAsciiString.hxx>
#include <gp_Ax2.hxx>
#include <gp_Dir.hxx>
#include <gp_Pnt.hxx>

#include <csignal>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <unistd.h>

namespace
{

const char* theStage = "(none)";

// Exits 86 rather than 0, so a crash is a status the caller can act on. run.sh's BEFORE lane
// expects it and its AFTER lane must not see it; exiting 0 here would make the AFTER lane pass
// whether or not the patch worked, which is the one thing it exists to answer.
const int THE_CRASH_EXIT = 86;

void onFatalSignal(int theSignal)
{
  const char* aName = theSignal == SIGSEGV ? "SIGSEGV" : (theSignal == SIGBUS ? "SIGBUS" : "signal");
  // Only async-signal-safe calls from here.
  write(STDOUT_FILENO, "  CRASHED (", 11);
  write(STDOUT_FILENO, aName, strlen(aName));
  write(STDOUT_FILENO, ") in ", 5);
  write(STDOUT_FILENO, theStage, strlen(theStage));
  write(STDOUT_FILENO, "\n", 1);
  _exit(THE_CRASH_EXIT);
}

occ::handle<TDocStd_Document> newDocument(occ::handle<TDocStd_Application>& theApp)
{
  theApp = new TDocStd_Application();
  BinXCAFDrivers::DefineFormat(theApp);
  occ::handle<TDocStd_Document> aDoc;
  theApp->NewDocument("BinXCAF", aDoc);
  return aDoc;
}

// Adds one datum, optionally with an annotation plane and optionally with a point.
TDF_Label addDatum(const occ::handle<TDocStd_Document>& theDoc,
                   const char*                          theName,
                   const bool                           theWithPlane,
                   const bool                           theWithPoint)
{
  occ::handle<XCAFDoc_DimTolTool> aTool = XCAFDoc_DimTolTool::Set(theDoc->Main());
  TDF_Label                       aLab  = aTool->AddDatum();
  occ::handle<XCAFDoc_Datum>      anAttr;
  if (!aLab.FindAttribute(XCAFDoc_Datum::GetID(), anAttr))
  {
    printf("  could not attach XCAFDoc_Datum\n");
    return aLab;
  }
  occ::handle<XCAFDimTolObjects_DatumObject> anObj = new XCAFDimTolObjects_DatumObject();
  anObj->SetName(new TCollection_HAsciiString(theName));
  if (theWithPlane)
  {
    anObj->SetPlane(gp_Ax2(gp_Pnt(6., 6., 6.), gp_Dir(0., 0., 1.), gp_Dir(1., 0., 0.)));
  }
  if (theWithPoint)
  {
    anObj->SetPoint(gp_Pnt(7., 7., 7.));
  }
  anAttr->SetObject(anObj);
  return aLab;
}

// The same three calls OCCTDocumentGetDatumInfo makes: GetDatumLabels, FindAttribute, GetObject.
void readDatum(const occ::handle<TDocStd_Document>& theDoc, const int theIndex)
{
  occ::handle<XCAFDoc_DimTolTool> aTool = XCAFDoc_DimTolTool::Set(theDoc->Main());
  TDF_LabelSequence               aLabels;
  aTool->GetDatumLabels(aLabels);
  if (theIndex < 1 || theIndex > aLabels.Length())
  {
    printf("  no datum at index %d\n", theIndex);
    return;
  }
  occ::handle<XCAFDoc_Datum> anAttr;
  if (!aLabels.Value(theIndex).FindAttribute(XCAFDoc_Datum::GetID(), anAttr))
  {
    printf("  no XCAFDoc_Datum attribute\n");
    return;
  }
  occ::handle<XCAFDimTolObjects_DatumObject> anObj = anAttr->GetObject();
  if (anObj.IsNull())
  {
    printf("  GetObject returned null\n");
    return;
  }
  printf("  read  name=%s hasPlane=%d hasPoint=%d",
         anObj->GetName().IsNull() ? "(null)" : anObj->GetName()->String().ToCString(),
         (int)anObj->HasPlane(),
         (int)anObj->HasPoint());
  if (anObj->HasPlane())
  {
    const gp_Pnt aL = anObj->GetPlane().Location();
    printf(" planeLoc=(%g,%g,%g)", aL.X(), aL.Y(), aL.Z());
  }
  if (anObj->HasPoint())
  {
    const gp_Pnt aP = anObj->GetPoint();
    printf(" point=(%g,%g,%g)", aP.X(), aP.Y(), aP.Z());
  }
  printf("\n");
}

} // namespace

int main(int argc, char** argv)
{
  const char* aWanted = argc > 1 ? argv[1] : "AB";
  const bool  aRunA    = strchr(aWanted, 'A') != nullptr;
  const bool  aRunB    = strchr(aWanted, 'B') != nullptr;
  const bool  aRunC    = strchr(aWanted, 'C') != nullptr;
  const bool  aRunD    = strchr(aWanted, 'D') != nullptr;
  signal(SIGSEGV, onFatalSignal);
  signal(SIGBUS, onFatalSignal);

  if (aRunA)
  {
  printf("=== A. datum with BOTH a plane and a point ===\n");
  printf("    wrote planeLoc=(6,6,6) point=(7,7,7); a correct read gives point=(7,7,7)\n");
  {
    occ::handle<TDocStd_Application> anApp;
    occ::handle<TDocStd_Document>    aDoc = newDocument(anApp);
    addDatum(aDoc, "A", true, true);
    theStage = "section A";
    readDatum(aDoc, 1);
    anApp->Close(aDoc);
  }
  }

  if (aRunB)
  {
  printf("=== B. control: a plane and no point, which is what a STEP import produces ===\n");
  {
    occ::handle<TDocStd_Application> anApp;
    occ::handle<TDocStd_Document>    aDoc = newDocument(anApp);
    addDatum(aDoc, "B", true, false);
    theStage = "section B";
    readDatum(aDoc, 1);
    anApp->Close(aDoc);
  }
  }

  if (aRunC)
  {
  printf("=== C. datum with a point and NO plane, read in the process that wrote it ===\n");
  {
    occ::handle<TDocStd_Application> anApp;
    occ::handle<TDocStd_Document>    aDoc = newDocument(anApp);
    addDatum(aDoc, "C", false, true);
    theStage = "section C, XCAFDoc_Datum::GetObject";
    printf("  about to call GetObject on a datum with a point and no plane\n");
    fflush(stdout);
    readDatum(aDoc, 1);
    anApp->Close(aDoc);
  }
  }

  if (aRunD)
  {
  printf("=== D. the same datum saved to OCAF and reloaded into a fresh application ===\n");
  {
    const char*                      aPath = "/tmp/occt_1022_point_only_datum.xbf";
    occ::handle<TDocStd_Application> anApp;
    occ::handle<TDocStd_Document>    aDoc = newDocument(anApp);
    addDatum(aDoc, "D", false, true);
    const PCDM_StoreStatus aStore = anApp->SaveAs(aDoc, TCollection_ExtendedString(aPath));
    anApp->Close(aDoc);
    printf("  saved to %s (status %d)\n", aPath, (int)aStore);

    occ::handle<TDocStd_Application> aReadApp = new TDocStd_Application();
    BinXCAFDrivers::DefineFormat(aReadApp);
    occ::handle<TDocStd_Document> aReloaded;
    const PCDM_ReaderStatus       aRead =
      aReadApp->Open(TCollection_ExtendedString(aPath), aReloaded);
    printf("  reloaded (status %d)\n", (int)aRead);
    theStage = "section D, GetObject after an OCAF round trip";
    printf("  about to read the reloaded datum the way OCCTDocumentGetDatumInfo does\n");
    fflush(stdout);
    readDatum(aReloaded, 1);
    aReadApp->Close(aReloaded);
  }
  }

  return 0;
}
