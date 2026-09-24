// Epic #766, Issue613MeshIndexContractTests.swift: kernel parity for all nine tests.
// Same inputs as the Swift tests, straight to OCCT: a 20x10x10 BRepPrimAPI_MakeBox at the origin,
// split by BRepAlgoAPI_Splitter with a 60x60 planar face rotated pi/2 about Y and moved to x = 10
// (the Swift fixture's Wire.rectangle -> Shape.face -> rotated -> translated), the resulting solids
// gathered into a compound. Then: TopExp::MapShapes face count vs TopExp_Explorer occurrences,
// BRepMesh_IncrementalMesh at 0.5 with each triangle wound by its face occurrence's orientation and
// indexed by the face's map index (occtForEachOrientedFace), and Poly_MergeNodesTool at
// smoothAngle 0.5 fed each occurrence with its REVERSED flag (OCCTPolyMergeNodes).
#include <BRepAlgoAPI_Splitter.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepBuilderAPI_MakePolygon.hxx>
#include <BRepBuilderAPI_Transform.hxx>
#include <BRepMesh_IncrementalMesh.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRep_Builder.hxx>
#include <BRep_Tool.hxx>
#include <IMeshTools_Parameters.hxx>
#include <Poly_MergeNodesTool.hxx>
#include <Poly_Triangulation.hxx>
#include <TopExp.hxx>
#include <TopExp_Explorer.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopTools_ListOfShape.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Compound.hxx>
#include <cmath>
#include <cstdio>
#include <map>
#include <set>
#include <utility>

static TopoDS_Shape splitBoxCompound()
{
  TopoDS_Shape block = BRepPrimAPI_MakeBox(gp_Pnt(0, 0, 0), 20, 10, 10).Shape();
  BRepBuilderAPI_MakePolygon poly(gp_Pnt(-30, -30, 0), gp_Pnt(30, -30, 0), gp_Pnt(30, 30, 0),
                                  gp_Pnt(-30, 30, 0), Standard_True);
  TopoDS_Shape plate = BRepBuilderAPI_MakeFace(poly.Wire(), Standard_True).Shape();
  gp_Trsf      rot;
  rot.SetRotation(gp_Ax1(gp_Pnt(0, 0, 0), gp_Dir(0, 1, 0)), M_PI / 2);
  TopoDS_Shape upright = BRepBuilderAPI_Transform(plate, rot, Standard_True).Shape();
  gp_Trsf      mv;
  mv.SetTranslation(gp_Vec(10, 0, 0));
  TopoDS_Shape knife = BRepBuilderAPI_Transform(upright, mv, Standard_True).Shape();

  BRepAlgoAPI_Splitter splitter;
  TopTools_ListOfShape args, tools;
  args.Append(block);
  tools.Append(knife);
  splitter.SetArguments(args);
  splitter.SetTools(tools);
  splitter.Build();
  BRep_Builder    bb;
  TopoDS_Compound c;
  bb.MakeCompound(c);
  int nSolids = 0;
  for (TopExp_Explorer ex(splitter.Shape(), TopAbs_SOLID); ex.More(); ex.Next(), nSolids++)
    bb.Add(c, ex.Current());
  printf("fixture: splitter done=%d solids=%d\n", splitter.IsDone(), nSolids);
  return c;
}

struct MeshScan
{
  int                      triangles = 0;
  std::set<int>            indices;
  std::map<int, int>       wallPlus, wallMinus;
  int                      outward = 0, inward = 0;
};

// One mesh extraction, as OCCTShapeCreateMesh[WithParams] does it.
static MeshScan scan(const TopoDS_Shape& s)
{
  MeshScan                   r;
  TopTools_IndexedMapOfShape map;
  for (TopExp_Explorer ex(s, TopAbs_FACE); ex.More(); ex.Next())
  {
    map.Add(ex.Current());
    int                        idx = map.FindIndex(ex.Current()) - 1;
    const TopoDS_Face&         f   = TopoDS::Face(ex.Current());
    TopLoc_Location            loc;
    Handle(Poly_Triangulation) t = BRep_Tool::Triangulation(f, loc);
    if (t.IsNull())
      continue;
    for (int i = 1; i <= t->NbTriangles(); i++)
    {
      int n1, n2, n3;
      t->Triangle(i).Get(n1, n2, n3);
      if (f.Orientation() == TopAbs_REVERSED)
        std::swap(n2, n3);
      gp_Pnt a = t->Node(n1).Transformed(loc), b = t->Node(n2).Transformed(loc),
             c = t->Node(n3).Transformed(loc);
      gp_Vec n = gp_Vec(a, b).Crossed(gp_Vec(a, c));
      r.triangles++;
      r.indices.insert(idx);
      if (std::fabs(a.X() - 10) < 1e-4 && std::fabs(b.X() - 10) < 1e-4 && std::fabs(c.X() - 10) < 1e-4)
      {
        if (n.X() > 1e-9)
          r.wallPlus[idx]++;
        else if (n.X() < -1e-9)
          r.wallMinus[idx]++;
      }
      gp_Pnt ctr((a.X() + b.X() + c.X()) / 3, (a.Y() + b.Y() + c.Y()) / 3, (a.Z() + b.Z() + c.Z()) / 3);
      gp_Pnt lower(5, 5, 5), upper(15, 5, 5);
      bool   own = (ctr.X() <= 10 + 1e-6 && n.Dot(gp_Vec(lower, ctr)) > 0)
                 || (ctr.X() >= 10 - 1e-6 && n.Dot(gp_Vec(upper, ctr)) > 0);
      own ? r.outward++ : r.inward++;
    }
  }
  return r;
}

static void print(const char* label, const MeshScan& r)
{
  printf("  %s: triangles=%d faceIndices={", label, r.triangles);
  for (int i : r.indices)
    printf(" %d", i);
  printf(" } wall(+x):");
  for (auto& kv : r.wallPlus)
    printf(" idx%d=%d", kv.first, kv.second);
  printf(" wall(-x):");
  for (auto& kv : r.wallMinus)
    printf(" idx%d=%d", kv.first, kv.second);
  printf(" outwardPerOwner=%d inward=%d\n", r.outward, r.inward);
}

static void merged(const TopoDS_Shape& s, const char* label, bool splitWall)
{
  Handle(Poly_MergeNodesTool) tool = new Poly_MergeNodesTool(0.5, 0.0);
  for (TopExp_Explorer ex(s, TopAbs_FACE); ex.More(); ex.Next())
  {
    const TopoDS_Face&         f = TopoDS::Face(ex.Current());
    TopLoc_Location            loc;
    Handle(Poly_Triangulation) t = BRep_Tool::Triangulation(f, loc);
    if (!t.IsNull())
      tool->AddTriangulation(t, loc.IsIdentity() ? gp_Trsf() : loc.Transformation(),
                             f.Orientation() == TopAbs_REVERSED);
  }
  Handle(Poly_Triangulation) r = tool->Result();
  int plus = 0, minus = 0, out = 0, in = 0;
  for (int i = 1; i <= r->NbTriangles(); i++)
  {
    int n1, n2, n3;
    r->Triangle(i).Get(n1, n2, n3);
    gp_Pnt a = r->Node(n1), b = r->Node(n2), c = r->Node(n3);
    gp_Vec n = gp_Vec(a, b).Crossed(gp_Vec(a, c));
    if (splitWall)
    {
      if (std::fabs(a.X() - 10) < 1e-4 && std::fabs(b.X() - 10) < 1e-4 && std::fabs(c.X() - 10) < 1e-4)
        (n.X() > 1e-9) ? plus++ : (n.X() < -1e-9 ? minus++ : 0);
    }
    else
    {
      gp_Pnt ctr((a.X() + b.X() + c.X()) / 3, (a.Y() + b.Y() + c.Y()) / 3, (a.Z() + b.Z() + c.Z()) / 3);
      n.Dot(gp_Vec(gp_Pnt(5, 5, 5), ctr)) > 0 ? out++ : in++;
    }
  }
  if (splitWall)
    printf("  %s: nbNodes=%d nbTriangles=%d wall +x=%d -x=%d\n", label, r->NbNodes(), r->NbTriangles(), plus, minus);
  else
    printf("  %s: nbNodes=%d nbTriangles=%d outward=%d inward=%d\n", label, r->NbNodes(), r->NbTriangles(), out, in);
}

int main()
{
  TopoDS_Shape c = splitBoxCompound();

  TopTools_IndexedMapOfShape faces;
  TopExp::MapShapes(c, TopAbs_FACE, faces);
  int                              occ = 0;
  std::map<int, std::set<int>>     orient;
  for (TopExp_Explorer ex(c, TopAbs_FACE); ex.More(); ex.Next(), occ++)
    orient[faces.FindIndex(ex.Current()) - 1].insert(ex.Current().Orientation());
  int shared = 0;
  for (auto& kv : orient)
    if (kv.second.size() > 1)
    {
      shared++;
      printf("  shared face index %d carries both FORWARD and REVERSED\n", kv.first);
    }
  printf("fixtureSharesAWall: distinctFaces=%d occurrences=%d sharedFaces=%d\n", faces.Extent(), occ, shared);

  BRepMesh_IncrementalMesh(c, 0.5, Standard_False, 0.5);
  printf("mesh(linearDeflection: 0.5), used by meshFaceIndices*, sharedWall*, meshWinding*:\n");
  print("split compound", scan(c));

  {
    TopoDS_Shape          c2 = splitBoxCompound();
    IMeshTools_Parameters p;
    p.Deflection               = 0.5;
    p.Angle                    = 0.5;
    p.DeflectionInterior       = 0.5;
    p.AngleInterior            = 0.5;
    p.MinSize                  = 0.0;
    p.InParallel               = Standard_True;
    p.InternalVerticesMode     = Standard_True;
    p.ControlSurfaceDeflection = Standard_True;
    BRepMesh_IncrementalMesh m(c2, p);
    m.Perform();
    printf("parameterisedMeshHoldsTheContract (MeshParameters.default, deflection 0.5):\n");
    print("split compound", scan(c2));
  }

  printf("plainBoxWindingUnchanged:\n");
  TopoDS_Shape box = BRepPrimAPI_MakeBox(gp_Pnt(0, 0, 0), 10, 10, 10).Shape();
  BRepMesh_IncrementalMesh(box, 0.5, Standard_False, 0.5);
  print("plain box (owner test reads centre (5,5,5) as the lower interior)", scan(box));

  printf("mergedNodesKeepBothWallSides:\n");
  merged(c, "split compound", true);
  printf("mergedNodesPlainBoxOutward:\n");
  merged(box, "plain box", false);
  return 0;
}
