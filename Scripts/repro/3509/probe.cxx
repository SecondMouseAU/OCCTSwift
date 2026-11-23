// #3509: which OCCT entry points fault on a face with no surface that carries a wire.
//
//   usage: probe <case> <fixture.brep>
//
// One process per case, because a fault is uncatchable (no OSD::SetSignal is installed here, which
// is what the bridge does only after one of its entry points has run). The fixture is read with
// BRepTools::Read, as the bridge does. Cases:
//
//   check1    BRepAlgoAPI_Check(shape)              OCCTShapeBooleanCheckSingle's call
//   check2    BRepAlgoAPI_Check(box, shape, FUSE)   OCCTShapeBooleanCheckPair's call
//   fuse      BRepAlgoAPI_Fuse(box, shape)
//   common    BRepAlgoAPI_Common(box, shape)
//   cut       BRepAlgoAPI_Cut(box, shape)
//   section   BRepAlgoAPI_Section(box, shape)
//   self      BOPAlgo_CheckerSI at the self-interference level, the route in the issue's stack
#include <BOPAlgo_CheckerSI.hxx>
#include <BRepAlgoAPI_Check.hxx>
#include <BRepAlgoAPI_Common.hxx>
#include <BRepAlgoAPI_Cut.hxx>
#include <BRepAlgoAPI_Fuse.hxx>
#include <BRepAlgoAPI_Section.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepTools.hxx>
#include <BRep_Builder.hxx>
#include <NCollection_List.hxx>
#include <TopoDS_Shape.hxx>

#include <cstdio>
#include <cstring>

int main(int argc, char** argv)
{
  if (argc < 3)
  {
    std::printf("usage: probe <case> <fixture.brep>\n");
    return 2;
  }
  TopoDS_Shape aShape;
  BRep_Builder aBuilder;
  if (!BRepTools::Read(aShape, argv[2], aBuilder))
  {
    std::printf("  could not read %s\n", argv[2]);
    return 2;
  }
  const TopoDS_Shape aBox = BRepPrimAPI_MakeBox(10.0, 10.0, 10.0).Shape();
  const char*        aCase = argv[1];

  if (std::strcmp(aCase, "check1") == 0)
  {
    BRepAlgoAPI_Check aCheck(aShape, true, true);
    std::printf("  IsValid -> %s\n", aCheck.IsValid() ? "true" : "false");
  }
  else if (std::strcmp(aCase, "check2") == 0)
  {
    BRepAlgoAPI_Check aCheck(aBox, aShape, BOPAlgo_FUSE, true, true);
    std::printf("  IsValid -> %s\n", aCheck.IsValid() ? "true" : "false");
  }
  else if (std::strcmp(aCase, "fuse") == 0)
  {
    BRepAlgoAPI_Fuse anOp(aBox, aShape);
    std::printf("  IsDone -> %s, HasErrors -> %s\n", anOp.IsDone() ? "true" : "false",
                anOp.HasErrors() ? "true" : "false");
  }
  else if (std::strcmp(aCase, "common") == 0)
  {
    BRepAlgoAPI_Common anOp(aBox, aShape);
    std::printf("  IsDone -> %s, HasErrors -> %s\n", anOp.IsDone() ? "true" : "false",
                anOp.HasErrors() ? "true" : "false");
  }
  else if (std::strcmp(aCase, "cut") == 0)
  {
    BRepAlgoAPI_Cut anOp(aBox, aShape);
    std::printf("  IsDone -> %s, HasErrors -> %s\n", anOp.IsDone() ? "true" : "false",
                anOp.HasErrors() ? "true" : "false");
  }
  else if (std::strcmp(aCase, "section") == 0)
  {
    BRepAlgoAPI_Section anOp(aBox, aShape);
    std::printf("  IsDone -> %s, HasErrors -> %s\n", anOp.IsDone() ? "true" : "false",
                anOp.HasErrors() ? "true" : "false");
  }
  else if (std::strcmp(aCase, "self") == 0)
  {
    NCollection_List<TopoDS_Shape> aList;
    aList.Append(aShape);
    BOPAlgo_CheckerSI aChecker;
    aChecker.SetArguments(aList);
    aChecker.SetLevelOfCheck(5);
    aChecker.Perform();
    std::printf("  HasErrors -> %s\n", aChecker.HasErrors() ? "true" : "false");
  }
  else
  {
    std::printf("  unknown case %s\n", aCase);
    return 2;
  }
  std::printf("  returned\n");
  return 0;
}
