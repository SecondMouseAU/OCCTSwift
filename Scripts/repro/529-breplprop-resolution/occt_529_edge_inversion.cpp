// OCCTSwift#529, the curvature-inversion exposure on the adaptor side.
//
// #494 found that GeomLProp_CLProps::Curvature() returns RealLast() to mean "infinite curvature" at
// a cusp, on a path that never assigns the myCurvature field CentreOfCurvature() then divides by --
// so the centre comes back (nan, inf, nan) reported as a success. BRepLProp_CLProps is the same
// template, so every bridge site that inverts a curvature through it has the same exposure. This
// probe measures what the three inverting operations do on the two degeneracies, through the
// adaptor.
//
// Build:
//   L=Libraries/OCCT.xcframework/macos-arm64
//   clang++ -std=c++17 -ObjC++ -w -I"$L/Headers" -L"$L" -lOCCT-macos \
//     -framework Foundation -framework AppKit -lz -lc++ \
//     Scripts/repro/529-breplprop-resolution/occt_529_edge_inversion.cpp -o /tmp/occt_529_inv

#include <BRepAdaptor_Curve.hxx>
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepLProp_CLProps.hxx>
#include <Geom_BezierCurve.hxx>
#include <Precision.hxx>
#include <Standard_Failure.hxx>
#include <TColgp_Array1OfPnt.hxx>
#include <TopoDS_Edge.hxx>
#include <gp_Pnt.hxx>

#include <cmath>
#include <cstdio>

static TopoDS_Edge bezierEdge(double spacing)
{
  TColgp_Array1OfPnt poles(1, 4);
  poles(1) = gp_Pnt(0, 0, 0);
  poles(2) = gp_Pnt(spacing, 0, 0);
  poles(3) = gp_Pnt(1, 1, 0);
  poles(4) = gp_Pnt(2, 0, 0);
  return BRepBuilderAPI_MakeEdge(new Geom_BezierCurve(poles)).Edge();
}

static TopoDS_Edge lineEdge()
{
  return BRepBuilderAPI_MakeEdge(gp_Pnt(0, 0, 0), gp_Pnt(10, 0, 0)).Edge();
}

// What OCCTEdgeLPropCentreOfCurvature / OCCTEdgeLPropNormal do today: construct, ask, and let
// catch (...) turn any throw into the zero-initialised out-parameters.
static void report(const char* label, const TopoDS_Edge& edge, double u, double resolution)
{
  BRepAdaptor_Curve ac(edge);
  BRepLProp_CLProps props(ac, u, 2, resolution);

  const bool tangentDefined = props.IsTangentDefined();
  const double k = props.Curvature();

  std::printf("%-42s u=%-6g res=%-9g tangent=%-5s curvature=%-14.6g%s\n", label, u, resolution,
              tangentDefined ? "yes" : "no", k, k == RealLast() ? "  (RealLast sentinel)" : "");

  // Centre of curvature, as the bridge asks for it.
  try
  {
    gp_Pnt centre;
    props.CentreOfCurvature(centre);
    const bool finite = std::isfinite(centre.X()) && std::isfinite(centre.Y())
                        && std::isfinite(centre.Z());
    std::printf("%-42s   CentreOfCurvature -> (%g, %g, %g)%s\n", "", centre.X(), centre.Y(),
                centre.Z(), finite ? "" : "   <-- NOT A POINT, returned as success");
  }
  catch (const Standard_Failure& e)
  {
    std::printf("%-42s   CentreOfCurvature -> threw Standard_Failure (bridge reports (0,0,0)): %s\n",
                "", e.GetMessageString());
  }

  // Normal.
  try
  {
    gp_Dir n;
    props.Normal(n);
    std::printf("%-42s   Normal            -> (%g, %g, %g)\n", "", n.X(), n.Y(), n.Z());
  }
  catch (const Standard_Failure& e)
  {
    std::printf("%-42s   Normal            -> threw Standard_Failure (bridge reports (0,0,0)): %s\n",
                "", e.GetMessageString());
  }
}

int main()
{
  std::printf("RealLast() = %g, Precision::Confusion() = %g\n\n", RealLast(),
              Precision::Confusion());

  // The spacing sweep is the point: an *exactly* coincident pair of poles makes D1 exactly zero and
  // CentreOfCurvature throws, which the bridge's catch (...) already absorbs. A *nearly* coincident
  // pair is the dangerous one -- OCCT still answers RealLast() from Curvature(), but the division
  // that follows produces a non-point instead of throwing, and the bridge reports it as a result.
  // Which spacings land in that window is decided by the resolution, which is what #529 is about.
  std::printf("=== how a near-cusp inverts, by pole spacing and resolution (u = 0) ===\n");
  for (double spacing : {0.0, 1e-12, 1e-9, 1e-8, 3e-7, 1e-7, 1e-6, 1e-5, 1e-3})
  {
    char label[64];
    for (double res : {1e-6, Precision::Confusion()})
    {
      std::snprintf(label, sizeof(label), "Bezier poles %g apart", spacing);
      report(label, bezierEdge(spacing), 0.0, res);
    }
    std::printf("\n");
  }

  std::printf("=== the two cases that are degenerate at any resolution ===\n");
  for (double res : {1e-6, Precision::Confusion()})
  {
    report("line (no centre of curvature)", lineEdge(), 5.0, res);
    report("Bezier mid-span (well conditioned)", bezierEdge(1.0), 0.5, res);
  }
  return 0;
}
