// #1979 kernel parity for Transform2DCreationTests, Transform2DCompositionTests,
// TransformFactory2DTests and Vector2DUtilityTests: Geom2d_Transformation, the gce_Make*2d
// factories, gce_MakeDir2d and gp_Vec2d on the tests' own inputs.
#include <GCE2d_MakeSegment.hxx>
#include <Geom2d_Transformation.hxx>
#include <Geom2d_TrimmedCurve.hxx>
#include <gce_MakeDir2d.hxx>
#include <gce_MakeMirror2d.hxx>
#include <gce_MakeRotation2d.hxx>
#include <gce_MakeScale2d.hxx>
#include <gce_MakeTranslation2d.hxx>
#include <gp_Trsf2d.hxx>
#include <gp_Vec2d.hxx>
#include <cmath>
#include <cstdio>

static void apply(const char* tag, const gp_Trsf2d& t, double x, double y)
{
  t.Transforms(x, y);
  printf("%s -> (%.15g, %.15g)\n", tag, x, y);
}

int main()
{
  Handle(Geom2d_Transformation) id = new Geom2d_Transformation();
  printf("identity: ScaleFactor=%g IsNegative=%d a11=%g a12=%g a21=%g a22=%g\n", id->ScaleFactor(), id->IsNegative(),
         id->Value(1, 1), id->Value(1, 2), id->Value(2, 1), id->Value(2, 2));
  gp_Trsf2d t;
  t.SetTranslation(gp_Vec2d(3, 4));
  apply("translation (3,4) of (0,0)", t, 0, 0);
  Handle(Geom2d_Transformation) g = new Geom2d_Transformation(t);
  apply("inverse of translation (3,4) applied to (3,4)", g->Inverted()->Trsf2d(), 3, 4);
  gp_Trsf2d t1, t2;
  t1.SetTranslation(gp_Vec2d(1, 0));
  t2.SetTranslation(gp_Vec2d(0, 2));
  Handle(Geom2d_Transformation) g1 = new Geom2d_Transformation(t1), g2 = new Geom2d_Transformation(t2);
  apply("(1,0) composed with (0,2) applied to origin", g1->Multiplied(g2)->Trsf2d(), 0, 0);
  apply("(1,0) powered 3 applied to origin", g1->Powered(3)->Trsf2d(), 0, 0);
  t.SetRotation(gp_Pnt2d(0, 0), M_PI / 2);
  apply("rotation pi/2 of (1,0)", t, 1, 0);
  t.SetScale(gp_Pnt2d(0, 0), 3);
  printf("scale 3: ScaleFactor=%g\n", t.ScaleFactor());
  apply("scale 3 of (1,2)", t, 1, 2);
  t.SetMirror(gp_Pnt2d(0, 0));
  apply("mirror through origin of (1,2)", t, 1, 2);
  t.SetMirror(gp_Ax2d(gp_Pnt2d(0, 0), gp_Dir2d(1, 0)));
  printf("mirror across x-axis: IsNegative=%d\n", t.IsNegative());
  apply("mirror across x-axis of (1,2)", t, 1, 2);
  t.SetTranslation(gp_Vec2d(5, 0));
  Handle(Geom2d_TrimmedCurve) seg = GCE2d_MakeSegment(gp_Pnt2d(0, 0), gp_Pnt2d(1, 0)).Value();
  seg->Transform(t);
  printf("segment (0,0)-(1,0) translated by 5: (%g, %g)-(%g, %g)\n", seg->StartPoint().X(), seg->StartPoint().Y(),
         seg->EndPoint().X(), seg->EndPoint().Y());

  apply("gce_MakeMirror2d origin of (3,4)", gce_MakeMirror2d(gp_Pnt2d(0, 0)).Value(), 3, 4);
  apply("gce_MakeRotation2d pi/2 of (1,0)", gce_MakeRotation2d(gp_Pnt2d(0, 0), M_PI / 2).Value(), 1, 0);
  apply("gce_MakeScale2d 3 of (1,2)", gce_MakeScale2d(gp_Pnt2d(0, 0), 3).Value(), 1, 2);
  apply("gce_MakeTranslation2d (10,20) of (1,2)", gce_MakeTranslation2d(gp_Vec2d(10, 20)).Value(), 1, 2);
  gp_Dir2d d = gce_MakeDir2d(3, 4).Value();
  gp_Dir2d e = gce_MakeDir2d(gp_Pnt2d(0, 0), gp_Pnt2d(1, 1)).Value();
  printf("gce_MakeDir2d(3,4)=(%.15g, %.15g); (0,0)->(1,1)=(%.15g, %.15g)\n", d.X(), d.Y(), e.X(), e.Y());

  gp_Vec2d a(1, 0), b(0, 1), c(3, 4);
  printf("angle (1,0)^(0,1)=%.15g cross=%g dot (3,4).(1,0)=%g |(3,4)|=%g normalized=(%g, %g)\n", a.Angle(b), a.Crossed(b),
         c.Dot(a), c.Magnitude(), c.Normalized().X(), c.Normalized().Y());
  return 0;
}
