// Ground truth for #2795: the P1..P4 boundary arrangement GeomFill_Coons::Init and
// GeomFill_Curved::Init require, and whether the two are the same arrangement.
//
// #2795 states the mechanism from GeomFill_Coons.cxx and says GeomFill_Curved.cxx is "identically"
// laid out. It is not, and this probe is what shows it: Curved puts P4 on the U = 1 boundary and P2
// on the U = NPolU boundary, the opposite of Coons, and its second loop runs only over the interior
// V range, so the four corners stay P1's and P3's instead of being overwritten.
//
// Extended for #2843 with the third class of the family, GeomFill_Stretch. It takes the Curved
// arrangement, not the Coons one, and it differs from Curved on exactly one point: its interior
// formula carries a bilinear corner-correction term (GeomFill_Stretch.cxx:92-96) that Curved has
// no counterpart for (GeomFill_Curved.cxx:115-119). So P2(1) and P4(NPolV) ARE read by Stretch,
// in the interior only, while Curved reads no endpoint of P2 or P4 at all.
//
// Compile (from the repo root, in a worktree with no Libraries/OCCT.xcframework, so the pinned
// v4.0.0-kernel.2 asset SwiftPM resolved is what gets linked):
//
//   XCF=$(find .build/artifacts -maxdepth 4 -name OCCT.xcframework)
//   clang++ -std=c++17 -ObjC++ -w \
//     -I"$XCF/macos-arm64/Headers" -L"$XCF/macos-arm64" \
//     -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
//     Scripts/repro/2795-geomfill-boundary-arrangement/probe.mm -o /tmp/occt_probe_2795

#include <GeomFill_Coons.hxx>
#include <GeomFill_Curved.hxx>
#include <GeomFill_Stretch.hxx>
#include <NCollection_Array1.hxx>
#include <NCollection_Array2.hxx>
#include <gp_Pnt.hxx>

#include <cstdio>
#include <string>

typedef NCollection_Array1<gp_Pnt> Row;

static const int N = 5;

// The four rows of a flat 10 x 10 square in the z = 0 plane, exactly as
// Tests/OCCTSurfaceTests/GeomFill/GeomFillCoonsTests.swift builds them.
static Row bottomRow() // y = 0, indexed along x
{
  Row r(1, N);
  for (int i = 1; i <= N; i++)
    r(i) = gp_Pnt((i - 1) * 10.0 / (N - 1), 0.0, 0.0);
  return r;
}

static Row topRow() // y = 10, indexed along x
{
  Row r(1, N);
  for (int i = 1; i <= N; i++)
    r(i) = gp_Pnt((i - 1) * 10.0 / (N - 1), 10.0, 0.0);
  return r;
}

static Row leftRow() // x = 0, indexed along y
{
  Row r(1, N);
  for (int i = 1; i <= N; i++)
    r(i) = gp_Pnt(0.0, (i - 1) * 10.0 / (N - 1), 0.0);
  return r;
}

static Row rightRow() // x = 10, indexed along y
{
  Row r(1, N);
  for (int i = 1; i <= N; i++)
    r(i) = gp_Pnt(10.0, (i - 1) * 10.0 / (N - 1), 0.0);
  return r;
}

template <class Filler>
static void dump(const char* label, const Row& P1, const Row& P2, const Row& P3, const Row& P4)
{
  Filler f(P1, P2, P3, P4);
  int    nbU = f.NbUPoles();
  int    nbV = f.NbVPoles();
  printf("%s nbU=%d nbV=%d\n", label, nbU, nbV);
  NCollection_Array2<gp_Pnt> poles(1, nbU, 1, nbV);
  f.Poles(poles);
  // Row-major in U with V varying fastest, which is the order the bridge flattens them in.
  bool uniform = true;
  for (int u = 1; u <= nbU; u++)
  {
    printf("  ");
    for (int v = 1; v <= nbV; v++)
    {
      gp_Pnt p = poles(u, v);
      printf("(%g,%g,%g)", p.X(), p.Y(), p.Z());
      // A correctly arranged flat square gives a uniform grid: x from U, y from V, z = 0.
      double ex = (u - 1) * 10.0 / (nbU - 1);
      double ey = (v - 1) * 10.0 / (nbV - 1);
      if (p.Distance(gp_Pnt(ex, ey, 0.0)) > 1e-9)
        uniform = false;
    }
    printf("\n");
  }
  printf("  uniform 5x5 flat square grid: %s\n", uniform ? "YES" : "no");
}

int main()
{
  const Row b1 = bottomRow();
  const Row b2 = topRow();
  const Row b3 = leftRow();
  const Row b4 = rightRow();

  printf("=== GeomFill_Coons ===\n");
  printf("Init places P1 at V=1 and P3 at V=NPolV (indexed along U), then P2 at U=1 and\n"
         "P4 at U=NPolU (indexed along V), second loop overwriting the four corners.\n\n");
  dump<GeomFill_Coons>("Coons (b1,b2,b3,b4)  [what the test fixture passes]", b1, b2, b3, b4);
  printf("\n");
  dump<GeomFill_Coons>("Coons (b1,b3,b2,b4)  [#2795's corrected arrangement]", b1, b3, b2, b4);
  printf("\n");
  dump<GeomFill_Coons>("Coons (b1,b4,b2,b3)", b1, b4, b2, b3);

  printf("\n=== GeomFill_Curved ===\n");
  printf("Init places P1 at V=1 and P3 at V=NPolV as Coons does, but then P4 at U=1 and\n"
         "P2 at U=NPolU, and only for j = 2..NPolV-1, so P1/P3 keep all four corners and\n"
         "P2(1), P2(NPolV), P4(1), P4(NPolV) are never read.\n\n");
  dump<GeomFill_Curved>("Curved (b1,b2,b3,b4)  [what the test fixture passes]", b1, b2, b3, b4);
  printf("\n");
  dump<GeomFill_Curved>("Curved (b1,b3,b2,b4)  [#2795's arrangement, wrong for Curved]",
                        b1,
                        b3,
                        b2,
                        b4);
  printf("\n");
  dump<GeomFill_Curved>("Curved (b1,b4,b2,b3)  [the corrected arrangement for Curved]",
                        b1,
                        b4,
                        b2,
                        b3);

  printf("\n=== the silent corner overwrite, isolated ===\n");
  printf("Coons: move P2(1) off the square's (0,0,0) corner and read pole (1,1).\n");
  {
    Row p2 = leftRow();
    p2(1) = gp_Pnt(0.0, 0.0, 99.0);
    GeomFill_Coons             f(b1, p2, b2, b4);
    NCollection_Array2<gp_Pnt> poles(1, f.NbUPoles(), 1, f.NbVPoles());
    f.Poles(poles);
    gp_Pnt c = poles(1, 1);
    printf("  P1(1)=(0,0,0) P2(1)=(0,0,99) -> pole(1,1)=(%g,%g,%g)  [P2 wins]\n",
           c.X(),
           c.Y(),
           c.Z());
  }
  printf("Curved: the same disagreement, same corner.\n");
  {
    Row p4 = leftRow();
    p4(1) = gp_Pnt(0.0, 0.0, 99.0);
    GeomFill_Curved            f(b1, b4, b2, p4);
    NCollection_Array2<gp_Pnt> poles(1, f.NbUPoles(), 1, f.NbVPoles());
    f.Poles(poles);
    gp_Pnt c = poles(1, 1);
    printf("  P1(1)=(0,0,0) P4(1)=(0,0,99) -> pole(1,1)=(%g,%g,%g)  [P1 wins, P4(1) unread]\n",
           c.X(),
           c.Y(),
           c.Z());
  }

  // ==== #2843: GeomFill_Stretch, the third class of the family ================================
  printf("\n=== GeomFill_Stretch (#2843) ===\n");
  printf("Init places P1 at V=1 and P3 at V=NPolV indexed along U, then P4 at U=1 and P2 at\n"
         "U=NPolU indexed along V, for j = 2..NPolV-1 only: the Curved arrangement, NOT the\n"
         "Coons one. GeomFill_BSplineCurves::Init confirms it from the caller side, passing\n"
         "GeomFill_Stretch(P1,P2,P3,P4) and GeomFill_Curved(P1,P2,P3,P4) unswapped while\n"
         "GeomFill_Coons gets (P1,P4,P3,P2) (GeomFill_BSplineCurves.cxx:344-350).\n\n");
  dump<GeomFill_Stretch>("Stretch (b1,b2,b3,b4)  [the Coons-ordered fixture]", b1, b2, b3, b4);
  printf("\n");
  dump<GeomFill_Stretch>("Stretch (b1,b3,b2,b4)  [the Coons arrangement, wrong for Stretch]",
                         b1,
                         b3,
                         b2,
                         b4);
  printf("\n");
  dump<GeomFill_Stretch>("Stretch (b1,b4,b2,b3)  [the correct arrangement: bottom,right,top,left]",
                         b1,
                         b4,
                         b2,
                         b3);

  printf("\n=== #2843: which corners Stretch reads, and where ===\n");
  printf("Stretch's interior subtracts a bilinear patch through P1(1), P2(1), P3(NPolU) and\n"
         "P4(NPolV) (GeomFill_Stretch.cxx:92-96). Curved has no such term. So a disagreeing\n"
         "corner is dropped from the BOUNDARY by both, but still moves Stretch's INTERIOR.\n\n");
  {
    // The correct Stretch arrangement is (bottom, right, top, left) = (b1, b4, b2, b3).
    // P2 is the right row, so P2(1) is the square's (10, 0, 0) corner, which the boundary
    // also gets from P1(NPolU).
    GeomFill_Stretch           clean(b1, b4, b2, b3);
    NCollection_Array2<gp_Pnt> cleanPoles(1, clean.NbUPoles(), 1, clean.NbVPoles());
    clean.Poles(cleanPoles);

    Row p2 = rightRow();
    p2(1)  = gp_Pnt(10.0, 0.0, 99.0); // read by the correction term
    GeomFill_Stretch           moved(b1, p2, b2, b3);
    NCollection_Array2<gp_Pnt> movedPoles(1, moved.NbUPoles(), 1, moved.NbVPoles());
    moved.Poles(movedPoles);
    gp_Pnt corner = movedPoles(moved.NbUPoles(), 1);
    gp_Pnt inner  = movedPoles(2, 2);
    printf("  P2(1) moved to (10,0,99):\n");
    printf("    boundary corner pole(NPolU,1) = (%g,%g,%g)   [clean (%g,%g,%g)]\n",
           corner.X(),
           corner.Y(),
           corner.Z(),
           cleanPoles(clean.NbUPoles(), 1).X(),
           cleanPoles(clean.NbUPoles(), 1).Y(),
           cleanPoles(clean.NbUPoles(), 1).Z());
    printf("    interior pole(2,2)            = (%g,%g,%g)   [clean (%g,%g,%g)]\n",
           inner.X(),
           inner.Y(),
           inner.Z(),
           cleanPoles(2, 2).X(),
           cleanPoles(2, 2).Y(),
           cleanPoles(2, 2).Z());

    // P2(NPolV) is the other end of the same row, and no term of Init reads it.
    Row p2b   = rightRow();
    p2b(N)    = gp_Pnt(10.0, 10.0, 99.0);
    GeomFill_Stretch           unread(b1, p2b, b2, b3);
    NCollection_Array2<gp_Pnt> unreadPoles(1, unread.NbUPoles(), 1, unread.NbVPoles());
    unread.Poles(unreadPoles);
    bool identical = true;
    for (int u = 1; u <= unread.NbUPoles(); u++)
      for (int v = 1; v <= unread.NbVPoles(); v++)
        if (unreadPoles(u, v).Distance(cleanPoles(u, v)) > 1e-12)
          identical = false;
    printf("  P2(NPolV) moved to (10,10,99): whole pole grid unchanged: %s\n",
           identical ? "YES [never read]" : "no");

    // The same experiment on Curved, where BOTH ends of P2 are unread.
    GeomFill_Curved            curvedClean(b1, b4, b2, b3);
    NCollection_Array2<gp_Pnt> ccPoles(1, curvedClean.NbUPoles(), 1, curvedClean.NbVPoles());
    curvedClean.Poles(ccPoles);
    GeomFill_Curved            curvedMoved(b1, p2, b2, b3); // p2 still has P2(1) at z = 99
    NCollection_Array2<gp_Pnt> cmPoles(1, curvedMoved.NbUPoles(), 1, curvedMoved.NbVPoles());
    curvedMoved.Poles(cmPoles);
    bool curvedIdentical = true;
    for (int u = 1; u <= curvedMoved.NbUPoles(); u++)
      for (int v = 1; v <= curvedMoved.NbVPoles(); v++)
        if (cmPoles(u, v).Distance(ccPoles(u, v)) > 1e-12)
          curvedIdentical = false;
    printf("  Curved, same P2(1) move:       whole pole grid unchanged: %s\n",
           curvedIdentical ? "YES [never read]" : "no");
  }
  return 0;
}
