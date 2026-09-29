// #2801 sweep, "wrong kind of object" accessor cluster.
//
// Each mode exercises ONE OCCT accessor whose type/presence precondition is guarded by an
// <Exception>_Raise_if written in an OCCT .cxx, which the pinned kernel (built Release, so
// -DNo_Exception) compiled out. The question per mode is what the unguarded line then does:
// throw something live, hand back a fabricated value, or fault.
//
// Run one mode per process and record the exit code; 139 is SIGSEGV, 134 SIGABRT.
// Compile line and transcript: transcript.txt beside this file.

#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <exception>
#include <variant>

#include <Standard_Failure.hxx>
#include <Standard_NoSuchObject.hxx>

#include <Geom_Line.hxx>
#include <Geom_Circle.hxx>
#include <Geom_BSplineCurve.hxx>
#include <Geom_TrimmedCurve.hxx>
#include <Geom_OffsetCurve.hxx>
#include <Geom_Hyperbola.hxx>
#include <Geom_Plane.hxx>
#include <Geom_CylindricalSurface.hxx>
#include <Geom_RectangularTrimmedSurface.hxx>
#include <Geom2d_Line.hxx>
#include <Geom2d_TrimmedCurve.hxx>
#include <Geom2d_Hyperbola.hxx>
#include <Geom2d_BSplineCurve.hxx>
#include <Geom_BezierCurve.hxx>
#include <GeomAdaptor_Curve.hxx>
#include <GeomAdaptor_Surface.hxx>
#include <Geom2dAdaptor_Curve.hxx>
#include <Adaptor3d_CurveOnSurface.hxx>
#include <GeomPlate_BuildAveragePlane.hxx>
#include <BRepTools_Quilt.hxx>
#include <BRepTools_Substitution.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <TopTools_ListOfShape.hxx>
#include <NCollection_HArray1.hxx>
#include <gp_Pnt.hxx>

#define RUN(label, body)                                                                           \
  do                                                                                               \
  {                                                                                                \
    std::printf("%-46s ", label);                                                                   \
    std::fflush(stdout);                                                                            \
    try                                                                                            \
    {                                                                                              \
      body;                                                                                        \
    }                                                                                              \
    catch (const Standard_Failure& e)                                                              \
    {                                                                                              \
      std::printf("Standard_Failure(%s): %s\n",                                                    \
                  e.ExceptionType() ? e.ExceptionType() : "Standard_Failure",                                                         \
                  e.GetMessageString() ? e.GetMessageString() : "");                               \
    }                                                                                              \
    catch (const std::exception& e)                                                                \
    {                                                                                              \
      std::printf("std::exception(%s): %s\n", typeid(e).name(), e.what());                          \
    }                                                                                              \
    catch (...)                                                                                    \
    {                                                                                              \
      std::printf("unknown exception\n");                                                           \
    }                                                                                               \
    std::fflush(stdout);                                                                            \
  } while (0)

static Handle(Geom_BSplineCurve) makeNonPeriodicBSpline()
{
  NCollection_Array1<gp_Pnt> poles(1, 4);
  poles(1) = gp_Pnt(0, 0, 0);
  poles(2) = gp_Pnt(1, 2, 0);
  poles(3) = gp_Pnt(3, 2, 0);
  poles(4) = gp_Pnt(4, 0, 0);
  NCollection_Array1<double> knots(1, 2);
  knots(1) = 0.0;
  knots(2) = 1.0;
  NCollection_Array1<int> mults(1, 2);
  mults(1) = 4;
  mults(2) = 4;
  return new Geom_BSplineCurve(poles, knots, mults, 3, false);
}

int main(int argc, char** argv)
{
  const int mode = argc > 1 ? std::atoi(argv[1]) : 0;
  std::printf("== mode %d ==\n", mode);

  switch (mode)
  {
    case 1:
    { // Geom_Curve::Period() on non-periodic curves. Guard: .cxx Standard_NoSuchObject.
      Handle(Geom_Line) line = new Geom_Line(gp_Pnt(0, 0, 0), gp_Dir(1, 0, 0));
      RUN("Geom_Line.Period()", {
        std::printf("no throw, value=%g (IsPeriodic=%d)\n", line->Period(), (int)line->IsPeriodic());
      });
      Handle(Geom_BSplineCurve) bs = makeNonPeriodicBSpline();
      RUN("Geom_BSplineCurve(non-periodic).Period()", {
        std::printf("no throw, value=%g (IsPeriodic=%d, span=%g)\n",
                    bs->Period(),
                    (int)bs->IsPeriodic(),
                    bs->LastParameter() - bs->FirstParameter());
      });
      Handle(Geom_TrimmedCurve) tr = new Geom_TrimmedCurve(bs, 0.2, 0.7);
      RUN("Geom_TrimmedCurve(of non-periodic).Period()",
          { std::printf("no throw, value=%g\n", tr->Period()); });
      Handle(Geom2d_Line) l2d = new Geom2d_Line(gp_Pnt2d(0, 0), gp_Dir2d(1, 0));
      RUN("Geom2d_Line.Period()", { std::printf("no throw, value=%g\n", l2d->Period()); });
      break;
    }

    case 2:
    { // Geom_Surface::UPeriod()/VPeriod() on a non-periodic surface.
      Handle(Geom_Plane) pln = new Geom_Plane(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1));
      RUN("Geom_Plane.UPeriod()", { std::printf("no throw, value=%g\n", pln->UPeriod()); });
      RUN("Geom_Plane.VPeriod()", { std::printf("no throw, value=%g\n", pln->VPeriod()); });
      Handle(Geom_CylindricalSurface) cyl =
        new Geom_CylindricalSurface(gp_Ax3(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 5.0);
      RUN("Geom_CylindricalSurface.VPeriod() (V not periodic)",
          { std::printf("no throw, value=%g\n", cyl->VPeriod()); });
      Handle(Geom_RectangularTrimmedSurface) rts =
        new Geom_RectangularTrimmedSurface(pln, 0, 1, 0, 1, true, true);
      RUN("Geom_RectangularTrimmedSurface(plane).UPeriod()",
          { std::printf("no throw, value=%g\n", rts->UPeriod()); });
      Handle(GeomAdaptor_Surface) gas = new GeomAdaptor_Surface(pln);
      RUN("GeomAdaptor_Surface(plane).UPeriod()",
          { std::printf("no throw, value=%g\n", gas->UPeriod()); });
      break;
    }

    case 3:
    { // GeomAdaptor_Curve type accessors on the wrong type: std::get on a variant.
      Handle(Geom_Line) line = new Geom_Line(gp_Pnt(0, 0, 0), gp_Dir(1, 0, 0));
      GeomAdaptor_Curve ac(line, 0, 10);
      std::printf("GetType()=%d (GeomAbs_Line=%d)\n", (int)ac.GetType(), (int)GeomAbs_Line);
      RUN("GeomAdaptor_Curve(line).Circle()", {
        gp_Circ c = ac.Circle();
        std::printf("no throw, radius=%g\n", c.Radius());
      });
      RUN("GeomAdaptor_Curve(line).Ellipse()", {
        gp_Elips e = ac.Ellipse();
        std::printf("no throw, majorR=%g\n", e.MajorRadius());
      });
      RUN("GeomAdaptor_Curve(line).Hyperbola()", {
        gp_Hypr h = ac.Hyperbola();
        std::printf("no throw, majorR=%g\n", h.MajorRadius());
      });
      RUN("GeomAdaptor_Curve(line).Parabola()", {
        gp_Parab p = ac.Parabola();
        std::printf("no throw, focal=%g\n", p.Focal());
      });
      // LocalContinuity is PRIVATE in GeomAdaptor_Curve.hxx (8.0.1), so no caller outside the
      // class can reach it. Left here as a record of why this mode does not test it.
      break;
    }

    case 4:
    { // The mirror case: Line() on a circle-typed adaptor, and on a BSpline-typed one
      // (whose variant holds BSplineData, not gp_Lin).
      Handle(Geom_Circle) circ =
        new Geom_Circle(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 3.0);
      GeomAdaptor_Curve ac(circ);
      RUN("GeomAdaptor_Curve(circle).Line()", {
        gp_Lin l = ac.Line();
        std::printf("no throw, loc=(%g,%g,%g)\n",
                    l.Location().X(),
                    l.Location().Y(),
                    l.Location().Z());
      });
      GeomAdaptor_Curve ab(makeNonPeriodicBSpline());
      RUN("GeomAdaptor_Curve(bspline).Circle()", {
        gp_Circ c = ab.Circle();
        std::printf("no throw, radius=%g\n", c.Radius());
      });
      break;
    }

    case 5:
    { // Geom2dAdaptor_Curve, same shape in 2d.
      Handle(Geom2d_Line) l2d = new Geom2d_Line(gp_Pnt2d(0, 0), gp_Dir2d(1, 0));
      Geom2dAdaptor_Curve ac(l2d, 0, 10);
      RUN("Geom2dAdaptor_Curve(line).Circle()", {
        gp_Circ2d c = ac.Circle();
        std::printf("no throw, radius=%g\n", c.Radius());
      });
      // Geom2dAdaptor_Curve::LocalContinuity is private too.
      break;
    }

    case 6:
    { // Geom_Hyperbola / Geom2d_Hyperbola with majorRadius at or below the guard threshold.
      Handle(Geom_Hyperbola) h0 =
        new Geom_Hyperbola(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 0.0, 1.0);
      RUN("Geom_Hyperbola(a=0).Eccentricity()",
          { std::printf("no throw, value=%g\n", h0->Eccentricity()); });
      RUN("Geom_Hyperbola(a=0).Parameter()",
          { std::printf("no throw, value=%g\n", h0->Parameter()); });
      Handle(Geom2d_Hyperbola) h2 =
        new Geom2d_Hyperbola(gp_Ax22d(gp_Ax2d(gp_Pnt2d(0, 0), gp_Dir2d(1, 0))), 1e-300, 1.0);
      RUN("Geom2d_Hyperbola(a=1e-300).Eccentricity()",
          { std::printf("no throw, value=%g\n", h2->Eccentricity()); });
      RUN("Geom2d_Hyperbola(a=1e-300).Parameter()",
          { std::printf("no throw, value=%g\n", h2->Parameter()); });
      break;
    }

    case 7:
    { // IsCN(N) / IsCNu(N) / IsCNv(N) with a negative N: Standard_RangeError, .cxx.
      Handle(Geom_BSplineCurve) bs = makeNonPeriodicBSpline();
      Handle(Geom_TrimmedCurve) tr = new Geom_TrimmedCurve(bs, 0.2, 0.7);
      RUN("Geom_TrimmedCurve.IsCN(-1)", { std::printf("no throw, %d\n", (int)tr->IsCN(-1)); });
      RUN("Geom_BSplineCurve.IsCN(-1)", { std::printf("no throw, %d\n", (int)bs->IsCN(-1)); });
      RUN("Geom_BSplineCurve.IsCN(INT_MIN)",
          { std::printf("no throw, %d\n", (int)bs->IsCN(-2147483647 - 1)); });
      Handle(Geom_OffsetCurve) oc = new Geom_OffsetCurve(bs, 1.0, gp_Dir(0, 0, 1));
      RUN("Geom_OffsetCurve.IsCN(-1)", { std::printf("no throw, %d\n", (int)oc->IsCN(-1)); });
      Handle(Geom_Plane)                     pln = new Geom_Plane(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1));
      Handle(Geom_RectangularTrimmedSurface) rts =
        new Geom_RectangularTrimmedSurface(pln, 0, 1, 0, 1, true, true);
      RUN("Geom_RectangularTrimmedSurface.IsCNu(-1)",
          { std::printf("no throw, %d\n", (int)rts->IsCNu(-1)); });
      Handle(Geom2d_Line)       l2d = new Geom2d_Line(gp_Pnt2d(0, 0), gp_Dir2d(1, 0));
      Handle(Geom2d_TrimmedCurve) t2 = new Geom2d_TrimmedCurve(l2d, 0, 1);
      RUN("Geom2d_TrimmedCurve.IsCN(-1)", { std::printf("no throw, %d\n", (int)t2->IsCN(-1)); });
      break;
    }

    case 8:
    { // Adaptor3d_CurveOnSurface::BSpline()/Bezier() on a NON-planar support surface, and
      // Line()/Circle() on a curve-on-surface whose type is not that.
      Handle(Geom_CylindricalSurface) cyl =
        new Geom_CylindricalSurface(gp_Ax3(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 5.0);
      Handle(Geom2d_Line)         l2d = new Geom2d_Line(gp_Pnt2d(0, 0), gp_Dir2d(1, 0));
      Handle(Geom2dAdaptor_Curve) ac2 = new Geom2dAdaptor_Curve(l2d, 0, 1);
      Handle(GeomAdaptor_Surface) as  = new GeomAdaptor_Surface(cyl);
      Adaptor3d_CurveOnSurface    cos(ac2, as);
      std::printf("GetType()=%d\n", (int)cos.GetType());
      RUN("Adaptor3d_CurveOnSurface(on cylinder).BSpline()", {
        Handle(Geom_BSplineCurve) b = cos.BSpline();
        std::printf("no throw, null=%d\n", (int)b.IsNull());
      });
      RUN("Adaptor3d_CurveOnSurface(on cylinder).Bezier()", {
        Handle(Geom_BezierCurve) b = cos.Bezier();
        std::printf("no throw, null=%d\n", (int)b.IsNull());
      });
      RUN("Adaptor3d_CurveOnSurface.Circle() (not a circle)", {
        gp_Circ c = cos.Circle();
        std::printf("no throw, radius=%g\n", c.Radius());
      });
      RUN("Adaptor3d_CurveOnSurface.Line() (not a line)", {
        gp_Lin l = cos.Line();
        std::printf("no throw, loc=(%g,%g,%g)\n",
                    l.Location().X(),
                    l.Location().Y(),
                    l.Location().Z());
      });
      break;
    }

    case 9:
    { // BRepTools_Quilt::Copy on a shape it never copied, and on an empty quilt.
      TopoDS_Shape    box = BRepPrimAPI_MakeBox(10, 10, 10).Shape();
      TopExp_Explorer ex(box, TopAbs_FACE);
      TopoDS_Face     f1 = TopoDS::Face(ex.Current());
      ex.Next();
      TopoDS_Face f2 = TopoDS::Face(ex.Current());

      BRepTools_Quilt empty;
      RUN("BRepTools_Quilt(empty).Copy(face)", {
        const TopoDS_Shape& s = empty.Copy(f1);
        std::printf("no throw, IsNull=%d\n", (int)s.IsNull());
      });
      BRepTools_Quilt q;
      q.Add(f1);
      RUN("BRepTools_Quilt(has f1).Copy(f2)", {
        const TopoDS_Shape& s = q.Copy(f2);
        std::printf("no throw, IsNull=%d\n", (int)s.IsNull());
      });
      break;
    }

    case 10:
    { // BRepTools_Substitution::Copy on an unsubstituted shape; Substitute twice.
      TopoDS_Shape    box = BRepPrimAPI_MakeBox(10, 10, 10).Shape();
      TopExp_Explorer ex(box, TopAbs_FACE);
      TopoDS_Face     f1 = TopoDS::Face(ex.Current());
      ex.Next();
      TopoDS_Face f2 = TopoDS::Face(ex.Current());

      BRepTools_Substitution sub;
      RUN("BRepTools_Substitution(empty).Copy(face)", {
        const TopTools_ListOfShape& l = sub.Copy(f1);
        std::printf("no throw, size=%d\n", (int)l.Size());
      });
      TopTools_ListOfShape repl;
      repl.Append(f2);
      sub.Substitute(f1, repl);
      RUN("BRepTools_Substitution.Substitute(same key twice)", {
        TopTools_ListOfShape again;
        again.Append(f2);
        sub.Substitute(f1, again);
        std::printf("no throw (silently rebound)\n");
      });
      RUN("BRepTools_Substitution.Copy(f2) (not a key)", {
        const TopTools_ListOfShape& l = sub.Copy(f2);
        std::printf("no throw, size=%d\n", (int)l.Size());
      });
      break;
    }

    case 11:
    { // GeomPlate_BuildAveragePlane::Plane()/Line() when the corresponding predicate is false.
      Handle(NCollection_HArray1<gp_Pnt>) pts = new NCollection_HArray1<gp_Pnt>(1, 3);
      // Three collinear points: the average "plane" is a line.
      pts->SetValue(1, gp_Pnt(0, 0, 0));
      pts->SetValue(2, gp_Pnt(1, 0, 0));
      pts->SetValue(3, gp_Pnt(2, 0, 0));
      RUN("GeomPlate_BuildAveragePlane(collinear)", {
        GeomPlate_BuildAveragePlane bap(pts, 3, 0.001, 1, 1);
        std::printf("IsPlane=%d IsLine=%d ... ", (int)bap.IsPlane(), (int)bap.IsLine());
        Handle(Geom_Plane) p = bap.Plane();
        std::printf("Plane() no throw, null=%d ", (int)p.IsNull());
        Handle(Geom_Line) l = bap.Line();
        std::printf("Line() no throw, null=%d\n", (int)l.IsNull());
      });
      break;
    }

    case 12:
    { // Mode 8 split one call per process. 12 = BSpline on a cylinder (mode 8's faulting call).
      Handle(Geom_CylindricalSurface) cyl =
        new Geom_CylindricalSurface(gp_Ax3(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 5.0);
      Handle(Geom2d_Line)         l2d = new Geom2d_Line(gp_Pnt2d(0, 0), gp_Dir2d(1, 0));
      Handle(Geom2dAdaptor_Curve) ac2 = new Geom2dAdaptor_Curve(l2d, 0, 1);
      // Geom2dAdaptor_Curve::BSpline() has NO check at all: it returns a null handle when the
      // variant holds no BSplineData. That null is what Adaptor3d_CurveOnSurface dereferences.
      RUN("Geom2dAdaptor_Curve(line).BSpline() alone",
          { std::printf("no throw, null=%d\n", (int)ac2->BSpline().IsNull()); });
      Handle(GeomAdaptor_Surface) as = new GeomAdaptor_Surface(cyl);
      RUN("GeomAdaptor_Surface(cylinder).Plane() alone", {
        gp_Pln p = as->Plane();
        std::printf("no throw, loc=(%g,%g,%g)\n",
                    p.Location().X(),
                    p.Location().Y(),
                    p.Location().Z());
      });
      Adaptor3d_CurveOnSurface cos(ac2, as);
      std::printf("about to call Adaptor3d_CurveOnSurface::BSpline()\n");
      std::fflush(stdout);
      Handle(Geom_BSplineCurve) b = cos.BSpline();
      std::printf("returned, null=%d\n", (int)b.IsNull());
      break;
    }

    case 13:
    { // Bezier on a cylinder, alone.
      Handle(Geom_CylindricalSurface) cyl =
        new Geom_CylindricalSurface(gp_Ax3(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 5.0);
      Handle(Geom2d_Line)         l2d = new Geom2d_Line(gp_Pnt2d(0, 0), gp_Dir2d(1, 0));
      Handle(Geom2dAdaptor_Curve) ac2 = new Geom2dAdaptor_Curve(l2d, 0, 1);
      Handle(GeomAdaptor_Surface) as  = new GeomAdaptor_Surface(cyl);
      Adaptor3d_CurveOnSurface    cos(ac2, as);
      std::printf("about to call Adaptor3d_CurveOnSurface::Bezier()\n");
      std::fflush(stdout);
      Handle(Geom_BezierCurve) b = cos.Bezier();
      std::printf("returned, null=%d\n", (int)b.IsNull());
      break;
    }

    case 14:
    { // Circle()/Line() on a curve-on-surface whose myType is neither, alone each.
      Handle(Geom_CylindricalSurface) cyl =
        new Geom_CylindricalSurface(gp_Ax3(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 5.0);
      // A 2d BSpline pcurve on a cylinder gives myType == GeomAbs_OtherCurve.
      NCollection_Array1<gp_Pnt2d> poles(1, 4);
      poles(1) = gp_Pnt2d(0.0, 0.0);
      poles(2) = gp_Pnt2d(0.4, 1.0);
      poles(3) = gp_Pnt2d(0.8, 2.0);
      poles(4) = gp_Pnt2d(1.2, 3.0);
      NCollection_Array1<double> knots(1, 2);
      knots(1) = 0.0;
      knots(2) = 1.0;
      NCollection_Array1<int> mults(1, 2);
      mults(1) = 4;
      mults(2) = 4;
      Handle(Geom2d_BSplineCurve) bs2d = new Geom2d_BSplineCurve(poles, knots, mults, 3, false);
      Handle(Geom2dAdaptor_Curve) ac2  = new Geom2dAdaptor_Curve(bs2d, 0, 1);
      Handle(GeomAdaptor_Surface) as   = new GeomAdaptor_Surface(cyl);
      Adaptor3d_CurveOnSurface    cos(ac2, as);
      std::printf("GetType()=%d (OtherCurve=%d)\n", (int)cos.GetType(), (int)GeomAbs_OtherCurve);
      RUN("Adaptor3d_CurveOnSurface(other).Circle()", {
        gp_Circ c = cos.Circle();
        std::printf("no throw, radius=%g loc=(%g,%g,%g)\n",
                    c.Radius(),
                    c.Location().X(),
                    c.Location().Y(),
                    c.Location().Z());
      });
      RUN("Adaptor3d_CurveOnSurface(other).Line()", {
        gp_Lin l = cos.Line();
        std::printf("no throw, loc=(%g,%g,%g) dir=(%g,%g,%g)\n",
                    l.Location().X(),
                    l.Location().Y(),
                    l.Location().Z(),
                    l.Direction().X(),
                    l.Direction().Y(),
                    l.Direction().Z());
      });
      break;
    }

    case 15:
    { // The guard is INSUFFICIENT even when live: the surface IS a plane, so the compiled-out
      // _Raise_if would pass, and the pcurve is a line, so myCurve->BSpline() is still null.
      Handle(Geom_Plane)          pln = new Geom_Plane(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1));
      Handle(Geom2d_Line)         l2d = new Geom2d_Line(gp_Pnt2d(0, 0), gp_Dir2d(1, 0));
      Handle(Geom2dAdaptor_Curve) ac2 = new Geom2dAdaptor_Curve(l2d, 0, 1);
      Handle(GeomAdaptor_Surface) as  = new GeomAdaptor_Surface(pln);
      Adaptor3d_CurveOnSurface    cos(ac2, as);
      std::printf("surface type=%d (Plane=%d), curve type=%d\n",
                  (int)as->GetType(),
                  (int)GeomAbs_Plane,
                  (int)cos.GetType());
      std::printf("about to call BSpline() on a line-pcurve over a PLANE\n");
      std::fflush(stdout);
      Handle(Geom_BSplineCurve) b = cos.BSpline();
      std::printf("returned, null=%d\n", (int)b.IsNull());
      break;
    }

    default:
      std::printf("usage: probe <1..15>\n");
      return 2;
  }
  std::printf("== mode %d finished ==\n", mode);
  return 0;
}
