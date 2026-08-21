// #1009: one GROUPED 12-double reader, and what gp_Trsf::SetValues really refuses.
//
// Part 1 transcribes the three byte-identical GROUPED readers (OCCTCurve3DParametricTransformation,
// OCCTDocumentAddComponentMatrix, OCCTShapeTransformed) and the shared helper that replaces them,
// and checks they agree on every entry of every fixture.
//
// Part 2 answers the question OCCTDocumentAddComponentMatrix's own comment asserts without
// measuring: "gp_Trsf::SetValues throws if not a proper rigid (orthonormal, det +1) transform, so
// reflections must be baked as a mirrored product (#174)". The header says something different
// ("Raises ConstructionError if the determinant of the aij is null"), and SetValues is
// Standard_EXPORT, compiled inside OCCT's own Release TUs where No_Exception removes the raise
// entirely. Both halves are measured here rather than argued.

#include <BRepBuilderAPI_Transform.hxx>
#include <BRepGProp.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <GProp_GProps.hxx>
#include <Geom_Line.hxx>
#include <Standard_Failure.hxx>
#include <TopoDS_Shape.hxx>
#include <gp_Trsf.hxx>

#include <cmath>
#include <cstdio>
#include <string>
#include <vector>

// --- the three transcribed readers, verbatim from each file ---

static gp_Trsf curve3dReader(const double* trsf12)
{
  gp_Trsf t;
  t.SetValues(trsf12[0],
              trsf12[1],
              trsf12[2],
              trsf12[9],
              trsf12[3],
              trsf12[4],
              trsf12[5],
              trsf12[10],
              trsf12[6],
              trsf12[7],
              trsf12[8],
              trsf12[11]);
  return t;
}

static gp_Trsf documentReader(const double* matrix12)
{
  gp_Trsf trsf;
  trsf.SetValues(matrix12[0],
                 matrix12[1],
                 matrix12[2],
                 matrix12[9],
                 matrix12[3],
                 matrix12[4],
                 matrix12[5],
                 matrix12[10],
                 matrix12[6],
                 matrix12[7],
                 matrix12[8],
                 matrix12[11]);
  return trsf;
}

static gp_Trsf modelingReader(const double* matrix12)
{
  gp_Trsf trsf;
  trsf.SetValues(matrix12[0],
                 matrix12[1],
                 matrix12[2],
                 matrix12[9],
                 matrix12[3],
                 matrix12[4],
                 matrix12[5],
                 matrix12[10],
                 matrix12[6],
                 matrix12[7],
                 matrix12[8],
                 matrix12[11]);
  return trsf;
}

// --- the shared helper that replaces them, verbatim from OCCTBridge_Internal.h ---

static gp_Trsf occtTrsfFromMatrix12Grouped(const double* m)
{
  gp_Trsf t;
  t.SetValues(m[0], m[1], m[2], m[9], m[3], m[4], m[5], m[10], m[6], m[7], m[8], m[11]);
  return t;
}

// The INTERLEAVED sibling, for the confusion measurement.
static gp_Trsf occtTrsfFromMatrix12Interleaved(const double* m)
{
  gp_Trsf t;
  t.SetValues(m[0], m[1], m[2], m[3], m[4], m[5], m[6], m[7], m[8], m[9], m[10], m[11]);
  return t;
}

struct Fixture
{
  std::string         name;
  std::vector<double> grouped;
};

static std::vector<Fixture> fixtures()
{
  const double c = std::cos(M_PI / 6), s = std::sin(M_PI / 6);
  return {
    {"identity", {1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0}},
    {"translate (5, 6, 7)", {1, 0, 0, 0, 1, 0, 0, 0, 1, 5, 6, 7}},
    // A rotation about Z with a translation, so no two of the twelve slots share a value and a
    // permuted read cannot coincidentally agree.
    {"rotate 30 about Z, translate (5, 6, 7)", {c, -s, 0, s, c, 0, 0, 0, 1, 5, 6, 7}},
    {"uniform scale 2, translate (1, 2, 3)", {2, 0, 0, 0, 2, 0, 0, 0, 2, 1, 2, 3}},
  };
}

static int comparePart1()
{
  std::printf("=== Part 1: the three readers against the shared helper ===\n\n");
  int divergences = 0;
  for (const Fixture& f : fixtures())
  {
    const double* m = f.grouped.data();
    gp_Trsf       a = curve3dReader(m);
    gp_Trsf       b = documentReader(m);
    gp_Trsf       c = modelingReader(m);
    gp_Trsf       h = occtTrsfFromMatrix12Grouped(m);
    int           bad = 0;
    for (int i = 1; i <= 3; i++)
      for (int j = 1; j <= 4; j++)
      {
        double v = h.Value(i, j);
        if (a.Value(i, j) != v || b.Value(i, j) != v || c.Value(i, j) != v)
          bad++;
      }
    std::printf("  %-40s %s\n", f.name.c_str(), bad == 0 ? "identical" : "DIVERGES");
    divergences += bad;
  }
  std::printf("\n  divergent entries: %d\n\n", divergences);
  return divergences;
}

static void comparePart1b()
{
  std::printf("=== Part 1b: the same array read with the wrong layout ===\n\n");
  // Both arrays below mean "translate by (5, 6, 7)" in their own layout.
  const double grouped[12]     = {1, 0, 0, 0, 1, 0, 0, 0, 1, 5, 6, 7};
  const double interleaved[12] = {1, 0, 0, 5, 0, 1, 0, 6, 0, 0, 1, 7};

  gp_Trsf right = occtTrsfFromMatrix12Grouped(grouped);
  gp_Trsf alsoRight = occtTrsfFromMatrix12Interleaved(interleaved);
  gp_Trsf wrong = occtTrsfFromMatrix12Interleaved(grouped);

  std::printf("  GROUPED array through the GROUPED reader:         translation (%g, %g, %g)\n",
              right.Value(1, 4),
              right.Value(2, 4),
              right.Value(3, 4));
  std::printf("  INTERLEAVED array through the INTERLEAVED reader: translation (%g, %g, %g)\n",
              alsoRight.Value(1, 4),
              alsoRight.Value(2, 4),
              alsoRight.Value(3, 4));
  std::printf("  GROUPED array through the INTERLEAVED reader:     translation (%g, %g, %g)"
              "  accepted\n\n",
              wrong.Value(1, 4),
              wrong.Value(2, 4),
              wrong.Value(3, 4));
}

// Reports what SetValues does with a matrix its own header says it should refuse, and with the
// reflection #174 says gp_Trsf rejects outright.
static void trySetValues(const char* label, const double* grouped)
{
  try
  {
    gp_Trsf t = occtTrsfFromMatrix12Grouped(grouped);
    std::printf("  %-34s ACCEPTED  scale=%g  IsNegative=%d  Form=%d\n",
                label,
                t.ScaleFactor(),
                (int)t.IsNegative(),
                (int)t.Form());
  }
  catch (Standard_Failure const& f)
  {
    std::printf("  %-34s REFUSED   %s\n", label, f.GetMessageString());
  }
  catch (...)
  {
    std::printf("  %-34s REFUSED   unknown C++ exception\n", label);
  }
}

static void comparePart2()
{
  std::printf("=== Part 2: what SetValues actually refuses ===\n\n");

  const double identity[12]   = {1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0};
  // det = -1: a mirror in X. #174 and the bridge comment both say gp_Trsf rejects this.
  const double reflection[12] = {-1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0};
  // det = 0: the case the header actually names.
  const double singular[12]   = {1, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0};
  const double allZero[12]    = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0};
  // Not orthonormal, det = 8: a uniform scale, which SetValues normalizes into its scale factor.
  const double scaled[12]     = {2, 0, 0, 0, 2, 0, 0, 0, 2, 0, 0, 0};
  // Not orthonormal and not a uniform scale: a shear, det = 1.
  const double shear[12]      = {1, 0.5, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0};

  trySetValues("identity (det +1)", identity);
  trySetValues("reflection in X (det -1)", reflection);
  trySetValues("singular (det 0)", singular);
  trySetValues("all zeros (det 0)", allZero);
  trySetValues("uniform scale 2 (det +8)", scaled);
  trySetValues("shear (det +1, not orthonormal)", shear);

  // A reflection that is accepted is only useful if it actually reflects. Measured on a box whose
  // corner sits away from the mirror plane, so a mirror moves it somewhere a rotation cannot.
  std::printf("\n  the reflection applied to a box at x in [1, 11]:\n");
  gp_Trsf      mirror = occtTrsfFromMatrix12Grouped(reflection);
  TopoDS_Shape box    = BRepPrimAPI_MakeBox(gp_Pnt(1, 0, 0), 10.0, 10.0, 10.0).Shape();
  TopoDS_Shape moved  = BRepBuilderAPI_Transform(box, mirror, Standard_True).Shape();
  GProp_GProps props;
  BRepGProp::VolumeProperties(box, props);
  double before = props.Mass();
  GProp_GProps props2;
  BRepGProp::VolumeProperties(moved, props2);
  std::printf("    centre of mass x: %g -> %g   volume: %g -> %g\n",
              props.CentreOfMass().X(),
              props2.CentreOfMass().X(),
              before,
              props2.Mass());
}

// The third call site's own quantity, so the Swift test asserts a number that was derived and then
// checked rather than simply recorded. Geom_Line's parameter is arc length from its origin point,
// so a uniform scale of k must map the parameter by k.
static void comparePart3()
{
  std::printf("\n=== Part 3: Geom_Curve::ParametricTransformation on a line ===\n\n");
  Handle(Geom_Line) line = new Geom_Line(gp_Pnt(0, 0, 0), gp_Dir(1, 0, 0));

  const double scale2[12]   = {2, 0, 0, 0, 2, 0, 0, 0, 2, 1, 2, 3};
  const double identity[12] = {1, 0, 0, 0, 1, 0, 0, 0, 1, 5, 6, 7};

  std::printf("  GROUPED uniform scale 2, translate (1,2,3): %g\n",
              line->ParametricTransformation(occtTrsfFromMatrix12Grouped(scale2)));
  std::printf("  the SAME array read INTERLEAVED:            %g\n",
              line->ParametricTransformation(occtTrsfFromMatrix12Interleaved(scale2)));
  std::printf("  GROUPED identity, translate (5,6,7):        %g\n",
              line->ParametricTransformation(occtTrsfFromMatrix12Grouped(identity)));
}

int main()
{
  int divergences = comparePart1();
  comparePart1b();
  comparePart2();
  comparePart3();
  return divergences > 0 ? 1 : 0;
}
