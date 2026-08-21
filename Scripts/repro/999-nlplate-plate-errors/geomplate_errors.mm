// Ground truth for #999 site 2: OCCTGeomPlateErrors declares maxDegree and maxSegments and
// hardcodes GeomPlate_BuildPlateSurface builder(3, 10, 5, tolerance), then reports the builder's
// own G0Error/G1Error/G2Error. Two questions this answers.
//
// 1. Are maxDegree/maxSegments knobs of this computation at all? In the sibling
//    OCCTGeomPlateSurface they are forwarded to GeomPlate_MakeApprox (Nbmax, dgmax) for the
//    BSpline fit that follows the plate build. This function performs no fit.
// 2. Does anything the caller supplies move the reported errors? The one parameter that is read,
//    `tolerance`, lands in the constructor's FOURTH slot, which is Tol2d, not Tol3d.
#include <GeomPlate_BuildPlateSurface.hxx>
#include <GeomPlate_MakeApprox.hxx>
#include <GeomPlate_PointConstraint.hxx>
#include <GeomPlate_Surface.hxx>
#include <Geom_BSplineSurface.hxx>
#include <Message_ProgressRange.hxx>
#include <gp_Pnt.hxx>
#include <cstdio>

namespace
{

// A wavy 5x5 grid of points, so the plate has something to deviate from.
struct Pt
{
  double x, y, z;
};
Pt points[25];

void fillPoints()
{
  int k = 0;
  for (int i = 0; i < 5; i++)
    for (int j = 0; j < 5; j++)
    {
      double x     = i * 2.5;
      double y     = j * 2.5;
      points[k++] = {x, y, 2.0 * ((i + j) % 2 ? 1.0 : -1.0) + 0.35 * x - 0.2 * y};
    }
}

void build(GeomPlate_BuildPlateSurface& builder, double pointTol)
{
  for (const Pt& p : points)
    builder.Add(new GeomPlate_PointConstraint(gp_Pnt(p.x, p.y, p.z), 0, pointTol));
  builder.Perform(Message_ProgressRange());
}

void report(const char* label, GeomPlate_BuildPlateSurface& builder)
{
  if (!builder.IsDone())
  {
    printf("%-42s NOT DONE\n", label);
    return;
  }
  printf("%-42s G0=%.12g G1=%.12g G2=%.12g\n",
         label,
         builder.G0Error(),
         builder.G1Error(),
         builder.G2Error());
}

} // namespace

int main()
{
  fillPoints();

  printf("--- what the bridge builds today, at three caller tolerances ---\n");
  for (double tol : {1e-1, 1e-3, 1e-6})
  {
    GeomPlate_BuildPlateSurface builder(3, 10, 5, tol);
    build(builder, tol);
    char label[96];
    snprintf(label, sizeof(label), "builder(3, 10, 5, Tol2d=%g)", tol);
    report(label, builder);
  }

  printf("\n--- the constructor slot the caller's tolerance actually lands in ---\n");
  {
    GeomPlate_BuildPlateSurface builder(3, 10, 5, 1e-5, 1e-1);
    build(builder, 1e-3);
    report("builder(3, 10, 5, Tol2d=1e-5, Tol3d=1e-1)", builder);
  }
  {
    GeomPlate_BuildPlateSurface builder(3, 10, 5, 1e-5, 1e-6);
    build(builder, 1e-3);
    report("builder(3, 10, 5, Tol2d=1e-5, Tol3d=1e-6)", builder);
  }

  printf("\n--- the builder's own Degree, which is NOT the approximation's maxDegree ---\n");
  for (int degree : {3, 5, 8})
  {
    GeomPlate_BuildPlateSurface builder(degree, 10, 5, 1e-3);
    build(builder, 1e-3);
    char label[96];
    snprintf(label, sizeof(label), "builder(Degree=%d, 10, 5, 1e-3)", degree);
    report(label, builder);
  }

  printf("\n--- do the approximation's own knobs move the builder's reported errors? ---\n");
  {
    GeomPlate_BuildPlateSurface builder(3, 10, 5, 1e-3);
    build(builder, 1e-3);
    report("before any GeomPlate_MakeApprox", builder);
    Handle(GeomPlate_Surface) plate = builder.Surface();
    for (int nbMax : {2, 20})
      for (int dgMax : {3, 8})
      {
        GeomPlate_MakeApprox approx(plate, 1e-3, nbMax, dgMax, 1e-4, 0, GeomAbs_C1);
        Handle(Geom_BSplineSurface) s = approx.Surface();
        char label[96];
        snprintf(label, sizeof(label),
                 "after MakeApprox(Nbmax=%d, dgmax=%d)", nbMax, dgMax);
        printf("%-42s poles=%dx%d approxErr=%.12g -> ",
               label,
               s.IsNull() ? 0 : s->NbUPoles(),
               s.IsNull() ? 0 : s->NbVPoles(),
               approx.ApproxError());
        printf("G0=%.12g G1=%.12g G2=%.12g\n",
               builder.G0Error(),
               builder.G1Error(),
               builder.G2Error());
      }
  }
  return 0;
}
