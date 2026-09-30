// Ground-truth probe for #2879: what BRepMesh_IncrementalMesh does with a degenerate linear
// deflection, on the kernel this repo pins.
//
// Usage: probe <deflection-literal>
//   e.g. probe 0.0 / probe 1e-12 / probe -1.0 / probe nan / probe 1e-7
//
// Run each case in its own process under an external timeout: the zero case is reported (#2879)
// not to return, and a hang cannot be caught in-process. run.sh does that.
//
// Build (from the repo root, against the kernel SwiftPM resolved, so the measurement is of the
// pinned asset rather than of whatever the checkout's Libraries/ happens to hold):
//   XC=$(find .build/artifacts -maxdepth 3 -name OCCT.xcframework -type d | head -1)
//   clang++ -std=c++17 -ObjC++ -w -I"$XC/macos-arm64/Headers" \
//     -L"$XC/macos-arm64" -lOCCT-macos -framework Foundation -framework AppKit \
//     -lz -lc++ Scripts/repro/2879/probe.mm -o /tmp/occt_probe_2879

#include <BRepMesh_IncrementalMesh.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <BRep_Tool.hxx>
#include <Poly_Triangulation.hxx>
#include <Precision.hxx>
#include <Standard_Failure.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Face.hxx>
#include <TopoDS_Shape.hxx>

#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <typeinfo>

int main(int argc, char** argv)
{
  const char* arg = (argc > 1) ? argv[1] : "0.0";
  double      defl;
  if (std::strcmp(arg, "nan") == 0)
    defl = std::nan("");
  else
    defl = std::atof(arg);

  std::printf("Precision::Confusion() = %g\n", Precision::Confusion());
  std::printf("deflection = %g\n", defl);
  std::fflush(stdout);

  TopoDS_Shape cyl = BRepPrimAPI_MakeCylinder(10.0, 5.0).Shape();

  try
  {
    BRepMesh_IncrementalMesh mesher(cyl, defl);
    mesher.Perform();
    std::printf("returned: IsDone=%d status=%d\n", (int)mesher.IsDone(), mesher.GetStatusFlags());
    int nodes = 0, faces = 0;
    for (TopExp_Explorer ex(cyl, TopAbs_FACE); ex.More(); ex.Next())
    {
      TopLoc_Location            loc;
      Handle(Poly_Triangulation) tri = BRep_Tool::Triangulation(TopoDS::Face(ex.Current()), loc);
      ++faces;
      if (!tri.IsNull())
        nodes += tri->NbNodes();
    }
    std::printf("faces=%d triangulation nodes=%d\n", faces, nodes);
  }
  catch (const Standard_Failure& e)
  {
    std::printf("threw Standard_Failure: %s: %s\n",
                typeid(e).name(),
                e.GetMessageString() ? e.GetMessageString() : "(no message)");
  }
  catch (...)
  {
    std::printf("threw a non-Standard_Failure exception\n");
  }

  std::fflush(stdout);
  return 0;
}
