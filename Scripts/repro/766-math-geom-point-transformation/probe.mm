// Epic #766 kernel-parity probe for Tests/OCCTMathTests/GeomPoint3DTests.swift and
// GeomTransformationTests.swift. Same OCCT calls and inputs as OCCTGeomPoint3D* and
// OCCTGeomTransform* (Geom_CartesianPoint, Geom_Transformation).
#include <Geom_CartesianPoint.hxx>
#include <Geom_Transformation.hxx>
#include <gp_Ax1.hxx>
#include <gp_Trsf.hxx>
#include <cstdio>

int main()
{
  {
    Handle(Geom_CartesianPoint) p = new Geom_CartesianPoint(1, 2, 3);
    printf("createAndRead: (%.10g, %.10g, %.10g)\n", p->X(), p->Y(), p->Z());
  }
  {
    Handle(Geom_CartesianPoint) p = new Geom_CartesianPoint(4, 5, 6);
    printf("createFromSIMD: (%.10g, %.10g, %.10g)\n", p->X(), p->Y(), p->Z());
  }
  {
    Handle(Geom_CartesianPoint) p = new Geom_CartesianPoint(0, 0, 0);
    p->SetCoord(10, 20, 30);
    printf("setCoordinates: (%.10g, %.10g, %.10g)\n", p->X(), p->Y(), p->Z());
  }
  {
    Handle(Geom_CartesianPoint) a = new Geom_CartesianPoint(0, 0, 0);
    Handle(Geom_CartesianPoint) b = new Geom_CartesianPoint(3, 4, 0);
    printf("distance: %.10g (square %.10g)\n", a->Distance(b), a->SquareDistance(b));
  }
  {
    Handle(Geom_CartesianPoint) p = new Geom_CartesianPoint(1, 0, 0);
    gp_Trsf                     t;
    t.SetTranslation(gp_Vec(10, 0, 0));
    p->Transform(t);
    printf("translate: (%.10g, %.10g, %.10g)\n", p->X(), p->Y(), p->Z());
  }

  {
    Handle(Geom_Transformation) t = new Geom_Transformation();
    printf("identity: scale=%.10g negative=%d\n", t->ScaleFactor(), t->IsNegative() ? 1 : 0);
  }
  {
    Handle(Geom_Transformation) t = new Geom_Transformation();
    t->SetTranslation(gp_Vec(10, 20, 30));
    double x = 0, y = 0, z = 0;
    t->Transforms(x, y, z);
    printf("translation: (0,0,0) -> (%.10g, %.10g, %.10g)\n", x, y, z);
    printf("matrixValue: V(1,4)=%.10g V(2,4)=%.10g V(3,4)=%.10g\n",
           t->Value(1, 4), t->Value(2, 4), t->Value(3, 4));
    Handle(Geom_Transformation) inv = t->Inverted();
    x = 10;
    y = 20;
    z = 30;
    inv->Transforms(x, y, z);
    printf("invert: inverse applied to (10,20,30) -> (%.10g, %.10g, %.10g)\n", x, y, z);
  }
  {
    Handle(Geom_Transformation) t = new Geom_Transformation();
    t->SetRotation(gp_Ax1(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), M_PI / 2);
    double x = 1, y = 0, z = 0;
    t->Transforms(x, y, z);
    printf("rotation: (1,0,0) -> (%.10g, %.10g, %.10g)\n", x, y, z);
  }
  {
    Handle(Geom_Transformation) t = new Geom_Transformation();
    t->SetScale(gp_Pnt(0, 0, 0), 2.0);
    printf("scale: scale=%.10g\n", t->ScaleFactor());
  }
  {
    Handle(Geom_Transformation) t = new Geom_Transformation();
    t->SetMirror(gp_Pnt(0, 0, 0));
    printf("mirror: negative=%d scale=%.10g\n", t->IsNegative() ? 1 : 0, t->ScaleFactor());
  }
  {
    Handle(Geom_Transformation) t1 = new Geom_Transformation();
    Handle(Geom_Transformation) t2 = new Geom_Transformation();
    t1->SetTranslation(gp_Vec(10, 0, 0));
    t2->SetTranslation(gp_Vec(0, 5, 0));
    Handle(Geom_Transformation) c = t1->Multiplied(t2);
    double                      x = 0, y = 0, z = 0;
    c->Transforms(x, y, z);
    printf("multiply: (0,0,0) -> (%.10g, %.10g, %.10g)\n", x, y, z);
  }
  return 0;
}
