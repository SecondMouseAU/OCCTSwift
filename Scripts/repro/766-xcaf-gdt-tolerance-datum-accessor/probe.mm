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

#include <XCAFDoc_DimTolTool.hxx>
#include <XCAFDimTolObjects_GeomToleranceObject.hxx>
#include <XCAFDimTolObjects_DatumObject.hxx>
#include <gp_Ax2.hxx>

// GDTToleranceDatumAccessorTests (and the tolerance/datum reads GDTDocumentTests relies on): the
// XCAFDimTolObjects_GeomToleranceObject / _DatumObject round-trips behind the bridge's accessors.
int main()
{
  Handle(XCAFDimTolObjects_GeomToleranceObject) t = new XCAFDimTolObjects_GeomToleranceObject();
  t->SetType(XCAFDimTolObjects_GeomToleranceType_Position);
  t->SetValue(0.1);
  printf("tolerance fresh: typeOfValue=%d material=%d zone=%d zoneValue=%g maxValue=%g modifiers=%d\n",
         (int)t->GetTypeOfValue(), (int)t->GetMaterialRequirementModifier(), (int)t->GetZoneModifier(),
         t->GetValueOfZoneModifier(), t->GetMaxValueModifier(), t->GetModifiers().Length());
  t->SetTypeOfValue(XCAFDimTolObjects_GeomToleranceTypeValue_Diameter);
  t->SetMaterialRequirementModifier(XCAFDimTolObjects_GeomToleranceMatReqModif_M);
  t->SetZoneModifier(XCAFDimTolObjects_GeomToleranceZoneModif_Projected);
  t->SetValueOfZoneModifier(15.0);
  t->SetMaxValueModifier(0.25);
  printf("tolerance written: typeOfValue=%d material=%d zone=%d zoneValue=%g maxValue=%g value=%g type=%d\n",
         (int)t->GetTypeOfValue(), (int)t->GetMaterialRequirementModifier(), (int)t->GetZoneModifier(),
         t->GetValueOfZoneModifier(), t->GetMaxValueModifier(), t->GetValue(), (int)t->GetType());
  t->SetValueOfZoneModifier(0);
  t->SetMaxValueModifier(0);
  printf("tolerance zeroed: zone=%d zoneValue=%g maxValue=%g (bridge reports > 0 only)\n", (int)t->GetZoneModifier(),
         t->GetValueOfZoneModifier(), t->GetMaxValueModifier());
  Handle(XCAFDimTolObjects_GeomToleranceObject) f = new XCAFDimTolObjects_GeomToleranceObject();
  f->SetType(XCAFDimTolObjects_GeomToleranceType_Flatness);
  f->SetValue(0.01);
  printf("flatness 0.01: type=%d value=%g\n", (int)f->GetType(), f->GetValue());
  NCollection_Sequence<XCAFDimTolObjects_GeomToleranceModif> tm;
  tm.Append(XCAFDimTolObjects_GeomToleranceModif_Free_State);
  tm.Append(XCAFDimTolObjects_GeomToleranceModif_All_Around);
  tm.Append(XCAFDimTolObjects_GeomToleranceModif_Statistical_Tolerance);
  t->SetModifiers(tm);
  printf("tolerance modifiers read back:");
  for (int i = 1; i <= t->GetModifiers().Length(); i++)
    printf(" %d", (int)t->GetModifiers().Value(i));
  printf("\n");

  Handle(XCAFDimTolObjects_DatumObject) d = new XCAFDimTolObjects_DatumObject();
  printf("datum fresh: position=%d modifiers=%d isTarget=%s\n", d->GetPosition(), d->GetModifiers().Length(),
         tf(d->IsDatumTarget()));
  d->SetPosition(2);
  printf("datum position 2 -> %d; 0 -> ", d->GetPosition());
  d->SetPosition(0);
  printf("%d\n", d->GetPosition());
  NCollection_Sequence<XCAFDimTolObjects_DatumSingleModif> dm;
  dm.Append(XCAFDimTolObjects_DatumSingleModif_Basic);
  dm.Append(XCAFDimTolObjects_DatumSingleModif_ContactingFeature);
  d->SetModifiers(dm);
  d->SetModifierWithValue(XCAFDimTolObjects_DatumModifWithValue_Projected, 12.5);
  XCAFDimTolObjects_DatumModifWithValue mv;
  double                                val;
  d->GetModifierWithValue(mv, val);
  printf("datum modifiers:");
  for (int i = 1; i <= d->GetModifiers().Length(); i++)
    printf(" %d", (int)d->GetModifiers().Value(i));
  printf("; withValue=%d value=%g\n", (int)mv, val);
  d->SetModifierWithValue(XCAFDimTolObjects_DatumModifWithValue_None, 0);
  d->GetModifierWithValue(mv, val);
  printf("datum withValue cleared=%d\n", (int)mv);

  const XCAFDimTolObjects_DatumTargetType types[3] = {XCAFDimTolObjects_DatumTargetType_Rectangle,
                                                     XCAFDimTolObjects_DatumTargetType_Line,
                                                     XCAFDimTolObjects_DatumTargetType_Point};
  for (auto ty : types)
  {
    Handle(XCAFDimTolObjects_DatumObject) g = new XCAFDimTolObjects_DatumObject();
    g->IsDatumTarget(true);
    g->SetDatumTargetType(ty);
    g->SetDatumTargetNumber(4);
    g->SetDatumTargetAxis(gp_Ax2(gp_Pnt(1, 2, 3), gp_Dir(0, 0, 1), gp_Dir(1, 0, 0)));
    g->SetDatumTargetLength(30);
    g->SetDatumTargetWidth(18);
    printf("target type %d: number=%d hasParams=%s length=%g width=%g (bridge: length unless Point, width only Rectangle)\n",
           (int)g->GetDatumTargetType(), g->GetDatumTargetNumber(), tf(g->HasDatumTargetParams()),
           g->GetDatumTargetLength(), g->GetDatumTargetWidth());
  }
  try
  {
    gp_Dir bad(0, 0, 0);
    printf("gp_Dir(0,0,0) constructed (unexpected)\n");
  }
  catch (const Standard_Failure& e)
  {
    printf("gp_Dir(0,0,0) throws (%s), so a degenerate placement axis is refused\n", e.what());
  }

  Handle(TDocStd_Application) app;
  Handle(TDocStd_Document)    doc = newDoc(app);
  TDF_LabelSequence           dl;
  XCAFDoc_DocumentTool::DimTolTool(doc->Main())->GetDatumLabels(dl);
  printf("fresh document datum labels=%d\n", dl.Length());
  return 0;
}
