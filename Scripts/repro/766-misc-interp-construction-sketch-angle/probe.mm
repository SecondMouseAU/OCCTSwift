// #766 / #1989: kernel-parity probe for the first block of Tests/OCCTMiscTests/OCCTMiscTests.swift:
// InterpolationExpansion3DTests, SketchBuildProfileTests and AngleHelperTests. The
// ConstructionContext suites in the same block are pure Swift bookkeeping (ID stores, locks, a
// document-keyed table) and have no kernel counterpart.
//
// Every fixture is built with the OCCT calls the bridge makes:
//   GeomAPI_Interpolate + Load(start, end)         OCCTCurve3DInterpolateWithTangents
//   GeomAPI_Interpolate + Load(tangents, flags)    OCCTInterpolateWithAllTangents
//   GeomAPI_Interpolate(points, parameters, ...)   OCCTInterpolateWithParameters
//   GeomAPI_Interpolate(points, periodic = true)   OCCTCurve3DInterpolate (closed: true)
//   BRepBuilderAPI_MakePolygon, closed              OCCTWireCreatePolygon3D via Wire.polygon3D
//   GProp linear properties                         OCCTWireGetLength
//   BRepAdaptor_Curve::D1 / BRepAdaptor_Surface     Edge.tangent / Face.normal
//   gp_Vec::Angle                                   the kernel's own angle, beside Swift's acos
//
// Build (from the repo root, against the SwiftPM-resolved pinned kernel):
//   X=.build/artifacts/<checkout>/OCCT/OCCT.xcframework/macos-arm64
//   clang++ -std=c++17 -ObjC++ -w -I"$X/Headers" -L"$X" -lOCCT-macos \
//     -framework Foundation -framework AppKit -lz -lc++ \
//     Scripts/repro/766-misc-interp-construction-sketch-angle/probe.mm -o /tmp/probe_766_misc1

#include <BRepAdaptor_Curve.hxx>
#include <BRepAdaptor_Surface.hxx>
#include <BRepBuilderAPI_MakePolygon.hxx>
#include <BRepGProp.hxx>
#include <BRepLProp_SLProps.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepTools.hxx>
#include <GProp_GProps.hxx>
#include <GeomAPI_Interpolate.hxx>
#include <Geom_BSplineCurve.hxx>
#include <NCollection_Array1.hxx>
#include <NCollection_HArray1.hxx>
#include <TColStd_HArray1OfReal.hxx>
#include <TColgp_HArray1OfPnt.hxx>
#include <TopExp.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopoDS.hxx>
#include <gp_Vec.hxx>
#include <cmath>
#include <cstdio>

static Handle(TColgp_HArray1OfPnt) pts(const double (*p)[3], int n)
{
  Handle(TColgp_HArray1OfPnt) a = new TColgp_HArray1OfPnt(1, n);
  for (int i = 0; i < n; i++)
    a->SetValue(i + 1, gp_Pnt(p[i][0], p[i][1], p[i][2]));
  return a;
}

static void describe(const char* theLabel, const Handle(Geom_BSplineCurve)& c)
{
  const double u0 = c->FirstParameter(), u1 = c->LastParameter();
  gp_Pnt       p0, p1;
  gp_Vec       v0, v1;
  c->D1(u0, p0, v0);
  c->D1(u1, p1, v1);
  v0.Normalize();
  v1.Normalize();
  std::printf("%s: domain [%.12g, %.12g] periodic=%d closed=%d\n",
              theLabel, u0, u1, c->IsPeriodic() ? 1 : 0, c->IsClosed() ? 1 : 0);
  std::printf("  start (%.12g, %.12g, %.12g) unit tangent (%.12g, %.12g, %.12g)\n",
              p0.X(), p0.Y(), p0.Z(), v0.X(), v0.Y(), v0.Z());
  std::printf("  end   (%.12g, %.12g, %.12g) unit tangent (%.12g, %.12g, %.12g)\n",
              p1.X(), p1.Y(), p1.Z(), v1.X(), v1.Y(), v1.Z());
}

int main()
{
  const double three[3][3] = {{0, 0, 0}, {5, 5, 0}, {10, 0, 0}};

  std::printf("== InterpolationExpansion3DTests ==\n");
  {
    GeomAPI_Interpolate it(pts(three, 3), Standard_False, 1e-6);
    it.Load(gp_Vec(1, 1, 0), gp_Vec(1, -1, 0));
    it.Perform();
    describe("interpolateWithEndpointTangents", it.Curve());
    GeomAPI_Interpolate plain(pts(three, 3), Standard_False, 1e-6);
    plain.Perform();
    describe("  (same points, no tangents loaded)", plain.Curve());
  }
  {
    GeomAPI_Interpolate               it(pts(three, 3), Standard_False, 1e-6);
    NCollection_Array1<gp_Vec>        tans(1, 3);
    Handle(NCollection_HArray1<bool>) flags = new NCollection_HArray1<bool>(1, 3);
    tans.SetValue(1, gp_Vec(1, 1, 0));
    tans.SetValue(2, gp_Vec(1, 0, 0));
    tans.SetValue(3, gp_Vec(1, -1, 0));
    flags->SetValue(1, true);
    flags->SetValue(2, false);
    flags->SetValue(3, true);
    it.Load(tans, flags);
    it.Perform();
    describe("interpolateWithAllTangents", it.Curve());
  }
  {
    Handle(TColStd_HArray1OfReal) params = new TColStd_HArray1OfReal(1, 3);
    params->SetValue(1, 0.0);
    params->SetValue(2, 0.5);
    params->SetValue(3, 1.0);
    GeomAPI_Interpolate it(pts(three, 3), params, Standard_False, 1e-6);
    it.Perform();
    describe("interpolateWithParameters", it.Curve());
    gp_Pnt mid = it.Curve()->Value(0.5);
    std::printf("  point at 0.5 (%.12g, %.12g, %.12g)\n", mid.X(), mid.Y(), mid.Z());
  }
  {
    const double square[4][3] = {{0, 0, 0}, {10, 0, 0}, {10, 10, 0}, {0, 10, 0}};
    GeomAPI_Interpolate it(pts(square, 4), Standard_True, 1e-6);
    it.Perform();
    describe("interpolatePeriodic", it.Curve());
  }

  std::printf("== SketchBuildProfileTests ==\n");
  {
    BRepBuilderAPI_MakePolygon poly;
    poly.Add(gp_Pnt(0, 0, 0));
    poly.Add(gp_Pnt(10, 0, 0));
    poly.Add(gp_Pnt(10, 10, 0));
    poly.Add(gp_Pnt(0, 10, 0));
    poly.Close();
    GProp_GProps g;
    BRepGProp::LinearProperties(poly.Wire(), g);
    std::printf("closed 10x10 square polygon: IsDone=%d length=%.12g\n",
                poly.IsDone() ? 1 : 0, g.Mass());
    BRepBuilderAPI_MakePolygon withDiag;
    withDiag.Add(gp_Pnt(0, 0, 0));
    withDiag.Add(gp_Pnt(10, 0, 0));
    withDiag.Add(gp_Pnt(10, 10, 0));
    withDiag.Add(gp_Pnt(0, 10, 0));
    withDiag.Add(gp_Pnt(0, 0, 0));
    withDiag.Add(gp_Pnt(10, 10, 0));
    GProp_GProps g2;
    BRepGProp::LinearProperties(withDiag.Wire(), g2);
    std::printf("the same polygon with the construction diagonal left in: length=%.12g\n",
                g2.Mass());
  }

  std::printf("== AngleHelperTests ==\n");
  {
    TopoDS_Shape               box = BRepPrimAPI_MakeBox(gp_Pnt(-5, -5, -5), 10, 10, 10).Shape();
    TopTools_IndexedMapOfShape edges, faces;
    TopExp::MapShapes(box, TopAbs_EDGE, edges);
    TopExp::MapShapes(box, TopAbs_FACE, faces);
    BRepAdaptor_Curve c1(TopoDS::Edge(edges(1))), c2(TopoDS::Edge(edges(2)));
    gp_Pnt            p;
    gp_Vec            t1, t2;
    c1.D1(0.5 * (c1.FirstParameter() + c1.LastParameter()), p, t1);
    c2.D1(0.5 * (c2.FirstParameter() + c2.LastParameter()), p, t2);
    std::printf("edges 1 and 2 (TopExp order): gp_Vec::Angle = %.12g\n", t1.Angle(t2));
    int n0 = 0, n90 = 0, n180 = 0, other = 0;
    for (int i = 1; i <= faces.Extent(); i++)
      for (int j = i + 1; j <= faces.Extent(); j++)
      {
        TopoDS_Face fi = TopoDS::Face(faces(i)), fj = TopoDS::Face(faces(j));
        double      ui0, ui1, vi0, vi1, uj0, uj1, vj0, vj1;
        BRepTools::UVBounds(fi, ui0, ui1, vi0, vi1);
        BRepTools::UVBounds(fj, uj0, uj1, vj0, vj1);
        BRepAdaptor_Surface si(fi), sj(fj);
        BRepLProp_SLProps   li(si, 0.5 * (ui0 + ui1), 0.5 * (vi0 + vi1), 1, 1e-9);
        BRepLProp_SLProps   lj(sj, 0.5 * (uj0 + uj1), 0.5 * (vj0 + vj1), 1, 1e-9);
        gp_Dir              ni = li.Normal(), nj = lj.Normal();
        if (fi.Orientation() == TopAbs_REVERSED)
          ni.Reverse();
        if (fj.Orientation() == TopAbs_REVERSED)
          nj.Reverse();
        double a = ni.Angle(nj);
        if (a < 1e-3)
          n0++;
        else if (std::fabs(a - M_PI) < 1e-3)
          n180++;
        else if (std::fabs(a - M_PI / 2) < 1e-3)
          n90++;
        else
          other++;
      }
    std::printf("box face pairs by normal angle: 0:%d  pi/2:%d  pi:%d  other:%d\n",
                n0, n90, n180, other);
    std::printf("gp_Vec(1,0,0).Angle(gp_Vec(2,0,0))  = %.17g\n",
                gp_Vec(1, 0, 0).Angle(gp_Vec(2, 0, 0)));
    std::printf("gp_Vec(1,0,0).Angle(gp_Vec(-1,0,0)) = %.17g\n",
                gp_Vec(1, 0, 0).Angle(gp_Vec(-1, 0, 0)));
    try
    {
      double a = gp_Vec(0, 0, 0).Angle(gp_Vec(1, 0, 0));
      std::printf("gp_Vec(0,0,0).Angle(...) = %.17g (no throw)\n", a);
    }
    catch (const Standard_Failure& e)
    {
      std::printf("gp_Vec(0,0,0).Angle(...) throws %s: %s\n", e.ExceptionType(), e.what());
    }
    std::printf("gp_Dir(1,0,0).Angle(gp_Dir(0,1,0)) = %.17g\n",
                gp_Dir(1, 0, 0).Angle(gp_Dir(0, 1, 0)));
    std::printf("gp_Dir(0,0,1).Angle(gp_Dir(0,1,0)) = %.17g\n",
                gp_Dir(0, 0, 1).Angle(gp_Dir(0, 1, 0)));
  }
  return 0;
}
