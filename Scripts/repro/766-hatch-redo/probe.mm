// Epic #766, HatchTests.swift: kernel parity for all five tests.
// HatchPattern.generate reaches OCCTHatchLines, which is a composition over Hatch_Hatcher: one
// AddLine(dir, dist) per spacing step across the perpendicular extent of boundary and islands,
// then Trim(p1, p2) for every boundary edge and every island edge, then Start/End per interval.
// This probe performs the same Hatch_Hatcher calls with the same inputs (unoriented mode,
// tolerance 1e-7) and prints what the kernel hands back.
#include <Hatch_Hatcher.hxx>
#include <cmath>
#include <cstdio>
#include <gp_Dir2d.hxx>
#include <gp_Lin2d.hxx>
#include <gp_Pnt2d.hxx>
#include <gp_Vec2d.hxx>
#include <vector>

struct P
{
  double x, y;
};

struct Seg
{
  double x1, y1, x2, y2;
};

static std::vector<Seg> hatch(const std::vector<P>&              boundary,
                              const std::vector<std::vector<P>>& islands,
                              double                             dx,
                              double                             dy,
                              double                             spacing)
{
  std::vector<Seg> out;
  Hatch_Hatcher    h(1.0e-7, false);
  double           len = std::sqrt(dx * dx + dy * dy);
  double           ndx = dx / len, ndy = dy / len, px = -ndy, py = ndx;
  double           lo = 1e30, hi = -1e30;
  auto             track = [&](const std::vector<P>& poly) {
    for (auto& p : poly)
    {
      double d = p.x * px + p.y * py;
      lo       = std::min(lo, d);
      hi       = std::max(hi, d);
    }
  };
  track(boundary);
  for (auto& isl : islands)
    track(isl);
  gp_Dir2d dir(ndx, ndy);
  for (double d = std::floor(lo / spacing) * spacing; d <= hi; d += spacing)
    h.AddLine(dir, d);
  auto trim = [&](const std::vector<P>& poly) {
    for (size_t i = 0; i < poly.size(); i++)
    {
      const P& a = poly[i];
      const P& b = poly[(i + 1) % poly.size()];
      h.Trim(gp_Pnt2d(a.x, a.y), gp_Pnt2d(b.x, b.y));
    }
  };
  trim(boundary);
  for (auto& isl : islands)
    trim(isl);
  for (int l = 1; l <= h.NbLines(); l++)
    for (int k = 1; k <= h.NbIntervals(l); k++)
    {
      const gp_Lin2d& line = h.Line(l);
      gp_Pnt2d a = line.Location().Translated(gp_Vec2d(line.Direction()) * h.Start(l, k));
      gp_Pnt2d b = line.Location().Translated(gp_Vec2d(line.Direction()) * h.End(l, k));
      out.push_back({a.X(), a.Y(), b.X(), b.Y()});
    }
  return out;
}

static void report(const char* tag, const std::vector<Seg>& s)
{
  double total = 0;
  for (auto& g : s)
    total += std::hypot(g.x2 - g.x1, g.y2 - g.y1);
  printf("%s: segments=%zu totalLength=%.17g\n", tag, s.size(), total);
}

int main()
{
  std::vector<P> square = {{0, 0}, {10, 0}, {10, 10}, {0, 10}};
  report("horizontalHatch", hatch(square, {}, 1, 0, 2.0));
  report("diagonalHatch", hatch(square, {}, 1, 1, 1.5));
  // emptyBoundary: HatchPattern.generate returns [] before any kernel call (boundary.count < 3,
  // and OCCTHatchLines repeats that guard). With no guard at all, an empty boundary gives an
  // empty perpendicular extent, so no line is added: the kernel's own answer is also nothing.
  report("emptyBoundary (unguarded kernel path)", hatch({}, {}, 1, 0, 1.0));
  // The island variant added to the test: with the guards gone, an island alone sets the
  // extent, lines are added, and the island's own edges trim them into its interior.
  report("emptyBoundary + island (unguarded kernel path)",
         hatch({}, {{{7, 7}, {13, 7}, {13, 13}, {7, 13}}}, 1, 0, 2.0));
  report("triangleBoundary", hatch({{0, 0}, {10, 0}, {5, 10}}, {}, 1, 0, 1.0));
  {
    std::vector<P> outer  = {{0, 0}, {20, 0}, {20, 20}, {0, 20}};
    std::vector<P> island = {{7, 7}, {13, 7}, {13, 13}, {7, 13}};
    auto           s      = hatch(outer, {island}, 1, 0, 2.0);
    report("islandsCutHoles", s);
    for (auto& g : s)
      if (std::fabs(g.y1 - 10) < 1e-6 && std::fabs(g.y2 - 10) < 1e-6)
        printf("  y=10 segment: (%.17g, %.17g) -> (%.17g, %.17g)\n", g.x1, g.y1, g.x2, g.y2);
    report("islandsCutHoles without island trim", hatch(outer, {}, 1, 0, 2.0));
  }
  return 0;
}
