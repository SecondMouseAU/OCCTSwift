// Epic #766, OCCTDrawingTests: PointProjectionTests and PolyHLRTests.
// Point projection: GeomAPI_ProjectPointOnSurf over the face's UV bounds at
// Precision::Confusion() (OCCTFaceProjectPoint / OCCTFaceProjectPointAll), and
// GeomAPI_ProjectPointOnCurve over the edge's range (OCCTEdgeProjectPoint's nearest point), on
// the same centred box, sphere and cylinder. Poly HLR: BRepMesh_IncrementalMesh then
// HLRBRep_PolyAlgo with HLRAlgo_Projector(gp_Ax2(origin, view)) as OCCTDrawingCreatePoly runs it;
// each category the way OCCTDrawingGetEdges assembles it (nil when nothing contributes).
#include <BRepAdaptor_Curve.hxx>
#include <BRepAlgoAPI_Fuse.hxx>
#include <BRepBndLib.hxx>
#include <BRepMesh_IncrementalMesh.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <BRepPrimAPI_MakeSphere.hxx>
#include <BRepTools.hxx>
#include <BRep_Builder.hxx>
#include <BRep_Tool.hxx>
#include <Bnd_Box.hxx>
#include <GeomAPI_ProjectPointOnCurve.hxx>
#include <GeomAPI_ProjectPointOnSurf.hxx>
#include <HLRAlgo_Projector.hxx>
#include <HLRBRep_Algo.hxx>
#include <HLRBRep_HLRToShape.hxx>
#include <HLRBRep_PolyAlgo.hxx>
#include <HLRBRep_PolyHLRToShape.hxx>
#include <Precision.hxx>
#include <TopExp.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Compound.hxx>
#include <cmath>
#include <cstdio>

static void faceProj(const char* tag, const TopoDS_Face& f, gp_Pnt p)
{
  Handle(Geom_Surface) s = BRep_Tool::Surface(f);
  double               u0, u1, v0, v1;
  BRepTools::UVBounds(f, u0, u1, v0, v1);
  GeomAPI_ProjectPointOnSurf proj(p, s, u0, u1, v0, v1, Precision::Confusion());
  gp_Pnt                     n = proj.NearestPoint();
  printf("%s: nbPoints=%d nearest=(%.17g, %.17g, %.17g) distance=%.17g\n", tag, proj.NbPoints(), n.X(),
         n.Y(), n.Z(), proj.LowerDistance());
}

static void category(const char* tag, TopoDS_Shape a, TopoDS_Shape b, TopoDS_Shape c)
{
  BRep_Builder    bld;
  TopoDS_Compound comp;
  bld.MakeCompound(comp);
  bool         any      = false;
  TopoDS_Shape parts[3] = {a, b, c};
  for (const TopoDS_Shape& s : parts)
    if (!s.IsNull())
    {
      bld.Add(comp, s);
      any = true;
    }
  if (!any)
  {
    printf("%s: nil\n", tag);
    return;
  }
  TopTools_IndexedMapOfShape m;
  TopExp::MapShapes(comp, TopAbs_EDGE, m);
  Bnd_Box bb;
  BRepBndLib::Add(comp, bb, true);
  double x0, y0, z0, x1, y1, z1;
  bb.Get(x0, y0, z0, x1, y1, z1);
  printf("%s: edges=%d extent=(%.9g, %.9g)..(%.9g, %.9g)\n", tag, m.Extent(), x0, y0, x1, y1);
}

static void poly(const char* tag, TopoDS_Shape s, gp_Dir v, double deflection)
{
  BRepMesh_IncrementalMesh mesh(s, deflection);
  Handle(HLRBRep_PolyAlgo) algo = new HLRBRep_PolyAlgo();
  algo->Projector(HLRAlgo_Projector(gp_Ax2(gp_Pnt(0, 0, 0), v)));
  algo->Load(s);
  algo->Update();
  HLRBRep_PolyHLRToShape h;
  h.Update(algo);
  char t[160];
  snprintf(t, sizeof t, "%s visible", tag);
  category(t, h.VCompound(), h.Rg1LineVCompound(), h.OutLineVCompound());
  snprintf(t, sizeof t, "%s hidden", tag);
  category(t, h.HCompound(), h.Rg1LineHCompound(), h.OutLineHCompound());
  snprintf(t, sizeof t, "%s outline", tag);
  category(t, h.OutLineVCompound(), h.OutLineHCompound(), TopoDS_Shape());
}

int main()
{
  TopoDS_Shape box = BRepPrimAPI_MakeBox(gp_Pnt(-5, -5, -5), 10, 10, 10).Shape();
  TopTools_IndexedMapOfShape faces, edges;
  TopExp::MapShapes(box, TopAbs_FACE, faces);
  TopExp::MapShapes(box, TopAbs_EDGE, edges);
  for (int i = 1; i <= faces.Extent(); ++i)
  {
    TopoDS_Face f = TopoDS::Face(faces(i));
    BRepAdaptor_Surface a(f);
    gp_Dir n = a.Plane().Axis().Direction();
    if (f.Orientation() == TopAbs_REVERSED)
      n.Reverse();
    if (n.Z() > 0.9)
    {
      faceProj("box top face, point (0,0,15)", f, gp_Pnt(0, 0, 15));
      break;
    }
  }
  {
    TopoDS_Shape               sph = BRepPrimAPI_MakeSphere(5).Shape();
    TopTools_IndexedMapOfShape sf;
    TopExp::MapShapes(sph, TopAbs_FACE, sf);
    faceProj("sphere r5 face 0, point (10,0,0)", TopoDS::Face(sf(1)), gp_Pnt(10, 0, 0));
  }
  {
    // First line edge in the unique edge map, projected from its midpoint + (1, 1, 1).
    TopoDS_Edge        e = TopoDS::Edge(edges(1));
    double             f, l;
    Handle(Geom_Curve) c  = BRep_Tool::Curve(e, f, l);
    gp_Pnt             a  = c->Value(f), b = c->Value(l);
    gp_Pnt             pt((a.X() + b.X()) / 2 + 1, (a.Y() + b.Y()) / 2 + 1, (a.Z() + b.Z()) / 2 + 1);
    GeomAPI_ProjectPointOnCurve proj(pt, c, f, l);
    printf("box edge 1 (%g,%g,%g)-(%g,%g,%g), midpoint+(1,1,1): distance=%.17g (sqrt 2 = %.17g)\n",
           a.X(), a.Y(), a.Z(), b.X(), b.Y(), b.Z(), proj.LowerDistance(), std::sqrt(2.0));
  }
  {
    TopoDS_Shape               cyl = BRepPrimAPI_MakeCylinder(5, 10).Shape();
    TopTools_IndexedMapOfShape ce;
    TopExp::MapShapes(cyl, TopAbs_EDGE, ce);
    for (int i = 1; i <= ce.Extent(); ++i)
    {
      BRepAdaptor_Curve ac(TopoDS::Edge(ce(i)));
      if (ac.GetType() != GeomAbs_Circle)
        continue;
      double             f, l;
      Handle(Geom_Curve) c   = BRep_Tool::Curve(TopoDS::Edge(ce(i)), f, l);
      gp_Pnt             on  = c->Value((f + l) / 2);
      gp_Vec             rad(on.X(), on.Y(), 0);
      gp_Pnt             off = on.Translated(rad.Normalized() * 3.0);
      GeomAPI_ProjectPointOnCurve proj(off, c, f, l);
      printf("cylinder circle edge %d, 3 out radially from its mid-parameter point: distance=%.17g\n",
             i, proj.LowerDistance());
      break;
    }
  }

  const double iso = 1.0 / std::sqrt(3.0);
  poly("fastTopViewBox", box, gp_Dir(0, 0, 1), 0.01);
  poly("fastIsometricBox", BRepPrimAPI_MakeBox(gp_Pnt(-10, -5, -2.5), 20, 10, 5).Shape(),
       gp_Dir(iso, iso, iso), 0.01);
  poly("fastProjectCylinder", BRepPrimAPI_MakeCylinder(5, 10).Shape(), gp_Dir(1, 0, 0), 0.01);
  {
    TopoDS_Shape fused = BRepAlgoAPI_Fuse(BRepPrimAPI_MakeBox(gp_Pnt(-5, -5, -5), 10, 10, 10).Shape(),
                                          BRepPrimAPI_MakeBox(gp_Pnt(-2.5, -2.5, -10), 5, 5, 20).Shape())
                           .Shape();
    poly("fastHiddenEdges", fused, gp_Dir(0, 1, 0), 0.01);
  }
  poly("fastVsExact fast", BRepPrimAPI_MakeSphere(10).Shape(), gp_Dir(0, 0, 1), 0.01);
  poly("customDeflection coarse", BRepPrimAPI_MakeSphere(10).Shape(), gp_Dir(0, 0, 1), 1.0);
  poly("customDeflection fine", BRepPrimAPI_MakeSphere(10).Shape(), gp_Dir(0, 0, 1), 0.001);
  return 0;
}
