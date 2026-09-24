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
#include <XCAFDimTolObjects_DimensionObject.hxx>
#include <TColStd_HArray1OfReal.hxx>
#include <TObj_Application.hxx>

// Supplement to 766-xcaf-issue1481-1588-173, which measured one dimension only and a
// NewDocument("TObjBin") document. This probe mirrors the tests' own flows through the calls the
// bridge makes (occtDocumentCreateDimensionImpl, OCCTTObjApplication*).
//
// Issue1481DimensionRefCountTests: a dimension registered with the single-shape overload
// SetDimension(shape, dim), with and without a tolerance object, on one shape and on two shapes.
// Issue1588TObjApplicationReleaseTests: TObj_Application state after the calls the tests make.

// The bridge's occtDocumentCreateDimensionImpl, minus the label registry: returns the dimension label.
static TDF_Label makeDimension(const Handle(TDocStd_Document)& d, const TDF_Label& shape, double value, bool tol,
                               double lo, double up, bool singleOverload)
{
  Handle(XCAFDoc_DimTolTool) t = XCAFDoc_DocumentTool::DimTolTool(d->Main());
  Handle(XCAFDimTolObjects_DimensionObject) o = new XCAFDimTolObjects_DimensionObject();
  o->SetQualifier(XCAFDimTolObjects_DimensionQualifier_None);
  o->SetAngularQualifier(XCAFDimTolObjects_AngularQualifier_None);
  o->SetNbOfDecimalPlaces(0, 0);
  o->SetClassOfTolerance(false, XCAFDimTolObjects_DimensionFormVariance_None, XCAFDimTolObjects_DimensionGrade_IT01);
  o->SetType(XCAFDimTolObjects_DimensionType_Size_Diameter);
  Handle(TColStd_HArray1OfReal) vals = new TColStd_HArray1OfReal(1, 1);
  vals->SetValue(1, value);
  o->SetValues(vals);
  if (tol)
  {
    o->SetLowerTolValue(lo);
    o->SetUpperTolValue(up);
  }
  TDF_Label dl = t->AddDimension();
  if (singleOverload)
    t->SetDimension(shape, dl);
  else
  {
    TDF_LabelSequence seq;
    seq.Append(shape);
    t->SetDimension(seq, seq, dl);
  }
  Handle(XCAFDoc_Dimension) a;
  dl.FindAttribute(XCAFDoc_Dimension::GetID(), a);
  a->SetObject(o);
  return dl;
}

static int refs(const Handle(TDocStd_Document)& d, const TDF_Label& shape)
{
  TDF_LabelSequence s;
  XCAFDoc_DocumentTool::DimTolTool(d->Main())->GetRefDimensionLabels(shape, s);
  return s.Length();
}

static int dimensionCount(const Handle(TDocStd_Document)& d)
{
  TDF_LabelSequence s;
  XCAFDoc_DocumentTool::DimTolTool(d->Main())->GetDimensionLabels(s);
  return s.Length();
}

int main()
{
  {
    Handle(TDocStd_Application) app;
    Handle(TDocStd_Document)    d = newDoc(app);
    TDF_Label s = XCAFDoc_DocumentTool::ShapeTool(d->Main())->AddShape(centredBox(10, 10, 10), false);
    makeDimension(d, s, 20.0, false, 0, 0, true);
    printf("#1481 one shape, single-shape overload: dimension labels=%d refs=%d\n", dimensionCount(d), refs(d, s));
  }
  {
    Handle(TDocStd_Application) app;
    Handle(TDocStd_Document)    d = newDoc(app);
    TDF_Label s = XCAFDoc_DocumentTool::ShapeTool(d->Main())->AddShape(centredBox(10, 10, 10), false);
    makeDimension(d, s, 20.0, true, -0.1, 0.1, true);
    printf("#1481 one shape with a tolerance (-0.1, 0.1), single-shape overload: dimension labels=%d refs=%d\n",
           dimensionCount(d), refs(d, s));
  }
  {
    Handle(TDocStd_Application) app;
    Handle(TDocStd_Document)    d  = newDoc(app);
    TDF_Label                   s1 = XCAFDoc_DocumentTool::ShapeTool(d->Main())->AddShape(centredBox(10, 10, 10), false);
    TDF_Label                   s2 = XCAFDoc_DocumentTool::ShapeTool(d->Main())->AddShape(centredBox(20, 20, 20), false);
    makeDimension(d, s1, 5.0, false, 0, 0, true);
    makeDimension(d, s2, 15.0, false, 0, 0, true);
    printf("#1481 two shapes, one dimension each, single-shape overload: dimension labels=%d refs(shape1)=%d refs(shape2)=%d\n",
           dimensionCount(d), refs(d, s1), refs(d, s2));
  }
  {
    Handle(TDocStd_Application) app;
    Handle(TDocStd_Document)    d = newDoc(app);
    TDF_Label s = XCAFDoc_DocumentTool::ShapeTool(d->Main())->AddShape(centredBox(10, 10, 10), false);
    makeDimension(d, s, 20.0, false, 0, 0, false);
    printf("#1481 (defect, for contrast) one shape, sequence overload: refs=%d\n", refs(d, s));
  }

  // Issue1588: the bridge's OCCTTObjApplicationGetInstance / SetVerbose / IsVerbose / CreateDocument.
  Handle(TObj_Application) a = TObj_Application::GetInstance();
  printf("#1588 GetInstance null=%s", tf(a.IsNull()));
  a->SetVerbose(true);
  printf(" IsVerbose after SetVerbose(true)=%s", tf(a->IsVerbose()));
  a->SetVerbose(false);
  printf(" after SetVerbose(false)=%s", tf(a->IsVerbose()));
  Handle(TDocStd_Document) doc;
  bool                     created = a->CreateNewDocument(doc, TCollection_ExtendedString("BinOcaf"));
  printf(" CreateNewDocument(BinOcaf)=%s document null=%s", tf(created), tf(doc.IsNull()));
  printf(" second GetInstance is the same instance=%s\n", tf(TObj_Application::GetInstance() == a));
  return 0;
}
