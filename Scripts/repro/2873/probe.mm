// #2873 ground truth: which plane the by-plane BRepGProp_Vinert overloads actually measure about.
//
// #2827's probe established that the by-plane mass is a measurement once patch 0043 stops
// discarding it. This one establishes WHAT it measures, because the answer decides a sign in
// OCCTBRepGPropVinertPlane and no amount of reading BRepGProp_Vinert.hxx settles it.
//
// Four questions, all measured on one flat cap square to the plane normal, where
// mass == (n_hat . n_face) * area * d1 exactly, so mass / area reads d1 off directly:
//
//   1. What d1 is, as a function of the gp_Pln handed in, and whether SetLocation moves it.
//   2. Whether OCCT's OTHER by-plane implementation agrees. BRepGProp_VinertGK integrates with
//      math_KronrodSingleIntegration through BRepGProp_UFunction, sharing no code with
//      BRepGProp_Gauss, so it is a genuine second construction and not a re-run of the first.
//   3. What the gp_Pln itself says the distance is: gp_Pln::Coefficients gives a x + b y + c z + d
//      = 0, so the signed distance from the plane to P is n_hat . P + d. Printed alongside so the
//      comparison is against gp_Pln's own arithmetic rather than against this file's.
//   4. Whether handing the kernel the plane mirrored through the origin makes d1 the signed
//      distance to the plane the caller asked for. That is the bridge-side fix, measured before it
//      is written.
//
// And the two aggregate identities (#2827) re-measured under the mirrored plane, since a fix that
// corrected the per-face value and broke the sums would be no fix at all.
//
// Compile (from a checkout with Libraries/OCCT.xcframework, or point -I/-L at the SwiftPM artifact
// under .build/artifacts/<pkg>/OCCT/OCCT.xcframework):
//
//   clang++ -std=c++17 -ObjC++ -w \
//     -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
//     -L"Libraries/OCCT.xcframework/macos-arm64" \
//     -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
//     Scripts/repro/2873/probe.mm -o /tmp/occt_probe_2873

#include <BRepAlgoAPI_Cut.hxx>
#include <BRepBuilderAPI_Transform.hxx>
#include <BRepGProp.hxx>
#include <BRepGProp_Domain.hxx>
#include <BRepGProp_Face.hxx>
#include <BRepGProp_Vinert.hxx>
#include <BRepGProp_VinertGK.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <GProp_GProps.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <gp_Ax2.hxx>
#include <gp_Pln.hxx>
#include <gp_Trsf.hxx>

#include <cstdio>

// The same domain load OCCTBRepGPropVinert/VinertPlane do: a face with wires is integrated over the
// region they trim, a face with none over its natural UV bounds.
static bool loadDomain(const TopoDS_Face& f, BRepGProp_Domain& d)
{
  TopExp_Explorer ex(f, TopAbs_EDGE);
  if (!ex.More())
    return false;
  d.Init(f);
  return true;
}

// The plane OCCTBRepGPropVinertPlane builds today from (planeNormal, planeDistance): through the
// point planeDistance along the normal from the origin, so geometrically it IS the plane at that
// offset.
static gp_Pln planeAtOffset(const gp_Dir& n, double offset)
{
  return gp_Pln(gp_Pnt(n.XYZ() * offset), n);
}

struct Measured
{
  double mass;
  gp_Pnt centre;
};

static Measured vinertByPlane(const TopoDS_Face& f, const gp_Pln& pln, const gp_Pnt& loc)
{
  BRepGProp_Face   gf(f);
  BRepGProp_Domain d;
  BRepGProp_Vinert v;
  v.SetLocation(loc);
  if (loadDomain(f, d))
    v.Perform(gf, d, pln);
  else
    v.Perform(gf, pln);
  return {v.Mass(), v.CentreOfMass()};
}

static Measured vinertGKByPlane(const TopoDS_Face& f, const gp_Pln& pln, const gp_Pnt& loc)
{
  BRepGProp_Face   gf(f);
  BRepGProp_Domain d;
  if (loadDomain(f, d))
  {
    BRepGProp_VinertGK v(gf, d, pln, loc, 1.0e-9, true, false);
    return {v.Mass(), v.CentreOfMass()};
  }
  BRepGProp_VinertGK v(gf, pln, loc, 1.0e-9, true, false);
  return {v.Mass(), v.CentreOfMass()};
}

static TopoDS_Face largestFace(const TopoDS_Shape& s, double& outArea)
{
  TopoDS_Face best;
  outArea = 0.0;
  for (TopExp_Explorer ex(s, TopAbs_FACE); ex.More(); ex.Next())
  {
    GProp_GProps a;
    BRepGProp::SurfaceProperties(ex.Current(), a);
    if (a.Mass() > outArea)
    {
      outArea = a.Mass();
      best    = TopoDS::Face(ex.Current());
    }
  }
  return best;
}

int main()
{
  // A 20 x 20 x 2 plate with a radius-3 hole, built from the corner, so the cap square to z sits
  // at z = 2 and NOT at z = 0: a fixture whose cap lay in the plane would read the same under
  // every convention under test.
  TopoDS_Shape plate = BRepPrimAPI_MakeBox(gp_Pnt(0, 0, 0), 20, 20, 2).Shape();
  TopoDS_Shape drill =
    BRepPrimAPI_MakeCylinder(gp_Ax2(gp_Pnt(10, 10, -5), gp_Dir(0, 0, 1)), 3, 10).Shape();
  TopoDS_Shape holed = BRepAlgoAPI_Cut(plate, drill).Shape();

  const gp_Dir n(0, 0, 1);

  double            capArea = 0.0;
  const TopoDS_Face cap     = largestFace(holed, capArea);

  GProp_GProps capProps;
  BRepGProp::SurfaceProperties(cap, capProps);
  const gp_Pnt capCentre = capProps.CentreOfMass();
  const double nDotC     = capCentre.XYZ().Dot(n.XYZ());

  std::printf("cap: area %.10g, area centroid (%.10g, %.10g, %.10g), n . C = %.10g\n\n",
              capArea,
              capCentre.X(),
              capCentre.Y(),
              capCentre.Z(),
              nDotC);

  const gp_Pnt locs[]    = {gp_Pnt(0, 0, 0), gp_Pnt(0, 0, 3), gp_Pnt(-4, 11, 2.5)};
  const char*  locName[] = {"(0, 0, 0)", "(0, 0, 3)", "(-4, 11, 2.5)"};
  const double offsets[] = {0.0, 1.0, -100.0, 5.0};

  // ---- 1, 2, 3: what the kernel measures, from both implementations, against gp_Pln's own
  // arithmetic, over a grid of SetLocation points.
  std::printf("what the kernel weights each element by, on the cap (mass / area = d1)\n");
  std::printf("  the plane passed is gp_Pln(gp_Pnt(n * offset), n), the plane AT that offset\n");
  std::printf("  %-16s %8s %14s %14s %14s %14s\n",
              "SetLocation",
              "offset",
              "Vinert d1",
              "VinertGK d1",
              "gp_Pln n.C+d",
              "geometric");
  for (int li = 0; li < 3; ++li)
  {
    for (double off : offsets)
    {
      const gp_Pln pln = planeAtOffset(n, off);
      double       a, b, c, d;
      pln.Coefficients(a, b, c, d);
      const double   plnSigned = capCentre.XYZ().Dot(gp_XYZ(a, b, c)) + d;
      const Measured g         = vinertByPlane(cap, pln, locs[li]);
      const Measured k         = vinertGKByPlane(cap, pln, locs[li]);
      std::printf("  %-16s %8g %14.10g %14.10g %14.10g %14.10g\n",
                  locName[li],
                  off,
                  g.mass / capArea,
                  k.mass / capArea,
                  plnSigned,
                  nDotC - off);
    }
  }

  // ---- 4: the mirrored plane, which is the bridge-side fix.
  std::printf("\nthe same, handing the kernel gp_Pln(gp_Pnt(n * -offset), n) instead\n");
  std::printf("  %-16s %8s %14s %14s %14s\n",
              "SetLocation",
              "offset",
              "Vinert d1",
              "VinertGK d1",
              "geometric");
  for (int li = 0; li < 3; ++li)
  {
    for (double off : offsets)
    {
      const gp_Pln   pln = planeAtOffset(n, -off);
      const Measured g   = vinertByPlane(cap, pln, locs[li]);
      const Measured k   = vinertGKByPlane(cap, pln, locs[li]);
      std::printf("  %-16s %8g %14.10g %14.10g %14.10g\n",
                  locName[li],
                  off,
                  g.mass / capArea,
                  k.mass / capArea,
                  nDotC - off);
    }
  }

  // ---- the centre of mass, which is the column's centroid and therefore says which plane the
  // column runs to. The cap is at z = 2, so a column to the plane at z = p has its centroid at
  // z = (2 + p) / 2.
  std::printf("\nthe column's centroid, cap at z = 2, SetLocation at the origin\n");
  std::printf("  %8s %20s %20s %16s\n",
              "offset",
              "centre.z, plane as-is",
              "centre.z, mirrored",
              "(2 + offset) / 2");
  for (double off : offsets)
  {
    const Measured asIs     = vinertByPlane(cap, planeAtOffset(n, off), gp_Pnt(0, 0, 0));
    const Measured mirrored = vinertByPlane(cap, planeAtOffset(n, -off), gp_Pnt(0, 0, 0));
    std::printf("  %8g %20.10g %20.10g %16.10g\n",
                off,
                asIs.centre.Z(),
                mirrored.centre.Z(),
                (2.0 + off) / 2.0);
  }

  // ---- the two #2827 aggregate identities, under the mirrored plane, on an off-origin fixture.
  gp_Trsf shift;
  shift.SetTranslation(gp_Vec(7, -3, 2));
  TopoDS_Shape shifted = BRepBuilderAPI_Transform(holed, shift, true).Shape();

  GProp_GProps vp;
  BRepGProp::VolumeProperties(shifted, vp, true);
  const gp_XYZ vpMoment = vp.CentreOfMass().XYZ() * vp.Mass();

  std::printf("\nthe #2827 identities under the mirrored plane, plate shifted by (7, -3, 2)\n");
  std::printf("  VolumeProperties        %.16g   first moment (%.12g, %.12g, %.12g)\n",
              vp.Mass(),
              vpMoment.X(),
              vpMoment.Y(),
              vpMoment.Z());
  const gp_Dir obl(1, 2, 3);
  for (int variant = 0; variant < 3; ++variant)
  {
    const gp_Dir nn  = (variant == 2) ? obl : n;
    const double off = (variant == 0) ? 0.0 : ((variant == 1) ? -100.0 : 7.0);
    const gp_Pln pln = planeAtOffset(nn, -off);
    double       sum = 0.0;
    gp_XYZ       mom(0, 0, 0);
    for (TopExp_Explorer ex(shifted, TopAbs_FACE); ex.More(); ex.Next())
    {
      const Measured m = vinertByPlane(TopoDS::Face(ex.Current()), pln, gp_Pnt(0, 0, 0));
      sum += m.mass;
      mom += m.centre.XYZ() * m.mass;
    }
    std::printf("  n (%g, %g, %g) off %7g   sum %.16g   first moment (%.12g, %.12g, %.12g)\n",
                nn.X(),
                nn.Y(),
                nn.Z(),
                off,
                sum,
                mom.X(),
                mom.Y(),
                mom.Z());
  }
  return 0;
}
