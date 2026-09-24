// Kernel-parity probe for Tests/OCCTAnalysisTests/HatchTests.swift (#1702 Triangle boundary,
// #1703 island hole). Drives Hatch_Hatcher(1e-7, false) through the same AddLine/Trim sequence
// OCCTHatchLines issues: lines along the normalised direction at distances
// floor((min - offset) / spacing) * spacing + offset ... max, measured along the perpendicular
// (-dy, dx); then Trim() against every boundary edge and every island edge.
#include <Hatch_Hatcher.hxx>
#include <gp_Dir2d.hxx>
#include <gp_Lin2d.hxx>
#include <gp_Pnt2d.hxx>
#include <gp_Vec2d.hxx>
#include <cmath>
#include <cstdio>
#include <vector>

typedef std::vector<std::vector<double>> Polys; // each polygon: x0,y0,x1,y1,...

static void run(const char* tag, const Polys& polys, double dirX, double dirY, double spacing)
{
  Hatch_Hatcher h(1.0e-7, false);
  double        len = std::sqrt(dirX * dirX + dirY * dirY);
  double        ndx = dirX / len, ndy = dirY / len;
  double        perpX = -ndy, perpY = ndx;
  double        minD = 1e30, maxD = -1e30;
  for (const auto& p : polys)
    for (size_t i = 0; i < p.size() / 2; i++)
    {
      double d = p[2 * i] * perpX + p[2 * i + 1] * perpY;
      minD     = std::fmin(minD, d);
      maxD     = std::fmax(maxD, d);
    }
  gp_Dir2d dir(ndx, ndy);
  for (double d = std::floor(minD / spacing) * spacing; d <= maxD; d += spacing)
    h.AddLine(dir, d);
  for (const auto& p : polys)
  {
    size_t n = p.size() / 2;
    for (size_t i = 0; i < n; i++)
    {
      size_t j = (i + 1) % n;
      h.Trim(gp_Pnt2d(p[2 * i], p[2 * i + 1]), gp_Pnt2d(p[2 * j], p[2 * j + 1]));
    }
  }
  int count = 0;
  for (int l = 1; l <= h.NbLines(); l++)
    for (int k = 1; k <= h.NbIntervals(l); k++)
    {
      const gp_Lin2d& line = h.Line(l);
      gp_Pnt2d a = line.Location().Translated(gp_Vec2d(line.Direction()) * h.Start(l, k));
      gp_Pnt2d b = line.Location().Translated(gp_Vec2d(line.Direction()) * h.End(l, k));
      printf("%s seg %d (line %d): (%.17g, %.17g) -> (%.17g, %.17g)\n", tag, count, l, a.X(),
             a.Y(), b.X(), b.Y());
      count++;
    }
  printf("%s: NbLines=%d segments=%d\n", tag, h.NbLines(), count);
}

int main()
{
  run("triangleBoundary", {{0, 0, 10, 0, 5, 10}}, 1, 0, 1.0);
  run("islandsCutHoles", {{0, 0, 20, 0, 20, 20, 0, 20}, {7, 7, 13, 7, 13, 13, 7, 13}}, 1, 0, 2.0);
  return 0;
}
