// #766 evidence fix for Issue1635ContapAnalyticGeometryTests.accessorsRefuseTheWrongLineType.
//
// The test asks a .line contour (the cylinder r5 h20 along +X, first line of its first face with
// one) for arc data and expects nil. OCCTContapContourLineArcRange and OCCTContapContourLineArcPoint
// refuse a non-restriction line themselves before reading Contap_Line::Arc(), so probe.mm never
// called Arc() on a Contap_Lin line and the earlier record carried a description of what Arc() is
// "valid" for rather than a result. This probe makes the call the bridge does not make: Arc() on
// the same Contap_Lin line, inside try/catch, and prints what OCCT does.
#include <Adaptor2d_Curve2d.hxx>
#include <BRepAdaptor_Surface.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <BRepTopAdaptor_TopolTool.hxx>
#include <Contap_Contour.hxx>
#include <Contap_Line.hxx>
#include <Standard_DomainError.hxx>
#include <Standard_Failure.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <cstdio>

int main()
{
  TopoDS_Shape cyl       = BRepPrimAPI_MakeCylinder(5, 20).Shape();
  int          faceIndex = 0;
  for (TopExp_Explorer ex(cyl, TopAbs_FACE); ex.More(); ex.Next(), faceIndex++)
  {
    Handle(BRepAdaptor_Surface)      surf = new BRepAdaptor_Surface(TopoDS::Face(ex.Current()));
    Handle(BRepTopAdaptor_TopolTool) tool = new BRepTopAdaptor_TopolTool(surf);
    Contap_Contour                   c;
    c.Init(gp_Vec(1, 0, 0));
    c.Perform(surf, tool);
    if (!c.IsDone() || c.IsEmpty() || c.NbLines() == 0 || c.Line(1).TypeContour() != Contap_Lin)
      continue;
    const Contap_Line& L = c.Line(1);
    printf("cylinder r5 h20 along +X, face %d, line 1: TypeContour is Contap_Lin (%d), "
           "Contap_Restriction is %d\n",
           faceIndex, (int)(L.TypeContour() == Contap_Lin), (int)Contap_Restriction);
    try
    {
      const Handle(Adaptor2d_Curve2d)& arc = L.Arc();
      printf("  Arc() on the Contap_Lin line returned (null handle: %d)\n", (int)arc.IsNull());
    }
    catch (const Standard_DomainError& f)
    {
      printf("  Arc() on the Contap_Lin line threw Standard_DomainError: '%s'\n", f.what());
    }
    catch (const Standard_Failure& f)
    {
      printf("  Arc() on the Contap_Lin line threw a Standard_Failure other than DomainError: '%s'\n",
             f.what());
    }
    return 0;
  }
  printf("no face has a first line of type Contap_Lin\n");
  return 0;
}
