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

// GDTUnifiedReadTests: what XCAFDimTolObjects_DimensionObject reports for a range, a plus/minus and
// a simple dimension, a class of tolerance, a tolerance written onto a range, and the two enum sizes.
static Handle(XCAFDimTolObjects_DimensionObject) simple(XCAFDimTolObjects_DimensionType t, double v)
{
  Handle(XCAFDimTolObjects_DimensionObject) o = new XCAFDimTolObjects_DimensionObject();
  o->SetType(t);
  Handle(TColStd_HArray1OfReal) vals = new TColStd_HArray1OfReal(1, 1);
  vals->SetValue(1, v);
  o->SetValues(vals);
  return o;
}

static void show(const char* what, const Handle(XCAFDimTolObjects_DimensionObject)& o)
{
  Handle(TColStd_HArray1OfReal) vals = o->GetValues();
  printf("%s: range=%s plusMinus=%s nvals=%d firstSlot=%g value=%g lower=%g upper=%g lowerTol=%g upperTol=%g class=%s\n",
         what, tf(o->IsDimWithRange()), tf(o->IsDimWithPlusMinusTolerance()), vals.IsNull() ? 0 : vals->Length(),
         vals.IsNull() ? 0.0 : vals->Value(vals->Lower()), o->GetValue(), o->GetLowerBound(), o->GetUpperBound(),
         o->GetLowerTolValue(), o->GetUpperTolValue(), tf(o->IsDimWithClassOfTolerance()));
}

int main()
{
  Handle(XCAFDimTolObjects_DimensionObject) r = simple(XCAFDimTolObjects_DimensionType_Size_Diameter, 10);
  r->SetLowerBound(10);
  r->SetUpperBound(12);
  show("range 10..12", r);
  bool lo = r->SetLowerTolValue(-0.3);
  bool up = r->SetUpperTolValue(0.7);
  printf("tolerance written onto the range: SetLowerTolValue=%s SetUpperTolValue=%s\n", tf(lo), tf(up));
  show("range after tolerance write", r);

  Handle(XCAFDimTolObjects_DimensionObject) pm = simple(XCAFDimTolObjects_DimensionType_Size_Diameter, 20);
  pm->SetLowerTolValue(-0.3);
  pm->SetUpperTolValue(0.7);
  show("plus/minus 20 -0.3/+0.7", pm);

  Handle(XCAFDimTolObjects_DimensionObject) s = simple(XCAFDimTolObjects_DimensionType_Size_Thickness, 3.5);
  show("simple thickness 3.5", s);

  Handle(XCAFDimTolObjects_DimensionObject) h = simple(XCAFDimTolObjects_DimensionType_Size_Diameter, 20);
  h->SetClassOfTolerance(true, XCAFDimTolObjects_DimensionFormVariance_H, XCAFDimTolObjects_DimensionGrade_IT7);
  bool                                    isHole = false;
  XCAFDimTolObjects_DimensionFormVariance fv     = XCAFDimTolObjects_DimensionFormVariance_None;
  XCAFDimTolObjects_DimensionGrade        g      = XCAFDimTolObjects_DimensionGrade_IT01;
  h->GetClassOfTolerance(isHole, fv, g);
  printf("H7 hole: isHole=%s formVariance=%d grade=%d\n", tf(isHole), (int)fv, (int)g);
  show("H7 hole", h);

  r->SetClassOfTolerance(false, XCAFDimTolObjects_DimensionFormVariance_JS, XCAFDimTolObjects_DimensionGrade_IT9);
  r->GetClassOfTolerance(isHole, fv, g);
  printf("range + js9 shaft: isHole=%s formVariance=%d grade=%d range=%s\n", tf(isHole), (int)fv, (int)g,
         tf(r->IsDimWithRange()));

  printf("XCAFDimTolObjects_DimensionFormVariance cases=%d\n", (int)XCAFDimTolObjects_DimensionFormVariance_ZC + 1);
  printf("XCAFDimTolObjects_DimensionGrade cases=%d\n", (int)XCAFDimTolObjects_DimensionGrade_IT18 + 1);
  printf("Size_Diameter ordinal=%d Perpendicularity-type tolerance ordinal is in the tolerance probe\n",
         (int)XCAFDimTolObjects_DimensionType_Size_Diameter);
  return 0;
}
