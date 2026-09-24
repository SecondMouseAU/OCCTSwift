// Epic #766, GeomFill{Profiler,SectionPlacement,Stretch,Sweep}Tests.swift: kernel parity.
//  - GeomFill_Profiler: AddCurve x2 (circles r5 z0 and r3 z10, or r4 z5), Perform(1e-6), Degree,
//    NbPoles, NbKnots, Poles(1), KnotsAndMults (OCCTGeomFillProfiler*)
//  - GeomFill_SectionPlacement(GeomFill_LocationDraft(+Z, 0) on the X axis [0, 10], circle r2
//    normal +X at the origin), Perform(1e-3) (OCCTGeomFillSectionPlacement)
//  - GeomFill_Stretch on the two fixtures' point rows (OCCTGeomFillStretch)
//  - GeomFill_Sweep(GeomFill_CurveAndTrihedron(GeomFill_CorrectedFrenet)) of a circle r3 along
//    the Z segment [0, 20], SetTolerance(1e-4), Build(UniformSection, GeomFill_Location, C2, 10, 50),
//    ErrorOnSurface and the face area, and the oscillating-spine #597 case (OCCTGeomFillSweep)
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepGProp.hxx>
#include <GProp_GProps.hxx>
#include <GeomAPI_Interpolate.hxx>
#include <GeomAdaptor_Curve.hxx>
#include <GeomFill_CorrectedFrenet.hxx>
#include <GeomFill_CurveAndTrihedron.hxx>
#include <GeomFill_LocationDraft.hxx>
#include <GeomFill_Profiler.hxx>
#include <GeomFill_SectionPlacement.hxx>
#include <GeomFill_Stretch.hxx>
#include <GeomFill_Sweep.hxx>
#include <GeomFill_UniformSection.hxx>
#include <Geom_Circle.hxx>
#include <Geom_Line.hxx>
#include <Geom_TrimmedCurve.hxx>
#include <NCollection_Array1.hxx>
#include <NCollection_Array2.hxx>
#include <TColgp_HArray1OfPnt.hxx>
#include <cmath>
#include <cstdio>
#include <TopoDS_Face.hxx>
#include <vector>

static Handle(Geom_Curve) circ(gp_Pnt c, gp_Dir n, double r)
{
  return new Geom_Circle(gp_Ax2(c, n), r);
}

static void profile(const char* tag, double r2, double z2)
{
  GeomFill_Profiler p;
  p.AddCurve(circ(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1), 5));
  p.AddCurve(circ(gp_Pnt(0, 0, z2), gp_Dir(0, 0, 1), r2));
  p.Perform(1e-6);
  printf("%s: Degree=%d NbPoles=%d NbKnots=%d", tag, p.Degree(), p.NbPoles(), p.NbKnots());
  NCollection_Array1<gp_Pnt> poles(1, p.NbPoles());
  p.Poles(1, poles);
  printf(" Poles(1)[1]=(%.12g, %.12g, %.12g) Poles(1)[2]=(%.12g, %.12g, %.12g)", poles(1).X(), poles(1).Y(), poles(1).Z(),
         poles(2).X(), poles(2).Y(), poles(2).Z());
  NCollection_Array1<double> k(1, p.NbKnots());
  NCollection_Array1<int>    m(1, p.NbKnots());
  p.KnotsAndMults(k, m);
  printf(" knots=");
  for (int i = 1; i <= p.NbKnots(); i++)
    printf("%.12g ", k(i));
  printf("mults=");
  for (int i = 1; i <= p.NbKnots(); i++)
    printf("%d ", m(i));
  printf("\n");
}

static void stretch(const char* tag, std::vector<gp_Pnt> a, std::vector<gp_Pnt> b, std::vector<gp_Pnt> c, std::vector<gp_Pnt> d)
{
  int                        n = (int)a.size();
  NCollection_Array1<gp_Pnt> P1(1, n), P2(1, n), P3(1, n), P4(1, n);
  for (int i = 0; i < n; i++)
  {
    P1(i + 1) = a[i];
    P2(i + 1) = b[i];
    P3(i + 1) = c[i];
    P4(i + 1) = d[i];
  }
  GeomFill_Stretch           s(P1, P2, P3, P4);
  NCollection_Array2<gp_Pnt> poles(1, s.NbUPoles(), 1, s.NbVPoles());
  s.Poles(poles);
  printf("%s: nbU=%d nbV=%d isRational=%d poles=", tag, s.NbUPoles(), s.NbVPoles(), s.isRational());
  for (int u = 1; u <= s.NbUPoles(); u++)
    for (int v = 1; v <= s.NbVPoles(); v++)
      printf("(%.12g,%.12g,%.12g)", poles(u, v).X(), poles(u, v).Y(), poles(u, v).Z());
  printf("\n");
}

static void sweep(const char* tag, Handle(Geom_Curve) path, double pf, double pl, double r)
{
  Handle(GeomAdaptor_Curve)          pa  = new GeomAdaptor_Curve(path, pf, pl);
  Handle(GeomFill_CorrectedFrenet)   tri = new GeomFill_CorrectedFrenet();
  Handle(GeomFill_CurveAndTrihedron) loc = new GeomFill_CurveAndTrihedron(tri);
  loc->SetCurve(pa);
  Handle(Geom_TrimmedCurve)       sec = new Geom_TrimmedCurve(circ(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1), r), 0, 2 * M_PI);
  Handle(GeomFill_UniformSection) law = new GeomFill_UniformSection(sec);
  GeomFill_Sweep                  sw(loc);
  sw.SetTolerance(1e-4);
  sw.Build(law, GeomFill_Location, GeomAbs_C2, 10, 50);
  printf("%s: IsDone=%d ErrorOnSurface=%.6g", tag, sw.IsDone(), sw.IsDone() ? sw.ErrorOnSurface() : -1.0);
  if (sw.IsDone())
  {
    GProp_GProps g;
    BRepGProp::SurfaceProperties(BRepBuilderAPI_MakeFace(sw.Surface(), 1e-6).Face(), g);
    printf(" faceArea=%.12g", g.Mass());
  }
  printf("\n");
}

int main()
{
  profile("profiler circles r5 z0 + r3 z10", 3, 10);
  profile("profiler circles r5 z0 + r4 z5", 4, 5);
  {
    Handle(GeomFill_LocationDraft) loc = new GeomFill_LocationDraft(gp_Dir(0, 0, 1), 0);
    loc->SetCurve(new GeomAdaptor_Curve(new Geom_TrimmedCurve(new Geom_Line(gp_Pnt(0, 0, 0), gp_Dir(1, 0, 0)), 0, 10)));
    GeomFill_SectionPlacement sp(loc, circ(gp_Pnt(0, 0, 0), gp_Dir(1, 0, 0), 2));
    sp.Perform(1e-3);
    printf("sectionPlacement: IsDone=%d ParameterOnPath=%.12g ParameterOnSection=%.12g Distance=%.12g Angle=%.12g\n", sp.IsDone(),
           sp.ParameterOnPath(), sp.ParameterOnSection(), sp.Distance(), sp.Angle());
  }
  stretch("stretchFill", {gp_Pnt(0, 0, 0), gp_Pnt(5, 0, 1), gp_Pnt(10, 0, 0)}, {gp_Pnt(10, 0, 0), gp_Pnt(10, 5, 2), gp_Pnt(10, 10, 0)},
          {gp_Pnt(10, 10, 0), gp_Pnt(5, 10, 1), gp_Pnt(0, 10, 0)}, {gp_Pnt(0, 10, 0), gp_Pnt(0, 5, 2), gp_Pnt(0, 0, 0)});
  stretch("isRational", {gp_Pnt(0, 0, 0), gp_Pnt(1, 0, 0)}, {gp_Pnt(1, 0, 0), gp_Pnt(1, 1, 0)}, {gp_Pnt(1, 1, 0), gp_Pnt(0, 1, 0)},
          {gp_Pnt(0, 1, 0), gp_Pnt(0, 0, 0)});
  sweep("sweepCircleAlongLine", new Geom_Line(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 0, 20, 3);
  {
    const int                   n   = 60;
    Handle(TColgp_HArray1OfPnt) pts = new TColgp_HArray1OfPnt(1, n);
    for (int i = 0; i < n; i++)
    {
      double t = (double)i / (n - 1) * 20.0 * M_PI;
      pts->SetValue(i + 1, gp_Pnt(t, 3.0 * std::sin(t * 5.0), 2.0 * std::cos(t * 7.0)));
    }
    GeomAPI_Interpolate in(pts, false, 1e-6);
    in.Perform();
    Handle(Geom_Curve) c = in.Curve();
    sweep("sweepRejectsOutOfToleranceFit (oscillating spine, circle r1)", c, c->FirstParameter(), c->LastParameter(), 1);
  }
  return 0;
}
