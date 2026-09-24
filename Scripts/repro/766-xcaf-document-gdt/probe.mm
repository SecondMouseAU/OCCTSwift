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
#include <XCAFDoc_Dimension.hxx>
#include <XCAFDoc_Datum.hxx>
#include <XCAFDimTolObjects_DimensionObject.hxx>
#include <XCAFDimTolObjects_DatumObject.hxx>
#include <XCAFDimTolObjects_DimensionType.hxx>
#include <XCAFDimTolObjects_GeomToleranceType.hxx>
#include <TColStd_HArray1OfReal.hxx>
#include <TCollection_HAsciiString.hxx>

// DocumentGDTTests: the XCAFDimTolObjects_DimensionObject calls behind createDimension /
// setDimensionBounds / dimension(at:), and the kernel enum sizes the two enum tests pin.
static Handle(XCAFDimTolObjects_DimensionObject) dim(double v, bool pm, double lo, double up)
{
  Handle(XCAFDimTolObjects_DimensionObject) o = new XCAFDimTolObjects_DimensionObject();
  o->SetType(XCAFDimTolObjects_DimensionType_Size_Diameter);
  Handle(TColStd_HArray1OfReal) vals = new TColStd_HArray1OfReal(1, pm ? 3 : 1);
  vals->SetValue(1, v);
  if (pm)
  {
    vals->SetValue(2, lo);
    vals->SetValue(3, up);
  }
  o->SetValues(vals);
  return o;
}

static void show(const char* what, const Handle(XCAFDimTolObjects_DimensionObject)& o)
{
  printf("%s: range=%s plusMinus=%s value=%g lowerTol=%g upperTol=%g lower=%g upper=%g\n", what,
         tf(o->IsDimWithRange()), tf(o->IsDimWithPlusMinusTolerance()), o->GetValue(),
         o->GetLowerTolValue(), o->GetUpperTolValue(), o->GetLowerBound(), o->GetUpperBound());
}

int main()
{
  // The corruption the bridge's pre-write guard exists for: bounds written onto plus/minus.
  Handle(XCAFDimTolObjects_DimensionObject) pm = dim(20, true, -0.3, 0.7);
  show("plus/minus before", pm);
  pm->SetLowerBound(10);
  pm->SetUpperBound(12);
  show("plus/minus after SetLower/UpperBound(10, 12) (bridge refuses before this)", pm);
  // Simple -> range, the conversion setDimensionBounds is for.
  Handle(XCAFDimTolObjects_DimensionObject) s = dim(20, false, 0, 0);
  s->SetLowerBound(10);
  s->SetUpperBound(12);
  show("simple after SetLower/UpperBound(10, 12)", s);
  // createAndReadDimension: radius 25 -0.1/+0.1 (occtDimensionApplyTolerance writes [v, lo, up]).
  Handle(XCAFDimTolObjects_DimensionObject) r = dim(25, true, -0.1, 0.1);
  r->SetType(XCAFDimTolObjects_DimensionType_Size_Radius);
  show("radius 25 -0.1/+0.1", r);
  printf("radius type ordinal=%d\n", (int)r->GetType());

  // Stored through the document: AddDimension + SetDimension + SetObject, then read back.
  Handle(TDocStd_Application) app;
  Handle(TDocStd_Document)    d = newDoc(app);
  Handle(XCAFDoc_DimTolTool)  t = XCAFDoc_DocumentTool::DimTolTool(d->Main());
  TDF_Label shape = XCAFDoc_DocumentTool::ShapeTool(d->Main())->AddShape(centredBox(100, 50, 25), false);
  TDF_Label dl    = t->AddDimension();
  // The single-shape overload OCCTDocumentCreateDimension's implementation uses (#1481).
  t->SetDimension(shape, dl);
  Handle(XCAFDoc_Dimension) da;
  dl.FindAttribute(XCAFDoc_Dimension::GetID(), da);
  da->SetObject(r);
  TDF_LabelSequence dls;
  t->GetDimensionLabels(dls);
  show("stored radius, read back via GetObject", da->GetObject());
  printf("dimension labels=%d (index of new = %d)\n", dls.Length(), dls.Length() - 1);
  TDF_LabelSequence refs;
  t->GetRefDimensionLabels(shape, refs);
  printf("ref dimension labels for the shape=%d\n", refs.Length());

  TDF_LabelSequence fresh;
  t->GetDatumLabels(fresh);
  printf("datum labels before any AddDatum=%d\n", fresh.Length());
  // Datum "A", then a second datum.
  TDF_Label             dat = t->AddDatum();
  Handle(XCAFDoc_Datum) datA;
  dat.FindAttribute(XCAFDoc_Datum::GetID(), datA);
  Handle(XCAFDimTolObjects_DatumObject) dobj = new XCAFDimTolObjects_DatumObject();
  dobj->SetName(new TCollection_HAsciiString("A"));
  datA->SetObject(dobj);
  t->AddDatum();
  TDF_LabelSequence dts;
  t->GetDatumLabels(dts);
  printf("datum[0] name=%s, datum labels after two AddDatum=%d\n",
         datA->GetObject()->GetName()->ToCString(), dts.Length());

  // Enum sizes: last enumerator + 1.
  printf("XCAFDimTolObjects_DimensionType cases=%d\n", (int)XCAFDimTolObjects_DimensionType_DimensionPresentation + 1);
  printf("XCAFDimTolObjects_GeomToleranceType cases=%d\n",
         (int)XCAFDimTolObjects_GeomToleranceType_TotalRunout + 1);
  return 0;
}
