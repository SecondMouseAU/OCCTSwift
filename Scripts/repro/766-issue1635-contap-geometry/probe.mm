// #766 kernel parity for Issue1635ContapAnalyticGeometryTests. For each fixture it walks the
// faces in TopExp_Explorer order, as the test's contour(of:along:firstLineType:) helper does, runs
// Contap_Contour the way OCCTContapContourDirection does, and prints the first face whose first
// line has the wanted type, with every accessor the test reads.
#include <Adaptor2d_Curve2d.hxx>
#include <BRepAdaptor_Surface.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <BRepPrimAPI_MakeSphere.hxx>
#include <BRepPrimAPI_MakeTorus.hxx>
#include <BRepTopAdaptor_TopolTool.hxx>
#include <Contap_Contour.hxx>
#include <Contap_Line.hxx>
#include <Contap_Point.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <cstdio>

static const char* typeName(Contap_IType t)
{
  switch (t)
  {
    case Contap_Lin:
      return "line";
    case Contap_Circle:
      return "circle";
    case Contap_Walking:
      return "walking";
    case Contap_Restriction:
      return "restriction";
  }
  return "?";
}

static void firstFaceWith(const char* label, const TopoDS_Shape& shape, gp_Vec dir, Contap_IType wanted)
{
  int faceIndex = 0;
  for (TopExp_Explorer ex(shape, TopAbs_FACE); ex.More(); ex.Next(), faceIndex++)
  {
    Handle(BRepAdaptor_Surface)      surf = new BRepAdaptor_Surface(TopoDS::Face(ex.Current()));
    Handle(BRepTopAdaptor_TopolTool) tool = new BRepTopAdaptor_TopolTool(surf);
    Contap_Contour                   c;
    c.Init(dir);
    c.Perform(surf, tool);
    if (!c.IsDone() || c.IsEmpty() || c.NbLines() == 0 || c.Line(1).TypeContour() != wanted)
      continue;
    printf("%s: face %d, NbLines=%d\n", label, faceIndex, c.NbLines());
    for (int i = 1; i <= c.NbLines(); i++)
    {
      const Contap_Line& L = c.Line(i);
      printf("  line %d type=%s NbVertex=%d", i, typeName(L.TypeContour()), L.NbVertex());
      if (L.TypeContour() == Contap_Walking)
        printf(" NbPnts=%d", L.NbPnts());
      printf("\n");
      if (L.TypeContour() == Contap_Lin)
      {
        gp_Lin l = L.Line();
        printf("    Line origin=(%.17g, %.17g, %.17g) dir=(%.17g, %.17g, %.17g)\n", l.Location().X(),
               l.Location().Y(), l.Location().Z(), l.Direction().X(), l.Direction().Y(), l.Direction().Z());
      }
      else if (L.TypeContour() == Contap_Circle)
      {
        gp_Circ k = L.Circle();
        printf("    Circle centre=(%.17g, %.17g, %.17g) axis=(%.17g, %.17g, %.17g) xdir=(%.17g, %.17g, %.17g) r=%.17g\n",
               k.Location().X(), k.Location().Y(), k.Location().Z(), k.Axis().Direction().X(),
               k.Axis().Direction().Y(), k.Axis().Direction().Z(), k.XAxis().Direction().X(),
               k.XAxis().Direction().Y(), k.XAxis().Direction().Z(), k.Radius());
      }
      else if (L.TypeContour() == Contap_Restriction)
      {
        const Handle(Adaptor2d_Curve2d)& arc = L.Arc();
        double f = arc->FirstParameter(), l = arc->LastParameter();
        gp_Pnt2d a = arc->Value(f), b = arc->Value(l);
        printf("    Arc range=[%.17g, %.17g] Value(first)=(%.17g, %.17g) Value(last)=(%.17g, %.17g)\n", f, l,
               a.X(), a.Y(), b.X(), b.Y());
      }
      else if (L.TypeContour() == Contap_Walking && L.NbPnts() > 0)
      {
        gp_Pnt p = L.Point(1).Value();
        printf("    Point(1)=(%.17g, %.17g, %.17g)\n", p.X(), p.Y(), p.Z());
      }
      for (int v = 1; v <= L.NbVertex(); v++)
      {
        const Contap_Point& P = L.Vertex(v);
        double              u, w;
        P.Parameters(u, w);
        printf("    vertex %d (%.17g, %.17g, %.17g) uv=(%.17g, %.17g) onArc=%d", v, P.Value().X(), P.Value().Y(),
               P.Value().Z(), u, w, P.IsOnArc());
        if (P.IsOnArc())
          printf(" parameterOnArc=%.17g", P.ParameterOnArc());
        printf("\n");
      }
    }
    return;
  }
  printf("%s: no face has a first line of that type\n", label);
}

int main()
{
  TopoDS_Shape cyl = BRepPrimAPI_MakeCylinder(5, 20).Shape();
  firstFaceWith("cylinder r5 h20 along +X, first .line", cyl, gp_Vec(1, 0, 0), Contap_Lin);
  TopoDS_Shape sph = BRepPrimAPI_MakeSphere(7).Shape();
  firstFaceWith("sphere r7 along +Z, first .circle", sph, gp_Vec(0, 0, 1), Contap_Circle);
  TopoDS_Shape tor = BRepPrimAPI_MakeTorus(10, 3).Shape();
  firstFaceWith("torus R10 r3 along +X, first .walking", tor, gp_Vec(1, 0, 0), Contap_Walking);
  // Shape.box(width: 10, height: 10, depth: 10) is centred on the origin.
  TopoDS_Shape box = BRepPrimAPI_MakeBox(gp_Pnt(-5, -5, -5), 10, 10, 10).Shape();
  firstFaceWith("box 10 centred along +X, first .restriction", box, gp_Vec(1, 0, 0), Contap_Restriction);
  return 0;
}
