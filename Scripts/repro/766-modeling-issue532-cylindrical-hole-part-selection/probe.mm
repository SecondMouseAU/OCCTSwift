// Epic #766, Tests/OCCTModelingTests/Issue532CylindricalHolePartSelectionTests.swift: kernel parity
// for all seven tests. OCCTBRepFeatCylindricalHole / ...Status run BRepFeat_MakeCylindricalHole:
// Init(shape, axis), then PerformUntilEnd / PerformThruNext / PerformBlind / Perform(R, from, to) /
// Perform(R), Status(), Build(). Same fixtures and extents here, printing removed volume, solid
// count, validity and status. Against the pinned kernel, which carries patch 0020.
#include <BRepAlgoAPI_Cut.hxx>
#include <BRepBuilderAPI_Transform.hxx>
#include <BRepCheck_Analyzer.hxx>
#include <BRepFeat_MakeCylindricalHole.hxx>
#include <BRepGProp.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRep_Builder.hxx>
#include <GProp_GProps.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS_Compound.hxx>
#include <cmath>
#include <cstdio>

static double vol(const TopoDS_Shape& s)
{
  GProp_GProps p;
  BRepGProp::VolumeProperties(s, p);
  return p.Mass();
}

static int solids(const TopoDS_Shape& s)
{
  int n = 0;
  for (TopExp_Explorer e(s, TopAbs_SOLID); e.More(); e.Next())
    n++;
  return n;
}

static TopoDS_Shape box(double w, double h, double d, double dz = 0)
{
  TopoDS_Shape b = BRepPrimAPI_MakeBox(gp_Pnt(-w / 2, -h / 2, -d / 2), w, h, d).Shape();
  if (dz == 0)
    return b;
  gp_Trsf t;
  t.SetTranslation(gp_Vec(0, 0, dz));
  return BRepBuilderAPI_Transform(b, t, Standard_True).Shape();
}

static TopoDS_Shape stack(int n)
{
  BRep_Builder    bb;
  TopoDS_Compound c;
  bb.MakeCompound(c);
  for (int i = 0; i < n; i++)
    bb.Add(c, box(50, 50, 20, -40.0 * i));
  return c;
}

// mode: 0 throughAll, 1 untilEnd, 2 thruNext, 3 blind(p0), 4 range(p0, p1)
static void drill(const char* label, const TopoDS_Shape& s, double oz, int mode, double p0 = 0, double p1 = 0)
{
  BRepFeat_MakeCylindricalHole h;
  h.Init(s, gp_Ax1(gp_Pnt(0, 0, oz), gp_Dir(0, 0, -1)));
  switch (mode)
  {
    case 0: h.Perform(5); break;
    case 1: h.PerformUntilEnd(5); break;
    case 2: h.PerformThruNext(5); break;
    case 3: h.PerformBlind(5, p0); break;
    default: h.Perform(5, p0, p1); break;
  }
  printf("%s: status=%d", label, (int)h.Status());
  if (h.Status() == BRepFeat_NoError)
  {
    h.Build();
    TopoDS_Shape r = h.Shape();
    printf(" removed=%.6f solids=%d valid=%d", vol(s) - vol(r), solids(r), BRepCheck_Analyzer(r).IsValid());
  }
  printf("\n");
}

int main()
{
  const double bore = M_PI * 25 * 20;
  printf("bore(r5 x 20)=%.6f 2*bore=%.6f 3*bore=%.6f blind15=%.6f\n", bore, 2 * bore, 3 * bore, M_PI * 25 * 15);
  TopoDS_Shape s2 = stack(2), s3 = stack(3);
  drill("untilEndAndRange untilEnd stack2", s2, 15, 1);
  drill("untilEndAndRange range(0,70) stack2", s2, 15, 4, 0, 70);
  drill("blindDrillsIntoAStack blind(20) stack2", s2, 15, 3, 20);
  drill("threePlateStack untilEnd stack3", s3, 15, 1);
  drill("threePlateStack range(0,70) stack3", s3, 15, 4, 0, 70);

  TopoDS_Shape bar = box(8, 50, 20);
  double       seg = 25 * std::acos(0.8) - 12;
  printf("singleSolid expected=%.6f\n", (M_PI * 25 - 2 * seg) * 20);
  drill("singleSolid untilEnd", bar, 15, 1);
  drill("singleSolid thruNext", bar, 15, 2);
  drill("singleSolid range(0,30)", bar, 15, 4, 0, 30);

  TopoDS_Shape plate = box(50, 50, 20);
  drill("singlePlate throughAll", plate, 15, 0);
  drill("singlePlate untilEnd", plate, 15, 1);
  drill("singlePlate thruNext", plate, 15, 2);
  drill("singlePlate range(0,30)", plate, 15, 4, 0, 30);
  drill("singlePlate range(10,20)", plate, 15, 4, 10, 20);
  drill("singlePlate blind(20)", plate, 15, 3, 20);

  TopoDS_Shape hollow = BRepAlgoAPI_Cut(box(50, 50, 50), box(40, 40, 40)).Shape();
  printf("hollow expected=%.6f\n", 2 * M_PI * 25 * 5);
  drill("hollowBox throughAll", hollow, 30, 0);
  drill("hollowBox untilEnd", hollow, 30, 1);
  drill("hollowBox range(0,60)", hollow, 30, 4, 0, 60);

  drill("rangeOverTheGap range(26,44) stack2", s2, 15, 4, 26, 44);
  printf("(BRepFeat_InvalidPlacement=%d)\n", (int)BRepFeat_InvalidPlacement);
  return 0;
}
