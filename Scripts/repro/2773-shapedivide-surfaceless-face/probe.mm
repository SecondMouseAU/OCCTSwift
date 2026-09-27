// #2773: is a surface-less face reachable through a file, and does it still take the process down?
//
// The crash itself is settled and is not re-derived here: ShapeUpgrade_ShapeDivide::Perform()'s
// TopAbs_FACE loop calls SplitFace->Perform(), which reaches
// ShapeUpgrade_FaceDivide::SplitSurface, which calls ShapeAnalysis::GetFaceUVBounds(face, ...),
// which at ShapeAnalysis.cxx:280 does
//
//   BRep_Tool::Surface(F, L)->Bounds(UMin, UMax, VMin, VMax);
//
// on a face with no edges, with no test of the handle. ShapeUpgrade_ShapeDivide.cxx's own
// catch (Standard_Failure const&) at line 216 would encode ShapeExtend_FAIL2, and misses a signal.
//
// What this probe measures is REACHABILITY: whether a file can carry the shape, mirroring the
// #2746 -> #2750 round trip that turned that defect from a curiosity into twenty guarded call
// sites (Scripts/repro/2746-brepcheck-incontext-sigsegv/, brep-roundtrip-analyzer).
//
// One case per process, because a reproducing case is uncatchable. run.sh drives them.
//
// Cases:
//   describe                       build the candidate shapes in memory and print their state
//   brep-write      <file>         BRepTools::Write the compound; does the writer accept it
//   brep-write-bare <file>         ... the bare face on its own, for the one wrapper that
//                                  takes a TopAbs_FACE rather than any shape
//   brep-read       <file>         BRepTools::Read it back; does the face come back surface-less
//   step-write      <file>         STEPControl_Writer the compound; what does it transfer
//   step-read       <file>         STEPControl_Reader it back; can a surface-less face come out
//   iges-write      <file>         IGESControl_Writer the compound
//   iges-read       <file>         IGESControl_Reader it back
//   divide-memory   <no|yes>       ShapeUpgrade_ShapeDivideContinuity on the in-memory shape
//   divide-file     <file> <no|yes>  ... on the shape read back from the .brep
//   divide-memory-withwire <no|yes>  ... on the surface-less face that DOES carry a wire
//   facedivide-direct <no|yes>   ShapeUpgrade_FaceDivide alone, with no ShapeDivide above it
//   uvbounds <no|yes>            ShapeAnalysis::GetFaceUVBounds alone: the minimal reproducer
//   shapefix <no|yes>            ShapeFix_Shape::Perform, the other big reacher of GetFaceUVBounds
//
// The <no|yes> argument is OSD::SetSignal, which is what the bridge's occtEnsureSignals() does
// once per process from fourteen entry points (#2750). It changes the outcome, so it is a case
// axis rather than a constant.

#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepTools.hxx>
#include <BRep_Builder.hxx>
#include <BRep_Tool.hxx>
#include <GeomAbs_Shape.hxx>
#include <IFSelect_ReturnStatus.hxx>
#include <IGESControl_Reader.hxx>
#include <IGESControl_Writer.hxx>
#include <OSD.hxx>
#include <STEPControl_Reader.hxx>
#include <STEPControl_Writer.hxx>
#include <ShapeExtend_Status.hxx>
#include <ShapeAnalysis.hxx>
#include <ShapeFix_Shape.hxx>
#include <ShapeUpgrade_FaceDivide.hxx>
#include <ShapeUpgrade_ShapeDivideContinuity.hxx>
#include <Standard_Failure.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Compound.hxx>
#include <TopoDS_Face.hxx>
#include <TopoDS_Shape.hxx>

#include <csignal>
#include <typeinfo>
#include <cstdio>
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
TopoDS_Face makeSurfacelessFace()
{
  BRep_Builder aBuilder;
  TopoDS_Face  aFace;
  aBuilder.MakeFace(aFace);
  return aFace;
}

//! The same TFace, but carrying the outer wire of a real box face, so it has edges. Those edges
//! keep their 3D curves and their pcurves against the box's own plane, which is not this face's
//! surface because this face has none.
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

//! A compound holding one surface-less face, which is the shape #2765's hunt built.
TopoDS_Shape makeCompound(const TopoDS_Face& theFace)
{
  BRep_Builder    aBuilder;
  TopoDS_Compound aCompound;
  aBuilder.MakeCompound(aCompound);
  aBuilder.Add(aCompound, theFace);
  return aCompound;
}

//! Prints, for every face of theShape, whether its surface handle is null and how many edges it
//! has. Those two together are the predicate ShapeAnalysis.cxx:280 actually faults on.
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
    TopLoc_Location aLoc;
    const bool      aNullSurf = BRep_Tool::Surface(aFace, aLoc).IsNull();
    int             anEdges   = 0;
    for (TopExp_Explorer anEdgeExp(aFace, TopAbs_EDGE); anEdgeExp.More(); anEdgeExp.Next())
    {
      anEdges++;
    }
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

//! Runs the wrapper's own tool the way OCCTShapeDivide does, and prints OCCT's two-part answer
//! (#2769). Reaching the FAIL2 line at ShapeUpgrade_ShapeDivide.cxx:216 is the outcome under test.
void runDivide(const TopoDS_Shape& theShape)
{
  std::printf("  running ShapeUpgrade_ShapeDivideContinuity::Perform()...\n");
  std::fflush(stdout);
  try
  {
    ShapeUpgrade_ShapeDivideContinuity aTool(theShape);
    aTool.SetBoundaryCriterion(GeomAbs_C1);
    aTool.SetPCurveCriterion(GeomAbs_C1);
    aTool.SetSurfaceCriterion(GeomAbs_C1);
    const bool aPerformed  = aTool.Perform();
    const bool aStatusFail = aTool.Status(ShapeExtend_FAIL);
    const bool aFail2      = aTool.Status(ShapeExtend_FAIL2);
    std::printf("  perform=%s status-fail=%s FAIL2=%s result-null=%s\n",
                aPerformed ? "true" : "false",
                aStatusFail ? "true" : "false",
                aFail2 ? "true" : "false",
                aTool.Result().IsNull() ? "true" : "false");
  }
  catch (Standard_Failure const& anException)
  {
    std::printf("  CAUGHT Standard_Failure at the CALLER: %s: %s\n",
                typeid(anException).name(),
                anException.GetMessageString() ? anException.GetMessageString() : "(no message)");
  }
  catch (...)
  {
    std::printf("  CAUGHT a non-Standard_Failure exception at the CALLER\n");
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
    std::printf("in-memory shapes (type 0=COMPOUND, 4=FACE):\n");
    describeShape("healthy box", BRepPrimAPI_MakeBox(10.0, 20.0, 30.0).Shape());
    describeShape("bare surface-less face", makeSurfacelessFace());
    describeShape("compound of one, no wire", makeCompound(makeSurfacelessFace()));
    describeShape("compound of one, with wire", makeCompound(makeSurfacelessFaceWithWire()));
    return 0;
  }

  if (std::strcmp(aCase, "brep-write") == 0 && argc >= 3)
  {
    const TopoDS_Shape aShape = makeCompound(makeSurfacelessFace());
    describeShape("about to write", aShape);
    std::fflush(stdout);
    bool aWritten = false;
    try
    {
      aWritten = BRepTools::Write(aShape, argv[2]);
    }
    catch (Standard_Failure const& anException)
    {
      std::printf("  BRepTools::Write threw %s\n", typeid(anException).name());
      return 1;
    }
    std::printf("  BRepTools::Write -> %s (%s)\n", aWritten ? "true" : "false", argv[2]);
    return aWritten ? 0 : 1;
  }

  if (std::strcmp(aCase, "brep-write-bare") == 0 && argc >= 3)
  {
    const TopoDS_Shape aShape = makeSurfacelessFace();
    describeShape("about to write", aShape);
    std::fflush(stdout);
    bool aWritten = false;
    try
    {
      aWritten = BRepTools::Write(aShape, argv[2]);
    }
    catch (Standard_Failure const& anException)
    {
      std::printf("  BRepTools::Write threw %s\n", typeid(anException).name());
      return 1;
    }
    std::printf("  BRepTools::Write -> %s (%s)\n", aWritten ? "true" : "false", argv[2]);
    return aWritten ? 0 : 1;
  }

  if (std::strcmp(aCase, "brep-write-withwire") == 0 && argc >= 3)
  {
    const TopoDS_Shape aShape = makeCompound(makeSurfacelessFaceWithWire());
    describeShape("about to write", aShape);
    std::fflush(stdout);
    bool aWritten = false;
    try
    {
      aWritten = BRepTools::Write(aShape, argv[2]);
    }
    catch (Standard_Failure const& anException)
    {
      std::printf("  BRepTools::Write threw %s\n", typeid(anException).name());
      return 1;
    }
    std::printf("  BRepTools::Write -> %s (%s)\n", aWritten ? "true" : "false", argv[2]);
    return aWritten ? 0 : 1;
  }

  if (std::strcmp(aCase, "brep-read") == 0 && argc >= 3)
  {
    TopoDS_Shape aShape;
    BRep_Builder aBuilder;
    bool         aRead = false;
    try
    {
      aRead = BRepTools::Read(aShape, argv[2], aBuilder);
    }
    catch (Standard_Failure const& anException)
    {
      std::printf("  BRepTools::Read threw %s\n", typeid(anException).name());
      return 1;
    }
    std::printf("  BRepTools::Read -> %s\n", aRead ? "true" : "false");
    describeShape("read back", aShape);
    return 0;
  }

  if (std::strcmp(aCase, "step-write") == 0 && argc >= 3)
  {
    const TopoDS_Shape aShape = makeCompound(makeSurfacelessFace());
    describeShape("about to transfer", aShape);
    std::fflush(stdout);
    try
    {
      STEPControl_Writer      aWriter;
      const IFSelect_ReturnStatus aTransfer = aWriter.Transfer(aShape, STEPControl_AsIs);
      std::printf("  STEPControl_Writer::Transfer -> %d\n", static_cast<int>(aTransfer));
      std::fflush(stdout);
      const IFSelect_ReturnStatus aWrite = aWriter.Write(argv[2]);
      std::printf("  STEPControl_Writer::Write -> %d (%s)\n", static_cast<int>(aWrite), argv[2]);
    }
    catch (Standard_Failure const& anException)
    {
      std::printf("  STEP write threw %s: %s\n",
                  typeid(anException).name(),
                  anException.GetMessageString() ? anException.GetMessageString() : "");
      return 1;
    }
    return 0;
  }

  if (std::strcmp(aCase, "step-read") == 0 && argc >= 3)
  {
    try
    {
      STEPControl_Reader          aReader;
      const IFSelect_ReturnStatus aStatus = aReader.ReadFile(argv[2]);
      std::printf("  STEPControl_Reader::ReadFile -> %d\n", static_cast<int>(aStatus));
      std::fflush(stdout);
      if (aStatus != IFSelect_RetDone)
      {
        return 1;
      }
      const int aRoots = aReader.NbRootsForTransfer();
      std::printf("  roots for transfer = %d\n", aRoots);
      aReader.TransferRoots();
      std::printf("  shapes transferred = %d\n", aReader.NbShapes());
      describeShape("one shape", aReader.OneShape());
    }
    catch (Standard_Failure const& anException)
    {
      std::printf("  STEP read threw %s\n", typeid(anException).name());
      return 1;
    }
    return 0;
  }

  if (std::strcmp(aCase, "iges-write") == 0 && argc >= 3)
  {
    const TopoDS_Shape aShape = makeCompound(makeSurfacelessFace());
    describeShape("about to transfer", aShape);
    std::fflush(stdout);
    try
    {
      IGESControl_Writer aWriter;
      const bool         aTransfer = aWriter.AddShape(aShape);
      std::printf("  IGESControl_Writer::AddShape -> %s\n", aTransfer ? "true" : "false");
      std::fflush(stdout);
      aWriter.ComputeModel();
      const bool aWrite = aWriter.Write(argv[2]);
      std::printf("  IGESControl_Writer::Write -> %s (%s)\n", aWrite ? "true" : "false", argv[2]);
    }
    catch (Standard_Failure const& anException)
    {
      std::printf("  IGES write threw %s: %s\n",
                  typeid(anException).name(),
                  anException.GetMessageString() ? anException.GetMessageString() : "");
      return 1;
    }
    return 0;
  }

  if (std::strcmp(aCase, "iges-read") == 0 && argc >= 3)
  {
    try
    {
      IGESControl_Reader          aReader;
      const IFSelect_ReturnStatus aStatus = aReader.ReadFile(argv[2]);
      std::printf("  IGESControl_Reader::ReadFile -> %d\n", static_cast<int>(aStatus));
      std::fflush(stdout);
      if (aStatus != IFSelect_RetDone)
      {
        return 1;
      }
      std::printf("  roots for transfer = %d\n", aReader.NbRootsForTransfer());
      aReader.TransferRoots();
      std::printf("  shapes transferred = %d\n", aReader.NbShapes());
      describeShape("one shape", aReader.OneShape());
    }
    catch (Standard_Failure const& anException)
    {
      std::printf("  IGES read threw %s\n", typeid(anException).name());
      return 1;
    }
    return 0;
  }

  if (std::strcmp(aCase, "divide-memory") == 0 && argc >= 3)
  {
    if (std::strcmp(argv[2], "yes") == 0)
    {
      OSD::SetSignal(Standard_False);
      std::printf("  OSD::SetSignal(Standard_False) installed\n");
    }
    const TopoDS_Shape aShape = makeCompound(makeSurfacelessFace());
    describeShape("input", aShape);
    runDivide(aShape);
    return 0;
  }

  if (std::strcmp(aCase, "divide-memory-withwire") == 0 && argc >= 3)
  {
    if (std::strcmp(argv[2], "yes") == 0)
    {
      OSD::SetSignal(Standard_False);
      std::printf("  OSD::SetSignal(Standard_False) installed\n");
    }
    const TopoDS_Shape aShape = makeCompound(makeSurfacelessFaceWithWire());
    describeShape("input", aShape);
    runDivide(aShape);
    return 0;
  }

  if (std::strcmp(aCase, "divide-file") == 0 && argc >= 4)
  {
    if (std::strcmp(argv[3], "yes") == 0)
    {
      OSD::SetSignal(Standard_False);
      std::printf("  OSD::SetSignal(Standard_False) installed\n");
    }
    TopoDS_Shape aShape;
    BRep_Builder aBuilder;
    if (!BRepTools::Read(aShape, argv[2], aBuilder))
    {
      std::printf("  BRepTools::Read -> false, nothing to run\n");
      return 1;
    }
    describeShape("input off disk", aShape);
    runDivide(aShape);
    return 0;
  }

  // Which handler absorbs the fault when one is installed? ShapeUpgrade_ShapeDivide.cxx:190 is the
  // only OCC_CATCH_SIGNALS between the caller and the fault: neither ShapeUpgrade_FaceDivide.cxx
  // nor ShapeAnalysis.cxx has one, and ShapeUpgrade_SplitSurface.cxx's is inside Build()'s
  // BSpline/Bezier Segment block, which a null surface never reaches. Calling FaceDivide directly
  // removes line 190 from the stack, so if the conversion is real the failure arrives at THIS
  // caller's own catch instead of being encoded as FAIL2.
  if (std::strcmp(aCase, "facedivide-direct") == 0 && argc >= 3)
  {
    if (std::strcmp(argv[2], "yes") == 0)
    {
      OSD::SetSignal(Standard_False);
      std::printf("  OSD::SetSignal(Standard_False) installed\n");
    }
    const TopoDS_Face aFace = makeSurfacelessFace();
    describeShape("input", aFace);
    std::printf("  running ShapeUpgrade_FaceDivide::Perform() with no ShapeDivide above it...\n");
    std::fflush(stdout);
    try
    {
      ShapeUpgrade_FaceDivide aTool(aFace);
      const bool              aPerformed = aTool.Perform();
      std::printf("  perform=%s status-fail=%s\n",
                  aPerformed ? "true" : "false",
                  aTool.Status(ShapeExtend_FAIL) ? "true" : "false");
    }
    catch (Standard_Failure const& anException)
    {
      std::printf("  CAUGHT Standard_Failure at the CALLER: %s: %s\n",
                  typeid(anException).name(),
                  anException.GetMessageString() ? anException.GetMessageString() : "(no message)");
    }
    catch (...)
    {
      std::printf("  CAUGHT a non-Standard_Failure exception at the CALLER\n");
    }
    return 0;
  }

  // The minimal reproducer, and the line the upstream report should name:
  // ShapeAnalysis.cxx:280 dereferences BRep_Tool::Surface(F, L) with no test, in the branch taken
  // when the face has no edges.
  if (std::strcmp(aCase, "uvbounds") == 0 && argc >= 3)
  {
    if (std::strcmp(argv[2], "yes") == 0)
    {
      OSD::SetSignal(Standard_False);
      std::printf("  OSD::SetSignal(Standard_False) installed\n");
    }
    const TopoDS_Face aFace = makeSurfacelessFace();
    describeShape("input", aFace);
    std::printf("  running ShapeAnalysis::GetFaceUVBounds()...\n");
    std::fflush(stdout);
    try
    {
      double aUf = 0.0, aUl = 0.0, aVf = 0.0, aVl = 0.0;
      ShapeAnalysis::GetFaceUVBounds(aFace, aUf, aUl, aVf, aVl);
      std::printf("  returned %g %g %g %g\n", aUf, aUl, aVf, aVl);
    }
    catch (Standard_Failure const&)
    {
      std::printf("  CAUGHT Standard_Failure at the CALLER\n");
    }
    return 0;
  }

  // ShapeFix_Face is the other heavy caller of GetFaceUVBounds, and ShapeFix_Shape is reachable
  // from many more bridge functions than the divide family, so whether it faults on the same input
  // decides how far the population extends.
  if (std::strcmp(aCase, "shapefix") == 0 && argc >= 3)
  {
    if (std::strcmp(argv[2], "yes") == 0)
    {
      OSD::SetSignal(Standard_False);
      std::printf("  OSD::SetSignal(Standard_False) installed\n");
    }
    const TopoDS_Shape aShape = makeCompound(makeSurfacelessFace());
    describeShape("input", aShape);
    std::printf("  running ShapeFix_Shape::Perform()...\n");
    std::fflush(stdout);
    try
    {
      occ::handle<ShapeFix_Shape> aFix = new ShapeFix_Shape(aShape);
      const bool                  aDone = aFix->Perform();
      std::printf("  perform=%s result-null=%s\n",
                  aDone ? "true" : "false",
                  aFix->Shape().IsNull() ? "true" : "false");
    }
    catch (Standard_Failure const&)
    {
      std::printf("  CAUGHT Standard_Failure at the CALLER\n");
    }
    return 0;
  }

  std::printf("unknown case: %s\n", aCase);
  return 2;
}
