// #3039: concurrent first use of BRepLib::Plane() through BRepLib_MakeEdge2d.
//
//   probe <threads> [warm]
//
// N threads wait at a spin barrier, then each builds the same half circle and reads both
// vertices. It has to run in a fresh process every time: the race can only happen on the first
// call. "warm" is the control, which calls BRepLib::Plane() once on the main thread first.
// Exit 0 clean, 1 a wrong vertex; a signal kills the process (the harness counts those).
#include <BRepLib.hxx>
#include <BRepLib_MakeEdge2d.hxx>
#include <BRep_Tool.hxx>
#include <TopExp.hxx>
#include <TopoDS_Edge.hxx>
#include <TopoDS_Vertex.hxx>
#include <gp_Ax2d.hxx>
#include <gp_Circ2d.hxx>

#include <atomic>
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <string>
#include <thread>
#include <vector>

int main(int argc, char** argv)
{
  const int  n    = argc > 1 ? atoi(argv[1]) : 16;
  const bool warm = argc > 2 && std::string(argv[2]) == "warm";
  if (warm)
    BRepLib::Plane();
  std::atomic<int>         ready{0};
  std::atomic<bool>        go{false};
  std::atomic<int>         bad{0};
  std::vector<std::thread> ts;
  for (int i = 0; i < n; i++)
  {
    ts.emplace_back([&, i] {
      ready++;
      while (!go.load())
      {
      }
      BRepLib_MakeEdge2d me(gp_Circ2d(gp_Ax2d(gp_Pnt2d(0, 0), gp_Dir2d(1, 0)), 5), 0, M_PI);
      TopoDS_Edge        e = me.Edge();
      TopoDS_Vertex      v1, v2;
      TopExp::Vertices(e, v1, v2);
      gp_Pnt     p1 = BRep_Tool::Pnt(v1), p2 = BRep_Tool::Pnt(v2);
      const bool ok = std::fabs(p1.X() - 5) < 1e-9 && std::fabs(p1.Y()) < 1e-9
                      && std::fabs(p1.Z()) < 1e-9 && std::fabs(p2.X() + 5) < 1e-9
                      && std::fabs(p2.Y()) < 1e-9 && std::fabs(p2.Z()) < 1e-9;
      if (!ok)
      {
        bad++;
        printf("thread %d: p1=(%.9g, %.9g, %.9g) p2=(%.9g, %.9g, %.9g)\n",
               i, p1.X(), p1.Y(), p1.Z(), p2.X(), p2.Y(), p2.Z());
      }
    });
  }
  while (ready.load() < n)
  {
  }
  go = true;
  for (auto& t : ts)
    t.join();
  printf("bad=%d of %d\n", bad.load(), n);
  return bad.load() == 0 ? 0 : 1;
}
