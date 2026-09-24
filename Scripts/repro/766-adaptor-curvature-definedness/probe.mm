// #766 kernel parity for Tests/OCCTAnalysisTests/AdaptorCurvatureDefinednessTests.swift.
// Reads BRepLProp_SLProps(face, u, v, 2, Precision::Confusion()) on the suite's fixtures, the
// construction occtFaceLocalProps makes for every OCCTFaceLProp* getter.
#include <BRepAdaptor_Surface.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepLProp_SLProps.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <BRepPrimAPI_MakeSphere.hxx>
#include <GC_MakePlane.hxx>
#include <Geom_ConicalSurface.hxx>
#include <Geom_Plane.hxx>
#include <Precision.hxx>
#include <Standard_Failure.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <cmath>
#include <cstdio>

static void report(const char* label, const TopoDS_Face& f, double u, double v)
{
  BRepAdaptor_Surface as(f);
  BRepLProp_SLProps   p(as, u, v, 2, Precision::Confusion());
  gp_Pnt              pt = p.Value();
  printf("%s u=%g v=%g value=(%.17g, %.17g, %.17g) curvDefined=%d", label, u, v, pt.X(), pt.Y(),
         pt.Z(), (int)p.IsCurvatureDefined());
  if (p.IsCurvatureDefined())
    printf(" kMax=%.17g kMin=%.17g mean=%.17g gauss=%.17g umbilic=%d", p.MaxCurvature(),
           p.MinCurvature(), p.MeanCurvature(), p.GaussianCurvature(), (int)p.IsUmbilic());
  printf("\n");
}

int main()
{
  // Test 1: Shape.cylinder(radius: 3, height: 12), every face at (1.1, 6)
  TopoDS_Shape cyl = BRepPrimAPI_MakeCylinder(3, 12).Shape();
  int          i   = 0;
  for (TopExp_Explorer e(cyl, TopAbs_FACE); e.More(); e.Next(), ++i)
  {
    char label[64];
    snprintf(label, sizeof label, "cylinder face %d", i);
    report(label, TopoDS::Face(e.Current()), 1.1, 6);
  }

  // Test 2: plane through the origin, normal +Z, face [-10,10]^2, at (0, 0)
  occ::handle<Geom_Plane> pl = GC_MakePlane(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)).Value();
  report("plane", BRepBuilderAPI_MakeFace(pl, -10, 10, -10, 10, 1e-6).Face(), 0, 0);

  // Test 3: apex cone face (radius 0, semi-angle pi/6), apex at v = 0; sphere r=5 poles
  occ::handle<Geom_ConicalSurface> cone =
    new Geom_ConicalSurface(gp_Ax3(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), M_PI / 6, 0);
  report("cone apex", BRepBuilderAPI_MakeFace(cone, 0, 2 * M_PI, -1, 10, 1e-6).Face(), 0, 0);
  TopoDS_Shape sph = BRepPrimAPI_MakeSphere(5).Shape();
  for (TopExp_Explorer e(sph, TopAbs_FACE); e.More(); e.Next())
  {
    report("sphere north pole", TopoDS::Face(e.Current()), 0, M_PI / 2);
    report("sphere south pole", TopoDS::Face(e.Current()), 0, -M_PI / 2);
  }

  // Test 4: TopoDS::Face on a solid and on an edge throws, which the bridge turns into false
  TopoDS_Shape box = BRepPrimAPI_MakeBox(gp_Pnt(-5, -5, -5), 10, 10, 10).Shape();
  TopoDS_Shape edge;
  for (TopExp_Explorer e(box, TopAbs_EDGE); e.More(); e.Next())
  {
    edge = e.Current();
    break;
  }
  const TopoDS_Shape* shapes[2] = {&box, &edge};
  for (const TopoDS_Shape* s : shapes)
  {
    try
    {
      TopoDS_Face f = TopoDS::Face(*s);
      (void)f;
      printf("TopoDS::Face on shape type %d: no throw\n", (int)s->ShapeType());
    }
    catch (const Standard_Failure& ex)
    {
      printf("TopoDS::Face on shape type %d throws %s\n", (int)s->ShapeType(),
             ex.ExceptionType());
    }
  }
  return 0;
}
