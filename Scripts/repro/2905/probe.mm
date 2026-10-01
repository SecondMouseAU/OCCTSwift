// Ground-truth probe for #2905: what BRepLib_ToolTriangulatedShape::ComputeNormals and
// BRepLib::EnsureNormalConsistency actually do, on the kernel this repo pins, now that #2337 has
// Shape.mesh compute node normals as a side effect of reading them.
//
// The two questions, one per case below:
//
//   1. How many faces does ComputeNormals change? It opens `if (theTris.IsNull() ||
//      theTris->HasNormals()) return;`, so on a shape whose triangulation already carries normals
//      it changes nothing. OCCTBRepLibComputeNormals reported `true` for every non-null
//      triangulation regardless, which is a value returned as a measurement that was never taken.
//
//   2. What does EnsureNormalConsistency return? It is `true` only when it *wrote* a normal:
//      either it had to add normals to a face that lacked them, or it averaged a pair across a
//      smooth shared edge (dot > cos(theAngTol)). A box's edges are 90 degrees, so neither
//      happens once the normals are already there. A cylinder's seam is smooth, so it does.
//
// Usage: probe [shape]
//   shape is "box" (the default) or "cylinder" or "sphere".
//
// Build: see run.sh.

#include <BRepLib.hxx>
#include <BRepLib_ToolTriangulatedShape.hxx>
#include <BRepMesh_IncrementalMesh.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <BRepPrimAPI_MakeSphere.hxx>
#include <BRep_Tool.hxx>
#include <Poly_Triangulation.hxx>
#include <Standard_Failure.hxx>
#include <TopExp_Explorer.hxx>
#include <TopLoc_Location.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Face.hxx>
#include <TopoDS_Shape.hxx>

#include <cstdio>
#include <cstring>

namespace
{
TopoDS_Shape makeShape(const char* which)
{
  if (std::strcmp(which, "cylinder") == 0)
    return BRepPrimAPI_MakeCylinder(10.0, 5.0).Shape();
  if (std::strcmp(which, "sphere") == 0)
    return BRepPrimAPI_MakeSphere(5.0).Shape();
  return BRepPrimAPI_MakeBox(10.0, 10.0, 10.0).Shape();
}

//! Faces, faces carrying a triangulation, and faces whose triangulation carries normals.
void census(const TopoDS_Shape& shape, const char* label)
{
  int faces = 0, meshed = 0, withNormals = 0, nodes = 0;
  for (TopExp_Explorer ex(shape, TopAbs_FACE); ex.More(); ex.Next())
  {
    TopLoc_Location            loc;
    Handle(Poly_Triangulation) tri = BRep_Tool::Triangulation(TopoDS::Face(ex.Current()), loc);
    ++faces;
    if (tri.IsNull())
      continue;
    ++meshed;
    nodes += tri->NbNodes();
    if (tri->HasNormals())
      ++withNormals;
  }
  std::printf("  %-28s faces=%d meshed=%d withNormals=%d nodes=%d\n",
              label,
              faces,
              meshed,
              withNormals,
              nodes);
}

//! What OCCTBRepLibComputeNormals should be counting: faces whose triangulation GAINED normals.
int computeNormalsCountingChanges(const TopoDS_Shape& shape)
{
  int changed = 0;
  for (TopExp_Explorer ex(shape, TopAbs_FACE); ex.More(); ex.Next())
  {
    const TopoDS_Face          face = TopoDS::Face(ex.Current());
    TopLoc_Location            loc;
    Handle(Poly_Triangulation) tri = BRep_Tool::Triangulation(face, loc);
    if (tri.IsNull())
      continue;
    const bool had = tri->HasNormals();
    BRepLib_ToolTriangulatedShape::ComputeNormals(face, tri);
    if (!had && tri->HasNormals())
      ++changed;
  }
  return changed;
}
} // namespace

int main(int argc, char** argv)
{
  const char* which = (argc > 1) ? argv[1] : "box";
  std::printf("shape = %s\n", which);

  try
  {
    // Case A: BRepMesh_IncrementalMesh alone, which is what every bridge path other than
    // occtAppendFaceTriangulation does, and what CoherentTriangulation.createFromMesh does.
    TopoDS_Shape a(makeShape(which));
    BRepMesh_IncrementalMesh mesherA(a, 0.1);
    mesherA.Perform();
    census(a, "A after BRepMesh alone:");
    std::printf("  A ComputeNormals changed %d face(s)\n", computeNormalsCountingChanges(a));
    census(a, "A after ComputeNormals:");
    std::printf("  A ComputeNormals again changed %d face(s)\n",
                computeNormalsCountingChanges(a));

    // Case B: the Shape.mesh path, BRepMesh followed by ComputeNormals on every face, which is
    // what occtAppendFaceTriangulation has done since #2337.
    TopoDS_Shape b(makeShape(which));
    BRepMesh_IncrementalMesh mesherB(b, 0.1);
    mesherB.Perform();
    (void)computeNormalsCountingChanges(b);
    census(b, "B after mesh+ComputeNormals:");
    std::printf("  B ComputeNormals again changed %d face(s)\n",
                computeNormalsCountingChanges(b));

    // Case C: EnsureNormalConsistency on a triangulation that already carries normals (B's
    // state), which is every shape a caller reaches through Shape.mesh.
    std::printf("  C EnsureNormalConsistency(0.01) on B = %d\n",
                (int)BRepLib::EnsureNormalConsistency(b, 0.01));
    std::printf("  C EnsureNormalConsistency(0.01) on B, second call = %d\n",
                (int)BRepLib::EnsureNormalConsistency(b, 0.01));

    // Case D: the same call on a triangulation with no normals (A's state before ComputeNormals),
    // where EnsureNormalConsistency adds them itself and so reports true.
    TopoDS_Shape d(makeShape(which));
    BRepMesh_IncrementalMesh mesherD(d, 0.1);
    mesherD.Perform();
    census(d, "D after BRepMesh alone:");
    std::printf("  D EnsureNormalConsistency(0.01) = %d\n",
                (int)BRepLib::EnsureNormalConsistency(d, 0.01));
    census(d, "D after EnsureNormalConsistency:");
    std::printf("  D EnsureNormalConsistency(0.01), second call = %d\n",
                (int)BRepLib::EnsureNormalConsistency(d, 0.01));
  }
  catch (const Standard_Failure& e)
  {
    std::printf("threw: %s\n", e.GetMessageString() ? e.GetMessageString() : "(no message)");
  }

  std::fflush(stdout);
  return 0;
}
