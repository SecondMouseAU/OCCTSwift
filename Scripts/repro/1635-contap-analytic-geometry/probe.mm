// Probe for #1635: what geometry a Contap_Contour silhouette actually carries, per line type.
//
// Build (from the repo root):
//   clang++ -std=c++17 -ObjC++ -w \
//     -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
//     -L"Libraries/OCCT.xcframework/macos-arm64" \
//     -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
//     Scripts/repro/1635-contap-analytic-geometry/probe.mm -o /tmp/occt_probe_1635
//   /tmp/occt_probe_1635

#include <Adaptor2d_Curve2d.hxx>
#include <BRepAdaptor_Surface.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeCone.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <BRepPrimAPI_MakeSphere.hxx>
#include <BRepPrimAPI_MakeTorus.hxx>
#include <BRepTopAdaptor_TopolTool.hxx>
#include <Contap_Contour.hxx>
#include <Contap_Line.hxx>
#include <Contap_Point.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <gp_Circ.hxx>
#include <gp_Lin.hxx>
#include <gp_Pln.hxx>
#include <gp_Pnt2d.hxx>

#include <cmath>
#include <cstdio>

static const char* typeName(Contap_IType t)
{
  switch (t)
  {
    case Contap_Lin:
      return "Contap_Lin";
    case Contap_Circle:
      return "Contap_Circle";
    case Contap_Walking:
      return "Contap_Walking";
    case Contap_Restriction:
      return "Contap_Restriction";
  }
  return "?";
}

static void probeFace(const char* label, const TopoDS_Face& face, const gp_Vec& dir)
{
  printf("--- %s, direction (%g, %g, %g)\n", label, dir.X(), dir.Y(), dir.Z());
  Handle(BRepAdaptor_Surface)      surf = new BRepAdaptor_Surface(face);
  Handle(BRepTopAdaptor_TopolTool) tool = new BRepTopAdaptor_TopolTool(surf);
  Contap_Contour                   contour;
  contour.Init(dir);
  contour.Perform(surf, tool);
  if (!contour.IsDone() || contour.IsEmpty())
  {
    printf("    IsDone=%d IsEmpty=%d, no lines\n", (int)contour.IsDone(), (int)contour.IsEmpty());
    return;
  }
  printf("    NbLines=%d\n", contour.NbLines());
  for (int i = 1; i <= contour.NbLines(); ++i)
  {
    const Contap_Line& L = contour.Line(i);
    printf("    line %d  %-18s NbVertex=%d", i, typeName(L.TypeContour()), L.NbVertex());
    try
    {
      printf("  NbPnts=%d", L.NbPnts());
    }
    catch (const Standard_Failure&)
    {
      printf("  NbPnts THREW");
    }
    printf("\n");

    switch (L.TypeContour())
    {
      case Contap_Lin: {
        gp_Lin ln = L.Line();
        printf("        Line()   origin=(%.4f, %.4f, %.4f) dir=(%.4f, %.4f, %.4f)\n",
               ln.Location().X(), ln.Location().Y(), ln.Location().Z(),
               ln.Direction().X(), ln.Direction().Y(), ln.Direction().Z());
        break;
      }
      case Contap_Circle: {
        gp_Circ c = L.Circle();
        printf("        Circle() centre=(%.4f, %.4f, %.4f) axis=(%.4f, %.4f, %.4f) "
               "xdir=(%.4f, %.4f, %.4f) r=%.4f\n",
               c.Location().X(), c.Location().Y(), c.Location().Z(),
               c.Axis().Direction().X(), c.Axis().Direction().Y(), c.Axis().Direction().Z(),
               c.XAxis().Direction().X(), c.XAxis().Direction().Y(), c.XAxis().Direction().Z(),
               c.Radius());
        break;
      }
      case Contap_Restriction: {
        const Handle(Adaptor2d_Curve2d)& arc = L.Arc();
        if (arc.IsNull())
          printf("        Arc()    NULL handle\n");
        else
        {
          const double f = arc->FirstParameter();
          const double l = arc->LastParameter();
          printf("        Arc()    range [%.4f, %.4f]", f, l);
          try
          {
            const gp_Pnt2d m = arc->Value(0.5 * (f + l));
            printf("  Value(mid)=(%.4f, %.4f)", m.X(), m.Y());
          }
          catch (const Standard_Failure&)
          {
            printf("  Value(mid) THREW");
          }
          printf("\n");
        }
        break;
      }
      default:
        break;
    }

    for (int v = 1; v <= L.NbVertex(); ++v)
    {
      const Contap_Point& P = L.Vertex(v);
      double              u = 0, vv = 0;
      P.Parameters(u, vv);
      printf("        vertex %d  (%.4f, %.4f, %.4f) uv=(%.4f, %.4f) paramOnLine=%.4f "
             "onArc=%d isVertex=%d multiple=%d internal=%d\n",
             v, P.Value().X(), P.Value().Y(), P.Value().Z(), u, vv, P.ParameterOnLine(),
             (int)P.IsOnArc(), (int)P.IsVertex(), (int)P.IsMultiple(), (int)P.IsInternal());
      if (P.IsOnArc())
        printf("            ParameterOnArc=%.4f\n", P.ParameterOnArc());
    }
  }
}

static TopoDS_Face lateralFace(const TopoDS_Shape& solid, int wanted)
{
  int n = 0;
  for (TopExp_Explorer ex(solid, TopAbs_FACE); ex.More(); ex.Next())
  {
    if (n == wanted)
      return TopoDS::Face(ex.Current());
    ++n;
  }
  return TopoDS_Face();
}

int main()
{
  // A cylinder's lateral face: the textbook analytic silhouette, a pair of tangent rulings.
  TopoDS_Shape cyl = BRepPrimAPI_MakeCylinder(5.0, 20.0).Shape();
  probeFace("cylinder r=5 h=20, face 0", lateralFace(cyl, 0), gp_Vec(1, 0, 0));

  // A sphere, whose silhouette is a great circle.
  TopoDS_Shape sph = BRepPrimAPI_MakeSphere(7.0).Shape();
  probeFace("sphere r=7, face 0", lateralFace(sph, 0), gp_Vec(1, 0, 0));
  probeFace("sphere r=7, face 0", lateralFace(sph, 0), gp_Vec(0, 0, 1));

  // A cone.
  TopoDS_Shape cone = BRepPrimAPI_MakeCone(6.0, 2.0, 10.0).Shape();
  probeFace("cone r1=6 r2=2 h=10, face 0", lateralFace(cone, 0), gp_Vec(1, 0, 0));

  // A torus, whose silhouette is traced numerically.
  TopoDS_Shape tor = BRepPrimAPI_MakeTorus(10.0, 3.0).Shape();
  probeFace("torus R=10 r=3, face 0", lateralFace(tor, 0), gp_Vec(1, 0, 0));
  probeFace("torus R=10 r=3, face 0", lateralFace(tor, 0), gp_Vec(0, 0, 1));

  // A planar face viewed edge on: the whole face is on the silhouette, which is where a
  // Contap_Restriction line can come from.
  TopoDS_Shape box = BRepPrimAPI_MakeBox(10.0, 10.0, 10.0).Shape();
  for (int f = 0; f < 6; ++f)
  {
    char lbl[64];
    snprintf(lbl, sizeof(lbl), "box face %d", f);
    probeFace(lbl, lateralFace(box, f), gp_Vec(1, 0, 0));
  }

  // A planar face on its own, viewed edge on.
  TopoDS_Face pl = BRepBuilderAPI_MakeFace(gp_Pln(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)),
                                           -5.0, 5.0, -5.0, 5.0).Face();
  probeFace("planar face, viewed edge on", pl, gp_Vec(1, 0, 0));
  probeFace("planar face, viewed face on", pl, gp_Vec(0, 0, 1));

  // The cylinder viewed along its own axis: no silhouette rulings.
  probeFace("cylinder r=5 h=20, face 0", lateralFace(cyl, 0), gp_Vec(0, 0, 1));

  return 0;
}
