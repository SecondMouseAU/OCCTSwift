// Epic #766 evidence correction for PR #2654 (Tests/OCCTModelingTests/AdvancedModelingTests.swift).
// probe.mm printed the kernel side at %.10g and under keys the bridge side did not share. This probe
// repeats the same OCCT calls with every double at %.17g, every flag as true/false and every shape
// type by its OCCT name, one `label: key=value ...` line per test, so a record's kernel data is read
// from this transcript. `done` is the bridge's nil test: IsDone() and, for a solid, MakeSolid().
// The pipe lines print `signedVolume`, the raw BRepGProp::VolumeProperties mass that
// Shape.signedVolume reports: Shape.volume is nil for a degenerate or reversed sweep.
//
// Silent-pass revision (#766): pipeShellFrenet, pipeShellCorrectedFrenet and pipeShellFixedBinormal
// built their profile in the XY plane at the origin, and each spine starts in that plane, so the
// profile lay in the plane holding the spine's start tangent: pipeShellFrenet swept a solid of mass
// -6.9e-16, pipeShellFixedBinormal an invalid solid of mass 0 and pipeShellCorrectedFrenet 84.96 (the
// transcript this replaces). Those three lines are now measured on a profile built at the spine's
// start, perpendicular to the tangent there (Wire.point(at: 0) / Wire.tangent(at: 0):
// BRepAdaptor_CompCurve at FirstParameter, D1, normalised) and print `volume`, the mass Shape.volume
// reports for a valid solid, together with the volume the other modes give on the same spine and
// profile (`control...Volume`), which the test comments cite: the volume also says which mode ran.
// Frenet and corrected Frenet on the S-curve and fixed binormal (Z) on the 3D spine differ (436.40 /
// 445.03, and 508.59 / 634.64 / 624.29), so a bridge that swapped or dropped a mode fails.
// Only those three lines of transcript-evidence-fix.txt were regenerated; the rest are the earlier
// run's (a rerun against the pinned v4.0.0-kernel.1 asset moves the two shell volumes by one ulp, well
// inside the records' 1e-9 relative tolerance).
// Original header follows.
// Epic #766, Tests/OCCTModelingTests/AdvancedModelingTests.swift: kernel parity for all 28 tests.
// Same inputs as the Swift tests, straight to the OCCT classes the bridge functions call:
// BRepFilletAPI_MakeFillet (OCCTShapeFilletEdges / ...Linear), BRepOffsetAPI_DraftAngle
// (OCCTShapeDraft), BRepAlgoAPI_Defeaturing (OCCTShapeRemoveFeatures),
// BRepOffsetAPI_MakePipeShell (OCCTShapeCreatePipeShellMultiSection), BRepAdaptor_CompCurve
// (OCCTWireGet*), BRepBuilderAPI_Transform (OCCTWireOffset3D), Geom_BSplineSurface
// (OCCTShapeCreateBSplineSurface), BRepFill::Shell (OCCTShapeCreateRuled) and
// BRepOffsetAPI_MakeThickSolid::MakeThickSolidByJoin (OCCTShapeShellWithOpenFaces).
#include <BRepAdaptor_CompCurve.hxx>
#include <BRepAdaptor_Surface.hxx>
#include <BRepAlgoAPI_Cut.hxx>
#include <BRepAlgoAPI_Defeaturing.hxx>
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepBuilderAPI_MakePolygon.hxx>
#include <BRepBuilderAPI_MakeWire.hxx>
#include <BRepBuilderAPI_Transform.hxx>
#include <BRepCheck_Analyzer.hxx>
#include <BRepFill.hxx>
#include <BRepFilletAPI_MakeFillet.hxx>
#include <BRepGProp.hxx>
#include <BRepLProp_SLProps.hxx>
#include <BRepOffsetAPI_DraftAngle.hxx>
#include <BRepOffsetAPI_MakePipeShell.hxx>
#include <BRepOffsetAPI_MakeThickSolid.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <GCPnts_AbscissaPoint.hxx>
#include <GProp_GProps.hxx>
#include <GeomAPI_PointsToBSpline.hxx>
#include <Geom_BSplineCurve.hxx>
#include <Geom_BSplineSurface.hxx>
#include <TColStd_Array1OfInteger.hxx>
#include <TColStd_Array1OfReal.hxx>
#include <TColgp_Array1OfPnt.hxx>
#include <TColgp_Array2OfPnt.hxx>
#include <TopExp.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopTools_ListOfShape.hxx>
#include <TopoDS.hxx>
#include <TopAbs.hxx>
#include <cstdio>
#include <initializer_list>
#include <utility>
#include <gp_Circ.hxx>
#include <gp_Pln.hxx>

static TopoDS_Shape box(double w, double h, double d)
{
  return BRepPrimAPI_MakeBox(gp_Pnt(-w / 2, -h / 2, -d / 2), w, h, d).Shape();
}

static double volume(const TopoDS_Shape& s)
{
  GProp_GProps p;
  BRepGProp::VolumeProperties(s, p);
  return p.Mass();
}

static bool valid(const TopoDS_Shape& s) { return BRepCheck_Analyzer(s).IsValid(); }

static const char* tf(bool b) { return b ? "true" : "false"; }

static TopoDS_Wire circle(gp_Pnt o, double r)
{
  return BRepBuilderAPI_MakeWire(BRepBuilderAPI_MakeEdge(gp_Circ(gp_Ax2(o, gp_Dir(0, 0, 1)), r)));
}

static TopoDS_Wire line(gp_Pnt a, gp_Pnt b)
{
  return BRepBuilderAPI_MakeWire(BRepBuilderAPI_MakeEdge(a, b));
}

static TopoDS_Wire bspline(std::initializer_list<gp_Pnt> pts)
{
  TColgp_Array1OfPnt arr(1, (int)pts.size());
  int                i = 1;
  for (const gp_Pnt& p : pts)
    arr.SetValue(i++, p);
  GeomAPI_PointsToBSpline fit(arr);
  return BRepBuilderAPI_MakeWire(BRepBuilderAPI_MakeEdge(fit.Curve()));
}

// Face normal the way OCCTFaceGetNormal reports it: surface normal at the UV-box centre,
// reversed for a reversed face.
static gp_Dir faceNormal(const TopoDS_Face& f)
{
  BRepAdaptor_Surface s(f);
  BRepLProp_SLProps   p(s,
                      (s.FirstUParameter() + s.LastUParameter()) / 2,
                      (s.FirstVParameter() + s.LastVParameter()) / 2,
                      1,
                      1e-6);
  gp_Dir n = p.Normal();
  if (f.Orientation() == TopAbs_REVERSED)
    n.Reverse();
  return n;
}

static void pipe(const char* label, const TopoDS_Wire& spine, std::initializer_list<TopoDS_Wire> profiles,
                 int mode, const TopoDS_Wire* aux, bool solid)
{
  BRepOffsetAPI_MakePipeShell ps(spine);
  if (mode == 0)
    ps.SetMode(Standard_True);
  else if (mode == 1)
    ps.SetMode(Standard_False);
  else if (mode == 2)
    ps.SetMode(gp_Dir(0, 0, 1));
  else
    ps.SetMode(*aux, Standard_False);
  ps.SetTransitionMode(BRepBuilderAPI_Transformed);
  for (const TopoDS_Wire& w : profiles)
    ps.Add(w, Standard_False, Standard_False);
  ps.SetIsBuildHistory(false);
  ps.Build();
  bool done = ps.IsDone(), made = false;
  if (done && solid)
    made = ps.MakeSolid();
  TopoDS_Shape r = done ? ps.Shape() : TopoDS_Shape();
  bool built = done && (!solid || made);
  printf("%s: done=%s irDone=%s makeSolid=%s type=\"%s\" valid=%s", label, tf(built), tf(done), tf(made),
         r.IsNull() ? "NULL" : TopAbs::ShapeTypeToString(r.ShapeType()), tf(!r.IsNull() && valid(r)));
  if (solid)
    printf(" signedVolume=%.17g", r.IsNull() ? 0.0 : volume(r));
  printf("\n");
}

// #766: the start frame of a spine as Wire.point(at: 0) and Wire.tangent(at: 0) report it.
static void startFrame(const TopoDS_Wire& spine, gp_Pnt& p, gp_Vec& t)
{
  BRepAdaptor_CompCurve c(spine);
  gp_Vec                d1;
  c.D1(c.FirstParameter(), p, d1);
  t = d1;
  if (t.Magnitude() > 1e-10)
    t.Normalize();
}

static TopoDS_Wire circleAcross(const gp_Pnt& o, const gp_Vec& n, double r)
{
  return BRepBuilderAPI_MakeWire(BRepBuilderAPI_MakeEdge(gp_Circ(gp_Ax2(o, gp_Dir(n)), r)));
}

// A w x h rectangle across the spine's start, as the Swift test builds it: `side` = normalised
// (tangent x Z) carries w, `up` = normalised (tangent x side) carries h, corners (-,-) (+,-) (+,+)
// (-,+) of the centre, joined by BRepBuilderAPI_MakePolygon and closed (Wire.polygon3D).
static TopoDS_Wire rectangleAcross(const gp_Pnt& o, const gp_Vec& t, double w, double h)
{
  gp_Vec side = t.Crossed(gp_Vec(0, 0, 1));
  side.Normalize();
  gp_Vec up = t.Crossed(side);
  up.Normalize();
  auto corner = [&](double sa, double sb) {
    return gp_Pnt(o.XYZ() + side.XYZ() * (sa * w / 2) + up.XYZ() * (sb * h / 2));
  };
  BRepBuilderAPI_MakePolygon poly;
  poly.Add(corner(-1, -1));
  poly.Add(corner(1, -1));
  poly.Add(corner(1, 1));
  poly.Add(corner(-1, 1));
  poly.Close();
  return poly.Wire();
}

// One sweep as OCCTShapeCreatePipeShellMultiSection runs it (transition Transformed, no contact, no
// correction, SetIsBuildHistory(false), Build, MakeSolid); mode 0 Frenet, 1 corrected Frenet, 2 fixed
// binormal Z. Returns the mass and fills done/type/valid.
static double sweep(const TopoDS_Wire& spine, const TopoDS_Wire& profile, int mode, bool& done,
                    const char*& type, bool& valid)
{
  BRepOffsetAPI_MakePipeShell ps(spine);
  if (mode == 0)
    ps.SetMode(Standard_True);
  else if (mode == 1)
    ps.SetMode(Standard_False);
  else
    ps.SetMode(gp_Dir(0, 0, 1));
  ps.SetTransitionMode(BRepBuilderAPI_Transformed);
  ps.Add(profile, Standard_False, Standard_False);
  ps.SetIsBuildHistory(false);
  ps.Build();
  bool made = ps.IsDone() && ps.MakeSolid();
  done      = ps.IsDone() && made;
  TopoDS_Shape r = ps.IsDone() ? ps.Shape() : TopoDS_Shape();
  type           = r.IsNull() ? "NULL" : TopAbs::ShapeTypeToString(r.ShapeType());
  valid          = !r.IsNull() && BRepCheck_Analyzer(r).IsValid();
  return r.IsNull() ? 0.0 : volume(r);
}

// `builder(profile)` makes the profile for a given start frame; the main sweep runs in `mode`, and each
// entry of `controls` re-sweeps the same spine and profile in another mode and prints its volume.
static void pipeAcrossStart(const char* label, const TopoDS_Wire& spine, double circleRadius, double rectW,
                            double rectH, int mode, std::initializer_list<std::pair<const char*, int>> controls)
{
  gp_Pnt p;
  gp_Vec t;
  startFrame(spine, p, t);
  auto profile = [&]() { return circleRadius > 0 ? circleAcross(p, t, circleRadius) : rectangleAcross(p, t, rectW, rectH); };
  bool        done, valid;
  const char* type;
  double      v = sweep(spine, profile(), mode, done, type, valid);
  printf("%s: done=%s type=\"%s\" valid=%s volume=%.17g", label, tf(done), type, tf(valid), v);
  for (const auto& c : controls)
  {
    bool        d, va;
    const char* ty;
    printf(" %s=%.17g", c.first, sweep(spine, profile(), c.second, d, ty, va));
  }
  printf("\n");
}

static void filletEdges(const char* label, const TopoDS_Shape& s, int first, int count, double r1, double r2)
{
  TopTools_IndexedMapOfShape edges;
  TopExp::MapShapes(s, TopAbs_EDGE, edges);
  BRepFilletAPI_MakeFillet mf(s);
  for (int i = first; i < first + count; i++)
    mf.Add(r1, r2, TopoDS::Edge(edges(i + 1)));
  mf.Build();
  printf("%s: edges=%d done=%s valid=%s volume=%.17g\n", label, edges.Extent(), tf(mf.IsDone()),
         tf(mf.IsDone() && valid(mf.Shape())), mf.IsDone() ? volume(mf.Shape()) : 0.0);
}

int main()
{
  filletEdges("filletSpecificEdges", box(20, 20, 10), 0, 4, 2.0, 2.0);
  filletEdges("filletSingleEdge", box(20, 10, 10), 0, 1, 1.0, 1.0);
  filletEdges("filletVariableRadius", box(30, 10, 10), 0, 1, 1.0, 3.0);

  {
    TopTools_IndexedMapOfShape e, f;
    TopoDS_Shape               b = box(10, 10, 10);
    TopExp::MapShapes(b, TopAbs_EDGE, e);
    TopExp::MapShapes(b, TopAbs_FACE, f);
    printf("edgeHasIndex/faceHasIndex: edges=%d faces=%d\n",
           e.Extent(), f.Extent());
  }

  {
    TopoDS_Shape               b = box(20, 20, 30);
    TopTools_IndexedMapOfShape faces;
    TopExp::MapShapes(b, TopAbs_FACE, faces);
    BRepOffsetAPI_DraftAngle da(b);
    int                      vertical = 0;
    for (int i = 1; i <= faces.Extent(); i++)
    {
      gp_Dir n = faceNormal(TopoDS::Face(faces(i)));
      if (std::abs(n.Z()) < std::sin(0.01))
      {
        vertical++;
        da.Add(TopoDS::Face(faces(i)), gp_Dir(0, 0, 1), 3.0 * M_PI / 180.0,
               gp_Pln(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)));
      }
    }
    da.Build();
    printf("draftVerticalFaces: verticalFaces=%d done=%s valid=%s volume=%.17g\n", vertical, tf(da.IsDone()),
           tf(da.IsDone() && valid(da.Shape())), da.IsDone() ? volume(da.Shape()) : 0.0);
  }

  {
    TopoDS_Shape cyl = BRepPrimAPI_MakeCylinder(3, 40).Shape();
    gp_Trsf      t;
    t.SetTranslation(gp_Vec(0, 0, -20));
    cyl = BRepBuilderAPI_Transform(cyl, t, Standard_True).Shape();
    TopoDS_Shape               holed = BRepAlgoAPI_Cut(box(20, 20, 20), cyl).Shape();
    TopTools_IndexedMapOfShape faces;
    TopExp::MapShapes(holed, TopAbs_FACE, faces);
    TopTools_ListOfShape nonPlanar;
    for (int i = 1; i <= faces.Extent(); i++)
      if (BRepAdaptor_Surface(TopoDS::Face(faces(i))).GetType() != GeomAbs_Plane)
        nonPlanar.Append(faces(i));
    BRepAlgoAPI_Defeaturing df;
    df.SetShape(holed);
    df.AddFacesToRemove(nonPlanar);
    df.Build();
    printf("removeFeatures: faces=%d nonPlanarFaces=%d done=%s valid=%s volume=%.17g\n", faces.Extent(),
           nonPlanar.Extent(), tf(df.IsDone()), tf(df.IsDone() && valid(df.Shape())),
           df.IsDone() ? volume(df.Shape()) : 0.0);
  }

  // #766: the profile stands across the spine's start (see the header). Frenet on the planar S-curve
  // with an r=2 circle; corrected Frenet on the 3D spine with an r=1.5 circle; fixed binormal Z on the
  // same 3D spine with a 5 x 3 rectangle. Each line also prints the volume of the other modes on the
  // same spine and profile, which the test comments cite.
  pipeAcrossStart("pipeShellFrenet",
                  bspline({gp_Pnt(0, 0, 0), gp_Pnt(10, 0, 0), gp_Pnt(20, 10, 0), gp_Pnt(30, 10, 0)}), 2, 0, 0, 0,
                  {{"controlCorrectedFrenetVolume", 1}});
  pipeAcrossStart("pipeShellCorrectedFrenet",
                  bspline({gp_Pnt(0, 0, 0), gp_Pnt(10, 5, 0), gp_Pnt(20, -5, 10), gp_Pnt(30, 0, 10)}), 1.5, 0, 0, 1,
                  {{"controlFrenetVolume", 0}});
  pipeAcrossStart("pipeShellFixedBinormal",
                  bspline({gp_Pnt(0, 0, 0), gp_Pnt(10, 5, 0), gp_Pnt(20, -5, 10), gp_Pnt(30, 0, 10)}), 0, 5, 3, 2,
                  {{"controlCorrectedFrenetVolume", 1}, {"controlFrenetVolume", 0}});
  pipe("pipeShellCreatesShell", line(gp_Pnt(0, 0, 0), gp_Pnt(20, 0, 0)), {circle(gp_Pnt(0, 0, 0), 3)},
       0, nullptr, false);
  pipe("multiSectionFrenetVaryingRadius", line(gp_Pnt(0, 0, 0), gp_Pnt(0, 0, 10)),
       {circle(gp_Pnt(0, 0, 0), 2), circle(gp_Pnt(0, 0, 5), 1), circle(gp_Pnt(0, 0, 10), 2)}, 0,
       nullptr, true);
  {
    TopoDS_Wire aux = line(gp_Pnt(3, 0, 0), gp_Pnt(3, 0, 10));
    pipe("multiSectionAuxiliarySpine", line(gp_Pnt(0, 0, 0), gp_Pnt(0, 0, 10)),
         {circle(gp_Pnt(0, 0, 0), 2), circle(gp_Pnt(0, 0, 10), 1)}, 3, &aux, true);
  }
  pipe("multiSectionProfileCountBounds(single)", line(gp_Pnt(0, 0, 0), gp_Pnt(0, 0, 10)),
       {circle(gp_Pnt(0, 0, 0), 2)}, 0, nullptr, true);

  {
    BRepAdaptor_CompCurve l(line(gp_Pnt(0, 0, 0), gp_Pnt(10, 0, 0)));
    BRepAdaptor_CompCurve c(circle(gp_Pnt(0, 0, 0), 10));
    printf("wireLengthLine: length=%.17g\nwireLengthCircle: length=%.17g\n", GCPnts_AbscissaPoint::Length(l),
           GCPnts_AbscissaPoint::Length(c));
  }
  {
    BRepAdaptor_CompCurve c(circle(gp_Pnt(0, 0, 0), 5));
    printf("wireCurveInfoCircle: closed=%s length=%.17g\n", tf(c.IsClosed()), GCPnts_AbscissaPoint::Length(c));
    BRepAdaptor_CompCurve l(line(gp_Pnt(0, 0, 0), gp_Pnt(20, 0, 0)));
    gp_Pnt                s = l.Value(l.FirstParameter()), e = l.Value(l.LastParameter());
    printf("wireCurveInfoLine: closed=%s length=%.17g start=[%.17g,%.17g,%.17g] end=[%.17g,%.17g,%.17g]\n",
           tf(l.IsClosed()), GCPnts_AbscissaPoint::Length(l), s.X(), s.Y(), s.Z(), e.X(), e.Y(), e.Z());
    double px[3];
    int    k = 0;
    for (double t : {0.0, 0.5, 1.0})
      px[k++] = l.Value(l.FirstParameter() + t * (l.LastParameter() - l.FirstParameter())).X();
    printf("wirePointAtParameter: x@0=%.17g x@0.5=%.17g x@1=%.17g\n", px[0], px[1], px[2]);
  }
  {
    BRepAdaptor_CompCurve l(line(gp_Pnt(0, 0, 0), gp_Pnt(10, 0, 0)));
    gp_Pnt                p;
    gp_Vec                d1, d2;
    l.D2((l.FirstParameter() + l.LastParameter()) / 2, p, d1, d2);
    gp_Vec t = d1.Normalized();
    printf("wireTangentAtParameter: tangent=[%.17g,%.17g,%.17g]\n", t.X(), t.Y(), t.Z());
    printf("wireCurvatureLine: curvature=%.17g\n", d1.Crossed(d2).Magnitude() / std::pow(d1.Magnitude(), 3));
    BRepAdaptor_CompCurve c(circle(gp_Pnt(0, 0, 0), 10));
    c.D2(c.FirstParameter() + 0.5 * (c.LastParameter() - c.FirstParameter()), p, d1, d2);
    printf("wireCurvatureCircle: curvature=%.17g\n", d1.Crossed(d2).Magnitude() / std::pow(d1.Magnitude(), 3));
    BRepAdaptor_CompCurve c5(circle(gp_Pnt(0, 0, 0), 5));
    c5.D2(c5.FirstParameter() + 0.25 * (c5.LastParameter() - c5.FirstParameter()), p, d1, d2);
    gp_Vec T = d1.Normalized();
    gp_Vec N = (d2 - T.Multiplied(d2.Dot(T))).Normalized();
    printf("wireCurvePointDerivatives: point=[%.17g,%.17g,%.17g] curvature=%.17g normal=[%.17g,%.17g,%.17g]\n",
           p.X(), p.Y(), p.Z(), d1.Crossed(d2).Magnitude() / std::pow(d1.Magnitude(), 3), N.X(), N.Y(), N.Z());
  }
  {
    gp_Trsf t;
    t.SetTranslation(gp_Vec(0, 0, 10));
    TopoDS_Wire           w = TopoDS::Wire(BRepBuilderAPI_Transform(circle(gp_Pnt(0, 0, 0), 5), t, Standard_True).Shape());
    BRepAdaptor_CompCurve c(w);
    gp_Pnt                s = c.Value(c.FirstParameter());
    printf("wireOffset3D: start=[%.17g,%.17g,%.17g]\n", s.X(), s.Y(), s.Z());
  }
  {
    double             z[4] = {0, 1, 1, 0};
    TColgp_Array2OfPnt poles(1, 4, 1, 4);
    for (int u = 0; u < 4; u++)
      for (int v = 0; v < 4; v++)
        poles.SetValue(u + 1, v + 1, gp_Pnt(10.0 * u, 10.0 * v, z[u]));
    TColStd_Array1OfReal    knots(1, 2);
    TColStd_Array1OfInteger mults(1, 2);
    knots.SetValue(1, 0);
    knots.SetValue(2, 1);
    mults.SetValue(1, 4);
    mults.SetValue(2, 4);
    Handle(Geom_BSplineSurface) s = new Geom_BSplineSurface(poles, knots, knots, mults, mults, 3, 3);
    BRepBuilderAPI_MakeFace     mf(s, 1e-6);
    printf("bsplineSurface: done=%s valid=%s\n", tf(mf.IsDone()), tf(mf.IsDone() && valid(mf.Face())));
  }
  {
    gp_Trsf t;
    t.SetTranslation(gp_Vec(0, 0, 20));
    TopoDS_Wire  bottom = circle(gp_Pnt(0, 0, 0), 10);
    TopoDS_Wire  top    = TopoDS::Wire(BRepBuilderAPI_Transform(bottom, t, Standard_True).Shape());
    TopoDS_Shape r      = BRepFill::Shell(bottom, top);
    printf("ruledSurfaceBetweenCircles: done=%s type=\"%s\"\n", tf(!r.IsNull()),
           r.IsNull() ? "NULL" : TopAbs::ShapeTypeToString(r.ShapeType()));
  }
  for (int which = 0; which < 2; which++)
  {
    TopoDS_Shape               b = which == 0 ? box(20, 20, 20) : box(30, 20, 10);
    TopTools_IndexedMapOfShape faces;
    TopExp::MapShapes(b, TopAbs_FACE, faces);
    TopTools_ListOfShape open;
    int                  up = 0;
    for (int i = 1; i <= faces.Extent(); i++)
    {
      if (which == 0 && faceNormal(TopoDS::Face(faces(i))).Z() > std::cos(0.01))
      {
        open.Append(faces(i));
        up++;
      }
    }
    if (which == 1)
      open.Append(faces(1));
    BRepOffsetAPI_MakeThickSolid ts;
    ts.MakeThickSolidByJoin(b, open, which == 0 ? 2.0 : 1.5, 1e-6);
    printf("%s: upwardFaces=%d done=%s valid=%s volume=%.17g\n",
           which == 0 ? "shellWithOpenFaces" : "shellWithSpecificFaceOpen", up, tf(ts.IsDone()),
           tf(ts.IsDone() && valid(ts.Shape())), ts.IsDone() ? volume(ts.Shape()) : 0.0);
  }
  return 0;
}
