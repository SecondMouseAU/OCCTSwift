// #3065: what does the BSpline adaptor cache do when one adaptor is shared across threads,
// and what does it cost to lock it? Pure C++ against OCCT, no Swift or bridge.
//
//   adaptor_contract race <mode> <threads> <iters>   mode: shared | copy
//   adaptor_contract perf <mode> <threads> <iters>   mode: hot | alt | sharedhot | sharedalt
//
// race: every thread alternates D0 between span 0 and span 2 of a three-span cubic, so every
//   evaluation forces a cache rebuild, and compares each point with Geom_BSplineCurve::D0,
//   which does not go through an adaptor cache. Prints one line: wrong points, total points.
// perf: wall time for <iters> D0 calls per thread. hot = same span every call (cache hit),
//   alt = alternating spans (cache rebuild every call). The shared* modes use one adaptor for
//   all threads; the others give each thread its own ShallowCopy().
#include <atomic>
#include <chrono>
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <string>
#include <thread>
#include <vector>

#include <Geom_BSplineCurve.hxx>
#include <GeomAdaptor_Curve.hxx>
#include <TColgp_Array1OfPnt.hxx>
#include <TColStd_Array1OfInteger.hxx>
#include <TColStd_Array1OfReal.hxx>

static Handle(Geom_BSplineCurve) makeCurve() {
  TColgp_Array1OfPnt p(1, 6);
  p(1) = gp_Pnt(0, 0, 0);  p(2) = gp_Pnt(1, 3, 1);  p(3) = gp_Pnt(2, -2, 4);
  p(4) = gp_Pnt(3, 5, -1); p(5) = gp_Pnt(4, -4, 2); p(6) = gp_Pnt(5, 1, 0);
  TColStd_Array1OfReal k(1, 4);
  k(1) = 0; k(2) = 1; k(3) = 2; k(4) = 3;
  TColStd_Array1OfInteger m(1, 4);
  m(1) = 4; m(2) = 1; m(3) = 1; m(4) = 4;
  return new Geom_BSplineCurve(p, k, m, 3);
}

int main(int argc, char** argv) {
  if (argc < 5) { fprintf(stderr, "usage\n"); return 2; }
  std::string cmd = argv[1], mode = argv[2];
  int nThreads = atoi(argv[3]);
  long iters = atol(argv[4]);
  Handle(Geom_BSplineCurve) curve = makeCurve();
  Handle(GeomAdaptor_Curve) shared = new GeomAdaptor_Curve(curve);
  std::atomic<int> ready{0};
  std::atomic<bool> go{false};
  std::atomic<long> wrong{0}, total{0};
  std::vector<std::thread> ts;
  std::vector<double> sink(nThreads, 0.0);
  for (int t = 0; t < nThreads; ++t) {
    ts.emplace_back([&, t]() {
      bool useShared = (mode == "shared" || mode == "sharedhot" || mode == "sharedalt");
      Handle(Adaptor3d_Curve) own;
      if (!useShared) own = shared->ShallowCopy();
      Adaptor3d_Curve* a = useShared ? static_cast<Adaptor3d_Curve*>(shared.get()) : own.get();
      bool hot = (mode == "hot" || mode == "sharedhot");
      ready++;
      while (!go.load()) {}
      double acc = 0;
      long w = 0;
      for (long i = 0; i < iters; ++i) {
        double u = hot ? 1.5 : ((i + t) % 2 ? 0.2 + 0.0001 * (i % 100) : 2.8 - 0.0001 * (i % 100));
        gp_Pnt p;
        a->D0(u, p);
        acc += p.X();
        if (cmd == "race") {
          gp_Pnt q;
          curve->D0(u, q);
          if (p.Distance(q) > 1e-9) ++w;
        }
      }
      sink[t] = acc;
      wrong += w;
      total += iters;
    });
  }
  while (ready.load() < nThreads) {}
  auto t0 = std::chrono::steady_clock::now();
  go = true;
  for (auto& th : ts) th.join();
  double s = std::chrono::duration<double>(std::chrono::steady_clock::now() - t0).count();
  if (cmd == "race") printf("wrong=%ld total=%ld\n", wrong.load(), total.load());
  else printf("seconds=%.4f ns_per_call=%.1f sink=%g\n", s, s * 1e9 / (double)iters, sink[0]);
  return 0;
}
