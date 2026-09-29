// Ground truth for #2795: the P1..P4 boundary arrangement GeomFill_Coons::Init and
// GeomFill_Curved::Init require, and whether the two are the same arrangement.
//
// #2795 states the mechanism from GeomFill_Coons.cxx and says GeomFill_Curved.cxx is "identically"
// laid out. It is not, and this probe is what shows it: Curved puts P4 on the U = 1 boundary and P2
// on the U = NPolU boundary, the opposite of Coons, and its second loop runs only over the interior
// V range, so the four corners stay P1's and P3's instead of being overwritten.
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
#include <NCollection_Array1.hxx>
#include <NCollection_Array2.hxx>
#include <gp_Pnt.hxx>

#include <cstdio>
#include <string>

typedef NCollection_Array1<gp_Pnt> Row;

static const int N = 5;

// The four rows of a flat 10 x 10 square in the z = 0 plane, exactly as
// Tests/OCCTSurfaceTests/GeomFillCoonsTests.swift builds them.
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
  return 0;
}
