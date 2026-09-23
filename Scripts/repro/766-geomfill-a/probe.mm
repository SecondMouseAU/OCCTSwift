// Epic #766, GeomFill{AppSurf,BoundWithSurf,CoonsAlgPatch,Coons,CorrectedFrenet,Curved,
// DegeneratedBound,DiscreteTrihedron,DraftTrihedron,EvolvedSection}Tests.swift: kernel parity.
// Same inputs, straight to the GeomFill classes the bridge functions build, in the same way:
//  - GeomFill_SectionGenerator + GeomFill_AppSurf(3, 8, 1e-3, 1e-3, 10, false) (OCCTGeomFillAppSurf)
//  - GeomFill_BoundWithSurf on Adaptor3d_CurveOnSurface (OCCTGeomFillBoundWithSurfEvaluate)
//  - GeomFill_SimpleBound x4, head-to-tail sort, rev[2]/rev[3] flipped, Reparametrize, then
//    GeomFill_CoonsAlgPatch::Value on the grid (OCCTGeomFillCoonsAlgPatchEval)
//  - GeomFill_Coons / GeomFill_Curved on 4 point rows (OCCTGeomFillCoonsPoles / CurvedPoles)
//  - GeomFill_CorrectedFrenet / DiscreteTrihedron / DraftTrihedron D0 at 0 on edge 0 of
//    BRepPrimAPI_MakeCylinder(10, 5), edges by TopExp::MapShapes as Shape.subShapes does
//  - GeomFill_EvolvedSection(curve, Law_Constant 1 on [0,1])::SectionShape on edge 0 of (5, 10)
//  - GeomFill_DegeneratedBound((1,2,3), 0, 1, 1e-3, 1e-3)
#include <Adaptor3d_CurveOnSurface.hxx>
#include <BRepAdaptor_Curve.hxx>
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <BRep_Tool.hxx>
#include <Geom2dAdaptor_Curve.hxx>
#include <Geom2d_Line.hxx>
#include <GeomAdaptor_Curve.hxx>
#include <GeomAdaptor_Surface.hxx>
#include <GeomFill_AppSurf.hxx>
#include <GeomFill_BoundWithSurf.hxx>
#include <GeomFill_Coons.hxx>
#include <GeomFill_CoonsAlgPatch.hxx>
#include <GeomFill_CorrectedFrenet.hxx>
#include <GeomFill_Curved.hxx>
#include <GeomFill_DegeneratedBound.hxx>
#include <GeomFill_DiscreteTrihedron.hxx>
#include <GeomFill_DraftTrihedron.hxx>
#include <GeomFill_EvolvedSection.hxx>
#include <GeomFill_Line.hxx>
#include <GeomFill_SectionGenerator.hxx>
#include <GeomFill_SimpleBound.hxx>
#include <Geom_Circle.hxx>
#include <Geom_Plane.hxx>
#include <Law_Constant.hxx>
#include <NCollection_Array2.hxx>
#include <NCollection_HArray1.hxx>
#include <TopExp.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Edge.hxx>
#include <cmath>
#include <cstdio>
#include <vector>

static void frame(const char* tag, bool ok, const gp_Vec& t, const gp_Vec& n, const gp_Vec& b)
{
  printf("%s: ok=%d T=(%.12g, %.12g, %.12g) N=(%.12g, %.12g, %.12g) B=(%.12g, %.12g, %.12g)\n", tag, ok, t.X(), t.Y(),
         t.Z(), n.X(), n.Y(), n.Z(), b.X(), b.Y(), b.Z());
}

static void poles(const char* tag, GeomFill_Filling& f)
{
  int                        nu = f.NbUPoles(), nv = f.NbVPoles();
  NCollection_Array2<gp_Pnt> p(1, nu, 1, nv);
  f.Poles(p);
  printf("%s: nbU=%d nbV=%d poles(row-major)=", tag, nu, nv);
  for (int i = 1; i <= nu; i++)
    for (int j = 1; j <= nv; j++)
      printf("(%.12g,%.12g,%.12g)", p(i, j).X(), p(i, j).Y(), p(i, j).Z());
  printf("\n");
}

static void coonsAlg(const char* tag, const TopoDS_Edge e[4], int evalU, int evalV)
{
  Handle(GeomFill_Boundary) bound[4];
  for (int i = 0; i < 4; i++)
  {
    double             f, l;
    Handle(Geom_Curve) c = BRep_Tool::Curve(e[i], f, l);
    bound[i]             = new GeomFill_SimpleBound(new GeomAdaptor_Curve(c, f, l), 1e-3, 1e-3);
  }
  bool   rev[4] = {false, false, false, false};
  gp_Pnt firstPnt, tail;
  bound[0]->Points(firstPnt, tail);
  for (int i = 1; i < 4; i++)
  {
    gp_Pnt qf, ql;
    bound[i]->Points(qf, ql);
    rev[i] = (ql.Distance(tail) < qf.Distance(tail));
    tail   = rev[i] ? qf : ql;
  }
  rev[2] = !rev[2];
  rev[3] = !rev[3];
  for (int i = 0; i < 4; i++)
    bound[i]->Reparametrize(0., 1., false, false, 1., 1., rev[i]);
  GeomFill_CoonsAlgPatch patch(bound[0], bound[1], bound[2], bound[3]);
  printf("%s:", tag);
  for (int i = 0; i < evalU; i++)
    for (int j = 0; j < evalV; j++)
    {
      gp_Pnt p = patch.Value((double)i / (evalU - 1), (double)j / (evalV - 1));
      printf(" [%d](%.12g,%.12g,%.12g)", i * evalV + j, p.X(), p.Y(), p.Z());
    }
  printf("\n");
}

int main()
{
  {
    GeomFill_SectionGenerator sg;
    sg.AddCurve(new Geom_Circle(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 5));
    sg.AddCurve(new Geom_Circle(gp_Ax2(gp_Pnt(0, 0, 10), gp_Dir(0, 0, 1)), 3));
    sg.Perform(1e-6);
    Handle(NCollection_HArray1<double>) params = new NCollection_HArray1<double>(1, 2);
    params->SetValue(1, 0.0);
    params->SetValue(2, 1.0);
    sg.SetParam(params);
    Handle(GeomFill_Line) line = new GeomFill_Line(2);
    GeomFill_AppSurf      app(3, 8, 1e-3, 1e-3, 10, false);
    app.Perform(line, sg, false);
    int ud = 0, vd = 0, nup = 0, nvp = 0, nuk = 0, nvk = 0;
    if (app.IsDone())
      app.SurfShape(ud, vd, nup, nvp, nuk, nvk);
    printf("appSurf: IsDone=%d uDegree=%d vDegree=%d nbUPoles=%d nbVPoles=%d nbUKnots=%d nbVKnots=%d\n", app.IsDone(), ud,
           vd, nup, nvp, nuk, nvk);
  }
  {
    Handle(GeomAdaptor_Surface) s = new GeomAdaptor_Surface(new Geom_Plane(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)));
    Handle(Geom2dAdaptor_Curve) c = new Geom2dAdaptor_Curve(new Geom2d_Line(gp_Pnt2d(0, 0.5), gp_Dir2d(1, 0)), 0, 1);
    Adaptor3d_CurveOnSurface       cos(c, s);
    Handle(GeomFill_BoundWithSurf) b = new GeomFill_BoundWithSurf(cos, 1e-3, 1e-3);
    gp_Pnt                         v = b->Value(0.5);
    gp_Vec                         n = b->HasNormals() ? b->Norm(0.5) : gp_Vec(0, 0, 0);
    printf("boundaryWithSurface: HasNormals=%d value(0.5)=(%.12g, %.12g, %.12g) value(0)=(%.12g, %.12g, %.12g) normal=(%.12g, %.12g, %.12g)\n",
           b->HasNormals(), v.X(), v.Y(), v.Z(), b->Value(0).X(), b->Value(0).Y(), b->Value(0).Z(), n.X(), n.Y(), n.Z());
  }
  {
    // Shape.box is centred on the origin.
    TopoDS_Shape               box = BRepPrimAPI_MakeBox(gp_Pnt(-5, -5, -5), 10, 10, 10).Shape();
    TopTools_IndexedMapOfShape em;
    TopExp::MapShapes(box, TopAbs_EDGE, em);
    TopoDS_Edge e[4] = {TopoDS::Edge(em(1)), TopoDS::Edge(em(2)), TopoDS::Edge(em(3)), TopoDS::Edge(em(4))};
    for (int i = 0; i < 4; i++)
    {
      gp_Pnt a = BRep_Tool::Pnt(TopExp::FirstVertex(e[i])), z = BRep_Tool::Pnt(TopExp::LastVertex(e[i]));
      printf("box edge[%d]: (%g,%g,%g)->(%g,%g,%g)\n", i, a.X(), a.Y(), a.Z(), z.X(), z.Y(), z.Z());
    }
    coonsAlg("coonsAlgPatch box edges 0..3, 5x5", e, 5, 5);
    TopoDS_Edge sq[4] = {BRepBuilderAPI_MakeEdge(gp_Pnt(0, 0, 0), gp_Pnt(10, 0, 0)).Edge(),
                         BRepBuilderAPI_MakeEdge(gp_Pnt(10, 0, 0), gp_Pnt(10, 10, 0)).Edge(),
                         BRepBuilderAPI_MakeEdge(gp_Pnt(10, 10, 0), gp_Pnt(0, 10, 0)).Edge(),
                         BRepBuilderAPI_MakeEdge(gp_Pnt(0, 10, 0), gp_Pnt(0, 0, 0)).Edge()};
    coonsAlg("centerLandsAtRealCenter square 3x3", sq, 3, 3);
  }
  {
    const int                  n = 5;
    NCollection_Array1<gp_Pnt> a(1, n), b(1, n), c(1, n), d(1, n);
    for (int i = 0; i < n; i++)
    {
      double t = (double)i / (n - 1);
      a(i + 1) = gp_Pnt(t * 10, 0, 0);
      b(i + 1) = gp_Pnt(t * 10, 10, 0);
      c(i + 1) = gp_Pnt(0, t * 10, 0);
      d(i + 1) = gp_Pnt(10, t * 10, 0);
    }
    GeomFill_Coons coons(a, b, c, d);
    poles("coonsFilling", coons);
    for (int i = 0; i < n; i++)
    {
      double t = (double)i / (n - 1);
      a(i + 1) = gp_Pnt(t * 10, 0, std::sin(t * M_PI));
      b(i + 1) = gp_Pnt(t * 10, 10, std::sin(t * M_PI) + 1);
      c(i + 1) = gp_Pnt(0, t * 10, std::sin(t * M_PI) * 0.5);
      d(i + 1) = gp_Pnt(10, t * 10, std::sin(t * M_PI) * 0.5 + 0.5);
    }
    GeomFill_Curved curved(a, b, c, d);
    poles("curvedFilling", curved);
  }
  {
    TopoDS_Shape               cyl = BRepPrimAPI_MakeCylinder(10, 5).Shape();
    TopTools_IndexedMapOfShape em;
    TopExp::MapShapes(cyl, TopAbs_EDGE, em);
    TopoDS_Edge e0 = TopoDS::Edge(em(1));
    gp_Vec      t, n, b;
    {
      GeomFill_CorrectedFrenet cf;
      cf.SetCurve(new BRepAdaptor_Curve(e0));
      bool ok = cf.D0(0, t, n, b);
      frame("correctedFrenet edge 0 at 0", ok, t, n, b);
    }
    {
      GeomFill_DiscreteTrihedron dt;
      dt.SetCurve(new BRepAdaptor_Curve(e0));
      bool ok = dt.D0(0, t, n, b);
      frame("discreteTrihedron edge 0 at 0", ok, t, n, b);
    }
    {
      GeomFill_DraftTrihedron dr(gp_Vec(0, 0, 1), M_PI / 6);
      dr.SetCurve(new BRepAdaptor_Curve(e0));
      bool ok = dr.D0(0, t, n, b);
      frame("draftTrihedron edge 0 at 0 (binormal +Z, pi/6)", ok, t, n, b);
    }
  }
  {
    TopoDS_Shape               cyl = BRepPrimAPI_MakeCylinder(5, 10).Shape();
    TopTools_IndexedMapOfShape em;
    TopExp::MapShapes(cyl, TopAbs_EDGE, em);
    double                     f, l;
    Handle(Geom_Curve)         c   = BRep_Tool::Curve(TopoDS::Edge(em(1)), f, l);
    Handle(Law_Constant)       law = new Law_Constant();
    law->Set(1.0, 0.0, 1.0);
    GeomFill_EvolvedSection ev(c, law);
    int                     np, nk, dg;
    ev.SectionShape(np, nk, dg);
    printf("evolvedSectionInfo edge 0 (%s): nbPoles=%d nbKnots=%d degree=%d isRational=%d\n", c->DynamicType()->Name(), np,
           nk, dg, ev.IsRational());
  }
  {
    Handle(GeomFill_DegeneratedBound) db = new GeomFill_DegeneratedBound(gp_Pnt(1, 2, 3), 0, 1, 1e-3, 1e-3);
    gp_Pnt                            v  = db->Value(0.5);
    printf("degeneratedBound: Value(0.5)=(%.12g, %.12g, %.12g) IsDegenerated=%d\n", v.X(), v.Y(), v.Z(), db->IsDegenerated());
  }
  return 0;
}
