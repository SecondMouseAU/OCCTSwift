// #2790: the three ShapeCustom converters that fault on a surface-less face, at three lines
// #2777 recorded as unlocated.
//
// #2777 bounded its own finding by running the whole ShapeCustom family over every fixture and
// reporting that three more operations exit 139 and two do not. It deliberately located none of the
// three, because each drives its own BRepTools_Modification subclass with its own NewSurface, so
// none of them shares ShapeCustom_DirectModification.cxx:55. Locating them is this probe's first
// job; choosing the predicate per site rather than inheriting #2777's is its second.
//
// Read first, then measured. The three lines, from the pinned Libraries/occt-src:
//
//   ShapeCustom::SweptToElementary            ShapeCustom.cxx:270
//     ShapeCustom::ApplyModifier -> BRepTools_Modifier
//       BRepTools_Modifier::FillNewSurfaceInfo    BRepTools_Modifier.cxx:705, EVERY face
//         ShapeCustom_SweptToElementary::NewSurface   ShapeCustom_SweptToElementary.cxx:89
//           S = BRep_Tool::Surface(F, L);            :96   null, untested
//           IsToConvert(S, SS)                       :98
//             S->IsKind(STANDARD_TYPE(Geom_SweptSurface))   :59   <- FAULT 1
//
//   ShapeCustom::ConvertToRevolution          ShapeCustom.cxx:259
//     ... the same two frames ...
//         ShapeCustom_ConvertToRevolution::NewSurface  ShapeCustom_ConvertToRevolution.cxx:79
//           S = BRep_Tool::Surface(F, L);            :86   null, untested
//           IsToConvert(S, ES)                       :89
//             ES = occ::down_cast<...>(S);           :51   fine on a null handle: dynamic_cast
//             if (ES.IsNull())                       :52   taken
//               S->IsKind(STANDARD_TYPE(Geom_RectangularTrimmedSurface))  :54  <- FAULT 2
//
//   ShapeCustom::ConvertToBSpline             ShapeCustom.cxx:281
//     ... the same two frames ...
//         ShapeCustom_ConvertToBSpline::NewSurface     ShapeCustom_ConvertToBSpline.cxx:95
//           S = BRep_Tool::Surface(F, L);            :102  null, untested
//           S->Bounds(U1, U2, V1, V2);               :104  <- FAULT 3
//
// So they are three lines in three files, and fault 3 is a different shape from the other two: it
// is in NewSurface itself, before any helper, and it is the same Geom_Surface::Bounds call that
// #2773's ShapeAnalysis::GetFaceUVBounds dereferences. Faults 1 and 2 are both the first statement
// of a file-static IsToConvert, which is the same shape as #2777's IsIndirectSurface.
//
// And the two that do NOT fault are explained by the same reading, which is what makes the negative
// worth keeping rather than re-deriving:
//
//   ShapeCustom::BSplineRestriction -> ShapeCustom_BSplineRestriction::NewSurface
//     ShapeCustom_BSplineRestriction.cxx:429-433   occ::handle<Geom_Surface> aSurface = ...
//                                                  if (aSurface.IsNull()) return false;
//   ShapeCustom::ScaleShape -> ShapeCustom_TrsfModification::NewSurface
//     ShapeCustom_TrsfModification.cxx:49 delegates to
//     BRepTools_TrsfModification.cxx:72-77         S = BRep_Tool::Surface(F, L);
//                                                  if (S.IsNull())
//                                                    // processing cases when there is no geometry
//                                                    return false;
//
// Two of the five ShapeCustom modification subclasses hold the test, three do not, and OCCT's own
// base class BRepTools_TrsfModification names the case in a comment. That is the strongest form of
// the follow-occt-callers argument available: the kernel already contains the fix, twice, in the
// same class family, so the upstream change is copying a line OCCT wrote itself.
//
// Everything above is read, not measured. This probe measures it, one case per process, because a
// reproducing case is uncatchable and takes the rest of the transcript with it.
//
// Cases, where <fixture> is one of compound | bare | withwire | barewithwire | box, <sig> is no |
// yes for OSD::SetSignal, and <which> names a modification subclass:
//
//   describe                              the in-memory fixtures, both predicate columns
//   describe-file  <file>                 ... a committed .brep fixture, read back off disk
//   predicate      <fixture>              what each candidate predicate answers for a fixture
//   shapecustom    <op> <fixture> <sig>   the six ShapeCustom:: free functions the bridge wraps
//   newsurface     <which> <fixture> <sig>   NewSurface called directly, with the handle printed
//   modifier       <which> <fixture> <sig>   BRepTools_Modifier over one subclass, no ApplyModifier
//   equivalence    <shape>                do the three ConvertToBSpline spellings agree?

#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <BRepTools.hxx>
#include <BRepTools_Modifier.hxx>
#include <BRep_Builder.hxx>
#include <BRep_Tool.hxx>
#include <Geom_Surface.hxx>
#include <GeomAbs_Shape.hxx>
#include <OSD.hxx>
#include <ShapeCustom.hxx>
#include <ShapeCustom_BSplineRestriction.hxx>
#include <ShapeCustom_ConvertToBSpline.hxx>
#include <ShapeCustom_ConvertToRevolution.hxx>
#include <ShapeCustom_DirectModification.hxx>
#include <ShapeCustom_RestrictionParameters.hxx>
#include <ShapeCustom_SweptToElementary.hxx>
#include <ShapeCustom_TrsfModification.hxx>
#include <Standard_Failure.hxx>
#include <Standard_Type.hxx>
#include <TopExp_Explorer.hxx>
#include <TopLoc_Location.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Compound.hxx>
#include <TopoDS_Face.hxx>
#include <TopoDS_Shape.hxx>
#include <gp_Pnt.hxx>
#include <gp_Trsf.hxx>

#include <csignal>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <string>
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
//! The same construction as #2773's and #2777's probes, so all three sets of measurements are
//! comparable.
TopoDS_Face makeSurfacelessFace()
{
  BRep_Builder aBuilder;
  TopoDS_Face  aFace;
  aBuilder.MakeFace(aFace);
  return aFace;
}

//! The same TFace, carrying the outer wire of a real box face, so it has edges with 3D curves and
//! pcurves against a surface that is not this face's, because this face has none. This is the shape
//! #2773's narrower predicate deliberately lets through, and the row that decides whether this
//! issue can reuse it.
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
  if (std::strcmp(theName, "box") == 0)
  {
    return BRepPrimAPI_MakeBox(10.0, 20.0, 30.0).Shape();
  }
  if (std::strcmp(theName, "cylinder") == 0)
  {
    return BRepPrimAPI_MakeCylinder(5.0, 10.0).Shape();
  }
  if (std::strcmp(theName, "twocylinders") == 0)
  {
    BRep_Builder    aBuilder;
    TopoDS_Compound aCompound;
    aBuilder.MakeCompound(aCompound);
    aBuilder.Add(aCompound, BRepPrimAPI_MakeCylinder(5.0, 10.0).Shape());
    aBuilder.Add(aCompound, BRepPrimAPI_MakeCylinder(3.0, 7.0).Shape());
    return aCompound;
  }
  std::printf("  unknown fixture '%s'\n", theName);
  return TopoDS_Shape();
}

//! The two candidate predicates, counted the way OCCTBridge_Internal.h counts them. The columns are
//! what #2773's occtShapeSurfacelessEdgelessFaceCount and #2777's occtShapeSurfacelessFaceCount
//! answer, so a row where they differ is a row that decides which one this issue may reuse.
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
  std::printf("  %-34s type=%d faces=%d SURFACELESS=%d edgeless=%d BOTH=%d\n",
              theLabel,
              static_cast<int>(theShape.ShapeType()),
              aFaces,
              aSurfacelessFace,
              aNoEdgeFace,
              aBoth);
}

//! OSD::SetSignal, the axis that decides whether an OCC_CATCH_SIGNALS somewhere above can convert
//! the fault. None of the six bridge functions in this issue's population installs one, and
//! ShapeCustom::ApplyModifier carries no OCC_CATCH_SIGNALS of its own, so `no` is the disposition a
//! shipped call runs under and `yes` is here to show whether the kernel has a correct answer at all.
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

occ::handle<ShapeCustom_RestrictionParameters> restrictionParameters()
{
  return new ShapeCustom_RestrictionParameters;
}

//! One of the five ShapeCustom BRepTools_Modification subclasses, by name. Used by both the
//! `newsurface` case, which calls NewSurface directly, and the `modifier` case, which is the shape
//! two bridge functions take: BRepTools_Modifier over the subclass with no ShapeCustom::
//! ApplyModifier above it.
occ::handle<BRepTools_Modification> modification(const char* theWhich)
{
  if (std::strcmp(theWhich, "SweptToElementary") == 0)
  {
    return new ShapeCustom_SweptToElementary;
  }
  if (std::strcmp(theWhich, "ConvertToRevolution") == 0)
  {
    return new ShapeCustom_ConvertToRevolution;
  }
  if (std::strcmp(theWhich, "ConvertToBSpline") == 0)
  {
    occ::handle<ShapeCustom_ConvertToBSpline> aMod = new ShapeCustom_ConvertToBSpline;
    aMod->SetExtrusionMode(true);
    aMod->SetRevolutionMode(true);
    aMod->SetOffsetMode(true);
    aMod->SetPlaneMode(false);
    return aMod;
  }
  if (std::strcmp(theWhich, "DirectModification") == 0)
  {
    return new ShapeCustom_DirectModification;
  }
  if (std::strcmp(theWhich, "TrsfModification") == 0)
  {
    gp_Trsf aTrsf;
    aTrsf.SetScale(gp_Pnt(0, 0, 0), 2.0);
    return new ShapeCustom_TrsfModification(aTrsf);
  }
  if (std::strcmp(theWhich, "BSplineRestriction") == 0)
  {
    return new ShapeCustom_BSplineRestriction(true,
                                             true,
                                             true,
                                             0.01,
                                             0.01,
                                             GeomAbs_C1,
                                             GeomAbs_C1,
                                             9,
                                             100,
                                             true,
                                             false,
                                             restrictionParameters());
  }
  std::printf("  unknown modification '%s'\n", theWhich);
  return occ::handle<BRepTools_Modification>();
}

//! Face count plus the name of each face's surface type, which is what "the two spellings agree"
//! has to mean for a conversion operation. A face whose surface is null prints as (null).
std::string surfaceSignature(const TopoDS_Shape& theShape)
{
  if (theShape.IsNull())
  {
    return "NULL SHAPE";
  }
  std::string aResult;
  int         aFaces = 0;
  for (TopExp_Explorer aFaceExp(theShape, TopAbs_FACE); aFaceExp.More(); aFaceExp.Next())
  {
    const TopoDS_Face&        aFace = TopoDS::Face(aFaceExp.Current());
    TopLoc_Location           aLoc;
    occ::handle<Geom_Surface> aSurf = BRep_Tool::Surface(aFace, aLoc);
    aFaces++;
    aResult += " ";
    aResult += aSurf.IsNull() ? "(null)" : aSurf->DynamicType()->Name();
  }
  return "faces=" + std::to_string(aFaces) + aResult;
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
    describeShape("cylinder (control)", fixture("cylinder"));
    describeShape("bare", fixture("bare"));
    describeShape("compound", fixture("compound"));
    describeShape("barewithwire", fixture("barewithwire"));
    describeShape("withwire", fixture("withwire"));
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

  if (std::strcmp(aCase, "predicate") == 0 && argc >= 3)
  {
    // Both candidate predicates, side by side, on one fixture. A fixture where SURFACELESS is 1 and
    // BOTH is 0 is one #2773's pair answers false for, and the operations below decide whether that
    // false is correct here.
    describeShape(argv[2], fixture(argv[2]));
    return 0;
  }

  if (std::strcmp(aCase, "shapecustom") == 0 && argc >= 5)
  {
    const char*        aWhich = argv[2];
    const TopoDS_Shape aShape = fixture(argv[3]);
    describeShape("input", aShape);
    applySignalDisposition(argv[4]);
    std::printf("  ShapeCustom::%s...\n", aWhich);
    std::fflush(stdout);
    try
    {
      TopoDS_Shape aResult;
      if (std::strcmp(aWhich, "DirectFaces") == 0)
      {
        aResult = ShapeCustom::DirectFaces(aShape);
      }
      else if (std::strcmp(aWhich, "ScaleShape") == 0)
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
        // The flags OCCTShapeConvertToBSpline hardcodes: extrusion, revolution, offset on, planes
        // off. OCCTShapeCustomConvertToBSpline takes all four from the caller and its Swift entry
        // point defaults to exactly these, which is the duplicate question the `equivalence` case
        // measures.
        aResult = ShapeCustom::ConvertToBSpline(aShape, true, true, true, false);
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
                                                 restrictionParameters());
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

  if (std::strcmp(aCase, "newsurface") == 0 && argc >= 5)
  {
    // The faulting frame itself. Nothing runs inside NewSurface before the statements named at the
    // top of this file, so a fault here is those lines and no other. The surface handle is printed
    // first, in this same process, so the null is observed rather than inferred.
    const char*        aWhich = argv[2];
    const TopoDS_Shape aShape = fixture(argv[3]);
    describeShape("input", aShape);
    applySignalDisposition(argv[4]);
    occ::handle<BRepTools_Modification> aMod = modification(aWhich);
    if (aMod.IsNull())
    {
      return 2;
    }
    for (TopExp_Explorer aFaceExp(aShape, TopAbs_FACE); aFaceExp.More(); aFaceExp.Next())
    {
      const TopoDS_Face&        aFace = TopoDS::Face(aFaceExp.Current());
      TopLoc_Location           aReadLoc;
      occ::handle<Geom_Surface> aRead = BRep_Tool::Surface(aFace, aReadLoc);
      std::printf("  BRep_Tool::Surface(F, L) -> %s\n", aRead.IsNull() ? "NULL" : "a surface");
      std::printf("  %s::NewSurface...\n", aWhich);
      std::fflush(stdout);
      occ::handle<Geom_Surface> aSurf;
      TopLoc_Location           aLoc;
      double                    aTol      = 0.0;
      bool                      aRevWires = false;
      bool                      aRevFace  = false;
      try
      {
        const bool aNew = aMod->NewSurface(aFace, aSurf, aLoc, aTol, aRevWires, aRevFace);
        std::printf("  NewSurface -> %s\n", aNew ? "true" : "false");
      }
      catch (Standard_Failure const& anException)
      {
        std::printf("  CAUGHT at the caller: %s: %s\n",
                    typeid(anException).name(),
                    anException.GetMessageString() ? anException.GetMessageString()
                                                   : "(no message)");
      }
      std::fflush(stdout);
    }
    return 0;
  }

  if (std::strcmp(aCase, "modifier") == 0 && argc >= 5)
  {
    // BRepTools_Modifier over one modification subclass with no ShapeCustom::ApplyModifier above it.
    // This is exactly the shape of OCCTShapeConvertToBSplineAdvanced and
    // OCCTShapeCustomDirectModification, two bridge functions neither #2777 nor #2790's issue body
    // derived, because both derivations went looking for `ShapeCustom::` free-function calls.
    const char*        aWhich = argv[2];
    const TopoDS_Shape aShape = fixture(argv[3]);
    describeShape("input", aShape);
    applySignalDisposition(argv[4]);
    occ::handle<BRepTools_Modification> aMod = modification(aWhich);
    if (aMod.IsNull())
    {
      return 2;
    }
    std::printf("  BRepTools_Modifier(shape, %s)...\n", aWhich);
    std::fflush(stdout);
    try
    {
      BRepTools_Modifier aModifier(aShape, aMod);
      std::printf("  IsDone -> %s\n", aModifier.IsDone() ? "true" : "false");
      if (aModifier.IsDone())
      {
        describeShape("result", aModifier.ModifiedShape(aShape));
      }
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

  if (std::strcmp(aCase, "equivalence") == 0 && argc >= 3)
  {
    // The duplicate question, measured on a healthy shape rather than asserted from the sources.
    // Three bridge functions spell "convert surfaces to BSpline":
    //
    //   OCCTShapeConvertToBSpline        ShapeCustom::ConvertToBSpline(S, true, true, true, false)
    //   OCCTShapeCustomConvertToBSpline  ShapeCustom::ConvertToBSpline(S, e, r, o, p)
    //   OCCTShapeConvertToBSplineAdvanced  BRepTools_Modifier(S, ShapeCustom_ConvertToBSpline)
    //
    // The first two reach the same OCCT overload, so the first is the second with its arguments
    // fixed. The third skips ShapeCustom::ApplyModifier, which is not a no-op: ApplyModifier
    // orients the shape FORWARD and recurses per child over a COMPOUND, keeping a context map so a
    // shape shared between assembly children is converted once (ShapeCustom.cxx:112-147).
    const TopoDS_Shape aShape = fixture(argv[2]);
    describeShape("input", aShape);
    std::fflush(stdout);
    try
    {
      const TopoDS_Shape aViaFree = ShapeCustom::ConvertToBSpline(aShape, true, true, true, false);
      std::printf("  ShapeCustom::ConvertToBSpline(true,true,true,false)  %s\n",
                  surfaceSignature(aViaFree).c_str());

      occ::handle<ShapeCustom_ConvertToBSpline> aMod = new ShapeCustom_ConvertToBSpline;
      aMod->SetExtrusionMode(true);
      aMod->SetRevolutionMode(true);
      aMod->SetOffsetMode(true);
      aMod->SetPlaneMode(false);
      BRepTools_Modifier aModifier(aShape, aMod);
      std::printf("  BRepTools_Modifier direct  IsDone=%s  %s\n",
                  aModifier.IsDone() ? "true" : "false",
                  aModifier.IsDone() ? surfaceSignature(aModifier.ModifiedShape(aShape)).c_str()
                                     : "(not done)");

      const TopoDS_Shape aPlanes = ShapeCustom::ConvertToBSpline(aShape, true, true, true, true);
      std::printf("  ... with planeMode TRUE, which the two spellings' defaults do not use  %s\n",
                  surfaceSignature(aPlanes).c_str());
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
