// #766 kernel parity for IntCSResultsTests, IntCurvesFaceShapeIntersectorTests,
// IntToolsBeanFaceIntersectorTests and IntToolsFaceFaceTests: the same OCCT calls, on the same
// inputs, that the bridge functions those tests reach make.
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepLib_MakeEdge.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeSphere.hxx>
#include <GC_MakePlane.hxx>
#include <GeomAPI_IntCS.hxx>
#include <Geom_Line.hxx>
#include <Geom_Plane.hxx>
#include <Geom_SphericalSurface.hxx>
#include <IntCurvesFace_ShapeIntersector.hxx>
#include <IntTools_BeanFaceIntersector.hxx>
#include <IntTools_Curve.hxx>
#include <IntTools_FaceFace.hxx>
#include <TopoDS.hxx>
#include <cstdio>

// Shape.face(from: Surface.plane(origin: .zero, normal: n), uRange: -s...s, vRange: -s...s)
static TopoDS_Face planeFace(gp_Dir n, double s)
{
  Handle(Geom_Plane) p = GC_MakePlane(gp_Pnt(0, 0, 0), n).Value();
  return BRepBuilderAPI_MakeFace(p, -s, s, -s, s, 1e-6).Face();
}

int main()
{
  // OCCTIntCSCreate / OCCTIntCSPoint
  {
    Handle(Geom_Line)             line = new Geom_Line(gp_Pnt(-20, 0, 0), gp_Dir(1, 0, 0));
    Handle(Geom_SphericalSurface) sph =
      new Geom_SphericalSurface(gp_Ax3(gp_Pnt(0, 0, 0), gp::DZ()), 5);
    GeomAPI_IntCS intcs;
    intcs.Perform(line, sph);
    printf("IntCS lineSphere: IsDone=%d NbPoints=%d NbSegments=%d\n",
           intcs.IsDone(), intcs.NbPoints(), intcs.NbSegments());
    for (int i = 1; i <= intcs.NbPoints(); i++)
    {
      gp_Pnt p = intcs.Point(i);
      double u, v, w;
      intcs.Parameters(i, u, v, w);
      printf("  point %d: (%.17g, %.17g, %.17g) w=%.17g u=%.17g v=%.17g\n",
             i, p.X(), p.Y(), p.Z(), w, u, v);
    }
  }
  // OCCTIntCurvesFaceShapeIntersect / OCCTIntCurvesFaceShapeIntersectNearest
  {
    // Shape.box(width: 10, height: 10, depth: 10) is centred on the origin.
    TopoDS_Shape box = BRepPrimAPI_MakeBox(gp_Pnt(-5, -5, -5), 10, 10, 10).Shape();
    IntCurvesFace_ShapeIntersector si;
    si.Load(box, 1e-6);
    si.Perform(gp_Lin(gp_Pnt(5, 5, -20), gp_Dir(0, 0, 1)), -1e10, 1e10);
    printf("ShapeIntersector box, ray (5,5,-20)+Z: NbPnt=%d\n", si.NbPnt());
    si.SortResult();
    for (int i = 1; i <= si.NbPnt(); i++)
      printf("  hit %d: (%.17g, %.17g, %.17g) w=%.17g\n",
             i, si.Pnt(i).X(), si.Pnt(i).Y(), si.Pnt(i).Z(), si.WParameter(i));

    IntCurvesFace_ShapeIntersector miss;
    miss.Load(box, 1e-6);
    miss.Perform(gp_Lin(gp_Pnt(100, 100, -20), gp_Dir(0, 0, 1)), -1e10, 1e10);
    printf("ShapeIntersector box, ray (100,100,-20)+Z: NbPnt=%d\n", miss.NbPnt());

    TopoDS_Shape                   sphere = BRepPrimAPI_MakeSphere(5).Shape();
    IntCurvesFace_ShapeIntersector sn;
    sn.Load(sphere, 1e-6);
    sn.PerformNearest(gp_Lin(gp_Pnt(0, 0, -20), gp_Dir(0, 0, 1)), -1e10, 1e10);
    printf("ShapeIntersector sphere r5, nearest from (0,0,-20)+Z: NbPnt=%d\n", sn.NbPnt());
    if (sn.NbPnt() >= 1)
      printf("  nearest: (%.17g, %.17g, %.17g) w=%.17g\n",
             sn.Pnt(1).X(), sn.Pnt(1).Y(), sn.Pnt(1).Z(), sn.WParameter(1));
  }
  // OCCTIntToolsBeanFaceIntersect
  {
    TopoDS_Face f        = planeFace(gp_Dir(0, 0, 1), 10);
    const char* names[2] = {"crossing (0,0,-5)-(0,0,5)", "on face (-3,0,0)-(3,0,0)"};
    gp_Pnt      a[2]     = {gp_Pnt(0, 0, -5), gp_Pnt(-3, 0, 0)};
    gp_Pnt      b[2]     = {gp_Pnt(0, 0, 5), gp_Pnt(3, 0, 0)};
    for (int k = 0; k < 2; k++)
    {
      TopoDS_Edge                  e = BRepLib_MakeEdge(a[k], b[k]).Edge();
      IntTools_BeanFaceIntersector bfi(e, f);
      bfi.Perform();
      printf("BeanFace %s: IsDone=%d\n", names[k], bfi.IsDone());
      if (!bfi.IsDone())
        continue;
      printf("  MinimalSquareDistance=%.17g NbRanges=%d\n",
             bfi.MinimalSquareDistance(), bfi.Result().Length());
      for (int i = 1; i <= bfi.Result().Length(); i++)
        printf("  range %d: [%.17g, %.17g]\n", i, bfi.Result()(i).First(), bfi.Result()(i).Last());
    }
  }
  // OCCTIntToolsFaceFace
  {
    const char* names[2] = {"perpendicular Z/Y planes", "coincident Z planes"};
    gp_Dir      n2[2]    = {gp_Dir(0, 1, 0), gp_Dir(0, 0, 1)};
    for (int k = 0; k < 2; k++)
    {
      IntTools_FaceFace ff;
      ff.SetParameters(true, true, true, 1e-7);
      ff.Perform(planeFace(gp_Dir(0, 0, 1), 5), planeFace(n2[k], 5));
      printf("FaceFace %s: IsDone=%d\n", names[k], ff.IsDone());
      if (!ff.IsDone())
        continue;
      printf("  TangentFaces=%d NbLines=%d NbPoints=%d\n",
             ff.TangentFaces(), ff.Lines().Length(), ff.Points().Length());
      for (int i = 1; i <= ff.Lines().Length(); i++)
      {
        const IntTools_Curve& c = ff.Lines()(i);
        if (c.HasBounds())
        {
          double t1, t2;
          gp_Pnt p1, p2;
          c.Bounds(t1, t2, p1, p2);
          printf("  line %d: (%.17g, %.17g, %.17g) -> (%.17g, %.17g, %.17g)\n",
                 i, p1.X(), p1.Y(), p1.Z(), p2.X(), p2.Y(), p2.Z());
        }
        else
          printf("  line %d: unbounded\n", i);
      }
    }
  }
  return 0;
}
