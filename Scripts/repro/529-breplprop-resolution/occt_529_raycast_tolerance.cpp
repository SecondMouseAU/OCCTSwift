// OCCTSwift#529 — the one BRepLProp site that does not hardcode a resolution, and what it takes
// instead.
//
// OCCTShapeRaycast (Sources/OCCTBridge/src/OCCTBridge_Spatial.mm) forwards its `tolerance`
// parameter twice: to IntCurvesFace_ShapeIntersector::Load, where it is the intersection tolerance
// it is documented as, and to BRepLProp_SLProps, where it becomes the Resolution -- the sine
// tolerance CSLib::Normal tests the two parametric directions for parallelism with. Those are
// different quantities, and Shape.raycast's default is 0.001, four decades looser than the
// Precision::Confusion() every other local-property site uses.
//
// The consequence is not a rounding difference. A sine tolerance is dimensionless and capped: once
// the caller passes a value >= 1, `aSin2 < theSinTol * theSinTol` is true for every possible pair
// of derivatives, so *every* hit reports an undefined normal and RayHit.normal falls back to
// (0, 0, 1) -- a plausible-looking unit vector, pointing up, for every face of every shape.
//
// Build:
//   L=Libraries/OCCT.xcframework/macos-arm64
//   clang++ -std=c++17 -ObjC++ -w -I"$L/Headers" -L"$L" -lOCCT-macos \
//     -framework Foundation -framework AppKit -lz -lc++ \
//     Scripts/repro/529-breplprop-resolution/occt_529_raycast_tolerance.cpp -o /tmp/occt_529_ray

#include <BRepAdaptor_Surface.hxx>
#include <BRepLProp_SLProps.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeSphere.hxx>
#include <IntCurvesFace_ShapeIntersector.hxx>
#include <Precision.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Face.hxx>
#include <TopoDS_Shape.hxx>
#include <gp_Dir.hxx>
#include <gp_Lin.hxx>
#include <gp_Pnt.hxx>

#include <cstdio>

// OCCTShapeRaycast's normal, as it stands today: the caller's intersection tolerance doubles as the
// local-property resolution. `resolution` is passed separately here so the same hit can be read
// both ways.
static void castRay(const char* label, const TopoDS_Shape& shape, const gp_Lin& ray,
                    double loadTolerance, double resolution)
{
  IntCurvesFace_ShapeIntersector intersector;
  intersector.Load(shape, loadTolerance);
  intersector.Perform(ray, -1e10, 1e10);

  std::printf("%-28s loadTol=%-8g resolution=%-10g hits=%d", label, loadTolerance, resolution,
              intersector.NbPnt());
  for (int i = 1; i <= intersector.NbPnt(); ++i)
  {
    BRepAdaptor_Surface adaptor(intersector.Face(i));
    BRepLProp_SLProps props(adaptor, intersector.UParameter(i), intersector.VParameter(i), 1,
                            resolution);
    if (props.IsNormalDefined())
    {
      gp_Dir n = props.Normal();
      if (intersector.Face(i).Orientation() == TopAbs_REVERSED) n.Reverse();
      std::printf("   hit%d normal (%.4g, %.4g, %.4g)", i, n.X(), n.Y(), n.Z());
    }
    else
    {
      std::printf("   hit%d normal UNDEFINED -> reported as (0, 0, 1)", i);
    }
  }
  std::printf("\n");
}

int main()
{
  std::printf("A sine tolerance is dimensionless: CSLib::Normal rejects the normal when\n"
              "|D1u ^ D1v|^2 / (|D1u|^2 |D1v|^2) < resolution^2, so resolution >= 1 rejects every\n"
              "normal there is. Precision::Confusion() = %g.\n\n",
              Precision::Confusion());

  const TopoDS_Shape sphere = BRepPrimAPI_MakeSphere(gp_Pnt(0, 0, 0), 5.0).Shape();
  const gp_Lin down(gp_Pnt(0, 0, 20), gp_Dir(0, 0, -1));
  const gp_Lin sideways(gp_Pnt(-20, 0, 0), gp_Dir(1, 0, 0));

  std::printf("=== sphere r=5, ray straight down the Z axis ===\n");
  for (double t : {Precision::Confusion(), 0.001, 0.1, 0.9, 1.0, 2.0})
    castRay("sphere / down", sphere, down, t, t);

  std::printf("\n=== sphere r=5, ray along +X (normals point sideways) ===\n");
  for (double t : {0.001, 1.0})
    castRay("sphere / sideways", sphere, sideways, t, t);

  std::printf("\n=== box 10x10x10, ray straight down ===\n");
  const TopoDS_Shape box = BRepPrimAPI_MakeBox(gp_Pnt(-5, -5, -5), 10.0, 10.0, 10.0).Shape();
  for (double t : {0.001, 1.0, 5.0})
    castRay("box / down", box, down, t, t);

  std::printf("\n=== the same hits, resolution decoupled from the load tolerance ===\n");
  for (double t : {0.001, 1.0, 5.0})
    castRay("box / down (fixed res)", box, down, t, Precision::Confusion());

  return 0;
}
