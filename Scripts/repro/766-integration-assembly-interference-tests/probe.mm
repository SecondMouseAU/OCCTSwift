// Kernel-parity probe for Tests/OCCTAnalysisTests/IntegrationAssemblyInterferenceTests.swift
// (#766 execution, issue #1890). Mirrors the Swift test: OCCTShapeSubtractEx
// (BRepAlgoAPI_Cut), OCCTShapeTranslate, OCCTShapeDistance (BRepExtrema_DistShapeShape at
// 1e-6), OCCTShapeIntersectEx (BRepAlgoAPI_Common) and OCCTShapeGetVolume
// (BRepGProp::VolumeProperties, OnlyClosed).

#include <BRepPrimAPI_MakeCylinder.hxx>
#include <BRepAlgoAPI_Cut.hxx>
#include <BRepAlgoAPI_Common.hxx>
#include <TopTools_ListOfShape.hxx>
#include <BRepBuilderAPI_Transform.hxx>
#include <BRepCheck_Analyzer.hxx>
#include <BRepExtrema_DistShapeShape.hxx>
#include <BRepGProp.hxx>
#include <GProp_GProps.hxx>
#include <gp_Trsf.hxx>
#include <cmath>
#include <cstdio>

template <class Op>
static TopoDS_Shape boolean(const TopoDS_Shape& a, const TopoDS_Shape& b)
{
  Op                   op;
  TopTools_ListOfShape args, tools;
  args.Append(a);
  tools.Append(b);
  op.SetArguments(args);
  op.SetTools(tools);
  op.Build();
  return op.IsDone() ? op.Shape() : TopoDS_Shape();
}

static TopoDS_Shape up40(const TopoDS_Shape& s)
{
  gp_Trsf t;
  t.SetTranslation(gp_Vec(0, 0, 40));
  return BRepBuilderAPI_Transform(s, t, Standard_True).Shape();
}

static double volume(const TopoDS_Shape& s)
{
  GProp_GProps p;
  BRepGProp::VolumeProperties(s, p, Standard_True);
  return p.Mass();
}

int main()
{
  TopoDS_Shape shaft   = BRepPrimAPI_MakeCylinder(10, 100).Shape();
  TopoDS_Shape housing = BRepPrimAPI_MakeCylinder(15, 20).Shape();
  TopoDS_Shape bore    = BRepPrimAPI_MakeCylinder(10.05, 20).Shape();

  TopoDS_Shape hollow = boolean<BRepAlgoAPI_Cut>(housing, bore);
  printf("hollowHousing: null=%d valid=%d volume=%.9f (pi*(15^2-10.05^2)*20 = %.9f)\n",
         (int)hollow.IsNull(),
         (int)BRepCheck_Analyzer(hollow).IsValid(),
         volume(hollow),
         M_PI * (225.0 - 10.05 * 10.05) * 20.0);

  TopoDS_Shape positioned = up40(hollow);
  printf("positionedHousing: valid=%d\n", (int)BRepCheck_Analyzer(positioned).IsValid());

  BRepExtrema_DistShapeShape d(shaft, positioned, 1e-6);
  printf("clearance: done=%d n=%d value=%.12f\n", (int)d.IsDone(), d.NbSolution(), d.Value());

  TopoDS_Shape common = boolean<BRepAlgoAPI_Common>(shaft, up40(housing));
  printf("interference: null=%d volume=%.9f (pi*100*20 = %.9f)\n",
         (int)common.IsNull(),
         volume(common),
         M_PI * 100.0 * 20.0);
  return 0;
}
