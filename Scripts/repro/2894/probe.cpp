// Probe for #2894: why an OCCT throw inside BRepFill_Evolved reaches std::terminate on wasm
// while a Standard_DomainError from BRepPrimAPI_MakeBox(0,0,0) is caught.
//
// Pure C++, no Swift, no bridge. Everything runs in ONE translation unit with ONE set of flags,
// so the module's exception configuration cannot be the variable.
//
// The decisive instrument is the terminate handler. When std::terminate is reached because an
// exception was thrown WHILE unwinding another, the C++ ABI makes the SECOND exception the
// current one, so `throw;` inside the handler re-raises it and names it. That is the one fact
// the disassembly cannot supply.

#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <exception>
#include <typeinfo>

#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepBuilderAPI_MakeWire.hxx>
#include <BRepFill_Evolved.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepTools_WireExplorer.hxx>
#include <Geom_Line.hxx>
#include <Geom_Plane.hxx>
#include <Geom_TrimmedCurve.hxx>
#include <NCollection_DataMap.hxx>
#include <NCollection_List.hxx>
#include <Standard_ConstructionError.hxx>
#include <Standard_Failure.hxx>
#include <TopTools_ShapeMapHasher.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Face.hxx>
#include <TopoDS_Wire.hxx>
#include <gp_Ax3.hxx>
#include <gp_Pnt.hxx>

static void report_terminate()
{
  std::printf("PROBE2894 TERMINATE HANDLER REACHED\n");
  if (std::current_exception() == nullptr)
  {
    std::printf("PROBE2894   no active exception (terminate called outright)\n");
  }
  else
  {
    try
    {
      throw;
    }
    catch (const Standard_Failure& f)
    {
      std::printf("PROBE2894   secondary: Standard_Failure %s: %s\n",
                  typeid(f).name(), f.what());
    }
    catch (const std::exception& e)
    {
      std::printf("PROBE2894   secondary: std::exception %s: %s\n", typeid(e).name(), e.what());
    }
    catch (...)
    {
      std::printf("PROBE2894   secondary: unknown type\n");
    }
  }
  std::fflush(stdout);
  std::_Exit(42);
}

// ---------------------------------------------------------------------------
// Case A: the known-catchable path. A degenerate box raises from inside the OCCT
// archive and the catch below fires. #2171's evidence, restated in C++.
// ---------------------------------------------------------------------------
static void caseA()
{
  std::printf("PROBE2894 A: BRepPrimAPI_MakeBox(0,0,0)\n");
  std::fflush(stdout);
  try
  {
    BRepPrimAPI_MakeBox mk(0.0, 0.0, 0.0);
    TopoDS_Shape        s = mk.Shape();
    std::printf("PROBE2894 A: NO THROW, shape null=%d\n", (int)s.IsNull());
  }
  catch (const Standard_Failure& f)
  {
    std::printf("PROBE2894 A: CAUGHT %s: %s\n", typeid(f).name(), f.what());
  }
  catch (...)
  {
    std::printf("PROBE2894 A: CAUGHT (...)\n");
  }
  std::fflush(stdout);
}

static TopoDS_Face spineFace()
{
  gp_Pnt                  p1(0, 0, 0), p2(100, 0, 0), p3(100, 100, 0), p4(0, 100, 0);
  BRepBuilderAPI_MakeWire mw;
  mw.Add(BRepBuilderAPI_MakeEdge(p1, p2).Edge());
  mw.Add(BRepBuilderAPI_MakeEdge(p2, p3).Edge());
  mw.Add(BRepBuilderAPI_MakeEdge(p3, p4).Edge());
  mw.Add(BRepBuilderAPI_MakeEdge(p4, p1).Edge());
  return BRepBuilderAPI_MakeFace(mw.Wire()).Face();
}

static TopoDS_Wire profileWire()
{
  gp_Pnt                  q1(0, 0, 0), q2(0, 0, 20), q3(10, 0, 20);
  BRepBuilderAPI_MakeWire mw;
  mw.Add(BRepBuilderAPI_MakeEdge(q1, q2).Edge());
  mw.Add(BRepBuilderAPI_MakeEdge(q2, q3).Edge());
  return mw.Wire();
}

// ---------------------------------------------------------------------------
// Case B: the issue, with the inputs the failing tests use.
// ---------------------------------------------------------------------------
static void caseB()
{
  std::printf("PROBE2894 B: BRepFill_Evolved::Perform\n");
  std::fflush(stdout);
  try
  {
    TopoDS_Face      spine   = spineFace();
    TopoDS_Wire      profile = profileWire();
    BRepFill_Evolved ev;
    ev.Perform(spine, profile, gp_Ax3(), GeomAbs_Arc, true);
    std::printf("PROBE2894 B: NO THROW, IsDone=%d\n", (int)ev.IsDone());
  }
  catch (const Standard_Failure& f)
  {
    std::printf("PROBE2894 B: CAUGHT %s: %s\n", typeid(f).name(), f.what());
  }
  catch (...)
  {
    std::printf("PROBE2894 B: CAUGHT (...)\n");
  }
  std::fflush(stdout);
}

// ---------------------------------------------------------------------------
// Case C: the hypothesis #2894's last comment proposes. An OCCT throw that unwinds
// through a frame holding exactly the locals PrepareProfile holds. If this
// terminates, "destructors of NCollection locals cannot be unwound through" is
// established without a kernel rebuild. If it is caught, that reading is dead.
// ---------------------------------------------------------------------------
static void throwDeep()
{
  occ::handle<Geom_Line>         line = new Geom_Line(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1));
  occ::handle<Geom_TrimmedCurve> tc   = new Geom_TrimmedCurve(line, 1.0, 1.0);
  std::printf("PROBE2894 C: inner did NOT throw (unexpected), tc null=%d\n", (int)tc.IsNull());
}

static void frameWithNCollectionLocals()
{
  occ::handle<Geom_Plane> plane = new Geom_Plane(gp_Ax3(gp::YOZ()));
  NCollection_DataMap<TopoDS_Shape, TopoDS_Shape, TopTools_ShapeMapHasher> map;
  NCollection_List<TopoDS_Shape>                                          list;
  TopoDS_Face                                                             f = spineFace();
  BRepTools_WireExplorer                                                  exp(profileWire());
  map.Bind(f, f);
  list.Append(f);
  throwDeep();
}

static void caseC()
{
  std::printf("PROBE2894 C: throw unwinding through NCollection locals\n");
  std::fflush(stdout);
  try
  {
    frameWithNCollectionLocals();
    std::printf("PROBE2894 C: NO THROW\n");
  }
  catch (const Standard_Failure& f)
  {
    std::printf("PROBE2894 C: CAUGHT %s: %s\n", typeid(f).name(), f.what());
  }
  catch (...)
  {
    std::printf("PROBE2894 C: CAUGHT (...)\n");
  }
  std::fflush(stdout);
}

// ---------------------------------------------------------------------------
// Case D: the raise itself, with nothing between it and the catch.
// ---------------------------------------------------------------------------
static void caseD()
{
  std::printf("PROBE2894 D: Geom_TrimmedCurve(U1 == U2) directly\n");
  std::fflush(stdout);
  try
  {
    occ::handle<Geom_Line>         line = new Geom_Line(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1));
    occ::handle<Geom_TrimmedCurve> tc   = new Geom_TrimmedCurve(line, 1.0, 1.0);
    std::printf("PROBE2894 D: NO THROW, tc null=%d\n", (int)tc.IsNull());
  }
  catch (const Standard_Failure& f)
  {
    std::printf("PROBE2894 D: CAUGHT %s: %s\n", typeid(f).name(), f.what());
  }
  catch (...)
  {
    std::printf("PROBE2894 D: CAUGHT (...)\n");
  }
  std::fflush(stdout);
}

// ---------------------------------------------------------------------------
// Case E: #2891, the other direction of the same seam. gp_Dir::CrossCross carries
// an INLINE Standard_ConstructionError_Raise_if, so it is live in whichever unit
// expands it. This unit is compiled without No_Exception, exactly as the bridge is,
// so if the raise does not fire here it does not fire in the bridge either.
// ---------------------------------------------------------------------------
static void caseE()
{
  std::printf("PROBE2894 E: gp_Ax3(P, (0,0,1), (0,0,1)) parallel N and Vx\n");
  std::fflush(stdout);
  try
  {
    gp_Ax3 ax3(gp_Pnt(5, 3, 2), gp_Dir(0, 0, 1), gp_Dir(0, 0, 1));
    gp_Ax3 r = ax3.Translated(gp_Vec(1, 2, 3));
    std::printf("PROBE2894 E: NO THROW, location (%g, %g, %g)\n", r.Location().X(),
                r.Location().Y(), r.Location().Z());
  }
  catch (const Standard_Failure& f)
  {
    std::printf("PROBE2894 E: CAUGHT %s: %s\n", typeid(f).name(), f.what());
  }
  catch (...)
  {
    std::printf("PROBE2894 E: CAUGHT (...)\n");
  }
  std::fflush(stdout);
}

// ---------------------------------------------------------------------------
// Case F: the happy path, so the characterisation says whether BRepFill_Evolved
// is broken on wasm or only its refusal is.
// ---------------------------------------------------------------------------
static void caseF()
{
  std::printf("PROBE2894 F: BRepFill_Evolved::Perform, straight vertical profile\n");
  std::fflush(stdout);
  try
  {
    TopoDS_Face             spine = spineFace();
    BRepBuilderAPI_MakeWire mw;
    mw.Add(BRepBuilderAPI_MakeEdge(gp_Pnt(0, 0, 0), gp_Pnt(0, 0, 20)).Edge());
    BRepFill_Evolved ev;
    ev.Perform(spine, mw.Wire(), gp_Ax3(), GeomAbs_Arc, true);
    std::printf("PROBE2894 F: NO THROW, IsDone=%d shapeNull=%d\n", (int)ev.IsDone(),
                (int)ev.Shape().IsNull());
  }
  catch (const Standard_Failure& f)
  {
    std::printf("PROBE2894 F: CAUGHT %s: %s\n", typeid(f).name(), f.what());
  }
  catch (...)
  {
    std::printf("PROBE2894 F: CAUGHT (...)\n");
  }
  std::fflush(stdout);
}

int main(int argc, char** argv)
{
  std::set_terminate(report_terminate);
  const char* only  = (argc > 1) ? argv[1] : "AEDCFB";
  auto        wants = [&](char c) { return std::strchr(only, c) != nullptr; };
  if (wants('A'))
    caseA();
  if (wants('E'))
    caseE();
  if (wants('D'))
    caseD();
  if (wants('C'))
    caseC();
  if (wants('F'))
    caseF();
  if (wants('B'))
    caseB();
  std::printf("PROBE2894 DONE\n");
  std::fflush(stdout);
  return 0;
}
