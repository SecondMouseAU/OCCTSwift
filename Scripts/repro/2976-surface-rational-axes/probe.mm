// #2976: which parametric axis IsURational() / IsVRational() actually report on, for
// Geom_BSplineSurface and Geom_BezierSurface, measured rather than read off the headers.
//
// Why measure. Geom_BSplineSurface.hxx defines IsURational() as "False if for each ROW of weights
// all the weights are identical", and a row is one U index across every V (the header's own
// array-bounds paragraph: rows run 1..NbUPoles, columns 1..NbVPoles). So IsURational() is False
// when the weights do not vary with V, which is the opposite of what the name suggests to a
// reader. Geom_BezierSurface.hxx says instead "False if the weights are identical in the U
// direction" and then gives the SAME example matrix as the BSpline page, so its prose and its
// example contradict each other and only one of them can be the behaviour.
//
// Build and run (from the repo root, with Libraries/OCCT.xcframework present):
//   Scripts/repro/2976-surface-rational-axes/run.sh

#import <Foundation/Foundation.h>

#include <GeomConvert.hxx>
#include <Geom_BSplineSurface.hxx>
#include <Geom_BezierSurface.hxx>
#include <Geom_CylindricalSurface.hxx>
#include <Geom_RectangularTrimmedSurface.hxx>
#include <NCollection_Array2.hxx>
#include <gp_Ax3.hxx>
#include <gp_Pnt.hxx>

#include <cstdio>

namespace
{

// A 3x3 grid of poles, enough to carry a 3x3 weight matrix.
NCollection_Array2<gp_Pnt> grid()
{
  NCollection_Array2<gp_Pnt> poles(1, 3, 1, 3);
  for (int i = 1; i <= 3; ++i)
  {
    for (int j = 1; j <= 3; ++j)
    {
      poles(i, j) = gp_Pnt(i, j, (i == 2 && j == 2) ? 1.0 : 0.0);
    }
  }
  return poles;
}

void reportBezier(const char* label, const double w[3][3])
{
  NCollection_Array2<double> weights(1, 3, 1, 3);
  for (int i = 1; i <= 3; ++i)
  {
    for (int j = 1; j <= 3; ++j)
    {
      weights(i, j) = w[i - 1][j - 1];
    }
  }
  Handle(Geom_BezierSurface) bez = new Geom_BezierSurface(grid(), weights);
  std::printf("  %-46s isURational=%d isVRational=%d\n", label, bez->IsURational() ? 1 : 0,
              bez->IsVRational() ? 1 : 0);
}

} // namespace

int main()
{
  std::printf("== Geom_BezierSurface, explicit weight matrices ==\n");
  std::printf("   (row index = U index, column index = V index, per the header's bounds)\n");

  // The matrix Geom_BezierSurface.hxx prints beside IsURational(), identical to the BSpline
  // page's. Every ROW is constant, so the weights vary along U and not along V.
  const double rowsConstant[3][3] = {{1.0, 1.0, 1.0}, {0.5, 0.5, 0.5}, {2.0, 2.0, 2.0}};
  reportBezier("rows constant, varies along U", rowsConstant);

  // Its transpose: every COLUMN is constant, so the weights vary along V and not along U.
  const double colsConstant[3][3] = {{1.0, 0.5, 2.0}, {1.0, 0.5, 2.0}, {1.0, 0.5, 2.0}};
  reportBezier("columns constant, varies along V", colsConstant);

  const double allEqual[3][3] = {{1.0, 1.0, 1.0}, {1.0, 1.0, 1.0}, {1.0, 1.0, 1.0}};
  reportBezier("all weights equal (not rational at all)", allEqual);

  const double bothVary[3][3] = {{1.0, 2.0, 0.5}, {0.5, 1.0, 2.0}, {2.0, 0.5, 1.0}};
  reportBezier("varies along both", bothVary);

  std::printf("\n== Geom_BSplineSurface, the cylinder #2976 names ==\n");
  gp_Ax3                          axis(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1));
  Handle(Geom_CylindricalSurface) cyl = new Geom_CylindricalSurface(axis, 5.0);
  // The User Directive: an infinite surface is trimmed before it is converted.
  Handle(Geom_RectangularTrimmedSurface) trimmed =
    new Geom_RectangularTrimmedSurface(cyl, 0.0, 2.0 * M_PI, 0.0, 10.0);
  Handle(Geom_BSplineSurface) bs = GeomConvert::SurfaceToBSplineSurface(trimmed);
  std::printf("  %-46s isURational=%d isVRational=%d\n", "radius 5, height 10, converted",
              bs->IsURational() ? 1 : 0, bs->IsVRational() ? 1 : 0);
  bs->ExchangeUV();
  std::printf("  %-46s isURational=%d isVRational=%d\n", "...after ExchangeUV()",
              bs->IsURational() ? 1 : 0, bs->IsVRational() ? 1 : 0);

  std::printf("\n== Geom_BSplineSurface, the same explicit matrices ==\n");
  {
    NCollection_Array2<double> weights(1, 3, 1, 3);
    NCollection_Array1<double> uknots(1, 2), vknots(1, 2);
    NCollection_Array1<int>    umult(1, 2), vmult(1, 2);
    uknots(1) = vknots(1) = 0.0;
    uknots(2) = vknots(2) = 1.0;
    umult(1) = umult(2) = vmult(1) = vmult(2) = 3;
    for (int i = 1; i <= 3; ++i)
    {
      for (int j = 1; j <= 3; ++j)
      {
        weights(i, j) = rowsConstant[i - 1][j - 1];
      }
    }
    Handle(Geom_BSplineSurface) s =
      new Geom_BSplineSurface(grid(), weights, uknots, vknots, umult, vmult, 2, 2);
    std::printf("  %-46s isURational=%d isVRational=%d\n", "rows constant, varies along U",
                s->IsURational() ? 1 : 0, s->IsVRational() ? 1 : 0);
  }
  {
    NCollection_Array2<double> weights(1, 3, 1, 3);
    NCollection_Array1<double> uknots(1, 2), vknots(1, 2);
    NCollection_Array1<int>    umult(1, 2), vmult(1, 2);
    uknots(1) = vknots(1) = 0.0;
    uknots(2) = vknots(2) = 1.0;
    umult(1) = umult(2) = vmult(1) = vmult(2) = 3;
    for (int i = 1; i <= 3; ++i)
    {
      for (int j = 1; j <= 3; ++j)
      {
        weights(i, j) = colsConstant[i - 1][j - 1];
      }
    }
    Handle(Geom_BSplineSurface) s =
      new Geom_BSplineSurface(grid(), weights, uknots, vknots, umult, vmult, 2, 2);
    std::printf("  %-46s isURational=%d isVRational=%d\n", "columns constant, varies along V",
                s->IsURational() ? 1 : 0, s->IsVRational() ? 1 : 0);
  }

  return 0;
}
