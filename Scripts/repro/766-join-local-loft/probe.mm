// Epic #766, JoinBezierPatchesTests.swift, LocalAnalysisSurfaceContinuityTests.swift,
// LocalRevolutionTests.swift, LocOpePipeTests.swift, LocOpeRevolutionFormTests.swift and
// LoftRuledTests.swift: kernel parity for the fourteen tests.
//  - GeomConvert_CompBezierSurfacesToBSplineSurface on the two degree-1 patches (2 rows x 1 col).
//  - LocalAnalysis_SurfaceContinuity at (0,0)/(0,0) on plane/plane and plane/cylinder.
//  - LocOpe_Revol / LocOpe_RevolutionForm on the centred box (Shape.box is a solid), LocOpe_Pipe of
//    the centred 2x2 square face along the 10-long X line.
//  - BRepOffsetAPI_ThruSections(solid, ruled) with CheckCompatibility(true) on two centred squares,
//    10 and 5 wide, both at z = 0 (OCCTShapeCreateLoftAdvanced).
// Those are the inputs the tests used to have, and each gives an empty or degenerate result. The
// second half runs the same operations on the inputs the rewritten tests now use.
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepBuilderAPI_MakePolygon.hxx>
#include <BRepBuilderAPI_MakeWire.hxx>
#include <BRepCheck_Analyzer.hxx>
#include <BRepBndLib.hxx>
#include <BRepGProp.hxx>
#include <Bnd_Box.hxx>
#include <BRepOffsetAPI_ThruSections.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <GProp_GProps.hxx>
#include <GeomConvert_CompBezierSurfacesToBSplineSurface.hxx>
#include <Geom_BSplineSurface.hxx>
#include <Geom_BezierSurface.hxx>
#include <Geom_CylindricalSurface.hxx>
#include <Geom_Plane.hxx>
#include <LocOpe_Pipe.hxx>
#include <LocOpe_Revol.hxx>
#include <LocOpe_RevolutionForm.hxx>
#include <LocalAnalysis_SurfaceContinuity.hxx>
#include <NCollection_Array2.hxx>
#include <Standard_Failure.hxx>
#include <TColGeom_Array2OfBezierSurface.hxx>
#include <TopExp.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Face.hxx>
#include <TopoDS_Wire.hxx>
#include <cstdio>

static void props(const char* name, const TopoDS_Shape& s)
{
  if (s.IsNull())
  {
    printf("%s: null shape\n", name);
    return;
  }
  GProp_GProps v, a;
  BRepGProp::VolumeProperties(s, v);
  BRepGProp::SurfaceProperties(s, a);
  TopTools_IndexedMapOfShape f;
  TopExp::MapShapes(s, TopAbs_FACE, f);
  printf("%s: type=%d valid=%d faces=%d volume=%.17g area=%.17g\n", name, (int)s.ShapeType(), BRepCheck_Analyzer(s).IsValid(),
         f.Extent(), v.Mass(), a.Mass());
}

static Handle(Geom_BezierSurface) bez(gp_Pnt a, gp_Pnt b, gp_Pnt c, gp_Pnt d)
{
  NCollection_Array2<gp_Pnt> p(1, 2, 1, 2);
  p(1, 1) = a;
  p(1, 2) = b;
  p(2, 1) = c;
  p(2, 2) = d;
  return new Geom_BezierSurface(p);
}

static TopoDS_Wire square(double w, double z = 0)
{
  double h = w / 2;
  return BRepBuilderAPI_MakePolygon(gp_Pnt(-h, -h, z), gp_Pnt(h, -h, z), gp_Pnt(h, h, z), gp_Pnt(-h, h, z), true).Wire();
}

int main()
{
  {
    TColGeom_Array2OfBezierSurface arr(1, 2, 1, 1);
    arr(1, 1) = bez(gp_Pnt(0, 0, 0), gp_Pnt(0, 10, 0), gp_Pnt(5, 0, 0), gp_Pnt(5, 10, 0));
    arr(2, 1) = bez(gp_Pnt(5, 0, 0), gp_Pnt(5, 10, 0), gp_Pnt(10, 0, 0), gp_Pnt(10, 10, 0));
    GeomConvert_CompBezierSurfacesToBSplineSurface conv(arr);
    printf("joinPatches: IsDone=%d", conv.IsDone());
    if (conv.IsDone())
    {
      Handle(Geom_BSplineSurface) s = new Geom_BSplineSurface(conv.Poles()->Array2(), conv.UKnots()->Array1(), conv.VKnots()->Array1(),
                                                              conv.UMultiplicities()->Array1(), conv.VMultiplicities()->Array1(),
                                                              conv.UDegree(), conv.VDegree());
      double u1, u2, v1, v2;
      s->Bounds(u1, u2, v1, v2);
      gp_Pnt p = s->Value(u1 + 0.75 * (u2 - u1), v1 + 0.5 * (v2 - v1));
      printf(" poles %dx%d bounds=[%g, %g]x[%g, %g] S(75%%,50%%)=(%.17g, %.17g, %.17g)", s->NbUPoles(), s->NbVPoles(), u1, u2, v1, v2,
             p.X(), p.Y(), p.Z());
    }
    printf("\n");
  }
  {
    Handle(Geom_Surface) p1 = new Geom_Plane(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1));
    Handle(Geom_Surface) p2 = new Geom_Plane(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1));
    Handle(Geom_Surface) cy = new Geom_CylindricalSurface(gp_Ax3(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 5);
    LocalAnalysis_SurfaceContinuity a(p1, 0, 0, p2, 0, 0, GeomAbs_C1);
    printf("identicalPlanes C1: IsDone=%d Status=%d IsC0=%d C0Value=%.17g\n", a.IsDone(), (int)a.ContinuityStatus(), a.IsC0(), a.C0Value());
    LocalAnalysis_SurfaceContinuity g(p1, 0, 0, p2, 0, 0, GeomAbs_G1);
    printf("identicalPlanes G1: IsDone=%d IsG1=%d\n", g.IsDone(), g.IsG1());
    LocalAnalysis_SurfaceContinuity c(p1, 0, 0, cy, 0, 0, GeomAbs_C1);
    printf("planeVsCylinder C1: IsDone=%d Status=%d IsC0=%d C0Value=%.17g\n", c.IsDone(), (int)c.ContinuityStatus(), c.IsC0(), c.C0Value());
  }
  TopoDS_Shape box3 = BRepPrimAPI_MakeBox(gp_Pnt(-1.5, -1.5, -0.05), 3, 3, 0.1).Shape();
  TopoDS_Shape box2 = BRepPrimAPI_MakeBox(gp_Pnt(-1, -1, -0.05), 2, 2, 0.1).Shape();
  gp_Ax1       z(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1));
  try
  {
    LocOpe_Revol r;
    r.Perform(box3, z, M_PI / 2);
    props("revolveAroundZ (box 3x3x0.1, pi/2)", r.Shape());
  }
  catch (Standard_Failure& e)
  {
    printf("revolveAroundZ: threw %s\n", e.GetMessageString());
  }
  try
  {
    LocOpe_Revol r;
    r.Perform(box2, z, M_PI / 4);
    props("revolveProducesSolid (box 2x2x0.1, pi/4)", r.Shape());
  }
  catch (Standard_Failure& e)
  {
    printf("revolveProducesSolid: threw %s\n", e.GetMessageString());
  }
  try
  {
    LocOpe_Revol r;
    r.Perform(box2, z, M_PI / 2, M_PI / 4);
    props("revolveWithOffset (pi/2, offset pi/4)", r.Shape());
  }
  catch (Standard_Failure& e)
  {
    printf("revolveWithOffset: threw %s\n", e.GetMessageString());
  }
  try
  {
    LocOpe_Revol r;
    r.Perform(box2, z, 2 * M_PI);
    props("fullRevolution (2 pi)", r.Shape());
  }
  catch (Standard_Failure& e)
  {
    printf("fullRevolution: threw %s\n", e.GetMessageString());
  }
  try
  {
    TopoDS_Face  f     = BRepBuilderAPI_MakeFace(square(2), true).Face();
    TopoDS_Wire  spine = BRepBuilderAPI_MakeWire(BRepBuilderAPI_MakeEdge(gp_Pnt(0, 0, 0), gp_Pnt(10, 0, 0)).Edge()).Wire();
    LocOpe_Pipe  p(spine, f);
    props("pipeSweep (2x2 square face along X, 10)", p.Shape());
  }
  catch (Standard_Failure& e)
  {
    printf("pipeSweep: threw %s\n", e.GetMessageString());
  }
  try
  {
    LocOpe_RevolutionForm rf;
    rf.Perform(box3, z, M_PI / 2);
    props("revolutionForm (box 3x3x0.1, pi/2)", rf.Shape());
  }
  catch (Standard_Failure& e)
  {
    printf("revolutionForm: threw %s\n", e.GetMessageString());
  }
  for (int k = 0; k < 3; k++)
  {
    bool solid = k != 2, ruled = k != 1;
    try
    {
      BRepOffsetAPI_ThruSections ts(solid, ruled);
      ts.CheckCompatibility(true);
      ts.AddWire(square(10));
      ts.AddWire(square(5));
      ts.Build();
      printf("loft solid=%d ruled=%d: IsDone=%d\n", solid, ruled, ts.IsDone());
      if (ts.IsDone())
        props("  loft", ts.Shape());
    }
    catch (Standard_Failure& e)
    {
      printf("loft solid=%d ruled=%d: threw %s\n", solid, ruled, e.GetMessageString());
    }
  }

  // The same operations on inputs they are meant for: a 2 x 5 face standing in the XZ plane at
  // x = 9..11 (the Z axis in its plane), a 2 x 2 face in the YZ plane swept along X, and squares
  // at different heights.
  printf("--- well-posed inputs ---\n");
  TopoDS_Face xz = BRepBuilderAPI_MakeFace(
                     BRepBuilderAPI_MakePolygon(gp_Pnt(9, 0, -2.5), gp_Pnt(11, 0, -2.5), gp_Pnt(11, 0, 2.5), gp_Pnt(9, 0, 2.5), true).Wire(),
                     true)
                     .Face();
  double angles[4][2] = {{M_PI / 2, 0}, {M_PI / 4, 0}, {M_PI / 2, M_PI / 4}, {2 * M_PI, 0}};
  for (auto& a : angles)
  {
    LocOpe_Revol r;
    if (a[1] == 0)
      r.Perform(xz, z, a[0]);
    else
      r.Perform(xz, z, a[0], a[1]);
    char name[64];
    snprintf(name, sizeof name, "LocOpe_Revol XZ face angle=%g offset=%g", a[0], a[1]);
    props(name, r.Shape());
    Bnd_Box b;
    BRepBndLib::Add(r.Shape(), b);
    double x0, y0, z0, x1, y1, z1;
    b.Get(x0, y0, z0, x1, y1, z1);
    printf("  bbox y=[%.6g, %.6g] x=[%.6g, %.6g]\n", y0, y1, x0, x1);
  }
  {
    LocOpe_RevolutionForm rf;
    rf.Perform(xz, z, M_PI / 2);
    props("LocOpe_RevolutionForm XZ face pi/2", rf.Shape());
  }
  {
    TopoDS_Face yz = BRepBuilderAPI_MakeFace(
                       BRepBuilderAPI_MakePolygon(gp_Pnt(0, -1, -1), gp_Pnt(0, 1, -1), gp_Pnt(0, 1, 1), gp_Pnt(0, -1, 1), true).Wire(), true)
                       .Face();
    TopoDS_Wire spine = BRepBuilderAPI_MakeWire(BRepBuilderAPI_MakeEdge(gp_Pnt(0, 0, 0), gp_Pnt(10, 0, 0)).Edge()).Wire();
    LocOpe_Pipe p(spine, yz);
    props("LocOpe_Pipe YZ face along X", p.Shape());
  }
  for (int k = 0; k < 4; k++)
  {
    bool solid = k != 2, ruled = k != 1 && k != 3;
    BRepOffsetAPI_ThruSections ts(solid, ruled);
    ts.CheckCompatibility(true);
    ts.AddWire(square(10, 0));
    if (k == 3)
      ts.AddWire(square(5, 5));
    ts.AddWire(square(k == 3 ? 10 : 5, 10));
    if (k == 0 || k == 1)
    {
      ts.Build();
      printf("loft 10@0 -> 5@10 solid=%d ruled=%d IsDone=%d\n", solid, ruled, ts.IsDone());
    }
    else if (k == 2)
    {
      ts.Build();
      printf("loft 10@0 -> 5@10 shell ruled IsDone=%d\n", ts.IsDone());
    }
    else
    {
      ts.Build();
      printf("loft 10@0 -> 5@5 -> 10@10 smooth solid IsDone=%d\n", ts.IsDone());
    }
    if (ts.IsDone())
      props("  loft", ts.Shape());
  }
  {
    BRepOffsetAPI_ThruSections ts(true, true);
    ts.CheckCompatibility(true);
    ts.AddWire(square(10, 0));
    ts.AddWire(square(5, 5));
    ts.AddWire(square(10, 10));
    ts.Build();
    printf("loft 10@0 -> 5@5 -> 10@10 ruled solid IsDone=%d\n", ts.IsDone());
    if (ts.IsDone())
      props("  loft", ts.Shape());
  }
  return 0;
}
