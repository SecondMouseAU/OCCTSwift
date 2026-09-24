// Epic #766, Tests/OCCTAnalysisTests/HatchBuilderTests.swift: kernel parity probe.
// OCCTHatcher* wraps Hatch_Hatcher(tol, /*Oriented=*/false); this probe builds the same.
#include <Hatch_Hatcher.hxx>
#include <gp_Pnt2d.hxx>
#include <cstdio>

static void dumpIntervals(const char* name, const Hatch_Hatcher& h)
{
  printf("%s NbLines=%d\n", name, h.NbLines());
  for (int i = 1; i <= h.NbLines(); ++i)
  {
    printf("  line %d coord=%g NbIntervals=%d", i, h.Coordinate(i), h.NbIntervals(i));
    for (int j = 1; j <= h.NbIntervals(i); ++j)
      printf(" [%g, %g]", h.Start(i, j), h.End(i, j));
    printf("\n");
  }
}

int main()
{
  {
    Hatch_Hatcher h(1e-6, false);
    printf("createHatcher constructed tolerance=%g\n", h.Tolerance());
  }
  {
    Hatch_Hatcher h(1e-6, false);
    h.AddXLine(0.0);
    h.AddXLine(5.0);
    h.AddXLine(10.0);
    dumpIntervals("addLinesAndCount", h);
  }
  {
    Hatch_Hatcher h(1e-6, false);
    h.AddYLine(0.0);
    h.AddYLine(5.0);
    dumpIntervals("addYLines", h);
  }
  {
    // The test's original trim: one diagonal segment from (-1,-1) to (11,11).
    Hatch_Hatcher h(1e-6, false);
    h.AddXLine(0.0);
    h.AddXLine(5.0);
    h.AddXLine(10.0);
    h.Trim(gp_Pnt2d(-1, -1), gp_Pnt2d(11, 11));
    dumpIntervals("trimAndIntervals diagonal segment", h);
  }
  {
    // A closed square (-1,-1)..(11,11), trimmed as four segments.
    Hatch_Hatcher h(1e-6, false);
    h.AddXLine(0.0);
    h.AddXLine(5.0);
    h.AddXLine(10.0);
    h.Trim(gp_Pnt2d(-1, -1), gp_Pnt2d(11, -1));
    h.Trim(gp_Pnt2d(11, -1), gp_Pnt2d(11, 11));
    h.Trim(gp_Pnt2d(11, 11), gp_Pnt2d(-1, 11));
    h.Trim(gp_Pnt2d(-1, 11), gp_Pnt2d(-1, -1));
    dumpIntervals("trimAndIntervals closed square", h);
  }
  {
    Hatch_Hatcher h(1e-6, false);
    h.AddXLine(0.0);
    h.AddXLine(5.0);
    h.AddXLine(10.0);
    dumpIntervals("untrimmed", h);
  }
  return 0;
}
