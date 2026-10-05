// #2983: kernel ground truth for the Stress re-sweep (StressExhaustiveAPITests,
// StressBuilderLifecycleTests, StressConcurrencyTests). Each line names the test and prints what OCCT
// gives for the same input through the class the bridge function wraps, with no bridge in the path.
// Where a figure also has a closed form the line says so, so that a figure which merely agrees with
// the kernel and with nothing else cannot pass for a derivation (batch 7 pinned a bridge defect as
// correct behaviour that way).
//
// Compile line, from the repo root, against the SwiftPM-resolved pinned asset (a worktree has no
// Libraries/OCCT.xcframework):
//   clang++ -std=c++17 -ObjC++ -w \
//     -I.build/artifacts/<package>/OCCT/OCCT.xcframework/macos-arm64/Headers \
//     -L.build/artifacts/<package>/OCCT/OCCT.xcframework/macos-arm64 \
//     -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
//     Scripts/repro/2983-stress/probe.mm -o /tmp/occt_probe_2983
#include <BRepAdaptor_CompCurve.hxx>
#include <BOPAlgo_CellsBuilder.hxx>
#include <BRepAdaptor_Surface.hxx>
#include <BRepBuilderAPI_Copy.hxx>
#include <BRepPrimAPI_MakePrism.hxx>
#include <BRepBuilderAPI_Sewing.hxx>
#include <BRepAlgoAPI_Check.hxx>
#include <BRepAlgoAPI_Section.hxx>
#include <BRepBndLib.hxx>
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepBuilderAPI_MakePolygon.hxx>
#include <BRepBuilderAPI_MakeVertex.hxx>
#include <BRepBuilderAPI_MakeWire.hxx>
#include <BRepBuilderAPI_Transform.hxx>
#include <BRepCheck_Analyzer.hxx>
#include <BRepFilletAPI_MakeChamfer.hxx>
#include <BRepFilletAPI_MakeFillet.hxx>
#include <BRepGProp.hxx>
#include <BRepOffsetAPI_MakePipeShell.hxx>
#include <BRepOffsetAPI_MakeOffsetShape.hxx>
#include <BRepOffsetAPI_ThruSections.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeCone.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <BRepPrimAPI_MakeSphere.hxx>
#include <BRepPrimAPI_MakeTorus.hxx>
#include <BRepPrimAPI_MakeWedge.hxx>
#include <BRepTools.hxx>
#include <BRep_Builder.hxx>
#include <BRep_Tool.hxx>
#include <Bnd_Box.hxx>
#include <GCPnts_AbscissaPoint.hxx>
#include <GProp_GProps.hxx>
#include <Geom2dAPI_Interpolate.hxx>
#include <Geom2d_BSplineCurve.hxx>
#include <Geom2d_Circle.hxx>
#include <Geom2d_Line.hxx>
#include <GeomAPI_Interpolate.hxx>
#include <GeomAPI_ProjectPointOnCurve.hxx>
#include <GeomAdaptor_Curve.hxx>
#include <GeomLProp_CLProps.hxx>
#include <GeomLProp_SLProps.hxx>
#include <Geom_BSplineCurve.hxx>
#include <Hatch_Hatcher.hxx>
#include <Message.hxx>
#include <Message_Messenger.hxx>
#include <Message_PrinterOStream.hxx>
#include <Geom_BSplineSurface.hxx>
#include <Geom_BezierSurface.hxx>
#include <Geom_Circle.hxx>
#include <Geom_ConicalSurface.hxx>
#include <Geom_CylindricalSurface.hxx>
#include <Geom_Plane.hxx>
#include <Geom_Surface.hxx>
#include <Geom_SphericalSurface.hxx>
#include <Geom_ToroidalSurface.hxx>
#include <Precision.hxx>
#include <ShapeAnalysis_FreeBounds.hxx>
#include <ShapeAnalysis_Wire.hxx>
#include <STEPControl_Writer.hxx>
#include <ShapeUpgrade_UnifySameDomain.hxx>
#include <ShapeFix_Shape.hxx>
#include <TColStd_Array1OfInteger.hxx>
#include <TColStd_Array1OfReal.hxx>
#include <TColgp_Array1OfPnt.hxx>
#include <TColgp_Array1OfPnt2d.hxx>
#include <TColgp_Array2OfPnt.hxx>
#include <TColgp_HArray1OfPnt.hxx>
#include <TColgp_HArray1OfPnt2d.hxx>
#include <TDF_Label.hxx>
#include <TDF_LabelSequence.hxx>
#include <TDocStd_Document.hxx>
#include <TopExp.hxx>
#include <TopExp_Explorer.hxx>
#include <TopTools_HSequenceOfShape.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopTools_ListOfShape.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Compound.hxx>
#include <XCAFApp_Application.hxx>
#include <XCAFDoc_DocumentTool.hxx>
#include <XCAFDoc_ShapeTool.hxx>
#include <gp_Pln.hxx>
#include <math_Function.hxx>
#include <math_GaussSingleIntegration.hxx>
#include <cmath>
#include <cstdio>
#include <sstream>

static double vol(const TopoDS_Shape& s)
{
  GProp_GProps p;
  BRepGProp::VolumeProperties(s, p, true);
  return p.Mass();
}

static double area(const TopoDS_Shape& s)
{
  GProp_GProps p;
  BRepGProp::SurfaceProperties(s, p);
  return p.Mass();
}

static int count(const TopoDS_Shape& s, TopAbs_ShapeEnum t)
{
  TopTools_IndexedMapOfShape m;
  TopExp::MapShapes(s, t, m);
  return m.Extent();
}

static double wlen(const TopoDS_Wire& w)
{
  BRepAdaptor_CompCurve c(w);
  return GCPnts_AbscissaPoint::Length(c);
}

// The box Shape.bounds reports: BRepBndLib::Add with the triangulation allowed and the shape
// tolerance (1e-7 on a fresh primitive) folded in.
static void bbox(const char* label, const TopoDS_Shape& s)
{
  Bnd_Box b;
  BRepBndLib::Add(s, b, true);
  double x0, y0, z0, x1, y1, z1;
  b.Get(x0, y0, z0, x1, y1, z1);
  printf("%s: bounds min=(%.9g, %.9g, %.9g) max=(%.9g, %.9g, %.9g)\n", label, x0, y0, z0, x1, y1, z1);
}

// The box Shape.boundingBoxOptimal reports: BRepBndLib::AddOptimal, exact for a torus where Add is not.
static void bboxOptimal(const char* label, const TopoDS_Shape& s)
{
  Bnd_Box b;
  BRepBndLib::AddOptimal(s, b, true, false);
  double x0, y0, z0, x1, y1, z1;
  b.Get(x0, y0, z0, x1, y1, z1);
  printf("%s: optimal min=(%.9g, %.9g, %.9g) max=(%.9g, %.9g, %.9g)\n", label, x0, y0, z0, x1, y1, z1);
}

static bool has(const TopoDS_Shape& whole, const TopoDS_Shape& part)
{
  for (TopExp_Explorer e(whole, part.ShapeType()); e.More(); e.Next())
    if (e.Current().IsSame(part))
      return true;
  return false;
}

static TopoDS_Shape centredBox(double w, double h, double d)
{
  return BRepPrimAPI_MakeBox(gp_Pnt(-w / 2, -h / 2, -d / 2), w, h, d).Shape();
}

static TopoDS_Wire rect(double w, double h)
{
  BRepBuilderAPI_MakePolygon p(gp_Pnt(-w / 2, -h / 2, 0), gp_Pnt(w / 2, -h / 2, 0), gp_Pnt(w / 2, h / 2, 0),
                               gp_Pnt(-w / 2, h / 2, 0), true);
  return p.Wire();
}

static TopoDS_Wire circleWire(const gp_Pnt& c, const gp_Dir& n, double r)
{
  Handle(Geom_Circle) g = new Geom_Circle(gp_Ax2(c, n), r);
  return BRepBuilderAPI_MakeWire(BRepBuilderAPI_MakeEdge(g)).Wire();
}

class XSquared : public math_Function
{
public:
  bool Value(const double x, double& f) override
  {
    f = x * x;
    return true;
  }
};

class XCubed : public math_Function
{
public:
  bool Value(const double x, double& f) override
  {
    f = x * x * x;
    return true;
  }
};

class One : public math_Function
{
public:
  bool Value(const double, double& f) override
  {
    f = 1.0;
    return true;
  }
};

class TwoX : public math_Function
{
public:
  bool Value(const double x, double& f) override
  {
    f = 2.0 * x;
    return true;
  }
};

static void gauss(const char* label, math_Function& f, double a, double b)
{
  math_GaussSingleIntegration g(f, a, b, 10);
  printf("gaussIntegration %s over [%g, %g], 10 points: done=%d value=%.15g\n", label, a, b, g.IsDone(), g.Value());
}

static void surfacePoint(const char* label, const Handle(Geom_Surface)& s, double u, double v)
{
  gp_Pnt p = s->Value(u, v);
  printf("%s (u=%.10g, v=%.10g) = (%.12g, %.12g, %.12g)\n", label, u, v, p.X(), p.Y(), p.Z());
}

static void curvatures(const char* label, const Handle(Geom_Surface)& s, double u, double v)
{
  GeomLProp_SLProps pr(s, u, v, 2, Precision::Confusion());
  // IsCurvatureDefined() computes the curvatures; ask it first rather than rely on the unspecified
  // evaluation order of printf's arguments.
  bool   defined = pr.IsCurvatureDefined();
  double k       = pr.GaussianCurvature();
  double h       = pr.MeanCurvature();
  printf("%s (u=%g, v=%g): defined=%d gaussian=%.15g mean=%.15g\n", label, u, v, defined, k, h);
}

int main()
{
  // The STEP writer narrates every transfer to stdout in colour; the transcript is for figures.
  Message::DefaultMessenger()->RemovePrinters(STANDARD_TYPE(Message_PrinterOStream));
  printf("== Shape Factories (distinct inputs)\n");
  {
    TopoDS_Shape box = centredBox(10, 20, 30);
    printf("box 10x20x30: volume=%.10g area=%.10g (6000, 2200) faces=%d\n", vol(box), area(box), count(box, TopAbs_FACE));
    bbox("box 10x20x30", box);
    TopoDS_Shape boxAt = BRepPrimAPI_MakeBox(gp_Pnt(1, 2, 3), 10, 20, 30).Shape();
    printf("boxWithOrigin (1,2,3) 10x20x30: volume=%.10g faces=%d\n", vol(boxAt), count(boxAt, TopAbs_FACE));
    bbox("boxWithOrigin", boxAt);
    TopoDS_Shape cyl = BRepPrimAPI_MakeCylinder(5, 10).Shape();
    printf("cylinder r5 h10: volume=%.10g (250 pi = %.10g) area=%.10g (150 pi = %.10g) faces=%d\n", vol(cyl), 250 * M_PI,
           area(cyl), 150 * M_PI, count(cyl, TopAbs_FACE));
    bbox("cylinder", cyl);
    TopoDS_Shape cylAt =
      BRepPrimAPI_MakeCylinder(gp_Ax2(gp_Pnt(3, 4, 2), gp_Dir(0, 0, 1)), 5, 10).Shape();
    printf("cylinderAtPosition (3,4) z2 r5 h10: volume=%.10g faces=%d\n", vol(cylAt), count(cylAt, TopAbs_FACE));
    bbox("cylinderAtPosition", cylAt);
    TopoDS_Shape sph = BRepPrimAPI_MakeSphere(5).Shape();
    printf("sphere r5: volume=%.10g (500 pi / 3 = %.10g) area=%.10g (100 pi = %.10g) faces=%d\n", vol(sph),
           500 * M_PI / 3, area(sph), 100 * M_PI, count(sph, TopAbs_FACE));
    bbox("sphere", sph);
    TopoDS_Shape cone = BRepPrimAPI_MakeCone(5, 2, 10).Shape();
    printf("cone 5/2/10: volume=%.10g (130 pi = %.10g) area=%.10g (pi (7 sqrt(109) + 29) = %.10g) faces=%d\n", vol(cone),
           130 * M_PI, area(cone), M_PI * (7 * std::sqrt(109.0) + 29), count(cone, TopAbs_FACE));
    bbox("cone", cone);
    TopoDS_Shape tor = BRepPrimAPI_MakeTorus(10, 3).Shape();
    printf("torus 10/3: volume=%.10g (180 pi^2 = %.10g) area=%.10g (120 pi^2 = %.10g) faces=%d\n", vol(tor),
           180 * M_PI * M_PI, area(tor), 120 * M_PI * M_PI, count(tor, TopAbs_FACE));
    bbox("torus", tor);
    bboxOptimal("torus", tor);
    TopoDS_Shape wedge = BRepPrimAPI_MakeWedge(10, 20, 30, 5).Shape();
    printf("wedge 10/20/30 ltx 5: volume=%.10g (4500) area=%.10g (1350 + 30 sqrt(425) = %.10g) faces=%d\n", vol(wedge),
           area(wedge), 1350 + 30 * std::sqrt(425.0), count(wedge, TopAbs_FACE));
    bbox("wedge", wedge);
    TopoDS_Wire w = rect(10, 10);
    printf("fromWire: edges=%d vertices=%d faces=%d length=%.10g\n", count(w, TopAbs_EDGE), count(w, TopAbs_VERTEX),
           count(w, TopAbs_FACE), wlen(w));
    TopoDS_Face f = BRepBuilderAPI_MakeFace(w, true).Face();
    printf("face: area=%.10g faces=%d edges=%d\n", area(f), count(f, TopAbs_FACE), count(f, TopAbs_EDGE));
    bbox("face", f);
  }

  printf("== Shape Queries\n");
  {
    TopoDS_Shape box = centredBox(10, 10, 10);
    gp_Trsf      zero;
    zero.SetScale(gp_Pnt(0, 0, 0), 0.0);
    TopoDS_Shape collapsed = BRepBuilderAPI_Transform(box, zero, true).Shape();
    printf("isValid: box=%d sphere=%d box scaled by 0=%d faces=%d volume=%.3g\n", BRepCheck_Analyzer(box).IsValid(),
           BRepCheck_Analyzer(BRepPrimAPI_MakeSphere(5).Shape()).IsValid(), BRepCheck_Analyzer(collapsed).IsValid(),
           count(collapsed, TopAbs_FACE), vol(collapsed));
    gp_Trsf shift5, shift20;
    shift5.SetTranslation(gp_Vec(5, 0, 0));
    shift20.SetTranslation(gp_Vec(20, 0, 0));
    BRep_Builder    bb;
    TopoDS_Compound overlapping, apart;
    bb.MakeCompound(overlapping);
    bb.Add(overlapping, box);
    bb.Add(overlapping, BRepBuilderAPI_Transform(box, shift5, true).Shape());
    bb.MakeCompound(apart);
    bb.Add(apart, box);
    bb.Add(apart, BRepBuilderAPI_Transform(box, shift20, true).Shape());
    printf("isBooleanValid: box=%d overlapping compound (small edges on, self-interference on)=%d "
           "(self-interference off)=%d disjoint compound=%d\n",
           BRepAlgoAPI_Check(box, true, true).IsValid(), BRepAlgoAPI_Check(overlapping, true, true).IsValid(),
           BRepAlgoAPI_Check(overlapping, true, false).IsValid(), BRepAlgoAPI_Check(apart, true, true).IsValid());
    std::ostringstream out;
    BRepTools::Write(box, out);
    std::string text = out.str();
    printf("brepString: contains \"CASCADE Topology V3\"=%d length=%zu\n", text.find("CASCADE Topology V3") != std::string::npos,
           text.size());
    std::istringstream in(text);
    TopoDS_Shape       back;
    BRep_Builder       builder;
    BRepTools::Read(back, in, builder);
    printf("brepString round trip: valid=%d type=%d (SOLID = %d) faces=%d volume=%.10g\n", BRepCheck_Analyzer(back).IsValid(),
           (int)back.ShapeType(), (int)TopAbs_SOLID, count(back, TopAbs_FACE), vol(back));
    TopoDS_Shape       cylinder = BRepPrimAPI_MakeCylinder(5, 10).Shape();
    std::ostringstream cout2;
    BRepTools::Write(cylinder, cout2);
    std::istringstream cin2(cout2.str());
    TopoDS_Shape       cylBack;
    BRepTools::Read(cylBack, cin2, builder);
    printf("brepString cylinder: differs from the box's=%d faces=%d volume=%.10g (250 pi = %.10g)\n",
           cout2.str() != text, count(cylBack, TopAbs_FACE), vol(cylBack), 250 * M_PI);
  }

  printf("== Wire API\n");
  {
    TopoDS_Wire tilted = circleWire(gp_Pnt(1, 2, 3), gp_Dir(1, 0, 0), 5);
    printf("circle r5 at (1,2,3) normal +X: length=%.10g (10 pi = %.10g) edges=%d\n", wlen(tilted), 10 * M_PI,
           count(tilted, TopAbs_EDGE));
    bbox("circle at (1,2,3) normal +X", tilted);
    BRepBuilderAPI_MakePolygon closed(gp_Pnt(0, 0, 0), gp_Pnt(10, 0, 0), gp_Pnt(10, 10, 0), gp_Pnt(0, 10, 0), true);
    BRepBuilderAPI_MakePolygon open(gp_Pnt(0, 0, 0), gp_Pnt(10, 0, 0), gp_Pnt(10, 10, 0), gp_Pnt(0, 10, 0), false);
    printf("polygon closed: edges=%d length=%.10g; open: edges=%d length=%.10g\n", count(closed.Wire(), TopAbs_EDGE),
           wlen(closed.Wire()), count(open.Wire(), TopAbs_EDGE), wlen(open.Wire()));
    TopoDS_Wire diag = BRepBuilderAPI_MakeWire(BRepBuilderAPI_MakeEdge(gp_Pnt(1, 2, 3), gp_Pnt(4, 6, 3))).Wire();
    printf("line (1,2,3) to (4,6,3): length=%.10g edges=%d\n", wlen(diag), count(diag, TopAbs_EDGE));
    TopoDS_Wire r = rect(10, 5);
    printf("rectangle 10x5: length=%.10g edges=%d\n", wlen(r), count(r, TopAbs_EDGE));
    bbox("rectangle 10x5", r);
  }

  printf("== Curve3D API\n");
  {
    Handle(Geom_Circle) c = new Geom_Circle(gp_Ax2(gp_Pnt(1, 2, 3), gp_Dir(0, 0, 1)), 5);
    gp_Pnt              p0 = c->Value(0), p1 = c->Value(M_PI / 2), p2 = c->Value(M_PI);
    printf("circle c(1,2,3) r5: domain=[%g, %.17g] p(0)=(%g, %g, %g) p(pi/2)=(%g, %g, %g) p(pi)=(%g, %g, %g)\n",
           c->FirstParameter(), c->LastParameter(), p0.X(), p0.Y(), p0.Z(), p1.X(), p1.Y(), p1.Z(), p2.X(), p2.Y(), p2.Z());
    GeomLProp_CLProps pr(c, 0.0, 2, Precision::Confusion());
    printf("circle curvature at 0=%.17g\n", pr.Curvature());
    Handle(TColgp_HArray1OfPnt) pts = new TColgp_HArray1OfPnt(1, 3);
    pts->SetValue(1, gp_Pnt(0, 0, 0));
    pts->SetValue(2, gp_Pnt(5, 5, 0));
    pts->SetValue(3, gp_Pnt(10, 0, 0));
    GeomAPI_Interpolate gi(pts, false, 1e-6);
    gi.Perform();
    Handle(Geom_BSplineCurve) bs = gi.Curve();
    gp_Pnt                    s = bs->StartPoint(), e = bs->EndPoint();
    GeomAPI_ProjectPointOnCurve proj(gp_Pnt(5, 5, 0), bs);
    printf("interpolate (0,0,0) (5,5,0) (10,0,0): domain=[%g, %.12g] (10 sqrt(2) = %.12g) start=(%g, %g, %g) end=(%g, %g, %g) "
           "degree=%d poles=%d; middle point at parameter %.12g (5 sqrt(2) = %.12g) distance %.3g\n",
           bs->FirstParameter(), bs->LastParameter(), 10 * std::sqrt(2.0), s.X(), s.Y(), s.Z(), e.X(), e.Y(), e.Z(),
           bs->Degree(), bs->NbPoles(), proj.LowerDistanceParameter(), 5 * std::sqrt(2.0), proj.LowerDistance());
    printf("interpolate continuity=%d (CN = %d) IsCN(2)=%d\n", (int)bs->Continuity(), (int)GeomAbs_CN, bs->IsCN(2));
    TColgp_Array1OfPnt poles(1, 3);
    poles(1) = gp_Pnt(0, 0, 0);
    poles(2) = gp_Pnt(5, 5, 0);
    poles(3) = gp_Pnt(10, 0, 0);
    TColStd_Array1OfReal knots(1, 3);
    knots(1) = 0;
    knots(2) = 1;
    knots(3) = 2;
    TColStd_Array1OfInteger mults(1, 3);
    mults(1) = 2;
    mults(2) = 1;
    mults(3) = 2;
    Handle(Geom_BSplineCurve) corner = new Geom_BSplineCurve(poles, knots, mults, 1);
    printf("degree-1 polyline B-spline: continuity=%d (C0 = %d) IsCN(0)=%d IsCN(1)=%d\n", (int)corner->Continuity(),
           (int)GeomAbs_C0, corner->IsCN(0), corner->IsCN(1));
    Handle(Geom_Circle) c5 = new Geom_Circle(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 5);
    GeomAdaptor_Curve   ga(c5);
    printf("arcLength r5: (0, pi)=%.15g (5 pi = %.15g) (0, 2pi)=%.15g (10 pi = %.15g) (pi/2, pi)=%.15g (2.5 pi = %.15g)\n",
           GCPnts_AbscissaPoint::Length(ga, 0, M_PI), 5 * M_PI, GCPnts_AbscissaPoint::Length(ga, 0, 2 * M_PI), 10 * M_PI,
           GCPnts_AbscissaPoint::Length(ga, M_PI / 2, M_PI), 2.5 * M_PI);
  }

  printf("== Curve2D API\n");
  {
    Handle(Geom2d_Circle) c = new Geom2d_Circle(gp_Ax2d(gp_Pnt2d(1, 2), gp_Dir2d(1, 0)), 5);
    gp_Pnt2d              p0 = c->Value(0), p1 = c->Value(M_PI / 2);
    printf("circle c(1,2) r5: domain=[%g, %.17g] p(0)=(%g, %g) p(pi/2)=(%g, %g)\n", c->FirstParameter(), c->LastParameter(),
           p0.X(), p0.Y(), p1.X(), p1.Y());
    Handle(Geom2d_Line) l1 = new Geom2d_Line(gp_Pnt2d(0, 0), gp_Dir2d(1, 1));
    Handle(Geom2d_Line) l2 = new Geom2d_Line(gp_Pnt2d(3, 4), gp_Dir2d(0, 2));
    gp_Pnt2d            a = l1->Value(1), b = l1->Value(2), c0 = l2->Value(0), c5 = l2->Value(5);
    printf("line (0,0)+(1,1): p(1)=(%.15g, %.15g) p(2)=(%.15g, %.15g); line (3,4)+(0,2): p(0)=(%g, %g) p(5)=(%g, %g)\n",
           a.X(), a.Y(), b.X(), b.Y(), c0.X(), c0.Y(), c5.X(), c5.Y());
    Handle(TColgp_HArray1OfPnt2d) pts = new TColgp_HArray1OfPnt2d(1, 3);
    pts->SetValue(1, gp_Pnt2d(0, 0));
    pts->SetValue(2, gp_Pnt2d(5, 5));
    pts->SetValue(3, gp_Pnt2d(10, 0));
    Geom2dAPI_Interpolate gi(pts, false, 1e-6);
    gi.Perform();
    Handle(Geom2d_BSplineCurve) bs  = gi.Curve();
    double                      mid = 5 * std::sqrt(2.0);
    gp_Pnt2d                    pm  = bs->Value(mid);
    printf("interpolate (0,0) (5,5) (10,0): domain=[%g, %.12g] start=(%g, %g) end=(%g, %g) point at 5 sqrt(2)=(%.12g, %.12g)\n",
           bs->FirstParameter(), bs->LastParameter(), bs->StartPoint().X(), bs->StartPoint().Y(), bs->EndPoint().X(),
           bs->EndPoint().Y(), pm.X(), pm.Y());
    TColgp_Array1OfPnt2d poles(1, 3);
    poles(1) = gp_Pnt2d(0, 0);
    poles(2) = gp_Pnt2d(5, 5);
    poles(3) = gp_Pnt2d(10, 0);
    TColStd_Array1OfReal knots(1, 3);
    knots(1) = 0;
    knots(2) = 1;
    knots(3) = 2;
    TColStd_Array1OfInteger mults(1, 3);
    mults(1) = 2;
    mults(2) = 1;
    mults(3) = 2;
    Handle(Geom2d_BSplineCurve) corner = new Geom2d_BSplineCurve(poles, knots, mults, 1);
    printf("2D degree-1 polyline B-spline: continuity=%d (C0 = %d); circle continuity=%d (CN = %d)\n", (int)corner->Continuity(),
           (int)GeomAbs_C0, (int)c->Continuity(), (int)GeomAbs_CN);
  }

  printf("== Surface API\n");
  {
    gp_Ax3 ax(gp_Pnt(1, 2, 3), gp_Dir(0, 0, 1));
    Handle(Geom_Surface) plane = new Geom_Plane(gp_Pln(gp_Pnt(1, 2, 3), gp_Dir(0, 0, 1)));
    surfacePoint("plane o(1,2,3) n=+Z", plane, 3, 4);
    Handle(Geom_Surface) cyl = new Geom_CylindricalSurface(ax, 5);
    surfacePoint("cylinder r5", cyl, 0, 7);
    surfacePoint("cylinder r5", cyl, M_PI / 2, 0);
    Handle(Geom_Surface) sph = new Geom_SphericalSurface(ax, 5);
    surfacePoint("sphere r5", sph, 0, 0);
    surfacePoint("sphere r5", sph, 0, M_PI / 2);
    surfacePoint("sphere r5", sph, M_PI / 2, 0);
    Handle(Geom_Surface) cone = new Geom_ConicalSurface(ax, M_PI / 6, 5);
    surfacePoint("cone r5 semiAngle pi/6", cone, 0, 0);
    surfacePoint("cone r5 semiAngle pi/6", cone, 0, 10);
    surfacePoint("cone r5 semiAngle pi/6", cone, M_PI / 2, 10);
    printf("cone: closed form (x, z) at v=10: x = 1 + 5 + 10 sin(pi/6) = %.12g, z = 3 + 10 cos(pi/6) = %.12g\n",
           6 + 10 * std::sin(M_PI / 6), 3 + 10 * std::cos(M_PI / 6));
    Handle(Geom_Surface) tor = new Geom_ToroidalSurface(ax, 10, 3);
    surfacePoint("torus 10/3", tor, 0, 0);
    surfacePoint("torus 10/3", tor, 0, M_PI / 2);
    surfacePoint("torus 10/3", tor, 0, M_PI);
    surfacePoint("torus 10/3", tor, M_PI / 2, 0);

    gp_Ax3 origin(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1));
    curvatures("sphere r10", new Geom_SphericalSurface(origin, 10), 1.0, 0.5);
    curvatures("sphere r10", new Geom_SphericalSurface(origin, 10), 4.0, -1.0);
    curvatures("sphere r5", new Geom_SphericalSurface(origin, 5), 1.0, 0.5);
    curvatures("cylinder r5", new Geom_CylindricalSurface(origin, 5), 1.0, 0.5);
    curvatures("plane", new Geom_Plane(gp_Pln(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1))), 1.0, 0.5);

    TColgp_Array2OfPnt poles(1, 3, 1, 2);
    double             z[3] = {0, 1, 0};
    for (int i = 0; i < 3; ++i)
      for (int j = 0; j < 2; ++j)
        poles(i + 1, j + 1) = gp_Pnt(i, j, z[i]);
    TColStd_Array1OfReal uk(1, 3);
    uk(1) = 0;
    uk(2) = 1;
    uk(3) = 2;
    TColStd_Array1OfReal vk(1, 2);
    vk(1) = 0;
    vk(2) = 1;
    TColStd_Array1OfInteger um(1, 3);
    um(1) = 2;
    um(2) = 1;
    um(3) = 2;
    TColStd_Array1OfInteger vm(1, 2);
    vm(1) = 2;
    vm(2) = 2;
    Handle(Geom_BSplineSurface) roof = new Geom_BSplineSurface(poles, uk, vk, um, vm, 1, 1);
    printf("roof (degree 1, interior u knot): IsCNu(0)=%d IsCNu(1)=%d IsCNv(2)=%d; plane: IsCNu(2)=%d IsCNv(2)=%d continuity=%d (CN = %d)\n",
           roof->IsCNu(0), roof->IsCNu(1), roof->IsCNv(2), plane->IsCNu(2), plane->IsCNv(2), (int)plane->Continuity(),
           (int)GeomAbs_CN);
  }

  printf("== Document API\n");
  {
    Handle(XCAFApp_Application) app = XCAFApp_Application::GetApplication();
    Handle(TDocStd_Document)    doc;
    app->NewDocument("MDTV-XCAF", doc);
    Handle(XCAFDoc_ShapeTool) st = XCAFDoc_DocumentTool::ShapeTool(doc->Main());
    TDF_LabelSequence         all, free;
    st->GetShapes(all);
    st->GetFreeShapes(free);
    printf("new document: shapes=%d free=%d\n", all.Length(), free.Length());
    TopoDS_Shape box = centredBox(10, 10, 10), sphere = BRepPrimAPI_MakeSphere(5).Shape();
    TDF_Label    lb  = st->AddShape(box, false);
    TDF_Label    ls  = st->AddShape(sphere, false);
    all.Clear();
    free.Clear();
    st->GetShapes(all);
    st->GetFreeShapes(free);
    TDF_Label foundBox, foundSphere, foundOther;
    bool      fb = st->FindShape(box, foundBox), fs = st->FindShape(sphere, foundSphere);
    bool      fo = st->FindShape(centredBox(10, 10, 10), foundOther);
    printf("two shapes added: shapes=%d free=%d; labels distinct=%d; find(box)=%d is its label=%d; find(sphere)=%d is its "
           "label=%d; find(an unadded box)=%d\n",
           all.Length(), free.Length(), !lb.IsEqual(ls), fb, fb && foundBox.IsEqual(lb), fs, fs && foundSphere.IsEqual(ls), fo);
  }

  printf("== Math\n");
  {
    XSquared sq;
    XCubed   cu;
    One      one;
    TwoX     tx;
    gauss("x^2", sq, 0, 1);
    gauss("x^3", cu, 0, 2);
    gauss("1", one, 0, 1);
    gauss("2x", tx, 1, 3);
  }

  printf("== Builder lifecycle\n");
  {
    TopoDS_Shape box = centredBox(10, 10, 10);
    // ChamferBuilder: edge 0 of the first face that takes it, two distances.
    {
      TopTools_IndexedMapOfShape edges, faces;
      TopExp::MapShapes(box, TopAbs_EDGE, edges);
      TopExp::MapShapes(box, TopAbs_FACE, faces);
      TopoDS_Edge edge = TopoDS::Edge(edges(1));
      BRepFilletAPI_MakeChamfer mc(box);
      bool                      added = false;
      for (int i = 1; i <= faces.Extent() && !added; ++i)
        if (has(faces(i), edge))
        {
          mc.Add(1.0, 2.0, edge, TopoDS::Face(faces(i)));
          added = true;
        }
      mc.Build();
      printf("chamfer two distances (1, 2) on one 10-long edge: done=%d volume=%.10g (1000 - 0.5*1*2*10 = 990) contours=%d "
             "symmetric=%d twoDistances=%d\n",
             mc.IsDone(), vol(mc.Shape()), mc.NbContours(), mc.IsSymetric(1), mc.IsTwoDistances(1));
    }
    // FilletBuilder: a ramp, 1 at one end and 2 at the other.
    {
      TopTools_IndexedMapOfShape edges;
      TopExp::MapShapes(box, TopAbs_EDGE, edges);
      BRepFilletAPI_MakeFillet mf(box);
      mf.Add(1.0, 2.0, TopoDS::Edge(edges(1)));
      mf.Build();
      printf("fillet ramp radius 1 to 2: done=%d contours=%d constant=%d\n", mf.IsDone(), mf.NbContours(), mf.IsConstant(1));
    }
    // PipeShell readiness.
    {
      TopoDS_Wire                spine   = circleWire(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1), 10);
      TopoDS_Wire                profile = circleWire(gp_Pnt(10, 0, 0), gp_Dir(0, 1, 0), 2);
      BRepOffsetAPI_MakePipeShell ps(spine);
      printf("pipe shell before a profile: ready=%d; ", ps.IsReady());
      ps.Add(profile);
      printf("after: ready=%d\n", ps.IsReady());
    }
    // ShapeFix_Shape status before and after Perform on a clean box.
    {
      ShapeFix_Shape sf(box);
      printf("shape fixer before perform: OK=%d DONE=%d; ", sf.Status(ShapeExtend_OK), sf.Status(ShapeExtend_DONE));
      bool fixed = sf.Perform();
      printf("after perform: returned %d OK=%d DONE=%d faces=%d\n", fixed, sf.Status(ShapeExtend_OK),
             sf.Status(ShapeExtend_DONE), count(sf.Shape(), TopAbs_FACE));
    }
    // ShapeAnalysis_Wire controls, against the box's upward face.
    {
      TopoDS_Face up;
      for (TopExp_Explorer e(box, TopAbs_FACE); e.More(); e.Next())
      {
        BRepAdaptor_Surface s(TopoDS::Face(e.Current()));
        gp_Pnt              p;
        gp_Vec              du, dv;
        s.D1((s.FirstUParameter() + s.LastUParameter()) / 2, (s.FirstVParameter() + s.LastVParameter()) / 2, p, du, dv);
        gp_Vec n = du.Crossed(dv);
        if (TopoDS::Face(e.Current()).Orientation() == TopAbs_REVERSED)
          n.Reverse();
        if (n.Z() > 0.5)
          up = TopoDS::Face(e.Current());
      }
      BRepBuilderAPI_MakePolygon bow(gp_Pnt(-5, -5, 0), gp_Pnt(5, 5, 0), gp_Pnt(5, -5, 0), gp_Pnt(-5, 5, 0), true);
      BRepBuilderAPI_MakePolygon gap(gp_Pnt(-5, -5, 0), gp_Pnt(5, -5, 0), gp_Pnt(5, 5, 0), gp_Pnt(-5, 5, 0), false);
      BRepBuilderAPI_MakePolygon sq(gp_Pnt(-5, -5, 0), gp_Pnt(5, -5, 0), gp_Pnt(5, 5, 0), gp_Pnt(-5, 5, 0), true);
      // Perform ORs CheckOrder, CheckSmall, CheckConnected, CheckEdgeCurves, CheckDegenerated,
      // CheckSelfIntersection, CheckLacking and CheckClosed (ShapeAnalysis_Wire.cxx). It answers 1 for
      // every wire here, because CheckEdgeCurves answers 1 for every one of them, so the answer says
      // that Perform was reached and says nothing about the wire's health.
      auto report = [](const char* name, const TopoDS_Wire& w, const TopoDS_Face& f) {
        Handle(ShapeAnalysis_Wire) a         = new ShapeAnalysis_Wire(w, f, 1e-7);
        bool                       performed = a->Perform();
        bool                       self      = a->CheckSelfIntersection();
        bool                       closed    = a->CheckClosed();
        bool                       order     = a->CheckOrder();
        bool                       gap3d     = a->CheckGap3d(1);
        bool                       gap2d     = a->CheckGap2d(1);
        bool                       curves    = a->CheckEdgeCurves();
        printf("ShapeAnalysis_Wire %s: perform=%d edgeCurves=%d edges=%d selfIntersection=%d closed=%d order=%d gap3d(1)=%d gap2d(1)=%d\n",
               name, performed, curves, a->NbEdges(), self, closed, order, gap3d, gap2d);
      };
      for (int k = 0; k < 3; ++k)
      {
        const char*        name = k == 0 ? "clean square" : (k == 1 ? "bowtie" : "open polygon");
        const TopoDS_Wire& w    = k == 0 ? sq.Wire() : (k == 1 ? bow.Wire() : gap.Wire());
        report(name, w, up);
      }
      // The section wire the lifecycle test analyses: the box cut at z = 0 (the bridge's
      // OCCTShapeSectionWiresAtZ: BRepAlgoAPI_Section, then ConnectEdgesToWires at 1e-6) against the
      // box's first face, which it does not lie on.
      {
        BRepAlgoAPI_Section               section(box, gp_Pln(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)));
        Handle(TopTools_HSequenceOfShape) edges = new TopTools_HSequenceOfShape;
        for (TopExp_Explorer e(section.Shape(), TopAbs_EDGE); e.More(); e.Next())
          edges->Append(e.Current());
        Handle(TopTools_HSequenceOfShape) wires = new TopTools_HSequenceOfShape;
        ShapeAnalysis_FreeBounds::ConnectEdgesToWires(edges, 1e-6, false, wires);
        TopExp_Explorer firstFace(box, TopAbs_FACE);
        printf("section wires at z=0: %d\n", wires->Length());
        report("section wire at z=0 on the box's first face", TopoDS::Wire(wires->Value(1)),
               TopoDS::Face(firstFace.Current()));
      }
    }
    // The release-only builders: what each holds before it is let go.
    {
      Hatch_Hatcher h(1e-6);
      h.AddXLine(1);
      h.AddYLine(2);
      printf("hatcher after an X and a Y line: NbLines=%d\n", h.NbLines());
      BRepBuilderAPI_Sewing sw(1e-6);
      sw.Add(box);
      printf("sewing after Add, before Perform: SewedShape null=%d; ", sw.SewedShape().IsNull());
      sw.Perform();
      printf("after Perform: null=%d faces=%d\n", sw.SewedShape().IsNull(), count(sw.SewedShape(), TopAbs_FACE));
      TopTools_IndexedMapOfShape edges;
      TopExp::MapShapes(box, TopAbs_EDGE, edges);
      BRepBuilderAPI_MakeWire mw;
      printf("empty MakeWire: IsDone=%d; ", mw.IsDone());
      mw.Add(TopoDS::Edge(edges(1)));
      printf("after one edge: IsDone=%d edges=%d\n", mw.IsDone(), count(mw.Wire(), TopAbs_EDGE));
      BOPAlgo_CellsBuilder cb;
      TopTools_ListOfShape args;
      args.Append(box);
      args.Append(BRepPrimAPI_MakeSphere(5).Shape());
      cb.SetArguments(args);
      cb.Perform();
      printf("cells builder, box and its inscribed sphere: GetAllParts solids=%d volume=%.10g\n",
             count(cb.GetAllParts(), TopAbs_SOLID), vol(cb.GetAllParts()));
    }
    // ThruSections: the apex loft, and the stale binding.
    {
      TopoDS_Vertex apex = BRepBuilderAPI_MakeVertex(gp_Pnt(0, 0, 0));
      TopoDS_Wire    w1  = circleWire(gp_Pnt(0, 0, 10), gp_Dir(0, 0, 1), 4);
      TopoDS_Wire    w2  = circleWire(gp_Pnt(0, 0, 20), gp_Dir(0, 0, 1), 3);
      BRepOffsetAPI_ThruSections ts(true, false, 1e-6);
      ts.CheckCompatibility(false);
      ts.AddVertex(apex);
      ts.AddWire(w1);
      ts.AddWire(w2);
      ts.Build();
      Bnd_Box b;
      BRepBndLib::Add(ts.Shape(), b, true);
      double x0, y0, z0, x1, y1, z1;
      b.Get(x0, y0, z0, x1, y1, z1);
      printf("apex loft (apex, r4 at z10, r3 at z20, smoothed): done=%d valid=%d solids=%d volume=%.9f z=[%.9g, %.9g]\n",
             ts.IsDone(), BRepCheck_Analyzer(ts.Shape()).IsValid(), count(ts.Shape(), TopAbs_SOLID), vol(ts.Shape()), z0, z1);
    }
    {
      TopoDS_Wire s1 = circleWire(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1), 5);
      TopoDS_Wire s2 = circleWire(gp_Pnt(0, 0, 10), gp_Dir(0, 0, 1), 3);
      TopoDS_Wire s3 = circleWire(gp_Pnt(0, 0, 20), gp_Dir(0, 0, 1), 2);
      BRepOffsetAPI_ThruSections ts(true, false, 1e-6);
      ts.AddWire(s1);
      ts.AddWire(s2);
      ts.AddWire(s3);
      ts.Build();
      TopExp_Explorer ex(s1, TopAbs_EDGE);
      TopoDS_Shape    edge = ex.Current();
      TopoDS_Shape    first = ts.GeneratedFace(edge);
      printf("stale binding, build A (3 circles): done=%d faces=%d GeneratedFace(first edge) null=%d member=%d\n", ts.IsDone(),
             count(ts.Shape(), TopAbs_FACE), first.IsNull(), !first.IsNull() && has(ts.Shape(), first));
      ts.CheckCompatibility(false);
      BRepBuilderAPI_MakePolygon tri(gp_Pnt(2, 0, 30), gp_Pnt(-1, 1.7320508, 30), gp_Pnt(-1, -1.7320508, 30), true);
      ts.AddWire(tri.Wire());
      ts.Build();
      printf("build B (a triangle section, checkCompatibility(false)): done=%d status=%d (Done = %d)\n", ts.IsDone(),
             (int)ts.GetStatus(), (int)BRepFill_ThruSectionErrorStatus_Done);
      ts.CheckCompatibility(true);
      ts.Build();
      TopoDS_Shape stale = ts.GeneratedFace(edge);
      printf("build C (checkCompatibility(true)): done=%d faces=%d valid=%d GeneratedFace(first edge) null=%d member of the new "
             "shape=%d\n",
             ts.IsDone(), count(ts.Shape(), TopAbs_FACE), BRepCheck_Analyzer(ts.Shape()).IsValid(), stale.IsNull(),
             !stale.IsNull() && has(ts.Shape(), stale));
    }
  }

  printf("== Further pins: extrude, mirror, patterns, face kinds, shape tool, STEP, unify, Bezier grid\n");
  {
    TopoDS_Face   square = BRepBuilderAPI_MakeFace(rect(10, 10), true).Face();
    TopoDS_Shape  prism  = BRepPrimAPI_MakePrism(square, gp_Vec(0, 0, 10)).Shape();
    printf("extrude square +Z length 10: volume=%.10g\n", vol(prism));
    bbox("extrude +Z", prism);
    TopoDS_Shape down = BRepPrimAPI_MakePrism(square, gp_Vec(0, 0, -10)).Shape();
    bbox("extrude -Z", down);

    TopoDS_Shape offsetBox = BRepPrimAPI_MakeBox(gp_Pnt(2, 3, 4), 10, 10, 10).Shape();
    gp_Trsf      m0, m1;
    m0.SetMirror(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(1, 0, 0)));
    m1.SetMirror(gp_Ax2(gp_Pnt(1, 0, 0), gp_Dir(1, 0, 0)));
    printf("mirror of the box (2,3,4)-(12,13,14): volume=%.10g\n", vol(BRepBuilderAPI_Transform(offsetBox, m0, true).Shape()));
    bbox("mirror across x=0", BRepBuilderAPI_Transform(offsetBox, m0, true).Shape());
    bbox("mirror across x=1", BRepBuilderAPI_Transform(offsetBox, m1, true).Shape());

    // The rotate and scale tests: the box (2,1,3) 4 x 3 x 2 is [2,6] x [1,4] x [3,5]. A quarter turn
    // about +Z sends (x, y, z) to (-y, x, z), closed form [-4,-1] x [2,6] x [3,5]; doubling about
    // the origin gives [4,12] x [2,8] x [6,10].
    TopoDS_Shape turnBox = BRepPrimAPI_MakeBox(gp_Pnt(2, 1, 3), 4, 3, 2).Shape();
    gp_Trsf      quarter, doubled;
    quarter.SetRotation(gp_Ax1(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), M_PI / 2);
    doubled.SetScale(gp_Pnt(0, 0, 0), 2.0);
    bbox("quarter turn about +Z of the box (2,1,3) 4 x 3 x 2", BRepBuilderAPI_Transform(turnBox, quarter, true).Shape());
    bbox("the same box doubled about the origin", BRepBuilderAPI_Transform(turnBox, doubled, true).Shape());

    TopoDS_Shape small = BRepPrimAPI_MakeBox(gp_Pnt(10, -1, -1), 2, 2, 2).Shape();
    BRep_Builder    pb;
    TopoDS_Compound circular, linear;
    pb.MakeCompound(circular);
    for (int k = 0; k < 4; ++k)
    {
      gp_Trsf r;
      r.SetRotation(gp_Ax1(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), k * M_PI / 2);
      pb.Add(circular, BRepBuilderAPI_Transform(small, r, true).Shape());
    }
    printf("circular pattern x4 of a 2-cube at (11,0,0): solids=%d volume=%.10g\n", count(circular, TopAbs_SOLID), vol(circular));
    bbox("circular pattern", circular);
    pb.MakeCompound(linear);
    for (int k = 0; k < 3; ++k)
    {
      gp_Trsf t;
      t.SetTranslation(gp_Vec(15 * k, 0, 0));
      pb.Add(linear, BRepBuilderAPI_Transform(centredBox(10, 10, 10), t, true).Shape());
    }
    printf("linear pattern x3, spacing 15, of the 10 box: solids=%d volume=%.10g\n", count(linear, TopAbs_SOLID), vol(linear));
    bbox("linear pattern", linear);

    auto kinds = [](const char* label, const TopoDS_Shape& s) {
      printf("face kinds of %s (GeomAbs_SurfaceType: plane 0, cylinder 1, cone 2, sphere 3, torus 4):", label);
      for (TopExp_Explorer e(s, TopAbs_FACE); e.More(); e.Next())
        printf(" %d", (int)BRepAdaptor_Surface(TopoDS::Face(e.Current())).GetType());
      printf("\n");
    };
    kinds("cylinder", BRepPrimAPI_MakeCylinder(5, 10).Shape());
    kinds("cone", BRepPrimAPI_MakeCone(5, 2, 10).Shape());
    kinds("sphere", BRepPrimAPI_MakeSphere(5).Shape());
    kinds("torus", BRepPrimAPI_MakeTorus(10, 3).Shape());
    kinds("box", centredBox(10, 10, 10));

    // XCAFDoc_ShapeTool: a box is free and simple; as the component of an assembly the instance is a
    // component and not simple, and the box is no longer free.
    Handle(XCAFApp_Application) app = XCAFApp_Application::GetApplication();
    Handle(TDocStd_Document)    doc;
    app->NewDocument("MDTV-XCAF", doc);
    Handle(XCAFDoc_ShapeTool) st = XCAFDoc_DocumentTool::ShapeTool(doc->Main());
    TDF_Label                 box = st->AddShape(centredBox(10, 10, 10), false);
    printf("shape tool, a top-level box: free=%d simple=%d component=%d\n", st->IsFree(box), st->IsSimpleShape(box),
           st->IsComponent(box));
    TDF_Label assembly = st->NewShape();
    TDF_Label instance = st->AddComponent(assembly, box, TopLoc_Location());
    printf("after AddComponent: instance component=%d simple=%d; the box free=%d\n", st->IsComponent(instance),
           st->IsSimpleShape(instance), st->IsFree(box));

    // STEP: the writer's file for the box holds one manifold solid of six advanced faces. This is
    // STEPControl_Writer, not the XCAF writer the bridge drives, but both go through the same
    // translators and the face count is theirs.
    auto stepFacts = [](const char* label, const TopoDS_Shape& s) {
      const char*       path = "/tmp/occt_2983_probe.step";
      STEPControl_Writer w;
      w.Transfer(s, STEPControl_AsIs);
      w.Write(path);
      FILE*       f = fopen(path, "rb");
      std::string text;
      char        buf[4096];
      size_t      n;
      while (f && (n = fread(buf, 1, sizeof buf, f)) > 0)
        text.append(buf, n);
      if (f)
        fclose(f);
      remove(path);
      auto occurrences = [&](const char* needle) {
        int c = 0;
        for (size_t at = text.find(needle); at != std::string::npos; at = text.find(needle, at + 1))
          ++c;
        return c;
      };
      printf("STEP of %s: header ISO-10303-21=%d manifold solid=%d advanced faces=%d spherical surface=%d\n", label,
             text.rfind("ISO-10303-21;", 0) == 0, occurrences("MANIFOLD_SOLID_BREP") > 0, occurrences("ADVANCED_FACE("),
             occurrences("SPHERICAL_SURFACE") > 0);
    };
    stepFacts("the box", centredBox(10, 10, 10));
    stepFacts("the sphere", BRepPrimAPI_MakeSphere(5).Shape());

    // ShapeUpgrade_UnifySameDomain before Build(): its Shape() is its input, here a private copy.
    BRepBuilderAPI_Copy             copy(centredBox(10, 10, 10), true);
    ShapeUpgrade_UnifySameDomain usd(copy.Shape(), true, true, false);
    printf("unify before Build: faces=%d volume=%.10g\n", count(usd.Shape(), TopAbs_FACE), vol(usd.Shape()));

    // The Bezier patch the concurrency test evaluates, at its 4 x 4 grid of (u, v).
    TColgp_Array2OfPnt poles(1, 4, 1, 4);
    double             zs[4][4] = {{0, 0, 0, 0}, {0, 2, 2, 0}, {0, 2, 2, 0}, {0, 0, 0, 0}};
    for (int i = 0; i < 4; ++i)
      for (int j = 0; j < 4; ++j)
        poles(i + 1, j + 1) = gp_Pnt(5.0 * j, 5.0 * i, zs[i][j]);
    Handle(Geom_BezierSurface) patch = new Geom_BezierSurface(poles);
    double                     sx = 0, sy = 0, sz = 0;
    int                        mismatches = 0;
    for (int ui = 0; ui < 4; ++ui)
      for (int vi = 0; vi < 4; ++vi)
      {
        double u = ui / 3.0, v = vi / 3.0;
        gp_Pnt p = patch->Value(u, v);
        sx += p.X();
        sy += p.Y();
        sz += p.Z();
        double z = 18 * u * (1 - u) * v * (1 - v);
        if (std::fabs(p.X() - 15 * v) > 1e-12 || std::fabs(p.Y() - 15 * u) > 1e-12 || std::fabs(p.Z() - z) > 1e-12)
          ++mismatches;
      }
    printf("Bezier patch over the 4x4 grid: sum=(%.12g, %.12g, %.12g) (120, 120, 32/9 = %.12g); points off x = 15 v, y = 15 u, "
           "z = 18 u(1-u) v(1-v) by more than 1e-12: %d\n",
           sx, sy, sz, 32.0 / 9.0, mismatches);
  }

  // The Kilo WARNING on StressExhaustiveAPITests.offset: the test's comment says "a 12-wide box" and
  // its assertion says volume 1200. What does the bridge's call, PerformBySimple on a 10 box by 1.0,
  // actually produce? Shape.box(width:height:depth:) is centred on the origin, so the same here.
  printf("== OffsetShape::PerformBySimple on the centred 10 box (offset(by:))\n");
  {
    TopoDS_Shape centred = BRepPrimAPI_MakeBox(gp_Pnt(-5, -5, -5), 10, 10, 10).Shape();
    for (double d : {1.0, 2.0, -1.0}) {
      BRepOffsetAPI_MakeOffsetShape off;
      off.PerformBySimple(centred, d);
      if (!off.IsDone()) { printf("offset %+g: not done\n", d); continue; }
      TopoDS_Shape r = off.Shape();
      printf("offset %+g: volume=%.10g area=%.10g faces=%d (a cube of side %g would be %.10g)\n",
             d, vol(r), area(r), count(r, TopAbs_FACE), 10 + 2 * d, std::pow(10 + 2 * d, 3));
      bbox(d == 1.0 ? "offset +1" : d == 2.0 ? "offset +2" : "offset -1", r);
    }
  }
  return 0;
}
