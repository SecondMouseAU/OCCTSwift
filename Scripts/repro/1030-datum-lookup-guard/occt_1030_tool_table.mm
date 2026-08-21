// #1030: the two bridge readers of XCAFDoc_Datum::GetObject that do NOT go through
// occtDocumentDatumObjectAt.
//
// occtDocumentDatumObjectAt reads the GD&T tool this bridge attaches to Main() itself. These two go
// through XCAFDoc_DocumentTool::DimTolTool, a different table at a different label, and both call
// GetObject on every datum they find:
//
//   OCCTDocumentDimTolToleranceCount  -> XCAFDimTolObjects_Tool::GetGeomTolerances
//   OCCTDocumentEditorRescaleGeometry -> XCAFDoc_Editor::RescaleGeometry
//
// The crashing datum cannot be authored from Swift in that table, because attaching an
// XCAFDoc_Datum attribute is not on the bridge's label surface, so this probe builds it in C++ and
// calls the real bridge functions. Sections are selected by argv because two of them take the
// process down when the guard is absent, and an aborted process reports nothing about whatever
// would have run after it.
//
//   A  tolerance count, datum with a point and no plane     SIGSEGV unguarded
//   B  rescale geometry, same datum                         SIGSEGV unguarded
//   C  control, datum with a plane and a point              never crashed, must still work

// The umbrella first: OCCTBridge_Internal.h uses the public typedefs and declares no
// includes of its own, exactly as every OCCTBridge_*.mm opens.
#import "../../../Sources/OCCTBridge/include/OCCTBridge.h"
#import "../../../Sources/OCCTBridge/src/OCCTBridge_Internal.h"

#include <TCollection_AsciiString.hxx>
#include <TCollection_HAsciiString.hxx>
#include <TDF_Tool.hxx>
#include <XCAFDimTolObjects_DatumObject.hxx>
#include <XCAFDimTolObjects_GeomToleranceObject.hxx>
#include <XCAFDoc_Datum.hxx>
#include <XCAFDoc_DimTolTool.hxx>
#include <XCAFDoc_DocumentTool.hxx>
#include <XCAFDoc_GeomTolerance.hxx>

#include <cstdio>
#include <cstring>

// Every bridge function used here is declared by the umbrella header above.

// A datum in the XCAFDoc_DocumentTool table, carrying a point and optionally a plane, linked to a
// geometric tolerance so GetGeomTolerances reaches it.
static void buildDatum(OCCTDocumentRef docRef, bool withPlane)
{
  Handle(XCAFDoc_DimTolTool) tool = XCAFDoc_DocumentTool::DimTolTool(docRef->doc->Main());

  TDF_Label                     tolLabel = tool->AddGeomTolerance();
  Handle(XCAFDoc_GeomTolerance) tolAttr;
  tolLabel.FindAttribute(XCAFDoc_GeomTolerance::GetID(), tolAttr);
  Handle(XCAFDimTolObjects_GeomToleranceObject) tolObj =
    new XCAFDimTolObjects_GeomToleranceObject();
  tolObj->SetType(XCAFDimTolObjects_GeomToleranceType_Flatness);
  tolObj->SetValue(0.01);
  tolAttr->SetObject(tolObj);

  TDF_Label             datumLabel = tool->AddDatum();
  Handle(XCAFDoc_Datum) datumAttr;
  datumLabel.FindAttribute(XCAFDoc_Datum::GetID(), datumAttr);
  Handle(XCAFDimTolObjects_DatumObject) datumObj = new XCAFDimTolObjects_DatumObject();
  datumObj->SetName(new TCollection_HAsciiString("A"));
  datumObj->SetPosition(1);
  datumObj->SetModifierWithValue(XCAFDimTolObjects_DatumModifWithValue_None, 0.0);
  if (withPlane)
    datumObj->SetPlane(gp_Ax2(gp_Pnt(6, 6, 6), gp_Dir(0, 0, 1), gp_Dir(1, 0, 0)));
  datumObj->SetPoint(gp_Pnt(7, 7, 7));
  datumAttr->SetObject(datumObj);

  tool->SetDatumToGeomTol(datumLabel, tolLabel);

  TCollection_AsciiString entry;
  TDF_Tool::Entry(datumLabel, entry);
  std::printf("  datum label %s, plane %s\n", entry.ToCString(), withPlane ? "yes" : "no");
  // The other table, the one occtDocumentDatumObjectAt reads, cannot see this datum at all.
  std::printf("  OCCTDocumentGetDatumCount (the Main() table) = %d\n",
              OCCTDocumentGetDatumCount(docRef));
}

int main(int argc, char** argv)
{
  const char* section = (argc > 1) ? argv[1] : "A";

  if (std::strcmp(section, "A") == 0)
  {
    std::printf("A: OCCTDocumentDimTolToleranceCount, datum with a point and no plane\n");
    OCCTDocumentRef doc = OCCTDocumentCreate();
    buildDatum(doc, false);
    std::printf("  calling OCCTDocumentDimTolToleranceCount...\n");
    std::fflush(stdout);
    std::printf("  returned %d\n", OCCTDocumentDimTolToleranceCount(doc));
  }
  else if (std::strcmp(section, "B") == 0)
  {
    std::printf("B: OCCTDocumentEditorRescaleGeometry, datum with a point and no plane\n");
    OCCTDocumentRef doc = OCCTDocumentCreate();
    buildDatum(doc, false);
    const int64_t mainId = doc->registerLabel(doc->doc->Main());
    std::printf("  calling OCCTDocumentEditorRescaleGeometry...\n");
    std::fflush(stdout);
    std::printf("  returned %d\n",
                OCCTDocumentEditorRescaleGeometry(doc, mainId, 2.0, true) ? 1 : 0);
  }
  else if (std::strcmp(section, "C") == 0)
  {
    std::printf("C: control, datum with a plane AND a point, both entry points\n");
    OCCTDocumentRef doc = OCCTDocumentCreate();
    buildDatum(doc, true);
    std::printf("  OCCTDocumentDimTolToleranceCount returned %d\n",
                OCCTDocumentDimTolToleranceCount(doc));
    const int64_t mainId = doc->registerLabel(doc->doc->Main());
    std::printf("  OCCTDocumentEditorRescaleGeometry returned %d\n",
                OCCTDocumentEditorRescaleGeometry(doc, mainId, 2.0, true) ? 1 : 0);
  }
  else
  {
    std::printf("unknown section %s\n", section);
    return 2;
  }

  std::printf("  section %s completed without crashing\n", section);
  return 0;
}
