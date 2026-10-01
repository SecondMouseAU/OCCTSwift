// Ground-truth probe for #2900: what BRepMesh_IncrementalMesh does with a degenerate ANGULAR
// deflection, on the kernel this repo pins. The linear half of the same question is #2879's probe
// next door, and this file is deliberately its twin so the two measurements compare.
//
// Usage: probe <angle-literal> [shape] [mode] [linear-deflection]
//   angle is "nan", or any strtod literal: 0.0 / -1.0 / 9e-13 / 0.5
//   shape is "cylinder" (the default, a curved solid) or "box" (planar faces only). Curvature is
//     what the angular deflection controls at all, so the two shapes are not the same question.
//   mode is "ctor" (the default: the 4-argument BRepMesh_IncrementalMesh(shape, lin, rel, ang)
//     that OCCTShapeCreateMesh and the two presentation sites use, which leaves AngleInterior at
//     IMeshTools_Parameters' -1.0 default and so has initParameters rewrite it to 2.0 * Angle),
//     "params" (the IMeshTools_Parameters ctor OCCTShapeCreateMeshWithParams uses, with
//     AngleInterior set from the test value too), or "interior", which holds Angle valid and puts
//     the test value in AngleInterior alone.
//   linear-deflection defaults to 0.1. Raise it (run.sh's second sweep uses 10.0) to let the
//     angular criterion rather than the linear one decide the tessellation, which is the only
//     setting in which a wrong angle is visible in the node count at all.
//
// Run each case in its own process under an external timeout: a non-returning mesh cannot be
// caught in-process (OCC_CATCH_SIGNALS is inert in this build). run.sh does that.
//
// Build: see run.sh, which compiles this against the SwiftPM-resolved xcframework so the
// measurement is of the pinned asset rather than of whatever Libraries/ happens to hold.

#include <BRepMesh_IncrementalMesh.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <BRep_Tool.hxx>
#include <IMeshTools_Parameters.hxx>
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

namespace
{
double parseValue(const char* arg)
{
  if (std::strcmp(arg, "nan") == 0)
    return std::nan("");
  return std::atof(arg);
}

void report(const TopoDS_Shape& shape)
{
  int faces = 0, meshed = 0, nodes = 0, triangles = 0;
  for (TopExp_Explorer ex(shape, TopAbs_FACE); ex.More(); ex.Next())
  {
    TopLoc_Location            loc;
    Handle(Poly_Triangulation) tri = BRep_Tool::Triangulation(TopoDS::Face(ex.Current()), loc);
    ++faces;
    if (!tri.IsNull())
    {
      ++meshed;
      nodes += tri->NbNodes();
      triangles += tri->NbTriangles();
    }
  }
  std::printf("faces=%d meshed=%d nodes=%d triangles=%d\n", faces, meshed, nodes, triangles);
}

void reportParameters(const BRepMesh_IncrementalMesh& mesher)
{
  std::printf("returned: IsDone=%d status=%d Angle=%.17g AngleInterior=%.17g\n",
              (int)mesher.IsDone(),
              mesher.GetStatusFlags(),
              mesher.Parameters().Angle,
              mesher.Parameters().AngleInterior);
}
} // namespace

int main(int argc, char** argv)
{
  const double angle    = parseValue((argc > 1) ? argv[1] : "0.0");
  const char*  shapeArg = (argc > 2) ? argv[2] : "cylinder";
  const char*  mode     = (argc > 3) ? argv[3] : "ctor";
  const double linear   = (argc > 4) ? parseValue(argv[4]) : 0.1;

  std::printf("Precision::Angular() = %g\n", Precision::Angular());
  std::printf("angle = %.17g  shape = %s  mode = %s  linear = %.17g\n",
              angle,
              shapeArg,
              mode,
              linear);
  std::fflush(stdout);

  TopoDS_Shape shape = (std::strcmp(shapeArg, "box") == 0)
                         ? BRepPrimAPI_MakeBox(10.0, 5.0, 3.0).Shape()
                         : BRepPrimAPI_MakeCylinder(10.0, 5.0).Shape();

  try
  {
    if (std::strcmp(mode, "ctor") == 0)
    {
      BRepMesh_IncrementalMesh mesher(shape, linear, Standard_False, angle);
      mesher.Perform();
      reportParameters(mesher);
    }
    else
    {
      IMeshTools_Parameters params;
      params.Deflection = linear;
      if (std::strcmp(mode, "interior") == 0)
      {
        params.Angle         = 0.5;
        params.AngleInterior = angle;
      }
      else
      {
        params.Angle         = angle;
        params.AngleInterior = angle;
      }
      BRepMesh_IncrementalMesh mesher(shape, params);
      mesher.Perform();
      reportParameters(mesher);
    }
    report(shape);
  }
  catch (const Standard_Failure& e)
  {
    std::printf("threw Standard_Failure: %s: %s\n",
                typeid(e).name(),
                e.GetMessageString() ? e.GetMessageString() : "(no message)");
    report(shape);
  }
  catch (...)
  {
    std::printf("threw a non-Standard_Failure exception\n");
    report(shape);
  }

  std::fflush(stdout);
  return 0;
}
