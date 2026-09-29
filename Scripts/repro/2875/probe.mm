// Ground truth for #2875: Geom2d_BezierCurve and Geom_BezierCurve disagree with themselves about
// how many poles a Bezier may hold. The constructors bound the pole count at MaxDegree() + 1;
// InsertPoleAfter refuses once the CURRENT count reaches MaxDegree(), one pole short, and the
// header for both classes documents the bound as "the resulting number of poles is greater than
// MaxDegree + 1", which is the constructors' bound and not the one the code applies.
//
// The 3D class writes its InsertPoleAfter guard as a literal `throw`, so it is live in the Release
// kernel. The 2D class writes the same guard as Standard_ConstructionError_Raise_if, which
// No_Exception compiles out (okf/policies/occt-validation-is-compiled-out.md), so on the 2D side
// nothing refuses anything and the pole count runs past the fixed-size static caches that back
// Multiplicities() and KnotSequence().
//
// Run one case per process: some of them are expected to corrupt or crash.
//   ./probe        runs every case in one process
//   ./probe <n>    runs case n alone
//
// Compile and run: Scripts/repro/2875/run.sh

#include <BSplCLib.hxx>
#include <Geom2d_BezierCurve.hxx>
#include <Geom_BezierCurve.hxx>
#include <NCollection_Array1.hxx>
#include <Standard_Failure.hxx>
#include <gp_Pnt.hxx>
#include <gp_Pnt2d.hxx>

#include <cstdio>
#include <cstdlib>
#include <cxxabi.h>
#include <typeinfo>

// Standard_Failure in this kernel has no DynamicType(); name the concrete class off typeid.
static const char* failureName(const Standard_Failure& e)
{
  static char buf[256];
  int         status = 0;
  char*       dem    = abi::__cxa_demangle(typeid(e).name(), nullptr, nullptr, &status);
  snprintf(buf, sizeof(buf), "%s", (status == 0 && dem) ? dem : typeid(e).name());
  free(dem);
  return buf;
}

static occ::handle<Geom_BezierCurve> make3d(int n)
{
  NCollection_Array1<gp_Pnt> poles(1, n);
  for (int i = 1; i <= n; ++i)
    poles(i) = gp_Pnt(double(i), double(i % 3), 0.0);
  return new Geom_BezierCurve(poles);
}

static occ::handle<Geom2d_BezierCurve> make2d(int n)
{
  NCollection_Array1<gp_Pnt2d> poles(1, n);
  for (int i = 1; i <= n; ++i)
    poles(i) = gp_Pnt2d(double(i), double(i % 3));
  return new Geom2d_BezierCurve(poles);
}

#define TRY(label, body)                                                                           \
  do                                                                                               \
  {                                                                                                \
    try                                                                                            \
    {                                                                                              \
      body                                                                                         \
    }                                                                                              \
    catch (Standard_Failure const& e)                                                              \
    {                                                                                              \
      printf("  %-44s -> THREW %s\n", label, failureName(e));                             \
    }                                                                                              \
    catch (...)                                                                                    \
    {                                                                                              \
      printf("  %-44s -> THREW (not a Standard_Failure)\n", label);                                \
    }                                                                                              \
    fflush(stdout);                                                                                \
  } while (0)

// ---------------------------------------------------------------------------------------------
static void case0()
{
  const int md = Geom_BezierCurve::MaxDegree();
  printf("case 0: the bounds, as constants\n");
  printf("  BSplCLib::MaxDegree()           = %d\n", BSplCLib::MaxDegree());
  printf("  Geom_BezierCurve::MaxDegree()   = %d\n", Geom_BezierCurve::MaxDegree());
  printf("  Geom2d_BezierCurve::MaxDegree() = %d\n", Geom2d_BezierCurve::MaxDegree());
  printf("  ctor predicate  nbpoles > MaxDegree()+1  refuses above %d poles\n", md + 1);
  printf("  insert predicate nbpoles >= MaxDegree()  tops the curve out at %d poles\n", md);
  printf("  header text \"resulting number of poles greater than MaxDegree + 1\" would top it\n");
  printf("  out at %d poles, which is the ctor's bound\n", md + 1);
}

// ---------------------------------------------------------------------------------------------
static void case1()
{
  const int md = Geom_BezierCurve::MaxDegree();
  printf("case 1: constructor boundary, both classes\n");
  for (int n : {2, md, md + 1, md + 2})
  {
    char label[96];
    snprintf(label, sizeof(label), "Geom_BezierCurve(%d poles)", n);
    TRY(label, {
      auto c = make3d(n);
      printf("  %-44s -> built, NbPoles %d Degree %d\n", label, c->NbPoles(), c->Degree());
    });
  }
  for (int n : {2, md, md + 1, md + 2})
  {
    char label[96];
    snprintf(label, sizeof(label), "Geom2d_BezierCurve(%d poles)", n);
    TRY(label, {
      auto c = make2d(n);
      printf("  %-44s -> built, NbPoles %d Degree %d\n", label, c->NbPoles(), c->Degree());
    });
  }
}

// ---------------------------------------------------------------------------------------------
static void case2()
{
  const int md = Geom_BezierCurve::MaxDegree();
  printf("case 2: 3D InsertPoleAfter across the boundary (literal throw, live)\n");
  for (int n : {md - 1, md, md + 1})
  {
    char label[96];
    snprintf(label, sizeof(label), "3D %2d poles, InsertPoleAfter(%d)", n, n);
    auto c = make3d(n);
    TRY(label, {
      c->InsertPoleAfter(n, gp_Pnt(99.0, 0.0, 0.0));
      printf("  %-44s -> accepted, NbPoles now %d\n", label, c->NbPoles());
    });
  }
}

// ---------------------------------------------------------------------------------------------
static void case3()
{
  const int md = Geom2d_BezierCurve::MaxDegree();
  printf("case 3: 2D InsertPoleAfter at nbpoles == MaxDegree() (macro, compiled out)\n");
  auto c = make2d(md); // 25 poles
  printf("  before: NbPoles %d Degree %d\n", c->NbPoles(), c->Degree());
  TRY("2D 25 poles, InsertPoleAfter(25)", {
    c->InsertPoleAfter(md, gp_Pnt2d(99.0, 0.0));
    printf("  after : NbPoles %d Degree %d\n", c->NbPoles(), c->Degree());
  });
  // A 26-pole result is exactly what the constructor accepts, so the static caches are in bounds.
  const NCollection_Array1<int>&    mults = c->Multiplicities();
  const NCollection_Array1<double>& fk    = c->KnotSequence();
  printf("  Multiplicities() = [%d, %d]   (sound value [%d, %d])\n",
         mults(1),
         mults(2),
         c->NbPoles(),
         c->NbPoles());
  printf("  KnotSequence().Length() = %d   (sound value %d)\n", fk.Length(), 2 * c->NbPoles());
  gp_Pnt2d p = c->Value(0.5);
  printf("  Value(0.5) = (%.6f, %.6f)\n", p.X(), p.Y());
  printf("  the kernel builds a %d-pole Geom2d_BezierCurve here and it is sound; the 3D twin\n",
         c->NbPoles());
  printf("  refuses the same operation\n");
}

// ---------------------------------------------------------------------------------------------
static void case4()
{
  const int md = Geom2d_BezierCurve::MaxDegree();
  printf("case 4: 2D InsertPoleAfter at nbpoles == MaxDegree()+1, past the static cache\n");
  auto c = make2d(md + 1); // 26 poles, the constructor's own maximum
  printf("  before: NbPoles %d Degree %d\n", c->NbPoles(), c->Degree());
  TRY("2D 26 poles, InsertPoleAfter(26)", {
    c->InsertPoleAfter(md + 1, gp_Pnt2d(99.0, 0.0));
    printf("  after : NbPoles %d Degree %d\n", c->NbPoles(), c->Degree());
  });
  printf("  Multiplicities() indexes a std::array of %d entries at [%d]\n", md + 1, c->NbPoles() - 1);
  fflush(stdout);
  const NCollection_Array1<int>& mults = c->Multiplicities();
  printf("  Multiplicities() = [%d, %d]   (sound value [%d, %d])\n",
         mults(1),
         mults(2),
         c->NbPoles(),
         c->NbPoles());
  fflush(stdout);
  printf("  KnotSequence(), same indexing\n");
  fflush(stdout);
  const NCollection_Array1<double>& fk = c->KnotSequence();
  printf("  KnotSequence().Length() = %d   (sound value %d)\n", fk.Length(), 2 * c->NbPoles());
  fflush(stdout);
  gp_Pnt2d p = c->Value(0.5);
  printf("  Value(0.5) = (%.6f, %.6f)\n", p.X(), p.Y());
  fflush(stdout);
}

// ---------------------------------------------------------------------------------------------
static void case5()
{
  const int md = Geom_BezierCurve::MaxDegree();
  printf("case 5: Increase() agrees with the constructor, not with InsertPoleAfter\n");
  for (int deg : {md, md + 1})
  {
    char label[96];
    snprintf(label, sizeof(label), "3D Increase(%d) from degree 1", deg);
    auto c = make3d(2);
    TRY(label, {
      c->Increase(deg);
      printf("  %-44s -> accepted, NbPoles %d Degree %d\n", label, c->NbPoles(), c->Degree());
    });
  }
  for (int deg : {md, md + 1})
  {
    char label[96];
    snprintf(label, sizeof(label), "2D Increase(%d) from degree 1", deg);
    auto c = make2d(2);
    TRY(label, {
      c->Increase(deg);
      printf("  %-44s -> accepted, NbPoles %d Degree %d\n", label, c->NbPoles(), c->Degree());
    });
  }
}

// ---------------------------------------------------------------------------------------------
static void case6()
{
  const int md = Geom2d_BezierCurve::MaxDegree();
  printf("case 6: how far the 2D side runs unchecked, one insertion at a time\n");
  auto c = make2d(2);
  for (int i = 0; i < 40; ++i)
  {
    int before = c->NbPoles();
    try
    {
      c->InsertPoleAfter(before, gp_Pnt2d(double(before) + 1.0, 0.0));
    }
    catch (Standard_Failure const& e)
    {
      printf("  at %d poles: THREW %s\n", before, failureName(e));
      break;
    }
    if (c->NbPoles() > md + 1)
    {
      printf("  reached %d poles, past the constructor's own maximum of %d\n", c->NbPoles(), md + 1);
      break;
    }
  }
  printf("  final NbPoles = %d, MaxDegree()+1 = %d\n", c->NbPoles(), md + 1);
}

int main(int argc, const char** argv)
{
  void (*cases[])() = {case0, case1, case2, case3, case4, case5, case6};
  const int n       = (int)(sizeof(cases) / sizeof(cases[0]));
  int       only    = (argc > 1) ? atoi(argv[1]) : -1;
  if (argc > 1)
  {
    if (only < 0 || only >= n)
    {
      printf("no such case: %d\n", only);
      return 2;
    }
    cases[only]();
    return 0;
  }
  for (int i = 0; i < n; ++i)
  {
    cases[i]();
    printf("\n");
  }
  return 0;
}
