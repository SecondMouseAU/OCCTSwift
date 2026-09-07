// #1399, healing family: the four behaviour claims no attribution detector can see.
//
// Each block replicates one bridge function's exact call sequence against the pinned kernel,
// so what is measured is the code path the Swift entry point runs, not a paraphrase of it.
// Build per CLAUDE.md's "Compile a Ground Truth C++ Test".

#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepLib.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <BRep_Builder.hxx>
#include <BRep_Tool.hxx>
#include <GeomAbs_Shape.hxx>
#include <Geom_BSplineSurface.hxx>
#include <Geom_CylindricalSurface.hxx>
#include <Geom_Plane.hxx>
#include <Geom_Surface.hxx>
#include <Geom_SurfaceOfRevolution.hxx>
#include <NCollection_HArray2.hxx>
#include <ShapeAnalysis_Geom.hxx>
#include <ShapeBuild_ReShape.hxx>
#include <ShapeCustom.hxx>
#include <ShapeCustom_RestrictionParameters.hxx>
#include <ShapeExtend_CompositeSurface.hxx>
#include <ShapeFix_ComposeShell.hxx>
#include <TColgp_Array1OfPnt.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Edge.hxx>
#include <TopoDS_Face.hxx>
#include <gp_Pln.hxx>

#include <cstdio>

static int faceCount(const TopoDS_Shape& s)
{
  int n = 0;
  for (TopExp_Explorer e(s, TopAbs_FACE); e.More(); e.Next())
    n++;
  return n;
}

// 1. Shape.updateEdgeTolerance(edge:tolerance:) -> OCCTBRepLibUpdateEdgeTolerance
//    -> BRepLib::UpdateEdgeTol(edge, tol, tol * 100.0).
//    docs/reference/Document-BSpline-Extrema.md called this "force the tolerance of a specific
//    edge to the given value" and attributed it to BRepLib::UpdateEdgeTolerance.
static void probeUpdateEdgeTol()
{
  printf("=== 1. BRepLib::UpdateEdgeTol, is the requested tolerance forced onto the edge?\n");
  TopoDS_Shape box = BRepPrimAPI_MakeBox(10.0, 10.0, 10.0).Shape();
  TopExp_Explorer exp(box, TopAbs_EDGE);
  TopoDS_Edge     edge = TopoDS::Edge(exp.Current());

  // Second construction: two different edges (a box edge and a free line edge built with no
  // face attached) and four requested values spanning both sides of the edge's own tolerance.
  TopoDS_Edge free =
    BRepBuilderAPI_MakeEdge(gp_Pnt(0, 0, 0), gp_Pnt(10, 0, 0)).Edge();

  const double asked[] = {1e-9, 1e-5, 0.5, 2.0};
  const struct
  {
    const char* name;
    TopoDS_Edge e;
  } subjects[] = {{"box edge", edge}, {"free line edge", free}};

  for (const auto& subject : subjects)
  {
    for (double a : asked)
    {
      TopoDS_Edge  e      = subject.e;
      const double before = BRep_Tool::Tolerance(e);
      const bool   ret    = BRepLib::UpdateEdgeTol(e, a, a * 100.0);
      const double after  = BRep_Tool::Tolerance(e);
      printf("   %-15s asked %-8g before %-10g returned %-5s after %-10g forced: %s\n",
             subject.name, a, before, ret ? "true" : "false", after,
             (after == a) ? "YES" : "NO");
    }
  }
  printf("\n");
}

// 2. Shape.composeShell(precision:) -> OCCTShapeFixComposeShell, which wraps the face's own
//    surface in a 1x1 ShapeExtend_CompositeSurface grid.
//    docs/reference/Shape-Completions.md called it "splits a face into sub-faces".
static void probeComposeShell()
{
  printf("=== 2. ShapeFix_ComposeShell on a 1x1 grid, does the face split?\n");
  TopoDS_Shape cyl = BRepPrimAPI_MakeCylinder(5.0, 10.0).Shape();
  TopoDS_Face  face;
  for (TopExp_Explorer e(cyl, TopAbs_FACE); e.More(); e.Next())
  {
    TopoDS_Face f = TopoDS::Face(e.Current());
    if (Handle(Geom_CylindricalSurface)::DownCast(BRep_Tool::Surface(f)))
    {
      face = f;
      break;
    }
  }
  if (face.IsNull())
  {
    printf("   no cylindrical face found\n\n");
    return;
  }

  Handle(Geom_Surface) surf = BRep_Tool::Surface(face);
  Handle(NCollection_HArray2<Handle(Geom_Surface)>) grid =
    new NCollection_HArray2<Handle(Geom_Surface)>(1, 1, 1, 1);
  grid->SetValue(1, 1, surf);
  Handle(ShapeExtend_CompositeSurface) comp = new ShapeExtend_CompositeSurface(grid);

  Handle(ShapeFix_ComposeShell) cs = new ShapeFix_ComposeShell();
  cs->SetContext(new ShapeBuild_ReShape());
  cs->Init(comp, TopLoc_Location(), face, 1e-6);
  const bool ok = cs->Perform();
  printf("   Perform()               : %s\n", ok ? "true" : "false");
  if (ok && !cs->Result().IsNull())
    printf("   faces in: 1, faces out  : %d\n", faceCount(cs->Result()));
  printf("   grid patches            : %d x %d\n", comp->NbUPatches(), comp->NbVPatches());
  printf("\n");
}

// 3. Shape.bsplineRestriction(...) -> OCCTShapeBSplineRestriction, which passes a default-built
//    ShapeCustom_RestrictionParameters.  docs/reference/Shape-Healing.md said "each geometry is
//    approximated as a BSpline".  The defaults leave the elementary surfaces alone.
static void probeBSplineRestriction()
{
  printf("=== 3. ShapeCustom::BSplineRestriction with default RestrictionParameters\n");
  Handle(ShapeCustom_RestrictionParameters) p = new ShapeCustom_RestrictionParameters();
  printf("   ConvertPlane            : %s\n", p->ConvertPlane() ? "true" : "false");
  printf("   ConvertCylindricalSurf  : %s\n", p->ConvertCylindricalSurf() ? "true" : "false");
  printf("   ConvertConicalSurf      : %s\n", p->ConvertConicalSurf() ? "true" : "false");
  printf("   ConvertSphericalSurf    : %s\n", p->ConvertSphericalSurf() ? "true" : "false");
  printf("   ConvertToroidalSurf     : %s\n", p->ConvertToroidalSurf() ? "true" : "false");
  printf("   ConvertBezierSurf       : %s\n", p->ConvertBezierSurf() ? "true" : "false");
  printf("   ConvertRevolutionSurf   : %s\n", p->ConvertRevolutionSurf() ? "true" : "false");
  printf("   ConvertExtrusionSurf    : %s\n", p->ConvertExtrusionSurf() ? "true" : "false");
  printf("   ConvertOffsetSurf       : %s\n", p->ConvertOffsetSurf() ? "true" : "false");
  printf("   GMaxDegree              : %d\n", p->GMaxDegree());
  printf("   GMaxSeg                 : %d\n", p->GMaxSeg());

  TopoDS_Shape cyl = BRepPrimAPI_MakeCylinder(5.0, 10.0).Shape();
  TopoDS_Shape out = ShapeCustom::BSplineRestriction(cyl, 0.01, 0.01, 9, 10000,
                                                     GeomAbs_C1, GeomAbs_C1, true, true, p);
  int elementary = 0, bspline = 0;
  for (TopExp_Explorer e(out, TopAbs_FACE); e.More(); e.Next())
  {
    Handle(Geom_Surface) s = BRep_Tool::Surface(TopoDS::Face(e.Current()));
    if (Handle(Geom_BSplineSurface)::DownCast(s))
      bspline++;
    else
      elementary++;
  }
  printf("   cylinder out: %d BSpline face(s), %d still elementary\n\n", bspline, elementary);
}

// 4. Shape.nearestPlane(to:) -> OCCTShapeNearestPlane -> ShapeAnalysis_Geom::NearestPlane.
//    docs/reference/Shape-Builders-1.md said "least-squares" and attributed it to gp_Pln.
static void probeNearestPlane()
{
  printf("=== 4. ShapeAnalysis_Geom::NearestPlane, least squares?\n");

  struct Case
  {
    const char* name;
    double      pts[8][3];
    int         n;
  };
  // A flat set, a set with one point lifted far off the plane (a least-squares fit would
  // still answer, tilted), and a cube-shaped cloud.
  Case cases[] = {
    {"flat square", {{0, 0, 0}, {10, 0, 0}, {10, 10, 0}, {0, 10, 0}}, 4},
    {"square + one point 3 units off", {{0, 0, 0}, {10, 0, 0}, {10, 10, 0}, {0, 10, 3}}, 4},
    {"square + one point 8 units off", {{0, 0, 0}, {10, 0, 0}, {10, 10, 0}, {0, 10, 8}}, 4},
    {"cube corners",
     {{0, 0, 0}, {10, 0, 0}, {10, 10, 0}, {0, 10, 0},
      {0, 0, 10}, {10, 0, 10}, {10, 10, 10}, {0, 10, 10}}, 8},
  };

  for (const Case& c : cases)
  {
    TColgp_Array1OfPnt pts(1, c.n);
    for (int i = 0; i < c.n; i++)
      pts.SetValue(i + 1, gp_Pnt(c.pts[i][0], c.pts[i][1], c.pts[i][2]));
    gp_Pln pln;
    double dmax = 0;
    const bool ok = ShapeAnalysis_Geom::NearestPlane(pts, pln, dmax);
    printf("   %-32s -> %s", c.name, ok ? "fitted" : "REFUSED");
    if (ok)
      printf(", maxDist %.4f, normal (%.3f, %.3f, %.3f)",
             dmax, pln.Axis().Direction().X(), pln.Axis().Direction().Y(),
             pln.Axis().Direction().Z());
    printf("\n");
  }

  // The refusal rule, swept: a 10 x 10 sheet thickened in Z. NearestPlane refuses unless the
  // smallest principal extent is strictly under half of each of the other two, so the cutoff
  // sits at a thickness of 5 on a 10-wide sheet, nowhere near "not planar".
  printf("   -- refusal sweep, 10 x 10 corners lifted to +z --\n");
  for (double z : {0.0, 1.0, 4.0, 4.9, 5.0, 5.1, 9.0})
  {
    TColgp_Array1OfPnt pts(1, 8);
    const double corners[4][2] = {{0, 0}, {10, 0}, {10, 10}, {0, 10}};
    for (int i = 0; i < 4; i++)
    {
      pts.SetValue(i + 1, gp_Pnt(corners[i][0], corners[i][1], 0.0));
      pts.SetValue(i + 5, gp_Pnt(corners[i][0], corners[i][1], z));
    }
    gp_Pln pln;
    double dmax = 0;
    const bool ok = ShapeAnalysis_Geom::NearestPlane(pts, pln, dmax);
    printf("   thickness %-5g -> %s", z, ok ? "fitted" : "REFUSED");
    if (ok)
      printf(", maxDist %.4f", dmax);
    printf("\n");
  }
  printf("\n");
}

// 5. Shape.revolutionToElementary() -> OCCTShapeRevolutionToElementary
//    -> ShapeCustom::ConvertToRevolution.  Every layer of documentation says the method turns
//    surfaces of revolution INTO elementary surfaces.  The pinned header says the opposite.
static void probeRevolutionToElementary()
{
  printf("=== 5. ShapeCustom::ConvertToRevolution, which direction does it run?\n");
  TopoDS_Shape cyl = BRepPrimAPI_MakeCylinder(5.0, 10.0).Shape();

  auto describe = [](const TopoDS_Shape& s, const char* label) {
    int revol = 0, elementary = 0;
    for (TopExp_Explorer e(s, TopAbs_FACE); e.More(); e.Next())
    {
      Handle(Geom_Surface) surf = BRep_Tool::Surface(TopoDS::Face(e.Current()));
      if (Handle(Geom_SurfaceOfRevolution)::DownCast(surf))
        revol++;
      else
        elementary++;
    }
    printf("   %-28s %d surface(s) of revolution, %d elementary\n", label, revol, elementary);
  };

  describe(cyl, "cylinder, as built:");
  describe(ShapeCustom::ConvertToRevolution(cyl), "after ConvertToRevolution:");
  describe(ShapeCustom::SweptToElementary(ShapeCustom::ConvertToRevolution(cyl)),
           "then SweptToElementary:");
  printf("\n");
}

int main()
{
  probeUpdateEdgeTol();
  probeComposeShell();
  probeBSplineRestriction();
  probeNearestPlane();
  probeRevolutionToElementary();
  return 0;
}
