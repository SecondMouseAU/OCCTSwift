// #766 / #1989: kernel-parity probe for the middle block of Tests/OCCTMiscTests/OCCTMiscTests.swift:
// EdgeFractionParameterTests, FaceUVMidpointSampleTests and ConstructionLayerTests. The
// MultiLeafCreatedByTests suite between them resolves BRepGraph's Swift-side history records and
// has no kernel counterpart.
//
// What the kernel decides for each:
//   edge parameter bounds             BRep_Tool::Range on the box's first edge
//   face UV midpoint point/normal      BRepTools::UVBounds + BRepLProp_SLProps on the box's first face
//   coplanarity of opposite faces      their separation along the shared normal
//   cone / spherical-cap radius        the surface point at the UV midpoint, measured from the axis
//   materialize failures (#880)        BRepBuilderAPI_MakePolygon on a 1e-9 square, MakeEdge between
//                                      NaN points, MakePolygon + MakeFace on NaN vertices
//
// Build (from the repo root, against the SwiftPM-resolved pinned kernel):
//   X=.build/artifacts/<checkout>/OCCT/OCCT.xcframework/macos-arm64
//   clang++ -std=c++17 -ObjC++ -w -I"$X/Headers" -L"$X" -lOCCT-macos \
//     -framework Foundation -framework AppKit -lz -lc++ \
//     Scripts/repro/766-misc-edge-face-leaf-layer/probe.mm -o /tmp/probe_766_misc2

#include <BRepAdaptor_Surface.hxx>
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepBuilderAPI_MakePolygon.hxx>
#include <BRepLProp_SLProps.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeCone.hxx>
#include <BRepTools.hxx>
#include <BRep_Tool.hxx>
#include <Geom_SphericalSurface.hxx>
#include <TopExp.hxx>
#include <TopExp_Explorer.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopoDS.hxx>
#include <gp_Ax3.hxx>
#include <cmath>
#include <cstdio>
#include <limits>

static void uvMid(const TopoDS_Face& f, gp_Pnt& p, gp_Dir& n, double& u, double& v)
{
  double u0, u1, v0, v1;
  BRepTools::UVBounds(f, u0, u1, v0, v1);
  u = 0.5 * (u0 + u1);
  v = 0.5 * (v0 + v1);
  BRepAdaptor_Surface s(f);
  BRepLProp_SLProps   l(s, u, v, 1, 1e-9);
  p = l.Value();
  n = l.Normal();
  if (f.Orientation() == TopAbs_REVERSED)
    n.Reverse();
}

int main()
{
  TopoDS_Shape               box = BRepPrimAPI_MakeBox(gp_Pnt(-5, -5, -5), 10, 10, 10).Shape();
  TopTools_IndexedMapOfShape edges, faces;
  TopExp::MapShapes(box, TopAbs_EDGE, edges);
  TopExp::MapShapes(box, TopAbs_FACE, faces);

  std::printf("== EdgeFractionParameterTests ==\n");
  double a, b;
  BRep_Tool::Range(TopoDS::Edge(edges(1)), a, b);
  std::printf("box edge 1 range [%.12g, %.12g], linear midpoint %.12g\n", a, b, 0.5 * (a + b));

  std::printf("== FaceUVMidpointSampleTests ==\n");
  gp_Pnt p;
  gp_Dir n;
  double u, v;
  uvMid(TopoDS::Face(faces(1)), p, n, u, v);
  std::printf("box face 1 UV mid (%.12g, %.12g): point (%.12g, %.12g, %.12g) normal (%.12g, %.12g, %.12g)\n",
              u, v, p.X(), p.Y(), p.Z(), n.X(), n.Y(), n.Z());
  gp_Pnt p2;
  gp_Dir n2;
  uvMid(TopoDS::Face(faces(2)), p2, n2, u, v);
  std::printf("box face 2 UV mid point (%.12g, %.12g, %.12g) normal (%.12g, %.12g, %.12g); "
              "separation along face 1 normal = %.12g\n",
              p2.X(), p2.Y(), p2.Z(), n2.X(), n2.Y(), n2.Z(),
              std::fabs(gp_Vec(p2, p).Dot(gp_Vec(n))));

  TopoDS_Shape cone = BRepPrimAPI_MakeCone(5, 0, 10).Shape();
  for (TopExp_Explorer ex(cone, TopAbs_FACE); ex.More(); ex.Next())
  {
    TopoDS_Face         f = TopoDS::Face(ex.Current());
    BRepAdaptor_Surface s(f);
    if (s.GetType() != GeomAbs_Cone)
      continue;
    double u0, u1, v0, v1;
    BRepTools::UVBounds(f, u0, u1, v0, v1);
    gp_Pnt  q    = s.Value(0.5 * (u0 + u1), 0.5 * (v0 + v1));
    gp_Ax1  axis = s.Cone().Axis();
    gp_Vec  off(axis.Location(), q);
    gp_Vec  along = gp_Vec(axis.Direction()) * off.Dot(gp_Vec(axis.Direction()));
    std::printf("cone face UV v in [%.12g, %.12g]: radius at UV midpoint = %.12g "
                "(distance to axis origin %.12g)\n",
                v0, v1, (off - along).Magnitude(), off.Magnitude());
  }

  Handle(Geom_SphericalSurface) sph = new Geom_SphericalSurface(gp_Ax3(), 5);
  TopoDS_Face cap = BRepBuilderAPI_MakeFace(sph, 0, 2 * M_PI, 1.3, 1.5, 1e-7).Face();
  {
    double u0, u1, v0, v1;
    BRepTools::UVBounds(cap, u0, u1, v0, v1);
    BRepAdaptor_Surface s(cap);
    gp_Pnt              q = s.Value(0.5 * (u0 + u1), 0.5 * (v0 + v1));
    gp_Vec              off(gp_Pnt(0, 0, 0), q);
    std::printf("spherical cap v in [1.3, 1.5]: distance to centre %.12g, radial component to Z %.12g\n",
                off.Magnitude(), std::hypot(off.X(), off.Y()));
  }

  std::printf("== ConstructionLayerTests ==\n");
  {
    const double h = 1e-9;
    BRepBuilderAPI_MakePolygon poly(gp_Pnt(-h, -h, 0), gp_Pnt(h, -h, 0), gp_Pnt(h, h, 0),
                                    gp_Pnt(-h, h, 0), Standard_True);
    std::printf("MakePolygon of a 2e-9 square (planeHalfSize 1e-9): IsDone = %d\n",
                poly.IsDone() ? 1 : 0);
  }
  const double nan = std::numeric_limits<double>::quiet_NaN();
  {
    BRepBuilderAPI_MakeEdge e(gp_Pnt(nan, nan, nan), gp_Pnt(nan, nan, nan));
    std::printf("MakeEdge between NaN points (zero-length axis direction): IsDone = %d\n",
                e.IsDone() ? 1 : 0);
  }
  {
    BRepBuilderAPI_MakePolygon poly(gp_Pnt(nan, nan, nan), gp_Pnt(nan, nan, nan),
                                    gp_Pnt(nan, nan, nan), gp_Pnt(nan, nan, nan), Standard_True);
    std::printf("MakePolygon on NaN vertices (zero-length plane normal): IsDone = %d\n",
                poly.IsDone() ? 1 : 0);
    if (poly.IsDone())
    {
      BRepBuilderAPI_MakeFace face(poly.Wire());
      std::printf("  MakeFace on that wire: IsDone = %d\n", face.IsDone() ? 1 : 0);
    }
  }
  return 0;
}
