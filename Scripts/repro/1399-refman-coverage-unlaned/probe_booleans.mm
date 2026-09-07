// #1399, booleans family: the behaviour claims no detector can see, measured against the pinned
// kernel rather than read off a header.
//
// Build (from the repo root):
//   clang++ -std=c++17 -ObjC++ -w \
//     -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
//     -L"Libraries/OCCT.xcframework/macos-arm64" \
//     -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
//     Scripts/repro/1399-refman-coverage-unlaned/probe_booleans.mm -o /tmp/occt_1399_booleans
//   /tmp/occt_1399_booleans
//
// Output is committed beside this file as probe-transcript.txt.

#include <BRepAdaptor_Surface.hxx>
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <BRep_Tool.hxx>
#include <BRepTopAdaptor_TopolTool.hxx>
#include <Contap_Contour.hxx>
#include <Contap_Line.hxx>
#include <ExtremaPC_Curve.hxx>
#include <Extrema_ExtElSS.hxx>
#include <Extrema_POnSurf.hxx>
#include <FilletSurf_StatusDone.hxx>
#include <FilletSurf_StatusType.hxx>
#include <GeomAPI.hxx>
#include <Geom_Line.hxx>
#include <Geom_TrimmedCurve.hxx>
#include <IntTools_CommonPrt.hxx>
#include <IntTools_EdgeFace.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <gp_Ax3.hxx>
#include <gp_Pln.hxx>
#include <gp_Sphere.hxx>

#include <Standard_DomainError.hxx>
#include <Standard_Failure.hxx>
#include <Standard_NotImplemented.hxx>
#include <Standard_OutOfRange.hxx>
#include <StdFail_NotDone.hxx>

#include <cmath>
#include <cstdio>
#include <string>
#include <typeinfo>

// Standard_Failure has no DynamicType(); the RTTI name is the portable way to say which one it
// was, and it is what the transcript needs to distinguish "not implemented" from "not done".
static const char* failureName(const Standard_Failure& f)
{
  return typeid(f).name();
}

static bool gProbePoints = false;

static void banner(const char* title)
{
  printf("\n=== %s\n", title);
}

// ---------------------------------------------------------------------------
// 1. Extrema_ExtElSS: which of the three wrapped pairs computes anything at all.
// ---------------------------------------------------------------------------
static void probeExtElSS()
{
  banner("Extrema_ExtElSS, the class behind ExtremaElSS.planeToPlane / planeToSphere / "
         "sphereToSphere");

  // Parallel planes, 5 apart.
  {
    gp_Pln p1(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1));
    gp_Pln p2(gp_Pnt(0, 0, 5), gp_Dir(0, 0, 1));
    try
    {
      Extrema_ExtElSS ext(p1, p2);
      printf("  plane/plane, parallel      IsDone=%d IsParallel=%d NbExt=%d sqDist=%g\n",
             (int)ext.IsDone(),
             (int)ext.IsParallel(),
             ext.NbExt(),
             ext.NbExt() > 0 ? ext.SquareDistance(1) : -1.0);
      // Perform(gp_Pln, gp_Pln) sets mySqDist but leaves myPOnS1/myPOnS2 as null handles, so
      // Points(1, ...) dereferences a null NCollection_HArray1. That is an OS fault, not a
      // catchable C++ exception, so it runs only under `--points`, which is expected to die.
      if (ext.NbExt() > 0 && gProbePoints)
      {
        printf("    calling Points(1, ...) on the parallel result...\n");
        Extrema_POnSurf a, b;
        ext.Points(1, a, b);
        printf("    Points(1) returned (%g, %g, %g) / (%g, %g, %g)\n",
               a.Value().X(),
               a.Value().Y(),
               a.Value().Z(),
               b.Value().X(),
               b.Value().Y(),
               b.Value().Z());
      }
      else if (ext.NbExt() > 0)
      {
        printf("    Points(1, ...) not called: see the note in the source, run with --points\n");
      }
    }
    catch (const Standard_Failure& f)
    {
      printf("  plane/plane, parallel      ctor THREW %s\n", failureName(f));
    }
  }

  // Crossing planes.
  {
    gp_Pln p1(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1));
    gp_Pln p2(gp_Pnt(0, 0, 0), gp_Dir(1, 0, 0));
    try
    {
      Extrema_ExtElSS ext(p1, p2);
      printf("  plane/plane, crossing      IsDone=%d IsParallel=%d NbExt=%d\n",
             (int)ext.IsDone(),
             (int)ext.IsParallel(),
             ext.NbExt());
    }
    catch (const Standard_Failure& f)
    {
      printf("  plane/plane, crossing      ctor THREW %s\n", failureName(f));
    }
  }

  // Plane and sphere.
  {
    gp_Pln    pl(gp_Pnt(0, 0, 20), gp_Dir(0, 0, 1));
    gp_Sphere sp(gp_Ax3(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 5);
    try
    {
      Extrema_ExtElSS ext(pl, sp);
      printf("  plane/sphere               IsDone=%d NbExt=%d\n", (int)ext.IsDone(), ext.NbExt());
    }
    catch (const Standard_Failure& f)
    {
      printf("  plane/sphere               ctor THREW %s\n", failureName(f));
    }
  }

  // Two spheres.
  {
    gp_Sphere s1(gp_Ax3(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 5);
    gp_Sphere s2(gp_Ax3(gp_Pnt(20, 0, 0), gp_Dir(0, 0, 1)), 5);
    try
    {
      Extrema_ExtElSS ext(s1, s2);
      printf("  sphere/sphere              IsDone=%d NbExt=%d\n", (int)ext.IsDone(), ext.NbExt());
    }
    catch (const Standard_Failure& f)
    {
      printf("  sphere/sphere              ctor THREW %s\n", failureName(f));
    }
  }
}

// ---------------------------------------------------------------------------
// 2. Contap_Line: NbPnts()/Point() are Walking-only.
// ---------------------------------------------------------------------------
static const char* contapTypeName(Contap_IType t)
{
  switch (t)
  {
    case Contap_Lin:
      return "Contap_Lin (0, .line)";
    case Contap_Circle:
      return "Contap_Circle (1, .circle)";
    case Contap_Walking:
      return "Contap_Walking (2, .walking)";
    case Contap_Restriction:
      return "Contap_Restriction (3, .restriction)";
  }
  return "?";
}

static void probeContap()
{
  banner("Contap_Line, the class behind ContapContourResult.pointCount / point / points");

  TopoDS_Shape solid = BRepPrimAPI_MakeCylinder(10.0, 30.0).Shape();
  TopExp_Explorer exp(solid, TopAbs_FACE);
  for (; exp.More(); exp.Next())
  {
    TopoDS_Face                      face = TopoDS::Face(exp.Current());
    Handle(BRepAdaptor_Surface)      surf = new BRepAdaptor_Surface(face);
    Handle(BRepTopAdaptor_TopolTool) tool = new BRepTopAdaptor_TopolTool(surf);
    Contap_Contour                   contour;
    contour.Init(gp_Vec(1, 0, 0));
    contour.Perform(surf, tool);
    if (!contour.IsDone() || contour.IsEmpty())
      continue;
    printf("  cylinder face, view direction (1,0,0): NbLines=%d\n", contour.NbLines());
    for (int i = 1; i <= contour.NbLines(); i++)
    {
      const Contap_Line& line = contour.Line(i);
      printf("    line %d  TypeContour=%s  NbVertex=%d  ", i, contapTypeName(line.TypeContour()),
             line.NbVertex());
      try
      {
        printf("NbPnts=%d\n", line.NbPnts());
      }
      catch (const Standard_Failure& f)
      {
        printf("NbPnts() THREW %s\n", failureName(f));
      }
    }
    break;
  }
}

// ---------------------------------------------------------------------------
// 3. IntTools_EdgeFace: what the second range of a common part holds.
// ---------------------------------------------------------------------------
static void reportEdgeFace(const char* label, const TopoDS_Edge& edge, const TopoDS_Face& face,
                           bool setRange)
{
  IntTools_EdgeFace ef;
  ef.SetEdge(edge);
  ef.SetFace(face);
  if (setRange)
  {
    double f = 0.0, l = 0.0;
    BRep_Tool::Range(edge, f, l);
    ef.SetRange(f, l);
  }
  ef.Perform();
  printf("  %-32s Range=(%g, %g)  IsDone=%d  CommonParts=%d\n",
         label,
         ef.Range().First(),
         ef.Range().Last(),
         (int)ef.IsDone(),
         ef.CommonParts().Length());
  for (int i = 1; i <= ef.CommonParts().Length(); i++)
  {
    const IntTools_CommonPrt& cp = ef.CommonParts()(i);
    printf("      part %d  Type=%s  Range1=(%g, %g)  Ranges2().Length()=%d  "
           "VertexParameter2()=%g\n",
           i,
           cp.Type() == TopAbs_VERTEX ? "VERTEX" : "EDGE",
           cp.Range1().First(),
           cp.Range1().Last(),
           cp.Ranges2().Length(),
           cp.VertexParameter2());
  }
}

static void probeEdgeFace()
{
  banner("IntTools_CommonPrt from IntTools_EdgeFace, the struct behind Shape.CommonPart");

  // The fixture Tests/OCCTAnalysisTests/IntToolsEdgeFaceTests.swift uses: a 10-cube's first face
  // and an edge running through it.
  TopoDS_Shape box  = BRepPrimAPI_MakeBox(10.0, 10.0, 10.0).Shape();
  TopoDS_Edge  edge = BRepBuilderAPI_MakeEdge(gp_Pnt(5, 5, -1), gp_Pnt(5, 5, 11)).Edge();
  double       f = 0.0, l = 0.0;
  BRep_Tool::Range(edge, f, l);
  printf("  the edge's own parameter range is (%g, %g)\n", f, l);

  int             index = 0;
  TopExp_Explorer fexp(box, TopAbs_FACE);
  for (; fexp.More(); fexp.Next(), index++)
  {
    TopoDS_Face face  = TopoDS::Face(fexp.Current());
    char        a[80] = {0}, b[80] = {0};
    snprintf(a, sizeof(a), "face %d, bridge (no SetRange)", index);
    snprintf(b, sizeof(b), "face %d, SetRange(0, 12)", index);
    reportEdgeFace(a, edge, face, false);
    reportEdgeFace(b, edge, face, true);
  }
  printf("  IntTools_EdgeFace::Perform feeds myRange straight to\n"
         "  IntTools_BeanFaceIntersector::SetBeanParameters, and IntTools_Range's default ctor is\n"
         "  (0, 0), so a bridge call that never calls SetRange searches a degenerate window.\n");
  printf("  IntTools_EdgeFace.cxx also never calls AppendRange2 or SetVertexParameter2, so every\n"
         "  param2Range Shape.edgeFaceIntersection reports is the default-constructed 0.\n");
}

// ---------------------------------------------------------------------------
// 4. ExtremaPC_Curve: Perform() vs PerformWithEndpoints().
// ---------------------------------------------------------------------------
static void probeExtremaPC()
{
  banner("ExtremaPC_Curve, the class behind Curve3D.extrema / minimumDistance");

  // A segment from (0,0,0) to (10,0,0), queried from a point past its far end.
  Handle(Geom_Line)        line = new Geom_Line(gp_Pnt(0, 0, 0), gp_Dir(1, 0, 0));
  Handle(Geom_TrimmedCurve) seg = new Geom_TrimmedCurve(line, 0.0, 10.0);
  gp_Pnt                    q(20, 0, 0); // 10 past the end, so the true minimum is at u = 10

  Handle(Geom_Curve) base = seg;
  ExtremaPC_Curve    ext(base);
  const ExtremaPC::Result&   r = ext.Perform(q, 1e-9);
  printf("  Perform()               IsDone=%d NbExt=%d", (int)r.IsDone(), r.NbExt());
  if (r.IsDone() && r.NbExt() > 0)
    printf(" MinSquareDistance=%g (min distance %g)", r.MinSquareDistance(),
           std::sqrt(r.MinSquareDistance()));
  printf("\n");

  const ExtremaPC::Result& re = ext.PerformWithEndpoints(q, 1e-9);
  printf("  PerformWithEndpoints()  IsDone=%d NbExt=%d", (int)re.IsDone(), re.NbExt());
  if (re.IsDone() && re.NbExt() > 0)
    printf(" MinSquareDistance=%g (min distance %g)", re.MinSquareDistance(),
           std::sqrt(re.MinSquareDistance()));
  printf("\n");
  printf("  true minimum distance from (20,0,0) to the segment [0,10] on +X is 10\n");
}

// ---------------------------------------------------------------------------
// 5. FilletSurf enum ordinals, printed rather than transcribed.
// ---------------------------------------------------------------------------
static void probeFilletSurfEnums()
{
  banner("FilletSurf_StatusDone vs FilletSurf_StatusType, the two enums the docs conflate");
  printf("  FilletSurf_StatusDone (FilletSurf_Builder::IsDone, the overall status):\n");
  printf("    IsOk=%d IsNotOk=%d IsPartial=%d\n",
         (int)FilletSurf_IsOk,
         (int)FilletSurf_IsNotOk,
         (int)FilletSurf_IsPartial);
  printf("  FilletSurf_StatusType (Start/EndSectionStatus, the per-extremity status):\n");
  printf("    TwoExtremityOnEdge=%d OneExtremityOnEdge=%d NoExtremityOnEdge=%d\n",
         (int)FilletSurf_TwoExtremityOnEdge,
         (int)FilletSurf_OneExtremityOnEdge,
         (int)FilletSurf_NoExtremityOnEdge);
}

int main(int argc, char** argv)
{
  setvbuf(stdout, nullptr, _IONBF, 0);
  for (int i = 1; i < argc; i++)
    if (std::string(argv[i]) == "--points")
      gProbePoints = true;
  printf("#1399 booleans-family probe, OCCT 8.0.1 (pinned xcframework)\n");
  probeExtElSS();
  probeContap();
  probeEdgeFace();
  probeExtremaPC();
  probeFilletSurfEnums();
  printf("\ndone\n");
  return 0;
}
