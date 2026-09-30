// #766 kernel parity for Tests/OCCTAnalysisTests/BndBoundSortBoxTests.swift: Bnd_BoundSortBox
// initialised as OCCTBoundSortBoxCreate does (box i at array position i + 1, enclosing box of all)
// and queried with Compare(Bnd_Box), the list OCCTBoundSortBoxCompare translates to 0-based.
#include <Bnd_BoundSortBox.hxx>
#include <Bnd_Box.hxx>
#include <NCollection_HArray1.hxx>
#include <cstdio>
#include <vector>

static void run(const char* label, const std::vector<std::vector<double>>& boxes, double x0,
                double y0, double z0, double x1, double y1, double z1, bool listAll)
{
  occ::handle<NCollection_HArray1<Bnd_Box>> arr =
    new NCollection_HArray1<Bnd_Box>(1, (int)boxes.size());
  Bnd_Box enclosing;
  for (size_t i = 0; i < boxes.size(); ++i)
  {
    Bnd_Box b;
    b.Update(boxes[i][0], boxes[i][1], boxes[i][2], boxes[i][3], boxes[i][4], boxes[i][5]);
    arr->SetValue((int)i + 1, b);
    enclosing.Add(b);
  }
  Bnd_BoundSortBox sorter;
  sorter.Initialize(enclosing, arr);
  Bnd_Box q;
  q.Update(x0, y0, z0, x1, y1, z1);
  const auto& r = sorter.Compare(q);
  int         n = 0;
  int         lo = 1 << 30, hi = -1;
  printf("%s: OCCT indices (1-based) =", label);
  for (auto it = r.cbegin(); it != r.cend(); ++it, ++n)
  {
    if (listAll)
      printf(" %d", *it);
    lo = std::min(lo, *it);
    hi = std::max(hi, *it);
  }
  printf(" count=%d", n);
  if (n)
    printf(" min=%d max=%d", lo, hi);
  printf("\n");
}

int main()
{
  run("compareOverlapping", {{0, 0, 0, 10, 10, 10}, {50, 50, 50, 60, 60, 60}, {5, 5, 5, 15, 15, 15}},
      8, 8, 8, 12, 12, 12, true);
  run("compareNonOverlapping", {{0, 0, 0, 10, 10, 10}}, 90, 90, 90, 95, 95, 95, true);
  run("bridgeFunctionReturnsZeroBasedIndex", {{0, 0, 0, 10, 10, 10}}, 5, 5, 5, 6, 6, 6, true);
  std::vector<std::vector<double>> five;
  for (int i = 0; i < 5; ++i)
  {
    double o = i * 0.1;
    five.push_back({o, o, o, o + 10, o + 10, o + 10});
  }
  run("sizingQuery / fillCall (5 staggered boxes)", five, 2, 2, 2, 3, 3, 3, true);
  std::vector<std::vector<double>> many;
  for (int i = 0; i < 1200; ++i)
  {
    double o = i * 0.001;
    many.push_back({o, o, o, o + 10, o + 10, o + 10});
  }
  run("swiftWrapperNeverTruncates (1200 boxes)", many, 2, 2, 2, 3, 3, 3, false);
  return 0;
}
