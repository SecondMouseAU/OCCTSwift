// Epic #766, ConvertElementarySurfacesTests.swift, CurveOnSurfaceCheckTests.swift,
// EvolvedSurfaceTests.swift and ExtendedRevolutionTests.swift: kernel parity for the ten tests.
//  - Convert_Cylinder/Cone/TorusToBSplineSurface on the same gp_ elementary surfaces, rebuilt into
//    a Geom_BSplineSurface as buildSurfaceFromElementary does, then evaluated.
//  - BRepLib_CheckCurveOnSurface over every (face, edge) with a pcurve, keeping the largest
//    MaxDistance, as OCCTShapeCheckCurveOnSurface does, on the centred box / sphere / cylinder and
//    on BRepAlgoAPI_Fuse(centred 10-box, r = 7 sphere).
//  - BRepOffsetAPI_MakeEvolved(quarter arc r = 20, centred 2x2 rectangle), OCCTShapeCreateEvolved.
//  - BRepPrimAPI_MakeRevol of the centred 2x5 rectangle face moved to x = 10, about Z, full and pi.
// And for FaceFromSurfaceTests.swift, FindSurfaceExTests.swift and FindSurfaceTests.swift (seven
// tests): BRepBuilderAPI_MakeFace(surface, u1, u2, v1, v2, 1e-6) areas (OCCTShapeCreateFaceFromSurface)
// and BRepLib_FindSurface on the centred rectangle wires / face (occtRunFindSurface).
#include <BRepAlgoAPI_Fuse.hxx>
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepBuilderAPI_MakePolygon.hxx>
#include <BRepBuilderAPI_MakeWire.hxx>
#include <BRepBuilderAPI_Transform.hxx>
#include <BRepCheck_Analyzer.hxx>
#include <BRepGProp.hxx>
#include <BRepLib_CheckCurveOnSurface.hxx>
#include <BRepLib_FindSurface.hxx>
#include <Geom_CylindricalSurface.hxx>
#include <Geom_Plane.hxx>
#include <Geom_SphericalSurface.hxx>
#include <gp_Pln.hxx>
#include <BRepOffsetAPI_MakeEvolved.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <BRepPrimAPI_MakeRevol.hxx>
#include <BRepPrimAPI_MakeSphere.hxx>
#include <BRep_Tool.hxx>
#include <Convert_ConeToBSplineSurface.hxx>
#include <Convert_CylinderToBSplineSurface.hxx>
#include <Convert_TorusToBSplineSurface.hxx>
#include <GProp_GProps.hxx>
#include <Geom_BSplineSurface.hxx>
#include <Geom_Circle.hxx>
#include <Geom_TrimmedCurve.hxx>
#include <Standard_Failure.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Edge.hxx>
#include <TopoDS_Face.hxx>
#include <TopoDS_Wire.hxx>
#include <cstdio>
#include <gp_Cone.hxx>
#include <gp_Cylinder.hxx>
#include <gp_Torus.hxx>

static Handle(Geom_BSplineSurface) build(const Convert_ElementarySurfaceToBSplineSurface& c)
{
  return new Geom_BSplineSurface(c.Poles(), c.Weights(), c.UKnots(), c.VKnots(), c.UMultiplicities(), c.VMultiplicities(),
                                 c.UDegree(), c.VDegree(), c.IsUPeriodic(), c.IsVPeriodic());
}

static void surf(const char* name, const Handle(Geom_BSplineSurface)& s)
{
  double u1, u2, v1, v2;
  s->Bounds(u1, u2, v1, v2);
  gp_Pnt p = s->Value(u1 + 0.3 * (u2 - u1), v1 + 0.6 * (v2 - v1));
  printf("%s: %dx%d poles bounds=[%.17g, %.17g]x[%.17g, %.17g] S(0.3, 0.6 of domain)=(%.17g, %.17g, %.17g)\n", name,
         s->NbUPoles(), s->NbVPoles(), u1, u2, v1, v2, p.X(), p.Y(), p.Z());
}

static void check(const char* name, const TopoDS_Shape& sh)
{
  double worst = 0;
  int    n     = 0;
  for (TopExp_Explorer f(sh, TopAbs_FACE); f.More(); f.Next())
    for (TopExp_Explorer e(f.Current(), TopAbs_EDGE); e.More(); e.Next())
    {
      double first, last;
      if (BRep_Tool::CurveOnSurface(TopoDS::Edge(e.Current()), TopoDS::Face(f.Current()), first, last).IsNull())
        continue;
      BRepLib_CheckCurveOnSurface c(TopoDS::Edge(e.Current()), TopoDS::Face(f.Current()));
      c.Perform();
      if (c.IsDone())
      {
        n++;
        if (c.MaxDistance() > worst)
          worst = c.MaxDistance();
      }
    }
  printf("%s: pairs checked=%d maxDistance=%.17g\n", name, n, worst);
}

static void props(const char* name, const TopoDS_Shape& s)
{
  GProp_GProps v, a;
  BRepGProp::VolumeProperties(s, v);
  BRepGProp::SurfaceProperties(s, a);
  printf("%s: type=%d valid=%d volume=%.17g area=%.17g\n", name, (int)s.ShapeType(), BRepCheck_Analyzer(s).IsValid(), v.Mass(),
         a.Mass());
}

int main()
{
  gp_Ax3 ax(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1));
  surf("cylinderPatch", build(Convert_CylinderToBSplineSurface(gp_Cylinder(ax, 5), 0, M_PI, 0, 10)));
  surf("conePatch", build(Convert_ConeToBSplineSurface(gp_Cone(ax, M_PI / 6, 5), 0, M_PI, 0, 10)));
  surf("fullTorus", build(Convert_TorusToBSplineSurface(gp_Torus(ax, 20, 5))));

  check("boxConsistency", BRepPrimAPI_MakeBox(gp_Pnt(-5, -10, -15), 10, 20, 30).Shape());
  check("sphereConsistency", BRepPrimAPI_MakeSphere(10).Shape());
  check("cylinderConsistency", BRepPrimAPI_MakeCylinder(5, 10).Shape());
  check("fusedConsistency", BRepAlgoAPI_Fuse(BRepPrimAPI_MakeBox(gp_Pnt(-5, -5, -5), 10, 10, 10).Shape(),
                                             BRepPrimAPI_MakeSphere(7).Shape())
                              .Shape());

  try
  {
    Handle(Geom_TrimmedCurve) arc =
      new Geom_TrimmedCurve(new Geom_Circle(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 20), 0, M_PI / 2);
    TopoDS_Wire spine = BRepBuilderAPI_MakeWire(BRepBuilderAPI_MakeEdge(arc).Edge()).Wire();
    TopoDS_Wire prof  = BRepBuilderAPI_MakePolygon(gp_Pnt(-1, -1, 0), gp_Pnt(1, -1, 0), gp_Pnt(1, 1, 0), gp_Pnt(-1, 1, 0), true).Wire();
    BRepOffsetAPI_MakeEvolved ev(spine, prof);
    printf("simpleEvolved: IsDone=%d\n", ev.IsDone());
    if (ev.IsDone())
      props("simpleEvolved", ev.Shape());
  }
  catch (Standard_Failure& e)
  {
    printf("simpleEvolved: threw %s\n", e.GetMessageString());
  }

  try
  {
    // A spine BRepOffsetAPI_MakeEvolved can use: the closed centred 20 x 20 square, with a
    // profile in the XZ plane (its local frame), a 2-long segment rising at 45 degrees.
    TopoDS_Wire sq  = BRepBuilderAPI_MakePolygon(gp_Pnt(-10, -10, 0), gp_Pnt(10, -10, 0), gp_Pnt(10, 10, 0), gp_Pnt(-10, 10, 0), true).Wire();
    TopoDS_Wire seg = BRepBuilderAPI_MakePolygon(gp_Pnt(0, 0, 0), gp_Pnt(2, 0, 2)).Wire();
    BRepOffsetAPI_MakeEvolved ev(sq, seg);
    printf("evolved square/segment: IsDone=%d\n", ev.IsDone());
    if (ev.IsDone())
      props("evolved square/segment", ev.Shape());
  }
  catch (Standard_Failure& e)
  {
    printf("evolved square/segment: threw %s\n", e.GetMessageString());
  }

  TopoDS_Wire r = BRepBuilderAPI_MakePolygon(gp_Pnt(-1, -2.5, 0), gp_Pnt(1, -2.5, 0), gp_Pnt(1, 2.5, 0), gp_Pnt(-1, 2.5, 0), true).Wire();
  gp_Trsf     t;
  t.SetTranslation(gp_Vec(10, 0, 0));
  TopoDS_Shape face = BRepBuilderAPI_Transform(BRepBuilderAPI_MakeFace(r, true).Face(), t, true).Shape();
  gp_Ax1       z(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1));
  props("revolveFaceFull", BRepPrimAPI_MakeRevol(face, z).Shape());
  props("revolveFacePartial", BRepPrimAPI_MakeRevol(face, z, M_PI).Shape());
  // The same 2 x 5 rectangle standing in the XZ plane at x = 9..11, so the axis lies in its
  // plane: a proper solid of revolution, volume 2 pi * 10 * (2 * 5) when full.
  TopoDS_Face xz = BRepBuilderAPI_MakeFace(
                     BRepBuilderAPI_MakePolygon(gp_Pnt(9, 0, -2.5), gp_Pnt(11, 0, -2.5), gp_Pnt(11, 0, 2.5), gp_Pnt(9, 0, 2.5), true).Wire(),
                     true)
                     .Face();
  props("revolveFaceFull (XZ profile)", BRepPrimAPI_MakeRevol(xz, z).Shape());
  props("revolveFacePartial (XZ profile)", BRepPrimAPI_MakeRevol(xz, z, M_PI).Shape());
  {
    Handle(Geom_Surface) pl  = new Geom_Plane(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1));
    Handle(Geom_Surface) cy  = new Geom_CylindricalSurface(ax, 5);
    Handle(Geom_Surface) sp  = new Geom_SphericalSurface(ax, 3);
    auto                 are = [](const Handle(Geom_Surface)& g, double a, double b, double c, double d) {
      GProp_GProps p;
      BRepGProp::SurfaceProperties(BRepBuilderAPI_MakeFace(g, a, b, c, d, 1e-6).Face(), p);
      return p.Mass();
    };
    printf("faceFromPlane: area=%.17g\n", are(pl, -5, 5, -5, 5));
    printf("faceFromCylinder: area=%.17g (pi r h = %.17g)\n", are(cy, 0, M_PI, 0, 10), M_PI * 50);
    printf("surfaceToFace: area=%.17g (4 pi r^2 = %.17g)\n", are(sp, 0, 2 * M_PI, -M_PI / 2, M_PI / 2), 4 * M_PI * 9);
    printf("surfaceToFaceTrimmed: area=%.17g (2 pi r^2 = %.17g)\n", are(sp, 0, 2 * M_PI, 0, M_PI / 2), 2 * M_PI * 9);
  }
  {
    TopoDS_Wire         sq = BRepBuilderAPI_MakePolygon(gp_Pnt(-5, -5, 0), gp_Pnt(5, -5, 0), gp_Pnt(5, 5, 0), gp_Pnt(-5, 5, 0), true).Wire();
    BRepLib_FindSurface a(sq, -1, false), b(sq, -1, true);
    TopoDS_Wire         rc = BRepBuilderAPI_MakePolygon(gp_Pnt(-5, -2.5, 0), gp_Pnt(5, -2.5, 0), gp_Pnt(5, 2.5, 0), gp_Pnt(-5, 2.5, 0), true).Wire();
    BRepLib_FindSurface c(BRepBuilderAPI_MakeFace(rc, true).Face(), -1, false);
    auto                pln = [](BRepLib_FindSurface& f) {
      Handle(Geom_Plane) p = Handle(Geom_Plane)::DownCast(f.Surface());
      if (p.IsNull())
        return printf(" not a plane");
      return printf(" plane z=%g normal=(%g,%g,%g)", p->Pln().Location().Z(), p->Pln().Axis().Direction().X(),
                    p->Pln().Axis().Direction().Y(), p->Pln().Axis().Direction().Z());
    };
    printf("wireOnPlane: Found=%d", a.Found());
    pln(a);
    printf("\nplaneOnlyMode: Found=%d", b.Found());
    pln(b);
    printf("\nfindPlaneFromWire: Found=%d", c.Found());
    pln(c);
    printf("\n");
  }
  return 0;
}
