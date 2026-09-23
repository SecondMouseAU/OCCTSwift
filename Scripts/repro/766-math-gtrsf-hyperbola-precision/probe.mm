// Epic #766 kernel-parity probe for Tests/OCCTMathTests/GTrsfModificationTests.swift,
// HyperbolaThreePointsTests.swift and IntegrationPrecisionExtremesTests.swift. Same OCCT calls
// and inputs as OCCTShapeCreateBox, OCCTShapeConvertToNURBS, OCCTShapeGTrsfModification,
// OCCTCurve3DMakeHyperbolaThreePoints, OCCTShapeDrillHole (oriented cylinder + BRepAlgoAPI_Cut),
// OCCTShapeGetVolume and OCCTShapeIsValid.
#include <BRepAlgoAPI_Cut.hxx>
#include <BRepBuilderAPI_NurbsConvert.hxx>
#include <BRepCheck_Analyzer.hxx>
#include <BRepGProp.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <BRepTools_GTrsfModification.hxx>
#include <BRepTools_Modifier.hxx>
#include <BRepBndLib.hxx>
#include <Bnd_Box.hxx>
#include <GC_MakeHyperbola.hxx>
#include <GProp_GProps.hxx>
#include <Geom_Hyperbola.hxx>
#include <TopExp_Explorer.hxx>
#include <gp_GTrsf.hxx>
#include <cstdio>

static TopoDS_Shape box(double w, double h, double d)
{
  return BRepPrimAPI_MakeBox(gp_Pnt(-w / 2, -h / 2, -d / 2), w, h, d).Shape();
}

static double vol(const TopoDS_Shape& s)
{
  GProp_GProps p;
  BRepGProp::VolumeProperties(s, p, true);
  return p.Mass();
}

static int nfaces(const TopoDS_Shape& s)
{
  int n = 0;
  for (TopExp_Explorer e(s, TopAbs_FACE); e.More(); e.Next())
    n++;
  return n;
}

int main()
{
  {
    TopoDS_Shape nurbs = BRepBuilderAPI_NurbsConvert(box(10, 10, 10)).Shape();
    gp_GTrsf     g;
    g.SetValue(1, 1, 2);
    g.SetValue(1, 2, 0);
    g.SetValue(1, 3, 0);
    g.SetValue(1, 4, 0);
    g.SetValue(2, 1, 0);
    g.SetValue(2, 2, 1);
    g.SetValue(2, 3, 0);
    g.SetValue(2, 4, 0);
    g.SetValue(3, 1, 0);
    g.SetValue(3, 2, 0);
    g.SetValue(3, 3, 1);
    g.SetValue(3, 4, 0);
    Handle(BRepTools_GTrsfModification) mod = new BRepTools_GTrsfModification(g);
    BRepTools_Modifier                  m(nurbs, mod);
    TopoDS_Shape                        r = m.ModifiedShape(nurbs);
    Bnd_Box                             b;
    BRepBndLib::Add(r, b);
    double x0, y0, z0, x1, y1, z1;
    b.Get(x0, y0, z0, x1, y1, z1);
    printf("nonUniformScale: done=%d valid=%d volume=%.10g bnd=(%.6g,%.6g,%.6g)-(%.6g,%.6g,%.6g)\n",
           m.IsDone() ? 1 : 0, BRepCheck_Analyzer(r).IsValid() ? 1 : 0, vol(r),
           x0, y0, z0, x1, y1, z1);
  }
  {
    GC_MakeHyperbola mh(gp_Pnt(5, 0, 0), gp_Pnt(0, 3, 0), gp_Pnt(0, 0, 0));
    printf("hyperbolaFromThreePoints: done=%d", mh.IsDone() ? 1 : 0);
    if (mh.IsDone())
    {
      Handle(Geom_Hyperbola) h = mh.Value();
      gp_Pnt                 p0 = h->Value(0.0), p1 = h->Value(1.0);
      printf(" major=%.10g minor=%.10g first=%.6g last=%.6g P(0)=(%.10g,%.10g,%.10g) P(1)=(%.10g,%.10g,%.10g)\n",
             h->MajorRadius(), h->MinorRadius(), h->FirstParameter(), h->LastParameter(),
             p0.X(), p0.Y(), p0.Z(), p1.X(), p1.Y(), p1.Z());
    }
    else
      printf("\n");
  }
  {
    TopoDS_Shape m = box(0.001, 0.001, 0.001);
    printf("microScale: valid=%d volume=%.17g\n", BRepCheck_Analyzer(m).IsValid() ? 1 : 0, vol(m));
  }
  {
    TopoDS_Shape m = box(1000, 1000, 1000);
    printf("macroScale: valid=%d volume=%.17g\n", BRepCheck_Analyzer(m).IsValid() ? 1 : 0, vol(m));
  }
  {
    TopoDS_Shape big = box(1000, 1000, 1000);
    Bnd_Box      b;
    BRepBndLib::Add(big, b);
    double x0, y0, z0, x1, y1, z1;
    b.Get(x0, y0, z0, x1, y1, z1);
    double diag = std::sqrt((x1 - x0) * (x1 - x0) + (y1 - y0) * (y1 - y0) + (z1 - z0) * (z1 - z0));
    TopoDS_Shape cyl =
      BRepPrimAPI_MakeCylinder(gp_Ax2(gp_Pnt(0, 0, 500), gp_Dir(0, 0, -1)), 0.01, diag * 2).Shape();
    BRepAlgoAPI_Cut cut(big, cyl);
    cut.Build();
    TopoDS_Shape r = cut.Shape();
    printf("mixedScaleLargeBoxSmallHole: done=%d valid=%d faces=%d volume=%.17g expected=%.17g\n",
           cut.IsDone() ? 1 : 0, BRepCheck_Analyzer(r).IsValid() ? 1 : 0, nfaces(r), vol(r),
           1e9 - M_PI * 0.01 * 0.01 * 1000.0);
  }
  return 0;
}
