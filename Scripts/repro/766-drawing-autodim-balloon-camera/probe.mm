// Epic #766, OCCTDrawingTests: AutoDimensionTests, BalloonTests, CameraTests.
// Same inputs as the Swift tests, straight to OCCT. BalloonTests is pure Swift (DXF entity
// counts and DrawingAnnotation.transformed) and has no kernel counterpart.
#include <BRepAdaptor_Curve.hxx>
#include <BRepBndLib.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <Bnd_Box.hxx>
#include <Graphic3d_Camera.hxx>
#include <TopExp.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopoDS.hxx>
#include <cmath>
#include <cstdio>

static void countCircles(const TopoDS_Shape& s, const gp_Dir& view, double minR, const char* tag)
{
  int                        faced = 0, edgeOn = 0, small = 0;
  TopTools_IndexedMapOfShape map;
  TopExp::MapShapes(s, TopAbs_EDGE, map);
  for (int i = 1; i <= map.Extent(); ++i)
  {
    BRepAdaptor_Curve c(TopoDS::Edge(map(i)));
    if (c.GetType() != GeomAbs_Circle)
      continue;
    if (c.Circle().Radius() < minR)
      small++;
    else if (std::abs(c.Circle().Axis().Direction().Dot(view)) < 0.1)
      edgeOn++;
    else
      faced++;
  }
  printf("%s: circles faced=%d edgeOn=%d belowMinRadius=%d\n", tag, faced, edgeOn, small);
}

// Projected extent of a shape's bounding box in the gp_Ax2(origin, view) frame, the frame
// addAutoDimensions projects the eight corners into.
static void projectedExtent(const TopoDS_Shape& s, const gp_Dir& view, const char* tag)
{
  Bnd_Box b;
  BRepBndLib::Add(s, b, true);
  double x0, y0, z0, x1, y1, z1;
  b.Get(x0, y0, z0, x1, y1, z1);
  gp_Ax2 ax(gp_Pnt(0, 0, 0), view);
  gp_Vec X(ax.XDirection()), Y(ax.YDirection());
  double mnx = 1e300, mxx = -1e300, mny = 1e300, mxy = -1e300;
  for (int i = 0; i < 8; ++i)
  {
    gp_Vec p(i & 1 ? x1 : x0, i & 2 ? y1 : y0, i & 4 ? z1 : z0);
    mnx = std::min(mnx, p.Dot(X));
    mxx = std::max(mxx, p.Dot(X));
    mny = std::min(mny, p.Dot(Y));
    mxy = std::max(mxy, p.Dot(Y));
  }
  printf("%s: projected width=%.17g height=%.17g\n", tag, mxx - mnx, mxy - mny);
}

static void printMat(const char* tag, const NCollection_Mat4<float>& m)
{
  printf("%s:", tag);
  for (int i = 0; i < 4; i++)
    for (int j = 0; j < 4; j++)
      printf(" %.9g", m.GetValue(i, j));
  printf("\n");
}

// OCCTCameraCreate's OCCTCamera() constructor sets zero-to-one depth (Metal NDC); match it.
static Handle(Graphic3d_Camera) makeCam()
{
  Handle(Graphic3d_Camera) cam = new Graphic3d_Camera();
  cam->SetZeroToOneDepth(Standard_True);
  return cam;
}

int main()
{
  {
    TopoDS_Shape box = BRepPrimAPI_MakeBox(10, 5, 3).Shape();
    projectedExtent(box, gp_Dir(0, 1, 0), "boxLinearExtents");
    TopoDS_Shape cyl = BRepPrimAPI_MakeCylinder(5, 20).Shape();
    projectedExtent(cyl, gp_Dir(0, 0, 1), "cylinderTopViewHasDiameters");
    countCircles(cyl, gp_Dir(0, 0, 1), 0.1, "cylinderTopViewHasDiameters");
    countCircles(cyl, gp_Dir(0, 1, 0), 0.1, "cylinderSideViewEdgeOn");
    countCircles(cyl, gp_Dir(0, 0, 1), 100, "minRadiusFilters");
  }
  {
    Handle(Graphic3d_Camera) cam = makeCam();
    gp_Pnt e = cam->Eye(), c = cam->Center();
    gp_Dir u = cam->Up();
    printf("defaultState: eye=(%g, %g, %g) center=(%g, %g, %g) up=(%g, %g, %g)\n", e.X(), e.Y(),
           e.Z(), c.X(), c.Y(), c.Z(), u.X(), u.Y(), u.Z());
    cam->SetAspect(1.5);
    printMat("projectionMatrixNonIdentity (row-major)", cam->ProjectionMatrixF());
  }
  {
    Handle(Graphic3d_Camera) cam = makeCam();
    cam->SetEye(gp_Pnt(0, 0, 10));
    cam->SetCenter(gp_Pnt(0, 0, 0));
    cam->SetUp(gp_Dir(0, 1, 0));
    NCollection_Mat4<float> v1 = cam->OrientationMatrixF();
    cam->SetEye(gp_Pnt(10, 0, 0));
    NCollection_Mat4<float> v2 = cam->OrientationMatrixF();
    printf("viewMatrixChanges: m00 %.9g -> %.9g, m22 %.9g -> %.9g\n", v1.GetValue(0, 0),
           v2.GetValue(0, 0), v1.GetValue(2, 2), v2.GetValue(2, 2));
  }
  {
    Handle(Graphic3d_Camera) cam = makeCam();
    cam->SetEye(gp_Pnt(0, 0, 100));
    cam->SetCenter(gp_Pnt(0, 0, 0));
    cam->SetUp(gp_Dir(0, 1, 0));
    cam->SetFOVy(45);
    cam->SetAspect(1.0);
    cam->SetZRange(1, 1000);
    gp_Pnt s = cam->Project(gp_Pnt(5, 3, 0));
    gp_Pnt w = cam->UnProject(s);
    printf("projectUnprojectRoundtrip: screen=(%.17g, %.17g, %.17g) world=(%.17g, %.17g, %.17g)\n",
           s.X(), s.Y(), s.Z(), w.X(), w.Y(), w.Z());
  }
  {
    Handle(Graphic3d_Camera) cam = makeCam();
    cam->SetEye(gp_Pnt(0, 0, 100));
    cam->SetCenter(gp_Pnt(0, 0, 0));
    cam->SetUp(gp_Dir(0, 1, 0));
    cam->SetAspect(1.0);
    cam->SetZRange(1, 1000);
    cam->SetProjectionType(Graphic3d_Camera::Projection_Perspective);
    NCollection_Mat4<float> p = cam->ProjectionMatrixF();
    cam->SetProjectionType(Graphic3d_Camera::Projection_Orthographic);
    NCollection_Mat4<float> o = cam->ProjectionMatrixF();
    printf("orthographicVsPerspective: m00 %.9g vs %.9g, m32 %.9g vs %.9g\n", p.GetValue(0, 0),
           o.GetValue(0, 0), p.GetValue(3, 2), o.GetValue(3, 2));
  }
  {
    // fitBoundingBox, both the original centred box and the off-centre box of the rewrite.
    double boxes[2][6] = {{-5, -5, -5, 5, 5, 5}, {20, 20, -5, 30, 30, 5}};
    for (auto& bb : boxes)
    {
      Handle(Graphic3d_Camera) cam = makeCam();
      cam->SetEye(gp_Pnt(0, 0, 100));
      cam->SetCenter(gp_Pnt(0, 0, 0));
      cam->SetUp(gp_Dir(0, 1, 0));
      cam->SetAspect(1.0);
      cam->SetZRange(0.1, 10000);
      gp_Pnt mid((bb[0] + bb[3]) / 2, (bb[1] + bb[4]) / 2, (bb[2] + bb[5]) / 2);
      gp_Pnt before = cam->Project(mid);
      Bnd_Box box;
      box.Update(bb[0], bb[1], bb[2], bb[3], bb[4], bb[5]);
      cam->FitMinMax(box, 0.01, false);
      gp_Pnt after = cam->Project(mid);
      gp_Pnt ctr = cam->Center();
      double mx = 0;
      for (int i = 0; i < 8; ++i)
      {
        gp_Pnt s = cam->Project(gp_Pnt(i & 1 ? bb[3] : bb[0], i & 2 ? bb[4] : bb[1], i & 4 ? bb[5] : bb[2]));
        mx = std::max(mx, std::max(std::abs(s.X()), std::abs(s.Y())));
      }
      printf("fitBoundingBox box=(%g..%g): mid before=(%.17g, %.17g) after=(%.17g, %.17g) "
             "center=(%.17g, %.17g, %.17g) max|corner ndc|=%.17g\n",
             bb[0], bb[3], before.X(), before.Y(), after.X(), after.Y(), ctr.X(), ctr.Y(), ctr.Z(), mx);
    }
  }
  return 0;
}
