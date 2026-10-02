// Epic #766, BRepGPropVinertGKTests.swift: kernel parity for the four tests #1759-#1762 cover.
// Same inputs as the Swift tests, straight to BRepGProp_VinertGK(BRepGProp_Face, gp_Pnt, tol,
// computeCG, false), which is what OCCTBRepGPropVinertGK constructs.
#include <BRepGProp_Face.hxx>
#include <BRepGProp_VinertGK.hxx>
#include <BRepLib_MakeFace.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeSphere.hxx>
#include <Geom_CylindricalSurface.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <cmath>
#include <cstdio>

static TopoDS_Face firstFace(const TopoDS_Shape& s)
{
  TopExp_Explorer ex(s, TopAbs_FACE);
  return TopoDS::Face(ex.Current());
}

static BRepGProp_VinertGK run(const TopoDS_Face& f, gp_Pnt loc, double tol, bool cg)
{
  BRepGProp_Face bf(f);
  return BRepGProp_VinertGK(bf, loc, tol, cg, false);
}

int main()
{
  // Shape.box(width:height:depth:) is centred on the origin (OCCTShapeCreateBox).
  {
    TopoDS_Face        f = firstFace(BRepPrimAPI_MakeBox(gp_Pnt(-5, -5, -5), 10, 10, 10).Shape());
    BRepGProp_VinertGK r = run(f, gp_Pnt(0, 0, 0), 0.001, true);
    gp_Pnt             c = r.CentreOfMass();
    printf("volumeIntegration: mass=%.17g error=%.17g centre=(%.17g, %.17g, %.17g)\n", r.Mass(),
           r.GetErrorReached(), c.X(), c.Y(), c.Z());
  }
  {
    TopoDS_Face        f = firstFace(BRepPrimAPI_MakeBox(gp_Pnt(-2.5, -2.5, -2.5), 5, 5, 5).Shape());
    BRepGProp_VinertGK r = run(f, gp_Pnt(0, 0, 0), 0.001, true);
    printf("errorBounds: mass=%.17g error=%.17g\n", r.Mass(), r.GetErrorReached());
  }
  {
    TopoDS_Face        f = firstFace(BRepPrimAPI_MakeSphere(10.0).Shape());
    BRepGProp_VinertGK r = run(f, gp_Pnt(0, 0, 0), 1e-3, true);
    double             v = 4.0 / 3.0 * M_PI * 1000.0;
    printf("errorReachedIsNonzeroOnCurvedFace: mass=%.17g error=%.17g analytic=%.17g relDev=%.17g\n",
           r.Mass(), r.GetErrorReached(), v, std::fabs(r.Mass() - v) / v);
  }
  {
    Handle(Geom_CylindricalSurface) cyl =
      new Geom_CylindricalSurface(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 5.0);
    TopoDS_Face        f     = BRepLib_MakeFace(cyl, 0, M_PI, 0, 10, 1e-7).Face();
    BRepGProp_VinertGK rFar  = run(f, gp_Pnt(0, 0, 0), 1e-3, false);
    BRepGProp_VinertGK rPrb  = run(f, gp_Pnt(0, 10, 0), 1e-3, false);
    double             slope = (rPrb.Mass() - rFar.Mass()) / 10.0;
    double             rootY = 0.0 - rFar.Mass() / slope;
    BRepGProp_VinertGK rNear = run(f, gp_Pnt(0, rootY, 0), 1e-3, false);
    printf("errorReachedGrowsAsMassApproachesZero: far mass=%.17g error=%.17g; probe mass=%.17g; "
           "slope=%.17g rootY=%.17g; near mass=%.17g error=%.17g\n",
           rFar.Mass(), rFar.GetErrorReached(), rPrb.Mass(), slope, rootY, rNear.Mass(),
           rNear.GetErrorReached());
  }
  return 0;
}
