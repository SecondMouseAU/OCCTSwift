// Epic #766 evidence correction for PR #2654 (Tests/OCCTModelingTests/AdvancedModelingTests.swift).
// probe.mm printed the kernel side at %.10g and under keys the bridge side did not share. This probe
// repeats the same OCCT calls with every double at %.17g, every flag as true/false and every shape
// type by its OCCT name, one `label: key=value ...` line per test, so a record's kernel data is read
// from this transcript. `done` is the bridge's nil test: IsDone() and, for a solid, MakeSolid().
// The pipe lines print `signedVolume`, the raw BRepGProp::VolumeProperties mass that
// Shape.signedVolume reports: Shape.volume is nil for a degenerate or reversed sweep.
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

  pipe("pipeShellFrenet", bspline({gp_Pnt(0, 0, 0), gp_Pnt(10, 0, 0), gp_Pnt(20, 10, 0), gp_Pnt(30, 10, 0)}),
       {circle(gp_Pnt(0, 0, 0), 2)}, 0, nullptr, true);
  pipe("pipeShellCorrectedFrenet",
       bspline({gp_Pnt(0, 0, 0), gp_Pnt(10, 5, 0), gp_Pnt(20, -5, 10), gp_Pnt(30, 0, 10)}),
       {circle(gp_Pnt(0, 0, 0), 1.5)}, 1, nullptr, true);
  {
    // Wire.rectangle(5, 3): centred at the origin in the XY plane.
    BRepBuilderAPI_MakeWire rect;
    gp_Pnt p1(-2.5, -1.5, 0), p2(2.5, -1.5, 0), p3(2.5, 1.5, 0), p4(-2.5, 1.5, 0);
    rect.Add(BRepBuilderAPI_MakeEdge(p1, p2));
    rect.Add(BRepBuilderAPI_MakeEdge(p2, p3));
    rect.Add(BRepBuilderAPI_MakeEdge(p3, p4));
    rect.Add(BRepBuilderAPI_MakeEdge(p4, p1));
    pipe("pipeShellFixedBinormal", bspline({gp_Pnt(0, 0, 0), gp_Pnt(50, 0, 0)}), {rect.Wire()}, 2,
         nullptr, true);
  }
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
