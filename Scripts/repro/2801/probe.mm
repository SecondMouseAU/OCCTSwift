// #2801: which OCCT validity checks survive in the kernel this repo pins.
//
// The claim under test is not "No_Exception is defined", which is read off the cmake files. It is
// the consequence: an <Exception>_Raise_if in an OCCT .cxx is gone from libOCCT, one in an inline
// header body is live in the bridge's own unit and dead in every OCCT unit, and a class that
// delegates its documented check to an inline one from inside its own .cxx therefore cannot raise
// it at all.
//
// Build both ways; the second half of the answer is the difference between them.
//
//   clang++ -std=c++17 -ObjC++ -w \
//     -I"$XC/macos-arm64/Headers" -L"$XC/macos-arm64" \
//     -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
//     Scripts/repro/2801/probe.mm -o /tmp/probe_2801
//   clang++ ... -DNo_Exception ... -o /tmp/probe_2801_noexc
//
// The bridge is the first build: SwiftPM defines nothing of the sort for
// Sources/OCCTBridge/src/*.mm. The second is what every OCCT translation unit was compiled as.

#include <BRepPrimAPI_MakeHalfSpace.hxx>
#include <BRep_Builder.hxx>
#include <GC_MakeSegment2d.hxx>
#include <Geom_Direction.hxx>
#include <Standard_Failure.hxx>
#include <TopoDS_Shell.hxx>
#include <gp_Ax2.hxx>
#include <gp_Dir.hxx>
#include <gp_Pnt.hxx>
#include <gp_Pnt2d.hxx>

#include <cmath>
#include <cstdio>
#include <string>

static int failures = 0;

static void report(const char* name, const char* expected, const char* got)
{
  bool ok = std::string(expected) == got;
  if (!ok)
    failures++;
  printf("[%s] %-46s expected %-18s got %s\n", ok ? "PASS" : "FAIL", name, expected, got);
}

int main()
{
#ifdef No_Exception
  printf("built WITH -DNo_Exception: this is how every OCCT translation unit was compiled\n\n");
#else
  printf("built WITHOUT -DNo_Exception: this is how SwiftPM compiles the bridge\n\n");
#endif

  // 1. gp_Dir's check is inline in gp_Dir.hxx, so it is compiled into whichever unit builds the
  //    direction. Live here, dead in any OCCT .cxx.
  {
    const char* got = "no-throw";
    try
    {
      gp_Dir  d(0.0, 0.0, 0.0);
      (void)d;
    }
    catch (const Standard_Failure&)
    {
      got = "threw";
    }
#ifdef No_Exception
    report("gp_Dir(0,0,0), inline check", "no-throw", got);
#else
    report("gp_Dir(0,0,0), inline check", "threw", got);
#endif
  }

  // 2. Geom_Direction carries the identical macro in an out-of-line Standard_EXPORT member, so it
  //    is compiled once into libOCCT with the macro empty. #2331's worked example.
  {
    const char* got = "no-throw";
    double      x   = 9.0;
    try
    {
      Handle(Geom_Direction) d = new Geom_Direction(0.0, 0.0, 0.0);
      x                        = d->Dir().X();
    }
    catch (const Standard_Failure&)
    {
      got = "threw";
    }
    report("Geom_Direction(0,0,0), out-of-line check", "no-throw", got);
    printf("       and its X() is %s\n", std::isnan(x) ? "nan" : "a number");
  }

  // 3. gp_Ax2 holds no _Raise_if of its own and documents "Raises ConstructionError if theN and
  //    theVx are parallel". gp_Ax2.cxx reaches that by building a gp_Dir from a cross product, so
  //    the inline check is expanded inside an OCCT unit and is gone. This is the case that makes
  //    "the check is inline" insufficient on its own.
  {
    const char* got = "no-throw";
    try
    {
      gp_Ax2 a(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1), gp_Dir(0, 0, 1));
      (void)a;
    }
    catch (const Standard_Failure&)
    {
      got = "threw";
    }
    report("gp_Ax2 with N parallel to Vx, delegated check", "no-throw", got);
  }

  // 4. Channel two of the census: an accessor whose only guard is an out-of-line
  //    StdFail_NotDone_Raise_if. A failed construction hands back its default-constructed member
  //    and the documented throw never happens, so a caller that does not test IsDone itself reads
  //    the failure as a result.
  {
    // An empty shell: BRepExtrema_DistShapeShape finds no solution, so the constructor's
    // FindExtrema returns false and IsDone stays false. Nothing else about the object changes.
    TopoDS_Shell empty;
    BRep_Builder().MakeShell(empty);
    BRepPrimAPI_MakeHalfSpace maker(empty, gp_Pnt(1.0, 1.0, 1.0));
    printf("       BRepPrimAPI_MakeHalfSpace.IsDone() is %s\n", maker.IsDone() ? "true" : "false");
    const char* got         = "no-throw";
    bool        isNullSolid = false;
    try
    {
      isNullSolid = maker.Solid().IsNull();
    }
    catch (const Standard_Failure&)
    {
      got = "threw";
    }
    report("MakeHalfSpace.Solid() when not done", "no-throw", got);
    printf("       and the solid it handed back %s\n",
           isNullSolid ? "is null, which reads as a shape to a caller that did not test IsDone"
                       : "is not null (or was not read)");
  }

  // 5. The same shape one layer up, in the family the bridge uses most: GC_MakeSegment2d's Value()
  //    carries the identical out-of-line StdFail_NotDone_Raise_if.
  {
    GC_MakeSegment2d maker(gp_Pnt2d(1.0, 1.0), gp_Pnt2d(1.0, 1.0));  // coincident: gce_ConfusedPoints
    printf("       GC_MakeSegment2d.IsDone() is %s\n", maker.IsDone() ? "true" : "false");
    const char* got        = "no-throw";
    bool        isNullCurve = false;
    try
    {
      isNullCurve = maker.Value().IsNull();
    }
    catch (const Standard_Failure&)
    {
      got = "threw";
    }
    report("GC_MakeSegment2d.Value() when not done", "no-throw", got);
    printf("       and the curve it handed back %s\n", isNullCurve ? "is a null Handle"
                                                                   : "is not null");
  }

  printf("\n%s\n", failures ? "FAILURES above" : "every expectation held");
  return failures ? 1 : 0;
}
