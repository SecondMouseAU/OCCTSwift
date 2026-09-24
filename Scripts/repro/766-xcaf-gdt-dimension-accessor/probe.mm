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
#include <TColStd_HArray1OfReal.hxx>

// GDTDimensionAccessorTests: the XCAFDimTolObjects_DimensionObject qualifier / decimal-place /
// modifier round-trips and the static type classifiers the bridge asks.
static Handle(XCAFDimTolObjects_DimensionObject) simple(XCAFDimTolObjects_DimensionType t, double v)
{
  Handle(XCAFDimTolObjects_DimensionObject) o = new XCAFDimTolObjects_DimensionObject();
  o->SetType(t);
  Handle(TColStd_HArray1OfReal) vals = new TColStd_HArray1OfReal(1, 1);
  vals->SetValue(1, v);
  o->SetValues(vals);
  return o;
}

int main()
{
  Handle(XCAFDimTolObjects_DimensionObject) d = simple(XCAFDimTolObjects_DimensionType_Size_Diameter, 20);
  printf("fresh qualifier=%d angular=%d\n", (int)d->GetQualifier(), (int)d->GetAngularQualifier());
  d->SetQualifier(XCAFDimTolObjects_DimensionQualifier_Max);
  printf("after SetQualifier(Max): qualifier=%d value=%g range=%s plusMinus=%s\n", (int)d->GetQualifier(),
         d->GetValue(), tf(d->IsDimWithRange()), tf(d->IsDimWithPlusMinusTolerance()));
  d->SetQualifier(XCAFDimTolObjects_DimensionQualifier_None);
  printf("after SetQualifier(None): qualifier=%d\n", (int)d->GetQualifier());

  Handle(XCAFDimTolObjects_DimensionObject) a = simple(XCAFDimTolObjects_DimensionType_Size_Angular, 45);
  a->SetQualifier(XCAFDimTolObjects_DimensionQualifier_Min);
  a->SetAngularQualifier(XCAFDimTolObjects_AngularQualifier_Large);
  printf("angular: qualifier=%d angularQualifier=%d\n", (int)a->GetQualifier(), (int)a->GetAngularQualifier());

  int l = -1, r = -1;
  d->GetNbOfDecimalPlaces(l, r);
  printf("decimal places fresh=(%d, %d)\n", l, r);
  const int pairs[3][2] = {{2, 3}, {0, 4}, {0, 0}};
  for (auto& p : pairs)
  {
    d->SetNbOfDecimalPlaces(p[0], p[1]);
    d->GetNbOfDecimalPlaces(l, r);
    printf("decimal places set (%d, %d) -> (%d, %d); bridge presence test (l > 0 || r > 0) = %s\n", p[0], p[1], l, r,
           tf(l > 0 || r > 0));
  }

  NCollection_Sequence<XCAFDimTolObjects_DimensionModif> mods;
  mods.Append(XCAFDimTolObjects_DimensionModif_AnyCrossSection);
  mods.Append(XCAFDimTolObjects_DimensionModif_Square);
  mods.Append(XCAFDimTolObjects_DimensionModif_StatisticalTolerance);
  printf("fresh modifiers=%d\n", d->GetModifiers().Length());
  d->SetModifiers(mods);
  printf("modifiers read back:");
  for (int i = 1; i <= d->GetModifiers().Length(); i++)
    printf(" %d", (int)d->GetModifiers().Value(i));
  printf(" (written, as ordinals: %d %d %d)\n", (int)XCAFDimTolObjects_DimensionModif_AnyCrossSection,
         (int)XCAFDimTolObjects_DimensionModif_Square, (int)XCAFDimTolObjects_DimensionModif_StatisticalTolerance);
  d->SetModifiers(NCollection_Sequence<XCAFDimTolObjects_DimensionModif>());
  printf("after clearing: modifiers=%d\n", d->GetModifiers().Length());

  auto cls = [](XCAFDimTolObjects_DimensionType t) {
    return std::make_pair(XCAFDimTolObjects_DimensionObject::IsDimensionalLocation(t),
                          XCAFDimTolObjects_DimensionObject::IsDimensionalSize(t));
  };
  auto p1 = cls(XCAFDimTolObjects_DimensionType_Location_LinearDistance);
  auto p2 = cls(XCAFDimTolObjects_DimensionType_Size_Diameter);
  auto p3 = cls(XCAFDimTolObjects_DimensionType_CommonLabel);
  printf("classifiers (location, size): LinearDistance=(%s, %s) Diameter=(%s, %s) CommonLabel=(%s, %s)\n",
         tf(p1.first), tf(p1.second), tf(p2.first), tf(p2.second), tf(p3.first), tf(p3.second));
  int both = 0;
  for (int t = 0; t <= (int)XCAFDimTolObjects_DimensionType_DimensionPresentation; t++)
  {
    auto p = cls((XCAFDimTolObjects_DimensionType)t);
    if (p.first && p.second)
      both++;
  }
  printf("types that are both location and size: %d\n", both);
  return 0;
}
