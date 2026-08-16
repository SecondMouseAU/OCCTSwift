// Ground truth probe for OCCTSwift#913: BRepOffsetAPI_ThruSections::CreateSmoothed() has no
// bounds check on its fixed-stride `shapes` array, which is sized from section 1's edge count
// alone. Under checkCompatibility(false), a section with a DIFFERENT edge count than section 1
// either overruns the array (more edges -- heap corruption, SIGSEGV/SIGBUS) or, if the running
// write index still lands in bounds by the end, silently misaligns per-section strides (fewer
// edges -- Build() == true, Shape().IsValid() == false, no signal anything went wrong).
//
// This probe runs six cases and prints IsDone()/crash status for each:
//
//   1. matching:    3 matching-edge-count sections, checkCompatibility(false) -- must succeed.
//   2. punctual:    an apex (AddVertex) + 2 matching wire sections -- must succeed (the
//                   w1Point/w2Point exemption must not over-reject a legitimate cone-apex loft).
//   3. reconciled:  mismatched sections WITH checkCompatibility(true) (default) -- must succeed,
//                   unaffected (BRepFill_CompatibleWires reconciles before CreateSmoothed runs).
//   4. overrun:     a reused builder, 2 matching circles then a 3rd section with MORE edges,
//                   checkCompatibility(false) -- the original crash. Stock: SIGSEGV (this probe's
//                   own signal handler) or SIGBUS (see README -- both genuinely observed, in
//                   different binaries). Patched: IsDone() == false, no crash.
//   5. fewer:       3 sections (2, 1, 3 edges -- the reviewer's own carefully-chosen example,
//                   where the running write index never exceeds bounds because the shortfall in
//                   section 2 is exactly made up by the surplus in section 3), checkCompatibility
//                   (false). Stock: IsDone() == true, Shape().IsValid() == false (silent wrong
//                   answer). Patched: IsDone() == false.
//   6. emptyPunctual: a genuinely zero-edge wire at the punctual position. Stock and patched both
//                   report IsDone() == false and neither crashes -- this project could not
//                   reproduce a live crash for this case (see README); the patch's explicit
//                   hasAnyEdge check is a hardening kept for correctness, not proof of closing an
//                   observed defect.
//
// Compile once against the stock archive and once with a patched BRepOffsetAPI_ThruSections.cxx
// override-linked in front (see README.md), and diff.

#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepBuilderAPI_MakePolygon.hxx>
#include <BRepBuilderAPI_MakeVertex.hxx>
#include <BRepBuilderAPI_MakeWire.hxx>
#include <BRepOffsetAPI_ThruSections.hxx>
#include <BRep_Builder.hxx>
#include <gce_MakeCirc.hxx>
#include <gp.hxx>
#include <gp_Ax2.hxx>
#include <gp_Circ.hxx>
#include <gp_Dir.hxx>
#include <gp_Pnt.hxx>
#include <TopoDS_Vertex.hxx>
#include <TopoDS_Wire.hxx>

#include <cmath>
#include <cstdio>
#include <csignal>
#include <execinfo.h>
#include <unistd.h>

namespace
{
void crashHandler(int sig)
{
  void* frames[64];
  int   n = backtrace(frames, 64);
  fprintf(stderr, "\n=== crashHandler: signal %d ===\n", sig);
  backtrace_symbols_fd(frames, n, STDERR_FILENO);
  _exit(134);
}

TopoDS_Wire circleWire(double theRadius, double theZ)
{
  gp_Ax2                  anAxis(gp_Pnt(0, 0, theZ), gp::DZ());
  gce_MakeCirc            aMakeCirc(anAxis, theRadius);
  BRepBuilderAPI_MakeEdge aMakeEdge(aMakeCirc.Value());
  return BRepBuilderAPI_MakeWire(aMakeEdge.Edge()).Wire();
}

TopoDS_Wire nGonWire(int theN, double theRadius, double theZ)
{
  BRepBuilderAPI_MakePolygon aPolygon;
  for (int i = 0; i < theN; ++i)
  {
    double anAngle = 2.0 * M_PI * i / theN;
    aPolygon.Add(gp_Pnt(theRadius * cos(anAngle), theRadius * sin(anAngle), theZ));
  }
  aPolygon.Close();
  return aPolygon.Wire();
}

TopoDS_Vertex apexVertex(double theZ)
{
  return BRepBuilderAPI_MakeVertex(gp_Pnt(0, 0, theZ));
}

TopoDS_Wire emptyWire()
{
  TopoDS_Wire  w;
  BRep_Builder b;
  b.MakeWire(w);
  return w;
}
} // namespace

int main()
{
  signal(SIGSEGV, crashHandler);
  signal(SIGBUS, crashHandler);
  signal(SIGABRT, crashHandler);

  // 1. matching
  {
    BRepOffsetAPI_ThruSections ts(true, false);
    ts.CheckCompatibility(false);
    ts.AddWire(nGonWire(4, 5.0, 0.0));
    ts.AddWire(nGonWire(4, 4.0, 5.0));
    ts.AddWire(nGonWire(4, 3.0, 10.0));
    ts.Build();
    printf("1. matching (3x 4-gon, no-check): IsDone=%d (want 1)\n", ts.IsDone());
    fflush(stdout);
  }

  // 2. punctual
  {
    BRepOffsetAPI_ThruSections ts(true, false);
    ts.CheckCompatibility(false);
    ts.AddVertex(apexVertex(0.0));
    ts.AddWire(nGonWire(5, 4.0, 5.0));
    ts.AddWire(nGonWire(5, 3.0, 10.0));
    ts.Build();
    printf("2. punctual (apex + 2x 5-gon, no-check): IsDone=%d (want 1)\n", ts.IsDone());
    fflush(stdout);
  }

  // 3. reconciled
  {
    BRepOffsetAPI_ThruSections ts(true, false);
    ts.CheckCompatibility(true);
    ts.AddWire(circleWire(5.0, 0.0));
    ts.AddWire(circleWire(3.0, 5.0));
    ts.AddWire(nGonWire(3, 2.0, 10.0));
    ts.Build();
    printf("3. reconciled (circle,circle,triangle, WITH check): IsDone=%d (want 1)\n", ts.IsDone());
    fflush(stdout);
  }

  // 4. overrun (the original crash)
  {
    BRepOffsetAPI_ThruSections ts(true, false);
    ts.CheckCompatibility(false);
    ts.AddWire(circleWire(5.0, 0.0));
    ts.AddWire(circleWire(3.0, 10.0));
    ts.Build();
    printf("4. overrun: build #1 (2 circles): IsDone=%d\n", ts.IsDone());
    fflush(stdout);
    ts.AddWire(nGonWire(3, 2.0, 20.0));
    printf("4. overrun: about to build #2 (+triangle, more edges, no-check)...\n");
    fflush(stdout);
    ts.Build();
    printf("4. overrun: build #2: IsDone=%d (want 0, no crash)\n", ts.IsDone());
    fflush(stdout);
  }

  // 5. fewer (the reviewer's own no-overrun example: 2 + 1 + 3 = 3 * 2)
  {
    BRepOffsetAPI_ThruSections ts(true, false);
    ts.CheckCompatibility(false);
    ts.AddWire(nGonWire(2, 5.0, 0.0));
    ts.AddWire(circleWire(3.0, 10.0));
    ts.AddWire(nGonWire(3, 2.0, 20.0));
    ts.Build();
    printf("5. fewer (2,1,3 edges, no-check): IsDone=%d (want 0)\n", ts.IsDone());
    fflush(stdout);
  }

  // 6. emptyPunctual
  {
    BRepOffsetAPI_ThruSections ts(true, false);
    ts.CheckCompatibility(false);
    ts.AddWire(emptyWire());
    ts.AddWire(nGonWire(4, 4.0, 5.0));
    ts.AddWire(nGonWire(4, 3.0, 10.0));
    ts.Build();
    printf("6. emptyPunctual (empty wire + 2x matching 4-gon, no-check): IsDone=%d (want 0, no "
           "crash on stock OR patched)\n",
           ts.IsDone());
    fflush(stdout);
  }

  printf("ALL DONE, no crash\n");
  return 0;
}
