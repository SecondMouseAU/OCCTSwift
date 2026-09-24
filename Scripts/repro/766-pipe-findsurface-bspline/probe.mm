// Epic #766, BRepFillPipeTests.swift, BRepLibFindSurfaceTests.swift and
// BSplineSurfaceCompletionsTests.swift: kernel parity for the six tests.
//  - BRepFill_Pipe(spine, profile, GeomFill_IsCorrectedFrenet, false, false) on a 50-long Z line
//    and a radius-5 circle (OCCTBRepFillPipe), with the swept area and ErrorOnSurface.
//  - BRepLib_FindSurface(wire, -1, onlyPlane = true) on the first face's wire of a centred 10-box
//    (occtRunFindSurface), with Found, ToleranceReached, Existed and the plane.
//  - BRepTools_Modifier + BRepTools_NurbsConvertModification on the same box
//    (OCCTBRepToolsModifierNurbsConvert), then face 1's Geom_BSplineSurface multiplicities and
//    what UReverse / VReverse do to a point.
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepBuilderAPI_MakeWire.hxx>
#include <BRepFill_Pipe.hxx>
#include <BRepGProp.hxx>
#include <BRepLib_FindSurface.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepTools_Modifier.hxx>
#include <BRepTools_NurbsConvertModification.hxx>
#include <BRep_Tool.hxx>
#include <GProp_GProps.hxx>
#include <Geom_BSplineSurface.hxx>
#include <Geom_Circle.hxx>
#include <Geom_Plane.hxx>
#include <TopExp.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Face.hxx>
#include <TopoDS_Wire.hxx>
#include <cstdio>
#include <gp_Pln.hxx>

int main()
{
  {
    TopoDS_Wire spine = BRepBuilderAPI_MakeWire(BRepBuilderAPI_MakeEdge(gp_Pnt(0, 0, 0), gp_Pnt(0, 0, 50)).Edge()).Wire();
    Handle(Geom_Circle) c = new Geom_Circle(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 5);
    TopoDS_Wire profile = BRepBuilderAPI_MakeWire(BRepBuilderAPI_MakeEdge(c).Edge()).Wire();
    BRepFill_Pipe pipe(spine, profile, GeomFill_IsCorrectedFrenet, false, false);
    GProp_GProps  g;
    BRepGProp::SurfaceProperties(pipe.Shape(), g);
    printf("pipeSweep: shapeType=%d area=%.17g (2 pi r h = %.17g) ErrorOnSurface=%.17g\n", (int)pipe.Shape().ShapeType(),
           g.Mass(), 2 * M_PI * 5 * 50, pipe.ErrorOnSurface());
  }
  // Shape.box is centred on the origin (OCCTShapeCreateBox), so the corner is (-5, -5, -5).
  TopoDS_Shape               box = BRepPrimAPI_MakeBox(gp_Pnt(-5, -5, -5), 10, 10, 10).Shape();
  TopTools_IndexedMapOfShape faces;
  TopExp::MapShapes(box, TopAbs_FACE, faces);
  {
    TopTools_IndexedMapOfShape wires;
    TopExp::MapShapes(faces(1), TopAbs_WIRE, wires);
    BRepLib_FindSurface fs(wires(1), -1, true);
    printf("findSurface: Found=%d", fs.Found());
    if (fs.Found())
    {
      Handle(Geom_Plane) pl = Handle(Geom_Plane)::DownCast(fs.Surface());
      printf(" surface=%s ToleranceReached=%.17g Existed=%d", fs.Surface()->DynamicType()->Name(), fs.ToleranceReached(),
             fs.Existed());
      if (!pl.IsNull())
      {
        gp_Pln p = pl->Pln();
        printf(" plane location=(%g,%g,%g) normal=(%g,%g,%g)", p.Location().X(), p.Location().Y(), p.Location().Z(),
               p.Axis().Direction().X(), p.Axis().Direction().Y(), p.Axis().Direction().Z());
      }
      printf(" location identity=%d", fs.Location().IsIdentity());
    }
    printf("\n");
  }
  {
    Handle(BRepTools_NurbsConvertModification) mod = new BRepTools_NurbsConvertModification();
    BRepTools_Modifier                         m(box);
    m.Perform(mod);
    TopoDS_Shape               nb = m.ModifiedShape(box);
    TopTools_IndexedMapOfShape nf;
    TopExp::MapShapes(nb, TopAbs_FACE, nf);
    Handle(Geom_BSplineSurface) bs = Handle(Geom_BSplineSurface)::DownCast(BRep_Tool::Surface(TopoDS::Face(nf(1))));
    printf("multiplicities: face1 surface=%s", BRep_Tool::Surface(TopoDS::Face(nf(1)))->DynamicType()->Name());
    if (!bs.IsNull())
    {
      printf(" U knots=%d mults=", bs->NbUKnots());
      for (int i = 1; i <= bs->NbUKnots(); i++)
        printf("%d ", bs->UMultiplicity(i));
      printf("V knots=%d mults=", bs->NbVKnots());
      for (int i = 1; i <= bs->NbVKnots(); i++)
        printf("%d ", bs->VMultiplicity(i));
      double u1, u2, v1, v2;
      bs->Bounds(u1, u2, v1, v2);
      printf("bounds=[%.17g, %.17g]x[%.17g, %.17g]\n", u1, u2, v1, v2);
      double u = u1 + 0.2 * (u2 - u1), v = v1 + 0.7 * (v2 - v1);
      gp_Pnt p0 = bs->Value(u, v);
      bs->UReverse();
      double ru1, ru2, rv1, rv2;
      bs->Bounds(ru1, ru2, rv1, rv2);
      gp_Pnt p1 = bs->Value(ru1 + ru2 - u, v);
      bs->VReverse();
      bs->Bounds(ru1, ru2, rv1, rv2);
      gp_Pnt p2 = bs->Value(ru1 + ru2 - u, rv1 + rv2 - v);
      gp_Pnt pu = bs->Value(u, v);
      printf("reverse: S(%.17g, %.17g)=(%.17g,%.17g,%.17g) after UReverse S(u1+u2-u, v)=(%.17g,%.17g,%.17g) after VReverse "
             "S(u1+u2-u, v1+v2-v)=(%.17g,%.17g,%.17g) S(u, v) after both=(%.17g,%.17g,%.17g) bounds after=[%g,%g]x[%g,%g]\n",
             u, v, p0.X(), p0.Y(), p0.Z(), p1.X(), p1.Y(), p1.Z(), p2.X(), p2.Y(), p2.Z(), pu.X(), pu.Y(), pu.Z(), ru1,
             ru2, rv1, rv2);
    }
  }
  return 0;
}
