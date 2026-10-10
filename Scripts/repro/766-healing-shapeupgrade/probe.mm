// #766 kernel parity: ShapeUpgradeClosedEdgeDivide, ConvertCurves3dToBezier, ConvertSurfacesToBezier,
// DivideClosed, EdgeDivide, FaceDivide, ShellSewing, SplitCurve, WireDivide tests. Each ShapeUpgrade_*
// class is driven exactly as its bridge function drives it (OCCTBridge_Healing_Upgrade.mm,
// OCCTBridge_Healing_Sewing.mm, OCCTBridge_Curve3D_Conversion.mm, OCCTBridge_Geom2d_Conversion.mm),
// on the same inputs; sub-shape indices are TopExp::MapShapes order, which is what
// Shape.subShapes(ofType:) returns. A null Result() is reported as null: the bridge maps it to nil.
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <BRepAdaptor_Curve.hxx>
#include <BRepAdaptor_Surface.hxx>
#include <BRepCheck_Analyzer.hxx>
#include <BRepGProp.hxx>
#include <GProp_GProps.hxx>
#include <BRep_Tool.hxx>
#include <Geom_BSplineCurve.hxx>
#include <Geom2d_BSplineCurve.hxx>
#include <Geom2d_BezierCurve.hxx>
#include <ShapeBuild_ReShape.hxx>
#include <ShapeUpgrade_ClosedEdgeDivide.hxx>
#include <ShapeUpgrade_ConvertCurve2dToBezier.hxx>
#include <ShapeUpgrade_EdgeDivide.hxx>
#include <ShapeUpgrade_FaceDivide.hxx>
#include <ShapeUpgrade_ShapeConvertToBezier.hxx>
#include <ShapeUpgrade_ShapeDivideClosed.hxx>
#include <ShapeUpgrade_ShellSewing.hxx>
#include <ShapeUpgrade_SplitCurve2dContinuity.hxx>
#include <ShapeUpgrade_SplitCurve3dContinuity.hxx>
#include <ShapeUpgrade_WireDivide.hxx>
#include <TColgp_Array1OfPnt.hxx>
#include <TColgp_Array1OfPnt2d.hxx>
#include <TColStd_Array1OfReal.hxx>
#include <TColStd_Array1OfInteger.hxx>
#include <TColGeom_HArray1OfCurve.hxx>
#include <TColGeom2d_HArray1OfCurve.hxx>
#include <TopExp.hxx>
#include <TopExp_Explorer.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopoDS.hxx>
#include <cstdio>
#include <vector>

static int unique(const TopoDS_Shape& s, TopAbs_ShapeEnum t)
{
  TopTools_IndexedMapOfShape m;
  TopExp::MapShapes(s, t, m);
  return m.Extent();
}

static void kinds(const char* label, const TopoDS_Shape& s)
{
  if (s.IsNull())
  {
    printf("%s: null (bridge returns nil)\n", label);
    return;
  }
  int cb = 0, ce = 0, sb = 0, sf = 0;
  TopTools_IndexedMapOfShape em, fm;
  TopExp::MapShapes(s, TopAbs_EDGE, em);
  TopExp::MapShapes(s, TopAbs_FACE, fm);
  for (int i = 1; i <= em.Extent(); i++)
  {
    if (BRep_Tool::Degenerated(TopoDS::Edge(em(i))))
      continue;
    ce++;
    if (BRepAdaptor_Curve(TopoDS::Edge(em(i))).GetType() == GeomAbs_BezierCurve)
      cb++;
  }
  for (int i = 1; i <= fm.Extent(); i++)
  {
    sf++;
    if (BRepAdaptor_Surface(TopoDS::Face(fm(i))).GetType() == GeomAbs_BezierSurface)
      sb++;
  }
  GProp_GProps g;
  BRepGProp::VolumeProperties(s, g);
  printf("%s: type=%d valid=%d edges(non-degenerate)=%d bezierEdges=%d faces=%d bezierFaces=%d volume=%.6f\n", label,
         (int)s.ShapeType(), (int)BRepCheck_Analyzer(s).IsValid(), ce, cb, sf, sb, g.Mass());
}

// OCCTShapeUpgradeConvertCurves3dToBezier
static TopoDS_Shape curves(const TopoDS_Shape& s, bool l, bool c, bool k, bool* done)
{
  ShapeUpgrade_ShapeConvertToBezier cv(s);
  cv.Set3dLineConversion(l);
  cv.Set3dCircleConversion(c);
  cv.Set3dConicConversion(k);
  cv.SetSurfaceSegmentMode(false); // curves only, as the bridge does
  *done = cv.Perform();
  return cv.Result();
}

// OCCTShapeUpgradeConvertSurfaceToBezier
static TopoDS_Shape surfaces(const TopoDS_Shape& s, bool p, bool r, bool e, bool b, bool* done)
{
  ShapeUpgrade_ShapeConvertToBezier cv(s);
  cv.SetPlaneMode(p);
  cv.SetRevolutionMode(r);
  cv.SetExtrusionMode(e);
  cv.SetBSplineMode(b);
  cv.SetSurfaceSegmentMode(true);
  *done = cv.Perform();
  return cv.Result();
}

static void printCurves3d(const char* label, const Handle(TColGeom_HArray1OfCurve)& cs)
{
  printf("%s: curves=%d", label, cs.IsNull() ? 0 : cs->Length());
  if (!cs.IsNull())
    for (int i = cs->Lower(); i <= cs->Upper(); i++)
    {
      gp_Pnt a = cs->Value(i)->Value(cs->Value(i)->FirstParameter());
      gp_Pnt b = cs->Value(i)->Value(cs->Value(i)->LastParameter());
      printf(" [(%g, %g, %g)-(%g, %g, %g)]", a.X(), a.Y(), a.Z(), b.X(), b.Y(), b.Z());
    }
  printf("\n");
}

static void printCurves2d(const char* label, const Handle(TColGeom2d_HArray1OfCurve)& cs)
{
  printf("%s: curves=%d", label, cs.IsNull() ? 0 : cs->Length());
  if (!cs.IsNull())
    for (int i = cs->Lower(); i <= cs->Upper(); i++)
    {
      gp_Pnt2d a = cs->Value(i)->Value(cs->Value(i)->FirstParameter());
      gp_Pnt2d b = cs->Value(i)->Value(cs->Value(i)->LastParameter());
      printf(" [(%g, %g)-(%g, %g) bezier=%d]", a.X(), a.Y(), b.X(), b.Y(),
             (int)cs->Value(i)->IsKind(STANDARD_TYPE(Geom2d_BezierCurve)));
    }
  printf("\n");
}

int main()
{
  setvbuf(stdout, nullptr, _IONBF, 0);
  TopoDS_Shape box = BRepPrimAPI_MakeBox(gp_Pnt(-5, -5, -5), 10, 10, 10).Shape();
  TopoDS_Shape cyl = BRepPrimAPI_MakeCylinder(5, 10).Shape();

  // ClosedEdgeDivide: OCCTShapeUpgradeClosedEdgeDivideCompute, every edge against face 0.
  {
    TopTools_IndexedMapOfShape e, f;
    TopExp::MapShapes(cyl, TopAbs_EDGE, e);
    TopExp::MapShapes(cyl, TopAbs_FACE, f);
    printf("cylinder: edges=%d faces=%d face0 type=%d\n", e.Extent(), f.Extent(),
           (int)BRepAdaptor_Surface(TopoDS::Face(f(1))).GetType());
    for (int i = 1; i <= e.Extent(); i++)
    {
      TopoDS_Edge ed = TopoDS::Edge(e(i));
      Handle(ShapeUpgrade_ClosedEdgeDivide) ced = new ShapeUpgrade_ClosedEdgeDivide();
      ced->SetFace(TopoDS::Face(f(1)));
      bool c = ced->Compute(ed);
      printf("  edge%d: curveType=%d closed=%d seamOnFace0=%d ClosedEdgeDivide.Compute(face0)=%d\n", i - 1,
             BRep_Tool::Degenerated(ed) ? -1 : (int)BRepAdaptor_Curve(ed).GetType(), (int)BRep_Tool::IsClosed(ed),
             (int)BRep_Tool::IsClosed(ed, TopoDS::Face(f(1))), (int)c);
    }
  }

  kinds("box", box);
  kinds("cylinder", cyl);
  bool d = false;
  TopoDS_Shape r;
  r = curves(box, true, true, true, &d);
  printf("curves->Bezier(box, T,T,T) Perform=%d ", (int)d);
  kinds("", r);
  r = curves(cyl, true, true, true, &d);
  printf("curves->Bezier(cyl, T,T,T) Perform=%d ", (int)d);
  kinds("", r);
  r = curves(cyl, false, true, false, &d);
  printf("curves->Bezier(cyl, F,T,F) Perform=%d ", (int)d);
  kinds("", r);
  r = surfaces(cyl, true, true, true, true, &d);
  printf("surfaces->Bezier(cyl, T,T,T,T) Perform=%d ", (int)d);
  kinds("", r);
  r = surfaces(cyl, false, true, false, false, &d);
  printf("surfaces->Bezier(cyl, F,T,F,F) Perform=%d ", (int)d);
  kinds("", r);
  r = surfaces(box, true, false, false, false, &d);
  printf("surfaces->Bezier(box, T,F,F,F) Perform=%d ", (int)d);
  kinds("", r);

  // The two bridge functions above never switch on the master modes (Set3dConversion /
  // SetSurfaceConversion), whose default is off, unlike OCCTShapeConvertToBezier. The same calls
  // with the master mode switched on, to show what the per-kind modes do once they are consulted:
  {
    struct C
    {
      const char*  label;
      TopoDS_Shape s;
      bool         l, c, k;
    } cs[] = {{"box, T,T,T", box, true, true, true},
              {"cyl, T,T,T", cyl, true, true, true},
              {"cyl, F,T,F", cyl, false, true, false}};
    for (auto& x : cs)
    {
      ShapeUpgrade_ShapeConvertToBezier cv(x.s);
      cv.Set3dConversion(true);
      cv.Set3dLineConversion(x.l);
      cv.Set3dCircleConversion(x.c);
      cv.Set3dConicConversion(x.k);
      cv.SetSurfaceSegmentMode(false);
      bool ok = cv.Perform();
      printf("with Set3dConversion(true): curves->Bezier(%s) Perform=%d ", x.label, (int)ok);
      kinds("", cv.Result());
    }
    struct S
    {
      const char*  label;
      TopoDS_Shape s;
      bool         p, r, e, b;
    } ss[] = {{"cyl, T,T,T,T", cyl, true, true, true, true},
              {"cyl, F,T,F,F", cyl, false, true, false, false},
              {"box, T,F,F,F", box, true, false, false, false}};
    for (auto& x : ss)
    {
      ShapeUpgrade_ShapeConvertToBezier cv(x.s);
      cv.SetSurfaceConversion(true);
      cv.SetPlaneMode(x.p);
      cv.SetRevolutionMode(x.r);
      cv.SetExtrusionMode(x.e);
      cv.SetBSplineMode(x.b);
      cv.SetSurfaceSegmentMode(true);
      bool ok = cv.Perform();
      printf("with SetSurfaceConversion(true): surfaces->Bezier(%s) Perform=%d ", x.label, (int)ok);
      kinds("", cv.Result());
    }
  }

  // DivideClosed: OCCTShapeUpgradeDivideClosed(splitPoints 1).
  {
    ShapeUpgrade_ShapeDivideClosed dc(cyl);
    dc.SetNbSplitPoints(1);
    bool ok = dc.Perform();
    printf("DivideClosed(cyl, 1): Perform=%d ", (int)ok);
    kinds("", dc.Result());
  }

  // EdgeDivide: OCCTShapeUpgradeEdgeDivideCompute.
  {
    TopTools_IndexedMapOfShape e, f;
    TopExp::MapShapes(box, TopAbs_EDGE, e);
    TopExp::MapShapes(box, TopAbs_FACE, f);
    Handle(ShapeUpgrade_EdgeDivide) ed = new ShapeUpgrade_EdgeDivide();
    ed->SetFace(TopoDS::Face(f(1)));
    bool ok = ed->Compute(TopoDS::Edge(e(1)));
    printf("EdgeDivide(box edge0, face0): Compute=%d HasCurve2d=%d HasCurve3d=%d\n", (int)ok, (int)ed->HasCurve2d(),
           (int)ed->HasCurve3d());
    TopTools_IndexedMapOfShape ce, cf;
    TopExp::MapShapes(cyl, TopAbs_EDGE, ce);
    TopExp::MapShapes(cyl, TopAbs_FACE, cf);
    for (int i = 1; i <= ce.Extent(); i++)
    {
      Handle(ShapeUpgrade_EdgeDivide) ed2 = new ShapeUpgrade_EdgeDivide();
      ed2->SetFace(TopoDS::Face(cf(1)));
      bool c = ed2->Compute(TopoDS::Edge(ce(i)));
      printf("EdgeDivide(cyl edge%d, face0): Compute=%d HasCurve2d=%d HasCurve3d=%d\n", i - 1, (int)c,
             (int)ed2->HasCurve2d(), (int)ed2->HasCurve3d());
    }
  }

  // FaceDivide: OCCTShapeUpgradeFaceDivide on face 0.
  for (int k = 0; k < 2; k++)
  {
    TopoDS_Shape s = k == 0 ? BRepPrimAPI_MakeCylinder(5, 20).Shape() : BRepPrimAPI_MakeBox(gp_Pnt(-50, -50, -50), 100, 100, 100).Shape();
    TopTools_IndexedMapOfShape f;
    TopExp::MapShapes(s, TopAbs_FACE, f);
    Handle(ShapeUpgrade_FaceDivide) fd = new ShapeUpgrade_FaceDivide(TopoDS::Face(f(1)));
    fd->SetSurfaceSegmentMode(true);
    bool done = fd->Perform();
    TopoDS_Shape res = fd->Result();
    printf("FaceDivide(%s face0): Perform=%d resultNull=%d", k == 0 ? "cyl r5 h20" : "box 100", (int)done,
           (int)res.IsNull());
    if (!res.IsNull())
    {
      GProp_GProps g;
      BRepGProp::SurfaceProperties(res, g);
      GProp_GProps g0;
      BRepGProp::SurfaceProperties(f(1), g0);
      printf(" type=%d faces=%d area=%.6f inputArea=%.6f isSameAsInput=%d", (int)res.ShapeType(),
             unique(res, TopAbs_FACE), g.Mass(), g0.Mass(), (int)res.IsSame(f(1)));
    }
    printf("\n");
  }

  // ShellSewing: OCCTShapeUpgradeShellSewing.
  {
    ShapeUpgrade_ShellSewing ss;
    TopoDS_Shape             rr = ss.ApplySewing(box, 1e-6);
    printf("ShellSewing(box, 1e-6): ");
    kinds("", rr);
    if (!rr.IsNull())
      printf("  isSameAsInput=%d\n", (int)rr.IsSame(box));
  }

  // SplitCurve*Continuity / ConvertCurve2dToBezier, criterion 2 = C2 as the bridge decodes it.
  {
    // Single-span cubic (the tests' original fixture) and a two-span cubic whose interior knot
    // has multiplicity 2 (C1 there), which a C2 criterion must split.
    struct Fix
    {
      const char*          name;
      std::vector<double>  px, py, knots;
      std::vector<int>     mults;
    } fixes[] = {
      {"single-span", {0, 1, 3, 4}, {0, 2, 1, 0}, {0, 1}, {4, 4}},
      {"C1 at 0.5", {0, 1, 2, 3, 4, 5}, {0, 2, 2, 1, 0, 1}, {0, 0.5, 1}, {4, 2, 4}},
    };
    for (auto& fx : fixes)
    {
      int                     np = (int)fx.px.size(), nk = (int)fx.knots.size();
      TColgp_Array1OfPnt      P(1, np);
      TColgp_Array1OfPnt2d    P2(1, np);
      TColStd_Array1OfReal    K(1, nk);
      TColStd_Array1OfInteger M(1, nk);
      for (int i = 0; i < np; i++)
      {
        P(i + 1)  = gp_Pnt(fx.px[i], fx.py[i], 0);
        P2(i + 1) = gp_Pnt2d(fx.px[i], fx.py[i]);
      }
      for (int i = 0; i < nk; i++)
      {
        K(i + 1) = fx.knots[i];
        M(i + 1) = fx.mults[i];
      }
      Handle(Geom_BSplineCurve)   c3 = new Geom_BSplineCurve(P, K, M, 3);
      Handle(Geom2d_BSplineCurve) c2 = new Geom2d_BSplineCurve(P2, K, M, 3);
      printf("%s: continuity3d=%d\n", fx.name, (int)c3->Continuity());
      gp_Pnt mid = c3->Value(0.5);
      printf("  C(0.5)=(%.9f, %.9f)\n", mid.X(), mid.Y());

      Handle(ShapeUpgrade_SplitCurve3dContinuity) s3 = new ShapeUpgrade_SplitCurve3dContinuity();
      s3->Init(c3);
      s3->SetCriterion(GeomAbs_C2);
      s3->SetTolerance(1e-6);
      s3->Perform(true);
      printCurves3d("  SplitCurve3dContinuity(C2)", s3->GetCurves());

      Handle(ShapeUpgrade_SplitCurve2dContinuity) s2 = new ShapeUpgrade_SplitCurve2dContinuity();
      s2->Init(c2);
      s2->SetCriterion(GeomAbs_C2);
      s2->SetTolerance(1e-6);
      s2->Perform(true);
      printCurves2d("  SplitCurve2dContinuity(C2)", s2->GetCurves());

      Handle(ShapeUpgrade_ConvertCurve2dToBezier) cb = new ShapeUpgrade_ConvertCurve2dToBezier();
      cb->Init(c2);
      cb->Perform(true);
      printCurves2d("  ConvertCurve2dToBezier", cb->GetCurves());
    }
  }

  // WireDivide: OCCTShapeUpgradeWireDivideOnFace(box wire0, box face0).
  {
    TopTools_IndexedMapOfShape f, w;
    TopExp::MapShapes(box, TopAbs_FACE, f);
    TopExp::MapShapes(box, TopAbs_WIRE, w);
    bool allPCurves = true;
    for (TopExp_Explorer ex(w(1), TopAbs_EDGE); ex.More(); ex.Next())
    {
      double a, b;
      if (BRep_Tool::CurveOnSurface(TopoDS::Edge(ex.Current()), TopoDS::Face(f(1)), a, b).IsNull())
        allPCurves = false;
    }
    printf("WireDivide(box wire0, face0): every edge has a pcurve on face0=%d", (int)allPCurves);
    if (allPCurves)
    {
      Handle(ShapeUpgrade_WireDivide) wd = new ShapeUpgrade_WireDivide();
      wd->SetContext(new ShapeBuild_ReShape());
      wd->Init(TopoDS::Wire(w(1)), TopoDS::Face(f(1)));
      wd->Perform();
      printf(" StatusDONE=%d wireNull=%d edges=%d isSameAsInput=%d", (int)wd->Status(ShapeExtend_DONE), (int)wd->Wire().IsNull(),
             wd->Wire().IsNull() ? -1 : unique(wd->Wire(), TopAbs_EDGE), (int)wd->Wire().IsSame(w(1)));
    }
    printf("\n");
  }
  return 0;
}
