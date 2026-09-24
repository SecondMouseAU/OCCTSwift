// Kernel-parity probe for #766 (OCCTXCAFTests). Calls the OCCT API the bridge calls, with the
// test's inputs, and prints what the kernel returns. Build line: CLAUDE.md "Compile a Ground
// Truth C++ Test", headers/lib from the pinned OCCT.xcframework.
#include <BRepPrimAPI_MakeBox.hxx>
#include <TDocStd_Application.hxx>
#include <TDocStd_Document.hxx>
#include <TDF_Label.hxx>
#include <TDF_LabelSequence.hxx>
#include <TDF_Tool.hxx>
#include <TCollection_AsciiString.hxx>
#include <TCollection_ExtendedString.hxx>
#include <XCAFDoc_DocumentTool.hxx>
#include <XCAFDoc_ShapeTool.hxx>
#include <XCAFDoc_ColorTool.hxx>
#include <XCAFDoc_VisMaterialTool.hxx>
#include <TopoDS_Shape.hxx>
#include <cstdio>

// OCCTDocument(): a private TDocStd_Application (#371), NewDocument("MDTV-XCAF"), then the three
// XCAF tools occtDocumentInit fetches.
static Handle(TDocStd_Document) newDoc(Handle(TDocStd_Application)& app)
{
  app = new TDocStd_Application();
  Handle(TDocStd_Document) d;
  app->NewDocument("MDTV-XCAF", d);
  XCAFDoc_DocumentTool::ShapeTool(d->Main());
  XCAFDoc_DocumentTool::ColorTool(d->Main());
  XCAFDoc_DocumentTool::VisMaterialTool(d->Main());
  return d;
}

// getLabelForTag: tag 0 is Main, otherwise Main().FindChild(tag, create).
static TDF_Label tagLabel(const Handle(TDocStd_Document)& d, int tag)
{
  return tag == 0 ? d->Main() : d->Main().FindChild(tag, Standard_True);
}

// OCCTShapeCreateBox: centred on the origin.
static TopoDS_Shape centredBox(double w, double h, double dp)
{
  return BRepPrimAPI_MakeBox(gp_Pnt(-w / 2, -h / 2, -dp / 2), w, h, dp).Shape();
}

static const char* tf(bool b) { return b ? "true" : "false"; }

#include <XCAFDimTolObjects_DimensionObject.hxx>
#include <XCAFDimTolObjects_GeomToleranceObject.hxx>
#include <XCAFDimTolObjects_DatumObject.hxx>
#include <XCAFDimTolObjects_DimensionModif.hxx>
#include <XCAFDimTolObjects_GeomToleranceModif.hxx>
#include <XCAFDimTolObjects_DatumSingleModif.hxx>
#include <gp_Ax2.hxx>

// Issue1037GDTEnumRangeTests / Issue1038DatumTargetPlacementTests: the enum ranges the setters
// check against, and what the datum object keeps of a target placement by target type.
int main()
{
  printf("DimensionModif range 0..%d (so 24 names no enumerator)\n", (int)XCAFDimTolObjects_DimensionModif_Between);
  printf("GeomToleranceModif range 0..%d (so 17 names none)\n", (int)XCAFDimTolObjects_GeomToleranceModif_All_Over);
  printf("DatumSingleModif range 0..%d (so 22 names none)\n", (int)XCAFDimTolObjects_DatumSingleModif_Translation);
  printf("FormVariance range 0..%d, Grade range 0..%d; H=%d IT6=%d\n", (int)XCAFDimTolObjects_DimensionFormVariance_ZC,
         (int)XCAFDimTolObjects_DimensionGrade_IT18, (int)XCAFDimTolObjects_DimensionFormVariance_H,
         (int)XCAFDimTolObjects_DimensionGrade_IT6);
  printf("dimension modifiers 2, 19 = StatisticalTolerance(%d), AnyCrossSection(%d)\n",
         (int)XCAFDimTolObjects_DimensionModif_StatisticalTolerance, (int)XCAFDimTolObjects_DimensionModif_AnyCrossSection);
  printf("datum modifiers 2, 3 = Basic(%d), ContactingFeature(%d)\n", (int)XCAFDimTolObjects_DatumSingleModif_Basic,
         (int)XCAFDimTolObjects_DatumSingleModif_ContactingFeature);
  Handle(XCAFDimTolObjects_DatumObject) d = new XCAFDimTolObjects_DatumObject();
  NCollection_Sequence<XCAFDimTolObjects_DatumSingleModif> two;
  two.Append(XCAFDimTolObjects_DatumSingleModif_Basic);
  two.Append(XCAFDimTolObjects_DatumSingleModif_ContactingFeature);
  d->SetModifiers(two);
  d->SetModifiers(NCollection_Sequence<XCAFDimTolObjects_DatumSingleModif>());
  printf("datum modifiers cleared with an empty sequence: %d\n", d->GetModifiers().Length());

  printf("fresh datum IsDatumTarget=%s (placement needs a non-Area target)\n", tf(d->IsDatumTarget()));
  Handle(XCAFDimTolObjects_DatumObject) r = new XCAFDimTolObjects_DatumObject();
  r->IsDatumTarget(true);
  r->SetDatumTargetType(XCAFDimTolObjects_DatumTargetType_Rectangle);
  r->SetDatumTargetNumber(1);
  r->SetDatumTargetAxis(gp_Ax2(gp_Pnt(1, 2, 3), gp_Dir(0, 0, 1), gp_Dir(1, 0, 0)));
  r->SetDatumTargetLength(30);
  r->SetDatumTargetWidth(18);
  printf("rectangle target: type=%d number=%d length=%g width=%g\n", (int)r->GetDatumTargetType(),
         r->GetDatumTargetNumber(), r->GetDatumTargetLength(), r->GetDatumTargetWidth());
  printf("Area target type ordinal=%d\n", (int)XCAFDimTolObjects_DatumTargetType_Area);
  r->IsDatumTarget(false);
  printf("after IsDatumTarget(false): IsDatumTarget=%s\n", tf(r->IsDatumTarget()));
  return 0;
}
