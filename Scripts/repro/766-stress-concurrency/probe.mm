// Epic #766, StressConcurrencyTests.swift: kernel parity for every test in the file, run
// serially. The tests' point is that concurrent calls agree with each other; the kernel value
// below is what each of them must also agree with.
#include <BRepAlgoAPI_Common.hxx>
#include <BRepAlgoAPI_Cut.hxx>
#include <BRepAlgoAPI_Fuse.hxx>
#include <BRepAdaptor_CompCurve.hxx>
#include <BRepBndLib.hxx>
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepBuilderAPI_MakeWire.hxx>
#include <BRepCheck_Analyzer.hxx>
#include <BRepFilletAPI_MakeFillet.hxx>
#include <BRepGProp.hxx>
#include <BRepMesh_IncrementalMesh.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <BRepPrimAPI_MakeSphere.hxx>
#include <BRepPrimAPI_MakeTorus.hxx>
#include <BRep_Tool.hxx>
#include <Bnd_Box.hxx>
#include <GCPnts_AbscissaPoint.hxx>
#include <GProp_GProps.hxx>
#include <Geom2d_Circle.hxx>
#include <Geom_BezierSurface.hxx>
#include <Geom_Circle.hxx>
#include <Geom_Plane.hxx>
#include <Poly_Triangulation.hxx>
#include <TColgp_Array2OfPnt.hxx>
#include <TopExp.hxx>
#include <TopExp_Explorer.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopTools_ListOfShape.hxx>
#include <TopoDS.hxx>
#include <cmath>
#include <cstdio>

static double vol(const TopoDS_Shape& s)
{
  GProp_GProps p;
  BRepGProp::VolumeProperties(s, p, true);
  return p.Mass();
}

template <typename Op>
static TopoDS_Shape boolOp(const TopoDS_Shape& a, const TopoDS_Shape& b)
{
  Op                   op;
  TopTools_ListOfShape args, tools;
  args.Append(a);
  tools.Append(b);
  op.SetArguments(args);
  op.SetTools(tools);
  op.Build();
  return op.Shape();
}

int main()
{
  TopoDS_Shape box    = BRepPrimAPI_MakeBox(gp_Pnt(-5, -5, -5), 10, 10, 10).Shape();
  TopoDS_Shape sphere = BRepPrimAPI_MakeSphere(5).Shape();
  TopoDS_Shape cyl    = BRepPrimAPI_MakeCylinder(5, 10).Shape();
  TopoDS_Shape torus  = BRepPrimAPI_MakeTorus(10, 3).Shape();

  printf("parallelVolumeQuery: box volume=%.12g\n", vol(box));
  {
    GProp_GProps p;
    BRepGProp::SurfaceProperties(sphere, p);
    printf("parallelAreaQuery: sphere area=%.12g (4*pi*25=%.12g)\n", p.Mass(), 4 * M_PI * 25);
  }
  {
    Bnd_Box b;
    BRepBndLib::Add(cyl, b, true);
    double x0, y0, z0, x1, y1, z1;
    b.Get(x0, y0, z0, x1, y1, z1);
    printf("parallelBoundsQuery: cylinder max=(%.12g, %.12g, %.12g)\n", x1, y1, z1);
  }
  {
    TopTools_IndexedMapOfShape m;
    TopExp::MapShapes(box, TopAbs_FACE, m);
    printf("parallelFaceCountQuery: faces=%d\n", m.Extent());
  }
  printf("parallelIsValidQuery: torus valid=%d\n", BRepCheck_Analyzer(torus).IsValid());
  {
    Handle(Geom_Circle) c = new Geom_Circle(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 5);
    printf("parallelCurve3DEval: domain=[%g, %.12g]", c->FirstParameter(), c->LastParameter());
    for (int i = 0; i < 8; ++i)
    {
      gp_Pnt p = c->Value(c->LastParameter() * i / 7.0);
      printf(" (%.6g,%.6g)", p.X(), p.Y());
    }
    printf("\n");
    gp_Pnt mid = c->Value(M_PI);
    printf("curveAcrossTaskBoundary: point at pi=(%.12g, %.12g, %.12g)\n", mid.X(), mid.Y(), mid.Z());
  }
  {
    Handle(Geom2d_Circle) c = new Geom2d_Circle(gp_Ax2d(gp_Pnt2d(0, 0), gp_Dir2d(1, 0)), 5);
    printf("parallelCurve2DEval: |p| at 8 samples:");
    for (int i = 0; i < 8; ++i)
    {
      gp_Pnt2d p = c->Value(c->LastParameter() * i / 7.0);
      printf(" %.12g", std::hypot(p.X(), p.Y()));
    }
    printf("\n");
  }
  {
    TColgp_Array2OfPnt poles(1, 4, 1, 4);
    double             z[4][4] = {{0, 0, 0, 0}, {0, 2, 2, 0}, {0, 2, 2, 0}, {0, 0, 0, 0}};
    for (int i = 0; i < 4; ++i)
      for (int j = 0; j < 4; ++j)
        poles(i + 1, j + 1) = gp_Pnt(5.0 * j, 5.0 * i, z[i][j]);
    Handle(Geom_BezierSurface) s = new Geom_BezierSurface(poles);
    gp_Pnt                     p = s->Value(0.5, 0.5);
    printf("parallelSurfaceEval: bezier point(0.5,0.5)=(%.12g, %.12g, %.12g)\n", p.X(), p.Y(), p.Z());
  }
  printf("parallelBoxCreation: MakeBox(10,10,10) volume=%.12g\n", vol(box));
  printf("parallelBooleanOps: fuse=%.10g cut=%.10g common=%.10g\n", vol(boolOp<BRepAlgoAPI_Fuse>(box, sphere)),
         vol(boolOp<BRepAlgoAPI_Cut>(box, sphere)), vol(boolOp<BRepAlgoAPI_Common>(box, sphere)));
  printf("parallelDocumentCreate: no kernel geometry (XCAFApp_Application::NewDocument); N/A\n");
  printf("booleanDeterministic: cut volume=%.12g\n", vol(boolOp<BRepAlgoAPI_Cut>(box, sphere)));
  {
    BRepFilletAPI_MakeFillet f(box);
    for (TopExp_Explorer e(box, TopAbs_EDGE); e.More(); e.Next())
      f.Add(1.0, TopoDS::Edge(e.Current()));
    f.Build();
    printf("filletDeterministic: IsDone=%d volume=%.12g\n", f.IsDone(), vol(f.Shape()));
  }
  {
    TopoDS_Shape             b = BRepPrimAPI_MakeBox(gp_Pnt(-5, -5, -5), 10, 10, 10).Shape();
    BRepMesh_IncrementalMesh m(b, 0.5, false, 0.5);
    int                      nodes = 0;
    for (TopExp_Explorer e(b, TopAbs_FACE); e.More(); e.Next())
    {
      TopLoc_Location loc;
      auto            t = BRep_Tool::Triangulation(TopoDS::Face(e.Current()), loc);
      nodes += t.IsNull() ? 0 : t->NbNodes();
    }
    printf("meshDeterministic: nodes=%d\n", nodes);
  }
  printf("volumeQueryDeterministic: torus volume=%.12g (2*pi^2*R*r^2=%.12g)\n", vol(torus), 2 * M_PI * M_PI * 10 * 9);
  printf("shapeAcrossTaskBoundary: box volume=%.12g\n", vol(box));
  {
    Handle(Geom_Plane) pl = new Geom_Plane(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1));
    gp_Pnt             p  = pl->Value(0, 0);
    printf("surfaceAcrossTaskBoundary: plane point(0,0)=(%g, %g, %g)\n", p.X(), p.Y(), p.Z());
  }
  printf("documentAcrossTaskBoundary: one shape added; XCAFDoc_ShapeTool::GetShapes length 1 expected\n");
  {
    BRepBuilderAPI_MakeWire mw;
    gp_Pnt                  p[4] = {gp_Pnt(-5, -5, 0), gp_Pnt(5, -5, 0), gp_Pnt(5, 5, 0), gp_Pnt(-5, 5, 0)};
    for (int i = 0; i < 4; ++i)
      mw.Add(BRepBuilderAPI_MakeEdge(p[i], p[(i + 1) % 4]));
    BRepAdaptor_CompCurve cc(mw.Wire());
    printf("wireAcrossTaskBoundary: rectangle wire length=%.12g\n", GCPnts_AbscissaPoint::Length(cc));
  }
  return 0;
}
