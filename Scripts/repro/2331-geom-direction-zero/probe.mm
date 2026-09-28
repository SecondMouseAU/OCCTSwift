// Ground truth for #2331: does Geom_Direction's zero-length guard fire in the pinned kernel?
//
// Geom_Direction.cxx's constructor and SetCoord both carry
//   Standard_ConstructionError_Raise_if(D <= gp::Resolution(), "... zero length")
// but both are out-of-line (Standard_EXPORT) and so compile into libOCCT with
// -DNo_Exception, which Scripts/build-occt.sh gets from CMAKE_BUILD_TYPE=Release plus
// BUILD_RELEASE_DISABLE_EXCEPTIONS=ON (occt_defs_flags.cmake:227). gp_Dir::SetCoord carries
// the identical macro but is inline, so it is compiled into THIS translation unit, which has
// no No_Exception. Each case runs in a forked child so an abort does not end the run.
//
// Build: see the ground-truth-probe skill; link against the resolved pinned xcframework.

#include <Geom_Direction.hxx>
#include <Geom_Vector.hxx>
#include <Precision.hxx>
#include <Standard_Failure.hxx>
#include <gp.hxx>
#include <gp_Dir.hxx>
#include <gp_XYZ.hxx>

#include <cmath>
#include <cstdio>
#include <limits>
#include <sys/wait.h>
#include <unistd.h>

static void runForked(const char* label, void (*body)())
{
  fflush(stdout);
  pid_t pid = fork();
  if (pid == 0)
  {
    printf("%-46s ", label);
    try
    {
      body();
    }
    catch (const Standard_Failure& e)
    {
      printf("Standard_Failure: %s\n",
             e.GetMessageString() ? e.GetMessageString() : "(no message)");
    }
    catch (...)
    {
      printf("unknown C++ exception\n");
    }
    fflush(stdout);
    _exit(0);
  }
  int status = 0;
  waitpid(pid, &status, 0);
  if (WIFSIGNALED(status))
    printf("  (child died on signal %d)\n", WTERMSIG(status));
}

static void printCoords(const gp_Dir& d)
{
  printf("no exception, coords=(%g, %g, %g)\n", d.X(), d.Y(), d.Z());
}

int main()
{
  printf("gp::Resolution() = %g\n\n", gp::Resolution());

  runForked("Geom_Direction(0, 0, 0)", [] {
    Handle(Geom_Direction) d = new Geom_Direction(0.0, 0.0, 0.0);
    printCoords(d->Dir());
  });

  runForked("gp_Dir(0, 0, 0)", [] {
    gp_Dir d(0.0, 0.0, 0.0);
    printCoords(d);
  });

  runForked("Geom_Direction(1,0,0)->SetCoord(0, 0, 0)", [] {
    Handle(Geom_Direction) d = new Geom_Direction(1.0, 0.0, 0.0);
    d->SetCoord(0.0, 0.0, 0.0);
    printCoords(d->Dir());
  });

  runForked("Geom_Direction(1e-200, 0, 0) sub-Resolution", [] {
    Handle(Geom_Direction) d = new Geom_Direction(1.0e-200, 0.0, 0.0);
    printCoords(d->Dir());
  });

  runForked("Geom_Direction(inf, 0, 0)", [] {
    Handle(Geom_Direction) d =
      new Geom_Direction(std::numeric_limits<double>::infinity(), 0.0, 0.0);
    printCoords(d->Dir());
  });

  runForked("Geom_Direction(nan, 0, 0)", [] {
    Handle(Geom_Direction) d =
      new Geom_Direction(std::numeric_limits<double>::quiet_NaN(), 0.0, 0.0);
    printCoords(d->Dir());
  });

  runForked("Geom_Direction(1,0,0)->Crossed(parallel)", [] {
    Handle(Geom_Direction) a     = new Geom_Direction(1.0, 0.0, 0.0);
    Handle(Geom_Direction) b     = new Geom_Direction(2.0, 0.0, 0.0);
    Handle(Geom_Vector)    cross = a->Crossed(b);
    if (cross.IsNull())
    {
      printf("Crossed returned a null handle\n");
      return;
    }
    gp_Vec v = cross->Vec();
    printf("no exception, non-null, vec=(%g, %g, %g)\n", v.X(), v.Y(), v.Z());
  });

  // The guard OCCT's own STEP importer applies before ever calling the constructor:
  // StepToGeom.cxx:1469-1479 (MakeDirection), "sln 22.10.2001. CTS23496: Direction is not
  // created if it has null magnitude" -> returns a null handle, no substituted direction.
  printf("\nOCCT's StepToGeom::MakeDirection guard, applied to the same inputs:\n");
  const double cases[][3] = {{0, 0, 0},
                             {1e-200, 0, 0},
                             {0, 0, 1},
                             {std::numeric_limits<double>::infinity(), 0, 0},
                             {std::numeric_limits<double>::quiet_NaN(), 0, 0}};
  for (const auto& c : cases)
  {
    bool infinite =
      Precision::IsInfinite(c[0]) || Precision::IsInfinite(c[1]) || Precision::IsInfinite(c[2]);
    bool accepted =
      !infinite && gp_XYZ(c[0], c[1], c[2]).SquareModulus() > gp::Resolution() * gp::Resolution();
    printf("  (%g, %g, %g) -> %s\n", c[0], c[1], c[2], accepted ? "constructed" : "null handle");
  }
  return 0;
}
