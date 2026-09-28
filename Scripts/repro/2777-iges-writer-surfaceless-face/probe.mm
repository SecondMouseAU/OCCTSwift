// #2777: where does IGESControl_Writer::AddShape fault on a surface-less face, and what is the
// predicate?
//
// #2773 recorded the crash as a side observation ("IGES cannot carry it either, because the writer
// faults on the way out") and deliberately did not locate it. This probe locates it and then asks
// the one question that decides the bridge guard's shape: does the writer fault on a surface-less
// face that CARRIES A WIRE, which is the input #2773's narrower predicate deliberately lets
// through because ShapeAnalysis::GetFaceUVBounds handles it correctly?
//
// Read first, then measured. The read says the fault is nowhere near BRepToIGES:
//
//   IGESControl_Writer::AddShape                     IGESControl_Writer.cxx:109
//     XSAlgo_ShapeProcessor::ProcessShape            XSAlgo_ShapeProcessor.cxx:73
//       ShapeProcess::Perform (flags overload)       ShapeProcess.cxx:189  <- OCC_CATCH_SIGNALS
//         directfaces                                ShapeProcess_OperLibrary.cxx (DirectFaces)
//           ShapeProcess_OperLibrary::ApplyModifier -> BRepTools_Modifier
//             BRepTools_Modifier::FillNewSurfaceInfo BRepTools_Modifier.cxx:718, EVERY face
//               ShapeCustom_DirectModification::NewSurface  ShapeCustom_DirectModification.cxx:99
//                 S = BRep_Tool::Surface(F, L);      <- null for a surface-less face, untested
//                 IsIndirectSurface(S, L)            ShapeCustom_DirectModification.cxx:50
//                   TS->IsKind(...)                  ShapeCustom_DirectModification.cxx:55  <- HERE
//
// IGESControl_Writer::InitializeMissingParameters (IGESControl_Writer.cxx:355-359) sets exactly one
// shape-processing operation, DirectFaces, so that operator runs on every AddShape call. Both of
// BRepToIGES' own face-surface reads are guarded (BRepToIGES_BRShell.cxx:249 and
// BRepToIGESBRep_Entity.cxx:548 both test !Surf.IsNull()), so the transfer itself would have
// survived; the shape processor in front of it does not.
//
// Nothing in that path looks at the face's edges. FillNewSurfaceInfo walks
// TopExp::MapShapes(..., TopAbs_FACE) and calls NewSurface on each face unconditionally, so the
// prediction is that the with-wire shape faults too and the predicate is the surface clause ALONE.
// That is a prediction from reading, which is the thing this probe exists to confirm or kill.
//
// And the STEP question #2777 asks: STEPControl_Writer::InitializeMissingParameters sets
// DirectFaces as well (STEPControl_Writer.cxx:315-320), so STEP write is on the same path, except
// that STEPControl_ActorWrite guards it: hasGeometry() at STEPControl_ActorWrite.cxx:163-214
// returns false for a TopAbs_FACE whose BRep_TFace::Surface() is null, and false for any compound
// containing one, and ProcessShape runs only `if (hasGeometry(aShape))`
// (STEPControl_ActorWrite.cxx:1158-1160). So OCCT's own STEP writer already tests the surface, with
// no edge clause. Measured below rather than trusted.
//
// One case per process, because a reproducing case is uncatchable. run.sh drives them.
//
// Cases, where <fixture> is one of compound | bare | withwire | barewithwire | barereversed | box
// and <sig> is no | yes for OSD::SetSignal, which is what the bridge's occtEnsureSignals() does
// once per process and which decides whether OCC_CATCH_SIGNALS can convert the fault:
//
//   describe                                the fixtures, in memory
//   describe-file  <file>                   ... read back off disk
//   brep-write     <fixture> <file>         BRepTools::Write a fixture, to make a test fixture
//   iges-write     <fixture> <mode> <sig> <file>   IGESControl_Writer(mode).AddShape, then Write
//   processshape   <fixture> <sig>          XSAlgo_ShapeProcessor::ProcessShape with IGES' flags
//   analyzer       <fixture>                BRepCheck_Analyzer, the gate already in front of IGES
//   directfaces    <fixture> <sig>          ShapeCustom::DirectFaces alone
//   shapecustom    <op> <fixture> <sig>     the rest of the ShapeCustom family, to bound the finding
//   newsurface     <fixture> <sig>          the faulting frame itself, on a bare-face fixture
//   transferface   <fixture> <sig>          BRepToIGES with no shape processor in front of it
//   step-write     <fixture> <sig> <file>   STEPControl_Writer::Transfer, the #2777 open question
//   step-read      <file>                   ... and what comes back
//   divide         <fixture> <sig>          ShapeUpgrade_ShapeDivideContinuity, the #2773 baseline

#include <BRepCheck_Analyzer.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepToIGES_BREntity.hxx>
#include <BRepTools.hxx>
#include <BRep_Builder.hxx>
#include <BRep_Tool.hxx>
#include <GeomAbs_Shape.hxx>
#include <IGESData_IGESEntity.hxx>
#include <IGESData_IGESModel.hxx>
#include <IFSelect_ReturnStatus.hxx>
#include <IGESControl_Controller.hxx>
#include <IGESControl_Writer.hxx>
#include <OSD.hxx>
#include <STEPControl_Reader.hxx>
#include <STEPControl_StepModelType.hxx>
#include <STEPControl_Writer.hxx>
#include <ShapeCustom.hxx>
#include <ShapeCustom_DirectModification.hxx>
#include <ShapeCustom_RestrictionParameters.hxx>
#include <ShapeExtend_Status.hxx>
#include <ShapeProcess.hxx>
#include <ShapeProcess_OperLibrary.hxx>
#include <ShapeUpgrade_ShapeDivideContinuity.hxx>
#include <Standard_Failure.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Compound.hxx>
#include <TopoDS_Face.hxx>
#include <TopoDS_Shape.hxx>
#include <Transfer_FinderProcess.hxx>
#include <XSAlgo_ShapeProcessor.hxx>

#include <csignal>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <typeinfo>
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
//! The same construction as #2773's probe, so the two sets of measurements are comparable.
TopoDS_Face makeSurfacelessFace()
{
  BRep_Builder aBuilder;
  TopoDS_Face  aFace;
  aBuilder.MakeFace(aFace);
  return aFace;
}

//! The same TFace, carrying the outer wire of a real box face, so it has edges with 3D curves and
//! pcurves against a surface that is not this face's, because this face has none. This is the shape
//! #2773's predicate deliberately lets through.
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

TopoDS_Shape makeCompound(const TopoDS_Shape& theShape)
{
  BRep_Builder    aBuilder;
  TopoDS_Compound aCompound;
  aBuilder.MakeCompound(aCompound);
  aBuilder.Add(aCompound, theShape);
  return aCompound;
}

//! Resolves a fixture name to a shape. `barewithwire` is the with-wire face on its own, for the
//! symmetry with `bare`; `box` is the healthy control every crashing case needs beside it.
TopoDS_Shape fixture(const char* theName)
{
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
  if (std::strcmp(theName, "barereversed") == 0)
  {
    return makeSurfacelessFace().Reversed();
  }
  if (std::strcmp(theName, "box") == 0)
  {
    return BRepPrimAPI_MakeBox(10.0, 20.0, 30.0).Shape();
  }
  std::printf("  unknown fixture '%s'\n", theName);
  return TopoDS_Shape();
}

//! Prints, per face, whether the surface handle is null and how many edges it has. Those two
//! columns are what the two candidate predicates disagree about.
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
  std::printf("  %-34s type=%d faces=%d null-surface=%d edgeless=%d BOTH=%d\n",
              theLabel,
              static_cast<int>(theShape.ShapeType()),
              aFaces,
              aSurfacelessFace,
              aNoEdgeFace,
              aBoth);
}

//! OSD::SetSignal, the axis that decides whether OCC_CATCH_SIGNALS can convert the fault. The
//! bridge installs one once per process from occtEnsureSignals(), and no IGES export entry point
//! is among those call sites, so `no` is the disposition a shipped export runs under.
void applySignalDisposition(const char* theArg)
{
  if (std::strcmp(theArg, "yes") == 0)
  {
    OSD::SetSignal(false);
    std::printf("  OSD::SetSignal(false) installed\n");
  }
  else
  {
    std::printf("  no OSD signal handler\n");
  }
  std::fflush(stdout);
}

} // namespace

int main(int argc, char** argv)
{
  std::signal(SIGSEGV, segvHandler);
  std::signal(SIGBUS, segvHandler);

  if (argc < 2)
  {
    std::printf("usage: probe <case> [args]\n");
    return 2;
  }
  const char* aCase = argv[1];

  if (std::strcmp(aCase, "describe") == 0)
  {
    std::printf("in-memory fixtures (type 0=COMPOUND, 2=SOLID, 4=FACE):\n");
    describeShape("box (control)", fixture("box"));
    describeShape("bare", fixture("bare"));
    describeShape("compound", fixture("compound"));
    describeShape("barewithwire", fixture("barewithwire"));
    describeShape("withwire", fixture("withwire"));
    describeShape("barereversed", fixture("barereversed"));
    return 0;
  }

  if (std::strcmp(aCase, "describe-file") == 0 && argc >= 3)
  {
    BRep_Builder aBuilder;
    TopoDS_Shape aShape;
    const bool   aRead = BRepTools::Read(aShape, argv[2], aBuilder);
    std::printf("  BRepTools::Read -> %s (%s)\n", aRead ? "true" : "false", argv[2]);
    describeShape("read back", aShape);
    return 0;
  }

  if (std::strcmp(aCase, "brep-write") == 0 && argc >= 4)
  {
    const TopoDS_Shape aShape = fixture(argv[2]);
    describeShape("about to write", aShape);
    std::fflush(stdout);
    const bool aWritten = BRepTools::Write(aShape, argv[3]);
    std::printf("  BRepTools::Write -> %s (%s)\n", aWritten ? "true" : "false", argv[3]);
    return aWritten ? 0 : 1;
  }

  if (std::strcmp(aCase, "iges-write") == 0 && argc >= 6)
  {
    const TopoDS_Shape aShape = fixture(argv[2]);
    const int          aMode  = std::atoi(argv[3]);
    describeShape("about to export", aShape);
    applySignalDisposition(argv[4]);
    std::printf("  IGESControl_Writer(\"MM\", %d).AddShape...\n", aMode);
    std::fflush(stdout);
    try
    {
      IGESControl_Writer aWriter("MM", aMode);
      const bool         anAdded = aWriter.AddShape(aShape);
      std::printf("  AddShape -> %s\n", anAdded ? "true" : "false");
      std::fflush(stdout);
      aWriter.ComputeModel();
      const bool aWrote = aWriter.Write(argv[5]);
      std::printf("  Write -> %s (%s)\n", aWrote ? "true" : "false", argv[5]);
    }
    catch (Standard_Failure const& anException)
    {
      std::printf("  CAUGHT at the caller: %s: %s\n",
                  typeid(anException).name(),
                  anException.GetMessageString() ? anException.GetMessageString() : "(no message)");
    }
    std::fflush(stdout);
    return 0;
  }

  if (std::strcmp(aCase, "directfaces") == 0 && argc >= 4)
  {
    const TopoDS_Shape aShape = fixture(argv[2]);
    describeShape("input", aShape);
    applySignalDisposition(argv[3]);
    std::printf("  ShapeCustom::DirectFaces...\n");
    std::fflush(stdout);
    try
    {
      const TopoDS_Shape aResult = ShapeCustom::DirectFaces(aShape);
      describeShape("result", aResult);
    }
    catch (Standard_Failure const& anException)
    {
      std::printf("  CAUGHT at the caller: %s: %s\n",
                  typeid(anException).name(),
                  anException.GetMessageString() ? anException.GetMessageString() : "(no message)");
    }
    std::fflush(stdout);
    return 0;
  }

  if (std::strcmp(aCase, "processshape") == 0 && argc >= 4)
  {
    const TopoDS_Shape aShape = fixture(argv[2]);
    describeShape("input", aShape);
    applySignalDisposition(argv[3]);
    // Exactly what IGESControl_Writer::AddShape does before it reaches BRepToIGES: the one
    // operation IGESControl_Writer::InitializeMissingParameters turns on.
    ShapeProcess::OperationsFlags aFlags;
    aFlags.set(ShapeProcess::Operation::DirectFaces);
    // ShapeProcess_OperLibrary::Init() is what registers the "DirectFaces" operator, and
    // ShapeProcess::Perform quietly does nothing for an operator it cannot find. In the writer it
    // has already run, from IGESControl_Controller::Init() in IGESControl_Writer's constructor.
    // Without this line every row of this case came back clean and measured nothing.
    ShapeProcess_OperLibrary::Init();
    std::printf("  XSAlgo_ShapeProcessor::ProcessShape with DirectFaces only...\n");
    std::fflush(stdout);
    try
    {
      XSAlgo_ShapeProcessor::PrepareForTransfer();
      XSAlgo_ShapeProcessor aProcessor(XSAlgo_ShapeProcessor::ParameterMap{});
      const TopoDS_Shape    aResult =
        aProcessor.ProcessShape(aShape, aFlags, Message_ProgressRange());
      describeShape("result", aResult);
      std::printf("  result is the input shape unchanged: %s\n",
                  aResult.IsEqual(aShape) ? "true" : "false");
    }
    catch (Standard_Failure const& anException)
    {
      std::printf("  CAUGHT at the caller: %s: %s\n",
                  typeid(anException).name(),
                  anException.GetMessageString() ? anException.GetMessageString() : "(no message)");
    }
    std::fflush(stdout);
    return 0;
  }

  if (std::strcmp(aCase, "analyzer") == 0 && argc >= 3)
  {
    // The gate that already stands in front of all five IGES export entry points. If
    // BRepCheck_Analyzer calls a surface-less face invalid, the shipped Swift API never reaches
    // AddShape and the guard is belt-and-braces; if it calls it valid, the guard is the only thing
    // between a consumer's export and a dead process. Asked of every fixture, because the wire
    // changes which BRepCheck_Face checks run.
    const TopoDS_Shape aShape = fixture(argv[2]);
    describeShape("input", aShape);
    std::fflush(stdout);
    try
    {
      BRepCheck_Analyzer anAnalyzer(aShape);
      std::printf("  BRepCheck_Analyzer::IsValid -> %s\n", anAnalyzer.IsValid() ? "true" : "false");
    }
    catch (Standard_Failure const& anException)
    {
      std::printf("  CAUGHT at the caller: %s: %s\n",
                  typeid(anException).name(),
                  anException.GetMessageString() ? anException.GetMessageString() : "(no message)");
    }
    std::fflush(stdout);
    return 0;
  }

  if (std::strcmp(aCase, "shapecustom") == 0 && argc >= 5)
  {
    // How far the ShapeCustom family reaches. Each of these drives BRepTools_Modifier over its own
    // BRepTools_Modification subclass, and each subclass has its own NewSurface, so none of them
    // shares DirectFaces' faulting line. This bounds the finding rather than widening it: whatever
    // these rows say belongs to a follow-up, not to #2777's guard.
    const char*        aWhich = argv[2];
    const TopoDS_Shape aShape = fixture(argv[3]);
    describeShape("input", aShape);
    applySignalDisposition(argv[4]);
    std::printf("  ShapeCustom::%s...\n", aWhich);
    std::fflush(stdout);
    try
    {
      TopoDS_Shape aResult;
      if (std::strcmp(aWhich, "ScaleShape") == 0)
      {
        aResult = ShapeCustom::ScaleShape(aShape, 2.0);
      }
      else if (std::strcmp(aWhich, "SweptToElementary") == 0)
      {
        aResult = ShapeCustom::SweptToElementary(aShape);
      }
      else if (std::strcmp(aWhich, "ConvertToRevolution") == 0)
      {
        aResult = ShapeCustom::ConvertToRevolution(aShape);
      }
      else if (std::strcmp(aWhich, "ConvertToBSpline") == 0)
      {
        aResult = ShapeCustom::ConvertToBSpline(aShape, true, true, true, true);
      }
      else if (std::strcmp(aWhich, "BSplineRestriction") == 0)
      {
        aResult = ShapeCustom::BSplineRestriction(aShape,
                                                 0.01,
                                                 0.01,
                                                 9,
                                                 100,
                                                 GeomAbs_C1,
                                                 GeomAbs_C1,
                                                 true,
                                                 false,
                                                 new ShapeCustom_RestrictionParameters);
      }
      else
      {
        std::printf("  unknown operation '%s'\n", aWhich);
        return 2;
      }
      describeShape("result", aResult);
    }
    catch (Standard_Failure const& anException)
    {
      std::printf("  CAUGHT at the caller: %s: %s\n",
                  typeid(anException).name(),
                  anException.GetMessageString() ? anException.GetMessageString() : "(no message)");
    }
    std::fflush(stdout);
    return 0;
  }

  if (std::strcmp(aCase, "newsurface") == 0 && argc >= 4)
  {
    // The exact frame. ShapeCustom_DirectModification::NewSurface's first statement is
    // S = BRep_Tool::Surface(F, L), and its second is the IsIndirectSurface(S, L) call whose own
    // first statement dereferences S. Nothing else in the function runs before that, so a fault
    // here is that line and no other.
    const TopoDS_Shape aShape = fixture(argv[2]);
    if (aShape.ShapeType() != TopAbs_FACE)
    {
      std::printf("  newsurface needs a bare face fixture\n");
      return 2;
    }
    const TopoDS_Face& aFace = TopoDS::Face(aShape);
    describeShape("input", aShape);
    TopLoc_Location aProbeLoc;
    std::printf("  BRep_Tool::Surface(F, L).IsNull() = %s\n",
                BRep_Tool::Surface(aFace, aProbeLoc).IsNull() ? "true" : "false");
    applySignalDisposition(argv[3]);
    std::printf("  ShapeCustom_DirectModification::NewSurface...\n");
    std::fflush(stdout);
    try
    {
      occ::handle<ShapeCustom_DirectModification> aMod = new ShapeCustom_DirectModification;
      occ::handle<Geom_Surface>                   aSurface;
      TopLoc_Location                             aLoc;
      double                                      aTol      = 0.0;
      bool                                        aRevWires = false;
      bool                                        aRevFace  = false;
      const bool                                  anIsNew =
        aMod->NewSurface(aFace, aSurface, aLoc, aTol, aRevWires, aRevFace);
      std::printf("  NewSurface -> %s\n", anIsNew ? "true" : "false");
    }
    catch (Standard_Failure const& anException)
    {
      std::printf("  CAUGHT at the caller: %s: %s\n",
                  typeid(anException).name(),
                  anException.GetMessageString() ? anException.GetMessageString() : "(no message)");
    }
    std::fflush(stdout);
    return 0;
  }

  if (std::strcmp(aCase, "transferface") == 0 && argc >= 4)
  {
    // BRepToIGES on its own, with no shape processor in front of it, to show which of the writer's
    // two layers is unsafe. BRepToIGES_BRShell::TransferFace tests !Surf.IsNull() at
    // BRepToIGES_BRShell.cxx:249 before reading the surface, so a FORWARD surface-less face should
    // come through as a null entity rather than a fault. The REVERSED branch above it, at
    // BRepToIGES_BRShell.cxx:134, dereferences the same handle untested, so `barereversed` is the
    // fixture that separates the two.
    const TopoDS_Shape aShape = fixture(argv[2]);
    describeShape("input", aShape);
    std::printf("  orientation = %d (0 FORWARD, 1 REVERSED)\n",
                static_cast<int>(aShape.Orientation()));
    // TransferFace reaches ShapeAlgo::AlgoContainer()->OuterWire, and that container is null until
    // something initialises it. IGESControl_Writer's constructor does, through
    // IGESControl_Controller::Init(); called on its own, TransferShape dies on the healthy box
    // control too, which is a broken harness rather than a finding, and was one here first.
    IGESControl_Controller::Init();
    applySignalDisposition(argv[3]);
    std::printf("  BRepToIGES_BREntity::TransferShape...\n");
    std::fflush(stdout);
    try
    {
      BRepToIGES_BREntity aTransfer;
      aTransfer.SetTransferProcess(new Transfer_FinderProcess(10000));
      aTransfer.SetModel(new IGESData_IGESModel);
      const occ::handle<IGESData_IGESEntity> anEntity = aTransfer.TransferShape(aShape);
      std::printf("  TransferShape -> %s entity\n", anEntity.IsNull() ? "null" : "non-null");
    }
    catch (Standard_Failure const& anException)
    {
      std::printf("  CAUGHT at the caller: %s: %s\n",
                  typeid(anException).name(),
                  anException.GetMessageString() ? anException.GetMessageString() : "(no message)");
    }
    std::fflush(stdout);
    return 0;
  }

  if (std::strcmp(aCase, "step-write") == 0 && argc >= 5)
  {
    const TopoDS_Shape aShape = fixture(argv[2]);
    describeShape("about to export", aShape);
    applySignalDisposition(argv[3]);
    std::printf("  STEPControl_Writer::Transfer...\n");
    std::fflush(stdout);
    try
    {
      STEPControl_Writer          aWriter;
      const IFSelect_ReturnStatus aStatus = aWriter.Transfer(aShape, STEPControl_AsIs);
      std::printf("  Transfer -> %d (1 == IFSelect_RetDone)\n", static_cast<int>(aStatus));
      std::fflush(stdout);
      const IFSelect_ReturnStatus aWrote = aWriter.Write(argv[4]);
      std::printf("  Write -> %d (%s)\n", static_cast<int>(aWrote), argv[4]);
    }
    catch (Standard_Failure const& anException)
    {
      std::printf("  CAUGHT at the caller: %s: %s\n",
                  typeid(anException).name(),
                  anException.GetMessageString() ? anException.GetMessageString() : "(no message)");
    }
    std::fflush(stdout);
    return 0;
  }

  if (std::strcmp(aCase, "step-read") == 0 && argc >= 3)
  {
    STEPControl_Reader          aReader;
    const IFSelect_ReturnStatus aStatus = aReader.ReadFile(argv[2]);
    std::printf("  ReadFile -> %d\n", static_cast<int>(aStatus));
    if (aStatus != IFSelect_RetDone)
    {
      return 1;
    }
    std::printf("  roots for transfer = %d\n", aReader.NbRootsForTransfer());
    aReader.TransferRoots();
    std::printf("  shapes transferred = %d\n", aReader.NbShapes());
    if (aReader.NbShapes() > 0)
    {
      describeShape("one shape", aReader.Shape(1));
    }
    return 0;
  }

  if (std::strcmp(aCase, "divide") == 0 && argc >= 4)
  {
    // The #2773 baseline on this pin. The pinned kernel carries patch 0042, so the rows that used
    // to exit 139 must now report FAIL2 instead. If they still exit 139 the pin is not what
    // Package.swift says it is, and nothing else here can be trusted.
    const TopoDS_Shape aShape = fixture(argv[2]);
    describeShape("input", aShape);
    applySignalDisposition(argv[3]);
    std::printf("  ShapeUpgrade_ShapeDivideContinuity::Perform...\n");
    std::fflush(stdout);
    try
    {
      ShapeUpgrade_ShapeDivideContinuity aTool(aShape);
      aTool.SetBoundaryCriterion(GeomAbs_C1);
      aTool.SetPCurveCriterion(GeomAbs_C1);
      aTool.SetSurfaceCriterion(GeomAbs_C1);
      const bool aPerformed = aTool.Perform();
      std::printf("  perform=%s status-fail=%s FAIL2=%s\n",
                  aPerformed ? "true" : "false",
                  aTool.Status(ShapeExtend_FAIL) ? "true" : "false",
                  aTool.Status(ShapeExtend_FAIL2) ? "true" : "false");
    }
    catch (Standard_Failure const& anException)
    {
      std::printf("  CAUGHT at the caller: %s: %s\n",
                  typeid(anException).name(),
                  anException.GetMessageString() ? anException.GetMessageString() : "(no message)");
    }
    std::fflush(stdout);
    return 0;
  }

  std::printf("unknown case '%s'\n", aCase);
  return 2;
}
