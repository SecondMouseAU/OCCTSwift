// Epic #766, PR #2289 evidence fix. probe.mm printed the sew result as the raw BRepBuilderAPI_Sewing
// SewedShape (a shell, type=3), but the test asserts what OCCTShapeSewSingle returns, and that bridge
// function turns a closed sewn shell into a solid with BRepBuilderAPI_MakeSolid. This probe makes the
// bridge's own calls (Sewing, then MakeSolid on a closed shell) so the sewFaces record can carry the
// shape type, face count, volume and validity on both sides. It also reprints the two analytical-
// conversion points at %.17g (probe.mm printed nine decimals).
// Also (PR #2289 test fix): the divideCylinder positive control below, the kinked B-spline face of
// Issue438DivideContinuityUnificationTests divided at C1, which the kernel must divide.
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepBuilderAPI_MakeSolid.hxx>
#include <BRepBuilderAPI_Sewing.hxx>
#include <BRepCheck_Analyzer.hxx>
#include <BRepGProp.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <GProp_GProps.hxx>
#include <GeomConvert.hxx>
#include <ShapeUpgrade_ShapeDivideContinuity.hxx>
#include <TColStd_Array1OfInteger.hxx>
#include <TColStd_Array1OfReal.hxx>
#include <TColgp_Array2OfPnt.hxx>
#include <GeomConvert_CurveToAnaCurve.hxx>
#include <GeomConvert_SurfToAnaSurf.hxx>
#include <Geom_BSplineCurve.hxx>
#include <Geom_BSplineSurface.hxx>
#include <Geom_Circle.hxx>
#include <Geom_CylindricalSurface.hxx>
#include <Geom_RectangularTrimmedSurface.hxx>
#include <TopExp.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopoDS.hxx>
#include <cstdio>

int main()
{
  // sewFaces: Shape.box(10, 10, 10) is centred; box.sewn(tolerance: 1e-6) = OCCTShapeSewSingle.
  {
    TopoDS_Shape box = BRepPrimAPI_MakeBox(gp_Pnt(-5, -5, -5), 10, 10, 10).Shape();
    BRepBuilderAPI_Sewing sewing(1e-6);
    sewing.Add(box);
    sewing.Perform();
    TopoDS_Shape sewn = sewing.SewedShape();
    printf("sewFaces SewedShape type=%d closed=%d\n", (int)sewn.ShapeType(), sewn.ShapeType() == TopAbs_SHELL ? (int)TopoDS::Shell(sewn).Closed() : -1);
    TopoDS_Shape result = sewn;
    if (sewn.ShapeType() == TopAbs_SHELL)
    {
      TopoDS_Shell shell = TopoDS::Shell(sewn);
      if (shell.Closed())
      {
        BRepBuilderAPI_MakeSolid makeSolid(shell);
        if (makeSolid.IsDone())
          result = makeSolid.Solid();
      }
    }
    GProp_GProps p;
    BRepGProp::VolumeProperties(result, p);
    TopTools_IndexedMapOfShape faces;
    TopExp::MapShapes(result, TopAbs_FACE, faces);
    printf("sewFaces as the bridge returns it: type=%d (2 = solid) valid=%d faces=%d volume=%.17g\n",
           (int)result.ShapeType(),
           BRepCheck_Analyzer(result).IsValid() ? 1 : 0,
           faces.Extent(),
           p.Mass());
  }
  // bsplineCircle: circle r=10 -> CurveToBSplineCurve -> CurveToAnaCurve(0.01).
  {
    Handle(Geom_Circle)       c  = new Geom_Circle(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 10);
    Handle(Geom_BSplineCurve) bs = GeomConvert::CurveToBSplineCurve(c);
    GeomConvert_CurveToAnaCurve conv(bs);
    Handle(Geom_Curve)          res;
    double                      nf = 0, nl = 0;
    conv.ConvertToAnalytical(0.01, res, bs->FirstParameter(), bs->LastParameter(), nf, nl);
    Handle(Geom_Circle) rc = Handle(Geom_Circle)::DownCast(res);
    gp_Pnt              p  = res->Value(0);
    printf("bsplineCircle isCircle=%d radius=%.17g value(0)=(%.17g, %.17g, %.17g)\n", (int)!rc.IsNull(), rc->Radius(), p.X(), p.Y(), p.Z());
  }
  // surfaceConversion: the infinite cylinder throws in SurfaceToBSplineSurface; the trimmed patch converts.
  {
    Handle(Geom_CylindricalSurface) cs = new Geom_CylindricalSurface(gp_Ax3(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 5);
    bool                            threw = false;
    try
    {
      GeomConvert::SurfaceToBSplineSurface(cs);
    }
    catch (Standard_Failure&)
    {
      threw = true;
    }
    Handle(Geom_RectangularTrimmedSurface) t   = new Geom_RectangularTrimmedSurface(cs, 0.0, 2 * M_PI, 0.0, 10.0);
    Handle(Geom_BSplineSurface)            bs  = GeomConvert::SurfaceToBSplineSurface(t);
    GeomConvert_SurfToAnaSurf              conv(bs);
    Handle(Geom_Surface)                   res = conv.ConvertToAnalytical(0.01);
    Handle(Geom_CylindricalSurface)        rc  = Handle(Geom_CylindricalSurface)::DownCast(res);
    gp_Pnt                                 p   = res->Value(0, 0);
    printf("surfaceConversion infiniteThrew=%d isCylinder=%d value(0,0)=(%.17g, %.17g, %.17g)\n", (int)threw, (int)!rc.IsNull(), p.X(), p.Y(), p.Z());
  }
  // divideCylinder control: the fixture of Issue438DivideContinuityUnificationTests.kinkedSurfaceFace, a
  // cubic B-spline surface with a multiplicity-3 interior knot in U and V (genuinely C0 there), trimmed to its
  // whole domain. Shape.divided(at: .c1, tolerance: 1e-4) is OCCTShapeDivide: ShapeUpgrade_ShapeDivideContinuity
  // with boundary, pcurve and surface criteria C1, tolerance 1e-4 and SetSurfaceSegmentMode(true). The cylinder
  // above answers Perform() false (no division needed); this face must be divided, or "nil" would be what the
  // bridge says to everything.
  {
    const int degree = 3;
    // knots 0..5, multiplicities 4,1,3,1,1,4 (the bump is at knot 2), 14 in total: 14 - 3 - 1 = 10 poles per side
    TColStd_Array1OfReal    knots(1, 6);
    TColStd_Array1OfInteger mults(1, 6);
    const int               m[6] = {4, 1, 3, 1, 1, 4};
    for (int i = 0; i < 6; i++)
    {
      knots.SetValue(i + 1, (double)i);
      mults.SetValue(i + 1, m[i]);
    }
    const int         n = 10;
    TColgp_Array2OfPnt poles(1, n, 1, n);
    for (int u = 0; u < n; u++)
      for (int v = 0; v < n; v++)
        poles.SetValue(u + 1, v + 1, gp_Pnt(u, v, ((u + v) % 3) * 0.5));
    Handle(Geom_BSplineSurface) surface = new Geom_BSplineSurface(poles, knots, knots, mults, mults, degree, degree);
    double u1, u2, v1, v2;
    surface->Bounds(u1, u2, v1, v2);
    BRepBuilderAPI_MakeFace maker(surface, u1, u2, v1, v2, 1e-6);
    TopoDS_Shape            face = maker.Face();
    ShapeUpgrade_ShapeDivideContinuity divider(face);
    divider.SetBoundaryCriterion(GeomAbs_C1);
    divider.SetPCurveCriterion(GeomAbs_C1);
    divider.SetSurfaceCriterion(GeomAbs_C1);
    divider.SetTolerance(1e-4);
    divider.SetSurfaceSegmentMode(Standard_True);
    bool performed = divider.Perform();
    int  faces     = 0;
    if (performed && !divider.Result().IsNull())
    {
      TopTools_IndexedMapOfShape fm;
      TopExp::MapShapes(divider.Result(), TopAbs_FACE, fm);
      faces = fm.Extent();
    }
    printf("divideCylinder control (kinked B-spline face, C1, 1e-4): Perform=%d resultFaces=%d\n", (int)performed, faces);
  }
  return 0;
}
