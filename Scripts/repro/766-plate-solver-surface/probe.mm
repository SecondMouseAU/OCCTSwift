// Epic #766, PlateConstraintExtTests.swift, PlateGlobalTranslationTests.swift,
// PlateLinearXYZTests.swift, PlateSolverTests.swift and PlateSurfaceTests.swift: kernel parity for
// the fifteen tests. Plate_Plate with the same constraints the OCCTPlate* bridge functions load,
// SolveTI(4, 1.0) as PlateSolver.solve() defaults to, then Evaluate / EvaluateDerivative / UVBox /
// Continuity; and the GeomPlate_BuildPlateSurface(3, 15, 2) -> GeomPlate_MakeApprox(tol, 20, 8,
// tol * 0.1, 0, C1) -> MakeFace chain of OCCTShapePlatePoints / OCCTShapePlateCurves.
#include <BRepAdaptor_Curve.hxx>
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepBuilderAPI_MakeVertex.hxx>
#include <BRepBuilderAPI_MakeWire.hxx>
#include <BRepCheck_Analyzer.hxx>
#include <BRepExtrema_DistShapeShape.hxx>
#include <BRepGProp.hxx>
#include <GProp_GProps.hxx>
#include <GeomPlate_BuildPlateSurface.hxx>
#include <GeomPlate_CurveConstraint.hxx>
#include <GeomPlate_MakeApprox.hxx>
#include <GeomPlate_PointConstraint.hxx>
#include <GeomPlate_Surface.hxx>
#include <Geom_BSplineSurface.hxx>
#include <Message_ProgressRange.hxx>
#include <NCollection_Array1.hxx>
#include <Plate_D1.hxx>
#include <Plate_GlobalTranslationConstraint.hxx>
#include <Plate_GtoCConstraint.hxx>
#include <Plate_LineConstraint.hxx>
#include <Plate_LinearXYZConstraint.hxx>
#include <Plate_PinpointConstraint.hxx>
#include <Plate_Plate.hxx>
#include <Plate_PlaneConstraint.hxx>
#include <Standard_Failure.hxx>
#include <TColStd_Array1OfReal.hxx>
#include <TColgp_SequenceOfXY.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Edge.hxx>
#include <algorithm>
#include <cstdio>
#include <gp_Lin.hxx>
#include <gp_Pln.hxx>

static void pin(Plate_Plate& p, double u, double v, double x, double y, double z)
{
  p.Load(Plate_PinpointConstraint(gp_XY(u, v), gp_XYZ(x, y, z), 0, 0));
}

static void corners(Plate_Plate& p, bool four = true)
{
  pin(p, 0, 0, 0, 0, 0);
  pin(p, 1, 0, 1, 0, 0);
  pin(p, 0, 1, 0, 1, 0);
  if (four)
    pin(p, 1, 1, 1, 1, 0);
}

static void ev(const char* tag, Plate_Plate& p, double u, double v)
{
  gp_XYZ r = p.Evaluate(gp_XY(u, v));
  printf(" %s F(%g,%g)=(%.17g, %.17g, %.17g)", tag, u, v, r.X(), r.Y(), r.Z());
}

static void evd(const char* tag, Plate_Plate& p, double u, double v, int iu, int iv)
{
  gp_XYZ r = p.EvaluateDerivative(gp_XY(u, v), iu, iv);
  printf(" %s D%d%d(%g,%g)=(%.17g, %.17g, %.17g)", tag, iu, iv, u, v, r.X(), r.Y(), r.Z());
}

static void plateFace(const char* name, GeomPlate_BuildPlateSurface& b, double tol)
{
  try
  {
    b.Perform();
    if (!b.IsDone())
    {
      printf("%s: Perform not done\n", name);
      return;
    }
    GeomPlate_MakeApprox        ap(b.Surface(), tol, 20, 8, tol * 0.1, 0, GeomAbs_C1);
    Handle(Geom_BSplineSurface) bs = ap.Surface();
    TopoDS_Face                 f  = BRepBuilderAPI_MakeFace(bs, tol).Face();
    GProp_GProps                g;
    BRepGProp::SurfaceProperties(f, g);
    printf("%s: face valid=%d area=%.17g", name, BRepCheck_Analyzer(f).IsValid(), g.Mass());
    BRepExtrema_DistShapeShape d(BRepBuilderAPI_MakeVertex(gp_Pnt(5, 5, 1)).Vertex(), f);
    printf(" dist((5,5,1))=%.3g", d.Value());
    double worst = 0;
    for (gp_Pnt c : {gp_Pnt(0, 0, 0), gp_Pnt(10, 0, 0), gp_Pnt(10, 10, 0), gp_Pnt(0, 10, 0)})
    {
      BRepExtrema_DistShapeShape dc(BRepBuilderAPI_MakeVertex(c).Vertex(), f);
      worst = std::max(worst, dc.Value());
    }
    printf(" max corner dist=%.3g\n", worst);
  }
  catch (Standard_Failure& e)
  {
    printf("%s: threw %s\n", name, e.GetMessageString());
  }
}

int main()
{
  {
    Plate_Plate p;
    corners(p, false);
    Plate_PlaneConstraint pc(gp_XY(0.5, 0.5), gp_Pln(gp_Pnt(0, 0, 1), gp_Dir(0, 0, 1)));
    p.Load(pc.LSC());
    p.SolveTI(4, 1.0, Message_ProgressRange());
    printf("planeConstraint (plane z = 1): IsDone=%d", p.IsDone());
    ev("", p, 0.5, 0.5);
    printf("\n");
  }
  {
    Plate_Plate p;
    pin(p, 0, 0, 0, 0, 0);
    pin(p, 1, 0, 1, 0, 0);
    Plate_LineConstraint lc(gp_XY(0.5, 0.5), gp_Lin(gp_Pnt(0, 0, 1), gp_Dir(1, 0, 0)));
    p.Load(lc.LSC());
    p.SolveTI(4, 1.0, Message_ProgressRange());
    printf("lineConstraint (line z = 1 along X): IsDone=%d", p.IsDone());
    ev("", p, 0.5, 0.5);
    printf("\n");
  }
  {
    Plate_Plate         p;
    TColgp_SequenceOfXY uvs;
    uvs.Append(gp_XY(0, 0));
    uvs.Append(gp_XY(1, 0));
    uvs.Append(gp_XY(0, 1));
    Plate_GlobalTranslationConstraint gt(uvs);
    p.Load(gt.LXYZC());
    pin(p, 0, 0, 0, 0, 1);
    p.SolveTI(4, 1.0, Message_ProgressRange());
    printf("loadGlobalTranslation (+ pin (0,0) -> (0,0,1)): IsDone=%d", p.IsDone());
    ev("", p, 1, 0);
    ev("", p, 0, 1);
    printf("\n");
  }
  {
    Plate_Plate p;
    pin(p, 0, 0, 0, 0, 1);
    pin(p, 1, 0, 0, 0, 1);
    pin(p, 0, 1, 0, 0, 1);
    p.SolveTI(4, 1.0, Message_ProgressRange());
    printf("solveWithGlobalTranslation: IsDone=%d", p.IsDone());
    ev("", p, 0.5, 0.5);
    printf("\n");
  }
  {
    Plate_Plate                                  p;
    NCollection_Array1<Plate_PinpointConstraint> ppc(1, 2);
    ppc.SetValue(1, Plate_PinpointConstraint(gp_XY(0, 0), gp_XYZ(0, 0, 1)));
    ppc.SetValue(2, Plate_PinpointConstraint(gp_XY(1, 0), gp_XYZ(0, 0, 1)));
    TColStd_Array1OfReal c(1, 2);
    c(1) = 1;
    c(2) = -1;
    p.Load(Plate_LinearXYZConstraint(ppc, c));
    pin(p, 0, 0, 0, 0, 3);
    p.SolveTI(4, 1.0, Message_ProgressRange());
    printf("loadLinearXYZ (+ pin (0,0) -> (0,0,3)): IsDone=%d", p.IsDone());
    ev("", p, 0, 0);
    ev("", p, 1, 0);
    printf("\n");
  }
  {
    Plate_Plate p;
    corners(p);
    pin(p, 0.5, 0.5, 0.5, 0.5, 1.0);
    p.SolveTI(4, 1.0, Message_ProgressRange());
    printf("basicSolve: IsDone=%d", p.IsDone());
    ev("", p, 0.5, 0.5);
    ev("", p, 0, 0);
    printf("\n");
  }
  {
    Plate_Plate p;
    corners(p);
    p.SolveTI(4, 1.0, Message_ProgressRange());
    double a, b, c, d;
    p.UVBox(a, b, c, d);
    printf("uvBoxAndContinuity: IsDone=%d UVBox=[%.17g, %.17g]x[%.17g, %.17g] Continuity=%d\n", p.IsDone(), a, b, c, d, (int)p.Continuity());
  }
  {
    Plate_Plate p;
    corners(p);
    p.Load(Plate_PinpointConstraint(gp_XY(0.5, 0.5), gp_XYZ(0, 0, 2), 1, 0));
    p.SolveTI(4, 1.0, Message_ProgressRange());
    printf("derivativeConstraint: IsDone=%d", p.IsDone());
    evd("", p, 0.5, 0.5, 1, 0);
    printf("\n");
  }
  {
    Plate_Plate p;
    corners(p, false);
    pin(p, 0.5, 0.5, 0.5, 0.5, 1.0);
    p.SolveTI(4, 1.0, Message_ProgressRange());
    printf("evaluateDerivative: IsDone=%d", p.IsDone());
    evd("", p, 0.5, 0.5, 1, 0);
    printf("\n");
  }
  {
    Plate_Plate p;
    corners(p);
    Plate_D1 s(gp_XYZ(1, 0, 0), gp_XYZ(0, 1, 0)), t(gp_XYZ(1, 0, 0.1), gp_XYZ(0, 1, 0.1));
    p.Load(Plate_GtoCConstraint(gp_XY(0.5, 0.5), s, t));
    p.SolveTI(4, 1.0, Message_ProgressRange());
    printf("gtoCConstraint: IsDone=%d", p.IsDone());
    evd("", p, 0.5, 0.5, 1, 0);
    evd("", p, 0.5, 0.5, 0, 1);
    printf("\n");
  }

  {
    GeomPlate_BuildPlateSurface b(3, 15, 2);
    double pts[9][3] = {{0, 0, 0}, {5, 0, 0.5}, {10, 0, 0}, {0, 5, 0.5}, {5, 5, 1}, {10, 5, 0.5}, {0, 10, 0}, {5, 10, 0.5}, {10, 10, 0}};
    for (auto& q : pts)
      b.Add(new GeomPlate_PointConstraint(gp_Pnt(q[0], q[1], q[2]), 0));
    plateFace("plateThroughGridPoints", b, 1.0);
  }
  {
    GeomPlate_BuildPlateSurface b(3, 15, 2);
    double pts[4][3] = {{0, 0, 0}, {10, 0, 0}, {10, 10, 0}, {0, 10, 0}};
    for (auto& q : pts)
      b.Add(new GeomPlate_PointConstraint(gp_Pnt(q[0], q[1], q[2]), 0));
    plateFace("plateWithCornerPoints", b, 1.0);
  }
  {
    GeomPlate_BuildPlateSurface b(3, 15, 2);
    for (int k = 0; k < 2; k++)
    {
      TopoDS_Edge e = BRepBuilderAPI_MakeEdge(gp_Pnt(0, 10 * k, 0), gp_Pnt(10, 10 * k, 0)).Edge();
      b.Add(new GeomPlate_CurveConstraint(new BRepAdaptor_Curve(e), 0));
    }
    plateFace("plateFromCurvesAPI", b, 1.0);
  }
  try
  {
    GeomPlate_BuildPlateSurface b(3, 15, 2);
    b.Add(new GeomPlate_PointConstraint(gp_Pnt(0, 0, 0), 0));
    b.Add(new GeomPlate_PointConstraint(gp_Pnt(10, 0, 0), 0));
    b.Perform();
    printf("plateTooFewPoints (unrefused, 2 points): IsDone=%d\n", b.IsDone());
    b.Surface();
  }
  catch (Standard_Failure& e)
  {
    printf("plateTooFewPoints (unrefused, 2 points): threw %s\n", e.GetMessageString());
  }
  return 0;
}
