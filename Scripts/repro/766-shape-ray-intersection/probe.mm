// Epic #766, ShapeRayIntersectionTests.swift: kernel parity for all three tests.
// ShapeRayIntersection(shape:origin:dir:) is OCCTCurveSurfaceInterCreateLine ->
// BRepIntCurveSurface_Inter::Init(shape, gp_Lin, 1e-6); the curve form is
// OCCTCurveSurfaceInterCreateCurve -> Init(shape, GeomAdaptor_Curve(Geom_Line), 1e-6).
// allHits() walks More()/Pnt()/U()/V()/W()/Next(). Shape.box is centred.
#include <BRepGProp.hxx>
#include <BRepIntCurveSurface_Inter.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeSphere.hxx>
#include <GProp_GProps.hxx>
#include <GeomAdaptor_Curve.hxx>
#include <Geom_Line.hxx>
#include <cstdio>
#include <gp_Lin.hxx>

static void walk(const char* tag, BRepIntCurveSurface_Inter& it)
{
  int n = 0;
  printf("%s:\n", tag);
  for (; it.More(); it.Next(), n++)
  {
    gp_Pnt       p = it.Pnt();
    GProp_GProps g;
    BRepGProp::SurfaceProperties(it.Face(), g);
    printf("  hit[%d] pnt=(%.17g, %.17g, %.17g) u=%.17g v=%.17g w=%.17g faceArea=%.17g\n", n, p.X(),
           p.Y(), p.Z(), it.U(), it.V(), it.W(), g.Mass());
  }
  printf("  hits=%d\n", n);
}

int main()
{
  TopoDS_Shape box = BRepPrimAPI_MakeBox(gp_Pnt(-5, -5, -5), 10, 10, 10).Shape();
  {
    BRepIntCurveSurface_Inter it;
    it.Init(box, gp_Lin(gp_Pnt(5, 5, -10), gp_Dir(0, 0, 1)), 1e-6);
    walk("lineBoxIntersection: ray (5,5,-10)+t(0,0,1), which runs along the box's x=5,y=5 edge",
         it);
  }
  {
    TopoDS_Shape       sphere = BRepPrimAPI_MakeSphere(5).Shape();
    Handle(Geom_Line)  line   = new Geom_Line(gp_Pnt(0, 0, -10), gp_Dir(0, 0, 1));
    GeomAdaptor_Curve  gac(line);
    BRepIntCurveSurface_Inter it;
    it.Init(sphere, gac, 1e-6);
    walk("curveSphereIntersection: line (0,0,-10)+t(0,0,1) through both poles", it);
  }
  {
    BRepIntCurveSurface_Inter it;
    it.Init(box, gp_Lin(gp_Pnt(0, 0, -10), gp_Dir(0, 0, 1)), 1e-6);
    walk("hitFaceAccess: ray (0,0,-10)+t(0,0,1)", it);
  }
  return 0;
}
