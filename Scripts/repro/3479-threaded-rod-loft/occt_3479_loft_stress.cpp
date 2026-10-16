// Concurrent smooth ThruSections lofts of an ISO-68 thread cam, the exact construction
// Shape.threadedRodSolid performs (cam wire per z-slice, BRepOffsetAPI_ThruSections isSolid=true
// isRuled=false CheckCompatibility(true)). Pure C++, no Swift or bridge.
//
// Usage: occt_3479_loft_stress <threads> <iterations> [serialGate]
//   serialGate=1 holds one process-wide mutex around each loft, the control: any report that
//   survives it is not a race between lofts.
//
// Built for the TSan kernel by Scripts/tsan-stress.sh's compile line; see README.md.

#include <atomic>
#include <chrono>
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <mutex>
#include <thread>
#include <vector>

#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepBuilderAPI_MakeWire.hxx>
#include <BRepOffsetAPI_ThruSections.hxx>
#include <GC_MakeArcOfCircle.hxx>
#include <GeomAPI_Interpolate.hxx>
#include <Geom_BSplineCurve.hxx>
#include <TColgp_HArray1OfPnt.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Shape.hxx>
#include <TopoDS_Wire.hxx>
#include <gp_Pnt.hxx>

namespace
{
const double kTwoPi = 2.0 * M_PI;

struct Seg
{
  bool   flat;
  double a0, d0, a1, d1; // axial fraction, depth (0 crest .. 1 root)
};

// crest flat, flank, root flat, flank: one pitch = one full turn.
const Seg kProfile[4] = {{true, 0.0, 0.0, 0.125, 0.0},
                         {false, 0.125, 0.0, 0.4375, 1.0},
                         {true, 0.4375, 1.0, 0.6875, 1.0},
                         {false, 0.6875, 1.0, 1.0, 0.0}};

gp_Pnt pt(double r, double ang, double z)
{
  return gp_Pnt(r * std::cos(ang), r * std::sin(ang), z);
}

TopoDS_Wire camWire(double z, double pitch, double rMaj, double cutDepth)
{
  const double      al = z * kTwoPi / pitch;
  BRepBuilderAPI_MakeWire mw;
  for (const Seg& s : kProfile)
  {
    const double r0 = rMaj - s.d0 * cutDepth, r1 = rMaj - s.d1 * cutDepth;
    const double a0 = al + s.a0 * kTwoPi, a1 = al + s.a1 * kTwoPi;
    if (s.flat)
    {
      GC_MakeArcOfCircle arc(pt(r0, a0, z), pt(r0, 0.5 * (a0 + a1), z), pt(r1, a1, z));
      if (!arc.IsDone())
        return TopoDS_Wire();
      mw.Add(BRepBuilderAPI_MakeEdge(arc.Value()).Edge());
    }
    else
    {
      Handle(TColgp_HArray1OfPnt) pts = new TColgp_HArray1OfPnt(1, 9);
      for (int i = 0; i <= 8; ++i)
      {
        const double f = i / 8.0;
        pts->SetValue(i + 1, pt(r0 + (r1 - r0) * f, a0 + (a1 - a0) * f, z));
      }
      GeomAPI_Interpolate interp(pts, Standard_False, 1e-6);
      interp.Perform();
      if (!interp.IsDone())
        return TopoDS_Wire();
      mw.Add(BRepBuilderAPI_MakeEdge(interp.Curve()).Edge());
    }
  }
  return mw.Wire();
}

std::mutex gGate;
bool       gUseGate = false;

bool buildOne(double pitch)
{
  const double rMaj = 6.0, cutDepth = 0.6134 * pitch, length = 16.0;
  const int    nSec = std::max(2, (int)std::ceil(length / (pitch / 16.0)));
  std::vector<TopoDS_Wire> wires;
  for (int i = 0; i <= nSec; ++i)
  {
    TopoDS_Wire w = camWire(length * i / nSec, pitch, rMaj, cutDepth);
    if (w.IsNull())
      return false;
    wires.push_back(w);
  }
  std::unique_lock<std::mutex> lock(gGate, std::defer_lock);
  if (gUseGate)
    lock.lock();
  BRepOffsetAPI_ThruSections maker(Standard_True, Standard_False);
  maker.CheckCompatibility(Standard_True);
  for (const TopoDS_Wire& w : wires)
    maker.AddWire(w);
  maker.Build();
  return maker.IsDone();
}
} // namespace

int main(int argc, char** argv)
{
  const int threads = argc > 1 ? atoi(argv[1]) : 8;
  const int iters   = argc > 2 ? atoi(argv[2]) : 4;
  gUseGate          = argc > 3 && atoi(argv[3]) != 0;
  const double pitches[] = {1.0, 1.25, 1.5, 1.75, 0.8, 2.0};
  std::atomic<int> built{0}, failed{0};
  std::vector<std::thread> pool;
  for (int t = 0; t < threads; ++t)
  {
    pool.emplace_back([&, t] {
      for (int k = 0; k < iters; ++k)
      {
        try
        {
          (buildOne(pitches[(t + k) % 6]) ? built : failed)++;
        }
        catch (...)
        {
          failed++;
        }
      }
    });
  }
  for (auto& th : pool)
    th.join();
  printf("threads=%d iters=%d gate=%d built=%d failed=%d\n", threads, iters, (int)gUseGate,
         built.load(), failed.load());
  return 0;
}
