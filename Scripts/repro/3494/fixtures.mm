// #3494 fixtures: valid BREP and binary files that carry every record kind the shape readers
// parse with a declared count (B-spline and Bezier curves, 2d curves and surfaces, trimmed and
// offset curves and surfaces, a Polygon3D table, PolygonOnTriangulations and Triangulations with
// normals, composed locations). The #3487 corpus has only the B-spline of a loft, no Bezier, no
// Polygon3D and no 2d B-spline.
//   fixtures <dir>     writes x_<name>.brep (text), x_<name>.bset (BinTools::Write, the
//                      BinTools_ShapeSet reader) and x_<name>.bin (BinTools_ShapeWriter)
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepBuilderAPI_MakeWire.hxx>
#include <BRepBuilderAPI_Transform.hxx>
#include <BRepMesh_IncrementalMesh.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <BRepPrimAPI_MakeSphere.hxx>
#include <BRepTools.hxx>
#include <BRep_Builder.hxx>
#include <BRep_Tool.hxx>
#include <BinTools.hxx>
#include <BinTools_ShapeWriter.hxx>
#include <Geom2d_BSplineCurve.hxx>
#include <Geom2d_BezierCurve.hxx>
#include <Geom2d_Circle.hxx>
#include <Geom2d_Ellipse.hxx>
#include <Geom2d_Hyperbola.hxx>
#include <Geom2d_Line.hxx>
#include <Geom2d_OffsetCurve.hxx>
#include <Geom2d_Parabola.hxx>
#include <Geom2d_TrimmedCurve.hxx>
#include <GeomAPI_Interpolate.hxx>
#include <Geom_BSplineCurve.hxx>
#include <Geom_BSplineSurface.hxx>
#include <Geom_BezierCurve.hxx>
#include <Geom_BezierSurface.hxx>
#include <Geom_Circle.hxx>
#include <Geom_ConicalSurface.hxx>
#include <Geom_CylindricalSurface.hxx>
#include <Geom_Ellipse.hxx>
#include <Geom_Hyperbola.hxx>
#include <Geom_Line.hxx>
#include <Geom_OffsetCurve.hxx>
#include <Geom_OffsetSurface.hxx>
#include <Geom_Parabola.hxx>
#include <Geom_Plane.hxx>
#include <Geom_RectangularTrimmedSurface.hxx>
#include <Geom_SphericalSurface.hxx>
#include <Geom_SurfaceOfLinearExtrusion.hxx>
#include <Geom_SurfaceOfRevolution.hxx>
#include <Geom_ToroidalSurface.hxx>
#include <Geom_TrimmedCurve.hxx>
#include <NCollection_Array1.hxx>
#include <NCollection_Array2.hxx>
#include <Poly_Triangulation.hxx>
#include <TopExp_Explorer.hxx>
#include <TopTools_FormatVersion.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Compound.hxx>
#include <fstream>
#include <sstream>
#include <string>

typedef opencascade::handle<Geom_Curve> HC;

static void emit(const TopoDS_Shape& s, const std::string& dir, const char* name, bool tri)
{
  std::string base = dir + "/x_" + name;
  BRepTools::Write(s, (base + ".brep").c_str(), tri, tri, TopTools_FormatVersion_VERSION_3);
  std::ostringstream o1;
  BinTools::Write(s, o1, tri, tri, BinTools_FormatVersion_CURRENT);
  std::ofstream(base + ".bset", std::ios::binary) << o1.str();
  std::ostringstream   o2;
  BinTools_ShapeWriter w;
  w.Write(s, o2);
  std::ofstream(base + ".bin", std::ios::binary) << o2.str();
}

static TopoDS_Edge edge(const opencascade::handle<Geom_Curve>& c)
{
  return BRepBuilderAPI_MakeEdge(c).Edge();
}

static opencascade::handle<Geom_BSplineCurve> bspline(bool rational, bool periodic)
{
  NCollection_Array1<gp_Pnt> p(1, 5);
  NCollection_Array1<double> w(1, 5);
  for (int i = 1; i <= 5; i++)
  {
    p(i) = gp_Pnt(i * 2.0, (i % 2) * 3.0, i * 0.5);
    w(i) = 1.0 + 0.25 * i;
  }
  NCollection_Array1<double> k(1, 3);
  NCollection_Array1<int>    m(1, 3);
  k(1) = 0; k(2) = 1; k(3) = 2;
  m(1) = 3; m(2) = 2; m(3) = 3;
  if (periodic)
  {
    NCollection_Array1<gp_Pnt> pp(1, 4);
    NCollection_Array1<double> pw(1, 4);
    NCollection_Array1<double> pk(1, 5);
    NCollection_Array1<int>    pm(1, 5);
    for (int i = 1; i <= 4; i++) { pp(i) = gp_Pnt(cos(i * 1.57), sin(i * 1.57), 0); pw(i) = 1.0 + 0.1 * i; }
    for (int i = 1; i <= 5; i++) { pk(i) = i - 1; pm(i) = 1; }
    return rational ? new Geom_BSplineCurve(pp, pw, pk, pm, 3, true) : new Geom_BSplineCurve(pp, pk, pm, 3, true);
  }
  return rational ? new Geom_BSplineCurve(p, w, k, m, 2, false) : new Geom_BSplineCurve(p, k, m, 2, false);
}

static TopoDS_Shape curves3d()
{
  TopoDS_Compound c;
  BRep_Builder    b;
  b.MakeCompound(c);
  gp_Ax2 ax(gp_Pnt(1, 2, 3), gp_Dir(0, 0, 1));
  opencascade::handle<Geom_Circle> circ = new Geom_Circle(ax, 4.0);
  NCollection_Array1<gp_Pnt> bp(1, 4);
  NCollection_Array1<double> bw(1, 4);
  for (int i = 1; i <= 4; i++) { bp(i) = gp_Pnt(i, i * i % 3, 0.5 * i); bw(i) = 1.0 + i; }
  HC list[] = {new Geom_Line(gp_Pnt(0, 0, 0), gp_Dir(1, 1, 0)),
               circ,
               new Geom_Ellipse(ax, 5.0, 3.0),
               new Geom_Parabola(ax, 2.0),
               new Geom_Hyperbola(ax, 5.0, 3.0),
               new Geom_BezierCurve(bp),
               new Geom_BezierCurve(bp, bw),
               bspline(false, false),
               bspline(true, false),
               bspline(false, true),
               bspline(true, true),
               new Geom_TrimmedCurve(circ, 0.2, 1.7),
               new Geom_OffsetCurve(circ, 0.5, gp_Dir(0, 0, 1))};
  for (const HC& h : list)
  {
    TopoDS_Edge e;
    if (h->DynamicType() == STANDARD_TYPE(Geom_Parabola) || h->DynamicType() == STANDARD_TYPE(Geom_Hyperbola)
        || h->DynamicType() == STANDARD_TYPE(Geom_Line))
      e = BRepBuilderAPI_MakeEdge(h, -1.0, 2.0).Edge();
    else if (h->IsPeriodic())
      e = BRepBuilderAPI_MakeEdge(h, 0.0, 1.5).Edge();
    else
      e = BRepBuilderAPI_MakeEdge(h, h->FirstParameter(), h->LastParameter()).Edge();
    if (!e.IsNull())
      b.Add(c, e);
  }
  return c;
}

static opencascade::handle<Geom_Surface> trim(const opencascade::handle<Geom_Surface>& s, double u1, double u2, double v1, double v2)
{
  return new Geom_RectangularTrimmedSurface(s, u1, u2, v1, v2, true, true);
}

static TopoDS_Shape surfaces()
{
  TopoDS_Compound c;
  BRep_Builder    b;
  b.MakeCompound(c);
  gp_Ax3 ax(gp_Pnt(1, 2, 3), gp_Dir(0, 0, 1));
  NCollection_Array2<gp_Pnt> bp(1, 3, 1, 3);
  NCollection_Array2<double> bw(1, 3, 1, 3);
  for (int i = 1; i <= 3; i++)
    for (int j = 1; j <= 3; j++) { bp(i, j) = gp_Pnt(i * 2.0, j * 2.0, (i * j) % 3); bw(i, j) = 1.0 + 0.2 * i * j; }
  NCollection_Array2<gp_Pnt> sp(1, 4, 1, 4);
  NCollection_Array2<double> sw(1, 4, 1, 4);
  for (int i = 1; i <= 4; i++)
    for (int j = 1; j <= 4; j++) { sp(i, j) = gp_Pnt(i * 2.0, j * 2.0, (i + j) % 3); sw(i, j) = 1.0 + 0.1 * i + 0.05 * j; }
  NCollection_Array1<double> uk(1, 2), vk(1, 2);
  NCollection_Array1<int>    um(1, 2), vm(1, 2);
  uk(1) = 0; uk(2) = 1; vk(1) = 0; vk(2) = 1;
  um(1) = 4; um(2) = 4; vm(1) = 4; vm(2) = 4;
  opencascade::handle<Geom_Plane>               pl = new Geom_Plane(ax);
  opencascade::handle<Geom_CylindricalSurface>  cy = new Geom_CylindricalSurface(ax, 3.0);
  opencascade::handle<Geom_Line>                ln = new Geom_Line(gp_Pnt(3, 0, 0), gp_Dir(0, 0, 1));
  opencascade::handle<Geom_Surface> list[] = {
     trim(pl, 0, 5, 0, 4),
     trim(cy, 0, 3.0, 0, 5),
     trim(new Geom_ConicalSurface(ax, 0.4, 2.0), 0, 3.0, 0, 5),
     trim(new Geom_SphericalSurface(ax, 3.0), 0, 3.0, -1, 1),
     trim(new Geom_ToroidalSurface(ax, 5.0, 1.0), 0, 3.0, 0, 3),
    new Geom_BezierSurface(bp),
    new Geom_BezierSurface(bp, bw),
    new Geom_BSplineSurface(sp, uk, vk, um, vm, 3, 3),
    new Geom_BSplineSurface(sp, sw, uk, vk, um, vm, 3, 3),
     trim(new Geom_SurfaceOfLinearExtrusion(new Geom_Circle(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 2.0), gp_Dir(0, 1, 1)), 0, 3.0, 0, 5),
     trim(new Geom_SurfaceOfRevolution(ln, gp_Ax1(gp_Pnt(0, 0, 0), gp_Dir(1, 0, 0))), 0, 3.0, 0, 5),
    new Geom_OffsetSurface( trim(cy, 0, 3.0, 0, 5), 0.5)};
  for (const opencascade::handle<Geom_Surface>& s : list)
  {
    TopoDS_Face f = BRepBuilderAPI_MakeFace(s, 1e-6).Face();
    if (!f.IsNull())
      b.Add(c, f);
  }
  return c;
}

static TopoDS_Shape pcurves()
{
  TopoDS_Compound c;
  BRep_Builder    b;
  b.MakeCompound(c);
  opencascade::handle<Geom_Plane> pl = new Geom_Plane(gp_Ax3());
  opencascade::handle<Geom_CylindricalSurface> cy = new Geom_CylindricalSurface(gp_Ax3(), 3.0);
  gp_Ax22d ax;
  opencascade::handle<Geom2d_Circle> circ = new Geom2d_Circle(ax, 2.0);
  NCollection_Array1<gp_Pnt2d> bp(1, 4);
  NCollection_Array1<double>   bw(1, 4);
  for (int i = 1; i <= 4; i++) { bp(i) = gp_Pnt2d(i, i * i % 3); bw(i) = 1.0 + i; }
  NCollection_Array1<double> k(1, 3);
  NCollection_Array1<int>    m(1, 3);
  k(1) = 0; k(2) = 1; k(3) = 2;
  m(1) = 3; m(2) = 2; m(3) = 3;
  NCollection_Array1<gp_Pnt2d> sp(1, 5);
  NCollection_Array1<double>   sw(1, 5);
  for (int i = 1; i <= 5; i++) { sp(i) = gp_Pnt2d(i, (i % 2) * 1.5); sw(i) = 1.0 + 0.2 * i; }
  opencascade::handle<Geom2d_Curve> list[] = {
    new Geom2d_Line(gp_Pnt2d(0, 0), gp_Dir2d(1, 1)),
    circ,
    new Geom2d_Ellipse(ax, 3.0, 2.0),
    new Geom2d_Parabola(ax, 1.0),
    new Geom2d_Hyperbola(ax, 3.0, 2.0),
    new Geom2d_BezierCurve(bp),
    new Geom2d_BezierCurve(bp, bw),
    new Geom2d_BSplineCurve(sp, k, m, 2),
    new Geom2d_BSplineCurve(sp, sw, k, m, 2),
    new Geom2d_TrimmedCurve(circ, 0.1, 1.5),
    new Geom2d_OffsetCurve(circ, 0.5)};
  int n = 0;
  for (const auto& h : list)
  {
    TopoDS_Edge e = BRepBuilderAPI_MakeEdge(gp_Pnt(0, 0, 0), gp_Pnt(1 + n, 0, 0)).Edge();
    b.UpdateEdge(e, h, (n % 2) ? pl : opencascade::handle<Geom_Surface>(cy), TopLoc_Location(), 1e-6);
    b.Range(e, (n % 2) ? pl : opencascade::handle<Geom_Surface>(cy), TopLoc_Location(), 0.1, 1.0);
    b.Add(c, e);
    n++;
  }
  // a seam edge: two pcurves on a closed surface
  TopoDS_Edge seam = BRepBuilderAPI_MakeEdge(gp_Pnt(3, 0, 0), gp_Pnt(3, 0, 5)).Edge();
  b.UpdateEdge(seam, new Geom2d_Line(gp_Pnt2d(0, 0), gp_Dir2d(0, 1)), new Geom2d_Line(gp_Pnt2d(6.28318530717958, 0), gp_Dir2d(0, 1)), cy, TopLoc_Location(), 1e-6);
  b.Add(c, seam);
  return c;
}

static TopoDS_Shape polygons3d()
{
  TopoDS_Compound c;
  BRep_Builder    b;
  b.MakeCompound(c);
  b.Add(c, edge(new Geom_Circle(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 4.0)));
  b.Add(c, edge(bspline(false, false)));
  b.Add(c, edge(bspline(true, false)));
  BRepMesh_IncrementalMesh(c, 0.05);
  return c;
}

static TopoDS_Shape meshes()
{
  TopoDS_Compound c;
  BRep_Builder    b;
  b.MakeCompound(c);
  TopoDS_Shape cyl = BRepPrimAPI_MakeCylinder(5, 12).Shape();
  TopoDS_Shape sph = BRepPrimAPI_MakeSphere(7).Shape();
  b.Add(c, cyl);
  b.Add(c, BRepBuilderAPI_Transform(sph, [] { gp_Trsf t; t.SetTranslation(gp_Vec(20, 0, 0)); return t; }(), true).Shape());
  BRepMesh_IncrementalMesh(c, 0.4);
  for (TopExp_Explorer e(c, TopAbs_FACE); e.More(); e.Next())
  {
    TopLoc_Location l;
    auto t = BRep_Tool::Triangulation(TopoDS::Face(e.Current()), l);
    if (!t.IsNull())
      t->ComputeNormals();
  }
  return c;
}

static TopoDS_Shape located()
{
  TopoDS_Shape box = BRepPrimAPI_MakeBox(4, 5, 6).Shape();
  gp_Trsf t1, t2, t3;
  t1.SetTranslation(gp_Vec(10, 0, 0));
  t2.SetRotation(gp_Ax1(gp::Origin(), gp::DZ()), 0.7);
  t3.SetScale(gp_Pnt(0, 0, 0), 1.0);
  TopLoc_Location l1(t1), l2(t2);
  TopoDS_Compound inner, outer;
  BRep_Builder    b;
  b.MakeCompound(inner);
  b.MakeCompound(outer);
  b.Add(inner, box.Located(l1));
  b.Add(inner, box.Located(l2 * l1));
  b.Add(inner, box.Located(l1.Powered(2) * l2));
  b.Add(outer, inner.Located(l2));
  b.Add(outer, inner.Located(l1 * l2));
  return outer;
}

// The smallest file of each kind, embedded in BREPKernelRecordCountTests (Tests/OCCTIOTests).
static void tiny(const std::string& dir)
{
  BRep_Builder b;
  NCollection_Array1<gp_Pnt> p(1, 3);
  p(1) = gp_Pnt(0, 0, 0);
  p(2) = gp_Pnt(1, 2, 0);
  p(3) = gp_Pnt(2, 0, 0);
  NCollection_Array1<double> k(1, 2);
  NCollection_Array1<int>    m(1, 2);
  k(1) = 0;
  k(2) = 1;
  m(1) = 3;
  m(2) = 3;
  opencascade::handle<Geom_BSplineCurve> bc = new Geom_BSplineCurve(p, k, m, 2);
  emit(edge(bc), dir, "tiny_bsplinecurve", false);

  NCollection_Array2<gp_Pnt> sp(1, 3, 1, 3);
  for (int i = 1; i <= 3; i++)
    for (int j = 1; j <= 3; j++)
      sp(i, j) = gp_Pnt(i, j, (i + j) % 2);
  opencascade::handle<Geom_BSplineSurface> bs = new Geom_BSplineSurface(sp, k, k, m, m, 2, 2);
  emit(BRepBuilderAPI_MakeFace(bs, 1e-6).Face(), dir, "tiny_bsplinesurface", false);

  NCollection_Array2<gp_Pnt> bz(1, 3, 1, 3);
  for (int i = 1; i <= 3; i++)
    for (int j = 1; j <= 3; j++)
      bz(i, j) = gp_Pnt(i, j, (i * j) % 2);
  emit(BRepBuilderAPI_MakeFace(new Geom_BezierSurface(bz), 1e-6).Face(), dir, "tiny_beziersurface", false);

  NCollection_Array1<gp_Pnt2d> p2(1, 3);
  p2(1) = gp_Pnt2d(0, 0);
  p2(2) = gp_Pnt2d(1, 2);
  p2(3) = gp_Pnt2d(2, 0);
  TopoDS_Edge e = BRepBuilderAPI_MakeEdge(gp_Pnt(0, 0, 0), gp_Pnt(2, 0, 0)).Edge();
  b.UpdateEdge(e, new Geom2d_BSplineCurve(p2, k, m, 2), new Geom_Plane(gp_Ax3()), TopLoc_Location(), 1e-6);
  emit(e, dir, "tiny_bspline2d", false);

  BRepBuilderAPI_MakeWire mw;
  gp_Pnt q[3] = {gp_Pnt(0, 0, 0), gp_Pnt(4, 0, 0), gp_Pnt(0, 3, 0)};
  for (int i = 0; i < 3; i++)
    mw.Add(BRepBuilderAPI_MakeEdge(q[i], q[(i + 1) % 3]).Edge());
  TopoDS_Shape tri = BRepBuilderAPI_MakeFace(mw.Wire()).Face();
  BRepMesh_IncrementalMesh(tri, 10.0);
  emit(tri, dir, "tiny_mesh", true);

  TopoDS_Shape arc = BRepBuilderAPI_MakeEdge(new Geom_Circle(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 4.0), 0.0, 1.2).Edge();
  BRepMesh_IncrementalMesh(arc, 1.0, false, 0.6);
  emit(arc, dir, "tiny_polygon3d", true);
}

int main(int argc, char** argv)
{
  if (argc < 2)
    return 2;
  std::string dir = argv[1];
  emit(curves3d(), dir, "curves3d", false);
  emit(surfaces(), dir, "surfaces", false);
  emit(pcurves(), dir, "pcurves", false);
  emit(polygons3d(), dir, "polygons3d", true);
  emit(meshes(), dir, "meshes", true);
  emit(located(), dir, "located", false);
  tiny(dir);
  return 0;
}
