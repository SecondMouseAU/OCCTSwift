// Kernel-parity probe for Tests/OCCTAnalysisTests/MeasurementTests.swift (#766 execution,
// issues #1768-#1785). Each block calls the OCCT API the bridge function it names reaches, with
// the inputs the Swift test uses, and prints what the kernel returns. See transcript.txt.
//
// Build: see CLAUDE.md "Compile a Ground Truth C++ Test", with -I/-L pointed at the xcframework.

#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <BRepPrimAPI_MakeSphere.hxx>
#include <BRepBuilderAPI_Transform.hxx>
#include <BRepGProp.hxx>
#include <GProp_GProps.hxx>
#include <BRepExtrema_DistShapeShape.hxx>
#include <TopExp.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopoDS.hxx>
#include <BRep_Tool.hxx>
#include <gp_Trsf.hxx>
#include <cstdio>

// OCCTShapeCreateBox: centred box.
static TopoDS_Shape box10()
{
  return BRepPrimAPI_MakeBox(gp_Pnt(-5, -5, -5), 10, 10, 10).Shape();
}

// OCCTShapeTranslate
static TopoDS_Shape translated(const TopoDS_Shape& s, double dx, double dy, double dz)
{
  gp_Trsf t;
  t.SetTranslation(gp_Vec(dx, dy, dz));
  return BRepBuilderAPI_Transform(s, t, Standard_True).Shape();
}

// OCCTShapeGetVolume / OCCTShapeGetCenterOfMass / OCCTShapeGetProperties: occtVolumeMassProperties
static GProp_GProps volumeProps(const TopoDS_Shape& s)
{
  GProp_GProps p;
  BRepGProp::VolumeProperties(s, p, Standard_True);
  return p;
}

// OCCTShapeGetSurfaceArea
static double area(const TopoDS_Shape& s)
{
  GProp_GProps p;
  BRepGProp::SurfaceProperties(s, p);
  return p.Mass();
}

int main()
{
  TopoDS_Shape box = box10();
  TopoDS_Shape cyl = BRepPrimAPI_MakeCylinder(5, 10).Shape();
  TopoDS_Shape sph = BRepPrimAPI_MakeSphere(5).Shape();

  printf("volumeOfBox: %.12f\n", volumeProps(box).Mass());
  printf("volumeOfCylinder: %.12f (pi*25*10 = %.12f)\n", volumeProps(cyl).Mass(), M_PI * 250.0);
  printf("volumeOfSphere: %.12f (4/3*pi*125 = %.12f)\n",
         volumeProps(sph).Mass(),
         4.0 / 3.0 * M_PI * 125.0);
  printf("surfaceAreaOfBox: %.12f\n", area(box));
  printf("surfaceAreaOfSphere: %.12f (4*pi*25 = %.12f)\n", area(sph), 4.0 * M_PI * 25.0);

  gp_Pnt c0 = volumeProps(box).CentreOfMass();
  printf("centerOfMassBox: (%.12f, %.12f, %.12f)\n", c0.X(), c0.Y(), c0.Z());
  gp_Pnt c1 = volumeProps(translated(box, 100, 200, 300)).CentreOfMass();
  printf("centerOfMassTranslatedBox: (%.12f, %.12f, %.12f)\n", c1.X(), c1.Y(), c1.Z());

  {
    GProp_GProps vp = volumeProps(box);
    double       density = 2.5;
    gp_Pnt       c       = vp.CentreOfMass();
    printf("fullShapeProperties: volume=%.12f area=%.12f mass=%.12f com=(%.12f, %.12f, %.12f)\n",
           vp.Mass(),
           area(box),
           vp.Mass() * density,
           c.X(),
           c.Y(),
           c.Z());
  }

  {
    BRepExtrema_DistShapeShape d(box, translated(box, 20, 0, 0), 1e-6);
    printf("distanceBetweenBoxes: done=%d n=%d value=%.12f\n",
           (int)d.IsDone(),
           d.NbSolution(),
           d.Value());
  }
  {
    BRepExtrema_DistShapeShape d(box, translated(box, 10, 0, 0), 1e-6);
    printf("distanceBetweenTouchingBoxes: done=%d n=%d value=%.12f\n",
           (int)d.IsDone(),
           d.NbSolution(),
           d.Value());
  }
  {
    TopoDS_Shape s2 = translated(BRepPrimAPI_MakeSphere(3).Shape(), 15, 0, 0);
    BRepExtrema_DistShapeShape d(sph, s2, 1e-6);
    printf("minDistanceConvenience: done=%d n=%d value=%.12f\n",
           (int)d.IsDone(),
           d.NbSolution(),
           d.Value());
  }

  // OCCTShapeIntersects: DistShapeShape(tolerance) then Value() <= tolerance.
  {
    BRepExtrema_DistShapeShape d(box, BRepPrimAPI_MakeSphere(3).Shape(), 1e-6);
    printf("intersectsOverlapping: value=%.12f intersects=%d\n",
           d.Value(),
           (int)(d.IsDone() && d.NbSolution() > 0 && d.Value() <= 1e-6));
  }
  {
    BRepExtrema_DistShapeShape d(box, translated(BRepPrimAPI_MakeSphere(3).Shape(), 50, 0, 0), 1e-6);
    printf("intersectsSeparated: value=%.12f intersects=%d\n",
           d.Value(),
           (int)(d.IsDone() && d.NbSolution() > 0 && d.Value() <= 1e-6));
  }
  {
    BRepExtrema_DistShapeShape d(box, translated(sph, 10, 0, 0), 0.1);
    printf("intersectsTouching: value=%.12f intersects=%d\n",
           d.Value(),
           (int)(d.IsDone() && d.NbSolution() > 0 && d.Value() <= 0.1));
  }

  // OCCTShapeGetVertexCount / OCCTShapeGetVertices / OCCTShapeGetVertexAt: TopExp::MapShapes.
  {
    TopTools_IndexedMapOfShape m;
    TopExp::MapShapes(box, TopAbs_VERTEX, m);
    printf("vertexCountBox / getAllVertices: %d\n", m.Extent());
    for (int i = 1; i <= m.Extent(); ++i)
    {
      gp_Pnt p = BRep_Tool::Pnt(TopoDS::Vertex(m(i)));
      printf("  vertex[%d] = (%g, %g, %g)\n", i - 1, p.X(), p.Y(), p.Z());
    }
    printf("vertexOutOfBounds: index 100 >= extent %d -> nil\n", m.Extent());
  }
  return 0;
}
