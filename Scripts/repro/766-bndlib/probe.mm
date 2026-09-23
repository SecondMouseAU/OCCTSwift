// Epic #766, Tests/OCCTAnalysisTests/BndLibTests.swift: kernel parity probe.
// Calls the same OCCT API as each OCCTBndLib* bridge function, with the test's inputs.
#include <BndLib.hxx>
#include <BndLib_Add3dCurve.hxx>
#include <BndLib_AddSurface.hxx>
#include <Bnd_Box.hxx>
#include <BRepAdaptor_Curve.hxx>
#include <BRepAdaptor_Surface.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeSphere.hxx>
#include <TopExp.hxx>
#include <TopoDS.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <gp_Circ.hxx>
#include <gp_Cylinder.hxx>
#include <gp_Lin.hxx>
#include <gp_Sphere.hxx>
#include <gp_Torus.hxx>
#include <cstdio>

static void dump(const char* name, const Bnd_Box& b)
{
  double x0, y0, z0, x1, y1, z1;
  b.Get(x0, y0, z0, x1, y1, z1);
  printf("%s min=(%.17g, %.17g, %.17g) max=(%.17g, %.17g, %.17g)\n", name, x0, y0, z0, x1, y1, z1);
}

int main()
{
  {
    // OCCTBndLibLine
    Bnd_Box b;
    BndLib::Add(gp_Lin(gp_Pnt(0, 0, 0), gp_Dir(1, 0, 0)), 0, 10, 0, b);
    dump("lineSegmentBounds", b);
  }
  {
    // OCCTBndLibCircle
    Bnd_Box b;
    BndLib::Add(gp_Circ(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 5), 0, b);
    dump("circleBounds", b);
  }
  {
    // OCCTBndLibSphere
    Bnd_Box b;
    BndLib::Add(gp_Sphere(gp_Ax3(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 3), 0, b);
    dump("sphereBounds", b);
  }
  {
    // OCCTBndLibCylinder
    Bnd_Box b;
    BndLib::Add(gp_Cylinder(gp_Ax3(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 2), 0, 10, 0, b);
    dump("cylinderBounds", b);
  }
  {
    // OCCTBndLibTorus
    Bnd_Box b;
    BndLib::Add(gp_Torus(gp_Ax3(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 10, 2), 0, b);
    dump("torusBounds", b);
  }
  {
    // OCCTBndLibEdge over every edge of Shape.box(width: 10, height: 20, depth: 30), which
    // OCCTShapeCreateBox centres on the origin. Edges enumerated as OCCTShapeGetSubShapes does.
    TopoDS_Shape               box = BRepPrimAPI_MakeBox(gp_Pnt(-5, -10, -15), 10, 20, 30).Shape();
    TopTools_IndexedMapOfShape map;
    TopExp::MapShapes(box, TopAbs_EDGE, map);
    printf("edgeBounds edge count=%d\n", map.Extent());
    for (int i = 1; i <= map.Extent(); ++i)
    {
      Bnd_Box           b;
      BRepAdaptor_Curve ac(TopoDS::Edge(map(i)));
      BndLib_Add3dCurve::Add(ac, 0, b);
      char name[64];
      snprintf(name, sizeof(name), "edgeBounds edge[%d]", i - 1);
      dump(name, b);
    }
  }
  {
    // OCCTBndLibFace on the first face of Shape.sphere(radius: 5).
    TopoDS_Shape               sph = BRepPrimAPI_MakeSphere(5).Shape();
    TopTools_IndexedMapOfShape map;
    TopExp::MapShapes(sph, TopAbs_FACE, map);
    printf("faceBounds face count=%d\n", map.Extent());
    Bnd_Box             b;
    BRepAdaptor_Surface as(TopoDS::Face(map(1)));
    BndLib_AddSurface::Add(as, 0, b);
    dump("faceBounds face[0]", b);
  }
  return 0;
}
