// Epic #766, Issue375MeshWindingTests.swift: kernel parity for both tests.
// Same inputs as the Swift tests, straight to OCCT: a 10x10x10 BRepPrimAPI_MakeBox centred on
// the origin, mirrored by BRepBuilderAPI_Transform(gp_Trsf::SetMirror(gp_Ax2)) as OCCTShapeMirror
// does, meshed by BRepMesh_IncrementalMesh, then each face's Poly_Triangulation wound by the face's
// TopoDS orientation (swap n2/n3 when REVERSED) and scored outward against the origin.
#include <BRepBuilderAPI_Transform.hxx>
#include <BRepMesh_IncrementalMesh.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRep_Tool.hxx>
#include <IMeshTools_Parameters.hxx>
#include <Poly_Triangulation.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <cstdio>
#include <gp_Ax2.hxx>
#include <gp_Trsf.hxx>
#include <utility>

static void score(const TopoDS_Shape& s, const char* label)
{
  int outward = 0, total = 0, reversedFaces = 0, rawOutward = 0;
  for (TopExp_Explorer ex(s, TopAbs_FACE); ex.More(); ex.Next())
  {
    const TopoDS_Face&         f = TopoDS::Face(ex.Current());
    TopLoc_Location            loc;
    Handle(Poly_Triangulation) t = BRep_Tool::Triangulation(f, loc);
    if (t.IsNull())
      continue;
    bool rev = f.Orientation() == TopAbs_REVERSED;
    reversedFaces += rev;
    gp_Trsf tr = loc.Transformation();
    for (int i = 1; i <= t->NbTriangles(); i++)
    {
      int n1, n2, n3;
      t->Triangle(i).Get(n1, n2, n3);
      for (int pass = 0; pass < 2; pass++)
      {
        int a = n1, b = n2, c = n3;
        if (pass == 0 && rev)
          std::swap(b, c);
        gp_Pnt p1 = t->Node(a).Transformed(tr), p2 = t->Node(b).Transformed(tr),
               p3 = t->Node(c).Transformed(tr);
        gp_Vec nrm = gp_Vec(p1, p2).Crossed(gp_Vec(p1, p3));
        bool   out = nrm.Dot(gp_Vec(p1.XYZ())) > 0;
        if (pass == 0)
          outward += out;
        else
          rawOutward += out;
      }
      total++;
    }
  }
  printf("  %s: triangles=%d reversedFaces=%d outwardFraction=%.17g (without the REVERSED swap: %.17g)\n",
         label, total, reversedFaces, (double)outward / total, (double)rawOutward / total);
}

static TopoDS_Shape mirrored(const TopoDS_Shape& s, const gp_Dir& n)
{
  gp_Trsf tr;
  tr.SetMirror(gp_Ax2(gp_Pnt(0, 0, 0), n));
  return BRepBuilderAPI_Transform(s, tr, Standard_True).Shape();
}

int main()
{
  printf("mirroredSolidMeshesConsistentlyOutward:\n");
  {
    TopoDS_Shape box = BRepPrimAPI_MakeBox(gp_Pnt(-5, -5, -5), 10, 10, 10).Shape();
    TopoDS_Shape m   = mirrored(box, gp_Dir(0, 0, 1));
    BRepMesh_IncrementalMesh(box, 0.5, Standard_False, 0.5);
    BRepMesh_IncrementalMesh(m, 0.5, Standard_False, 0.5);
    score(box, "box");
    score(m, "box mirrored through z=0");
  }
  printf("meshParametersOverloadMatchesOutwardBehavior:\n");
  {
    TopoDS_Shape          box = BRepPrimAPI_MakeBox(gp_Pnt(-5, -5, -5), 10, 10, 10).Shape();
    TopoDS_Shape          m   = mirrored(box, gp_Dir(1, 0, 0));
    IMeshTools_Parameters p;
    p.Deflection               = 0.1;
    p.Angle                    = 0.5;
    p.DeflectionInterior       = 0.1;
    p.AngleInterior            = 0.5;
    p.MinSize                  = 0.0;
    p.Relative                 = Standard_False;
    p.InParallel               = Standard_True;
    p.InternalVerticesMode     = Standard_True;
    p.ControlSurfaceDeflection = Standard_True;
    p.AdjustMinSize            = Standard_False;
    p.AllowQualityDecrease     = Standard_False;
    BRepMesh_IncrementalMesh mesher(m, p);
    mesher.Perform();
    score(m, "box mirrored through x=0, MeshParameters.default");
  }
  return 0;
}
