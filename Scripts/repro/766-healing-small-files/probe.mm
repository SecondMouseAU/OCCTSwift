// #766 kernel parity: ShellAnalysis, SplitSurface, SurfaceConvertToAnalytical, SurfaceSplitContinuity,
// SurfaceValueOfUV, UnifySameDomainBuilder, UpdateTolerances, WireVertexAnalysis tests. Each block
// drives the OCCT class the way its bridge function does, on the same inputs.
#include <BRepAlgoAPI_Fuse.hxx>
#include <BRepBndLib.hxx>
#include <BRepBuilderAPI_Copy.hxx>
#include <BRepBuilderAPI_MakePolygon.hxx>
#include <BRepBuilderAPI_Transform.hxx>
#include <BRepCheck_Analyzer.hxx>
#include <BRepGProp.hxx>
#include <BRepLib.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <BRepPrimAPI_MakeSphere.hxx>
#include <BRep_Tool.hxx>
#include <Bnd_Box.hxx>
#include <GC_MakePlane.hxx>
#include <GC_MakeTrimmedCylinder.hxx>
#include <GProp_GProps.hxx>
#include <GeomConvert.hxx>
#include <Geom_BSplineSurface.hxx>
#include <Geom_CylindricalSurface.hxx>
#include <Geom_Plane.hxx>
#include <Geom_RectangularTrimmedSurface.hxx>
#include <Geom_SphericalSurface.hxx>
#include <ShapeAnalysis_Shell.hxx>
#include <ShapeAnalysis_ShapeTolerance.hxx>
#include <ShapeAnalysis_Surface.hxx>
#include <ShapeAnalysis_WireVertex.hxx>
#include <ShapeCustom_Surface.hxx>
#include <ShapeExtend.hxx>
#include <ShapeUpgrade_SplitSurfaceAngle.hxx>
#include <ShapeUpgrade_SplitSurfaceArea.hxx>
#include <ShapeUpgrade_SplitSurfaceContinuity.hxx>
#include <ShapeUpgrade_UnifySameDomain.hxx>
#include <TColStd_HSequenceOfReal.hxx>
#include <TopExp.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopoDS.hxx>
#include <cstdio>

static int count(const TopoDS_Shape& s, TopAbs_ShapeEnum t)
{
  TopTools_IndexedMapOfShape m;
  TopExp::MapShapes(s, t, m);
  return m.Extent();
}

static double volume(const TopoDS_Shape& s)
{
  GProp_GProps g;
  BRepGProp::VolumeProperties(s, g);
  return g.Mass();
}

static void shell(const char* label, const TopoDS_Shape& s)
{
  ShapeAnalysis_Shell a;
  bool                bad = a.CheckOrientedShells(s, true, true);
  int                 free = 0;
  if (a.HasFreeEdges())
    free = count(a.FreeEdges(), TopAbs_EDGE);
  printf("ShapeAnalysis_Shell(%s): orientationProblem=%d freeEdges=%d badEdges=%d connected=%d freeCount=%d\n", label,
         (int)bad, (int)a.HasFreeEdges(), (int)a.HasBadEdges(), (int)a.HasConnectedEdges(), free);
}

static void splits(const char* label, const Handle(TColStd_HSequenceOfReal)& u, const Handle(TColStd_HSequenceOfReal)& v)
{
  printf("%s: u=%d [", label, u.IsNull() ? 0 : u->Length());
  for (int i = 1; !u.IsNull() && i <= u->Length(); i++)
    printf("%s%.6f", i > 1 ? ", " : "", u->Value(i));
  printf("] v=%d [", v.IsNull() ? 0 : v->Length());
  for (int i = 1; !v.IsNull() && i <= v->Length(); i++)
    printf("%s%.6f", i > 1 ? ", " : "", v->Value(i));
  printf("]\n");
}

static TopoDS_Shape box10() { return BRepPrimAPI_MakeBox(gp_Pnt(-5, -5, -5), 10, 10, 10).Shape(); }

int main()
{
  setvbuf(stdout, nullptr, _IONBF, 0);
  // ShellAnalysisTests
  shell("box 10", box10());
  shell("sphere r5", BRepPrimAPI_MakeSphere(5).Shape());

  // SplitSurfaceTests
  Handle(Geom_Surface) infCyl = new Geom_CylindricalSurface(gp_Ax3(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 10);
  try
  {
    Handle(Geom_BSplineSurface) b = GeomConvert::SurfaceToBSplineSurface(infCyl);
    printf("toBSpline(infinite cylinder): null=%d\n", (int)b.IsNull());
  }
  catch (Standard_Failure& e)
  {
    printf("toBSpline(infinite cylinder): throws %s\n", e.what());
  }
  Handle(Geom_Surface) trimCyl10 = GC_MakeTrimmedCylinder(gp_Ax1(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 10, 10).Value();
  Handle(Geom_BSplineSurface) bsp10 = GeomConvert::SurfaceToBSplineSurface(trimCyl10);
  printf("trimmed cylinder r10 h10 as BSpline: degree u=%d v=%d, u knots=%d\n", bsp10->UDegree(), bsp10->VDegree(),
         bsp10->NbUKnots());
  {
    Handle(ShapeUpgrade_SplitSurfaceContinuity) s = new ShapeUpgrade_SplitSurfaceContinuity();
    s->Init(bsp10);
    s->SetCriterion(GeomAbs_C2);
    s->SetTolerance(1e-6);
    s->Perform(true);
    splits("SplitSurfaceContinuity(bsp r10 h10, C2)", s->USplitValues(), s->VSplitValues());
  }
  {
    Handle(ShapeUpgrade_SplitSurfaceAngle) s = new ShapeUpgrade_SplitSurfaceAngle(M_PI / 2);
    s->Init(infCyl);
    s->Perform(true);
    splits("SplitSurfaceAngle(infinite cylinder r10, pi/2)", s->USplitValues(), s->VSplitValues());
  }
  {
    Handle(Geom_Surface) pl = GC_MakePlane(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)).Value();
    Handle(Geom_Surface) tp = new Geom_RectangularTrimmedSurface(pl, 0.0, 10.0, 0.0, 10.0);
    Handle(ShapeUpgrade_SplitSurfaceArea) s = new ShapeUpgrade_SplitSurfaceArea();
    s->Init(tp);
    s->NbParts() = 4;
    s->SetSplittingIntoSquares(false);
    s->Perform(true);
    splits("SplitSurfaceArea(plane [0,10]^2, 4 parts)", s->USplitValues(), s->VSplitValues());
  }

  // SurfaceConvertToAnalyticalTests + SurfaceSplitContinuityTests: trimmed cylinder r5 h10 as a BSpline
  Handle(Geom_Surface) trimCyl5 = GC_MakeTrimmedCylinder(gp_Ax1(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 5, 10).Value();
  Handle(Geom_BSplineSurface) bsp5 = GeomConvert::SurfaceToBSplineSurface(trimCyl5);
  {
    ShapeCustom_Surface  sc(bsp5);
    Handle(Geom_Surface) r = sc.ConvertToAnalytical(1e-4, Standard_False);
    printf("ConvertToAnalytical(bsp r5 h10, 1e-4): null=%d type=%s gap=%.3e", (int)r.IsNull(),
           r.IsNull() ? "-" : r->DynamicType()->Name(), sc.Gap());
    Handle(Geom_CylindricalSurface) c = Handle(Geom_CylindricalSurface)::DownCast(r);
    if (!c.IsNull())
      printf(" radius=%.9f", c->Radius());
    printf("\n");
  }
  {
    Handle(ShapeUpgrade_SplitSurfaceContinuity) s = new ShapeUpgrade_SplitSurfaceContinuity();
    s->Init(bsp5);
    s->SetCriterion(GeomAbs_C2);
    s->SetTolerance(1e-6);
    s->Perform();
    printf("SplitSurfaceContinuity(bsp r5 h10, C2): OK=%d DONE1=%d ", (int)s->Status(ShapeExtend_OK),
           (int)s->Status(ShapeExtend_DONE1));
    splits("", s->USplitValues(), s->VSplitValues());
  }

  // SurfaceValueOfUVTests
  {
    Handle(Geom_Surface)          pl = GC_MakePlane(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)).Value();
    Handle(ShapeAnalysis_Surface) sa = new ShapeAnalysis_Surface(pl);
    gp_Pnt2d                      uv = sa->ValueOfUV(gp_Pnt(5, 3, 2), 1e-6);
    printf("plane ValueOfUV(5,3,2) = (%.9f, %.9f) gap=%.9f\n", uv.X(), uv.Y(), sa->Gap());
    Handle(ShapeAnalysis_Surface) sa1 = new ShapeAnalysis_Surface(pl);
    gp_Pnt2d                      uv1 = sa1->ValueOfUV(gp_Pnt(5, 3, 0), 1e-6);
    Handle(ShapeAnalysis_Surface) sa2 = new ShapeAnalysis_Surface(pl);
    gp_Pnt2d                      uv2 = sa2->NextValueOfUV(uv1, gp_Pnt(5.5, 3.5, 0), 1e-6);
    printf("plane NextValueOfUV((%.3f, %.3f), (5.5,3.5,0)) = (%.9f, %.9f) gap=%.9f\n", uv1.X(), uv1.Y(), uv2.X(),
           uv2.Y(), sa2->Gap());
    Handle(Geom_Surface)          sp = new Geom_SphericalSurface(gp_Ax3(gp_Pnt(0, 0, 0), gp::DZ()), 5);
    Handle(ShapeAnalysis_Surface) ss = new ShapeAnalysis_Surface(sp);
    gp_Pnt2d                      suv = ss->ValueOfUV(gp_Pnt(0, 0, 10), 1e-6);
    printf("sphere r5 ValueOfUV(0,0,10) = (%.9f, %.9f) gap=%.9f\n", suv.X(), suv.Y(), ss->Gap());
  }

  // UnifySameDomainBuilderTests: two 10-boxes side by side, fused (the bridge unifies a copy)
  {
    TopoDS_Shape a = box10();
    gp_Trsf      t;
    t.SetTranslation(gp_Vec(10, 0, 0));
    TopoDS_Shape     b = BRepBuilderAPI_Transform(box10(), t, true).Shape();
    BRepAlgoAPI_Fuse fu(a, b);
    TopoDS_Shape     fused = fu.Shape();
    printf("fused boxes: faces=%d edges=%d volume=%.6f\n", count(fused, TopAbs_FACE), count(fused, TopAbs_EDGE),
           volume(fused));
    for (int mode = 0; mode < 5; mode++)
    {
      TopoDS_Shape                 work = BRepBuilderAPI_Copy(fused).Shape();
      ShapeUpgrade_UnifySameDomain u(work, true, true, false);
      const char*                  label = "default";
      if (mode == 1)
      {
        u.AllowInternalEdges(true);
        label = "AllowInternalEdges(true)";
      }
      else if (mode == 2)
      {
        // keep the internal edge on the top face: the one at x = 5, z = 5
        TopTools_IndexedMapOfShape em;
        TopExp::MapShapes(work, TopAbs_EDGE, em);
        int kept = 0;
        for (int i = 1; i <= em.Extent(); i++)
        {
          Bnd_Box bb;
          BRepBndLib::Add(em(i), bb);
          double x0, y0, z0, x1, y1, z1;
          bb.Get(x0, y0, z0, x1, y1, z1);
          if (fabs(x0 - 5) < 1e-3 && fabs(x1 - 5) < 1e-3 && fabs(z0 - 5) < 1e-3 && fabs(z1 - 5) < 1e-3)
          {
            u.KeepShape(em(i));
            kept++;
          }
        }
        printf("  (edges kept: %d)\n", kept);
        label = "KeepShape(top internal edge)";
      }
      else if (mode == 3)
      {
        u.SetSafeInputMode(true);
        label = "SetSafeInputMode(true)";
      }
      else if (mode == 4)
      {
        u.SetLinearTolerance(1e-6);
        u.SetAngularTolerance(1e-3);
        label = "SetLinearTolerance(1e-6) SetAngularTolerance(1e-3)";
      }
      u.Build();
      TopoDS_Shape r = u.Shape();
      printf("unify %s: faces=%d edges=%d valid=%d volume=%.6f\n", label, count(r, TopAbs_FACE), count(r, TopAbs_EDGE),
             (int)BRepCheck_Analyzer(r).IsValid(), volume(r));
    }
  }

  // UpdateTolerancesTests: BRepLib::UpdateTolerances on a copy
  {
    ShapeAnalysis_ShapeTolerance st;
    TopoDS_Shape                 boxCopy = BRepBuilderAPI_Copy(box10()).Shape();
    BRepLib::UpdateTolerances(boxCopy, true);
    printf("UpdateTolerances(box): valid=%d volume=%.6f maxTol=%.17g\n", (int)BRepCheck_Analyzer(boxCopy).IsValid(),
           volume(boxCopy), st.Tolerance(boxCopy, 1));
    TopoDS_Shape cyl     = BRepPrimAPI_MakeCylinder(5, 10).Shape();
    TopoDS_Shape cylCopy = BRepBuilderAPI_Copy(cyl).Shape();
    BRepLib::UpdateTolerances(cylCopy, true);
    printf("UpdateTolerances(cylinder r5 h10): valid=%d volume=%.9f (input %.9f) maxTol=%.17g\n",
           (int)BRepCheck_Analyzer(cylCopy).IsValid(), volume(cylCopy), volume(cyl), st.Tolerance(cylCopy, 1));
  }

  // WireVertexAnalysisTests
  {
    BRepBuilderAPI_MakePolygon p(gp_Pnt(0, 0, 0), gp_Pnt(10, 0, 0), gp_Pnt(10, 10, 0));
    TopoDS_Wire                w = p.Wire();
    ShapeAnalysis_WireVertex   wv;
    wv.Init(w, 0.01);
    wv.Analyze();
    printf("WireVertex(open L, 0.01): done=%d nbEdges=%d status:", (int)wv.IsDone(), wv.NbEdges());
    for (int i = 1; i <= wv.NbEdges(); i++)
      printf(" %d", wv.Status(i));
    printf("\n");
  }
  return 0;
}
