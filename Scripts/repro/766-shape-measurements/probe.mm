// Epic #766, ShapeMeasurementsTests.swift: kernel parity for all six tests.
// Shape.measure() is Swift composition, not one bridge call. Per face it reads
// Face.area(tolerance: 1e-6)      -> OCCTFaceGetArea     -> BRepGProp::SurfaceProperties(f, props, 1e-6)
// Face.surfaceInertia.centerOfMass -> OCCTBRepGPropSinert -> BRepGProp_Sinert(BRepGProp_Face), location 0
// Face.outerWire?.length          -> OCCTFaceGetOuterWire + OCCTWireGetLength
//                                    -> BRepTools::OuterWire, BRepAdaptor_CompCurve arc length
// and per edge Edge.length -> OCCTEdgeGetLength -> BRepGProp::LinearProperties. Face.bounds is
// BRepBndLib::Add(face, box, useTriangulation=true). This probe makes the same kernel calls, with
// GCPnts_AbscissaPoint::Length standing in for the bridge's own occtAdaptorArcLength quadrature.
#include <BRepAdaptor_CompCurve.hxx>
#include <BRepBndLib.hxx>
#include <BRepGProp.hxx>
#include <BRepGProp_Domain.hxx>
#include <BRepGProp_Face.hxx>
#include <BRepGProp_Sinert.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <BRepTools.hxx>
#include <Bnd_Box.hxx>
#include <GCPnts_AbscissaPoint.hxx>
#include <GProp_GProps.hxx>
#include <TopExp.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopoDS.hxx>
#include <cmath>
#include <cstdio>

static void measure(const char* tag, const TopoDS_Shape& s)
{
  TopTools_IndexedMapOfShape fm, em;
  TopExp::MapShapes(s, TopAbs_FACE, fm);
  TopExp::MapShapes(s, TopAbs_EDGE, em);
  printf("%s: faces=%d edges=%d\n", tag, fm.Extent(), em.Extent());
  double totA = 0, totP = 0, totE = 0;
  for (int i = 1; i <= fm.Extent(); i++)
  {
    TopoDS_Face  f = TopoDS::Face(fm(i));
    GProp_GProps a;
    BRepGProp::SurfaceProperties(f, a, 1e-6);
    BRepGProp_Face   gf(f);
    BRepGProp_Sinert si;
    si.SetLocation(gp_Pnt(0, 0, 0));
    si.Perform(gf);
    gp_Pnt      c = si.CentreOfMass();
    // The bridge's Perform(BRepGProp_Face) integrates over the face's natural (untrimmed)
    // parameter bounds. The domain-bounded overload is printed alongside for comparison.
    BRepGProp_Face   gfd(f);
    BRepGProp_Domain dom(f);
    BRepGProp_Sinert sid;
    sid.SetLocation(gp_Pnt(0, 0, 0));
    sid.Perform(gfd, dom);
    gp_Pnt cd = sid.CentreOfMass();
    printf("  face[%d] domain-bounded Sinert: mass=%.17g centroid=(%.17g, %.17g, %.17g)\n", i - 1,
           sid.Mass(), cd.X(), cd.Y(), cd.Z());
    TopoDS_Wire w = BRepTools::OuterWire(f);
    double      perim = -1;
    if (!w.IsNull())
    {
      BRepAdaptor_CompCurve cc(w);
      perim = GCPnts_AbscissaPoint::Length(cc);
    }
    Bnd_Box b;
    BRepBndLib::Add(f, b, true);
    double x0, y0, z0, x1, y1, z1;
    b.Get(x0, y0, z0, x1, y1, z1);
    printf("  face[%d] area=%.17g sinertMass=%.17g centroid=(%.17g, %.17g, %.17g) perimeter=%.17g "
           "bounds=[(%.9g, %.9g, %.9g), (%.9g, %.9g, %.9g)]\n",
           i - 1, a.Mass(), si.Mass(), c.X(), c.Y(), c.Z(), perim, x0, y0, z0, x1, y1, z1);
    totA += a.Mass();
    if (perim >= 0)
      totP += perim;
  }
  for (int i = 1; i <= em.Extent(); i++)
  {
    GProp_GProps l;
    BRepGProp::LinearProperties(em(i), l);
    printf("  edge[%d] length=%.17g\n", i - 1, l.Mass());
    totE += l.Mass();
  }
  printf("  totalFaceArea=%.17g totalFacePerimeter=%.17g totalEdgeLength=%.17g\n", totA, totP,
         totE);
}

int main()
{
  measure("box(2,3,5)", BRepPrimAPI_MakeBox(gp_Pnt(-1, -1.5, -2.5), 2, 3, 5).Shape());
  measure("cylinder(5,10)", BRepPrimAPI_MakeCylinder(5, 10).Shape());
  printf("pi*25=%.17g\n", M_PI * 25);
  return 0;
}
