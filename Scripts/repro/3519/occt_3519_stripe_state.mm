// OCCTSwift#3519 ground truth, the second half: what is actually null in each faulting state.
//
// occt_3519_simulated_surf_matrix.mm shows WHICH states fault. This reads the object the fault is
// a read of: for every stripe of the builder, ChFiDS_Stripe::SetOfSurfData() (the handle NbSurf(IC)
// dereferences without a null test), its length when it is set, and whether the first SurfData
// carries simulation sections (ChFiDS_SurfData::Simul(), what Sect(IC, IS) returns).
//
// BRepFilletAPI_MakeFillet::myBuilder and ChFi3d_Builder::myListStripe are private and protected,
// so this probe opens them with `#define private public` AFTER the standard headers. That is a
// probe-only trick: it does not change the layout, and nothing under Sources/ does it.
//
// Compile (from the repo root, against the xcframework the package pins):
//   XC=.build/artifacts/<package>/OCCT/OCCT.xcframework
//   clang++ -std=c++17 -ObjC++ -w -I"$XC/macos-arm64/Headers" -L"$XC/macos-arm64" -lOCCT-macos \
//     -framework Foundation -framework AppKit -lz -lc++ \
//     Scripts/repro/3519/occt_3519_stripe_state.mm -o /tmp/occt_3519_state
#include <algorithm>
#include <cstdio>
#include <functional>
#include <map>
#include <memory>
#include <mutex>
#include <set>
#include <sstream>
#include <string>
#include <vector>

#define private public
#define protected public
#include <BRepFilletAPI_MakeFillet.hxx>
#include <ChFi3d_FilBuilder.hxx>
#include <ChFiDS_Stripe.hxx>
#include <ChFiDS_SurfData.hxx>
#undef private
#undef protected

#include <BRepPrimAPI_MakeBox.hxx>
#include <Standard_Failure.hxx>
#include <TopExp.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopoDS.hxx>

static std::string describe(BRepFilletAPI_MakeFillet& mk)
{
  std::string out;
  int         i = 0;
  for (auto it = mk.myBuilder.myListStripe.begin(); it != mk.myBuilder.myListStripe.end(); ++it)
  {
    ++i;
    const occ::handle<ChFiDS_Stripe>& st = *it;
    char                              b[200];
    if (st->SetOfSurfData().IsNull())
    {
      snprintf(b, sizeof b, "  stripe %d: SetOfSurfData() = NULL\n", i);
    }
    else
    {
      const int n = st->SetOfSurfData()->Length();
      snprintf(b, sizeof b, "  stripe %d: SetOfSurfData() set, Length() = %d%s\n", i, n,
               n > 0 ? (st->SetOfSurfData()->Value(1)->Simul().IsNull()
                          ? ", first SurfData Simul() = null (built, not simulated)"
                          : ", first SurfData Simul() set (simulated)")
                     : " (empty)");
    }
    out += b;
  }
  if (out.empty())
    out = "  (no stripe)\n";
  return out;
}

int main()
{
  struct Row
  {
    const char*                                         name;
    std::function<void(BRepFilletAPI_MakeFillet&, const TopoDS_Edge&, const TopoDS_Edge&)> run;
  };
  auto tryDo = [](const std::function<void()>& f)
  {
    try
    {
      f();
    }
    catch (Standard_Failure const& e)
    {
      printf("  [threw: %s]\n", e.GetMessageString() ? e.GetMessageString() : "");
    }
  };
  std::vector<Row> rows = {
    {"fresh (no contour)", [&](BRepFilletAPI_MakeFillet&, const TopoDS_Edge&, const TopoDS_Edge&) {}},
    {"edge added, never built, never simulated",
     [&](BRepFilletAPI_MakeFillet& m, const TopoDS_Edge& e, const TopoDS_Edge&) { m.Add(1.0, e); }},
    {"edge added, Simulate(1)",
     [&](BRepFilletAPI_MakeFillet& m, const TopoDS_Edge& e, const TopoDS_Edge&)
     {
       m.Add(1.0, e);
       tryDo([&] { m.Simulate(1); });
     }},
    {"edge added, Simulate(1), Reset()",
     [&](BRepFilletAPI_MakeFillet& m, const TopoDS_Edge& e, const TopoDS_Edge&)
     {
       m.Add(1.0, e);
       tryDo([&] { m.Simulate(1); });
       m.Reset();
     }},
    {"edge added, Build(), then Reset()",
     [&](BRepFilletAPI_MakeFillet& m, const TopoDS_Edge& e, const TopoDS_Edge&)
     {
       m.Add(1.0, e);
       tryDo([&] { m.Build(); });
       m.Reset();
     }},
    {"edge added, Build() ok",
     [&](BRepFilletAPI_MakeFillet& m, const TopoDS_Edge& e, const TopoDS_Edge&)
     {
       m.Add(1.0, e);
       tryDo([&] { m.Build(); });
     }},
    {"declined build (radius 20)",
     [&](BRepFilletAPI_MakeFillet& m, const TopoDS_Edge& e, const TopoDS_Edge&)
     {
       m.Add(20.0, e);
       tryDo([&] { m.Build(); });
     }},
    {"Simulate(1) declined (radius 20)",
     [&](BRepFilletAPI_MakeFillet& m, const TopoDS_Edge& e, const TopoDS_Edge&)
     {
       m.Add(20.0, e);
       tryDo([&] { m.Simulate(1); });
     }},
    {"two contours, only contour 1 Simulate(1)'d",
     [&](BRepFilletAPI_MakeFillet& m, const TopoDS_Edge& e, const TopoDS_Edge& f)
     {
       m.Add(1.0, e);
       m.Add(1.0, f);
       tryDo([&] { m.Simulate(1); });
     }},
  };

  printf("=== ChFiDS_Stripe::SetOfSurfData() per stripe, per state (BRepFilletAPI_MakeFillet) ===\n");
  for (Row& r : rows)
  {
    TopoDS_Shape               box = BRepPrimAPI_MakeBox(10.0, 10.0, 10.0).Shape();
    TopTools_IndexedMapOfShape edges;
    TopExp::MapShapes(box, TopAbs_EDGE, edges);
    const TopoDS_Edge          e1 = TopoDS::Edge(edges(1));
    TopTools_IndexedMapOfShape v1;
    TopExp::MapShapes(e1, TopAbs_VERTEX, v1);
    TopoDS_Edge e2;
    for (int i = 2; i <= edges.Extent() && e2.IsNull(); ++i)
    {
      TopTools_IndexedMapOfShape v;
      TopExp::MapShapes(edges(i), TopAbs_VERTEX, v);
      bool shares = false;
      for (int j = 1; j <= v.Extent(); ++j)
        shares = shares || v1.Contains(v(j));
      if (!shares)
        e2 = TopoDS::Edge(edges(i));
    }
    BRepFilletAPI_MakeFillet mk(box);
    printf("\n--- %s\n", r.name);
    r.run(mk, e1, e2);
    printf("%s", describe(mk).c_str());
  }
  return 0;
}
