// #2174: the smoke link. A C++ main over libOCCT-wasm.a, with no Swift and no bridge.
//
// Keeping Swift out is the point. Three link-time risks were opened by #2171 and left unreachable
// by #2172 and #2173, and every one of them is a property of the ARCHIVE:
//
//   * the libc++ seam. The Swift SDK's prebuilt libc++.a references no __cxa_throw at all, so its
//     copies of std::__throw_* abort where wasi-sdk's eh runtime throws. #2171 recorded the
//     outcome as weak-symbol resolution, therefore link-order dependent, and worth re-checking at
//     OCCT scale. Case 5 is that check; README.md has what it found, which is that libc++ ABI-tags
//     the two apart and they cannot be confused.
//   * operator new and std::bad_alloc, which #2171 did not probe at all. That one is
//     probe-alloc.cxx, separately, because its failure mode is a trap that would take every
//     other measurement with it.
//   * -lsetjmp and -lwasi-emulated-getpid, which have never been on a link command line.
//     run.sh's `libs` case removes each in turn and records what the link says.
//
// If this program fails, the statement is about libOCCT-wasm.a. Were the bridge and the Swift
// runtime in the picture, it could equally be about Package.swift, which is #2048's and #2175's.
//
// STEP export is probe-step.cxx, a separate executable, and it is separate for a measured reason:
// the one source file this build does not compile, STEPConstruct_AP203Context.cxx, is on the STEP
// writer's own path, so a probe with STEP in it does not link at all and takes every other case
// with it. Keeping them apart is what lets the archive be proved while that gap is open.
//
// Every case prints `case <name>: ...` and a PASS/FAIL, and main returns the number of failures,
// so the exit status is the count and not a boolean.

#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <stdexcept>
#include <vector>

#include <BRepGProp.hxx>
#include <BRepMesh_IncrementalMesh.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRep_Tool.hxx>
#include <GProp_GProps.hxx>
#include <Geom_CartesianPoint.hxx>
#include <Poly_Triangulation.hxx>
#include <NCollection_IndexedMap.hxx>
#include <Standard_Failure.hxx>
#include <TopAbs_ShapeEnum.hxx>
#include <TopExp.hxx>
#include <TopExp_Explorer.hxx>
#include <TopLoc_Location.hxx>
#include <TopTools_ShapeMapHasher.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Face.hxx>
#include <TopoDS_Shape.hxx>
#include <gp_Pnt.hxx>

static int gFailures = 0;

static void check(const char* theCase, bool theOk, const char* theDetail)
{
  std::printf("case %-22s %-5s %s\n", theCase, theOk ? "PASS" : "FAIL", theDetail);
  if (!theOk)
  {
    ++gFailures;
  }
}

// 1. A real OCCT object held by a Handle: constructed, refcounted, read back, released.
static void caseHandle()
{
  char aDetail[256];
  int  aHeld = 0, aShared = 0;
  double aSum = 0.0;
  {
    Handle(Geom_CartesianPoint) aPoint = new Geom_CartesianPoint(1.0, 2.0, 3.0);
    aHeld                              = aPoint->GetRefCount();
    {
      Handle(Geom_CartesianPoint) aSecond = aPoint;
      aShared                             = aPoint->GetRefCount();
    }
    const gp_Pnt aXYZ = aPoint->Pnt();
    aSum              = aXYZ.X() + aXYZ.Y() + aXYZ.Z();
  }
  std::snprintf(aDetail, sizeof(aDetail),
                "Geom_CartesianPoint(1,2,3) x+y+z=%.1f, refcount 1 held=%d, 2 holders=%d", aSum,
                aHeld, aShared);
  check("handle", aSum == 6.0 && aHeld == 1 && aShared == 2, aDetail);
}

// 2. OCCT raises Standard_Failure from inside its own compiled code, and we catch it here.
//
// BRepPrimAPI_MakeBox(0,0,0) reaches BRepPrim_GWedge.cxx, which throws Standard_DomainError. The
// raise is in a TKPrim object of the archive and the handler is in this file, so a catch proves
// the unwinder crosses the archive boundary rather than proving anything about one file.
static void caseRaise()
{
  char aDetail[256];
  bool aCaught = false;
  char aType[128];
  aType[0] = '\0';
  try
  {
    BRepPrimAPI_MakeBox aBox(0.0, 0.0, 0.0);
    (void)aBox.Shape();
  }
  catch (const Standard_Failure& theFailure)
  {
    aCaught = true;
    std::snprintf(aType, sizeof(aType), "%s", theFailure.ExceptionType());
  }
  std::snprintf(aDetail, sizeof(aDetail),
                "MakeBox(0,0,0) raised from TKPrim and was caught as %s",
                aCaught ? aType : "<nothing raised>");
  check("raise-from-occt", aCaught && std::strcmp(aType, "Standard_DomainError") == 0, aDetail);
}

// 3. Real modelling: a solid, its volume, and its topology counts.
static TopoDS_Shape gBox;

static void caseModelling()
{
  char aDetail[256];
  gBox = BRepPrimAPI_MakeBox(10.0, 20.0, 30.0).Shape();
  GProp_GProps aProps;
  BRepGProp::VolumeProperties(gBox, aProps);
  const double aVolume = aProps.Mass();
  // TopExp::MapShapes, not a TopExp_Explorer count. An explorer visits a shared sub-shape once per
  // owner, so exploring a box for edges yields 24: twelve edges, each reached through two faces.
  // The first version of this case counted that way and asserted 12, and the probe reported FAIL
  // against a perfectly correct box.
  NCollection_IndexedMap<TopoDS_Shape, TopTools_ShapeMapHasher> aFaceMap, anEdgeMap;
  TopExp::MapShapes(gBox, TopAbs_FACE, aFaceMap);
  TopExp::MapShapes(gBox, TopAbs_EDGE, anEdgeMap);
  const int aFaces  = aFaceMap.Extent();
  const int anEdges = anEdgeMap.Extent();
  std::snprintf(aDetail, sizeof(aDetail), "box 10x20x30 volume=%.1f faces=%d edges=%d", aVolume,
                aFaces, anEdges);
  check("modelling", aVolume > 5999.9 && aVolume < 6000.1 && aFaces == 6 && anEdges == 12, aDetail);
}

// 4. Meshing, which is the other half of #1689's scope and a different set of toolkits.
static void caseMesh()
{
  char aDetail[256];
  BRepMesh_IncrementalMesh aMesher(gBox, 1.0);
  int                      aTriangles = 0, aNodes = 0;
  for (TopExp_Explorer anExp(gBox, TopAbs_FACE); anExp.More(); anExp.Next())
  {
    TopLoc_Location            aLoc;
    Handle(Poly_Triangulation) aTri = BRep_Tool::Triangulation(TopoDS::Face(anExp.Current()), aLoc);
    if (!aTri.IsNull())
    {
      aTriangles += aTri->NbTriangles();
      aNodes += aTri->NbNodes();
    }
  }
  std::snprintf(aDetail, sizeof(aDetail), "IsDone=%d triangles=%d nodes=%d",
                aMesher.IsDone() ? 1 : 0, aTriangles, aNodes);
  check("mesh", aMesher.IsDone() && aTriangles >= 12 && aNodes >= 8, aDetail);
}

// 5. The libc++ seam, the single most important thing this probe can settle.
//
// std::vector::at raises through std::__throw_out_of_range, which WASI.sdk's prebuilt libc++
// defines as an abort() because that libc++ is built with exceptions off, and which our own
// exception-enabled compile defines as a throw. #2171 recorded the outcome as weak-symbol
// resolution and therefore link-order dependent. It is not: libc++ ABI-tags the two with
// _LIBCPP_ODR_SIGNATURE, so they are `...B8ne210106...` and `...B8nn210106...` and cannot be
// confused for each other. The measurement is in README.md; this case is the behavioural half of
// it, and if the aborting definition were ever reached it would kill the process here rather than
// fail.
static void caseLibcxxSeam()
{
  char aDetail[256];
  std::vector<int> aVector;
  aVector.push_back(7);
  bool aCaught = false;
  char aWhat[128];
  aWhat[0] = '\0';
  try
  {
    (void)aVector.at(3);
  }
  catch (const std::out_of_range& theError)
  {
    aCaught = true;
    std::snprintf(aWhat, sizeof(aWhat), "%s", theError.what());
  }
  std::snprintf(aDetail, sizeof(aDetail), "vector::at(3) on size 1 threw std::out_of_range: %s",
                aCaught ? aWhat : "<nothing; the aborting definition would not get this far>");
  check("libcxx-seam", aCaught, aDetail);
}

int main()
{
  std::printf("OCCT smoke probe, wasm32-unknown-wasip1, C++ only (no Swift, no bridge)\n");
  caseHandle();
  caseRaise();
  caseModelling();
  caseMesh();
  caseLibcxxSeam();
  std::printf("failures: %d\n", gFailures);
  return gFailures;
}
