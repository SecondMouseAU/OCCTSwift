// Epic #766, PointCloudAnalysisTests.swift: kernel parity for all six tests.
// Shape.analyzePointCloud reaches OCCTAnalyzePointCloud -> GProp_PEquation(points, 1e-6) and
// classifies by IsPoint / IsLinear / IsPlanar / else space. The empty case never reaches the
// kernel (Swift returns nil for no points, and the bridge rejects pointCount < 1); what the
// kernel does with an empty array is printed anyway, to show what those guards are guarding.
#include <GProp_PEquation.hxx>
#include <Standard_Failure.hxx>
#include <TColgp_Array1OfPnt.hxx>
#include <cstdio>
#include <gp_Lin.hxx>
#include <gp_Pln.hxx>
#include <vector>

static void run(const char* tag, const std::vector<gp_Pnt>& pts)
{
  try
  {
    TColgp_Array1OfPnt a(1, (int)pts.size());
    for (size_t i = 0; i < pts.size(); i++)
      a.SetValue((int)i + 1, pts[i]);
    GProp_PEquation eq(a, 1e-6);
    if (eq.IsPoint())
    {
      gp_Pnt p = eq.Point();
      printf("%s: point (%.17g, %.17g, %.17g)\n", tag, p.X(), p.Y(), p.Z());
    }
    else if (eq.IsLinear())
    {
      gp_Lin l = eq.Line();
      printf("%s: linear origin=(%.17g, %.17g, %.17g) dir=(%.17g, %.17g, %.17g)\n", tag,
             l.Location().X(), l.Location().Y(), l.Location().Z(), l.Direction().X(),
             l.Direction().Y(), l.Direction().Z());
    }
    else if (eq.IsPlanar())
    {
      gp_Pln p = eq.Plane();
      gp_Dir n = p.Axis().Direction();
      printf("%s: planar origin=(%.17g, %.17g, %.17g) normal=(%.17g, %.17g, %.17g)\n", tag,
             p.Location().X(), p.Location().Y(), p.Location().Z(), n.X(), n.Y(), n.Z());
    }
    else
      printf("%s: space\n", tag);
  }
  catch (const Standard_Failure& e)
  {
    printf("%s: threw Standard_Failure: %s\n", tag, e.GetMessageString());
  }
  catch (...)
  {
    printf("%s: threw a non-OCCT exception\n", tag);
  }
}

int main()
{
  run("coincidentPoints", {gp_Pnt(5, 5, 5), gp_Pnt(5, 5, 5), gp_Pnt(5, 5, 5)});
  run("collinearPoints", {gp_Pnt(0, 0, 0), gp_Pnt(5, 0, 0), gp_Pnt(10, 0, 0)});
  run("coplanarPoints", {gp_Pnt(0, 0, 0), gp_Pnt(10, 0, 0), gp_Pnt(10, 10, 0), gp_Pnt(0, 10, 0)});
  run("spacePoints", {gp_Pnt(0, 0, 0), gp_Pnt(10, 0, 0), gp_Pnt(0, 10, 0), gp_Pnt(0, 0, 10)});
  run("emptyReturnsNil (unguarded kernel path)", {});
  run("singlePoint", {gp_Pnt(3, 4, 5)});
  return 0;
}
