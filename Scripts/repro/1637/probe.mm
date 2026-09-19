// Ground truth for #1637: ShapeCustom::BSplineRestriction with a ShapeCustom_RestrictionParameters
// the caller has actually set, and what the two global caps (GMaxDegree, GMaxSeg) do next to the
// per-call maxDegree / maxSegments.
//
// Build: see CLAUDE.md, "Compile a Ground Truth C++ Test".

#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <BRepPrimAPI_MakeSphere.hxx>
#include <BRepPrimAPI_MakeTorus.hxx>
#include <BRep_Tool.hxx>
#include <Geom_BSplineSurface.hxx>
#include <ShapeCustom.hxx>
#include <ShapeCustom_RestrictionParameters.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <gp_Pln.hxx>

#include <cstdio>
#include <string>

struct Tally
{
  int bspline = 0;
  int other   = 0;
  int maxDeg  = 0;
  int maxSeg  = 0;
};

static Tally tally(const TopoDS_Shape& s)
{
  Tally t;
  for (TopExp_Explorer e(s, TopAbs_FACE); e.More(); e.Next())
  {
    Handle(Geom_Surface)        surf = BRep_Tool::Surface(TopoDS::Face(e.Current()));
    Handle(Geom_BSplineSurface) bs   = Handle(Geom_BSplineSurface)::DownCast(surf);
    if (bs.IsNull())
      t.other++;
    else
    {
      t.bspline++;
      t.maxDeg = std::max(t.maxDeg, std::max(bs->UDegree(), bs->VDegree()));
      t.maxSeg = std::max(t.maxSeg, std::max(bs->NbUKnots() - 1, bs->NbVKnots() - 1));
    }
  }
  return t;
}

static void run(const char*                                     label,
                const TopoDS_Shape&                             in,
                const Handle(ShapeCustom_RestrictionParameters)& params,
                int                                             maxDegree,
                int                                             maxSegments)
{
  TopoDS_Shape out = ShapeCustom::BSplineRestriction(in, 0.01, 0.01, maxDegree, maxSegments,
                                                     GeomAbs_C1, GeomAbs_C1, true, true, params);
  Tally        t   = tally(out);
  printf("   %-44s -> %d BSpline face(s), %d other; max degree %d, max spans %d\n", label,
         t.bspline, t.other, t.maxDeg, t.maxSeg);
}

static Handle(ShapeCustom_RestrictionParameters) allSurfaceTypes()
{
  Handle(ShapeCustom_RestrictionParameters) p = new ShapeCustom_RestrictionParameters();
  p->ConvertPlane()            = true;
  p->ConvertBezierSurf()       = true;
  p->ConvertRevolutionSurf()   = true;
  p->ConvertExtrusionSurf()    = true;
  p->ConvertOffsetSurf()       = true;
  p->ConvertCylindricalSurf()  = true;
  p->ConvertConicalSurf()      = true;
  p->ConvertToroidalSurf()     = true;
  p->ConvertSphericalSurf()    = true;
  return p;
}

static void dumpDefaults()
{
  Handle(ShapeCustom_RestrictionParameters) p = new ShapeCustom_RestrictionParameters();
  printf("=== 0. every ShapeCustom_RestrictionParameters default, read off the pinned kernel\n");
  printf("   ConvertPlane            %d\n", (int)p->ConvertPlane());
  printf("   ConvertBezierSurf       %d\n", (int)p->ConvertBezierSurf());
  printf("   ConvertRevolutionSurf   %d\n", (int)p->ConvertRevolutionSurf());
  printf("   ConvertExtrusionSurf    %d\n", (int)p->ConvertExtrusionSurf());
  printf("   ConvertOffsetSurf       %d\n", (int)p->ConvertOffsetSurf());
  printf("   ConvertCylindricalSurf  %d\n", (int)p->ConvertCylindricalSurf());
  printf("   ConvertConicalSurf      %d\n", (int)p->ConvertConicalSurf());
  printf("   ConvertToroidalSurf     %d\n", (int)p->ConvertToroidalSurf());
  printf("   ConvertSphericalSurf    %d\n", (int)p->ConvertSphericalSurf());
  printf("   SegmentSurfaceMode      %d\n", (int)p->SegmentSurfaceMode());
  printf("   ConvertCurve3d          %d\n", (int)p->ConvertCurve3d());
  printf("   ConvertOffsetCurv3d     %d\n", (int)p->ConvertOffsetCurv3d());
  printf("   ConvertCurve2d          %d\n", (int)p->ConvertCurve2d());
  printf("   ConvertOffsetCurv2d     %d\n", (int)p->ConvertOffsetCurv2d());
  printf("   GMaxDegree              %d\n", p->GMaxDegree());
  printf("   GMaxSeg                 %d\n\n", p->GMaxSeg());
}

int main()
{
  dumpDefaults();
  TopoDS_Shape cyl    = BRepPrimAPI_MakeCylinder(5.0, 10.0).Shape();
  TopoDS_Shape sphere = BRepPrimAPI_MakeSphere(5.0).Shape();
  TopoDS_Shape torus  = BRepPrimAPI_MakeTorus(10.0, 3.0).Shape();

  printf("=== 1. defaults, which is what both bridge entry points pass today\n");
  run("cylinder, default params", cyl, new ShapeCustom_RestrictionParameters(), 9, 10000);
  run("sphere, default params", sphere, new ShapeCustom_RestrictionParameters(), 9, 10000);
  run("torus, default params", torus, new ShapeCustom_RestrictionParameters(), 9, 10000);

  printf("\n=== 2. every surface-type flag on\n");
  run("cylinder, all flags", cyl, allSurfaceTypes(), 9, 10000);
  run("sphere, all flags", sphere, allSurfaceTypes(), 9, 10000);
  run("torus, all flags", torus, allSurfaceTypes(), 9, 10000);

  printf("\n=== 3. one flag at a time, on the cylinder (2 planes + 1 cylindrical face)\n");
  {
    Handle(ShapeCustom_RestrictionParameters) p = new ShapeCustom_RestrictionParameters();
    p->ConvertCylindricalSurf()                 = true;
    run("cylinder, ConvertCylindricalSurf only", cyl, p, 9, 10000);
  }
  {
    Handle(ShapeCustom_RestrictionParameters) p = new ShapeCustom_RestrictionParameters();
    p->ConvertPlane()                           = true;
    run("cylinder, ConvertPlane only", cyl, p, 9, 10000);
  }

  printf("\n=== 4. SegmentSurfaceMode\n");
  {
    Handle(ShapeCustom_RestrictionParameters) p = allSurfaceTypes();
    p->SegmentSurfaceMode()                     = true;
    run("cylinder, all flags + SegmentSurfaceMode", cyl, p, 9, 10000);
  }

  printf("\n=== 5. GMaxDegree / GMaxSeg next to the per-call maxDegree / maxSegments\n");
  for (int gmax : {3, 5, 15})
  {
    Handle(ShapeCustom_RestrictionParameters) p = allSurfaceTypes();
    p->GMaxDegree()                             = gmax;
    char label[80];
    snprintf(label, sizeof(label), "torus, GMaxDegree %d, call maxDegree 9", gmax);
    run(label, torus, p, 9, 10000);
  }
  for (int call : {3, 5, 9})
  {
    Handle(ShapeCustom_RestrictionParameters) p = allSurfaceTypes();
    char label[80];
    snprintf(label, sizeof(label), "torus, GMaxDegree 15, call maxDegree %d", call);
    run(label, torus, p, call, 10000);
  }
  for (int gseg : {1, 2, 10000})
  {
    Handle(ShapeCustom_RestrictionParameters) p = allSurfaceTypes();
    p->GMaxSeg()                                = gseg;
    char label[80];
    snprintf(label, sizeof(label), "torus, GMaxSeg %d, call maxSegments 10000", gseg);
    run(label, torus, p, 9, 10000);
  }
  return 0;
}
