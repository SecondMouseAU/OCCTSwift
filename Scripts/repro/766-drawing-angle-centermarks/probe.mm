// Epic #766, OCCTDrawingTests: AngleDimensionTests, AutoCentermarkFrameAgreementTests,
// AutoCentermarksTests. Same inputs as the Swift tests, straight to OCCT.
// AngularDimensionReflexSweepTests is pure Swift (DXFWriter + DrawingDimension.Angular) and has
// no kernel counterpart.
#include <BRepAdaptor_Curve.hxx>
#include <BRepBndLib.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepBuilderAPI_MakePolygon.hxx>
#include <BRepBuilderAPI_Transform.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <BRep_Builder.hxx>
#include <Bnd_Box.hxx>
#include <HLRAlgo_Projector.hxx>
#include <HLRBRep_Algo.hxx>
#include <HLRBRep_HLRToShape.hxx>
#include <PrsDim_AngleDimension.hxx>
#include <TopExp.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Compound.hxx>
#include <cmath>
#include <cstdio>

static void countCircles(const TopoDS_Shape& s, const gp_Dir& view, double minR, const char* tag)
{
  int added = 0, edgeOn = 0, filtered = 0;
  // Shape.edges() walks the unique edge map, as TopExp::MapShapes does.
  TopTools_IndexedMapOfShape map;
  TopExp::MapShapes(s, TopAbs_EDGE, map);
  for (int i = 1; i <= map.Extent(); ++i)
  {
    BRepAdaptor_Curve c(TopoDS::Edge(map(i)));
    if (c.GetType() != GeomAbs_Circle)
      continue;
    gp_Circ circ = c.Circle();
    if (circ.Radius() < minR)
    {
      filtered++;
      continue;
    }
    if (std::abs(circ.Axis().Direction().Dot(view)) < 0.1)
    {
      edgeOn++;
      continue;
    }
    added++;
  }
  printf("%s: circles faced=%d edgeOn=%d belowMinRadius=%d\n", tag, added, edgeOn, filtered);
}

int main()
{
  const double deg = 180.0 / M_PI;
  {
    Handle(PrsDim_AngleDimension) d =
      new PrsDim_AngleDimension(gp_Pnt(5, 0, 0), gp_Pnt(0, 0, 0), gp_Pnt(0, 5, 0));
    gp_Pnt c = d->CenterPoint();
    printf("rightAngle/angleGeometry: degrees=%.17g valid=%d center=(%.17g, %.17g, %.17g)\n",
           d->GetValue() * deg, d->IsValid(), c.X(), c.Y(), c.Z());
  }
  {
    Handle(PrsDim_AngleDimension) d = new PrsDim_AngleDimension(
      gp_Pnt(5, 0, 0), gp_Pnt(0, 0, 0), gp_Pnt(2.5, 2.5 * std::sqrt(3.0), 0));
    printf("sixtyDegreeAngle: degrees=%.17g\n", d->GetValue() * deg);
  }
  {
    Handle(PrsDim_AngleDimension) d =
      new PrsDim_AngleDimension(gp_Pnt(5, 0, 0), gp_Pnt(0, 0, 0), gp_Pnt(-5, 0, 0));
    printf("straightAngle: degrees=%.17g valid=%d\n", d->GetValue() * deg, d->IsValid());
  }
  {
    BRepBuilderAPI_MakePolygon poly(gp_Pnt(-5, -5, 0),
                                    gp_Pnt(5, -5, 0),
                                    gp_Pnt(5, 5, 0),
                                    gp_Pnt(-5, 5, 0),
                                    true);
    TopoDS_Face f1 = BRepBuilderAPI_MakeFace(poly.Wire()).Face();
    gp_Trsf     t;
    t.SetRotation(gp_Ax1(gp_Pnt(0, 0, 0), gp_Dir(1, 0, 0)), M_PI / 2);
    TopoDS_Face f2 = TopoDS::Face(BRepBuilderAPI_Transform(f1, t, true).Shape());
    Handle(PrsDim_AngleDimension) d = new PrsDim_AngleDimension(f1, f2);
    printf("perpendicularFaces: degrees=%.17g valid=%d\n", d->GetValue() * deg, d->IsValid());
  }
  {
    // AutoCentermarkFrameAgreement: cylinder at (0,10,5), axis (1,0,0), r 5, h 10, viewed down +X.
    gp_Dir               view(1, 0, 0);
    TopoDS_Shape         cyl = BRepPrimAPI_MakeCylinder(gp_Ax2(gp_Pnt(0, 10, 5), view), 5, 10).Shape();
    gp_Ax2               ax(gp_Pnt(0, 0, 0), view);
    Handle(HLRBRep_Algo) algo = new HLRBRep_Algo();
    algo->Add(cyl);
    algo->Projector(HLRAlgo_Projector(ax));
    algo->Update();
    algo->Hide();
    HLRBRep_HLRToShape hs(algo);
    TopoDS_Compound    comp;
    BRep_Builder       b;
    b.MakeCompound(comp);
    TopoDS_Shape parts[3] = {hs.VCompound(), hs.Rg1LineVCompound(), hs.OutLineVCompound()};
    for (const TopoDS_Shape& s : parts)
      if (!s.IsNull())
        b.Add(comp, s);
    Bnd_Box box;
    BRepBndLib::Add(comp, box, true);
    double x0, y0, z0, x1, y1, z1;
    box.Get(x0, y0, z0, x1, y1, z1);
    printf("frameAgreement: visible bbox centre=(%.17g, %.17g)\n", (x0 + x1) / 2, (y0 + y1) / 2);
    gp_Vec X(ax.XDirection()), Y(ax.YDirection());
    gp_Pnt centres[2] = {gp_Pnt(0, 10, 5), gp_Pnt(10, 10, 5)};
    for (const gp_Pnt& c : centres)
      printf("frameAgreement: gp_Ax2 frame projects circle centre (%g,%g,%g) to (%.17g, %.17g)\n",
             c.X(), c.Y(), c.Z(), gp_Vec(c.XYZ()).Dot(X), gp_Vec(c.XYZ()).Dot(Y));
  }
  {
    TopoDS_Shape cyl = BRepPrimAPI_MakeCylinder(5, 20).Shape();
    countCircles(cyl, gp_Dir(0, 0, 1), 0, "cylinderTopViewMark");
    countCircles(cyl, gp_Dir(0, 1, 0), 0, "cylinderSideViewSkipped");
    countCircles(cyl, gp_Dir(0, 0, 1), 100, "minRadiusFilter");
  }
  return 0;
}
