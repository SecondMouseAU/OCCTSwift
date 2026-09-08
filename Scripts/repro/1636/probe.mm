// Ground truth for #1636: what ShapeFix_FreeBounds::GetShape() holds, next to the compound of
// wires the bridge returns today, and whether the connection step ever rewrites the source shape.
//
// Build: see CLAUDE.md, "Compile a Ground Truth C++ Test".

#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepBuilderAPI_MakePolygon.hxx>
#include <BRepBuilderAPI_Transform.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRep_Builder.hxx>
#include <BRep_Tool.hxx>
#include <ShapeFix_FreeBounds.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Compound.hxx>
#include <gp_Trsf.hxx>

#include <cstdio>

static int count(const TopoDS_Shape& s, TopAbs_ShapeEnum t)
{
  int n = 0;
  for (TopExp_Explorer e(s, t); e.More(); e.Next())
    n++;
  return n;
}

static const char* typeName(const TopoDS_Shape& s)
{
  if (s.IsNull())
    return "NULL";
  switch (s.ShapeType())
  {
    case TopAbs_COMPOUND: return "COMPOUND";
    case TopAbs_COMPSOLID: return "COMPSOLID";
    case TopAbs_SOLID: return "SOLID";
    case TopAbs_SHELL: return "SHELL";
    case TopAbs_FACE: return "FACE";
    case TopAbs_WIRE: return "WIRE";
    case TopAbs_EDGE: return "EDGE";
    case TopAbs_VERTEX: return "VERTEX";
    default: return "SHAPE";
  }
}

static TopoDS_Face rect(double x0, double y0, double dx, double dy, double z)
{
  BRepBuilderAPI_MakePolygon p;
  p.Add(gp_Pnt(x0, y0, z));
  p.Add(gp_Pnt(x0 + dx, y0, z));
  p.Add(gp_Pnt(x0 + dx, y0 + dy, z));
  p.Add(gp_Pnt(x0, y0 + dy, z));
  p.Close();
  return BRepBuilderAPI_MakeFace(p.Wire());
}

static void run(const char* label, const TopoDS_Shape& in, double sewtol, double closetol)
{
  printf("=== %s   sewtol %g  closetol %g\n", label, sewtol, closetol);
  printf("   input                 : %-9s faces %d  wires %d  edges %d  vertices %d\n",
         typeName(in), count(in, TopAbs_FACE), count(in, TopAbs_WIRE), count(in, TopAbs_EDGE),
         count(in, TopAbs_VERTEX));

  ShapeFix_FreeBounds fixer(in, sewtol, closetol, true, true);
  TopoDS_Compound     closed = fixer.GetClosedWires();
  TopoDS_Compound     open   = fixer.GetOpenWires();
  const TopoDS_Shape& got    = fixer.GetShape();

  // What the bridge builds today.
  BRep_Builder    b;
  TopoDS_Compound bridge;
  b.MakeCompound(bridge);
  if (!closed.IsNull())
    b.Add(bridge, closed);
  if (!open.IsNull())
    b.Add(bridge, open);

  printf("   bridge result today   : %-9s faces %d  wires %d  (closed %d, open %d)\n",
         typeName(bridge), count(bridge, TopAbs_FACE), count(bridge, TopAbs_WIRE),
         count(closed, TopAbs_WIRE), count(open, TopAbs_WIRE));
  printf("   GetShape()            : %-9s faces %d  wires %d  edges %d  vertices %d\n",
         typeName(got), count(got, TopAbs_FACE), count(got, TopAbs_WIRE), count(got, TopAbs_EDGE),
         count(got, TopAbs_VERTEX));
  printf("   GetShape().IsSame(in) : %s\n", got.IsSame(in) ? "true" : "false");
  printf("\n");
}

int main()
{
  BRep_Builder b;

  // 1. One face, the shape the current test uses.
  {
    TopoDS_Compound c;
    b.MakeCompound(c);
    b.Add(c, rect(0, 0, 10, 10, 0));
    run("single face in a compound", c, 1e-6, 1e-4);
  }

  // 2. Two faces sharing an edge exactly.
  {
    TopoDS_Compound c;
    b.MakeCompound(c);
    b.Add(c, rect(0, 0, 10, 10, 0));
    b.Add(c, rect(10, 0, 10, 10, 0));
    run("two adjacent faces", c, 1e-6, 1e-4);
  }

  // 3. Two faces with a gap between them wider than sewtol but under closetol.
  {
    TopoDS_Compound c;
    b.MakeCompound(c);
    b.Add(c, rect(0, 0, 10, 10, 0));
    b.Add(c, rect(10.00005, 0, 10, 10, 0));
    run("two faces, 5e-5 gap", c, 1e-6, 1e-3);
    TopoDS_Compound c2;
    b.MakeCompound(c2);
    b.Add(c2, rect(0, 0, 10, 10, 0));
    b.Add(c2, rect(10.00005, 0, 10, 10, 0));
    run("two faces, 5e-5 gap, equal tolerances (the silent no-op)", c2, 1e-4, 1e-4);
  }

  // 4. An open shell: a box with one face dropped, as a compound of the five remaining faces.
  {
    TopoDS_Shape    box = BRepPrimAPI_MakeBox(10.0, 10.0, 10.0).Shape();
    TopoDS_Compound c;
    b.MakeCompound(c);
    int i = 0;
    for (TopExp_Explorer e(box, TopAbs_FACE); e.More(); e.Next(), i++)
      if (i != 0)
        b.Add(c, e.Current());
    run("open box shell, five faces", c, 1e-6, 1e-4);
  }
  return 0;
}
