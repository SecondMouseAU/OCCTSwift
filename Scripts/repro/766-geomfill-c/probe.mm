// Epic #766, GeomFill{GuideTrihedronAC,GuideTrihedronPlan,LocationDraft,NSections}Tests.swift:
// kernel parity. Same inputs, straight to the GeomFill classes the bridge wraps:
//  - GeomFill_GuideTrihedronAC / GuideTrihedronPlan on GeomAdaptor_Curve(guide), SetCurve(path),
//    D0(5) (OCCTGeomFillGuideTrihedron{AC,Plan}{Create,SetCurve,D0}); guide = the line through
//    (0, 5, 0) along X trimmed to [0, 10], path = the X axis trimmed to [0, 10]
//  - GeomFill_LocationDraft(+Z, angle), Direction(), SetCurve(path), SetAngle, D0(5)
//  - GeomFill_NSections(sections, params): ComputeSurface/BSplineSurface and SectionShape
#include <GeomAdaptor_Curve.hxx>
#include <GeomFill_GuideTrihedronAC.hxx>
#include <GeomFill_GuideTrihedronPlan.hxx>
#include <GeomFill_LocationDraft.hxx>
#include <GeomFill_NSections.hxx>
#include <Geom_BSplineSurface.hxx>
#include <Geom_Circle.hxx>
#include <Geom_Line.hxx>
#include <Geom_TrimmedCurve.hxx>
#include <NCollection_Sequence.hxx>
#include <cstdio>

static void frame(const char* tag, bool ok, const gp_Vec& t, const gp_Vec& n, const gp_Vec& b)
{
  printf("%s: ok=%d T=(%.12g, %.12g, %.12g) N=(%.12g, %.12g, %.12g) B=(%.12g, %.12g, %.12g)\n", tag, ok, t.X(), t.Y(),
         t.Z(), n.X(), n.Y(), n.Z(), b.X(), b.Y(), b.Z());
}

static void draft(const char* tag, GeomFill_LocationDraft& d)
{
  gp_Mat m;
  gp_Vec v;
  bool   ok = d.D0(5.0, m, v);
  printf("%s: ok=%d M=[", tag, ok);
  for (int r = 1; r <= 3; r++)
    for (int c = 1; c <= 3; c++)
      printf("%.12g%s", m.Value(r, c), (r == 3 && c == 3) ? "" : ", ");
  printf("] V=(%.12g, %.12g, %.12g)\n", v.X(), v.Y(), v.Z());
}

int main()
{
  Handle(Geom_TrimmedCurve) guide = new Geom_TrimmedCurve(new Geom_Line(gp_Pnt(0, 5, 0), gp_Dir(1, 0, 0)), 0, 10);
  Handle(Geom_TrimmedCurve) path  = new Geom_TrimmedCurve(new Geom_Line(gp_Pnt(0, 0, 0), gp_Dir(1, 0, 0)), 0, 10);
  gp_Vec                    t, n, b;
  {
    Handle(GeomFill_GuideTrihedronAC) ac = new GeomFill_GuideTrihedronAC(new GeomAdaptor_Curve(guide));
    bool                              sc = ac->SetCurve(new GeomAdaptor_Curve(path));
    bool                              ok = ac->D0(5.0, t, n, b);
    printf("guideTrihedronAC SetCurve=%d\n", sc);
    frame("guideTrihedronAC D0(5)", ok, t, n, b);
  }
  {
    Handle(GeomFill_GuideTrihedronPlan) pl = new GeomFill_GuideTrihedronPlan(new GeomAdaptor_Curve(guide));
    bool                                sc = pl->SetCurve(new GeomAdaptor_Curve(path));
    bool                                ok = pl->D0(5.0, t, n, b);
    printf("guideTrihedronPlan SetCurve=%d\n", sc);
    frame("guideTrihedronPlan D0(5)", ok, t, n, b);
  }
  {
    GeomFill_LocationDraft d1(gp_Dir(0, 0, 1), M_PI / 6);
    printf("locationDraft Direction=(%.12g, %.12g, %.12g)\n", d1.Direction().X(), d1.Direction().Y(), d1.Direction().Z());
    GeomFill_LocationDraft d2(gp_Dir(0, 0, 1), M_PI / 12);
    d2.SetCurve(new GeomAdaptor_Curve(path));
    draft("locationDraft angle pi/12 D0(5)", d2);
    GeomFill_LocationDraft d3(gp_Dir(0, 0, 1), M_PI / 6);
    d3.SetCurve(new GeomAdaptor_Curve(path));
    draft("locationDraft angle pi/6 D0(5)", d3);
    d3.SetAngle(M_PI / 4);
    d3.SetCurve(new GeomAdaptor_Curve(path));
    draft("locationDraft pi/6 then SetAngle(pi/4), SetCurve, D0(5)", d3);
    GeomFill_LocationDraft d5(gp_Dir(0, 0, 1), M_PI / 6);
    d5.SetCurve(new GeomAdaptor_Curve(path));
    d5.SetAngle(M_PI / 4);
    draft("setAngle: pi/6, SetCurve, SetAngle(pi/4), D0(5) (the Swift test's order)", d5);
    GeomFill_LocationDraft d4(gp_Dir(0, 0, 1), M_PI / 6);
    d4.SetAngle(M_PI / 4);
    d4.SetCurve(new GeomAdaptor_Curve(path));
    draft("locationDraft pi/6, SetAngle(pi/4) before SetCurve, D0(5)", d4);
  }
  {
    auto circ = [](double z, double r) {
      return Handle(Geom_Curve)(new Geom_Circle(gp_Ax2(gp_Pnt(0, 0, z), gp_Dir(0, 0, 1)), r));
    };
    NCollection_Sequence<Handle(Geom_Curve)> s;
    NCollection_Sequence<double>             p;
    s.Append(circ(0, 5));
    s.Append(circ(3, 4));
    s.Append(circ(6, 3));
    p.Append(0.0);
    p.Append(0.5);
    p.Append(1.0);
    Handle(GeomFill_NSections) ns = new GeomFill_NSections(s, p);
    ns->ComputeSurface();
    Handle(Geom_BSplineSurface) bs = ns->BSplineSurface();
    double                      u1, u2, v1, v2;
    bs->Bounds(u1, u2, v1, v2);
    gp_Pnt a = bs->Value(u1, (v1 + v2) / 2), c = bs->Value(u1, v2);
    printf("surfaceFromCircleSections: bounds=[%.12g, %.12g]x[%.12g, %.12g] S(u1, vmid)=(%.12g, %.12g, %.12g) S(u1, v2)=(%.12g, %.12g, %.12g)\n",
           u1, u2, v1, v2, a.X(), a.Y(), a.Z(), c.X(), c.Y(), c.Z());
    NCollection_Sequence<Handle(Geom_Curve)> s2;
    NCollection_Sequence<double>             p2;
    s2.Append(circ(0, 5));
    s2.Append(circ(3, 4));
    p2.Append(0.0);
    p2.Append(1.0);
    Handle(GeomFill_NSections) ns2 = new GeomFill_NSections(s2, p2);
    int                        np, nk, dg;
    ns2->SectionShape(np, nk, dg);
    printf("sectionInfo: nbPoles=%d nbKnots=%d degree=%d\n", np, nk, dg);
  }
  return 0;
}
