// #994: do OCCTBridge_BRepGraph.mm's locationFromMatrix and OCCTBridge_Topology.mm's
// trsfFromMatrix12 build the same transform, and does matrix12FromTrsf invert it exactly?
//
// The two helpers were defined 4,800 lines apart in different files. Both call
// gp_Trsf::SetValues(m[0]..m[11]) in order; the BRepGraph one additionally wraps the result in a
// TopLoc_Location, which is the composite OCCTShapeLocated and OCCTShapeSetLocation also build a
// line later. Nothing in the tree ever checked that the three agree, and nothing could have caught
// a drift, because the BRepGraph side writes a location into the graph that no read-side bridge
// function exposes (measured: BRepGraph.shape(nodeKind:.product/.occurrence) returns the shape
// unplaced, or nil).
//
// The second question this settles is the layout hazard. This bridge carries TWO 12-double
// conventions, INTERLEAVED (3x4 row-major, what gp_Trsf::SetValues itself takes) and GROUPED
// (nine rotation values then three translations), which #835 separated on the Swift side into
// TransformMatrix3D and Matrix12Grouped after they had been confusable as bare [Double]. Feeding
// one to the other's reader is not rejected: this kernel is built with No_Exception, so
// SetValues' own orthonormality precondition is compiled out and a wrong answer comes back
// looking like a right one.
//
// Build:
//   clang++ -std=c++17 -ObjC++ -w \
//     -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
//     -L"Libraries/OCCT.xcframework/macos-arm64" \
//     -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
//     Scripts/repro/994-matrix12-interleaved/occt_994_matrix12.mm -o /tmp/occt_994

#include <TopLoc_Location.hxx>
#include <gp_Ax1.hxx>
#include <gp_Dir.hxx>
#include <gp_Pnt.hxx>
#include <gp_Trsf.hxx>

#include <cmath>
#include <cstdio>

// --- The three helpers, transcribed unchanged from origin/main before the fix ---

// OCCTBridge_BRepGraph.mm:4631
static TopLoc_Location locationFromMatrix(const double m[12])
{
  gp_Trsf trsf;
  trsf.SetValues(m[0], m[1], m[2], m[3], m[4], m[5], m[6], m[7], m[8], m[9], m[10], m[11]);
  return TopLoc_Location(trsf);
}

// OCCTBridge_Topology.mm:4134
static gp_Trsf trsfFromMatrix12(const double* m)
{
  gp_Trsf t;
  t.SetValues(m[0], m[1], m[2], m[3], m[4], m[5], m[6], m[7], m[8], m[9], m[10], m[11]);
  return t;
}

// OCCTBridge_Topology.mm:4141
static void matrix12FromTrsf(const gp_Trsf& t, double* m)
{
  m[0]  = t.Value(1, 1);
  m[1]  = t.Value(1, 2);
  m[2]  = t.Value(1, 3);
  m[3]  = t.Value(1, 4);
  m[4]  = t.Value(2, 1);
  m[5]  = t.Value(2, 2);
  m[6]  = t.Value(2, 3);
  m[7]  = t.Value(2, 4);
  m[8]  = t.Value(3, 1);
  m[9]  = t.Value(3, 2);
  m[10] = t.Value(3, 3);
  m[11] = t.Value(3, 4);
}

// --- The GROUPED reader, transcribed from OCCTShapeTransformed (OCCTBridge_Modeling.mm:12510),
//     which is NOT what this fix converges and must never be handed an INTERLEAVED array ---

static gp_Trsf trsfFromMatrix12Grouped(const double* m)
{
  gp_Trsf t;
  t.SetValues(m[0], m[1], m[2], m[9], m[3], m[4], m[5], m[10], m[6], m[7], m[8], m[11]);
  return t;
}

static int failures = 0;

static bool sameTrsf(const gp_Trsf& a, const gp_Trsf& b)
{
  for (int r = 1; r <= 3; r++)
    for (int c = 1; c <= 4; c++)
      if (a.Value(r, c) != b.Value(r, c)) // bit for bit: same inputs, same call
        return false;
  return true;
}

static void check(const char* label, const double* m)
{
  gp_Trsf         viaTopology = trsfFromMatrix12(m);
  TopLoc_Location viaGraph    = locationFromMatrix(m);

  bool agree = sameTrsf(viaTopology, viaGraph.Transformation());

  double back[12];
  matrix12FromTrsf(viaTopology, back);
  double worstRoundTrip = 0.0;
  for (int i = 0; i < 12; i++)
    worstRoundTrip = std::max(worstRoundTrip, std::abs(back[i] - m[i]));

  printf("%-34s agree=%s  roundTrip max|back-m|=%.17g%s\n",
         label,
         agree ? "yes" : "NO",
         worstRoundTrip,
         (agree && worstRoundTrip == 0.0) ? "" : "   <-- DIVERGENCE");
  if (!agree || worstRoundTrip != 0.0)
    failures++;
}

int main()
{
  // 1. Identity.
  const double identity[12] = {1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0};
  check("identity", identity);

  // 2. Pure translation, the shape every placement in this bridge is built around.
  const double translate[12] = {1, 0, 0, 5, 0, 1, 0, 6, 0, 0, 1, 7};
  check("translate (5, 6, 7)", translate);

  // 3. A 30-degree rotation about Z, with a translation, so every one of the twelve slots is a
  //    distinct number and a permuted read cannot coincidentally agree.
  const double c = std::cos(M_PI / 6.0), s = std::sin(M_PI / 6.0);
  const double rotZ[12] = {c, -s, 0, 5, s, c, 0, 6, 0, 0, 1, 7};
  check("rotate 30 about Z + translate", rotZ);

  // 4. A rotation about an arbitrary axis, built by gp_Trsf itself and read back out, so the
  //    fixture is a transform the kernel produced rather than one written by hand.
  {
    gp_Trsf built;
    built.SetRotation(gp_Ax1(gp_Pnt(1, 2, 3), gp_Dir(1, 1, 1)), 0.7);
    double m[12];
    matrix12FromTrsf(built, m);
    check("kernel-built rotation about (1,1,1)", m);
  }

  // 5. A uniform scale, which gp_Trsf::SetValues accepts (it divides the scale out).
  const double scaled[12] = {2, 0, 0, 1, 0, 2, 0, 2, 0, 0, 2, 3};
  check("uniform scale 2 + translate", scaled);

  // --- The layout hazard, measured rather than asserted ---
  //
  // Same logical transform, translation by (5, 6, 7), written both ways.
  const double interleaved[12] = {1, 0, 0, 5, 0, 1, 0, 6, 0, 0, 1, 7};
  const double grouped[12]     = {1, 0, 0, 0, 1, 0, 0, 0, 1, 5, 6, 7};

  gp_Trsf right = trsfFromMatrix12(interleaved);
  gp_Trsf alsoRight = trsfFromMatrix12Grouped(grouped);
  gp_Trsf wrong = trsfFromMatrix12(grouped); // GROUPED array through the INTERLEAVED reader

  printf("\nlayout hazard, both arrays meaning translate (5, 6, 7):\n");
  printf("  INTERLEAVED array through the INTERLEAVED reader: translation (%g, %g, %g)\n",
         right.Value(1, 4),
         right.Value(2, 4),
         right.Value(3, 4));
  printf("  GROUPED array through the GROUPED reader:         translation (%g, %g, %g)\n",
         alsoRight.Value(1, 4),
         alsoRight.Value(2, 4),
         alsoRight.Value(3, 4));
  printf("  GROUPED array through the INTERLEAVED reader:     translation (%g, %g, %g)  "
         "accepted=%s\n",
         wrong.Value(1, 4),
         wrong.Value(2, 4),
         wrong.Value(3, 4),
         "yes (No_Exception: SetValues' orthonormality precondition is compiled out)");

  if (!sameTrsf(right, alsoRight))
  {
    printf("  <-- the two readers DISAGREE on the same logical transform, which they must not\n");
    failures++;
  }
  if (sameTrsf(right, wrong))
  {
    printf("  <-- the mismatched read coincidentally agreed; pick a fixture where it does not\n");
    failures++;
  }

  printf("\n%s: %d divergence(s)\n", failures == 0 ? "AGREE" : "DISAGREE", failures);
  return failures == 0 ? 0 : 1;
}
