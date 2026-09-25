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
#include <XCAFDoc_Volume.hxx>
#include <XCAFDoc_Centroid.hxx>
#include <BRepPrimAPI_MakeSphere.hxx>
#include <TopExp_Explorer.hxx>

// Supplement to 766-xcaf-xde for XDEAreaVolumeCentroidTests and XDEAssemblyOperationTests: the tests'
// own scenarios through the calls the bridge makes, with the raw doubles printed at full precision.
//  - area / volume / centroid: box 10x20x30 added with AddShape(box, true) (Document.addShape's
//    default), then XCAFDoc_Area / _Volume / _Centroid Set and Get on that free-shape label;
//  - getComponents / userCount: a box added with AddShape(box, true), an assembly from NewShape, one
//    component (identity location), then GetComponents / GetReferredShape / GetUsers;
//  - updateAssemblies: a 10x10x10 part added with AddShape(part, false), one component translated 20 in x,
//    UpdateAssemblies, then NbComponents and the solids of the assembly's shape.
int main()
{
  {
    Handle(TDocStd_Application) app;
    Handle(TDocStd_Document)    d  = newDoc(app);
    Handle(XCAFDoc_ShapeTool)   st = XCAFDoc_DocumentTool::ShapeTool(d->Main());
    TDF_Label                   l  = st->AddShape(centredBox(10, 20, 30), true);
    XCAFDoc_Area::Set(l, 2200.0);
    XCAFDoc_Volume::Set(l, 6000.0);
    XCAFDoc_Centroid::Set(l, gp_Pnt(5, 10, 15));
    double area = -1, vol = -1;
    gp_Pnt c;
    bool   a = XCAFDoc_Area::Get(l, area);
    bool   v = XCAFDoc_Volume::Get(l, vol);
    bool   g = XCAFDoc_Centroid::Get(l, c);
    printf("area: Get=%s value=%.17g; volume: Get=%s value=%.17g; centroid: Get=%s value=(%.17g, %.17g, %.17g)\n", tf(a), area,
           tf(v), vol, tf(g), c.X(), c.Y(), c.Z());
  }
  {
    Handle(TDocStd_Application) app;
    Handle(TDocStd_Document)    d  = newDoc(app);
    Handle(XCAFDoc_ShapeTool)   st = XCAFDoc_DocumentTool::ShapeTool(d->Main());
    TDF_Label                   box = st->AddShape(centredBox(10, 20, 30), true);
    TDF_Label                   asmL = st->NewShape();
    TDF_Label                   comp = st->AddComponent(asmL, box, TopLoc_Location());
    TDF_LabelSequence           comps;
    XCAFDoc_ShapeTool::GetComponents(asmL, comps);
    TDF_Label referred;
    bool      ok = XCAFDoc_ShapeTool::GetReferredShape(comp, referred);
    TDF_LabelSequence users;
    printf("getComponents: component null=%s GetComponents=%d first IsEqual component=%s GetReferredShape=%s referred null=%s "
           "referred IsEqual box=%s\n",
           tf(comp.IsNull()), comps.Length(), tf(comps.Length() > 0 && comps.Value(1).IsEqual(comp)), tf(ok),
           tf(referred.IsNull()), tf(referred.IsEqual(box)));
    printf("userCount: GetUsers(box)=%d\n", XCAFDoc_ShapeTool::GetUsers(box, users));
  }
  {
    Handle(TDocStd_Application) app;
    Handle(TDocStd_Document)    d    = newDoc(app);
    Handle(XCAFDoc_ShapeTool)   st   = XCAFDoc_DocumentTool::ShapeTool(d->Main());
    TDF_Label                   part = st->AddShape(centredBox(10, 10, 10), false);
    TDF_Label                   asmL = st->NewShape();
    gp_Trsf                     t;
    t.SetTranslation(gp_Vec(20, 0, 0));
    TDF_Label comp = st->AddComponent(asmL, part, TopLoc_Location(t));
    st->UpdateAssemblies();
    int solids = 0;
    for (TopExp_Explorer e(XCAFDoc_ShapeTool::GetShape(asmL), TopAbs_SOLID); e.More(); e.Next())
      solids++;
    printf("updateAssemblies: component null=%s NbComponents=%d solids in the assembly shape=%d\n", tf(comp.IsNull()),
           XCAFDoc_ShapeTool::NbComponents(asmL), solids);
  }
  return 0;
}
