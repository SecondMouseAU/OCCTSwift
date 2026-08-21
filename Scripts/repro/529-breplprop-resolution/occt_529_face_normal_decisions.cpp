// OCCTSwift#529, what the resolution change does to a *decision*, not to a reported value.
//
// OCCTFaceGetNormal evaluates the surface normal at the parametric midpoint of a face and reports
// it (Face.normal), and Face.isHorizontal / isUpwardFacing / isDownwardFacing / isVertical are all
// predicates over that one normal. Tightening the resolution from 1e-6 to Precision::Confusion()
// can only make IsNormalDefined() *more* permissive (the null test is
// SquareMagnitude() > resolution^2, and CSLib::Normal's parallelism test is
// |D1u ^ D1v| > sinTol * |D1u| * |D1v|), so a face can only move from "no normal" to "a normal",
// never the other way, and the direction it reports when defined does not depend on the resolution
// at all. This probe measures that claim over real shapes rather than asserting it: for every face
// of every shape it compares definedness and direction at both values.
//
// Build:
//   L=Libraries/OCCT.xcframework/macos-arm64
//   clang++ -std=c++17 -ObjC++ -w -I"$L/Headers" -L"$L" -lOCCT-macos \
//     -framework Foundation -framework AppKit -lz -lc++ \
//     Scripts/repro/529-breplprop-resolution/occt_529_face_normal_decisions.cpp \
//     -o /tmp/occt_529_decisions
//   /tmp/occt_529_decisions [extra.brep ...]

#include <BRepAdaptor_Surface.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepFilletAPI_MakeFillet.hxx>
#include <BRepLProp_SLProps.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeCone.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <BRepPrimAPI_MakeSphere.hxx>
#include <BRepPrimAPI_MakeTorus.hxx>
#include <BRepTools.hxx>
#include <BRep_Builder.hxx>
#include <Geom_ConicalSurface.hxx>
#include <Geom_Line.hxx>
#include <Geom_SurfaceOfLinearExtrusion.hxx>
#include <Precision.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Face.hxx>
#include <TopoDS_Shape.hxx>

#include <cmath>
#include <cstdio>
#include <string>
#include <utility>
#include <vector>

static const double kOld = 1e-6;
static const double kNew = Precision::Confusion();

struct Decision
{
  bool defined = false;
  gp_Dir normal;
};

// Exactly what OCCTFaceGetNormal does, with the resolution as a parameter.
static Decision faceNormal(const TopoDS_Face& face, double resolution)
{
  Decision d;
  try
  {
    BRepAdaptor_Surface adaptor(face);
    const double uMid = (adaptor.FirstUParameter() + adaptor.LastUParameter()) / 2.0;
    const double vMid = (adaptor.FirstVParameter() + adaptor.LastVParameter()) / 2.0;
    BRepLProp_SLProps props(adaptor, uMid, vMid, 1, resolution);
    if (!props.IsNormalDefined()) return d;
    gp_Dir n = props.Normal();
    if (face.Orientation() == TopAbs_REVERSED) n.Reverse();
    d.defined = true;
    d.normal = n;
  }
  catch (...)
  {
  }
  return d;
}

// Face.isHorizontal / isUpwardFacing, at their Swift default tolerance.
static bool isHorizontal(const Decision& d, double tol = 0.01)
{
  return d.defined && std::abs(d.normal.Z()) > std::cos(tol);
}
static bool isUpward(const Decision& d, double tol = 0.01)
{
  return d.defined && d.normal.Z() > std::cos(tol);
}

// Component-wise, not gp_Dir::IsEqual(other, 0.0): IsEqual measures the angle, and gp_Dir::Angle
// returns ~1.5e-17 rather than 0 for two *bit-identical* directions whenever the dot product
// rounds just below 1 and it takes the asin(CrossMagnitude) branch. Comparing two props objects
// built at the same resolution shows the same 1.5e-17, so an angular test at tolerance 0 reports a
// difference that is not there. The question here is whether the resolution perturbs the reported
// direction at all, so ask for exact equality of the numbers actually handed to the caller.
static bool sameDirection(const gp_Dir& a, const gp_Dir& b)
{
  return a.X() == b.X() && a.Y() == b.Y() && a.Z() == b.Z();
}

static void compare(const char* name, const TopoDS_Shape& shape)
{
  if (shape.IsNull())
  {
    std::printf("%-34s SKIPPED (null shape)\n", name);
    return;
  }

  int faces = 0, flippedToDefined = 0, flippedToUndefined = 0, directionChanged = 0;
  int horizOld = 0, horizNew = 0, upOld = 0, upNew = 0;
  std::vector<std::string> notes;

  int index = 0;
  for (TopExp_Explorer exp(shape, TopAbs_FACE); exp.More(); exp.Next(), ++index)
  {
    const TopoDS_Face face = TopoDS::Face(exp.Current());
    ++faces;

    const Decision o = faceNormal(face, kOld);
    const Decision n = faceNormal(face, kNew);

    if (!o.defined && n.defined) ++flippedToDefined;
    if (o.defined && !n.defined) ++flippedToUndefined;
    if (o.defined && n.defined && !sameDirection(o.normal, n.normal)) ++directionChanged;

    horizOld += isHorizontal(o) ? 1 : 0;
    horizNew += isHorizontal(n) ? 1 : 0;
    upOld += isUpward(o) ? 1 : 0;
    upNew += isUpward(n) ? 1 : 0;

    if (o.defined != n.defined || (o.defined && n.defined && !sameDirection(o.normal, n.normal)))
    {
      char buf[220];
      std::snprintf(buf, sizeof(buf),
                    "      face %d: 1e-6 %s -> Confusion %s%s", index,
                    o.defined ? "defined" : "UNDEFINED", n.defined ? "defined" : "UNDEFINED",
                    n.defined ? "" : "");
      std::string line = buf;
      if (n.defined)
      {
        std::snprintf(buf, sizeof(buf), " normal (%.6g, %.6g, %.6g)", n.normal.X(), n.normal.Y(),
                      n.normal.Z());
        line += buf;
      }
      notes.push_back(line);
    }
  }

  std::printf("%-34s faces=%-4d  definedness -/+ = %d/%d  direction changed = %d  "
              "horizontal %d->%d  upward %d->%d%s\n",
              name, faces, flippedToUndefined, flippedToDefined, directionChanged, horizOld,
              horizNew, upOld, upNew,
              (flippedToDefined || flippedToUndefined || directionChanged) ? "   <-- CHANGED" : "");
  for (const std::string& note : notes) std::printf("%s\n", note.c_str());
}

int main(int argc, char** argv)
{
  std::printf("Face-normal decisions at the parametric midpoint: 1e-6 (today) vs "
              "Precision::Confusion() = %g\n\n",
              kNew);

  compare("box 10x20x30", BRepPrimAPI_MakeBox(10.0, 20.0, 30.0).Shape());
  compare("cylinder r=5 h=20", BRepPrimAPI_MakeCylinder(5.0, 20.0).Shape());
  compare("sphere r=7", BRepPrimAPI_MakeSphere(7.0).Shape());
  compare("cone r1=5 r2=0 h=12 (apex)", BRepPrimAPI_MakeCone(5.0, 0.0, 12.0).Shape());
  compare("cone r1=5 r2=2 h=12 (frustum)", BRepPrimAPI_MakeCone(5.0, 2.0, 12.0).Shape());
  compare("torus R=10 r=3", BRepPrimAPI_MakeTorus(10.0, 3.0).Shape());
  compare("half sphere (pole at v mid)", BRepPrimAPI_MakeSphere(7.0, 0.0, M_PI / 2).Shape());

  // A bare conical face whose v range straddles the apex, so the *midpoint* is the degenerate
  // point rather than an edge of the domain -- the case where a midpoint-sampling entry point is
  // most likely to see the resolution at all.
  {
    gp_Ax3 axis(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1));
    occ::handle<Geom_ConicalSurface> cone = new Geom_ConicalSurface(axis, M_PI / 6.0, 0.0);
    compare("conical face, v in [-1e-6, 1e-6]",
            BRepBuilderAPI_MakeFace(cone, 0.0, 2 * M_PI, -1e-6, 1e-6, Precision::Confusion())
                .Face());
    compare("conical face, v in [-3e-7, 3e-7]",
            BRepBuilderAPI_MakeFace(cone, 0.0, 2 * M_PI, -3e-7, 3e-7, Precision::Confusion())
                .Face());
    compare("conical face, v in [-1e-8, 1e-8]",
            BRepBuilderAPI_MakeFace(cone, 0.0, 2 * M_PI, -1e-8, 1e-8, Precision::Confusion())
                .Face());
  }

  // The one shape of surface where the resolution *does* reach IsNormalDefined(). CSLib::Normal
  // tests the two first derivatives for nullity against gp::Resolution() (a fixed ~1e-300 epsilon)
  // and uses the caller's value only as a SINE tolerance on the angle between them:
  //
  //     aSin2 = |D1u ^ D1v|^2 / (|D1u|^2 |D1v|^2);  if (aSin2 < theSinTol^2) -> D1uIsParallelD1v
  //
  // That test is scale-invariant, so a surface whose derivatives merely shrink (a cone at its apex,
  // a sphere at its pole) keeps a defined normal all the way down. Only a surface whose two
  // parametric directions become nearly *parallel* is affected. An extrusion of a line along a
  // direction a hair off the line's own is exactly that, with the angle dialled to order.
  for (double angle : {1e-5, 3e-6, 1e-6, 5e-7, 1e-7, 1e-8})
  {
    occ::handle<Geom_Line> line = new Geom_Line(gp_Pnt(0, 0, 0), gp_Dir(1, 0, 0));
    gp_Dir extrusion(std::cos(angle), std::sin(angle), 0.0);
    occ::handle<Geom_SurfaceOfLinearExtrusion> surf =
        new Geom_SurfaceOfLinearExtrusion(line, extrusion);
    char label[64];
    std::snprintf(label, sizeof(label), "extrusion skewed by %g rad", angle);
    compare(label,
            BRepBuilderAPI_MakeFace(surf, 0.0, 10.0, 0.0, 10.0, Precision::Confusion()).Face());
  }

  // A filleted box: many BSpline/torus-patch faces, the closest thing to production geometry that
  // builds from primitives.
  {
    TopoDS_Shape box = BRepPrimAPI_MakeBox(10.0, 20.0, 30.0).Shape();
    BRepFilletAPI_MakeFillet fillet(box);
    for (TopExp_Explorer exp(box, TopAbs_EDGE); exp.More(); exp.Next())
      fillet.Add(1.5, TopoDS::Edge(exp.Current()));
    fillet.Build();
    compare("filleted box (r=1.5, all edges)", fillet.IsDone() ? fillet.Shape() : TopoDS_Shape());
  }

  // Any .brep passed on the command line, so the real fixtures can be swept too.
  for (int i = 1; i < argc; ++i)
  {
    TopoDS_Shape shape;
    BRep_Builder builder;
    if (!BRepTools::Read(shape, argv[i], builder))
    {
      std::printf("%-34s SKIPPED (unreadable)\n", argv[i]);
      continue;
    }
    compare(argv[i], shape);
  }

  return 0;
}
