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
#include <TColStd_HArray1OfReal.hxx>
#include <TCollection_HAsciiString.hxx>
#include <cmath>

// Issue1055DatumNameLengthTests / Issue1056GDTWriteAnswerTests: datum names of any length, NaN
// tolerances, and zone / datum modifier values under _None.
int main()
{
  const int lengths[6] = {1, 63, 64, 65, 100, 200};
  for (int n : lengths)
  {
    TCollection_AsciiString s;
    for (int i = 0; i < n; i++)
      s += "A";
    Handle(XCAFDimTolObjects_DatumObject) d = new XCAFDimTolObjects_DatumObject();
    d->SetName(new TCollection_HAsciiString(s));
    printf("datum name of %d chars reads back %d chars\n", n, d->GetName()->Length());
  }

  auto dim = []() {
    Handle(XCAFDimTolObjects_DimensionObject) o = new XCAFDimTolObjects_DimensionObject();
    Handle(TColStd_HArray1OfReal) v = new TColStd_HArray1OfReal(1, 1);
    v->SetValue(1, 20);
    o->SetValues(v);
    return o;
  };
  const double pairs[3][2] = {{NAN, 0.5}, {-0.3, NAN}, {NAN, NAN}};
  for (auto& p : pairs)
  {
    Handle(XCAFDimTolObjects_DimensionObject) o = dim();
    bool lo = o->SetLowerTolValue(p[0]);
    bool up = o->SetUpperTolValue(p[1]);
    printf("tolerance (%g, %g): SetLower=%s SetUpper=%s read back (%g, %g); bridge readback check equal=%s\n", p[0], p[1],
           tf(lo), tf(up), o->GetLowerTolValue(), o->GetUpperTolValue(),
           tf(lo && up && o->GetLowerTolValue() == p[0] && o->GetUpperTolValue() == p[1]));
  }
  Handle(XCAFDimTolObjects_DimensionObject) ok = dim();
  ok->SetLowerTolValue(-0.3);
  ok->SetUpperTolValue(0.7);
  printf("tolerance (-0.3, 0.7): plusMinus=%s lowerTol=%g upperTol=%g value=%g\n", tf(ok->IsDimWithPlusMinusTolerance()),
         ok->GetLowerTolValue(), ok->GetUpperTolValue(), ok->GetValue());

  Handle(XCAFDimTolObjects_GeomToleranceObject) t = new XCAFDimTolObjects_GeomToleranceObject();
  t->SetZoneModifier(XCAFDimTolObjects_GeomToleranceZoneModif_Projected);
  t->SetValueOfZoneModifier(15.0);
  printf("zone Projected, 15: zone=%d value=%g\n", (int)t->GetZoneModifier(), t->GetValueOfZoneModifier());
  t->SetZoneModifier(XCAFDimTolObjects_GeomToleranceZoneModif_None);
  printf("zone set to None without clearing the value: value still %g (the bridge writes 0 with None)\n",
         t->GetValueOfZoneModifier());
  Handle(XCAFDimTolObjects_DatumObject) d = new XCAFDimTolObjects_DatumObject();
  d->SetModifierWithValue(XCAFDimTolObjects_DatumModifWithValue_None, 15.0);
  XCAFDimTolObjects_DatumModifWithValue m;
  double                                v;
  d->GetModifierWithValue(m, v);
  printf("datum modifier None with 15: modifier=%d value=%g (bridge reports nothing under None)\n", (int)m, v);
  return 0;
}
