// Ground truth for #2993: what Extrema_ExtElC / Extrema_ExtElCS hand back on their IsParallel()
// branch, and what OCCT's own production caller (Extrema_ExtCC) does with it.
//
// Build and run: see README.md in this directory.

#include <Extrema_ExtCC.hxx>
#include <Extrema_ExtElC.hxx>
#include <Extrema_ExtElCS.hxx>
#include <Extrema_POnCurv.hxx>
#include <GeomAdaptor_Curve.hxx>
#include <Geom_Circle.hxx>
#include <Geom_Line.hxx>
#include <Precision.hxx>
#include <Standard_Failure.hxx>
#include <gp_Ax2.hxx>
#include <gp_Circ.hxx>
#include <gp_Dir.hxx>
#include <gp_Elips.hxx>
#include <gp_Lin.hxx>
#include <gp_Pln.hxx>
#include <gp_Pnt.hxx>

#include <cmath>
#include <cstdio>

static void dumpPoints(const Extrema_ExtElC& ext)
{
  for (int i = 1; i <= ext.NbExt(); ++i)
  {
    Extrema_POnCurv p1, p2;
    try
    {
      ext.Points(i, p1, p2);
      printf("    Points(%d): p1=(%.9f, %.9f, %.9f) u1=%.9f | p2=(%.9f, %.9f, %.9f) u2=%.9f\n",
             i,
             p1.Value().X(),
             p1.Value().Y(),
             p1.Value().Z(),
             p1.Parameter(),
             p2.Value().X(),
             p2.Value().Y(),
             p2.Value().Z(),
             p2.Parameter());
    }
    catch (const Standard_Failure& f)
    {
      printf("    Points(%d): raised %s\n", i, f.GetMessageString());
    }
  }
}

static void header(const char* label, bool isParallel, int nb, double sqDist)
{
  printf("%s\n  IsParallel=%d NbExt=%d SquareDistance(1)=%.9f (distance %.9f)\n",
         label,
         (int)isParallel,
         nb,
         sqDist,
         std::sqrt(sqDist));
}

int main(int argc, char** argv)
{
  const bool faultOnPurpose = argc > 1;
  (void)argv;
  setvbuf(stdout, nullptr, _IONBF, 0);
  printf("=== Extrema_ExtElC: the parallel branch's witness points ===\n\n");

  // The #2993 fixture: a line along the circle's own axis, circle of radius 5 about the origin.
  {
    gp_Lin         l(gp_Pnt(0, 0, 10), gp_Dir(0, 0, 1));
    gp_Circ        c(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 5.0);
    Extrema_ExtElC ext(l, c, 1e-6);
    header("Line/Circle, line on the circle's axis (ExtremaElCLinCircTests fixture)",
           ext.IsParallel(),
           ext.NbExt(),
           ext.SquareDistance(1));
    dumpPoints(ext);
    printf("  the circle's centre is (0, 0, 0), which is 5 from EVERY point of the circle\n\n");
  }

  // Two parallel lines.
  {
    gp_Lin         l1(gp_Pnt(0, 0, 0), gp_Dir(1, 0, 0));
    gp_Lin         l2(gp_Pnt(0, 3, 0), gp_Dir(1, 0, 0));
    Extrema_ExtElC ext(l1, l2, 1e-6);
    header("Line/Line, parallel 3 apart", ext.IsParallel(), ext.NbExt(), ext.SquareDistance(1));
    dumpPoints(ext);
    printf("\n");
  }

  // Concentric coplanar circles.
  {
    gp_Circ        c1(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 5.0);
    gp_Circ        c2(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 3.0);
    Extrema_ExtElC ext(c1, c2);
    header("Circle/Circle, concentric radii 5 and 3",
           ext.IsParallel(),
           ext.NbExt(),
           ext.SquareDistance(1));
    dumpPoints(ext);
    printf("\n");
  }

  // Line on an ellipse's own axis.
  {
    gp_Lin   l(gp_Pnt(0, 0, 10), gp_Dir(0, 0, 1));
    gp_Ax2   ax(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1), gp_Dir(1, 0, 0));
    gp_Elips e(ax, 5.0, 3.0);
    try
    {
      Extrema_ExtElC ext(l, e);
      header("Line/Ellipse, line on the ellipse's axis",
             ext.IsParallel(),
             ext.NbExt(),
             ext.SquareDistance(1));
      dumpPoints(ext);
    }
    catch (const Standard_Failure& f)
    {
      printf("Line/Ellipse, line on the ellipse's axis: raised %s\n", f.GetMessageString());
    }
    printf("\n");
  }

  // Line parallel to a plane (Extrema_ExtElCS, which already surfaces isParallel to Swift).
  {
    gp_Lin          l(gp_Pnt(0, 0, 4), gp_Dir(1, 0, 0));
    gp_Pln          pl(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1));
    Extrema_ExtElCS ext(l, pl);
    printf("Line/Plane, line parallel to the plane at z = 4\n  IsParallel=%d NbExt=%d "
           "SquareDistance(1)=%.9f\n",
           (int)ext.IsParallel(),
           ext.NbExt(),
           ext.SquareDistance(1));
    // Extrema_ExtElCS::Points is NOT called here by default: on the parallel branch
    // Extrema_ExtElCS.cxx:62-68 allocates mySqDist alone and leaves myPoint1 / myPoint2 as null
    // handles, while NbExt() returns 1, so Points(1, ...) dereferences a null handle. That is an
    // uncatchable SIGSEGV on this build, not a Standard_Failure: measured, the process dies at
    // exit 139 with no output after this line. Run the probe with any argument to see it. It is
    // the shape carried patches 0024 (Extrema_ExtCC) and 0044 (Extrema_ExtSS / ExtCS) fix in two
    // other classes, and Extrema_ExtElCS is a third.
    if (faultOnPurpose)
    {
      Extrema_POnCurv pc;
      Extrema_POnSurf ps;
      printf("    calling Points(1, ...) on the parallel branch, which faults...\n");
      ext.Points(1, pc, ps);
      printf("    ...it returned, which this build does not do\n");
    }
    printf("\n");
  }

  printf("=== Extrema_ExtCC, OCCT's own production caller, on the same line/circle ===\n");
  {
    Handle(Geom_Line)   gl = new Geom_Line(gp_Ax1(gp_Pnt(0, 0, 10), gp_Dir(0, 0, 1)));
    Handle(Geom_Circle) gc =
      new Geom_Circle(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 5.0);
    GeomAdaptor_Curve a1(gl, -1000, 1000);
    GeomAdaptor_Curve a2(gc, 0, 2 * M_PI);
    Extrema_ExtCC     ecc(a1, a2);
    printf("  IsDone=%d IsParallel=%d NbExt=%d\n",
           (int)ecc.IsDone(),
           (int)(ecc.IsDone() ? ecc.IsParallel() : false),
           (int)(ecc.IsDone() ? ecc.NbExt() : 0));
    if (ecc.IsDone())
    {
      for (int i = 1; i <= ecc.NbExt(); ++i)
      {
        printf("    SquareDistance(%d)=%.9f (distance %.9f)\n",
               i,
               ecc.SquareDistance(i),
               std::sqrt(ecc.SquareDistance(i)));
        Extrema_POnCurv p1, p2;
        try
        {
          ecc.Points(i, p1, p2);
          printf("    Points(%d): p1=(%.9f, %.9f, %.9f) p2=(%.9f, %.9f, %.9f)\n",
                 i,
                 p1.Value().X(),
                 p1.Value().Y(),
                 p1.Value().Z(),
                 p2.Value().X(),
                 p2.Value().Y(),
                 p2.Value().Z());
        }
        catch (const Standard_Failure& f)
        {
          printf("    Points(%d): raised %s  <-- the distance is real and there is no point pair\n",
                 i,
                 f.GetMessageString());
        }
      }
    }
  }
  return 0;
}
