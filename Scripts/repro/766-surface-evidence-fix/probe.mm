// Epic #766 evidence correction, Surface domain. Kernel-side measurements for the nine parity records
// whose bridge and kernel outputs did not carry the same quantity. Each block calls the same OCCT API
// with the same inputs as the bridge function the Swift test reaches; the AUDIT-style lines of the
// Swift side were read with a temporary print in each test (never committed).
//
//  1 NLPlate order (#1017)           : NLPlate_NLPlate::Evaluate at uv (0, 0), Solve2(order, 1), orders 2 and 8
//                                      (the plate itself; the bridge returns a 20x20 refit of it).
//  3 plate through points (#571)     : the two entry points, OCCTShapePlatePoints (BuildPlateSurface(3, 15, 2))
//                                      and OCCTGeomPlateSurface (BuildPlateSurface(3, 10, 5)), same
//                                      GeomPlate_MakeApprox arguments (tol 0.01, Nbmax 20, degree 8, C1,
//                                      dmax = tol * 0.1), face by BRepBuilderAPI_MakeFace, area by
//                                      BRepGProp::SurfaceProperties.
//  4 curve-constrained plate (#571)  : OCCTShapePlateCurves on the warped octagon, then the distance from
//                                      each corner to the face as OCCTFaceProjectPoint measures it
//                                      (GeomAPI_ProjectPointOnSurf over BRepTools::UVBounds).
//  5 drawMesh one row (#620)         : the OCCTSurfaceDrawMesh sweep, row 0 of a 1 x 12 and a 6 x 12 grid.
//  6 sphere BSpline (#791)           : Convert_SphereToBSplineSurface rebuilt as a Geom_BSplineSurface the way
//                                      buildSurfaceFromElementary does, sampled 9 x 9, worst |distance - radius|.
//  7 grid layout (#486)              : the 5 x 3 grid of a radius-5 sphere by D0 (drawMesh) and by
//                                      GeomGridEval_Surface::EvaluateGridD1 (evaluateGridD1).
//  8 NLPlate incremental (G2G3 file) : IncrementalSolve(2, 1, 4, false) on the z = 0 plane with the
//                                      (0.5, 0.5) -> (0.5, 0.5, 1) constraint, Evaluate at (0.5, 0.5), and the
//                                      bridge's own refit (occtNLPlateFitSolved) of that plate.
//  9 approximation (#491)            : GeomConvert_ApproxSurface IsDone / HasResult / Surface non-null for the
//                                      twelve requests of Issue491SurfaceApproxParityTests.
#include <BRepAdaptor_Curve.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepBuilderAPI_MakePolygon.hxx>
#include <BRepGProp.hxx>
#include <BRepTools.hxx>
#include <BRep_Tool.hxx>
#include <Convert_SphereToBSplineSurface.hxx>
#include <GC_MakeTrimmedCone.hxx>
#include <GC_MakeTrimmedCylinder.hxx>
#include <GProp_GProps.hxx>
#include <GeomAPI_ProjectPointOnSurf.hxx>
#include <GeomAPI_PointsToBSplineSurface.hxx>
#include <GeomConvert_ApproxSurface.hxx>
#include <GeomGridEval_Surface.hxx>
#include <GeomPlate_BuildPlateSurface.hxx>
#include <GeomPlate_CurveConstraint.hxx>
#include <GeomPlate_MakeApprox.hxx>
#include <GeomPlate_PointConstraint.hxx>
#include <GeomPlate_Surface.hxx>
#include <Geom_BSplineSurface.hxx>
#include <Geom_OffsetSurface.hxx>
#include <Geom_Plane.hxx>
#include <Geom_RectangularTrimmedSurface.hxx>
#include <Geom_SphericalSurface.hxx>
#include <Geom_ToroidalSurface.hxx>
#include <NLPlate_HPG0Constraint.hxx>
#include <NLPlate_NLPlate.hxx>
#include <Precision.hxx>
#include <TColStd_Array1OfInteger.hxx>
#include <TColStd_Array1OfReal.hxx>
#include <TColStd_Array2OfReal.hxx>
#include <TColgp_Array2OfPnt.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Face.hxx>
#include <TopoDS_Wire.hxx>
#include <cmath>
#include <cstdio>
#include <gp_Sphere.hxx>
#include <vector>

// ---------------------------------------------------------------------------------------------------
// #1017 and the incremental solve share the bridge's working domain and refit.
static Handle(Geom_BSplineSurface) refit(const NLPlate_NLPlate& solver, double u1, double u2, double v1, double v2,
                                         double tolerance)
{
  // occtNLPlateFitSolved: 20 x 20 samples of the solved plate, GeomAPI_PointsToBSplineSurface(3, 8, C2, tol),
  // then occtNLPlateReparametrise maps the knots linearly onto the working domain.
  const int          nuPts = 20, nvPts = 20;
  TColgp_Array2OfPnt poles(1, nuPts, 1, nvPts);
  for (int iu = 1; iu <= nuPts; iu++)
  {
    const double pu = u1 + (u2 - u1) * (iu - 1) / (nuPts - 1);
    for (int iv = 1; iv <= nvPts; iv++)
    {
      const double pv  = v1 + (v2 - v1) * (iv - 1) / (nvPts - 1);
      const gp_XYZ val = solver.Evaluate(gp_XY(pu, pv));
      poles(iu, iv)    = gp_Pnt(val.X(), val.Y(), val.Z());
    }
  }
  GeomAPI_PointsToBSplineSurface approx;
  approx.Init(poles, 3, 8, GeomAbs_C2, tolerance);
  Handle(Geom_BSplineSurface) result = approx.Surface();
  Standard_Real               fu1, fu2, fv1, fv2;
  result->Bounds(fu1, fu2, fv1, fv2);
  {
    const double                      scale = (u2 - u1) / (fu2 - fu1);
    const NCollection_Array1<double>& src   = result->UKnots();
    NCollection_Array1<double>        knots(src.Lower(), src.Upper());
    for (int i = src.Lower(); i <= src.Upper(); i++)
      knots(i) = u1 + (src(i) - fu1) * scale;
    result->SetUKnots(knots);
  }
  {
    const double                      scale = (v2 - v1) / (fv2 - fv1);
    const NCollection_Array1<double>& src   = result->VKnots();
    NCollection_Array1<double>        knots(src.Lower(), src.Upper());
    for (int i = src.Lower(); i <= src.Upper(); i++)
      knots(i) = v1 + (src(i) - fv1) * scale;
    result->SetVKnots(knots);
  }
  return result;
}

static Handle(Geom_BSplineSurface) plateApprox(const Handle(GeomPlate_Surface)& plate, double tol)
{
  // occtPlateApproxSurface with the shared defaults: maxDegree 8, maxSegments 20, C1, dmax = tol * 0.1.
  GeomPlate_MakeApprox approx(plate, tol, 20, 8, tol * 0.1, 0, GeomAbs_C1);
  return approx.Surface();
}

static double faceArea(const TopoDS_Face& f)
{
  GProp_GProps props;
  BRepGProp::SurfaceProperties(f, props);
  return props.Mass();
}

int main()
{
  // ------------------------------------------------------------------------------------------------ 1
  {
    // Working domain of the bridge for the z = 0 plane and constraints at (-5,-5), (5,5), (0,0): the span of the
    // constraint parameters padded outward by max(10, 0.5 * span) = 10 -> [-15, 15] x [-15, 15].
    for (int order : {2, 8})
    {
      Handle(Geom_Plane)                     plane = new Geom_Plane(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1));
      Handle(Geom_RectangularTrimmedSurface) trim  = new Geom_RectangularTrimmedSurface(plane, -15.0, 15.0, -15.0, 15.0);
      NLPlate_NLPlate                        s(trim);
      s.Load(new NLPlate_HPG0Constraint(gp_XY(-5, -5), gp_XYZ(-5, -5, 1)));
      s.Load(new NLPlate_HPG0Constraint(gp_XY(5, 5), gp_XYZ(5, 5, 2)));
      s.Load(new NLPlate_HPG0Constraint(gp_XY(0, 0), gp_XYZ(0, 0, 5)));
      s.Solve2(order, 1);
      gp_XYZ                      e = s.Evaluate(gp_XY(0, 0));
      Handle(Geom_BSplineSurface) f = refit(s, -15, 15, -15, 15, 0.1);
      gp_Pnt                      p = f->Value(0, 0);
      printf("1017 order=%d IsDone=%d Evaluate(0,0).z=%.17g refit(0,0).z=%.17g\n", order, s.IsDone(), e.Z(), p.Z());
    }
  }

  // Wavy point set of Issue571PlateApproxTests.
  std::vector<gp_Pnt> wavy;
  for (int i = 0; i < 5; i++)
    for (int j = 0; j < 5; j++)
      wavy.push_back(gp_Pnt(i * 4.0, j * 4.0, 4.0 * std::sin(i * 1.3) * std::cos(j * 1.1)));

  // ------------------------------------------------------------------------------------------------ 3
  {
    double areas[2];
    int    nbPts[2]   = {15, 10};
    int    nbIters[2] = {2, 5};
    for (int k = 0; k < 2; k++)
    {
      GeomPlate_BuildPlateSurface b(3, nbPts[k], nbIters[k]);
      for (const gp_Pnt& p : wavy)
        b.Add(new GeomPlate_PointConstraint(p, 0));
      b.Perform();
      Handle(Geom_BSplineSurface) bs = plateApprox(b.Surface(), 0.01);
      BRepBuilderAPI_MakeFace     mk(bs, 0.01);
      areas[k] = faceArea(mk.Face());
    }
    printf("571a through=%.17g named=%.17g\n", areas[0], areas[1]);
  }

  // ------------------------------------------------------------------------------------------------ 4
  {
    std::vector<gp_Pnt> corners;
    for (int i = 0; i < 8; i++)
    {
      double angle = i * M_PI / 4;
      corners.push_back(gp_Pnt(8 * std::cos(angle), 8 * std::sin(angle), 3 * std::sin(i * 2.1)));
    }
    BRepBuilderAPI_MakePolygon poly;
    for (const gp_Pnt& p : corners)
      poly.Add(p);
    poly.Close();
    TopoDS_Wire wire = poly.Wire();

    GeomPlate_BuildPlateSurface b(3, 15, 2);
    for (TopExp_Explorer ex(wire, TopAbs_EDGE); ex.More(); ex.Next())
    {
      BRepAdaptor_Curve       adaptor(TopoDS::Edge(ex.Current()));
      Handle(Adaptor3d_Curve) curve = new BRepAdaptor_Curve(adaptor);
      b.Add(new GeomPlate_CurveConstraint(curve, 0));
    }
    b.Perform();
    Handle(Geom_BSplineSurface) bs = plateApprox(b.Surface(), 0.01);
    BRepBuilderAPI_MakeFace     mk(bs, 0.01);
    TopoDS_Face                 face = mk.Face();
    printf("571b area=%.17g\n", faceArea(face));
    Handle(Geom_Surface) surf = BRep_Tool::Surface(face);
    double               uMin, uMax, vMin, vMax;
    BRepTools::UVBounds(face, uMin, uMax, vMin, vMax);
    for (size_t k = 0; k < corners.size(); k++)
    {
      GeomAPI_ProjectPointOnSurf proj(corners[k], surf, uMin, uMax, vMin, vMax, Precision::Confusion());
      printf("571b corner=%zu dist=%.17g\n", k, proj.NbPoints() > 0 ? proj.LowerDistance() : -1.0);
    }
  }

  // ------------------------------------------------------------------------------------------------ 5
  {
    Handle(Geom_SphericalSurface) s = new Geom_SphericalSurface(gp_Ax3(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 10);
    double                        u1, u2, v1, v2;
    s->Bounds(u1, u2, v1, v2);
    auto param = [](double lo, double hi, int i, int n) { return lo + (hi - lo) * i / (n > 1 ? (n - 1) : 1); };
    for (int j = 0; j < 12; j++)
    {
      gp_Pnt one, many;
      s->D0(param(u1, u2, 0, 1), param(v1, v2, j, 12), one);   // uCount 1: row 0 is the low end
      s->D0(param(u1, u2, 0, 6), param(v1, v2, j, 12), many);  // uCount 6: row 0 is the low end too
      printf("620 j=%d one=%.17g,%.17g,%.17g many=%.17g,%.17g,%.17g\n", j, one.X(), one.Y(), one.Z(), many.X(), many.Y(),
             many.Z());
    }
  }

  // ------------------------------------------------------------------------------------------------ 6
  {
    struct Cfg
    {
      gp_Pnt o;
      double ax, ay, az;  // the axis as the test spells it, before gp_Dir normalises it
      double r;
    } cfgs[3] = {{gp_Pnt(0, 0, 0), 0, 0, 1, 5}, {gp_Pnt(3, -2, 7), 1, 1, 1, 2.5}, {gp_Pnt(-4, 10, -1), 0, 1, 0, 9.75}};
    for (auto& c0 : cfgs)
    {
      struct
      {
        gp_Pnt o;
        gp_Dir d;
        double r;
      } c = {c0.o, gp_Dir(c0.ax, c0.ay, c0.az), c0.r};
      Convert_SphereToBSplineSurface cv(gp_Sphere(gp_Ax3(c.o, c.d), c.r));
      int nup = cv.NbUPoles(), nvp = cv.NbVPoles(), nuk = cv.NbUKnots(), nvk = cv.NbVKnots();
      TColgp_Array2OfPnt      poles(1, nup, 1, nvp);
      TColStd_Array2OfReal    weights(1, nup, 1, nvp);
      for (int i = 1; i <= nup; i++)
        for (int j = 1; j <= nvp; j++)
        {
          poles(i, j)   = cv.Poles().Value(i, j);
          weights(i, j) = cv.Weights().Value(i, j);
        }
      TColStd_Array1OfReal    uk(1, nuk), vk(1, nvk);
      TColStd_Array1OfInteger um(1, nuk), vm(1, nvk);
      for (int i = 1; i <= nuk; i++)
      {
        uk(i) = cv.UKnots().Value(i);
        um(i) = cv.UMultiplicities().Value(i);
      }
      for (int i = 1; i <= nvk; i++)
      {
        vk(i) = cv.VKnots().Value(i);
        vm(i) = cv.VMultiplicities().Value(i);
      }
      Handle(Geom_BSplineSurface) bss =
        new Geom_BSplineSurface(poles, weights, uk, vk, um, vm, cv.UDegree(), cv.VDegree(), cv.IsUPeriodic(), cv.IsVPeriodic());
      double u1, u2, v1, v2;
      bss->Bounds(u1, u2, v1, v2);
      double maxDev = 0;
      for (int i = 0; i <= 8; i++)
        for (int j = 0; j <= 8; j++)
        {
          gp_Pnt p = bss->Value(u1 + (u2 - u1) * i / 8, v1 + (v2 - v1) * j / 8);
          maxDev   = std::max(maxDev, std::fabs(p.Distance(c.o) - c.r));
        }
      printf("791 origin=%g,%g,%g axis=%g,%g,%g radius=%g maxdev=%.17g\n", c.o.X(), c.o.Y(), c.o.Z(), c0.ax, c0.ay, c0.az,
             c.r, maxDev);
    }
  }

  // ------------------------------------------------------------------------------------------------ 7
  {
    Handle(Geom_SphericalSurface) s = new Geom_SphericalSurface(gp_Ax3(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 5);
    double                        u1, u2, v1, v2;
    s->Bounds(u1, u2, v1, v2);
    const int uCount = 5, vCount = 3;
    NCollection_Array1<double> uArr(1, uCount), vArr(1, vCount);
    for (int i = 0; i < uCount; i++)
      uArr(i + 1) = u1 + (u2 - u1) * i / (uCount - 1);
    for (int j = 0; j < vCount; j++)
      vArr(j + 1) = v1 + (v2 - v1) * j / (vCount - 1);
    GeomGridEval_Surface                              ev(s);
    NCollection_Array2<GeomGridEval::SurfD1>          grid = ev.EvaluateGridD1(uArr, vArr);
    for (int i = 0; i < uCount; i++)
      for (int j = 0; j < vCount; j++)
      {
        gp_Pnt d0;
        s->D0(uArr(i + 1), vArr(j + 1), d0);
        const gp_Pnt& g = grid.Value(i + 1, j + 1).Point;
        printf("486 iu=%d iv=%d u=%.17g v=%.17g mesh=%.17g,%.17g,%.17g d1=%.17g,%.17g,%.17g\n", i, j, uArr(i + 1), vArr(j + 1),
               d0.X(), d0.Y(), d0.Z(), g.X(), g.Y(), g.Z());
      }
  }

  // ------------------------------------------------------------------------------------------------ 8
  {
    Handle(Geom_Plane)                     plane = new Geom_Plane(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1));
    // Working domain: infinite plane, one constraint at (0.5, 0.5): pad = max(10, 0) = 10 -> [-9.5, 10.5]^2.
    Handle(Geom_RectangularTrimmedSurface) trim = new Geom_RectangularTrimmedSurface(plane, -9.5, 10.5, -9.5, 10.5);
    NLPlate_NLPlate                        s(trim);
    s.Load(new NLPlate_HPG0Constraint(gp_XY(0.5, 0.5), gp_XYZ(0.5, 0.5, 1.0)));
    s.IncrementalSolve(2, 1, 4, false);
    gp_XYZ                      e = s.Evaluate(gp_XY(0.5, 0.5));
    Handle(Geom_BSplineSurface) f = refit(s, -9.5, 10.5, -9.5, 10.5, 1e-3);
    gp_Pnt                      p = f->Value(0.5, 0.5);
    printf("nlplate IsDone=%d Evaluate=%.17g,%.17g,%.17g refit=%.17g,%.17g,%.17g\n", s.IsDone(), e.X(), e.Y(), e.Z(), p.X(),
           p.Y(), p.Z());
  }

  // ------------------------------------------------------------------------------------------------ 9
  {
    gp_Ax3                        ax(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1));
    Handle(Geom_SphericalSurface) sphere = new Geom_SphericalSurface(ax, 10);
    Handle(Geom_OffsetSurface)    offset = new Geom_OffsetSurface(sphere, 1.5);
    Handle(Geom_ToroidalSurface)  torus  = new Geom_ToroidalSurface(ax, 20, 5);
    Handle(Geom_Surface)          cyl    = GC_MakeTrimmedCylinder(gp_Ax1(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 5, 20).Value();
    Handle(Geom_Surface)          cone   = GC_MakeTrimmedCone(gp_Pnt(0, 0, 0), gp_Pnt(0, 0, 12), 5, 2).Value();
    struct Req
    {
      const char*          label;
      Handle(Geom_Surface) s;
      double               tol;
      GeomAbs_Shape        c;
      int                  seg;
      int                  deg;
    };
    std::vector<Req> reqs = {
      {"sphere r=10, shared defaults", sphere, 1e-3, GeomAbs_C2, 100, 8},
      {"sphere r=10, tol 1e-5", sphere, 1e-5, GeomAbs_C2, 100, 8},
      {"sphere r=10, tol 1e-9", sphere, 1e-9, GeomAbs_C2, 100, 8},
      {"sphere r=10, C0", sphere, 1e-3, GeomAbs_C0, 100, 8},
      {"sphere r=10, C1", sphere, 1e-3, GeomAbs_C1, 100, 8},
      {"offset sphere +1.5, tol 1e-5", offset, 1e-5, GeomAbs_C2, 100, 8},
      {"offset sphere +1.5, shared defaults", offset, 1e-3, GeomAbs_C2, 100, 8},
      {"torus 20/5, shared defaults", torus, 1e-3, GeomAbs_C2, 100, 8},
      {"torus 20/5, tol 1e-9", torus, 1e-9, GeomAbs_C2, 100, 8},
      {"trimmed cylinder r=5", cyl, 1e-3, GeomAbs_C2, 100, 8},
      {"trimmed cone", cone, 1e-3, GeomAbs_C2, 100, 8},
      {"trimmed cone, degree 4 in 20 segments", cone, 1e-3, GeomAbs_C2, 20, 4},
    };
    for (const Req& r : reqs)
    {
      GeomConvert_ApproxSurface a(r.s, r.tol, r.c, r.c, r.deg, r.deg, r.seg, 0);
      bool                      hasSurface = a.HasResult() && !a.Surface().IsNull();
      printf("491 label=%s isDone=%d hasResult=%d surface=%d\n", r.label, a.IsDone() ? 1 : 0, a.HasResult() ? 1 : 0,
             hasSurface ? 1 : 0);
    }
  }
  return 0;
}
