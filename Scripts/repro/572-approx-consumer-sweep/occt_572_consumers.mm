// OCCTSwift #572: do the sweep / offset / unify / convert consumers of
// GeomConvert_ApproxSurface move when patch 0019 (#522) makes the interior truncation
// error real?
//
// Each case drives the same OCCT call the corresponding bridge function drives, and
// prints a fingerprint a re-parameterisation would move: surface type, degrees, pole and
// knot counts, an order-independent hash of every face's sampled geometry, and volume and
// area where a solid comes out. The "direction" section then reruns each reached site's own
// approximation request on its own input and puts the error OCCT reports next to the
// deviation actually there.
//
// Compile (from the repo root):
//   clang++ -std=c++17 -ObjC++ -w \
//     -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
//     -L"Libraries/OCCT.xcframework/macos-arm64" \
//     -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
//     Scripts/repro/572-approx-consumer-sweep/occt_572_consumers.mm -o /tmp/occt_572
//
// For the A/B, link an -O0 copy of AdvApp2Var_ApproxF2var.cxx ahead of the archive: one
// as it stands, one with 0019 reverted. See the README: comparing an -O0 override against
// the shipped -O2 archive moves unrelated rows in the sixth significant digit.

#include <cstdio>
#include <cstdint>
#include <cstring>
#include <sstream>
#include <string>
#include <vector>
#include <algorithm>

#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepBuilderAPI_MakeWire.hxx>
#include <BRepBuilderAPI_MakePolygon.hxx>
#include <BRepBuilderAPI_Sewing.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <BRepPrimAPI_MakeSphere.hxx>
#include <BRepPrimAPI_MakeTorus.hxx>
#include <BRepAlgoAPI_Fuse.hxx>
#include <BRepAlgoAPI_Cut.hxx>
#include <BRepFilletAPI_MakeFillet.hxx>
#include <BRepOffsetAPI_MakePipe.hxx>
#include <BRepOffsetAPI_MakePipeShell.hxx>
#include <BRepOffsetAPI_MakeOffsetShape.hxx>
#include <BRepOffsetAPI_MakeThickSolid.hxx>
#include <BOPAlgo_Options.hxx>
#include <BRepGProp.hxx>
#include <BRepTools.hxx>
#include <BRep_Tool.hxx>
#include <GProp_GProps.hxx>
#include <ShapeUpgrade_UnifySameDomain.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <TopTools_ListOfShape.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopExp.hxx>

#include <Geom_BSplineCurve.hxx>
#include <Geom_BSplineSurface.hxx>
#include <Geom_CylindricalSurface.hxx>
#include <Geom_Circle.hxx>
#include <Geom_OffsetSurface.hxx>
#include <Geom_Plane.hxx>
#include <Geom_RectangularTrimmedSurface.hxx>
#include <Geom_SphericalSurface.hxx>
#include <Geom_SurfaceOfLinearExtrusion.hxx>
#include <Geom_SurfaceOfRevolution.hxx>
#include <Geom_ToroidalSurface.hxx>
#include <Geom_TrimmedCurve.hxx>
#include <GeomConvert.hxx>
#include <GeomConvert_ApproxSurface.hxx>
#include <GeomAPI_ProjectPointOnSurf.hxx>
#include <GeomLib.hxx>
#include <NCollection_Array1.hxx>
#include <NCollection_Array2.hxx>
#include <gp_Ax1.hxx>
#include <gp_Ax2.hxx>
#include <gp_Ax3.hxx>
#include <gp_Circ.hxx>
#include <gp_Pnt.hxx>
#include <Precision.hxx>

// ---------------------------------------------------------------------------
// Fingerprinting
// ---------------------------------------------------------------------------

static uint64_t fnv1a(const std::string& s)
{
  uint64_t h = 1469598103934665603ULL;
  for (unsigned char c : s)
  {
    h ^= c;
    h *= 1099511628211ULL;
  }
  return h;
}

static void printSurface(const char* label, const Handle(Geom_Surface)& s)
{
  if (s.IsNull())
  {
    printf("%-34s surface=NULL\n", label);
    return;
  }
  double u0, u1, v0, v1;
  s->Bounds(u0, u1, v0, v1);

  // Sample the surface itself, so a change of parameterisation that keeps the same
  // pole layout still shows up.
  std::ostringstream pts;
  pts.precision(12);
  for (int i = 0; i <= 8; ++i)
  {
    for (int j = 0; j <= 8; ++j)
    {
      gp_Pnt p = s->Value(u0 + (u1 - u0) * i / 8.0, v0 + (v1 - v0) * j / 8.0);
      pts << p.X() << ' ' << p.Y() << ' ' << p.Z() << ' ';
    }
  }

  Handle(Geom_BSplineSurface) bs = Handle(Geom_BSplineSurface)::DownCast(s);
  if (bs.IsNull())
  {
    printf("%-34s type=%-34s U[%g %g] V[%g %g] pts=%016llx\n",
           label,
           s->DynamicType()->Name(),
           u0,
           u1,
           v0,
           v1,
           (unsigned long long)fnv1a(pts.str()));
    return;
  }
  printf("%-34s type=%-34s uDeg=%d vDeg=%d uPoles=%d vPoles=%d uKnots=%d vKnots=%d "
         "uPer=%d vPer=%d U[%g %g] V[%g %g] pts=%016llx\n",
         label,
         s->DynamicType()->Name(),
         bs->UDegree(),
         bs->VDegree(),
         bs->NbUPoles(),
         bs->NbVPoles(),
         bs->NbUKnots(),
         bs->NbVKnots(),
         (int)bs->IsUPeriodic(),
         (int)bs->IsVPeriodic(),
         u0,
         u1,
         v0,
         v1,
         (unsigned long long)fnv1a(pts.str()));
}

static void printShape(const char* label, const TopoDS_Shape& sh)
{
  if (sh.IsNull())
  {
    printf("%-34s shape=NULL\n", label);
    return;
  }
  GProp_GProps vp, sp;
  BRepGProp::VolumeProperties(sh, vp);
  BRepGProp::SurfaceProperties(sh, sp);

  TopTools_IndexedMapOfShape faces, edges, verts;
  TopExp::MapShapes(sh, TopAbs_FACE, faces);
  TopExp::MapShapes(sh, TopAbs_EDGE, edges);
  TopExp::MapShapes(sh, TopAbs_VERTEX, verts);

  // A BRepTools::Write hash is not usable here: the offset and boolean paths order their
  // output differently from run to run on the same binary. Fingerprint the geometry
  // instead, per face: its surface type, layout and a sampled point grid, then sort the
  // per-face strings so face order cannot matter.
  std::vector<std::string> faceFingerprints;
  int nbBSpline = 0, maxUDeg = 0, maxVDeg = 0, maxUPoles = 0, maxVPoles = 0;
  for (int i = 1; i <= faces.Extent(); ++i)
  {
    TopLoc_Location      loc;
    Handle(Geom_Surface) s = BRep_Tool::Surface(TopoDS::Face(faces(i)), loc);
    std::ostringstream   fp;
    fp.precision(10);
    if (s.IsNull())
    {
      faceFingerprints.push_back("null");
      continue;
    }
    fp << s->DynamicType()->Name();
    Handle(Geom_BSplineSurface) bs = Handle(Geom_BSplineSurface)::DownCast(s);
    if (!bs.IsNull())
    {
      ++nbBSpline;
      fp << ' ' << bs->UDegree() << 'x' << bs->VDegree() << ' ' << bs->NbUPoles() << 'x'
         << bs->NbVPoles() << ' ' << bs->NbUKnots() << 'x' << bs->NbVKnots();
      if (bs->UDegree() > maxUDeg)
        maxUDeg = bs->UDegree();
      if (bs->VDegree() > maxVDeg)
        maxVDeg = bs->VDegree();
      if (bs->NbUPoles() > maxUPoles)
        maxUPoles = bs->NbUPoles();
      if (bs->NbVPoles() > maxVPoles)
        maxVPoles = bs->NbVPoles();
    }
    double u0, u1, v0, v1;
    s->Bounds(u0, u1, v0, v1);
    if (Precision::IsInfinite(u0) || Precision::IsInfinite(u1) || Precision::IsInfinite(v0)
        || Precision::IsInfinite(v1))
    {
      fp << " infinite";
    }
    else
    {
      for (int a = 0; a <= 4; ++a)
        for (int b = 0; b <= 4; ++b)
        {
          gp_Pnt p = s->Value(u0 + (u1 - u0) * a / 4.0, v0 + (v1 - v0) * b / 4.0);
          p.Transform(loc.Transformation());
          fp << ' ' << p.X() << ' ' << p.Y() << ' ' << p.Z();
        }
    }
    faceFingerprints.push_back(fp.str());
  }
  std::sort(faceFingerprints.begin(), faceFingerprints.end());
  std::string joined;
  for (const std::string& f : faceFingerprints)
    joined += f + "\n";

  printf("%-34s vol=%.12g area=%.12g nF=%d nE=%d nV=%d bsplineF=%d maxDeg=%dx%d "
         "maxPoles=%dx%d faces=%016llx\n",
         label,
         vp.Mass(),
         sp.Mass(),
         faces.Extent(),
         edges.Extent(),
         verts.Extent(),
         nbBSpline,
         maxUDeg,
         maxVDeg,
         maxUPoles,
         maxVPoles,
         (unsigned long long)fnv1a(joined));
}

// ---------------------------------------------------------------------------
// Shared fixtures
// ---------------------------------------------------------------------------

// A C0 BSpline curve: two straight spans meeting at a corner (interior knot with
// multiplicity == degree). IsCN(1) is false, which is what drives GeomConvert_1.cxx:960
// to request GeomAbs_C0.
static Handle(Geom_BSplineCurve) cornerCurveC0()
{
  NCollection_Array1<gp_Pnt> poles(1, 5);
  poles(1) = gp_Pnt(4, 0, -3);
  poles(2) = gp_Pnt(6, 0, -1);
  poles(3) = gp_Pnt(8, 0, 0);
  poles(4) = gp_Pnt(6, 0, 1);
  poles(5) = gp_Pnt(4, 0, 3);
  NCollection_Array1<double> knots(1, 3);
  knots(1) = 0.0;
  knots(2) = 0.5;
  knots(3) = 1.0;
  NCollection_Array1<int> mults(1, 3);
  mults(1) = 3;
  mults(2) = 2; // == degree: a C0 corner
  mults(3) = 3;
  return new Geom_BSplineCurve(poles, knots, mults, 2);
}

// A smooth (C2) BSpline curve over the same poles, for the contrast case.
static Handle(Geom_BSplineCurve) smoothCurveC2()
{
  NCollection_Array1<gp_Pnt> poles(1, 5);
  poles(1) = gp_Pnt(4, 0, -3);
  poles(2) = gp_Pnt(6, 0, -1);
  poles(3) = gp_Pnt(8, 0, 0);
  poles(4) = gp_Pnt(6, 0, 1);
  poles(5) = gp_Pnt(4, 0, 3);
  NCollection_Array1<double> knots(1, 3);
  knots(1) = 0.0;
  knots(2) = 0.5;
  knots(3) = 1.0;
  NCollection_Array1<int> mults(1, 3);
  mults(1) = 4;
  mults(2) = 1;
  mults(3) = 4;
  return new Geom_BSplineCurve(poles, knots, mults, 3);
}

static TopoDS_Wire circleWire(const gp_Ax2& ax, double r)
{
  BRepBuilderAPI_MakeEdge me(new Geom_Circle(gp_Circ(ax, r)));
  BRepBuilderAPI_MakeWire mw(me.Edge());
  return mw.Wire();
}

// ---------------------------------------------------------------------------
// Row 1: GeomFill_Sweep.cxx:296 (Shape.pipeShell family, Shape.sweep)
// ---------------------------------------------------------------------------

static void caseSweep()
{
  printf("\n### row 1: GeomFill_Sweep.cxx:296 (pipe shell / sweep)\n");

  // A spine with a tangent discontinuity: two straight segments meeting at a corner,
  // which is where the swept surface has a chance of not being C1 in V.
  BRepBuilderAPI_MakePolygon poly(gp_Pnt(0, 0, 0), gp_Pnt(0, 0, 10), gp_Pnt(6, 0, 16));
  const TopoDS_Wire          spine = poly.Wire();
  const TopoDS_Wire profile = circleWire(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 1.5);

  // Shape.sweep, i.e. BRepOffsetAPI_MakePipe, with ForceApproxC1 never set (it is not on the
  // two-argument constructor this bridge uses).
  try
  {
    BRepOffsetAPI_MakePipe maker(spine, profile);
    maker.Build();
    printShape("sweep/MakePipe", maker.IsDone() ? maker.Shape() : TopoDS_Shape());
  }
  catch (...)
  {
    printf("%-34s THREW\n", "sweep/MakePipe");
  }

  for (int force = 0; force <= 1; ++force)
  {
    for (int mode = 0; mode <= 1; ++mode) // 0 = Frenet, 1 = corrected Frenet
    {
      char label[80];
      snprintf(label, sizeof(label), "pipeShell/force=%d/mode=%d", force, mode);
      try
      {
        BRepOffsetAPI_MakePipeShell ps(spine);
        ps.SetMode(mode == 1);
        ps.SetTransitionMode(BRepBuilderAPI_Transformed);
        ps.SetForceApproxC1(force == 1);
        ps.Add(profile, Standard_False, Standard_False);
        ps.SetIsBuildHistory(Standard_False);
        ps.Build();
        printShape(label, ps.IsDone() ? ps.Shape() : TopoDS_Shape());
      }
      catch (...)
      {
        printf("%-34s THREW\n", label);
      }
    }
  }

  // A spine whose corner is *inside* one edge, so BRepFill cannot split the sweep at a
  // vertex and the swept surface itself carries the C0 join in V.
  {
    NCollection_Array1<gp_Pnt> poles(1, 5);
    poles(1) = gp_Pnt(0, 0, 0);
    poles(2) = gp_Pnt(0, 0, 4);
    poles(3) = gp_Pnt(0, 0, 8);
    poles(4) = gp_Pnt(4, 0, 11);
    poles(5) = gp_Pnt(9, 0, 13);
    NCollection_Array1<double> knots(1, 3);
    knots(1) = 0.0;
    knots(2) = 0.5;
    knots(3) = 1.0;
    NCollection_Array1<int> mults(1, 3);
    mults(1) = 3;
    mults(2) = 2; // == degree: the spine has a C0 corner mid-edge
    mults(3) = 3;
    Handle(Geom_BSplineCurve) spineCurve = new Geom_BSplineCurve(poles, knots, mults, 2);
    BRepBuilderAPI_MakeEdge   me(spineCurve);
    BRepBuilderAPI_MakeWire   mw(me.Edge());
    const TopoDS_Wire         cornerSpine = mw.Wire();

    for (int force = 0; force <= 1; ++force)
    {
      char label[80];
      snprintf(label, sizeof(label), "pipeShell/c0Spine/force=%d", force);
      try
      {
        BRepOffsetAPI_MakePipeShell ps(cornerSpine);
        ps.SetMode(Standard_True);
        ps.SetForceApproxC1(force == 1);
        ps.Add(circleWire(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 1.0),
               Standard_False,
               Standard_False);
        ps.SetIsBuildHistory(Standard_False);
        ps.Build();
        printShape(label, ps.IsDone() ? ps.Shape() : TopoDS_Shape());
      }
      catch (...)
      {
        printf("%-34s THREW\n", label);
      }
    }

    // Several sections along that same spine, which is what makes the swept surface
    // evolve non-smoothly in the spine direction.
    for (int force = 0; force <= 1; ++force)
    {
      char label[80];
      snprintf(label, sizeof(label), "pipeShell/multiSection/force=%d", force);
      try
      {
        BRepOffsetAPI_MakePipeShell ps(cornerSpine);
        ps.SetMode(Standard_True);
        ps.SetForceApproxC1(force == 1);
        ps.Add(circleWire(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 1.0), Standard_False, Standard_False);
        ps.Add(circleWire(gp_Ax2(gp_Pnt(0, 0, 8), gp_Dir(0, 0, 1)), 2.5), Standard_False, Standard_False);
        ps.Add(circleWire(gp_Ax2(gp_Pnt(9, 0, 13), gp_Dir(0.93, 0, 0.37)), 0.8), Standard_False, Standard_False);
        ps.SetIsBuildHistory(Standard_False);
        ps.Build();
        printShape(label, ps.IsDone() ? ps.Shape() : TopoDS_Shape());
      }
      catch (...)
      {
        printf("%-34s THREW\n", label);
      }
    }
  }

  // A curved spine, where the swept surface is a genuine approximation rather than a
  // ruled patch.
  const TopoDS_Wire arcSpine = circleWire(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 1, 0)), 8);
  for (int force = 0; force <= 1; ++force)
  {
    char label[80];
    snprintf(label, sizeof(label), "pipeShell/arc/force=%d", force);
    try
    {
      BRepOffsetAPI_MakePipeShell ps(arcSpine);
      ps.SetMode(Standard_True);
      ps.SetForceApproxC1(force == 1);
      ps.Add(circleWire(gp_Ax2(gp_Pnt(8, 0, 0), gp_Dir(0, 0, 1)), 1.2),
             Standard_False,
             Standard_False);
      ps.SetIsBuildHistory(Standard_False);
      ps.Build();
      printShape(label, ps.IsDone() ? ps.Shape() : TopoDS_Shape());
    }
    catch (...)
    {
      printf("%-34s THREW\n", label);
    }
  }
}

// ---------------------------------------------------------------------------
// Row 2: BRepOffset_Offset.cxx:1626 (Shape.offset, Shape.thickSolid)
// ---------------------------------------------------------------------------

static void caseOffset()
{
  printf("\n### row 2: BRepOffset_Offset.cxx:1626 (offset / thick solid)\n");

  const TopoDS_Shape box = BRepPrimAPI_MakeBox(10, 6, 4).Shape();

  // Shape.offset(by:) with an arc join, which is the case that builds a spherical face on
  // every convex vertex, i.e. the branch that owns the row's construction site.
  for (int join = 0; join <= 2; ++join)
  {
    char label[80];
    snprintf(label, sizeof(label), "offsetByJoin/join=%d", join);
    try
    {
      GeomAbs_JoinType jt = join == 0 ? GeomAbs_Arc : (join == 1 ? GeomAbs_Tangent : GeomAbs_Intersection);
      BRepOffsetAPI_MakeOffsetShape off;
      off.PerformByJoin(box, 2.0, 1e-7, BRepOffset_Skin, Standard_False, Standard_False, jt, Standard_False);
      printShape(label, off.IsDone() ? off.Shape() : TopoDS_Shape());
    }
    catch (...)
    {
      printf("%-34s THREW\n", label);
    }
  }

  // Same, on a shape whose vertices join curved faces.
  try
  {
    const TopoDS_Shape cyl = BRepPrimAPI_MakeCylinder(3.0, 8.0).Shape();
    BRepOffsetAPI_MakeOffsetShape off;
    off.PerformByJoin(cyl, 1.5, 1e-7, BRepOffset_Skin, Standard_False, Standard_False, GeomAbs_Arc, Standard_False);
    printShape("offsetByJoin/cylinder", off.IsDone() ? off.Shape() : TopoDS_Shape());
  }
  catch (...)
  {
    printf("%-34s THREW\n", "offsetByJoin/cylinder");
  }

  // Shape.thickSolid(facesToRemove:offset:)
  try
  {
    TopTools_IndexedMapOfShape faces;
    TopExp::MapShapes(box, TopAbs_FACE, faces);
    TopTools_ListOfShape toRemove;
    toRemove.Append(faces(1));
    BRepOffsetAPI_MakeThickSolid ts;
    ts.MakeThickSolidByJoin(box, toRemove, 1.0, 1e-6);
    printShape("thickSolid/box", ts.IsDone() ? ts.Shape() : TopoDS_Shape());
  }
  catch (...)
  {
    printf("%-34s THREW\n", "thickSolid/box");
  }

  try
  {
    const TopoDS_Shape         cyl = BRepPrimAPI_MakeCylinder(3.0, 8.0).Shape();
    TopTools_IndexedMapOfShape faces;
    TopExp::MapShapes(cyl, TopAbs_FACE, faces);
    TopTools_ListOfShape toRemove;
    toRemove.Append(faces(2));
    BRepOffsetAPI_MakeThickSolid ts;
    ts.MakeThickSolidByJoin(cyl, toRemove, 0.8, 1e-6);
    printShape("thickSolid/cylinder", ts.IsDone() ? ts.Shape() : TopoDS_Shape());
  }
  catch (...)
  {
    printf("%-34s THREW\n", "thickSolid/cylinder");
  }
}

// ---------------------------------------------------------------------------
// Row 3: ShapeUpgrade_UnifySameDomain.cxx:3629 (UnifySameDomainBuilder.build())
// ---------------------------------------------------------------------------

static TopoDS_Shape halvedCylinder()
{
  // A full cylinder cut in two by a plane through its axis, then fused back: the lateral
  // surface arrives as two half-faces on one Geom_CylindricalSurface, so unifying them
  // closes the U period on a base surface that is not a BSpline.
  const TopoDS_Shape cyl  = BRepPrimAPI_MakeCylinder(3.0, 8.0).Shape();
  const TopoDS_Shape tool = BRepPrimAPI_MakeBox(gp_Pnt(-5, -5, -1), 10, 5, 10).Shape();
  BRepAlgoAPI_Cut    cut(cyl, tool);
  BRepAlgoAPI_Fuse   fuse(cut.Shape(), BRepAlgoAPI_Cut(cyl, BRepPrimAPI_MakeBox(gp_Pnt(-5, 0, -1), 10, 5, 10).Shape()).Shape());
  return fuse.Shape();
}

static void unifyCase(const char* label, const TopoDS_Shape& in, bool concatBSplines)
{
  try
  {
    ShapeUpgrade_UnifySameDomain usd(in, Standard_True, Standard_True, concatBSplines);
    usd.Build();
    printShape(label, usd.Shape());
  }
  catch (...)
  {
    printf("%-34s THREW\n", label);
  }
}

static void caseUnify()
{
  printf("\n### row 3: ShapeUpgrade_UnifySameDomain.cxx:3629 (unify same domain)\n");

  const TopoDS_Shape cylHalves = halvedCylinder();
  printShape("unify/cylinderHalves/input", cylHalves);
  unifyCase("unify/cylinderHalves/concat=0", cylHalves, false);
  unifyCase("unify/cylinderHalves/concat=1", cylHalves, true);

  const TopoDS_Shape sphere = BRepPrimAPI_MakeSphere(5.0).Shape();
  unifyCase("unify/sphere/concat=1", sphere, true);

  const TopoDS_Shape torus = BRepPrimAPI_MakeTorus(8.0, 2.0).Shape();
  unifyCase("unify/torus/concat=1", torus, true);

  // Two boxes fused along a shared face: the classic coplanar-face merge, no periodicity.
  const TopoDS_Shape b1 = BRepPrimAPI_MakeBox(10, 6, 4).Shape();
  const TopoDS_Shape b2 = BRepPrimAPI_MakeBox(gp_Pnt(10, 0, 0), 10, 6, 4).Shape();
  unifyCase("unify/twoBoxes/concat=1", BRepAlgoAPI_Fuse(b1, b2).Shape(), true);

  // A cylinder fused to a box: unifying has to deal with a periodic cylindrical face.
  const TopoDS_Shape cyl2 = BRepPrimAPI_MakeCylinder(3.0, 8.0).Shape();
  unifyCase("unify/boxPlusCylinder/concat=1",
            BRepAlgoAPI_Fuse(BRepPrimAPI_MakeBox(gp_Pnt(-5, -5, -2), 10, 10, 2).Shape(), cyl2).Shape(),
            true);

  // The construction site at :3629 needs a base surface that closes in U (or V) WITHOUT
  // being periodic there (Uperiod is taken from IsUPeriodic() at :3244, so every
  // cylinder, sphere, torus and surface of revolution takes the other branch), and that
  // is not already a B-spline. An extrusion of a closed, non-periodic B-spline curve is
  // such a surface: build one, split it in two faces and sew them back together.
  try
  {
    NCollection_Array1<gp_Pnt> poles(1, 9);
    const double               r = 4.0;
    poles(1) = gp_Pnt(r, 0, 0);
    poles(2) = gp_Pnt(r, r, 0);
    poles(3) = gp_Pnt(0, r, 0);
    poles(4) = gp_Pnt(-r, r, 0);
    poles(5) = gp_Pnt(-r, 0, 0);
    poles(6) = gp_Pnt(-r, -r, 0);
    poles(7) = gp_Pnt(0, -r, 0);
    poles(8) = gp_Pnt(r, -r, 0);
    poles(9) = gp_Pnt(r, 0, 0); // closed, but clamped rather than periodic
    NCollection_Array1<double> knots(1, 5);
    knots(1) = 0.0;
    knots(2) = 0.25;
    knots(3) = 0.5;
    knots(4) = 0.75;
    knots(5) = 1.0;
    NCollection_Array1<int> mults(1, 5);
    mults(1) = 3;
    mults(2) = 2;
    mults(3) = 2;
    mults(4) = 2;
    mults(5) = 3;
    Handle(Geom_BSplineCurve) closedCurve = new Geom_BSplineCurve(poles, knots, mults, 2);

    Handle(Geom_SurfaceOfLinearExtrusion) closedExt =
      new Geom_SurfaceOfLinearExtrusion(closedCurve, gp_Dir(0, 0, 1));
    printf("%-34s uClosed=%d uPeriodic=%d\n",
           "unify/closedExtrusion/base",
           (int)closedExt->IsUClosed(),
           (int)closedExt->IsUPeriodic());

    TopoDS_Face f1 = BRepBuilderAPI_MakeFace(closedExt, 0.0, 0.5, 0.0, 5.0, 1e-7).Face();
    TopoDS_Face f2 = BRepBuilderAPI_MakeFace(closedExt, 0.5, 1.0, 0.0, 5.0, 1e-7).Face();
    BRepBuilderAPI_Sewing sew(1e-6);
    sew.Add(f1);
    sew.Add(f2);
    sew.Perform();
    const TopoDS_Shape shell = sew.SewedShape();
    printShape("unify/closedExtrusion/input", shell);
    unifyCase("unify/closedExtrusion/concat=1", shell, true);
  }
  catch (const Standard_Failure& f)
  {
    printf("%-34s THREW %s\n",
           "unify/closedExtrusion",
           f.GetMessageString() ? f.GetMessageString() : "");
  }
}

// ---------------------------------------------------------------------------
// Row 4: GeomLib.cxx:1517 (GeomLib::ExtendSurfByLength)
// ---------------------------------------------------------------------------

static void caseGeomLib()
{
  printf("\n### row 4: GeomLib.cxx:1517 (ExtendSurfByLength)\n");

  // Direct: the entry point itself, on the surface families that are neither already a
  // BSpline nor a trimmed K-part, which is the branch holding the construction site.
  struct Named
  {
    const char*          label;
    Handle(Geom_Surface) surf;
  };

  Handle(Geom_SurfaceOfRevolution) rev =
    new Geom_SurfaceOfRevolution(smoothCurveC2(), gp_Ax1(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)));
  Handle(Geom_SurfaceOfRevolution) revC0 =
    new Geom_SurfaceOfRevolution(cornerCurveC0(), gp_Ax1(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)));
  Handle(Geom_SurfaceOfLinearExtrusion) ext =
    new Geom_SurfaceOfLinearExtrusion(smoothCurveC2(), gp_Dir(0, 1, 0));
  Handle(Geom_OffsetSurface) offSphere =
    new Geom_OffsetSurface(new Geom_SphericalSurface(gp_Ax3(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 5.0), 1.0);

  Named cases[] = {
    {"geomLib/revolutionC2", new Geom_RectangularTrimmedSurface(rev, 0.0, 4.0, 0.0, 1.0)},
    {"geomLib/revolutionC0", new Geom_RectangularTrimmedSurface(revC0, 0.0, 4.0, 0.0, 1.0)},
    {"geomLib/extrusion", new Geom_RectangularTrimmedSurface(ext, 0.0, 1.0, -3.0, 3.0)},
    {"geomLib/offsetSphere", new Geom_RectangularTrimmedSurface(offSphere, 0.0, 4.0, -1.0, 1.0)},
  };

  for (const Named& c : cases)
  {
    for (int inU = 0; inU <= 1; ++inU)
    {
      char label[96];
      snprintf(label, sizeof(label), "%s/inU=%d", c.label, inU);
      try
      {
        Handle(Geom_BoundedSurface) bs = Handle(Geom_BoundedSurface)::DownCast(c.surf->Copy());
        if (bs.IsNull())
        {
          printf("%-34s NOT-BOUNDED\n", label);
          continue;
        }
        GeomLib::ExtendSurfByLength(bs, 1.0, 1, inU == 1, Standard_True);
        printSurface(label, bs);
      }
      catch (...)
      {
        printf("%-34s THREW\n", label);
      }
    }
  }

  // Indirect: the kernel paths that reach ExtendSurfByLength on this package's behalf are
  // BRepFill_Sweep (sweeps), BRepOffset (offset / thick solid) and ChFi3d (fillets).
  try
  {
    const TopoDS_Shape        box = BRepPrimAPI_MakeBox(10, 6, 4).Shape();
    TopTools_IndexedMapOfShape edges;
    TopExp::MapShapes(box, TopAbs_EDGE, edges);
    BRepFilletAPI_MakeFillet fillet(box);
    for (int i = 1; i <= edges.Extent(); ++i)
      fillet.Add(1.0, TopoDS::Edge(edges(i)));
    fillet.Build();
    printShape("fillet/boxAllEdges", fillet.IsDone() ? fillet.Shape() : TopoDS_Shape());
  }
  catch (...)
  {
    printf("%-34s THREW\n", "fillet/boxAllEdges");
  }

  try
  {
    const TopoDS_Shape        cyl = BRepPrimAPI_MakeCylinder(3.0, 8.0).Shape();
    TopTools_IndexedMapOfShape edges;
    TopExp::MapShapes(cyl, TopAbs_EDGE, edges);
    BRepFilletAPI_MakeFillet fillet(cyl);
    for (int i = 1; i <= edges.Extent(); ++i)
      fillet.Add(0.8, TopoDS::Edge(edges(i)));
    fillet.Build();
    printShape("fillet/cylinderAllEdges", fillet.IsDone() ? fillet.Shape() : TopoDS_Shape());
  }
  catch (...)
  {
    printf("%-34s THREW\n", "fillet/cylinderAllEdges");
  }
}

// ---------------------------------------------------------------------------
// Row 5: GeomConvert_1.cxx:786 and :960 (Surface.toBSpline and friends)
// ---------------------------------------------------------------------------

static void toBSplineCase(const char* label, const Handle(Geom_Surface)& s)
{
  try
  {
    Handle(Geom_BSplineSurface) bs = GeomConvert::SurfaceToBSplineSurface(s);
    printSurface(label, bs);
  }
  catch (const Standard_Failure& f)
  {
    printf("%-34s THREW %s\n", label, f.GetMessageString() ? f.GetMessageString() : "");
  }
  catch (...)
  {
    printf("%-34s THREW\n", label);
  }
}

static void caseGeomConvert()
{
  printf("\n### row 5: GeomConvert_1.cxx:786/:960 (Surface.toBSpline)\n");

  Handle(Geom_SurfaceOfRevolution) revC2 =
    new Geom_SurfaceOfRevolution(smoothCurveC2(), gp_Ax1(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)));
  Handle(Geom_SurfaceOfRevolution) revC0 =
    new Geom_SurfaceOfRevolution(cornerCurveC0(), gp_Ax1(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)));
  Handle(Geom_SurfaceOfLinearExtrusion) extC2 =
    new Geom_SurfaceOfLinearExtrusion(smoothCurveC2(), gp_Dir(0, 1, 0));
  Handle(Geom_SurfaceOfLinearExtrusion) extC0 =
    new Geom_SurfaceOfLinearExtrusion(cornerCurveC0(), gp_Dir(0, 1, 0));

  // :960, the "direct" case. A surface of revolution over a bounded curve is finite, so
  // it reaches SurfaceToBSplineSurface untrimmed, and its continuity in V is the basis
  // curve's: C2 for the smooth curve, C0 for the corner one.
  toBSplineCase("toBSpline/revolutionC2", revC2);
  toBSplineCase("toBSpline/revolutionC0", revC0);

  // :786, the Geom_RectangularTrimmedSurface case, which asks for C1 or C2 and never C0.
  toBSplineCase("toBSpline/trimRevolutionC2",
                new Geom_RectangularTrimmedSurface(revC2, 0.0, 4.0, 0.0, 1.0));
  toBSplineCase("toBSpline/trimRevolutionC0",
                new Geom_RectangularTrimmedSurface(revC0, 0.0, 4.0, 0.0, 1.0));
  toBSplineCase("toBSpline/trimExtrusionC2",
                new Geom_RectangularTrimmedSurface(extC2, 0.0, 1.0, -3.0, 3.0));
  toBSplineCase("toBSpline/trimExtrusionC0",
                new Geom_RectangularTrimmedSurface(extC0, 0.0, 1.0, -3.0, 3.0));

  // Offset surfaces, trimmed and not.
  Handle(Geom_OffsetSurface) offSphere =
    new Geom_OffsetSurface(new Geom_SphericalSurface(gp_Ax3(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 5.0), 1.0);
  toBSplineCase("toBSpline/offsetSphere", offSphere);
  toBSplineCase("toBSpline/trimOffsetSphere",
                new Geom_RectangularTrimmedSurface(offSphere, 0.0, 4.0, -1.0, 1.0));

  // Geom_OffsetSurface refuses a basis surface that is not C1, so the offset of the
  // corner revolution cannot be built at all, so construct it inside the guard.
  try
  {
    Handle(Geom_OffsetSurface) offRevC0 = new Geom_OffsetSurface(revC0, 0.7);
    toBSplineCase("toBSpline/offsetRevolutionC0", offRevC0);
  }
  catch (const Standard_Failure& f)
  {
    printf("%-34s CONSTRUCT-THREW %s\n",
           "toBSpline/offsetRevolutionC0",
           f.GetMessageString() ? f.GetMessageString() : "");
  }

  // An offset of the smooth revolution is buildable, and is the shape a caller reaches
  // through Surface.offset(distance:).toBSpline().
  try
  {
    Handle(Geom_OffsetSurface) offRevC2 = new Geom_OffsetSurface(revC2, 0.7);
    toBSplineCase("toBSpline/offsetRevolutionC2", offRevC2);
    toBSplineCase("toBSpline/trimOffsetRevolutionC2",
                  new Geom_RectangularTrimmedSurface(offRevC2, 0.0, 4.0, 0.0, 1.0));
  }
  catch (const Standard_Failure& f)
  {
    printf("%-34s CONSTRUCT-THREW %s\n",
           "toBSpline/offsetRevolutionC2",
           f.GetMessageString() ? f.GetMessageString() : "");
  }

  // :960 decides its continuity request from the surface's own IsCNu/IsCNv, starting at
  // GeomAbs_C0 and rising only if the surface is C1 or C2 there. A Geom_OffsetSurface
  // reports IsCNu(N) as its basis surface's IsCNu(N + 1), so offsetting a B-spline that
  // is C1 but not C2 in U produces a surface whose U request is C0, the continuity the
  // #522 collapse lives at.
  try
  {
    NCollection_Array2<gp_Pnt> poles(1, 6, 1, 4);
    for (int i = 1; i <= 6; ++i)
      for (int j = 1; j <= 4; ++j)
        poles(i, j) = gp_Pnt(i * 1.5, j * 1.5, ((i * j) % 5) * 0.6);
    NCollection_Array1<double> uknots(1, 3);
    uknots(1) = 0.0;
    uknots(2) = 0.5;
    uknots(3) = 1.0;
    NCollection_Array1<int> umults(1, 3);
    umults(1) = 4;
    umults(2) = 2; // degree 3 with multiplicity 2: C1 in U, not C2
    umults(3) = 4;
    NCollection_Array1<double> vknots(1, 2);
    vknots(1) = 0.0;
    vknots(2) = 1.0;
    NCollection_Array1<int> vmults(1, 2);
    vmults(1) = 4;
    vmults(2) = 4;
    Handle(Geom_BSplineSurface) c1InU =
      new Geom_BSplineSurface(poles, uknots, vknots, umults, vmults, 3, 3);
    printf("%-34s isCNu1=%d isCNu2=%d isCNv2=%d\n",
           "toBSpline/c1InU/base",
           (int)c1InU->IsCNu(1),
           (int)c1InU->IsCNu(2),
           (int)c1InU->IsCNv(2));

    Handle(Geom_OffsetSurface) offC1InU = new Geom_OffsetSurface(c1InU, 0.6);
    printf("%-34s isCNu1=%d isCNv1=%d\n",
           "toBSpline/offsetC1InU/base",
           (int)offC1InU->IsCNu(1),
           (int)offC1InU->IsCNv(1));
    toBSplineCase("toBSpline/offsetC1InU", offC1InU);
    toBSplineCase("toBSpline/trimOffsetC1InU",
                  new Geom_RectangularTrimmedSurface(offC1InU, 0.1, 0.9, 0.1, 0.9));
  }
  catch (const Standard_Failure& f)
  {
    printf("%-34s CONSTRUCT-THREW %s\n",
           "toBSpline/offsetC1InU",
           f.GetMessageString() ? f.GetMessageString() : "");
  }

  // Analytic families, for the contrast: these never reach the approximator.
  toBSplineCase("toBSpline/sphere",
                new Geom_SphericalSurface(gp_Ax3(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 5.0));
  toBSplineCase("toBSpline/torus",
                new Geom_ToroidalSurface(gp_Ax3(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 8.0, 2.0));
  toBSplineCase("toBSpline/trimCylinder",
                new Geom_RectangularTrimmedSurface(
                  new Geom_CylindricalSurface(gp_Ax3(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 3.0),
                  0.0,
                  6.0,
                  0.0,
                  4.0));
}

// ---------------------------------------------------------------------------
// Direction of travel: run each reached site's own approximation request on its own
// input, and put the error OCCT reports next to the deviation actually there.
// ---------------------------------------------------------------------------

static void approxAndMeasure(const char*                 label,
                             const Handle(Geom_Surface)& s,
                             double                      tol,
                             GeomAbs_Shape               uc,
                             GeomAbs_Shape               vc,
                             int                         degU,
                             int                         degV,
                             int                         nmax,
                             int                         prec)
{
  try
  {
    GeomConvert_ApproxSurface approx(s, tol, uc, vc, degU, degV, nmax, prec);
    if (!approx.HasResult())
    {
      printf("%-34s isDone=%d hasResult=0\n", label, (int)approx.IsDone());
      return;
    }
    Handle(Geom_BSplineSurface) fit = approx.Surface();

    double su0, su1, sv0, sv1, fu0, fu1, fv0, fv1;
    s->Bounds(su0, su1, sv0, sv1);
    fit->Bounds(fu0, fu1, fv0, fv1);

    // Two deviation measures, because the first one alone cannot tell a bad fit from a
    // re-parameterised one:
    //   paramDev: same normalised parameters on both surfaces. GeomConvert_ApproxSurface
    //              keeps the source's parameter range, so this is what the approximator's
    //              own error model is about.
    //   projDev:  nearest point on the fit to each sampled source point. Independent of
    //              parameterisation, so it measures the shape and nothing else.
    double worst = 0.0, worstU = 0.0, worstV = 0.0, worstProj = 0.0;
    for (int i = 0; i <= 20; ++i)
    {
      for (int j = 0; j <= 20; ++j)
      {
        const double a = i / 20.0, b = j / 20.0;
        gp_Pnt       p = s->Value(su0 + (su1 - su0) * a, sv0 + (sv1 - sv0) * b);
        gp_Pnt       q = fit->Value(fu0 + (fu1 - fu0) * a, fv0 + (fv1 - fv0) * b);
        const double d = p.Distance(q);
        if (d > worst)
        {
          worst  = d;
          worstU = su0 + (su1 - su0) * a;
          worstV = sv0 + (sv1 - sv0) * b;
        }
        GeomAPI_ProjectPointOnSurf proj(p, fit, fu0, fu1, fv0, fv1);
        if (proj.IsDone() && proj.NbPoints() > 0 && proj.LowerDistance() > worstProj)
          worstProj = proj.LowerDistance();
      }
    }
    printf("%-34s isDone=%d tol=%g maxError=%.6g paramDev=%.6g projDev=%.6g ratio=%.4g "
           "deg=%dx%d poles=%dx%d worstAt=(%.4g,%.4g) srcU[%g %g]V[%g %g] "
           "fitU[%g %g]V[%g %g]\n",
           label,
           (int)approx.IsDone(),
           tol,
           approx.MaxError(),
           worst,
           worstProj,
           approx.MaxError() > 0 ? worstProj / approx.MaxError() : -1.0,
           fit->UDegree(),
           fit->VDegree(),
           fit->NbUPoles(),
           fit->NbVPoles(),
           worstU,
           worstV,
           su0,
           su1,
           sv0,
           sv1,
           fu0,
           fu1,
           fv0,
           fv1);
  }
  catch (const Standard_Failure& f)
  {
    printf("%-34s THREW %s\n", label, f.GetMessageString() ? f.GetMessageString() : "");
  }
  catch (...)
  {
    printf("%-34s THREW\n", label);
  }
}

// The surface carried by the first B-spline face of a shape, which is what the sweep
// sites hand to the approximator.
static Handle(Geom_Surface) firstBSplineFaceSurface(const TopoDS_Shape& sh)
{
  TopTools_IndexedMapOfShape faces;
  TopExp::MapShapes(sh, TopAbs_FACE, faces);
  for (int i = 1; i <= faces.Extent(); ++i)
  {
    TopLoc_Location      loc;
    Handle(Geom_Surface) s = BRep_Tool::Surface(TopoDS::Face(faces(i)), loc);
    if (!Handle(Geom_BSplineSurface)::DownCast(s).IsNull())
      return s;
  }
  return Handle(Geom_Surface)();
}

// Max distance from a grid of points on `truth` to the nearest point on `candidate`.
static double deviationBetween(const Handle(Geom_Surface)& truth,
                               const Handle(Geom_Surface)& candidate)
{
  if (truth.IsNull() || candidate.IsNull())
    return -1.0;
  double tu0, tu1, tv0, tv1, cu0, cu1, cv0, cv1;
  truth->Bounds(tu0, tu1, tv0, tv1);
  candidate->Bounds(cu0, cu1, cv0, cv1);
  double worst = 0.0;
  for (int i = 0; i <= 20; ++i)
    for (int j = 0; j <= 20; ++j)
    {
      gp_Pnt p = truth->Value(tu0 + (tu1 - tu0) * i / 20.0, tv0 + (tv1 - tv0) * j / 20.0);
      GeomAPI_ProjectPointOnSurf proj(p, candidate, cu0, cu1, cv0, cv1);
      if (proj.IsDone() && proj.NbPoints() > 0 && proj.LowerDistance() > worst)
        worst = proj.LowerDistance();
    }
  return worst;
}

// End to end for row 1: how far the shell BRepOffsetAPI_MakePipeShell returns with
// ForceApproxC1 on sits from the one it returns with ForceApproxC1 off, which is the
// surface the C1 conversion is approximating.
static void caseSweepEndToEnd()
{
  printf("\n### end to end: the forced-C1 pipe shell against the un-forced one\n");

  NCollection_Array1<gp_Pnt> poles(1, 5);
  poles(1) = gp_Pnt(0, 0, 0);
  poles(2) = gp_Pnt(0, 0, 4);
  poles(3) = gp_Pnt(0, 0, 8);
  poles(4) = gp_Pnt(4, 0, 11);
  poles(5) = gp_Pnt(9, 0, 13);
  NCollection_Array1<double> knots(1, 3);
  knots(1) = 0.0;
  knots(2) = 0.5;
  knots(3) = 1.0;
  NCollection_Array1<int> mults(1, 3);
  mults(1) = 3;
  mults(2) = 2;
  mults(3) = 3;
  BRepBuilderAPI_MakeEdge me(new Geom_BSplineCurve(poles, knots, mults, 2));
  BRepBuilderAPI_MakeWire mw(me.Edge());
  const TopoDS_Wire       spine = mw.Wire();

  auto build = [&](bool force) -> TopoDS_Shape {
    BRepOffsetAPI_MakePipeShell ps(spine);
    ps.SetMode(Standard_True);
    ps.SetForceApproxC1(force ? Standard_True : Standard_False);
    ps.Add(circleWire(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 1.0), Standard_False, Standard_False);
    ps.SetIsBuildHistory(Standard_False);
    ps.Build();
    return ps.IsDone() ? ps.Shape() : TopoDS_Shape();
  };

  try
  {
    const TopoDS_Shape   plain  = build(false);
    const TopoDS_Shape   forced = build(true);
    Handle(Geom_Surface) sPlain = firstBSplineFaceSurface(plain);
    Handle(Geom_Surface) sForce = firstBSplineFaceSurface(forced);
    GProp_GProps         vpPlain, vpForce;
    BRepGProp::VolumeProperties(plain, vpPlain);
    BRepGProp::VolumeProperties(forced, vpForce);
    printf("%-34s devPlainToForced=%.6g devForcedToPlain=%.6g volPlain=%.9g volForced=%.9g\n",
           "e2e/pipeShellForceApproxC1",
           deviationBetween(sPlain, sForce),
           deviationBetween(sForce, sPlain),
           vpPlain.Mass(),
           vpForce.Mass());
  }
  catch (...)
  {
    printf("%-34s THREW\n", "e2e/pipeShellForceApproxC1");
  }
}

static void caseDirection()
{
  printf("\n### direction: each reached site's own request, reported error vs real deviation\n");

  // Row 1's input: the swept surface GeomFill_Sweep hands to the converter when
  // ForceApproxC1 is on, which is exactly the surface the un-forced sweep returns.
  {
    NCollection_Array1<gp_Pnt> poles(1, 5);
    poles(1) = gp_Pnt(0, 0, 0);
    poles(2) = gp_Pnt(0, 0, 4);
    poles(3) = gp_Pnt(0, 0, 8);
    poles(4) = gp_Pnt(4, 0, 11);
    poles(5) = gp_Pnt(9, 0, 13);
    NCollection_Array1<double> knots(1, 3);
    knots(1) = 0.0;
    knots(2) = 0.5;
    knots(3) = 1.0;
    NCollection_Array1<int> mults(1, 3);
    mults(1) = 3;
    mults(2) = 2;
    mults(3) = 3;
    BRepBuilderAPI_MakeEdge me(new Geom_BSplineCurve(poles, knots, mults, 2));
    BRepBuilderAPI_MakeWire mw(me.Edge());
    try
    {
      BRepOffsetAPI_MakePipeShell ps(mw.Wire());
      ps.SetMode(Standard_True);
      ps.SetForceApproxC1(Standard_False);
      ps.Add(circleWire(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 1.0), Standard_False, Standard_False);
      ps.SetIsBuildHistory(Standard_False);
      ps.Build();
      Handle(Geom_Surface) swept = firstBSplineFaceSurface(ps.Shape());
      if (!swept.IsNull())
        approxAndMeasure("dir/sweptSurface(C1,1e-4,nmax16)",
                         swept,
                         1.e-4,
                         GeomAbs_C1,
                         GeomAbs_C1,
                         14,
                         14,
                         16,
                         1);
    }
    catch (...)
    {
      printf("%-34s THREW\n", "dir/sweptSurface");
    }
  }

  // Row 4's input, at GeomLib::ExtendSurfByLength's own tolerance.
  {
    Handle(Geom_SurfaceOfRevolution) revC0 =
      new Geom_SurfaceOfRevolution(cornerCurveC0(), gp_Ax1(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)));
    approxAndMeasure("dir/revolutionC0(C1,1e-7,nmax16)",
                     new Geom_RectangularTrimmedSurface(revC0, 0.0, 4.0, 0.0, 1.0),
                     Precision::Confusion(),
                     GeomAbs_C1,
                     GeomAbs_C1,
                     14,
                     14,
                     16,
                     1);
    Handle(Geom_SurfaceOfRevolution) revC2 =
      new Geom_SurfaceOfRevolution(smoothCurveC2(), gp_Ax1(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)));
    approxAndMeasure("dir/revolutionC2(C1,1e-7,nmax16)",
                     new Geom_RectangularTrimmedSurface(revC2, 0.0, 4.0, 0.0, 1.0),
                     Precision::Confusion(),
                     GeomAbs_C1,
                     GeomAbs_C1,
                     14,
                     14,
                     16,
                     1);
  }

  // Row 5's two inputs, at GeomConvert_1's own tolerance and continuity choices.
  {
    NCollection_Array2<gp_Pnt> poles(1, 6, 1, 4);
    for (int i = 1; i <= 6; ++i)
      for (int j = 1; j <= 4; ++j)
        poles(i, j) = gp_Pnt(i * 1.5, j * 1.5, ((i * j) % 5) * 0.6);
    NCollection_Array1<double> uknots(1, 3);
    uknots(1) = 0.0;
    uknots(2) = 0.5;
    uknots(3) = 1.0;
    NCollection_Array1<int> umults(1, 3);
    umults(1) = 4;
    umults(2) = 2;
    umults(3) = 4;
    NCollection_Array1<double> vknots(1, 2);
    vknots(1) = 0.0;
    vknots(2) = 1.0;
    NCollection_Array1<int> vmults(1, 2);
    vmults(1) = 4;
    vmults(2) = 4;
    try
    {
      Handle(Geom_OffsetSurface) off = new Geom_OffsetSurface(
        new Geom_BSplineSurface(poles, uknots, vknots, umults, vmults, 3, 3),
        0.6);
      // :960's own request for this surface: C0 in U (IsCNu(1) is false), C2 in V.
      approxAndMeasure("dir/offsetC1InU(C0/C2,1e-4,nmax24)",
                       off,
                       1.e-4,
                       GeomAbs_C0,
                       GeomAbs_C2,
                       14,
                       14,
                       24,
                       1);
      // :786's request for the trimmed form of the same surface.
      approxAndMeasure("dir/trimOffsetC1InU(C1,1e-4,nmax24)",
                       new Geom_RectangularTrimmedSurface(off, 0.1, 0.9, 0.1, 0.9),
                       1.e-4,
                       GeomAbs_C1,
                       GeomAbs_C1,
                       14,
                       14,
                       24,
                       1);
    }
    catch (...)
    {
      printf("%-34s THREW\n", "dir/offsetC1InU");
    }
  }

  // Row 3's input: the closed, non-periodic extrusion the unifier converts.
  {
    NCollection_Array1<gp_Pnt> poles(1, 9);
    const double               r = 4.0;
    poles(1) = gp_Pnt(r, 0, 0);
    poles(2) = gp_Pnt(r, r, 0);
    poles(3) = gp_Pnt(0, r, 0);
    poles(4) = gp_Pnt(-r, r, 0);
    poles(5) = gp_Pnt(-r, 0, 0);
    poles(6) = gp_Pnt(-r, -r, 0);
    poles(7) = gp_Pnt(0, -r, 0);
    poles(8) = gp_Pnt(r, -r, 0);
    poles(9) = gp_Pnt(r, 0, 0);
    NCollection_Array1<double> knots(1, 5);
    knots(1) = 0.0;
    knots(2) = 0.25;
    knots(3) = 0.5;
    knots(4) = 0.75;
    knots(5) = 1.0;
    NCollection_Array1<int> mults(1, 5);
    mults(1) = 3;
    mults(2) = 2;
    mults(3) = 2;
    mults(4) = 2;
    mults(5) = 3;
    Handle(Geom_SurfaceOfLinearExtrusion) ext = new Geom_SurfaceOfLinearExtrusion(
      new Geom_BSplineCurve(poles, knots, mults, 2),
      gp_Dir(0, 0, 1));
    approxAndMeasure("dir/closedExtrusion(C1,1e-4,nmax16)",
                     new Geom_RectangularTrimmedSurface(ext, 0.0, 1.0, 0.0, 5.0),
                     1.e-4,
                     GeomAbs_C1,
                     GeomAbs_C1,
                     14,
                     14,
                     16,
                     1);
  }
}

int main()
{
  // Unbuffered, so a probe writing to stderr interleaves with these lines in order.
  setvbuf(stdout, nullptr, _IONBF, 0);
  // The boolean and offset paths are otherwise free to reorder their own work between
  // runs of the same binary, which shows up as a moving fingerprint.
  BOPAlgo_Options::SetParallelMode(Standard_False);
  printf("=== OCCTSwift #572: GeomConvert_ApproxSurface consumers, fingerprinted ===\n");
  caseSweep();
  caseOffset();
  caseUnify();
  caseGeomLib();
  caseGeomConvert();
  caseDirection();
  caseSweepEndToEnd();
  printf("\n=== done ===\n");
  return 0;
}
