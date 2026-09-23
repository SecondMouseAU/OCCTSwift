// #2061: STEPControl_ActorRead's NM_DETECTED is a process-global non-manifold flag.
//
// One thread reads a STEP file containing a NON_MANIFOLD_SURFACE_SHAPE_REPRESENTATION, which sets
// the flag. Another reads a plain manifold assembly whose NAUO child transfers to a COMPOUND. At
// STEPControl_ActorRead.cxx:734/:797 a set flag makes that compound be FLATTENED into the parent
// instead of nested, so the second thread gets a structurally different shape through no fault of
// its own.
//
//   correct    root COMPOUND -> [ COMPOUND(2 solids), SOLID ]      2 direct children
//   corrupted  root COMPOUND -> [ SOLID, SOLID, SOLID ]            3 direct children
//
// Exit 0 when every manifold read came back correct, 1 when any did not.

#include <BRep_Builder.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepBuilderAPI_MakePolygon.hxx>
#include <BRepBuilderAPI_Sewing.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <Interface_Static.hxx>
#include <STEPControl_Controller.hxx>
#include <STEPControl_Reader.hxx>
#include <STEPControl_Writer.hxx>
#include <TopoDS_Compound.hxx>
#include <TopoDS_Iterator.hxx>

#include <atomic>
#include <cstdlib>
#include <iostream>
#include <string>
#include <thread>
#include <vector>

namespace
{

//! Components in the manifold assembly; each is a compound of two solids.
const int THE_COMPONENTS = 4;
//! Solids per component. Widens the reset-to-read window.
const int THE_SOLIDS_PER_COMPONENT = 12;

std::atomic<int> theCorrupted(0);
std::atomic<int> theChecked(0);
std::atomic<int> theReadFailures(0);

TopoDS_Shape quad(gp_Pnt a, gp_Pnt b, gp_Pnt c, gp_Pnt d)
{
  BRepBuilderAPI_MakePolygon aPoly(a, b, c, d, true);
  return BRepBuilderAPI_MakeFace(aPoly.Wire()).Shape();
}

//! A compound holding an edge shared by three faces: what makes the writer emit an NMSSR.
bool writeNonManifold(const std::string& theFile)
{
  BRepBuilderAPI_Sewing aSew(1e-6);
  aSew.SetNonManifoldMode(true);
  aSew.Add(quad({0, 0, 0}, {10, 0, 0}, {10, 10, 0}, {0, 10, 0}));
  aSew.Add(quad({0, 0, 0}, {10, 0, 0}, {10, 0, 10}, {0, 0, 10}));
  aSew.Add(quad({0, 0, 0}, {10, 0, 0}, {10, -10, 0}, {0, -10, 0}));
  aSew.Perform();

  BRep_Builder    aB;
  TopoDS_Compound aC;
  aB.MakeCompound(aC);
  aB.Add(aC, aSew.SewedShape());

  Interface_Static::SetIVal("write.step.assembly", 0);
  Interface_Static::SetIVal("write.step.nonmanifold", 1);
  STEPControl_Writer aW;
  return aW.Transfer(aC, STEPControl_AsIs) == IFSelect_RetDone
         && aW.Write(theFile.c_str()) == IFSelect_RetDone;
}

//! An assembly whose first component is a compound of two solids, so its NAUO child comes back as
//! a COMPOUND, which is the only shape the branch under test can alter.
bool writeManifoldAssembly(const std::string& theFile)
{
  // EVERY component is itself a compound, so every NAUO child read at :734/:797 has a COMPOUND
  // result. With only one compound component the flag could leak on a read whose result was not a
  // compound, and the corruption stayed invisible; measured 25 leaked reads and 0 corruptions.
  BRep_Builder    aB;
  TopoDS_Compound aRoot;
  aB.MakeCompound(aRoot);
  for (int i = 0; i < THE_COMPONENTS; i++)
  {
    TopoDS_Compound anInner;
    aB.MakeCompound(anInner);
    // Many solids per component: the flag is reset at the START of the component's transfer and
    // read only after it finishes, so a heavy component is what makes that window wide enough for
    // another thread's set to land in it.
    for (int j = 0; j < THE_SOLIDS_PER_COMPONENT; j++)
      aB.Add(anInner,
             BRepPrimAPI_MakeBox(gp_Pnt(i * 300.0 + j * 15.0, 0, 0), 10.0, 10.0, 10.0).Shape());
    aB.Add(aRoot, anInner);
  }

  Interface_Static::SetIVal("write.step.assembly", 1);
  Interface_Static::SetIVal("write.step.nonmanifold", 0);
  STEPControl_Writer aW;
  return aW.Transfer(aRoot, STEPControl_AsIs) == IFSelect_RetDone
         && aW.Write(theFile.c_str()) == IFSelect_RetDone;
}

void readNonManifold(const std::string& theFile, int theIters)
{
  for (int i = 0; i < theIters; i++)
  {
    STEPControl_Reader aR;
    if (aR.ReadFile(theFile.c_str()) != IFSelect_RetDone)
    {
      theReadFailures++;
      continue;
    }
    aR.TransferRoots();
  }
}

void readManifoldAndCheck(const std::string& theFile, int theIters)
{
  for (int i = 0; i < theIters; i++)
  {
    STEPControl_Reader aR;
    if (aR.ReadFile(theFile.c_str()) != IFSelect_RetDone)
    {
      theReadFailures++;
      continue;
    }
    aR.TransferRoots();
    if (aR.NbShapes() < 1)
    {
      theReadFailures++;
      continue;
    }
    const TopoDS_Shape aRoot = aR.Shape(1);

    int aDirect = 0, aCompounds = 0;
    for (TopoDS_Iterator it(aRoot); it.More(); it.Next())
    {
      aDirect++;
      if (it.Value().ShapeType() == TopAbs_COMPOUND)
        aCompounds++;
    }
    theChecked++;
    // Correct: every component survives as its own nested compound. A leaked flag flattens one or
    // more of them, raising the direct-child count and lowering the compound count together.
    if (aDirect != THE_COMPONENTS || aCompounds != THE_COMPONENTS)
      theCorrupted++;
  }
}

} // namespace

int main(int argc, char** argv)
{
  const int   aThreads = (argc > 1) ? std::atoi(argv[1]) : 4;
  const int   aIters   = (argc > 2) ? std::atoi(argv[2]) : 10;
  std::string aDir     = (argc > 3) ? argv[3] : "/tmp";
  const std::string aNM  = aDir + "/occt2061_nonmanifold.step";
  const std::string aASM = aDir + "/occt2061_assembly.step";

  // Init first: Interface_Static::SetIVal silently fails on a parameter not yet declared.
  STEPControl_Controller::Init();

  if (!writeNonManifold(aNM) || !writeManifoldAssembly(aASM))
  {
    std::cout << "FIXTURE GENERATION FAILED" << std::endl;
    return 2;
  }
  Interface_Static::SetIVal("read.step.nonmanifold", 1);

  std::vector<std::thread> aPool;
  for (int t = 0; t < aThreads; t++)
  {
    // Alternating. A 3:1 skew toward the setters was tried and measured WORSE: it lowered total
    // contention on the flag and TSan stopped reporting it at all.
    if (t % 2 == 0)
      aPool.emplace_back(readNonManifold, aNM, aIters);
    else
      aPool.emplace_back(readManifoldAndCheck, aASM, aIters);
  }
  for (auto& t : aPool)
    t.join();

  std::cout << "checked=" << theChecked.load() << " corrupted=" << theCorrupted.load()
            << " readFailures=" << theReadFailures.load() << std::endl;
  if (theCorrupted.load() > 0)
  {
    std::cout << "FAIL: a manifold assembly came back flattened (#2061)" << std::endl;
    return 1;
  }
  std::cout << "PASS: every manifold assembly kept its nested compound" << std::endl;
  return 0;
}
