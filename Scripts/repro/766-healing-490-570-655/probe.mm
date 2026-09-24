// #766 kernel parity: Issue490ContinuityDecoderTests, Issue570HealingApproxTests,
// Issue655FreeBoundsInternalOrientationTests. ShapeCustom::BSplineRestriction and
// ShapeCustom_BSplineRestriction through BRepTools_Modifier (OCCTShapeCustomBSplineRestriction,
// OCCTShapeBSplineRestrictionAdvanced, OCCTShapeBSplineRestriction), ShapeUpgrade_SplitSurfaceContinuity
// (OCCTSurfaceSplitByContinuity / OCCTSplitSurfaceContinuity), ShapeCustom::ConvertToBSpline on an
// offset sphere (OCCTShapeConvertToBSpline), ShapeAnalysis_FreeBounds and FreeBoundsProperties on
// the #655 INTERNAL-loop fixture.
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <BRepBuilderAPI_MakePolygon.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepGProp.hxx>
#include <GProp_GProps.hxx>
#include <BRep_Builder.hxx>
#include <BRep_Tool.hxx>
#include <BRepTools_Modifier.hxx>
#include <Geom_BSplineSurface.hxx>
#include <Geom_SphericalSurface.hxx>
#include <Geom_OffsetSurface.hxx>
#include <ShapeCustom.hxx>
#include <ShapeCustom_BSplineRestriction.hxx>
#include <ShapeCustom_RestrictionParameters.hxx>
#include <ShapeUpgrade_SplitSurfaceContinuity.hxx>
#include <ShapeAnalysis_FreeBounds.hxx>
#include <ShapeAnalysis_FreeBoundsProperties.hxx>
#include <TColgp_Array2OfPnt.hxx>
#include <TColStd_Array1OfReal.hxx>
#include <TColStd_Array1OfInteger.hxx>
#include <TColStd_HSequenceOfReal.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <cstdio>
#include <cmath>

static double vol(const TopoDS_Shape& s)
{
  GProp_GProps g;
  BRepGProp::VolumeProperties(s, g);
  return g.Mass();
}

static int count(const TopoDS_Shape& s, TopAbs_ShapeEnum t)
{
  int n = 0;
  for (TopExp_Explorer e(s, t); e.More(); e.Next())
    n++;
  return n;
}

static double deviation(const TopoDS_Shape& r, const Handle(Geom_Surface)& src)
{
  TopExp_Explorer      e(r, TopAbs_FACE);
  Handle(Geom_Surface) fit = BRep_Tool::Surface(TopoDS::Face(e.Current()));
  double               u0, u1, v0, v1, worst = 0;
  src->Bounds(u0, u1, v0, v1);
  for (int i = 0; i <= 24; i++)
    for (int j = 0; j <= 24; j++)
    {
      double u = u0 + (u1 - u0) * i / 24, v = v0 + (v1 - v0) * j / 24;
      worst    = std::max(worst, src->Value(u, v).Distance(fit->Value(u, v)));
    }
  return worst;
}

int main()
{
  // #490 restriction entry points: cylinder r5 h10, tol 0.01, maxDegree 6, maxSegments 20, degree priority, rational
  TopoDS_Shape cyl = BRepPrimAPI_MakeCylinder(5, 10).Shape();
  GeomAbs_Shape cs[] = {GeomAbs_C0, GeomAbs_C1, GeomAbs_C2, GeomAbs_C3};
  const char*   cn[] = {"C0", "C1", "C2", "C3"};
  for (int k = 0; k < 4; k++)
  {
    Handle(ShapeCustom_RestrictionParameters) p = new ShapeCustom_RestrictionParameters();
    double                                    vp = -1, va = -1;
    try
    {
      TopoDS_Shape r = ShapeCustom::BSplineRestriction(cyl, 0.01, 0.01, 6, 20, cs[k], cs[k], true, true, p);
      if (!r.IsNull())
        vp = vol(r);
    }
    catch (...)
    {
      vp = -2;
    }
    try
    {
      Handle(ShapeCustom_BSplineRestriction) m =
        new ShapeCustom_BSplineRestriction(true, true, true, 0.01, 0.01, cs[k], cs[k], 6, 20, true, true);
      BRepTools_Modifier mod(cyl, m);
      if (mod.IsDone())
        va = vol(mod.ModifiedShape(cyl));
    }
    catch (...)
    {
      va = -2;
    }
    printf("#490 restriction %s: plain volume=%.9f advanced volume=%.9f (-1 null, -2 threw)\n", cn[k], vp, va);
  }
  // #490 surface split: cubic in U with a mult-3 knot at 0.5
  {
    TColgp_Array2OfPnt P(1, 7, 1, 4);
    for (int i = 0; i < 7; i++)
      for (int j = 0; j < 4; j++)
        P(i + 1, j + 1) = gp_Pnt(i, j, i <= 3 ? 0.3 * i : 0.3 * (8.0 - i));
    TColStd_Array1OfReal    ku(1, 3), kv(1, 2);
    TColStd_Array1OfInteger mu(1, 3), mv(1, 2);
    ku(1) = 0; ku(2) = 0.5; ku(3) = 1; mu(1) = 4; mu(2) = 3; mu(3) = 4;
    kv(1) = 0; kv(2) = 1; mv(1) = 4; mv(2) = 4;
    Handle(Geom_BSplineSurface) s = new Geom_BSplineSurface(P, ku, kv, mu, mv, 3, 3);
    GeomAbs_Shape               lv[] = {GeomAbs_C0, GeomAbs_C1, GeomAbs_C2, GeomAbs_C3, GeomAbs_CN};
    const char*                 ln[] = {"C0", "C1", "C2", "C3", "CN (99 saturates here)"};
    for (int k = 0; k < 5; k++)
    {
      Handle(ShapeUpgrade_SplitSurfaceContinuity) sp = new ShapeUpgrade_SplitSurfaceContinuity();
      sp->Init(s);
      sp->SetCriterion(lv[k]);
      sp->SetTolerance(1e-6);
      sp->Perform();
      printf("#490 split %s: uSplitValues=%d vSplitValues=%d\n", ln[k], sp->USplitValues()->Length(),
             sp->VSplitValues()->Length());
    }
  }
  // #570 offset sphere, full domain
  {
    Handle(Geom_SphericalSurface) sph = new Geom_SphericalSurface(gp_Ax3(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 10);
    Handle(Geom_OffsetSurface)    off = new Geom_OffsetSurface(sph, 2);
    double                        u0, u1, v0, v1;
    off->Bounds(u0, u1, v0, v1);
    TopoDS_Face  f = BRepBuilderAPI_MakeFace(off, u0, u1, v0, v1, 1e-7);
    TopoDS_Shape c = ShapeCustom::ConvertToBSpline(f, true, true, true, false);
    Handle(Geom_BSplineSurface) b =
      Handle(Geom_BSplineSurface)::DownCast(BRep_Tool::Surface(TopoDS::Face(TopExp_Explorer(c, TopAbs_FACE).Current())));
    printf("#570 ConvertToBSpline(offset sphere): isBSpline=%d uDegree=%d uPoles=%d deviation=%.3e\n", (int)!b.IsNull(),
           b.IsNull() ? -1 : b->UDegree(), b.IsNull() ? -1 : b->NbUPoles(), deviation(c, off));
    Handle(ShapeCustom_RestrictionParameters) p = new ShapeCustom_RestrictionParameters();
    TopoDS_Shape r = ShapeCustom::BSplineRestriction(f, 0.01, 0.01, 9, 10000, GeomAbs_C1, GeomAbs_C1, true, true, p);
    printf("#570 BSplineRestriction(offset sphere, tol 0.01): deviation=%.3e\n", deviation(r, off));
    TopoDS_Shape r2 = ShapeCustom::BSplineRestriction(f, 10, 10, 9, 10000, GeomAbs_C1, GeomAbs_C1, true, true, p);
    printf("#570 BSplineRestriction(offset sphere, tol 10, the RTOL injection): deviation=%.3e\n", deviation(r2, off));
    TopoDS_Face  fb = BRepBuilderAPI_MakeFace(sph, u0, u1, v0, v1, 1e-7);
    TopoDS_Shape cb = ShapeCustom::ConvertToBSpline(fb, true, true, true, false);
    printf("#570 basis sphere instead of the offset (the OFFSETBASIS injection): deviation from offset=%.3e\n",
           deviation(cb, off));
  }
  // #655 fixture
  for (int o = 0; o < 2; o++)
  {
    TopAbs_Orientation         ori = o == 0 ? TopAbs_INTERNAL : TopAbs_FORWARD;
    BRepBuilderAPI_MakePolygon p1(gp_Pnt(0, 0, 0), gp_Pnt(10, 0, 0), gp_Pnt(10, 10, 0), gp_Pnt(0, 10, 0), true);
    TopoDS_Face                f1 = BRepBuilderAPI_MakeFace(p1.Wire());
    BRep_Builder               b;
    TopoDS_Wire                loop;
    b.MakeWire(loop);
    gp_Pnt lp[] = {gp_Pnt(2, 2, 0), gp_Pnt(8, 2, 0), gp_Pnt(8, 8, 0), gp_Pnt(2, 8, 0)};
    for (int i = 0; i < 4; i++)
    {
      TopoDS_Edge e = BRepBuilderAPI_MakeEdge(lp[i], lp[(i + 1) % 4]);
      e.Orientation(ori);
      b.Add(loop, e);
    }
    loop.Orientation(ori);
    b.Add(f1, loop);
    BRepBuilderAPI_MakePolygon p2(gp_Pnt(50, 50, 0), gp_Pnt(60, 50, 0), gp_Pnt(60, 60, 0), gp_Pnt(50, 60, 0), true);
    TopoDS_Compound            comp;
    b.MakeCompound(comp);
    b.Add(comp, f1);
    b.Add(comp, BRepBuilderAPI_MakeFace(p2.Wire()).Face());
    ShapeAnalysis_FreeBounds a(comp, 1e-6);
    printf("#655 %s loop: edges=%d closedWires=%d closedEdges=%d openWires=%d", o == 0 ? "INTERNAL" : "FORWARD",
           count(comp, TopAbs_EDGE), count(a.GetClosedWires(), TopAbs_WIRE), count(a.GetClosedWires(), TopAbs_EDGE),
           count(a.GetOpenWires(), TopAbs_WIRE));
    for (double tol : {0.0, -1.0})
    {
      ShapeAnalysis_FreeBoundsProperties fp;
      fp.Init(comp, tol);
      fp.Perform();
      printf("; props(tol %g) closed=%d open=%d", tol, (int)fp.NbClosedFreeBounds(), (int)fp.NbOpenFreeBounds());
    }
    printf("\n");
  }
  return 0;
}
