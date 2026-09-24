// Epic #766, OCCTMeshTests.swift "Mesh Tests" suite: kernel parity for its ten tests.
// ("Mesh from raw arrays" has no kernel counterpart: OCCTMeshCreateFromArrays calls no OCCT API.)
// Same inputs as the Swift tests, straight to OCCT. extract() is what OCCTShapeCreateMesh does
// (BRepMesh_IncrementalMesh, then each face's Poly_Triangulation concatenated, wound by the face's
// orientation, vertices narrowed to float); toShape() is OCCTMeshToShapeWithTolerance (one
// BRepBuilderAPI_MakeFace per triangle, BRepBuilderAPI_Sewing at the weld tolerance); the mesh
// booleans are toShape() on both meshes, BRepAlgoAPI_Fuse / Cut / Common, then extract() at 0.5.
#include <BRepAlgoAPI_Common.hxx>
#include <BRepGProp.hxx>
#include <GProp_GProps.hxx>
#include <BRepAlgoAPI_Cut.hxx>
#include <BRepAlgoAPI_Fuse.hxx>
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepBuilderAPI_MakeWire.hxx>
#include <BRepBuilderAPI_Sewing.hxx>
#include <BRepBuilderAPI_Transform.hxx>
#include <BRepMesh_IncrementalMesh.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <BRepPrimAPI_MakeSphere.hxx>
#include <BRep_Tool.hxx>
#include <IMeshTools_Parameters.hxx>
#include <Poly_Triangulation.hxx>
#include <TopExp.hxx>
#include <TopExp_Explorer.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopoDS.hxx>
#include <cstdio>
#include <utility>
#include <vector>

struct M
{
  std::vector<float>    v;
  std::vector<uint32_t> idx;
  std::vector<int>      face;
  bool                  allHaveNormals = true;
};

static M collect(const TopoDS_Shape& s)
{
  M                          m;
  TopTools_IndexedMapOfShape map;
  for (TopExp_Explorer ex(s, TopAbs_FACE); ex.More(); ex.Next())
  {
    map.Add(ex.Current());
    const TopoDS_Face&         f = TopoDS::Face(ex.Current());
    TopLoc_Location            loc;
    Handle(Poly_Triangulation) t = BRep_Tool::Triangulation(f, loc);
    if (t.IsNull())
      continue;
    m.allHaveNormals = m.allHaveNormals && t->HasNormals();
    uint32_t base    = (uint32_t)(m.v.size() / 3);
    for (int i = 1; i <= t->NbNodes(); i++)
    {
      gp_Pnt p = t->Node(i).Transformed(loc);
      m.v.push_back((float)p.X());
      m.v.push_back((float)p.Y());
      m.v.push_back((float)p.Z());
    }
    for (int i = 1; i <= t->NbTriangles(); i++)
    {
      int a, b, c;
      t->Triangle(i).Get(a, b, c);
      if (f.Orientation() == TopAbs_REVERSED)
        std::swap(b, c);
      m.idx.push_back(base + a - 1);
      m.idx.push_back(base + b - 1);
      m.idx.push_back(base + c - 1);
      m.face.push_back(map.FindIndex(ex.Current()) - 1);
    }
  }
  return m;
}

static M extract(const TopoDS_Shape& s, double lin, double ang = 0.5)
{
  BRepMesh_IncrementalMesh(s, lin, Standard_False, ang);
  return collect(s);
}

static TopoDS_Shape toShape(const M& m, double tol)
{
  BRepBuilderAPI_Sewing sew(tol);
  for (size_t i = 0; i + 2 < m.idx.size(); i += 3)
  {
    gp_Pnt p[3];
    for (int k = 0; k < 3; k++)
      p[k] = gp_Pnt(m.v[m.idx[i + k] * 3], m.v[m.idx[i + k] * 3 + 1], m.v[m.idx[i + k] * 3 + 2]);
    if (p[0].Distance(p[1]) < 1e-9 || p[1].Distance(p[2]) < 1e-9 || p[2].Distance(p[0]) < 1e-9)
      continue;
    BRepBuilderAPI_MakeWire w;
    w.Add(BRepBuilderAPI_MakeEdge(p[0], p[1]));
    w.Add(BRepBuilderAPI_MakeEdge(p[1], p[2]));
    w.Add(BRepBuilderAPI_MakeEdge(p[2], p[0]));
    if (!w.IsDone())
      continue;
    BRepBuilderAPI_MakeFace f(w.Wire());
    if (f.IsDone())
      sew.Add(f.Face());
  }
  sew.Perform();
  return sew.SewedShape();
}

static int nEdges(const TopoDS_Shape& s)
{
  TopTools_IndexedMapOfShape e;
  TopExp::MapShapes(s, TopAbs_EDGE, e);
  return e.Extent();
}

// Signed volume by the divergence theorem, in double from the float vertices.
static double volume(const M& m)
{
  double vol = 0;
  for (size_t i = 0; i + 2 < m.idx.size(); i += 3)
  {
    const float* a = &m.v[m.idx[i] * 3];
    const float* b = &m.v[m.idx[i + 1] * 3];
    const float* c = &m.v[m.idx[i + 2] * 3];
    vol += ((double)a[0] * ((double)b[1] * c[2] - (double)b[2] * c[1])
            - (double)a[1] * ((double)b[0] * c[2] - (double)b[2] * c[0])
            + (double)a[2] * ((double)b[0] * c[1] - (double)b[1] * c[0]))
           / 6.0;
  }
  return vol;
}

static TopoDS_Shape box(double w, double h, double d)
{
  return BRepPrimAPI_MakeBox(gp_Pnt(-w / 2, -h / 2, -d / 2), w, h, d).Shape();
}

static void report(const char* label, const M& m)
{
  printf("  %s: vertexCount=%zu triangleCount=%zu volume=%.6f\n", label, m.v.size() / 3,
         m.idx.size() / 3, volume(m));
}

int main()
{
  printf("meshFromShape:\n");
  report("box 10x5x3 at 0.1", extract(box(10, 5, 3), 0.1));

  printf("meshDataAccess:\n");
  {
    M m = extract(BRepPrimAPI_MakeSphere(5).Shape(), 0.5);
    report("sphere r5 at 0.5", m);
    printf("  every face triangulation carries normals: %d\n", m.allHaveNormals);
  }

  printf("enhancedMeshParameters:\n");
  {
    TopoDS_Shape          b = box(10, 10, 10);
    IMeshTools_Parameters p;
    p.Deflection               = 0.05;
    p.Angle                    = 0.5;
    p.DeflectionInterior       = 0.05;
    p.AngleInterior            = 0.5;
    p.MinSize                  = 0.0;
    p.InParallel               = Standard_True;
    p.InternalVerticesMode     = Standard_True;
    p.ControlSurfaceDeflection = Standard_True;
    BRepMesh_IncrementalMesh mesher(b, p);
    mesher.Perform();
    report("box 10 at 0.05 (parameters)", collect(b));
  }

  printf("trianglesWithFaces:\n");
  {
    M   m  = extract(box(10, 10, 10), 0.1);
    int lo = 99, hi = -99;
    for (int f : m.face)
    {
      lo = std::min(lo, f);
      hi = std::max(hi, f);
    }
    report("box 10 at 0.1", m);
    printf("  faceIndex range %d...%d\n", lo, hi);
  }

  printf("meshToShape / meshToShapeWeldTolerance:\n");
  {
    M            m = extract(box(10, 10, 10), 0.5);
    TopoDS_Shape d = toShape(m, 1e-6);
    printf("  box mesh toShape(1e-6): null=%d edges=%d\n", d.IsNull(), nEdges(d));
    M g;
    g.v   = {0, 0, 0, 10, 0, 0, 5, 5, 0, 0, 0.5f, 0, 10, 0.5f, 0, 5, -5, 0};
    g.idx = {0, 1, 2, 3, 4, 5};
    printf("  gappy mesh: edges at 1e-6=%d, at 2.0=%d\n", nEdges(toShape(g, 1e-6)), nEdges(toShape(g, 2.0)));
  }

  printf("mesh booleans (deflection 0.5):\n");
  {
    M            b1 = extract(box(10, 10, 10), 0.5);
    gp_Trsf      tr;
    tr.SetTranslation(gp_Vec(5, 0, 0));
    TopoDS_Shape moved = BRepBuilderAPI_Transform(box(10, 10, 10), tr, Standard_True).Shape();
    M            b2    = extract(moved, 0.5);
    TopoDS_Shape s1 = toShape(b1, 1e-6), s2 = toShape(b2, 1e-6);
    report("union", extract(BRepAlgoAPI_Fuse(s1, s2).Shape(), 0.5));
    report("  (subtract, same inputs)", extract(BRepAlgoAPI_Cut(s1, s2).Shape(), 0.5));
    report("  (intersect, same inputs)", extract(BRepAlgoAPI_Common(s1, s2).Shape(), 0.5));
  }
  {
    M            b   = extract(box(10, 10, 10), 0.5);
    M            cyl = extract(BRepPrimAPI_MakeCylinder(3, 15).Shape(), 0.5);
    TopoDS_Shape s1 = toShape(b, 1e-6), s2 = toShape(cyl, 1e-6);
    report("subtraction (box - cylinder r3 h15)", extract(BRepAlgoAPI_Cut(s1, s2).Shape(), 0.5));
    report("  (union, same inputs)", extract(BRepAlgoAPI_Fuse(s1, s2).Shape(), 0.5));
  }
  {
    M            b  = extract(box(10, 10, 10), 0.5);
    M            sp = extract(BRepPrimAPI_MakeSphere(7).Shape(), 0.5);
    TopoDS_Shape s1 = toShape(b, 1e-6), s2 = toShape(sp, 1e-6);
    report("intersection (box and sphere r7)", extract(BRepAlgoAPI_Common(s1, s2).Shape(), 0.5));
    report("  (union, same inputs)", extract(BRepAlgoAPI_Fuse(s1, s2).Shape(), 0.5));
  }

  // What the same booleans give on the original solids: the geometry the mesh booleans are
  // documented to produce. The sewn meshes above are shells, not solids.
  printf("reference: the same booleans on the B-Rep solids, BRepGProp::VolumeProperties:\n");
  {
    gp_Trsf tr;
    tr.SetTranslation(gp_Vec(5, 0, 0));
    TopoDS_Shape b     = box(10, 10, 10);
    TopoDS_Shape moved = BRepBuilderAPI_Transform(box(10, 10, 10), tr, Standard_True).Shape();
    GProp_GProps g;
    BRepGProp::VolumeProperties(BRepAlgoAPI_Fuse(b, moved).Shape(), g);
    printf("  union of the two boxes: %.6f\n", g.Mass());
    GProp_GProps g2;
    BRepGProp::VolumeProperties(BRepAlgoAPI_Cut(b, BRepPrimAPI_MakeCylinder(3, 15).Shape()).Shape(), g2);
    printf("  box - cylinder: %.6f\n", g2.Mass());
    GProp_GProps g3;
    BRepGProp::VolumeProperties(BRepAlgoAPI_Common(b, BRepPrimAPI_MakeSphere(7).Shape()).Shape(), g3);
    printf("  box and sphere r7: %.6f\n", g3.Mass());
  }
  {
    M            b1 = extract(box(10, 10, 10), 0.5);
    TopoDS_Shape s1 = toShape(b1, 1e-6);
    printf("  toShape(box mesh) top-level type: %d (TopAbs_SHELL=%d, TopAbs_SOLID=%d)\n", s1.ShapeType(),
           TopAbs_SHELL, TopAbs_SOLID);
  }
  return 0;
}
