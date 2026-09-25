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

#include <BRepMesh_IncrementalMesh.hxx>
#include <BRepPrimAPI_MakeSphere.hxx>
#include <BRep_Tool.hxx>
#include <BRep_Builder.hxx>
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepBuilderAPI_Transform.hxx>
#include <BRepBndLib.hxx>
#include <Bnd_Box.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Compound.hxx>
#include <Poly_Triangulation.hxx>

// Issue443TriangulationAttributeTests: what BRepMesh_IncrementalMesh leaves on each face, summed
// the way occtMergedTriangulation merges it (every face, located, worst deflection).
struct Merged
{
  int    faces = 0, nodes = 0, triangles = 0;
  double worst = 0;
  bool   normals = true;
  Bnd_Box nodeBox;
};

static Merged merge(const TopoDS_Shape& s, double defl)
{
  BRepMesh_IncrementalMesh m(s, defl);
  Merged r;
  for (TopExp_Explorer e(s, TopAbs_FACE); e.More(); e.Next())
  {
    TopLoc_Location            loc;
    Handle(Poly_Triangulation) t = BRep_Tool::Triangulation(TopoDS::Face(e.Current()), loc);
    if (t.IsNull())
      continue;
    r.faces++;
    r.nodes += t->NbNodes();
    r.triangles += t->NbTriangles();
    r.worst = std::max(r.worst, t->Deflection());
    r.normals = r.normals && t->HasNormals();
    for (int i = 1; i <= t->NbNodes(); i++)
      r.nodeBox.Add(t->Node(i).Transformed(loc.Transformation()));
  }
  return r;
}

static void show(const char* what, const Merged& r)
{
  double x0 = 0, y0 = 0, z0 = 0, x1 = 0, y1 = 0, z1 = 0;
  if (!r.nodeBox.IsVoid())
    r.nodeBox.Get(x0, y0, z0, x1, y1, z1);
  printf("%s: faces=%d nodes=%d triangles=%d worstDeflection=%g normals=%s nodeX=[%g, %g]\n", what, r.faces, r.nodes, r.triangles,
         r.worst, tf(r.normals), x0, x1);
}

int main()
{
  show("box 10x10x10 at 1.0", merge(centredBox(10, 10, 10), 1.0));
  TopoDS_Compound c;
  BRep_Builder    b;
  b.MakeCompound(c);
  b.Add(c, centredBox(10, 10, 10));
  gp_Trsf tr;
  tr.SetTranslation(gp_Vec(30, 0, 0));
  b.Add(c, BRepBuilderAPI_Transform(centredBox(10, 10, 10), tr, true).Shape());
  show("compound of two boxes at 1.0", merge(c, 1.0));
  show("sphere r10 at 2.0", merge(BRepPrimAPI_MakeSphere(10).Shape(), 2.0));
  show("sphere r10 at 0.2", merge(BRepPrimAPI_MakeSphere(10).Shape(), 0.2));
  gp_Trsf mv;
  mv.SetTranslation(gp_Vec(100, 0, 0));
  TopoDS_Shape moved = centredBox(10, 10, 10).Moved(TopLoc_Location(mv));
  show("box moved +100 in x (located)", merge(moved, 1.0));
  gp_Trsf mir;
  mir.SetMirror(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(1, 0, 0)));
  TopoDS_Shape mb = BRepBuilderAPI_Transform(BRepPrimAPI_MakeBox(gp_Pnt(10, 0, 0), 10, 10, 10).Shape(), mir, true).Shape();
  show("box at x 10..20 mirrored in x", merge(mb, 1.0));
  TopoDS_Shape edge = BRepBuilderAPI_MakeEdge(gp_Pnt(0, 0, 0), gp_Pnt(1, 0, 0)).Edge();
  show("a lone edge (no face)", merge(edge, 1.0));
  return 0;
}
