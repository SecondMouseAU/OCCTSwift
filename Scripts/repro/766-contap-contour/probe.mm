// #766 kernel parity for Tests/OCCTAnalysisTests/ContapContourTests.swift and
// ContapContourFullTests.swift.
//   Contap_ContAna::Perform(gp_Sphere, gp_Dir) / (gp_Cylinder, gp_Dir) / (gp_Sphere, gp_Pnt)
//     -> OCCTContapSphereDir / OCCTContapCylinderDir / OCCTContapSphereEye
//   Contap_Contour::Init(gp_Vec) + Perform(BRepAdaptor_Surface, BRepTopAdaptor_TopolTool) per face
//     -> OCCTContapContourDirection, OCCTContapContourLineCount
#include <BRepAdaptor_Surface.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <BRepTopAdaptor_TopolTool.hxx>
#include <Contap_ContAna.hxx>
#include <Contap_Contour.hxx>
#include <TopExp.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopoDS.hxx>
#include <cmath>
#include <cstdio>

static void ana(const char* label, Contap_ContAna& c)
{
  printf("%s: done=%d nb=%d", label, (int)c.IsDone(), c.IsDone() ? c.NbContours() : -1);
  if (c.IsDone() && c.NbContours() > 0)
  {
    if (c.TypeContour() == GeomAbs_Circle)
    {
      gp_Circ ci = c.Circle();
      printf(" circle centre=(%.17g, %.17g, %.17g) radius=%.17g", ci.Location().X(),
             ci.Location().Y(), ci.Location().Z(), ci.Radius());
    }
    else if (c.TypeContour() == GeomAbs_Line)
      for (int i = 1; i <= c.NbContours(); ++i)
      {
        gp_Lin l = c.Line(i);
        printf(" line%d loc=(%.17g, %.17g, %.17g) dir=(%.17g, %.17g, %.17g)", i, l.Location().X(),
               l.Location().Y(), l.Location().Z(), l.Direction().X(), l.Direction().Y(),
               l.Direction().Z());
      }
  }
  printf("\n");
}

int main()
{
  gp_Sphere sph(gp_Ax3(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 10);
  {
    Contap_ContAna c;
    c.Perform(sph, gp_Dir(0, 0, 1));
    ana("sphereContourDir r=10 dir=(0,0,1)", c);
  }
  gp_Cylinder cyl(gp_Ax3(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 5);
  {
    Contap_ContAna c;
    c.Perform(cyl, gp_Dir(1, 0, 0));
    ana("cylinderContourDir r=5 dir=(1,0,0)", c);
  }
  {
    gp_Vec         d(2, 1, 0.5);
    Contap_ContAna c;
    c.Perform(cyl, gp_Dir(d));
    ana("cylinderContourDirBothLines r=5 dir=normalize(2,1,0.5)", c);
  }
  {
    Contap_ContAna c;
    c.Perform(sph, gp_Pnt(100, 0, 0));
    ana("sphereContourEye r=10 eye=(100,0,0)", c);
  }

  TopoDS_Shape               cylinder = BRepPrimAPI_MakeCylinder(10, 20).Shape();
  TopTools_IndexedMapOfShape faces;
  TopExp::MapShapes(cylinder, TopAbs_FACE, faces);
  for (int i = 1; i <= faces.Extent(); ++i)
  {
    occ::handle<BRepAdaptor_Surface>      s = new BRepAdaptor_Surface(TopoDS::Face(faces(i)));
    occ::handle<BRepTopAdaptor_TopolTool> t = new BRepTopAdaptor_TopolTool(s);
    Contap_Contour                        c;
    c.Init(gp_Vec(1, 0, 0));
    c.Perform(s, t);
    int lines = (c.IsDone() && !c.IsEmpty()) ? c.NbLines() : 0;
    printf("contourOnCylinder face %d type=%d: done=%d empty=%d lines=%d", i - 1,
           (int)s->GetType(), (int)c.IsDone(), c.IsDone() ? (int)c.IsEmpty() : -1, lines);
    for (int l = 1; l <= lines; ++l)
    {
      // NbPnts() throws Standard_DomainError on an analytic (non-walking) line; the bridge's
      // OCCTContapContourLinePointCount catches it and reports 0.
      int n = 0;
      try
      {
        n = c.Line(l).NbPnts();
      }
      catch (const Standard_Failure&)
      {
        n = -1;
      }
      printf(" [line %d type=%d nbPnts=%d]", l, (int)c.Line(l).TypeContour(), n);
    }
    printf("\n");
  }
  return 0;
}
