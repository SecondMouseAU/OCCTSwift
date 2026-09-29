// #2789: where does BRepCheck_Analyzer fault on a surface-less face that carries a wire?
//
// #2777 measured the fault and deliberately did not locate it:
//
//   analyzer box           IsValid -> true
//   analyzer compound      IsValid -> false        (no crash)
//   analyzer bare          IsValid -> false        (no crash)
//   analyzer withwire      SIGSEGV, exit 139
//   analyzer barewithwire  SIGSEGV, exit 139
//
// The edgeless rows are the interesting negative: the analyzer calls an edgeless surface-less face
// invalid, which is the right answer, so whatever faults needs the wire.
//
// Read first, in the pinned Libraries/occt-src, then confirmed by measurement below. The FACE branch
// of BRepCheck_ParallelAnalyzer::operator() (BRepCheck_Analyzer.cxx:127-303) makes exactly three
// kinds of call per face, in this order:
//
//   1. BRepCheck_Vertex::InContext(face)  for every vertex   BRepCheck_Analyzer.cxx:133
//   2. BRepCheck_Edge::InContext(face)    for every edge     BRepCheck_Analyzer.cxx:166
//   3. BRepCheck_Wire::InContext(face)    for every wire     BRepCheck_Analyzer.cxx:210
//   4. BRepCheck_Face::OrientationOfWires(true)              BRepCheck_Analyzer.cxx:272
//
// and each sits inside `try { OCC_CATCH_SIGNALS ... } catch (Standard_Failure const&)`. OCCT's own
// translation units are compiled with OCC_CONVERT_SIGNALS, so those handlers are live, but they can
// only convert a signal a handler installed by OSD::SetSignal raised, and no bridge BRepCheck entry
// point installs one. So a catchable Standard_Failure is absorbed and recorded as a fail status, and
// an OS signal with no OSD handler in the process is not.
//
// THE READ WAS WRONG THE FIRST TIME, and the case that killed it is `analyzer <fixture> no 0`.
// The prediction from reading was step (3), BRepCheck_Wire::SelfIntersect, on the strength of
// BRepAdaptor_Surface::Initialize returning silently for a null surface
// (BRepAdaptor_Surface.cxx:66-69) and leaving the adaptor default-constructed, so that
// BRepCheck_Wire.cxx:1203's `HS->Value(...)` would go through a null GeomAdaptor_Surface handle.
// SelfIntersect runs only `if (myGctrl)` (BRepCheck_Wire.cxx:230-234), and the fixture exits 139
// with geometric controls OFF as well as on, so it is not that line. That prediction is left in
// place rather than deleted, because it is the shape the next person will also reach for.
//
// MEASURED, the fault is step (2), and one frame in:
//
//   BRepCheck_Edge::InContext(face)                       BRepCheck_Edge.cxx:263
//     case TopAbs_FACE, guarded by `if (!myCref.IsNull())` BRepCheck_Edge.cxx:308-311
//       Su = TF->Surface();                               BRepCheck_Edge.cxx:336   null, untested
//       while (itcr.More())                               BRepCheck_Edge.cxx:342
//         cr->IsCurveOnSurface(Su, L)                      BRepCheck_Edge.cxx:348
//           return (S == mySurface) && ...                BRep_CurveOnSurface.cxx:62  handle compare
//       if (!pcurvefound)                                 BRepCheck_Edge.cxx:460
//         dtyp = Su->DynamicType();                       BRepCheck_Edge.cxx:463   <- HERE
//
// Three things make that line the one and not a candidate among several.
//
// It is OUTSIDE `if (myGctrl)`, which is why the geometric-controls-off row faults too, and the two
// `if (myGctrl)` blocks in the same function (lines 395 and 479) are the only other places `Su` is
// touched. The comparison at line 348 is a handle equality test, so a null `Su` matches no
// representation, `pcurvefound` stays false and the `!pcurvefound` branch is the one taken: the
// pcurves the fixture's edges carry are on the box plane they came from, not on this face, which has
// no surface to carry them.
//
// And it is the SAME FUNCTION as #2746's fault at a DIFFERENT line with the opposite precondition.
// #2746 needs a pcurve that DOES match the face's surface, so it takes the `pcurvefound` branch and
// dies on a failed `down_cast<GeomAdaptor_Curve>`; this needs a face with no surface at all, so no
// pcurve can match and it dies on the null `Su` in the branch #2746 never reaches. That is why
// `occtShapeHasPCurveOnlyEdge` is at all 20 analyzer sites and does not cover this: the two
// predicates are disjoint, not nested.
//
// The `surfnopcurve` fixture below is the control that closes it. A face WITH a plane surface whose
// edges carry no pcurve on it reaches line 463 by the same route, with `pcurvefound` false, and
// survives, because `Su` is not null. So the branch is reached on both and the null surface is the
// whole difference.
//
// One case per process, because a reproducing case is uncatchable and takes the rest of the
// transcript with it. That is #2777's pattern, which is #2773's, which is #2750's. run.sh drives it.
//
// Cases, where <fixture> is one of compound | bare | withwire | barewithwire | withpolywire |
// surfnopcurve | box, <sig> is no | yes for OSD::SetSignal (what the bridge's occtEnsureSignals()
// does once per process), and <geom> is 1 | 0 for the analyzer's and the checkers'
// geometric-controls flag:
//
//   describe                                the fixtures, in memory
//   describe-file      <file>               ... read back off disk
//   analyzer           <fixture> <sig> <geom>   BRepCheck_Analyzer(shape, geom).IsValid()
//   analyzer-sub       <fixture> <sig>      IsValid(subshape) per sub-shape, the #2755 half
//   vertex-incontext   <fixture> <sig>      step 1 above, alone
//   edge-incontext     <fixture> <sig> <geom>   step 2 above, alone: the faulting step
//   wire-incontext     <fixture> <sig> <geom>   step 3 above, alone
//   wire-selfintersect <fixture> <sig>      BRepCheck_Wire::SelfIntersect(face, ...) alone
//   wire-closed        <fixture> <sig>      BRepCheck_Wire::Closed() alone
//   wire-orientation   <fixture> <sig>      BRepCheck_Wire::Orientation(face) alone
//   wire-closed2d      <fixture> <sig>      BRepCheck_Wire::Closed2d(face) alone
//   face-wires         <fixture> <sig>      BRepCheck_Face::OrientationOfWires(true), step 4 alone
//   makefaceplane      <fixture>            the one vacuous guard site, measured not argued
//   algocheck          <fixture> <sig>      BRepAlgoAPI_Check, which constructs one for you
//   subchecker         <fixture> <sig>      every other BRepCheck entry point the bridge reaches
//   dynamictype        <fixture> <sig>      line 463 itself: TF->Surface()->DynamicType()
//   adaptor            <fixture> <sig>      the killed prediction: BRepAdaptor_Surface then Value
//   pcurve             <fixture>            what BRep_Tool::CurveOnSurface(E, F) answers here
//   crefs              <fixture>            myCref's precondition: 3D curve and pcurve per edge
//   brep-write         <fixture> <file>     BRepTools::Write, to remake a committed fixture

#include <BRepAdaptor_Surface.hxx>
#include <BRepAlgoAPI_Check.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepBuilderAPI_MakePolygon.hxx>
#include <BRepCheck_Analyzer.hxx>
#include <BRepCheck_Edge.hxx>
#include <BRepCheck_Face.hxx>
#include <BRepCheck_Status.hxx>
#include <BRepCheck_Vertex.hxx>
#include <BRepCheck_Wire.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepTools.hxx>
#include <BRep_Builder.hxx>
#include <BRep_CurveRepresentation.hxx>
#include <BRep_TEdge.hxx>
#include <BRep_TFace.hxx>
#include <BRep_Tool.hxx>
#include <Geom2d_Curve.hxx>
#include <Geom_Plane.hxx>
#include <Geom_Surface.hxx>
#include <Precision.hxx>
#include <OSD.hxx>
#include <Standard_Failure.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Compound.hxx>
#include <TopoDS_Face.hxx>
#include <TopoDS_Shape.hxx>
#include <TopoDS_Wire.hxx>

#include <csignal>
#include <typeinfo>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <unistd.h>

namespace
{

void segvHandler(int theSignal)
{
  const char* aMessage = "\n*** SIGSEGV / SIGBUS: the process died ***\n";
  write(STDERR_FILENO, aMessage, std::strlen(aMessage));
  std::signal(theSignal, SIG_DFL);
  raise(theSignal);
}

//! A face built by BRep_Builder::MakeFace alone: a TFace with no surface, no location, no wires.
//! The same construction as #2773's and #2777's probes, so the three sets of rows are comparable.
TopoDS_Face makeSurfacelessFace()
{
  BRep_Builder aBuilder;
  TopoDS_Face  aFace;
  aBuilder.MakeFace(aFace);
  return aFace;
}

//! The same TFace, carrying the outer wire of a real box face, so it has edges with 3D curves and
//! pcurves against a surface that is not this face's, because this face has none.
TopoDS_Face makeSurfacelessFaceWithWire()
{
  BRep_Builder aBuilder;
  TopoDS_Face  aFace = makeSurfacelessFace();
  TopoDS_Shape aBox  = BRepPrimAPI_MakeBox(10.0, 20.0, 30.0).Shape();
  for (TopExp_Explorer aFaceExp(aBox, TopAbs_FACE); aFaceExp.More(); aFaceExp.Next())
  {
    const TopoDS_Face& aBoxFace = TopoDS::Face(aFaceExp.Current());
    TopoDS_Wire        anOuter  = BRepTools::OuterWire(aBoxFace);
    if (!anOuter.IsNull())
    {
      aBuilder.Add(aFace, anOuter);
      break;
    }
  }
  return aFace;
}

//! The same TFace carrying a wire whose edges have a 3D curve and NO pcurve anywhere, so that
//! `pcurvefound` is false at BRepCheck_Edge.cxx:460 for a reason that has nothing to do with the
//! face's own surface. If the fault needed a pcurve the way #2746's does, this fixture would survive.
TopoDS_Face makeSurfacelessFaceWithPolygonWire()
{
  BRep_Builder aBuilder;
  TopoDS_Face  aFace = makeSurfacelessFace();
  BRepBuilderAPI_MakePolygon aPolygon;
  aPolygon.Add(gp_Pnt(0.0, 0.0, 0.0));
  aPolygon.Add(gp_Pnt(10.0, 0.0, 0.0));
  aPolygon.Add(gp_Pnt(10.0, 20.0, 0.0));
  aPolygon.Add(gp_Pnt(0.0, 20.0, 0.0));
  aPolygon.Close();
  if (aPolygon.IsDone())
  {
    aBuilder.Add(aFace, aPolygon.Wire());
  }
  return aFace;
}

//! The control that pins line 463 rather than merely reaching it: a face WITH a plane surface,
//! carrying the same pcurve-free polygon wire. `pcurvefound` is false here too, so
//! BRepCheck_Edge.cxx:463 runs, and `Su` is not null, so it has something to ask DynamicType() of.
TopoDS_Face makePlaneFaceWithPolygonWire()
{
  BRep_Builder              aBuilder;
  TopoDS_Face               aFace;
  occ::handle<Geom_Surface> aPlane = new Geom_Plane(gp_Pnt(0.0, 0.0, 0.0), gp_Dir(0.0, 0.0, 1.0));
  aBuilder.MakeFace(aFace, aPlane, Precision::Confusion());
  BRepBuilderAPI_MakePolygon aPolygon;
  aPolygon.Add(gp_Pnt(0.0, 0.0, 0.0));
  aPolygon.Add(gp_Pnt(10.0, 0.0, 0.0));
  aPolygon.Add(gp_Pnt(10.0, 20.0, 0.0));
  aPolygon.Add(gp_Pnt(0.0, 20.0, 0.0));
  aPolygon.Close();
  if (aPolygon.IsDone())
  {
    aBuilder.Add(aFace, aPolygon.Wire());
  }
  return aFace;
}

TopoDS_Shape makeCompound(const TopoDS_Shape& theShape)
{
  BRep_Builder    aBuilder;
  TopoDS_Compound aCompound;
  aBuilder.MakeCompound(aCompound);
  aBuilder.Add(aCompound, theShape);
  return aCompound;
}

TopoDS_Shape fixture(const char* theName)
{
  // A fixture name ending in .brep is a path, so every case below can be driven against a committed
  // fixture as well as against a shape built here. That is how #2746's own
  // brepcheck-incontext-pcurve-only-edge.brep gets measured against the sites this issue widens to.
  const size_t aLength = std::strlen(theName);
  if (aLength > 5 && std::strcmp(theName + aLength - 5, ".brep") == 0)
  {
    BRep_Builder aBuilder;
    TopoDS_Shape aShape;
    if (!BRepTools::Read(aShape, theName, aBuilder))
    {
      std::printf("  could not read %s\n", theName);
      return TopoDS_Shape();
    }
    return aShape;
  }
  if (std::strcmp(theName, "compound") == 0)
  {
    return makeCompound(makeSurfacelessFace());
  }
  if (std::strcmp(theName, "bare") == 0)
  {
    return makeSurfacelessFace();
  }
  if (std::strcmp(theName, "withwire") == 0)
  {
    return makeCompound(makeSurfacelessFaceWithWire());
  }
  if (std::strcmp(theName, "barewithwire") == 0)
  {
    return makeSurfacelessFaceWithWire();
  }
  if (std::strcmp(theName, "withpolywire") == 0)
  {
    return makeSurfacelessFaceWithPolygonWire();
  }
  if (std::strcmp(theName, "surfnopcurve") == 0)
  {
    return makePlaneFaceWithPolygonWire();
  }
  if (std::strcmp(theName, "box") == 0)
  {
    return BRepPrimAPI_MakeBox(10.0, 20.0, 30.0).Shape();
  }
  std::printf("  unknown fixture '%s'\n", theName);
  return TopoDS_Shape();
}

//! occtShapeSurfacelessFaceCount from OCCTBridge_Internal.h, restated so the probe reports the same
//! number the bridge's guard reads. Not shared: the bridge header pulls in the whole bridge.
int occtSurfacelessFaceCount(const TopoDS_Shape& theShape)
{
  int aFound = 0;
  for (TopExp_Explorer aFaceExp(theShape, TopAbs_FACE); aFaceExp.More(); aFaceExp.Next())
  {
    TopLoc_Location aLoc;
    if (BRep_Tool::Surface(TopoDS::Face(aFaceExp.Current()), aLoc).IsNull())
    {
      aFound++;
    }
  }
  return aFound;
}

//! The first face of a fixture, which is the shape every per-checker case below needs as its context.
TopoDS_Face firstFace(const TopoDS_Shape& theShape)
{
  for (TopExp_Explorer anExp(theShape, TopAbs_FACE); anExp.More(); anExp.Next())
  {
    return TopoDS::Face(anExp.Current());
  }
  return TopoDS_Face();
}

void describeShape(const char* theLabel, const TopoDS_Shape& theShape)
{
  if (theShape.IsNull())
  {
    std::printf("  %-34s NULL SHAPE\n", theLabel);
    return;
  }
  int aFaces           = 0;
  int aSurfacelessFace = 0;
  int aNoEdgeFace      = 0;
  int aBoth            = 0;
  int aWires           = 0;
  int anEdgesTotal     = 0;
  int aVerticesTotal   = 0;
  for (TopExp_Explorer aFaceExp(theShape, TopAbs_FACE); aFaceExp.More(); aFaceExp.Next())
  {
    const TopoDS_Face& aFace = TopoDS::Face(aFaceExp.Current());
    aFaces++;
    int anEdges = 0;
    for (TopExp_Explorer anEdgeExp(aFace, TopAbs_EDGE); anEdgeExp.More(); anEdgeExp.Next())
    {
      anEdges++;
    }
    TopLoc_Location aLoc;
    const bool      aNullSurf = BRep_Tool::Surface(aFace, aLoc).IsNull();
    if (aNullSurf)
    {
      aSurfacelessFace++;
    }
    if (anEdges == 0)
    {
      aNoEdgeFace++;
    }
    if (aNullSurf && anEdges == 0)
    {
      aBoth++;
    }
  }
  for (TopExp_Explorer anExp(theShape, TopAbs_WIRE); anExp.More(); anExp.Next())
  {
    aWires++;
  }
  for (TopExp_Explorer anExp(theShape, TopAbs_EDGE); anExp.More(); anExp.Next())
  {
    anEdgesTotal++;
  }
  for (TopExp_Explorer anExp(theShape, TopAbs_VERTEX); anExp.More(); anExp.Next())
  {
    aVerticesTotal++;
  }
  std::printf("  %-22s type=%d faces=%d null-surface=%d edgeless=%d BOTH=%d wires=%d edges=%d "
              "vertices=%d\n",
              theLabel,
              static_cast<int>(theShape.ShapeType()),
              aFaces,
              aSurfacelessFace,
              aNoEdgeFace,
              aBoth,
              aWires,
              anEdgesTotal,
              aVerticesTotal);
}

//! OSD::SetSignal, the axis that decides whether OCC_CATCH_SIGNALS could convert the fault. No
//! BRepCheck entry point in the bridge installs one, so `no` is the shipped disposition.
void applySignalDisposition(const char* theArg)
{
  if (std::strcmp(theArg, "yes") == 0)
  {
    OSD::SetSignal(false);
    std::printf("  OSD::SetSignal(false) installed\n");
  }
  else
  {
    std::signal(SIGSEGV, segvHandler);
    std::signal(SIGBUS, segvHandler);
    std::printf("  no OSD handler, bare SIGSEGV reporter only\n");
  }
  std::fflush(stdout);
}

const char* statusName(BRepCheck_Status theStatus)
{
  switch (theStatus)
  {
    case BRepCheck_NoError:
      return "NoError";
    case BRepCheck_EmptyWire:
      return "EmptyWire";
    case BRepCheck_NotConnected:
      return "NotConnected";
    case BRepCheck_NoCurveOnSurface:
      return "NoCurveOnSurface";
    case BRepCheck_SelfIntersectingWire:
      return "SelfIntersectingWire";
    case BRepCheck_NoSurface:
      return "NoSurface";
    case BRepCheck_InvalidCurveOnSurface:
      return "InvalidCurveOnSurface";
    case BRepCheck_BadOrientationOfSubshape:
      return "BadOrientationOfSubshape";
    case BRepCheck_NotClosed:
      return "NotClosed";
    default:
      break;
  }
  static char aBuffer[32];
  std::snprintf(aBuffer, sizeof(aBuffer), "status(%d)", static_cast<int>(theStatus));
  return aBuffer;
}

void printStatuses(const char* theLabel, const NCollection_List<BRepCheck_Status>& theList)
{
  std::printf("  %-24s", theLabel);
  for (NCollection_List<BRepCheck_Status>::Iterator anIt(theList); anIt.More(); anIt.Next())
  {
    std::printf(" %s", statusName(anIt.Value()));
  }
  std::printf("\n");
  std::fflush(stdout);
}

int usage()
{
  std::printf("see the case list at the top of probe.mm\n");
  return 2;
}

} // namespace

int main(int argc, char** argv)
{
  if (argc < 2)
  {
    return usage();
  }
  const char* aCase = argv[1];

  if (std::strcmp(aCase, "describe") == 0)
  {
    const char* aNames[] =
      {"box", "compound", "bare", "withwire", "barewithwire", "withpolywire", "surfnopcurve"};
    for (const char* aName : aNames)
    {
      describeShape(aName, fixture(aName));
    }
    return 0;
  }

  if (std::strcmp(aCase, "describe-file") == 0)
  {
    if (argc < 3)
    {
      return usage();
    }
    BRep_Builder aBuilder;
    TopoDS_Shape aShape;
    if (!BRepTools::Read(aShape, argv[2], aBuilder))
    {
      std::printf("  could not read %s\n", argv[2]);
      return 1;
    }
    describeShape(argv[2], aShape);
    return 0;
  }

  if (std::strcmp(aCase, "brep-write") == 0)
  {
    if (argc < 4)
    {
      return usage();
    }
    const TopoDS_Shape aShape = fixture(argv[2]);
    if (aShape.IsNull())
    {
      return 1;
    }
    const bool aWritten = BRepTools::Write(aShape, argv[3]) == true;
    std::printf("  wrote %s: %s\n", argv[3], aWritten ? "true" : "false");
    return aWritten ? 0 : 1;
  }

  if (argc < 3)
  {
    return usage();
  }
  const TopoDS_Shape aShape = fixture(argv[2]);
  if (aShape.IsNull())
  {
    return 1;
  }
  const char* aSig = argc > 3 ? argv[3] : "no";

  if (std::strcmp(aCase, "analyzer") == 0)
  {
    const bool aGeom = argc > 4 ? std::strcmp(argv[4], "0") != 0 : true;
    applySignalDisposition(aSig);
    std::printf("  geometric controls = %s\n", aGeom ? "true" : "false");
    std::fflush(stdout);
    try
    {
      BRepCheck_Analyzer anAnalyzer(aShape, aGeom);
      std::printf("  IsValid -> %s\n", anAnalyzer.IsValid() ? "true" : "false");
    }
    catch (const Standard_Failure& anException)
    {
      std::printf("  CAUGHT %s: %s\n",
                  typeid(anException).name(),
                  anException.GetMessageString() ? anException.GetMessageString() : "");
      return 1;
    }
    return 0;
  }

  if (std::strcmp(aCase, "analyzer-sub") == 0)
  {
    // #2755: BRepCheck_Analyzer::Perform() walks the whole parent whichever sub-shape is asked
    // after, so this case exists to show that "ask about one vertex" is not a narrower operation
    // than "ask about the shape". It is the same walk.
    applySignalDisposition(aSig);
    try
    {
      BRepCheck_Analyzer anAnalyzer(aShape, true);
      for (TopExp_Explorer anExp(aShape, TopAbs_VERTEX); anExp.More(); anExp.Next())
      {
        std::printf("  IsValid(vertex) -> %s\n", anAnalyzer.IsValid(anExp.Current()) ? "true" : "false");
        break;
      }
    }
    catch (const Standard_Failure& anException)
    {
      std::printf("  CAUGHT %s\n", typeid(anException).name());
      return 1;
    }
    return 0;
  }

  const TopoDS_Face aFace = firstFace(aShape);
  if (aFace.IsNull())
  {
    std::printf("  no face in fixture\n");
    return 1;
  }
  TopLoc_Location aFaceLoc;
  std::printf("  face surface null = %s\n",
              BRep_Tool::Surface(aFace, aFaceLoc).IsNull() ? "true" : "false");
  std::fflush(stdout);

  if (std::strcmp(aCase, "vertex-incontext") == 0)
  {
    applySignalDisposition(aSig);
    int aCount = 0;
    for (TopExp_Explorer anExp(aFace, TopAbs_VERTEX); anExp.More(); anExp.Next())
    {
      BRepCheck_Vertex aChecker(TopoDS::Vertex(anExp.Current()));
      aChecker.InContext(aFace);
      aCount++;
    }
    std::printf("  %d vertices checked in context, no fault\n", aCount);
    return 0;
  }

  if (std::strcmp(aCase, "edge-incontext") == 0)
  {
    const bool aGeom = argc > 4 ? std::strcmp(argv[4], "0") != 0 : true;
    applySignalDisposition(aSig);
    std::printf("  geometric controls = %s\n", aGeom ? "true" : "false");
    std::fflush(stdout);
    int aCount = 0;
    for (TopExp_Explorer anExp(aFace, TopAbs_EDGE); anExp.More(); anExp.Next())
    {
      BRepCheck_Edge aChecker(TopoDS::Edge(anExp.Current()));
      aChecker.GeometricControls(aGeom);
      try
      {
        aChecker.InContext(aFace);
        printStatuses("edge in context", aChecker.StatusOnShape(aFace));
      }
      catch (const Standard_Failure& anException)
      {
        std::printf("  CAUGHT %s on edge %d\n", typeid(anException).name(), aCount);
      }
      aCount++;
    }
    std::printf("  %d edges checked in context, no fault\n", aCount);
    return 0;
  }

  if (std::strcmp(aCase, "wire-incontext") == 0)
  {
    const bool aGeom = argc > 4 ? std::strcmp(argv[4], "0") != 0 : true;
    applySignalDisposition(aSig);
    std::printf("  geometric controls = %s\n", aGeom ? "true" : "false");
    int aCount = 0;
    for (TopExp_Explorer anExp(aFace, TopAbs_WIRE); anExp.More(); anExp.Next())
    {
      BRepCheck_Wire aChecker(TopoDS::Wire(anExp.Current()));
      aChecker.GeometricControls(aGeom);
      try
      {
        aChecker.InContext(aFace);
        printStatuses("wire in context", aChecker.StatusOnShape(aFace));
      }
      catch (const Standard_Failure& anException)
      {
        std::printf("  CAUGHT %s\n", typeid(anException).name());
      }
      aCount++;
    }
    std::printf("  %d wires checked in context, no fault\n", aCount);
    return 0;
  }

  if (std::strcmp(aCase, "wire-selfintersect") == 0 || std::strcmp(aCase, "wire-closed") == 0
      || std::strcmp(aCase, "wire-orientation") == 0 || std::strcmp(aCase, "wire-closed2d") == 0)
  {
    applySignalDisposition(aSig);
    for (TopExp_Explorer anExp(aFace, TopAbs_WIRE); anExp.More(); anExp.Next())
    {
      BRepCheck_Wire aChecker(TopoDS::Wire(anExp.Current()));
      aChecker.GeometricControls(true);
      try
      {
        BRepCheck_Status aStatus = BRepCheck_NoError;
        if (std::strcmp(aCase, "wire-selfintersect") == 0)
        {
          TopoDS_Edge anE1, anE2;
          aStatus = aChecker.SelfIntersect(aFace, anE1, anE2, false);
        }
        else if (std::strcmp(aCase, "wire-closed") == 0)
        {
          aStatus = aChecker.Closed(false);
        }
        else if (std::strcmp(aCase, "wire-orientation") == 0)
        {
          aStatus = aChecker.Orientation(aFace, false);
        }
        else
        {
          aStatus = aChecker.Closed2d(aFace, false);
        }
        std::printf("  %s -> %s\n", aCase, statusName(aStatus));
      }
      catch (const Standard_Failure& anException)
      {
        std::printf("  CAUGHT %s: %s\n",
                    typeid(anException).name(),
                    anException.GetMessageString() ? anException.GetMessageString() : "");
      }
      break;
    }
    return 0;
  }

  if (std::strcmp(aCase, "face-wires") == 0)
  {
    applySignalDisposition(aSig);
    BRepCheck_Face aChecker(aFace);
    aChecker.GeometricControls(true);
    try
    {
      const BRepCheck_Status aStatus = aChecker.OrientationOfWires(false);
      std::printf("  OrientationOfWires -> %s\n", statusName(aStatus));
    }
    catch (const Standard_Failure& anException)
    {
      std::printf("  CAUGHT %s\n", typeid(anException).name());
    }
    return 0;
  }

  if (std::strcmp(aCase, "adaptor") == 0)
  {
    // The line itself. BRepAdaptor_Surface::Initialize returns silently on a null surface
    // (BRepAdaptor_Surface.cxx:66-69), leaving the adaptor default-constructed, and then every
    // HS->... call in BRepCheck_Wire::SelfIntersect goes through a null GeomAdaptor_Surface handle.
    applySignalDisposition(aSig);
    BRepAdaptor_Surface anAdaptor;
    try
    {
      anAdaptor.Initialize(aFace, false);
      std::printf("  Initialize returned with no exception\n");
    }
    catch (const Standard_Failure& anException)
    {
      std::printf("  Initialize CAUGHT %s\n", typeid(anException).name());
      return 1;
    }
    std::printf("  calling BRepAdaptor_Surface::Value(0, 0) ...\n");
    std::fflush(stdout);
    try
    {
      const gp_Pnt aPoint = anAdaptor.Value(0.0, 0.0);
      std::printf("  Value -> (%g, %g, %g)\n", aPoint.X(), aPoint.Y(), aPoint.Z());
    }
    catch (const Standard_Failure& anException)
    {
      std::printf("  Value CAUGHT %s\n", typeid(anException).name());
    }
    return 0;
  }

  if (std::strcmp(aCase, "makefaceplane") == 0)
  {
    // The one site where the surface clause is provably vacuous, measured rather than argued:
    // OCCTBridge.mm's inner analyzer takes `BRepBuilderAPI_MakeFace(wire, OnlyPlane=true).Face()`,
    // and BRepLib_MakeFace's wire constructor returns IsDone() only after
    // BRepLib_FindSurface::Found() (BRepLib_MakeFace.cxx:194-198), then builds the face with
    // FS.Surface() at line 206. So a face that branch reaches always has a surface.
    int aFaces = 0;
    for (TopExp_Explorer aWireExp(aShape, TopAbs_WIRE); aWireExp.More(); aWireExp.Next())
    {
      BRepBuilderAPI_MakeFace aMaker(TopoDS::Wire(aWireExp.Current()), true);
      if (!aMaker.IsDone())
      {
        std::printf("  wire %d: MakeFace not done\n", aFaces);
        aFaces++;
        continue;
      }
      TopLoc_Location aLoc;
      std::printf("  wire %d: IsDone, face surface null = %s, surfacelessFaceCount = %d\n",
                  aFaces,
                  BRep_Tool::Surface(aMaker.Face(), aLoc).IsNull() ? "true" : "false",
                  occtSurfacelessFaceCount(aMaker.Face()));
      aFaces++;
    }
    std::printf("  %d wires\n", aFaces);
    return 0;
  }

  if (std::strcmp(aCase, "algocheck") == 0)
  {
    // The #2798-shaped widening: a bridge site that reaches the faulting frame with no
    // `BRepCheck_Analyzer` text anywhere in the bridge. BRepAlgoAPI_Check::Perform runs
    // BOPAlgo_ArgumentAnalyzer and then constructs `BRepCheck_Analyzer(myS1)` unconditionally at
    // BRepAlgoAPI_Check.cxx:92, and `(myS2)` at :94. Driven exactly the way
    // OCCTShapeBooleanCheckSingle does, `catch (...)` included, because the question is whether the
    // bridge's own catch is enough.
    applySignalDisposition(aSig);
    try
    {
      BRepAlgoAPI_Check aCheck(aShape, true, true);
      std::printf("  IsValid -> %s\n", aCheck.IsValid() ? "true" : "false");
    }
    catch (...)
    {
      std::printf("  CAUGHT something the bridge's catch (...) would also catch\n");
    }
    return 0;
  }

  if (std::strcmp(aCase, "subchecker") == 0)
  {
    // Every OTHER BRepCheck entry point the bridge reaches, driven the way the bridge drives it.
    // checkSubShape in OCCTBridge_Healing_Fix.mm calls Minimum() and nothing else; the four
    // OCCTBRepCheckFace* functions in OCCTBridge_Healing_Analysis.mm call IntersectWires,
    // ClassifyWires and OrientationOfWires. None of them calls InContext, which is where line 463
    // lives, so the prediction is that all of them cope. Measured because the prediction above this
    // one was wrong.
    applySignalDisposition(aSig);
    try
    {
      BRepCheck_Face aFaceChecker(aFace);
      aFaceChecker.GeometricControls(true);
      std::printf("  Face::Minimum ...\n");
      std::fflush(stdout);
      aFaceChecker.Minimum();
      printStatuses("Face::Minimum", aFaceChecker.Status());
      std::printf("  Face::IntersectWires -> %s\n", statusName(aFaceChecker.IntersectWires(false)));
      std::fflush(stdout);
      std::printf("  Face::ClassifyWires -> %s\n", statusName(aFaceChecker.ClassifyWires(false)));
      std::fflush(stdout);
      std::printf("  Face::OrientationOfWires -> %s\n",
                  statusName(aFaceChecker.OrientationOfWires(false)));
    }
    catch (const Standard_Failure& anException)
    {
      std::printf("  Face CAUGHT %s\n", typeid(anException).name());
    }
    std::fflush(stdout);
    for (TopExp_Explorer anExp(aFace, TopAbs_EDGE); anExp.More(); anExp.Next())
    {
      try
      {
        BRepCheck_Edge anEdgeChecker(TopoDS::Edge(anExp.Current()));
        anEdgeChecker.Minimum();
        printStatuses("Edge::Minimum", anEdgeChecker.Status());
      }
      catch (const Standard_Failure& anException)
      {
        std::printf("  Edge CAUGHT %s\n", typeid(anException).name());
      }
      break;
    }
    for (TopExp_Explorer anExp(aFace, TopAbs_WIRE); anExp.More(); anExp.Next())
    {
      try
      {
        BRepCheck_Wire aWireChecker(TopoDS::Wire(anExp.Current()));
        aWireChecker.Minimum();
        printStatuses("Wire::Minimum", aWireChecker.Status());
      }
      catch (const Standard_Failure& anException)
      {
        std::printf("  Wire CAUGHT %s\n", typeid(anException).name());
      }
      break;
    }
    for (TopExp_Explorer anExp(aFace, TopAbs_VERTEX); anExp.More(); anExp.Next())
    {
      try
      {
        BRepCheck_Vertex aVertexChecker(TopoDS::Vertex(anExp.Current()));
        aVertexChecker.Minimum();
        printStatuses("Vertex::Minimum", aVertexChecker.Status());
      }
      catch (const Standard_Failure& anException)
      {
        std::printf("  Vertex CAUGHT %s\n", typeid(anException).name());
      }
      break;
    }
    std::printf("  every sub-checker returned, no fault\n");
    return 0;
  }

  if (std::strcmp(aCase, "dynamictype") == 0)
  {
    // BRepCheck_Edge.cxx:463 on its own, with nothing above it: `Su = TF->Surface()` then
    // `Su->DynamicType()`. Line 336 fetches the handle through the TFace cast rather than through
    // BRep_Tool::Surface, so the probe does the same thing the kernel line does.
    applySignalDisposition(aSig);
    const occ::handle<BRep_TFace> aTFace = occ::down_cast<BRep_TFace>(aFace.TShape());
    std::printf("  TFace null = %s\n", aTFace.IsNull() ? "true" : "false");
    const occ::handle<Geom_Surface>& aSurface = aTFace->Surface();
    std::printf("  TF->Surface() null = %s\n", aSurface.IsNull() ? "true" : "false");
    std::printf("  calling Su->DynamicType() ...\n");
    std::fflush(stdout);
    try
    {
      const occ::handle<Standard_Type> aType = aSurface->DynamicType();
      std::printf("  DynamicType -> %s\n", aType->Name());
    }
    catch (const Standard_Failure& anException)
    {
      std::printf("  CAUGHT %s\n", typeid(anException).name());
    }
    return 0;
  }

  if (std::strcmp(aCase, "crefs") == 0)
  {
    // The precondition on the whole TopAbs_FACE branch: BRepCheck_Edge::Minimum sets myCref from the
    // edge's 3D curve representation, and BRepCheck_Edge.cxx:308 runs the branch only if it is not
    // null. An edge with no 3D curve at all never reaches line 463.
    int aCount = 0;
    for (TopExp_Explorer anExp(aFace, TopAbs_EDGE); anExp.More(); anExp.Next())
    {
      const TopoDS_Edge& anEdge = TopoDS::Edge(anExp.Current());
      TopLoc_Location    aLoc;
      double             aFirst = 0.0, aLast = 0.0;
      const bool aHasCurve3d = !BRep_Tool::Curve(anEdge, aLoc, aFirst, aLast).IsNull();
      int        aPCurves    = 0;
      const occ::handle<BRep_TEdge> aTEdge = occ::down_cast<BRep_TEdge>(anEdge.TShape());
      for (NCollection_List<occ::handle<BRep_CurveRepresentation>>::Iterator anIt(aTEdge->Curves());
           anIt.More();
           anIt.Next())
      {
        if (anIt.Value()->IsCurveOnSurface())
        {
          aPCurves++;
        }
      }
      std::printf("  edge %d: 3D curve = %s, pcurve representations = %d\n",
                  aCount,
                  aHasCurve3d ? "yes" : "no",
                  aPCurves);
      aCount++;
    }
    std::printf("  %d edges\n", aCount);
    return 0;
  }

  if (std::strcmp(aCase, "pcurve") == 0)
  {
    // The question that decides whether SelfIntersect gets past its first-edge pcurve test at
    // BRepCheck_Wire.cxx:1156 at all. If CurveOnSurface answers null, SelfIntersect returns
    // SelfIntersectingWire before touching HS, and the fault has to be somewhere else.
    int aCount = 0;
    for (TopExp_Explorer anExp(aFace, TopAbs_EDGE); anExp.More(); anExp.Next())
    {
      double                    aFirst = 0.0, aLast = 0.0;
      occ::handle<Geom2d_Curve> aPCurve =
        BRep_Tool::CurveOnSurface(TopoDS::Edge(anExp.Current()), aFace, aFirst, aLast);
      std::printf("  edge %d: CurveOnSurface(E, F) null = %s\n",
                  aCount,
                  aPCurve.IsNull() ? "true" : "false");
      aCount++;
    }
    std::printf("  %d edges\n", aCount);
    return 0;
  }

  return usage();
}
