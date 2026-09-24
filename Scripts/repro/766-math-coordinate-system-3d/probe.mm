// Kernel parity probe for CoordinateSystem3DTests (#1983). Mirrors OCCTAx3Create,
// OCCTAx3CreateFromNormal, OCCTAx3Angle, OCCTAx3IsCoplanar, OCCTAx3MirrorPoint, OCCTAx3Rotate and
// OCCTAx3Translate with each test's own inputs. The degenerate cases print whether the kernel
// throws, since the bridge's documented fallback is what the Swift test then observes.
#include <Standard_Failure.hxx>
#include <gp_Ax1.hxx>
#include <gp_Ax3.hxx>
#include <gp_Vec.hxx>
#include <cmath>
#include <cstdio>

static void pr(const char* tag, const gp_XYZ& p)
{
  printf("%s (%.12g, %.12g, %.12g)\n", tag, p.X(), p.Y(), p.Z());
}

int main()
{
  {
    gp_Ax3 a(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1), gp_Dir(1, 0, 0));
    printf("defaultXYZ direct=%d\n", a.Direct());
    pr("defaultXYZ yDirection", a.YDirection().XYZ());
  }
  {
    gp_Ax3 a(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1));
    printf("fromNormal direct=%d\n", a.Direct());
    pr("fromNormal xDirection", a.XDirection().XYZ());
  }
  {
    // angle: the Swift value type re-feeds each system's own xDirection (from the normal-only
    // constructor) into OCCTAx3Angle.
    gp_Ax3 n1(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1));
    gp_Ax3 n2(gp_Pnt(0, 0, 0), gp_Dir(1, 0, 0));
    gp_Ax3 a1(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1), n1.XDirection());
    gp_Ax3 a2(gp_Pnt(0, 0, 0), gp_Dir(1, 0, 0), n2.XDirection());
    printf("angle %.15g (pi/2=%.15g)\n", a1.Angle(a2), M_PI / 2);
  }
  {
    gp_Ax3 n1(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1));
    gp_Ax3 n2(gp_Pnt(1, 1, 0), gp_Dir(0, 0, 1));
    gp_Ax3 a1(n1.Location(), n1.Direction(), n1.XDirection());
    gp_Ax3 a2(n2.Location(), n2.Direction(), n2.XDirection());
    printf("isCoplanar %d\n", a1.IsCoplanar(a2, 1e-6, 1e-6));
  }
  {
    gp_Ax3 a(gp_Pnt(1, 0, 0), gp_Dir(0, 0, 1), gp_Dir(1, 0, 0));
    pr("mirrorPoint origin", a.Mirrored(gp_Pnt(0, 0, 0)).Location().XYZ());
  }
  {
    gp_Ax3 a(gp_Pnt(1, 0, 0), gp_Dir(0, 0, 1), gp_Dir(1, 0, 0));
    pr("rotate origin",
       a.Rotated(gp_Ax1(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), M_PI / 2).Location().XYZ());
  }
  {
    gp_Ax3 a(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1), gp_Dir(1, 0, 0));
    pr("translate origin", a.Translated(gp_Vec(1, 2, 3)).Location().XYZ());
  }
  // Degenerate inputs: the kernel throws, the bridge catch supplies the fallback.
  try
  {
    gp_Ax3 a(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1), gp_Dir(0, 0, 1));
    printf("parallel direction/xDirection: no throw\n");
  }
  catch (const Standard_Failure& e)
  {
    printf("parallel direction/xDirection: throws %s\n", e.ExceptionType());
  }
  try
  {
    gp_Dir d(0, 0, 0);
    printf("zero direction: no throw\n");
  }
  catch (const Standard_Failure& e)
  {
    printf("zero direction: throws %s\n", e.ExceptionType());
  }
  {
    // rotateWithZeroAxisDirectionFallsBackToUnmoved: the source is valid, the axis is not.
    gp_Ax3 a(gp_Pnt(5, 3, 2), gp_Dir(0, 0, 1), gp_Dir(1, 0, 0));
    printf("rotate source direct=%d\n", a.Direct());
    try
    {
      gp_Ax1 ax(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 0));
      printf("zero rotation axis: no throw\n");
    }
    catch (const Standard_Failure& e)
    {
      printf("zero rotation axis: throws %s\n", e.ExceptionType());
    }
  }
  return 0;
}
