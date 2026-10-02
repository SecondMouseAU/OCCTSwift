// Epic #766, OCCTMeshTests.swift suites "Presentation Mesh Tests", "Drawer Mesh Extraction",
// "Issue1224 Presentation Mesh Overload Parity", "MeshCoordinateSystem Enum", "BRepMesh Deflection"
// and "BRepBuilderAPI MakeShapeOnMesh": kernel parity for their 18 tests.
// Same inputs as the Swift tests, straight to OCCT. shaded() / edges() are what
// OCCTShapeGetShadedMesh / OCCTShapeGetEdgeMesh count (BRepMesh_IncrementalMesh, then per-face
// triangulations, and per-edge PolygonOnTriangulation / Polygon3D / GCPnts_TangentialDeflection);
// the drawer variants first mesh at occtDrawerGetEffectiveDeflection's value and DeviationAngle(),
// as OCCTShapeGetShadedMeshWithDrawer does.
#include <BRepAdaptor_Curve.hxx>
#include <BRepBndLib.hxx>
#include <BRepBuilderAPI_MakeShapeOnMesh.hxx>
#include <BRepCheck_Analyzer.hxx>
#include <BRepMesh_Deflection.hxx>
#include <BRepMesh_IncrementalMesh.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <BRepPrimAPI_MakeSphere.hxx>
#include <BRep_Tool.hxx>
#include <Bnd_Box.hxx>
#include <GCPnts_TangentialDeflection.hxx>
#include <Poly_Array1OfTriangle.hxx>
#include <Poly_Polygon3D.hxx>
#include <TColgp_Array1OfPnt.hxx>
#include <Poly_PolygonOnTriangulation.hxx>
#include <Poly_Triangulation.hxx>
#include <Prs3d.hxx>
#include <Prs3d_Drawer.hxx>
#include <RWMesh_CoordinateSystem.hxx>
#include <TopExp.hxx>
#include <TopExp_Explorer.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopoDS.hxx>
#include <cstdio>

static TopoDS_Shape box(double w, double h, double d)
{
  return BRepPrimAPI_MakeBox(gp_Pnt(-w / 2, -h / 2, -d / 2), w, h, d).Shape();
}

static void shaded(const TopoDS_Shape& s, double defl, const char* label)
{
  BRepMesh_IncrementalMesh m(s, defl);
  m.Perform();
  int v = 0, t = 0;
  for (TopExp_Explorer ex(s, TopAbs_FACE); ex.More(); ex.Next())
  {
    TopLoc_Location            loc;
    Handle(Poly_Triangulation) tri = BRep_Tool::Triangulation(TopoDS::Face(ex.Current()), loc);
    if (!tri.IsNull())
    {
      v += tri->NbNodes();
      t += tri->NbTriangles();
    }
  }
  printf("  %s: shaded vertexCount=%d triangleCount=%d\n", label, v, t);
}

static void edges(const TopoDS_Shape& s, double defl, const char* label)
{
  BRepMesh_IncrementalMesh m(s, defl);
  m.Perform();
  TopTools_IndexedMapOfShape em;
  TopExp::MapShapes(s, TopAbs_EDGE, em);
  int segs = 0, verts = 0, onTri = 0, p3d = 0, disc = 0;
  for (int ei = 1; ei <= em.Extent(); ei++)
  {
    TopoDS_Edge e     = TopoDS::Edge(em(ei));
    bool        found = false;
    for (TopExp_Explorer fx(s, TopAbs_FACE); fx.More() && !found; fx.Next())
    {
      TopLoc_Location            loc;
      Handle(Poly_Triangulation) tri = BRep_Tool::Triangulation(TopoDS::Face(fx.Current()), loc);
      if (tri.IsNull())
        continue;
      TopLoc_Location                     el;
      Handle(Poly_PolygonOnTriangulation) p = BRep_Tool::PolygonOnTriangulation(e, tri, el);
      if (p.IsNull() || p->Nodes().Length() < 2)
        continue;
      segs++;
      onTri++;
      verts += p->Nodes().Length();
      found = true;
    }
    if (found)
      continue;
    TopLoc_Location        loc;
    Handle(Poly_Polygon3D) p3 = BRep_Tool::Polygon3D(e, loc);
    if (!p3.IsNull() && p3->NbNodes() >= 2)
    {
      segs++;
      p3d++;
      verts += p3->NbNodes();
      continue;
    }
    try
    {
      BRepAdaptor_Curve           c(e);
      GCPnts_TangentialDeflection d(c, defl, 0.1);
      if (d.NbPoints() >= 2)
      {
        segs++;
        disc++;
        verts += d.NbPoints();
      }
    }
    catch (...)
    {
    }
  }
  printf("  %s: distinct edges=%d segmentCount=%d vertexCount=%d (onTriangulation=%d polygon3D=%d discretised=%d)\n",
         label, em.Extent(), segs, verts, onTri, p3d, disc);
}

static double effective(const Handle(Prs3d_Drawer)& d, const TopoDS_Shape& s)
{
  if (d->TypeOfDeflection() != Aspect_TOD_RELATIVE)
    return d->MaximalChordialDeviation();
  Bnd_Box b;
  BRepBndLib::Add(s, b, false);
  return Prs3d::GetDeflection(b, d->DeviationCoefficient(), d->MaximalChordialDeviation());
}

static void drawerShaded(const TopoDS_Shape& s, const Handle(Prs3d_Drawer)& d, const char* label)
{
  double defl = effective(d, s);
  BRepMesh_IncrementalMesh(s, defl, Standard_False, d->DeviationAngle());
  printf("  %s: effective deflection=%.17g angle=%.17g\n", label, defl, d->DeviationAngle());
  shaded(s, defl, label);
}

int main()
{
  printf("Presentation Mesh Tests:\n");
  shaded(box(10, 10, 10), 0.1, "box 10 at 0.1");
  shaded(BRepPrimAPI_MakeCylinder(5, 10).Shape(), 0.1, "cylinder r5 h10 at 0.1");
  edges(box(10, 10, 10), 0.1, "box 10 at 0.1");
  edges(BRepPrimAPI_MakeSphere(5).Shape(), 0.1, "sphere r5 at 0.1");

  printf("Drawer Mesh Extraction:\n");
  {
    Handle(Prs3d_Drawer) d = new Prs3d_Drawer();
    printf("  default drawer: type=%d (RELATIVE=%d) coefficient=%.17g maxChordial=%.17g angle=%.17g\n",
           d->TypeOfDeflection(), Aspect_TOD_RELATIVE, d->DeviationCoefficient(),
           d->MaximalChordialDeviation(), d->DeviationAngle());
    TopoDS_Shape b = box(10, 10, 10);
    drawerShaded(b, d, "box 10, default drawer");
    TopoDS_Shape b2 = box(10, 10, 10);
    BRepMesh_IncrementalMesh(b2, effective(d, b2), Standard_False, d->DeviationAngle());
    edges(b2, effective(d, b2), "box 10, default drawer");
  }
  {
    TopoDS_Shape         s = BRepPrimAPI_MakeSphere(10).Shape();
    Handle(Prs3d_Drawer) c = new Prs3d_Drawer();
    c->SetDeviationCoefficient(0.1);
    Handle(Prs3d_Drawer) f = new Prs3d_Drawer();
    f->SetDeviationCoefficient(0.001);
    drawerShaded(s, c, "sphere r10, coefficient 0.1");
    drawerShaded(s, f, "same sphere, then coefficient 0.001");
  }
  {
    Handle(Prs3d_Drawer) d = new Prs3d_Drawer();
    d->SetTypeOfDeflection(Aspect_TOD_ABSOLUTE);
    d->SetMaximalChordialDeviation(0.5);
    drawerShaded(box(10, 10, 10), d, "box 10, absolute 0.5");
    drawerShaded(BRepPrimAPI_MakeSphere(10).Shape(), d, "sphere r10, absolute 0.5");
  }
  {
    Handle(Prs3d_Drawer) d = new Prs3d_Drawer();
    drawerShaded(BRepPrimAPI_MakeSphere(1).Shape(), d, "sphere r1, default drawer");
    drawerShaded(BRepPrimAPI_MakeSphere(50).Shape(), d, "sphere r50, default drawer");
  }

  printf("Issue1224 overload parity (absolute 0.1 drawer vs deflection 0.1):\n");
  {
    Handle(Prs3d_Drawer) d = new Prs3d_Drawer();
    d->SetTypeOfDeflection(Aspect_TOD_ABSOLUTE);
    d->SetMaximalChordialDeviation(0.1);
    shaded(box(10, 10, 10), 0.1, "box 10, deflection 0.1");
    drawerShaded(box(10, 10, 10), d, "box 10, drawer");
    edges(box(10, 10, 10), 0.1, "box 10, deflection 0.1");
  }

  printf("MeshCoordinateSystem: RWMesh_CoordinateSystem_Undefined=%d Zup=%d Yup=%d Blender=%d glTF=%d\n",
         RWMesh_CoordinateSystem_Undefined, RWMesh_CoordinateSystem_Zup, RWMesh_CoordinateSystem_Yup,
         RWMesh_CoordinateSystem_Blender, RWMesh_CoordinateSystem_glTF);

  printf("BRepMesh Deflection:\n");
  printf("  ComputeAbsoluteDeflection(box 10x20x30, 0.01, 30) = %.17g\n",
         BRepMesh_Deflection::ComputeAbsoluteDeflection(box(10, 20, 30), 0.01, 30.0));
  double cases[][2] = {{0.1, 0.2}, {0.2, 0.2}, {0.21, 0.2}, {0.3, 0.2}, {0.05, 0.2}, {0.01, 0.2}};
  for (auto& c : cases)
    printf("  IsConsistent(current=%g, required=%g, allowDecrease=false, ratio=0.1) = %d\n", c[0], c[1],
           BRepMesh_Deflection::IsConsistent(c[0], c[1], Standard_False, 0.1));

  printf("BRepBuilderAPI_MakeShapeOnMesh:\n");
  {
    TColgp_Array1OfPnt nodes(1, 4);
    nodes(1) = gp_Pnt(0, 0, 0);
    nodes(2) = gp_Pnt(10, 0, 0);
    nodes(3) = gp_Pnt(5, 10, 0);
    nodes(4) = gp_Pnt(5, 5, 10);
    Poly_Array1OfTriangle tris(1, 4);
    tris(1)                       = Poly_Triangle(1, 3, 2);
    tris(2)                       = Poly_Triangle(1, 2, 4);
    tris(3)                       = Poly_Triangle(2, 3, 4);
    tris(4)                       = Poly_Triangle(3, 1, 4);
    BRepBuilderAPI_MakeShapeOnMesh mk(new Poly_Triangulation(nodes, tris));
    mk.Build();
    TopTools_IndexedMapOfShape f, e;
    TopExp::MapShapes(mk.Shape(), TopAbs_FACE, f);
    TopExp::MapShapes(mk.Shape(), TopAbs_EDGE, e);
    printf("  tetrahedron: done=%d type=%d faces=%d edges=%d valid=%d\n", mk.IsDone(), mk.Shape().ShapeType(),
           f.Extent(), e.Extent(), BRepCheck_Analyzer(mk.Shape()).IsValid());
  }
  {
    TColgp_Array1OfPnt nodes(1, 3);
    nodes(1) = gp_Pnt(0, 0, 0);
    nodes(2) = gp_Pnt(10, 0, 0);
    nodes(3) = gp_Pnt(5, 10, 0);
    Poly_Array1OfTriangle tris(1, 1);
    tris(1)                       = Poly_Triangle(1, 2, 3);
    BRepBuilderAPI_MakeShapeOnMesh mk(new Poly_Triangulation(nodes, tris));
    mk.Build();
    TopTools_IndexedMapOfShape f;
    TopExp::MapShapes(mk.Shape(), TopAbs_FACE, f);
    printf("  single triangle: done=%d null=%d faces=%d\n", mk.IsDone(), mk.Shape().IsNull(), f.Extent());
  }
  return 0;
}
