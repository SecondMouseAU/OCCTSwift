// Second probe for OCCTSwift #1036: what a bounding-box guard would decide, and how much slack
// Bnd_Box's own gap adds. The guard under test rejects a perspective projection whose shape reaches
// the eye plane, i.e. max over the shape of (P . viewDir) >= focus.

#include <BRepBndLib.hxx>
#include <BRepBuilderAPI_Transform.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeSphere.hxx>
#include <Bnd_Box.hxx>
#include <HLRAlgo_Projector.hxx>
#include <HLRBRep_Algo.hxx>
#include <HLRBRep_HLRToShape.hxx>
#include <TopExp.hxx>
#include <TopExp_Explorer.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Shape.hxx>
#include <TopoDS_Vertex.hxx>
#include <gp_Ax2.hxx>
#include <gp_Dir.hxx>
#include <gp_Pnt.hxx>
#include <gp_Trsf.hxx>

#include <BRep_Tool.hxx>
#include <cstdio>

// The support function of the axis-aligned bounding box in direction d: the largest value of
// (P . d) over the box, which bounds the same quantity over the shape inside it.
static double bboxSupport(const TopoDS_Shape& shape, const gp_Dir& d, bool& ok, double& gap)
{
  Bnd_Box bb;
  BRepBndLib::Add(shape, bb);
  if (bb.IsVoid())
  {
    ok = false;
    return 0.0;
  }
  ok = true;
  gap = bb.GetGap();
  double xmin, ymin, zmin, xmax, ymax, zmax;
  bb.Get(xmin, ymin, zmin, xmax, ymax, zmax);
  return (d.X() > 0 ? xmax * d.X() : xmin * d.X()) + (d.Y() > 0 ? ymax * d.Y() : ymin * d.Y())
         + (d.Z() > 0 ? zmax * d.Z() : zmin * d.Z());
}

// The true maximum of (P . d) over the shape's vertices, for comparison on polyhedra.
static double vertexMax(const TopoDS_Shape& shape, const gp_Dir& d)
{
  TopTools_IndexedMapOfShape verts;
  TopExp::MapShapes(shape, TopAbs_VERTEX, verts);
  double best = -1e300;
  for (int i = 1; i <= verts.Extent(); i++)
  {
    gp_Pnt p = BRep_Tool::Pnt(TopoDS::Vertex(verts(i)));
    double v = p.X() * d.X() + p.Y() * d.Y() + p.Z() * d.Z();
    if (v > best)
      best = v;
  }
  return best;
}

static void row(const char* label, const TopoDS_Shape& shape, const gp_Dir& d, double focus)
{
  bool   ok  = false;
  double gap = 0.0;
  double sup = bboxSupport(shape, d, ok, gap);
  double vm  = vertexMax(shape, d);

  double xmin = 0, xmax = 0;
  int    nEdges = 0;
  bool   built  = false;
  try
  {
    gp_Ax2               projAxis(gp_Pnt(0, 0, 0), d);
    HLRAlgo_Projector    projector(projAxis, focus);
    Handle(HLRBRep_Algo) hlrAlgo = new HLRBRep_Algo();
    hlrAlgo->Add(shape);
    hlrAlgo->Projector(projector);
    hlrAlgo->Update();
    hlrAlgo->Hide();
    HLRBRep_HLRToShape shapes(hlrAlgo);
    TopoDS_Shape       visible = shapes.VCompound();
    if (!visible.IsNull())
    {
      for (TopExp_Explorer e(visible, TopAbs_EDGE); e.More(); e.Next())
        nEdges++;
      if (nEdges > 0)
      {
        Bnd_Box bb;
        BRepBndLib::Add(visible, bb);
        double a, b, c, e2, f2, g2;
        bb.Get(a, b, c, e2, f2, g2);
        xmin  = a;
        xmax  = e2;
        built = true;
      }
    }
  }
  catch (...)
  {
  }

  printf("%-34s focus=%-9g support=%11.5f vertexMax=%11.5f gap=%.2e guard=%s  built=%s",
         label,
         focus,
         sup,
         vm,
         gap,
         sup >= focus ? "REJECT" : "accept",
         built ? "yes" : "no ");
  if (built)
    printf(" x=[%12.4f,%12.4f]", xmin, xmax);
  printf("\n");
}

int main()
{
  gp_Dir dz(0, 0, 1);

  printf("== a shape far BEHIND the picture plane (negative Z) is a correct, shrunken answer ==\n");
  {
    TopoDS_Shape s = BRepPrimAPI_MakeBox(gp_Pnt(20, -5, -1010), gp_Pnt(30, 5, -1000)).Shape();
    row("z=[-1010,-1000] offset", s, dz, 50);
  }

  printf("\n== the boundary: box top at z=10, focus straddling it ==\n");
  {
    TopoDS_Shape s = BRepPrimAPI_MakeBox(gp_Pnt(20, -5, 0), gp_Pnt(30, 5, 10)).Shape();
    row("z=[0,10] offset", s, dz, 9.9999);
    row("z=[0,10] offset", s, dz, 10.0);
    row("z=[0,10] offset", s, dz, 10.0001);
    row("z=[0,10] offset", s, dz, 10.001);
    row("z=[0,10] offset", s, dz, 10.01);
    row("z=[0,10] offset", s, dz, 11.0);
  }

  printf("\n== conservatism: a rotated box, where the AABB overshoots the true extent ==\n");
  {
    gp_Trsf t;
    t.SetRotation(gp_Ax1(gp_Pnt(0, 0, 0), gp_Dir(1, 0, 0)), 0.7853981633974483);
    TopoDS_Shape s0 = BRepPrimAPI_MakeBox(gp_Pnt(20, -5, 0), gp_Pnt(30, 5, 10)).Shape();
    TopoDS_Shape s  = BRepBuilderAPI_Transform(s0, t).Shape();
    row("rotated 45deg about X", s, dz, 12.0);
    row("rotated 45deg about X", s, dz, 20.0);
  }

  printf("\n== a curved shape, where vertices under-report and the bbox does not ==\n");
  {
    TopoDS_Shape s = BRepPrimAPI_MakeSphere(gp_Pnt(0, 0, 0), 10).Shape();
    row("sphere r=10 at origin", s, dz, 9.5);
    row("sphere r=10 at origin", s, dz, 10.5);
    row("sphere r=10 at origin", s, dz, 30.0);
  }
  return 0;
}
