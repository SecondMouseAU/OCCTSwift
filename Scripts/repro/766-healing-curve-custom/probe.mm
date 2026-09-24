// #766 kernel parity: BSplineRestrictionAdvancedTests, ConvertToBSplineAdvancedTests,
// CurveConvertToPeriodicTests, CurveProjectTests, CurveSamplePointsTests, CurveSplitTests,
// CurveValidateRangeTests. Same OCCT calls, same inputs as the bridge functions.
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <BRepCheck_Analyzer.hxx>
#include <BRepGProp.hxx>
#include <GProp_GProps.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <BRepAdaptor_Surface.hxx>
#include <BRepBndLib.hxx>
#include <Bnd_Box.hxx>
#include <BRepTools_Modifier.hxx>
#include <ShapeCustom_BSplineRestriction.hxx>
#include <ShapeCustom_ConvertToBSpline.hxx>
#include <ShapeCustom_Curve.hxx>
#include <ShapeAnalysis_Curve.hxx>
#include <ShapeUpgrade_SplitCurve3d.hxx>
#include <GeomAPI_Interpolate.hxx>
#include <GC_MakeSegment.hxx>
#include <Geom_Circle.hxx>
#include <Geom_TrimmedCurve.hxx>
#include <Geom_BSplineCurve.hxx>
#include <TColgp_HArray1OfPnt.hxx>
#include <TColStd_HSequenceOfReal.hxx>
#include <TColGeom_HArray1OfCurve.hxx>
#include <NCollection_Sequence.hxx>
#include <cstdio>

static const char* stype(int t)
{
  const char* n[] = {"plane", "cylinder", "cone", "sphere", "torus", "bezier",
                     "bspline", "revolution", "extrusion", "offset", "other"};
  return n[t];
}

static void report(const char* label, const TopoDS_Shape& s)
{
  if (s.IsNull())
  {
    printf("%s: NULL\n", label);
    return;
  }
  GProp_GProps p;
  BRepGProp::VolumeProperties(s, p);
  int nf         = 0;
  int counts[11] = {0};
  for (TopExp_Explorer e(s, TopAbs_FACE); e.More(); e.Next())
  {
    nf++;
    BRepAdaptor_Surface a(TopoDS::Face(e.Current()));
    counts[a.GetType()]++;
  }
  Bnd_Box b;
  BRepBndLib::Add(s, b);
  double x0, y0, z0, x1, y1, z1;
  b.Get(x0, y0, z0, x1, y1, z1);
  printf("%s: type=%d valid=%d faces=%d volume=%.9f bboxSize=(%.6f, %.6f, %.6f) surfaces:", label,
         (int)s.ShapeType(), (int)BRepCheck_Analyzer(s).IsValid(), nf, p.Mass(), x1 - x0, y1 - y0,
         z1 - z0);
  for (int i = 0; i < 11; i++)
    if (counts[i])
      printf(" %s=%d", stype(i), counts[i]);
  printf("\n");
}

static Handle(Geom_BSplineCurve) interp(const gp_Pnt* p, int n)
{
  Handle(TColgp_HArray1OfPnt) pts = new TColgp_HArray1OfPnt(1, n);
  for (int i = 0; i < n; i++)
    pts->SetValue(i + 1, p[i]);
  GeomAPI_Interpolate in(pts, Standard_False, 1e-6);
  in.Perform();
  return in.IsDone() ? in.Curve() : Handle(Geom_BSplineCurve)();
}

int main()
{
  // restrictBox: OCCTShapeBSplineRestrictionAdvanced(box 10x20x30, T,T,T, 0.1, 0.1, C1, C1, 5, 20, T, F)
  {
    TopoDS_Shape box = BRepPrimAPI_MakeBox(gp_Pnt(-5, -10, -15), 10, 20, 30).Shape();
    Handle(ShapeCustom_BSplineRestriction) mod = new ShapeCustom_BSplineRestriction(
      Standard_True, Standard_True, Standard_True, 0.1, 0.1, GeomAbs_C1, GeomAbs_C1, 5, 20,
      Standard_True, Standard_False);
    BRepTools_Modifier m(box, mod);
    printf("restrictBox IsDone=%d\n", (int)m.IsDone());
    report("restrictBox result", m.ModifiedShape(box));
  }
  // convertCylinder: OCCTShapeConvertToBSplineAdvanced(cyl r10 h50, T, T, T, F)
  {
    TopoDS_Shape                         cyl = BRepPrimAPI_MakeCylinder(10, 50).Shape();
    Handle(ShapeCustom_ConvertToBSpline) mod = new ShapeCustom_ConvertToBSpline();
    mod->SetExtrusionMode(Standard_True);
    mod->SetRevolutionMode(Standard_True);
    mod->SetOffsetMode(Standard_True);
    mod->SetPlaneMode(Standard_False);
    BRepTools_Modifier m(cyl, mod);
    printf("convertCylinder IsDone=%d\n", (int)m.IsDone());
    report("convertCylinder result", m.ModifiedShape(cyl));
    // what planeMode=true would do (the injection)
    Handle(ShapeCustom_ConvertToBSpline) mod2 = new ShapeCustom_ConvertToBSpline();
    mod2->SetPlaneMode(Standard_True);
    BRepTools_Modifier m2(cyl, mod2);
    report("convertCylinder planeMode=T", m2.ModifiedShape(cyl));
  }
  // convertToPeriodic: interpolate the 5 points (first == last), ShapeCustom_Curve::ConvertToPeriodic(false)
  {
    gp_Pnt p[] = {gp_Pnt(10, 0, 0), gp_Pnt(0, 10, 0), gp_Pnt(-10, 0, 0), gp_Pnt(0, -10, 0),
                  gp_Pnt(10, 0, 0)};
    Handle(Geom_BSplineCurve) c = interp(p, 5);
    printf("interpolated closed: null=%d isPeriodic=%d isClosed=%d first=%.9f last=%.9f\n",
           (int)c.IsNull(), (int)c->IsPeriodic(), (int)c->IsClosed(), c->FirstParameter(),
           c->LastParameter());
    ShapeCustom_Curve  scc(c);
    Handle(Geom_Curve) per = scc.ConvertToPeriodic(Standard_False);
    printf("ConvertToPeriodic: null=%d", (int)per.IsNull());
    if (!per.IsNull())
    {
      gp_Pnt a = per->Value(per->FirstParameter());
      printf(" type=%s isPeriodic=%d isClosed=%d first=%.9f last=%.9f start=(%.6f, %.6f, %.6f)",
             per->DynamicType()->Name(), (int)per->IsPeriodic(), (int)per->IsClosed(),
             per->FirstParameter(), per->LastParameter(), a.X(), a.Y(), a.Z());
    }
    printf("\n");
  }
  ShapeAnalysis_Curve        sac;
  Handle(Geom_TrimmedCurve)  seg = GC_MakeSegment(gp_Pnt(0, 0, 0), gp_Pnt(10, 0, 0)).Value();
  Handle(Geom_Circle)        circ5 = new Geom_Circle(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 5);
  printf("segment domain=[%.9f, %.9f]; circle domain=[%.9f, %.9f]\n", seg->FirstParameter(),
         seg->LastParameter(), circ5->FirstParameter(), circ5->LastParameter());
  // projectOntoLine / projectOntoCircle: ShapeAnalysis_Curve::Project over the curve's own domain
  {
    gp_Pnt proj;
    double param = 0;
    double d = sac.Project(seg, gp_Pnt(5, 3, 0), 1e-6, proj, param, seg->FirstParameter(),
                           seg->LastParameter(), Standard_False);
    printf("project (5,3,0) on segment: distance=%.9f parameter=%.9f point=(%.9f, %.9f, %.9f)\n", d,
           param, proj.X(), proj.Y(), proj.Z());
    d = sac.Project(circ5, gp_Pnt(10, 0, 0), 1e-6, proj, param, circ5->FirstParameter(),
                    circ5->LastParameter(), Standard_False);
    printf("project (10,0,0) on circle r5: distance=%.9f parameter=%.9f point=(%.9f, %.9f, %.9f)\n",
           d, param, proj.X(), proj.Y(), proj.Z());
  }
  // sampleCircle / sampleLine: ShapeAnalysis_Curve::GetSamplePoints over the full domain
  {
    NCollection_Sequence<gp_Pnt> pts;
    bool ok = sac.GetSamplePoints(circ5, circ5->FirstParameter(), circ5->LastParameter(), pts);
    double maxDev = 0;
    for (int i = 1; i <= pts.Length(); i++)
      maxDev = std::max(maxDev, std::abs(gp_Pnt(0, 0, 0).Distance(pts(i)) - 5.0));
    printf("samples circle: ok=%d count=%d first=(%.9f, %.9f, %.9f) last=(%.9f, %.9f, %.9f) maxRadiusDev=%.3e\n",
           (int)ok, pts.Length(), pts(1).X(), pts(1).Y(), pts(1).Z(), pts(pts.Length()).X(),
           pts(pts.Length()).Y(), pts(pts.Length()).Z(), maxDev);
    NCollection_Sequence<gp_Pnt> lp;
    ok = sac.GetSamplePoints(seg, seg->FirstParameter(), seg->LastParameter(), lp);
    printf("samples segment: ok=%d count=%d", (int)ok, lp.Length());
    for (int i = 1; i <= lp.Length(); i++)
      printf(" (%.6f, %.6f, %.6f)", lp(i).X(), lp(i).Y(), lp(i).Z());
    printf("\n");
  }
  // splitCurve: interpolate, split at mid of domain with ShapeUpgrade_SplitCurve3d
  {
    gp_Pnt p[] = {gp_Pnt(0, 0, 0), gp_Pnt(2, 5, 0), gp_Pnt(5, 3, 0), gp_Pnt(8, 7, 0),
                  gp_Pnt(10, 0, 0)};
    Handle(Geom_BSplineCurve) c   = interp(p, 5);
    double                    f   = c->FirstParameter(), l = c->LastParameter();
    double                    mid = (f + l) / 2.0;
    Handle(ShapeUpgrade_SplitCurve3d) sp = new ShapeUpgrade_SplitCurve3d();
    sp->Init(c, f, l);
    Handle(TColStd_HSequenceOfReal) vals = new TColStd_HSequenceOfReal();
    vals->Append(mid);
    sp->SetSplitValues(vals);
    sp->Perform(Standard_True);
    Handle(TColGeom_HArray1OfCurve) cs = sp->GetCurves();
    gp_Pnt                          pm = c->Value(mid);
    printf("split: domain=[%.9f, %.9f] mid=%.9f point(mid)=(%.9f, %.9f, %.9f) pieces=%d\n", f, l, mid,
           pm.X(), pm.Y(), pm.Z(), cs.IsNull() ? -1 : cs->Length());
    for (int i = 1; !cs.IsNull() && i <= cs->Length(); i++)
    {
      Handle(Geom_Curve) k = cs->Value(i);
      gp_Pnt             a = k->Value(k->FirstParameter()), b = k->Value(k->LastParameter());
      printf("  piece %d: [%.9f, %.9f] start=(%.9f, %.9f, %.9f) end=(%.9f, %.9f, %.9f)\n", i,
             k->FirstParameter(), k->LastParameter(), a.X(), a.Y(), a.Z(), b.X(), b.Y(), b.Z());
    }
  }
  // validateInBounds / validateOutOfBounds: ShapeAnalysis_Curve::ValidateRange(seg, f, l, 1e-6)
  {
    double f = 2, l = 8;
    bool   a = sac.ValidateRange(seg, f, l, 1e-6);
    printf("ValidateRange(2, 8): returned=%d first=%.9f last=%.9f\n", (int)a, f, l);
    f = -5;
    l = 15;
    a = sac.ValidateRange(seg, f, l, 1e-6);
    printf("ValidateRange(-5, 15): returned=%d first=%.9f last=%.9f\n", (int)a, f, l);
  }
  return 0;
}
