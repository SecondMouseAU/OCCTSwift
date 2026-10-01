// #766 kernel parity for Tests/OCCTAnalysisTests/GeomCone3DTests.swift, GeomIntIntSSTests.swift,
// GeomLPropCLPropsTests.swift and GeomLPropSLPropsTests.swift. Each block mirrors the bridge
// function the test reaches: OCCTSurfaceCone*, OCCTGeomIntSSCreate/LineCount/Line,
// OCCTGeomLPropCLProps and OCCTFaceLPropMaxCurvature. Shapes are built as OCCTShapeCreateBox
// (centred), OCCTShapeCreateCylinder and OCCTShapeCreateSphere build them, and sub-shapes are
// indexed through TopExp::MapShapes as OCCTShapeGetSubShapes indexes them.
#include <BRepAdaptor_Surface.hxx>
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepLProp_SLProps.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <BRepPrimAPI_MakeSphere.hxx>
#include <BRep_Tool.hxx>
#include <GeomInt_IntSS.hxx>
#include <GeomLProp_CLProps.hxx>
#include <Geom_ConicalSurface.hxx>
#include <Geom_Curve.hxx>
#include <Precision.hxx>
#include <TopExp.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopoDS.hxx>
#include <gp_Ax3.hxx>
#include <gp_Cone.hxx>
#include <cmath>
#include <cstdio>

static void cone()
{
  Handle(Geom_ConicalSurface) c0 =
    new Geom_ConicalSurface(gp_Ax3(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 0.3, 5);
  printf("coneSemiAngle: semiAngle=%.17g\n", c0->SemiAngle());
  printf("coneRefRadius: refRadius=%.17g\n", c0->RefRadius());
  Handle(Geom_ConicalSurface) c =
    new Geom_ConicalSurface(gp_Ax3(gp_Pnt(1, 2, 3), gp_Dir(0, 0, 1)), 0.3, 5);
  gp_Pnt a = c->Apex();
  printf("coneApex: apex=(%.17g, %.17g, %.17g) (3 - 5/tan(0.3)=%.17g)\n", a.X(), a.Y(), a.Z(),
         3 - 5.0 / tan(0.3));
  gp_Ax1 ax = c->Cone().Axis();
  printf("coneAxis: position=(%.17g, %.17g, %.17g) direction=(%.17g, %.17g, %.17g)\n",
         ax.Location().X(), ax.Location().Y(), ax.Location().Z(), ax.Direction().X(),
         ax.Direction().Y(), ax.Direction().Z());
}

static TopoDS_Shape box(double w, double h, double d)
{
  return BRepPrimAPI_MakeBox(gp_Pnt(-w / 2, -h / 2, -d / 2), w, h, d).Shape();
}

static void intss()
{
  TopoDS_Shape               cyl = BRepPrimAPI_MakeCylinder(10, 20).Shape();
  TopoDS_Shape               bx  = box(30, 30, 1);
  TopTools_IndexedMapOfShape cf, bf;
  TopExp::MapShapes(cyl, TopAbs_FACE, cf);
  TopExp::MapShapes(bx, TopAbs_FACE, bf);
  printf("planeCylinderIntersection: %d cylinder faces x %d box faces\n", cf.Extent(), bf.Extent());
  int total = 0, circles = 0, firstI = 0, firstJ = 0;
  for (int i = 1; i <= cf.Extent(); i++)
    for (int j = 1; j <= bf.Extent(); j++)
    {
      Handle(Geom_Surface) s1 = BRep_Tool::Surface(TopoDS::Face(cf(i)));
      Handle(Geom_Surface) s2 = BRep_Tool::Surface(TopoDS::Face(bf(j)));
      GeomInt_IntSS        ss;
      ss.Perform(s1, s2, 1e-6, true, false, false);
      if (!ss.IsDone())
      {
        printf("  pair (%d,%d): not done\n", i, j);
        continue;
      }
      int n = ss.NbLines();
      if (n == 0)
        continue;
      if (!firstI)
      {
        firstI = i;
        firstJ = j;
      }
      for (int k = 1; k <= n; k++)
      {
        Handle(Geom_Curve) c = ss.Line(k);
        BRepBuilderAPI_MakeEdge me(c);
        GeomLProp_CLProps       p(c, c->FirstParameter(), 2, Precision::Confusion());
        double                  curv = p.IsTangentDefined() ? p.Curvature() : -1;
        gp_Pnt                  pt   = p.Value();
        printf("  pair (%d,%d) line %d: %s edge=%d curvature@first=%.17g point@first=(%.17g, "
               "%.17g, %.17g)\n",
               i, j, k, c->DynamicType()->Name(), (int)me.IsDone(), curv, pt.X(), pt.Y(), pt.Z());
        total++;
        if (std::abs(curv - 0.1) < 1e-9)
          circles++;
      }
    }
  printf("planeCylinderIntersection: first pair with lines=(%d,%d) total lines=%d, of which "
         "circles (curvature 0.1)=%d\n",
         firstI, firstJ, total, circles);
}

static void clprops()
{
  TopoDS_Shape               cyl = BRepPrimAPI_MakeCylinder(10, 5).Shape();
  TopTools_IndexedMapOfShape em;
  TopExp::MapShapes(cyl, TopAbs_EDGE, em);
  for (int i = 1; i <= em.Extent(); i++)
  {
    double             f, l;
    Handle(Geom_Curve) c = BRep_Tool::Curve(TopoDS::Edge(em(i)), f, l);
    if (c.IsNull())
    {
      printf("curvePropsOnCircle: edge %d has no 3D curve\n", i);
      continue;
    }
    GeomLProp_CLProps p(c, 0, 2, Precision::Confusion());
    gp_Pnt            pt = p.Value();
    printf("curvePropsOnCircle: edge %d %s point=(%.17g, %.17g, %.17g) tangentDefined=%d", i,
           c->DynamicType()->Name(), pt.X(), pt.Y(), pt.Z(), (int)p.IsTangentDefined());
    if (p.IsTangentDefined())
    {
      double k = p.Curvature();
      gp_Dir t;
      p.Tangent(t);
      printf(" curvature=%.17g tangent=(%.17g, %.17g, %.17g)", k, t.X(), t.Y(), t.Z());
      if (std::abs(k) > Precision::Confusion())
      {
        gp_Dir n;
        p.Normal(n);
        gp_Pnt cc;
        p.CentreOfCurvature(cc);
        printf(" normal=(%.17g, %.17g, %.17g) centre=(%.17g, %.17g, %.17g)", n.X(), n.Y(), n.Z(),
               cc.X(), cc.Y(), cc.Z());
      }
    }
    printf("\n");
  }

  TopoDS_Shape               bx = box(10, 10, 10);
  TopTools_IndexedMapOfShape bm;
  TopExp::MapShapes(bx, TopAbs_EDGE, bm);
  double             f, l;
  Handle(Geom_Curve) c = BRep_Tool::Curve(TopoDS::Edge(bm(1)), f, l);
  GeomLProp_CLProps  p(c, 0.5, 2, Precision::Confusion());
  gp_Pnt             pt = p.Value();
  gp_Dir             t;
  p.Tangent(t);
  printf("tangentOnLineEdge: edge 1 %s range=[%.17g, %.17g] point@0.5=(%.17g, %.17g, %.17g) "
         "tangentDefined=%d tangent=(%.17g, %.17g, %.17g) curvature=%.17g\n",
         c->DynamicType()->Name(), f, l, pt.X(), pt.Y(), pt.Z(), (int)p.IsTangentDefined(), t.X(),
         t.Y(), t.Z(), p.Curvature());
}

static void slprops()
{
  TopoDS_Shape               sph = BRepPrimAPI_MakeSphere(10).Shape();
  TopTools_IndexedMapOfShape sm;
  TopExp::MapShapes(sph, TopAbs_FACE, sm);
  {
    BRepAdaptor_Surface as(TopoDS::Face(sm(1)));
    BRepLProp_SLProps   p(as, 0, 0.5, 2, Precision::Confusion());
    printf("surfacePropsOnSphere: faces=%d curvatureDefined=%d max=%.17g min=%.17g\n", sm.Extent(),
           (int)p.IsCurvatureDefined(), p.MaxCurvature(), p.MinCurvature());
  }
  TopoDS_Shape               bx = box(10, 10, 10);
  TopTools_IndexedMapOfShape bm;
  TopExp::MapShapes(bx, TopAbs_FACE, bm);
  {
    BRepAdaptor_Surface as(TopoDS::Face(bm(1)));
    BRepLProp_SLProps   p(as, 0, 0, 2, Precision::Confusion());
    printf("normalOnPlaneFace: curvatureDefined=%d max=%.17g min=%.17g\n",
           (int)p.IsCurvatureDefined(), p.MaxCurvature(), p.MinCurvature());
  }
}

int main()
{
  cone();
  intss();
  clprops();
  slprops();
  return 0;
}
