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

#include <XCAFDoc_Area.hxx>
#include <Quantity_ColorRGBA.hxx>
#include <TColStd_HSequenceOfExtendedString.hxx>
#include <XCAFDoc_Volume.hxx>
#include <XCAFDoc_Centroid.hxx>
#include <XCAFDoc_LayerTool.hxx>
#include <XCAFDoc_Editor.hxx>
#include <TDocStd_XLink.hxx>
#include <BRepPrimAPI_MakeSphere.hxx>
#include <BRep_Builder.hxx>
#include <TopoDS_Compound.hxx>
#include <TopExp_Explorer.hxx>

// XDE* tests and XLinkTests: XCAFDoc area / volume / centroid attributes, ShapeTool assembly and
// query calls, ColorTool by shape, XCAFDoc_Editor Expand / RescaleGeometry, LayerTool, TDocStd_XLink.
int main()
{
  Handle(TDocStd_Application) app;
  Handle(TDocStd_Document)    d  = newDoc(app);
  Handle(XCAFDoc_ShapeTool)   st = XCAFDoc_DocumentTool::ShapeTool(d->Main());
  TopoDS_Shape                box = centredBox(10, 20, 30);
  TDF_Label                   bl  = st->AddShape(box, true);
  XCAFDoc_Area::Set(bl, 2200.0);
  XCAFDoc_Volume::Set(bl, 6000.0);
  XCAFDoc_Centroid::Set(bl, gp_Pnt(5, 10, 15));
  double  area = 0, vol = 0;
  gp_Pnt  cen;
  XCAFDoc_Area::Get(bl, area);
  XCAFDoc_Volume::Get(bl, vol);
  XCAFDoc_Centroid::Get(bl, cen);
  printf("Area=%g Volume=%g Centroid=(%g, %g, %g)\n", area, vol, cen.X(), cen.Y(), cen.Z());

  TDF_Label part = st->AddShape(centredBox(10, 10, 10), false);
  TDF_Label asmL = st->NewShape();
  gp_Trsf   t1, t2;
  t2.SetTranslation(gp_Vec(20, 0, 0));
  TDF_Label c1 = st->AddComponent(asmL, part, TopLoc_Location(t1));
  TDF_Label c2 = st->AddComponent(asmL, part, TopLoc_Location(t2));
  TDF_Label referred;
  XCAFDoc_ShapeTool::GetReferredShape(c1, referred);
  TDF_LabelSequence users;
  printf("assembly: components=%d referred IsEqual part=%s users(part)=%d", XCAFDoc_ShapeTool::NbComponents(asmL),
         tf(referred.IsEqual(part)), XCAFDoc_ShapeTool::GetUsers(part, users));
  st->RemoveComponent(c2);
  printf(" after RemoveComponent=%d", XCAFDoc_ShapeTool::NbComponents(asmL));
  st->UpdateAssemblies();
  int solids = 0;
  for (TopExp_Explorer e(XCAFDoc_ShapeTool::GetShape(asmL), TopAbs_SOLID); e.More(); e.Next())
    solids++;
  printf(" after UpdateAssemblies assembly solids=%d\n", solids);

  Handle(XCAFDoc_ColorTool) ct = XCAFDoc_DocumentTool::ColorTool(d->Main());
  TopoDS_Shape              cb = centredBox(5, 5, 5);
  st->AddShape(cb, true);
  ct->SetColor(cb, Quantity_ColorRGBA(Quantity_Color(0.2, 0.4, 0.6, Quantity_TOC_RGB), 0.5f), XCAFDoc_ColorGen);
  Quantity_ColorRGBA got;
  bool               isSet = ct->GetColor(cb, XCAFDoc_ColorGen, got);
  printf("ColorTool by shape: set=%s rgba=(%g, %g, %g, %g)", tf(isSet), got.GetRGB().Red(), got.GetRGB().Green(), got.GetRGB().Blue(),
         got.Alpha());
  TopoDS_Shape ob = centredBox(6, 6, 6);
  st->AddShape(ob, true);
  ct->SetColor(ob, Quantity_ColorRGBA(Quantity_Color(1, 0, 0, Quantity_TOC_RGB), 1.0f), XCAFDoc_ColorGen);
  ct->GetColor(ob, XCAFDoc_ColorGen, got);
  printf(" opaque alpha=%g", got.Alpha());
  ct->SetVisibility(bl, false);
  printf(" visibility after false=%s", tf(XCAFDoc_ColorTool::IsVisible(bl)));
  ct->SetVisibility(bl, true);
  printf(" after true=%s\n", tf(XCAFDoc_ColorTool::IsVisible(bl)));

  TopoDS_Compound comp;
  BRep_Builder    bb;
  bb.MakeCompound(comp);
  bb.Add(comp, centredBox(10, 20, 30));
  bb.Add(comp, BRepPrimAPI_MakeSphere(5).Shape());
  TDF_Label cl = st->AddShape(comp, false);
  bool      ex = XCAFDoc_Editor::Expand(d->Main(), cl, false);
  printf("Editor::Expand(two-body compound)=%s components after=%d", tf(ex), XCAFDoc_ShapeTool::NbComponents(cl));
  TDF_Label rb = st->AddShape(centredBox(10, 20, 30), true);
  printf(" RescaleGeometry(free box label, 2, force)=%s\n", tf(XCAFDoc_Editor::RescaleGeometry(rb, 2.0, true)));

  Handle(XCAFDoc_LayerTool) lt = XCAFDoc_DocumentTool::LayerTool(d->Main());
  lt->SetLayer(bl, TCollection_ExtendedString("Layer1"));
  printf("LayerTool: IsSet(Layer1)=%s", tf(lt->IsSet(bl, TCollection_ExtendedString("Layer1"))));
  TDF_Label other = st->AddShape(centredBox(2, 2, 2), true);
  lt->SetLayer(other, TCollection_ExtendedString("TestLayer"));
  Handle(TColStd_HSequenceOfExtendedString) names = lt->GetLayers(other);
  printf(" layers(other)=%d [0]=%s", names->Length(), TCollection_AsciiString(names->Value(1)).ToCString());
  TDF_Label ll;
  bool      found = lt->FindLayer(TCollection_ExtendedString("TestLayer"), ll);
  lt->SetVisibility(ll, false);
  printf(" FindLayer=%s visibility after false=%s", tf(found), tf(lt->IsVisible(ll)));
  lt->SetVisibility(ll, true);
  printf(" after true=%s\n", tf(lt->IsVisible(ll)));

  TDF_LabelSequence all, freeS;
  st->GetShapes(all);
  st->GetFreeShapes(freeS);
  TDF_Label f1, f2;
  TopoDS_Shape q = centredBox(3, 3, 3);
  TDF_Label    ql = st->AddShape(q, true);
  printf("ShapeTool: shapes=%d free=%d FindShape=%s Search=%s", all.Length(), freeS.Length(), tf(st->FindShape(q, f1)),
         tf(st->Search(q, f2)));
  TDF_Label nl = st->NewShape();
  printf(" RemoveShape(new)=%s IsTopLevel(free)=%s IsComponent(free)=%s\n", tf(st->RemoveShape(nl)), tf(st->IsTopLevel(ql)),
         tf(XCAFDoc_ShapeTool::IsComponent(ql)));

  Handle(TDocStd_XLink) xl = TDocStd_XLink::Set(tagLabel(d, 2));
  xl->DocumentEntry("/doc/path");
  xl->LabelEntry("0:1:2");
  printf("XLink: set=%s document=%s label=%s\n", tf(!xl.IsNull()), xl->DocumentEntry().ToCString(), xl->LabelEntry().ToCString());
  return 0;
}
