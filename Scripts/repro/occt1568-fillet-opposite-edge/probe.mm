// Ground-truth probe for upstream OCCT issue #1568, "Crash on fillet meeting opposite edge".
// Replays the attached DRAW script (test.tcl) against the pinned 8.0.1 + 29 patches kernel:
//
//   restore model.brep model
//   explode model e
//   blend result model 1.5 model_3 1.5 model_9 1.5 model_11 1.5 model_6 \
//        1.5 model_13 1.5 model_14 1.5 model_15 1.5 model_16 \
//        1.5 model_17 1.5 model_18 1.5 model_19 1.5 model_12
//
// The numbering follows DBRep.cxx's explode(): a TopExp_Explorer over TopAbs_EDGE, deduplicated
// by NCollection_Map<TopoDS_Shape, TopTools_ShapeMapHasher> (IsSame, not IsEqual), seeded with
// the parent shape. The parameters follow BRepTest_FilletCommands.cxx's BLEND(): ChFi3d_Rational,
// SetParams(ta, tesp, t2d, t3d, t2d, fl), SetContinuity(GeomAbs_C1, tapp_angle), with that file's
// static defaults.

#include <execinfo.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <vector>

#include <BRepFilletAPI_MakeFillet.hxx>
#include <BRepTools.hxx>
#include <BRep_Builder.hxx>
#include <ChFi3d_FilletShape.hxx>
#include <GeomAbs_Shape.hxx>
#include <NCollection_Map.hxx>
#include <TopExp_Explorer.hxx>
#include <TopTools_ShapeMapHasher.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Edge.hxx>
#include <TopoDS_Shape.hxx>

static const char* gStage = "start";

static void onFatalSignal(int theSig)
{
  // async-signal-unsafe in the strict sense, but this process is dying either way and the
  // stage marker is the whole point of the probe.
  fprintf(stderr, "\n*** SIGNAL %d raised at stage: %s ***\n", theSig, gStage);
  void*  aFrames[64];
  int    aCount = backtrace(aFrames, 64);
  backtrace_symbols_fd(aFrames, aCount, STDERR_FILENO);
  fflush(stderr);
  _exit(128 + theSig);
}

int main(int argc, const char** argv)
{
  signal(SIGSEGV, onFatalSignal);
  signal(SIGBUS, onFatalSignal);
  signal(SIGILL, onFatalSignal);
  signal(SIGABRT, onFatalSignal);

  const char* aPath = (argc > 1) ? argv[1] : "model.brep";

  gStage = "BRepTools::Read";
  printf("[1] reading %s\n", aPath);
  fflush(stdout);

  TopoDS_Shape aModel;
  BRep_Builder aBuilder;
  if (!BRepTools::Read(aModel, aPath, aBuilder))
  {
    printf("FAILED: could not read %s\n", aPath);
    return 1;
  }
  if (aModel.IsNull())
  {
    printf("FAILED: read produced a null shape\n");
    return 1;
  }
  printf("    shape type = %d\n", (int)aModel.ShapeType());
  fflush(stdout);

  gStage = "explode edges";
  printf("[2] exploding edges, DRAW numbering\n");
  fflush(stdout);

  NCollection_Map<TopoDS_Shape, TopTools_ShapeMapHasher> aSeen;
  aSeen.Add(aModel);
  std::vector<TopoDS_Shape>                              anEdges;  // 0-based; DRAW's model_N is [N-1]
  for (TopExp_Explorer anExp(aModel, TopAbs_EDGE); anExp.More(); anExp.Next())
  {
    if (aSeen.Add(anExp.Current()))
    {
      anEdges.push_back(anExp.Current());
    }
  }
  printf("    %zu distinct edges\n", anEdges.size());
  fflush(stdout);

  std::vector<int> aWanted = {3, 9, 11, 6, 13, 14, 15, 16, 17, 18, 19, 12};
  if (argc > 3)
  {
    aWanted.clear();
    const char* p = argv[3];
    while (*p != '\0')
    {
      aWanted.push_back(atoi(p));
      while (*p != '\0' && *p != ',') { p++; }
      if (*p == ',') { p++; }
    }
  }
  const int  aNbWanted = (int)aWanted.size();
  const double aRadius = (argc > 2) ? atof(argv[2]) : 1.5;

  for (int i = 0; i < aNbWanted; ++i)
  {
    if (aWanted[i] > (int)anEdges.size())
    {
      printf("FAILED: model_%d does not exist, only %zu edges\n", aWanted[i], anEdges.size());
      return 1;
    }
  }

  gStage = "BRepFilletAPI_MakeFillet construction";
  printf("[3] constructing BRepFilletAPI_MakeFillet, ChFi3d_Rational\n");
  fflush(stdout);

  // BRepTest_FilletCommands.cxx statics.
  const double ta = 1.e-2, tesp = 1.0e-4, t2d = 1.e-5, t3d = 1.e-4, fl = 1.e-3;
  const double tapp_angle = 1.e-2;

  BRepFilletAPI_MakeFillet aFillet(aModel, ChFi3d_Rational);
  aFillet.SetParams(ta, tesp, t2d, t3d, t2d, fl);
  aFillet.SetContinuity(GeomAbs_C1, tapp_angle);

  gStage = "Add edges";
  for (int i = 0; i < aNbWanted; ++i)
  {
    const TopoDS_Edge anEdge = TopoDS::Edge(anEdges[aWanted[i] - 1]);
    printf("[4] Add(%.3f, model_%d)\n", aRadius, aWanted[i]);
    fflush(stdout);
    aFillet.Add(aRadius, anEdge);
  }

  gStage = "BRepFilletAPI_MakeFillet::Build";
  printf("[5] Build()\n");
  fflush(stdout);

  aFillet.Build();

  gStage = "post-Build";
  printf("[6] Build returned. IsDone = %s\n", aFillet.IsDone() ? "true" : "false");
  fflush(stdout);

  if (aFillet.IsDone())
  {
    const TopoDS_Shape aResult = aFillet.Shape();
    printf("    result null = %s, type = %d\n",
           aResult.IsNull() ? "true" : "false",
           aResult.IsNull() ? -1 : (int)aResult.ShapeType());
  }
  else
  {
    printf("    NbFaultyContours = %d\n", aFillet.NbFaultyContours());
  }
  fflush(stdout);

  printf("[7] completed without a signal\n");
  return 0;
}
