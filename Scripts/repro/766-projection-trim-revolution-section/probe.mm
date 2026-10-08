// Epic #766, ProjectCurveOnSurfaceTests.swift, ProjectionOnSurfaceTests.swift,
// RectangularTrimmedSurfaceTests.swift, RevolutionFeatureTests.swift, RevolutionFormTests.swift,
// RevolutionFromCurveTests.swift, SectionPlaneTests.swift, ShapeRevolutionAxesTests.swift and
// ShellFromSurfaceTests.swift: kernel parity. Same inputs, straight to the OCCT call each bridge
// function makes (named per block below). Shape.box is centred on the origin.
#include <BRepAdaptor_Surface.hxx>
#include <BRepAlgoAPI_Fuse.hxx>
#include <BRepAlgoAPI_Section.hxx>
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepBuilderAPI_MakePolygon.hxx>
#include <BRepBuilderAPI_MakeShell.hxx>
#include <BRepBuilderAPI_MakeWire.hxx>
#include <BRepCheck_Analyzer.hxx>
#include <BRepFeat_MakeRevol.hxx>
#include <BRepFeat_MakeRevolutionForm.hxx>
#include <BRepGProp.hxx>
#include <BRepLib_FindSurface.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <BRepPrimAPI_MakeRevolution.hxx>
#include <BRepPrimAPI_MakeTorus.hxx>
#include <GC_MakeSegment.hxx>
#include <GProp_GProps.hxx>
#include <GeomAPI_ProjectPointOnSurf.hxx>
#include <Geom2d_Curve.hxx>
#include <Geom_Circle.hxx>
#include <Geom_CylindricalSurface.hxx>
#include <Geom_Line.hxx>
#include <Geom_Plane.hxx>
#include <Geom_RectangularTrimmedSurface.hxx>
#include <Geom_SphericalSurface.hxx>
#include <Geom_TrimmedCurve.hxx>
#include <ShapeConstruct_ProjectCurveOnSurface.hxx>
#include <Standard_Failure.hxx>
#include <TopExp.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Face.hxx>
#include <TopoDS_Shell.hxx>
#include <TopoDS_Wire.hxx>
#include <cstdio>

static void props(const char* name, const TopoDS_Shape& s)
{
  GProp_GProps v, a;
  BRepGProp::VolumeProperties(s, v);
  BRepGProp::SurfaceProperties(s, a);
  TopTools_IndexedMapOfShape e;
  TopExp::MapShapes(s, TopAbs_EDGE, e);
  printf("%s: type=%d valid=%d volume=%.17g area=%.17g edges=%d\n", name, (int)s.ShapeType(), BRepCheck_Analyzer(s).IsValid(), v.Mass(),
         a.Mass(), e.Extent());
}

static TopoDS_Wire rect(double w, double h)
{
  return BRepBuilderAPI_MakePolygon(gp_Pnt(-w / 2, -h / 2, 0), gp_Pnt(w / 2, -h / 2, 0), gp_Pnt(w / 2, h / 2, 0), gp_Pnt(-w / 2, h / 2, 0), true)
    .Wire();
}

int main()
{
  // OCCTProjectCurveOnSurface: ShapeConstruct_ProjectCurveOnSurface, Init(surface, 1e-6), Perform.
  {
    Handle(Geom_TrimmedCurve) line = new Geom_TrimmedCurve(new Geom_Line(gp_Pnt(1, 2, 0), gp_Dir(1, 0, 0)), 0, 10);
    Handle(ShapeConstruct_ProjectCurveOnSurface) pr = new ShapeConstruct_ProjectCurveOnSurface();
    pr->Init(new Geom_Plane(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 1e-6);
    Handle(Geom2d_Curve) c2;
    bool                 ok = pr->Perform(line, 0, 10, c2);
    printf("projectLineOnPlane: ok=%d", ok);
    if (!c2.IsNull())
    {
      gp_Pnt2d a = c2->Value(c2->FirstParameter()), b = c2->Value(c2->LastParameter());
      printf(" domain=[%g, %g] start=(%.17g, %.17g) end=(%.17g, %.17g)", c2->FirstParameter(), c2->LastParameter(), a.X(), a.Y(), b.X(), b.Y());
      gp_Pnt2d p0 = c2->Value(0), p10 = c2->Value(10);
      printf(" value(0)=(%.17g, %.17g) value(10)=(%.17g, %.17g)", p0.X(), p0.Y(), p10.X(), p10.Y());
    }
    printf("\n");
  }
  // OCCTProjOnSurfCreate: GeomAPI_ProjectPointOnSurf::Init(point, surface).
  {
    GeomAPI_ProjectPointOnSurf p;
    p.Init(gp_Pnt(10, 0, 0), new Geom_SphericalSurface(gp_Ax3(gp_Pnt(0, 0, 0), gp::DZ()), 5));
    printf("multiResultProjection: NbPoints=%d", p.NbPoints());
    for (int i = 1; i <= p.NbPoints(); i++)
    {
      double u, v;
      p.Parameters(i, u, v);
      gp_Pnt q = p.Point(i);
      printf(" [%d] point=(%.17g, %.17g, %.17g) uv=(%.17g, %.17g) dist=%.17g", i, q.X(), q.Y(), q.Z(), u, v, p.Distance(i));
    }
    double lu, lv;
    p.LowerDistanceParameters(lu, lv);
    printf(" lower=%.17g at (%.17g, %.17g)\n", p.LowerDistance(), lu, lv);
  }
  // OCCTSurfaceCreateRectangularTrimmed / TrimmedInU / TrimmedInV.
  {
    Handle(Geom_Plane) pl = new Geom_Plane(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1));
    double             a, b, c, d;
    Handle(Geom_RectangularTrimmedSurface) t1 = new Geom_RectangularTrimmedSurface(pl, -5.0, 5.0, -3.0, 3.0);
    t1->Bounds(a, b, c, d);
    printf("trimPlane: bounds=[%g, %g]x[%g, %g]\n", a, b, c, d);
    Handle(Geom_RectangularTrimmedSurface) t2 = new Geom_RectangularTrimmedSurface(pl, -2.0, 2.0, true);
    t2->Bounds(a, b, c, d);
    printf("trimInU: bounds=[%g, %g]x[%g, %g]\n", a, b, c, d);
    Handle(Geom_RectangularTrimmedSurface) t3 = new Geom_RectangularTrimmedSurface(pl, -3.0, 3.0, false);
    t3->Bounds(a, b, c, d);
    printf("trimInV: bounds=[%g, %g]x[%g, %g]\n", a, b, c, d);
  }
  // OCCTShapeRevolFeature / ThruAll: BRepFeat_MakeRevol(box, face(rect 50x100), face 1, axis, fuse = 1, true).
  for (int thru = 0; thru < 2; thru++)
  {
    try
    {
      TopoDS_Shape               box = BRepPrimAPI_MakeBox(gp_Pnt(-100, -100, -100), 200, 200, 200).Shape();
      TopTools_IndexedMapOfShape faces;
      TopExp::MapShapes(box, TopAbs_FACE, faces);
      TopoDS_Face        pbase = BRepBuilderAPI_MakeFace(rect(50, 100), true).Face();
      BRepFeat_MakeRevol m(box, pbase, TopoDS::Face(faces(1)), gp_Ax1(gp_Pnt(0, 0, 200), gp_Dir(0, 1, 0)), 1, true);
      if (thru)
        m.PerformThruAll();
      else
        m.Perform(90 * M_PI / 180.0);
      printf("%s: IsDone=%d ", thru ? "revolvedThruAll" : "revolvedBoss", m.IsDone());
      if (m.IsDone())
        props("", m.Shape());
      else
        printf("\n");
    }
    catch (Standard_Failure& e)
    {
      printf("%s: threw %s\n", thru ? "revolvedThruAll" : "revolvedBoss", e.GetMessageString());
    }
  }
  // The same features with a profile that lies on the box's top face (z = 100, face 6) and an
  // axis along Y at x = 50, z = 100, so the revolution actually adds material.
  for (int thru = 0; thru < 2; thru++)
  {
    try
    {
      TopoDS_Shape               box = BRepPrimAPI_MakeBox(gp_Pnt(-100, -100, -100), 200, 200, 200).Shape();
      TopTools_IndexedMapOfShape faces;
      TopExp::MapShapes(box, TopAbs_FACE, faces);
      TopoDS_Wire top = BRepBuilderAPI_MakePolygon(gp_Pnt(-25, -50, 100), gp_Pnt(25, -50, 100), gp_Pnt(25, 50, 100), gp_Pnt(-25, 50, 100), true).Wire();
      TopoDS_Face        pbase = BRepBuilderAPI_MakeFace(top, true).Face();
      BRepFeat_MakeRevol m(box, pbase, TopoDS::Face(faces(6)), gp_Ax1(gp_Pnt(50, 0, 100), gp_Dir(0, 1, 0)), 1, true);
      if (thru)
        m.PerformThruAll();
      else
        m.Perform(90 * M_PI / 180.0);
      printf("%s (top-face profile): IsDone=%d ", thru ? "revolvedThruAll" : "revolvedBoss", m.IsDone());
      if (m.IsDone())
        props("", m.Shape());
      else
        printf("\n");
    }
    catch (Standard_Failure& e)
    {
      printf("%s (top-face profile): threw %s\n", thru ? "revolvedThruAll" : "revolvedBoss", e.GetMessageString());
    }
  }
  // OCCTShapeAddRevolutionForm: BRepFeat_MakeRevolutionForm on Fuse(cyl r2 h5, cyl r1 z5..8).
  try
  {
    TopoDS_Shape c1 = BRepPrimAPI_MakeCylinder(2, 5).Shape();
    TopoDS_Shape c2 = BRepPrimAPI_MakeCylinder(gp_Ax2(gp_Pnt(0, 0, 5), gp_Dir(0, 0, 1)), 1, 3).Shape();
    TopoDS_Shape s  = BRepAlgoAPI_Fuse(c1, c2).Shape();
    props("revolutionForm base", s);
    TopoDS_Wire         w = BRepBuilderAPI_MakeWire(BRepBuilderAPI_MakeEdge(gp_Pnt(-2, 0, 5), gp_Pnt(-1, 0, 8)).Edge()).Wire();
    BRepLib_FindSurface f(w);
    printf("addRevolutionForm: FindSurface found=%d plane=%d", f.Found(), f.Found() && !Handle(Geom_Plane)::DownCast(f.Surface()).IsNull());
    if (f.Found() && !Handle(Geom_Plane)::DownCast(f.Surface()).IsNull())
    {
      bool                        sliding = true;
      BRepFeat_MakeRevolutionForm m(s, w, Handle(Geom_Plane)::DownCast(f.Surface()), gp_Ax1(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 0.2, 0.2, 1, sliding);
      m.Perform();
      printf(" IsDone=%d ", m.IsDone());
      if (m.IsDone())
        props("", m.Shape());
      else
        printf("\n");
    }
    else
      printf("\n");
  }
  catch (Standard_Failure& e)
  {
    printf("addRevolutionForm: threw %s\n", e.GetMessageString());
  }
  // OCCTShapeCreateRevolutionFromCurve: BRepPrimAPI_MakeRevolution(gp_Ax2(origin, Z), meridian, angle).
  {
    gp_Ax2                     ax(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1));
    Handle(Geom_TrimmedCurve)  seg = GC_MakeSegment(gp_Pnt(5, 0, 0), gp_Pnt(5, 0, 10)).Value();
    props("revolveSegment", BRepPrimAPI_MakeRevolution(ax, seg, 2 * M_PI).Shape());
    Handle(Geom_Circle) circ = new Geom_Circle(gp_Ax2(gp_Pnt(10, 0, 0), gp_Dir(0, 1, 0)), 3);
    props("revolveCircle", BRepPrimAPI_MakeRevolution(ax, circ, 2 * M_PI).Shape());
    props("partialRevolution", BRepPrimAPI_MakeRevolution(ax, seg, M_PI / 2).Shape());
  }
  // OCCTShapeSectionWithPlane / WithSurface: BRepAlgoAPI_Section.
  {
    TopoDS_Shape box = BRepPrimAPI_MakeBox(gp_Pnt(-5, -5, -5), 10, 10, 10).Shape();
    BRepAlgoAPI_Section s1(box, gp_Pln(gp_Pnt(0, 0, 5), gp_Dir(0, 0, 1)));
    s1.Build();
    props("sectionWithPlane z = 5", s1.Shape());
    BRepAlgoAPI_Section s0(box, gp_Pln(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)));
    s0.Build();
    props("  (for comparison, z = 0)", s0.Shape());
    BRepAlgoAPI_Section s2(box, new Geom_CylindricalSurface(gp_Ax3(gp_Pnt(5, 5, 0), gp_Dir(0, 0, 1)), 3.0));
    s2.Build();
    props("sectionWithSurface", s2.Shape());
  }
  // Revolution axes: BRepAdaptor_Surface of each face, for the cylinder and torus kinds.
  {
    TopoDS_Shape               cyl = BRepPrimAPI_MakeCylinder(5, 10).Shape();
    TopTools_IndexedMapOfShape f;
    TopExp::MapShapes(cyl, TopAbs_FACE, f);
    for (int i = 1; i <= f.Extent(); i++)
    {
      BRepAdaptor_Surface a(TopoDS::Face(f(i)));
      if (a.GetType() == GeomAbs_Cylinder)
      {
        gp_Ax1 ax = a.Cylinder().Axis();
        printf("cylinderOneAxis: face %d cylinder axis loc=(%g,%g,%g) dir=(%g,%g,%g)\n", i, ax.Location().X(), ax.Location().Y(),
               ax.Location().Z(), ax.Direction().X(), ax.Direction().Y(), ax.Direction().Z());
      }
    }
    TopoDS_Shape tor = BRepPrimAPI_MakeTorus(20, 5).Shape();
    TopExp::MapShapes(tor, TopAbs_FACE, f);
    printf("torus: faces=%d", f.Extent());
    TopTools_IndexedMapOfShape tf;
    TopExp::MapShapes(tor, TopAbs_FACE, tf);
    for (int i = 1; i <= tf.Extent(); i++)
      printf(" face %d type=%d", i, (int)BRepAdaptor_Surface(TopoDS::Face(tf(i))).GetType());
    printf("\n");
  }
  // OCCTShapeCreateShellFromSurface / OCCTShapeMakeShell: BRepBuilderAPI_MakeShell(surface, u1, u2, v1, v2).
  {
    BRepBuilderAPI_MakeShell m1(new Geom_CylindricalSurface(gp_Ax3(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 5), 0, 2 * M_PI, 0, 10);
    props("shellFromCylinder", m1.Shell());
    BRepBuilderAPI_MakeShell m2(new Geom_Plane(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), -5, 5, -5, 5);
    props("shellFromPlane", m2.Shell());
  }
  return 0;
}
