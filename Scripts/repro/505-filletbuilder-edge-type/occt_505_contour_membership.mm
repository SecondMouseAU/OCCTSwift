// OCCTSwift#505 ground truth, probe 2: what BRepFilletAPI_MakeFillet's three edge-keyed accessors
// do when the edge is not the one they were asked about.
//
// GetBounds/GetLaw/SetLaw all reach ChFiDS_FilSpine::ChangeLaw(E), which resolves the edge with
// ChFiDS_Spine::Index(E) and returns 0 for an edge the contour does not contain. Every use of that
// index downstream (FirstParameter(IE) -> abscissa->Value(IE - 1)) is unchecked, because OCCT's own
// *_Raise_if bounds checks are compiled out of the pinned Release build. This probe measures the
// consequence, plus the two documented throws (before Build, and on a constant contour).
//
// Each case runs in a forked child, so a case that dies by signal still leaves the rest measurable.
//
// Compile:
//   clang++ -std=c++17 -ObjC++ -w \
//     -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
//     -L"Libraries/OCCT.xcframework/macos-arm64" \
//     -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
//     Scripts/repro/505-filletbuilder-edge-type/occt_505_contour_membership.mm \
//     -o /tmp/occt_505_contour_membership

#include <BRepFilletAPI_MakeFillet.hxx>
#include <BRepGProp.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <GProp_GProps.hxx>
#include <Law_Function.hxx>
#include <Law_Linear.hxx>
#include <Standard_Failure.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Edge.hxx>
#include <TopoDS_Shape.hxx>

#include <cstdio>
#include <functional>
#include <sys/wait.h>
#include <typeinfo>
#include <unistd.h>

static TopoDS_Shape makeBox()
{
  return BRepPrimAPI_MakeBox(10.0, 10.0, 10.0).Shape();
}

static void collectEdges(const TopoDS_Shape& theShape, TopoDS_Edge theEdges[], const int theCount)
{
  TopExp_Explorer anExp(theShape, TopAbs_EDGE);
  for (int i = 0; i < theCount && anExp.More(); anExp.Next(), ++i)
  {
    theEdges[i] = TopoDS::Edge(anExp.Current());
  }
}

static double volumeOf(const TopoDS_Shape& theShape)
{
  GProp_GProps aProps;
  BRepGProp::VolumeProperties(theShape, aProps);
  return aProps.Mass();
}

// Runs one case in a child process and reports how it ended.
static void runCase(const char* theName, const std::function<void()>& theBody)
{
  fflush(stdout);
  const pid_t aPid = fork();
  if (aPid == 0)
  {
    try
    {
      theBody();
    }
    catch (const Standard_Failure& aFail)
    {
      printf("  threw %s: %s\n",
             typeid(aFail).name(),
             aFail.GetMessageString() ? aFail.GetMessageString() : "");
    }
    catch (...)
    {
      printf("  threw a non-Standard_Failure exception\n");
    }
    fflush(stdout);
    _exit(0);
  }
  int aStatus = 0;
  waitpid(aPid, &aStatus, 0);
  if (WIFSIGNALED(aStatus))
  {
    printf("  [%s] died by signal %d\n", theName, WTERMSIG(aStatus));
  }
  else
  {
    printf("  [%s] exited %d\n", theName, WEXITSTATUS(aStatus));
  }
}

int main()
{
  // ---- case 1: two contours, ask contour 1 about contour 2's edge --------------------------
  printf("case 1: GetBounds/GetLaw for an edge belonging to a different contour\n");
  runCase("cross-contour read", [] {
    const TopoDS_Shape aBox = makeBox();
    TopoDS_Edge        anEdges[4];
    collectEdges(aBox, anEdges, 4);

    BRepFilletAPI_MakeFillet aFillet(aBox);
    aFillet.Add(0.5, 2.0, anEdges[0]); // contour 1
    aFillet.Add(1.0, 3.0, anEdges[2]); // contour 2
    aFillet.Build();
    printf("  IsDone=%d NbContours=%d Contour(e0)=%d Contour(e2)=%d\n",
           (int)aFillet.IsDone(),
           aFillet.NbContours(),
           aFillet.Contour(anEdges[0]),
           aFillet.Contour(anEdges[2]));

    for (int aC = 1; aC <= 2; ++aC)
    {
      for (int anE = 0; anE < 3; anE += 2)
      {
        double aF = -1.0, aL = -1.0;
        const bool anOk = aFillet.GetBounds(aC, anEdges[anE], aF, aL);
        occ::handle<Law_Function> aLaw = aFillet.GetLaw(aC, anEdges[anE]);
        printf("  GetBounds(%d, e%d)=%d [%.9f, %.9f]  law=%p  law(first)=%.9f law(last)=%.9f\n",
               aC,
               anE,
               (int)anOk,
               aF,
               aL,
               (void*)aLaw.get(),
               aLaw.IsNull() ? -1.0 : aLaw->Value(aF),
               aLaw.IsNull() ? -1.0 : aLaw->Value(aL));
      }
    }
  });

  // ---- case 2: an edge in no contour at all -------------------------------------------------
  printf("case 2: GetBounds/GetLaw for an edge in no contour (Index(E) == 0)\n");
  runCase("orphan read", [] {
    const TopoDS_Shape aBox = makeBox();
    TopoDS_Edge        anEdges[4];
    collectEdges(aBox, anEdges, 4);

    BRepFilletAPI_MakeFillet aFillet(aBox);
    aFillet.Add(0.5, 2.0, anEdges[0]);
    aFillet.Build();
    printf("  Contour(e1)=%d (0 means no contour holds it)\n", aFillet.Contour(anEdges[1]));

    double     aF = -1.0, aL = -1.0;
    const bool anOk = aFillet.GetBounds(1, anEdges[1], aF, aL);
    printf("  GetBounds(1, e1)=%d [%.9f, %.9f]\n", (int)anOk, aF, aL);
    occ::handle<Law_Function> aLaw = aFillet.GetLaw(1, anEdges[1]);
    printf("  GetLaw(1, e1)=%p\n", (void*)aLaw.get());
  });

  // ---- case 3: SetLaw for an edge in no contour ---------------------------------------------
  printf("case 3: SetLaw for an edge in no contour (writes through the same index)\n");
  runCase("orphan write", [] {
    const TopoDS_Shape aBox = makeBox();
    TopoDS_Edge        anEdges[4];
    collectEdges(aBox, anEdges, 4);

    BRepFilletAPI_MakeFillet aFillet(aBox);
    aFillet.Add(0.5, 2.0, anEdges[0]);
    aFillet.Build();

    double aF = 0.0, aL = 1.0;
    aFillet.GetBounds(1, anEdges[0], aF, aL);
    occ::handle<Law_Linear> aLaw = new Law_Linear();
    aLaw->Set(aF, 4.0, aL, 4.0);

    printf("  SetLaw(1, e1 /* not in any contour */, law) ...\n");
    fflush(stdout);
    aFillet.SetLaw(1, anEdges[1], aLaw);
    printf("  returned\n");

    occ::handle<Law_Function> aBack = aFillet.GetLaw(1, anEdges[0]);
    printf("  GetLaw(1, e0) after the foreign SetLaw: %p value(first)=%.9f\n",
           (void*)aBack.get(),
           aBack.IsNull() ? -1.0 : aBack->Value(aF));
  });

  // ---- case 4: before Build -----------------------------------------------------------------
  printf("case 4: the same three calls before Build\n");
  runCase("pre-build", [] {
    const TopoDS_Shape aBox = makeBox();
    TopoDS_Edge        anEdges[4];
    collectEdges(aBox, anEdges, 4);

    BRepFilletAPI_MakeFillet aFillet(aBox);
    aFillet.Add(0.5, 2.0, anEdges[0]);

    double aF = -1.0, aL = -1.0;
    try
    {
      const bool anOk = aFillet.GetBounds(1, anEdges[0], aF, aL);
      printf("  GetBounds before Build=%d\n", (int)anOk);
    }
    catch (const Standard_Failure& aFail)
    {
      printf("  GetBounds before Build threw: %s\n",
             aFail.GetMessageString() ? aFail.GetMessageString() : "");
    }
  });

  // ---- case 5: a constant-radius contour ----------------------------------------------------
  printf("case 5: the same three calls on a constant-radius contour\n");
  runCase("constant contour", [] {
    const TopoDS_Shape aBox = makeBox();
    TopoDS_Edge        anEdges[4];
    collectEdges(aBox, anEdges, 4);

    BRepFilletAPI_MakeFillet aFillet(aBox);
    aFillet.Add(1.0, anEdges[0]);
    aFillet.Build();
    printf("  IsDone=%d IsConstant(1)=%d\n", (int)aFillet.IsDone(), (int)aFillet.IsConstant(1));

    double aF = -1.0, aL = -1.0;
    try
    {
      const bool anOk = aFillet.GetBounds(1, anEdges[0], aF, aL);
      printf("  GetBounds on constant contour=%d [%.9f, %.9f]\n", (int)anOk, aF, aL);
    }
    catch (const Standard_Failure& aFail)
    {
      printf("  GetBounds on constant contour threw: %s\n",
             aFail.GetMessageString() ? aFail.GetMessageString() : "");
    }
    try
    {
      occ::handle<Law_Function> aLaw = aFillet.GetLaw(1, anEdges[0]);
      printf("  GetLaw on constant contour=%p\n", (void*)aLaw.get());
    }
    catch (const Standard_Failure& aFail)
    {
      printf("  GetLaw on constant contour threw: %s\n",
             aFail.GetMessageString() ? aFail.GetMessageString() : "");
    }
  });

  // ---- case 6: does SetLaw change the built result? -----------------------------------------
  printf("case 6: SetLaw on the right edge, then rebuild\n");
  for (const double aNewRadius : {3.0, 1.0, 0.2})
  {
    runCase("setlaw effect", [aNewRadius] {
      const TopoDS_Shape aBox = makeBox();
      TopoDS_Edge        anEdges[4];
      collectEdges(aBox, anEdges, 4);

      BRepFilletAPI_MakeFillet aFillet(aBox);
      aFillet.Add(0.5, 2.0, anEdges[0]);
      aFillet.Build();
      const double aBefore = volumeOf(aFillet.Shape());

      double aF = 0.0, aL = 1.0;
      aFillet.GetBounds(1, anEdges[0], aF, aL);
      occ::handle<Law_Linear> aLaw = new Law_Linear();
      aLaw->Set(aF, aNewRadius, aL, aNewRadius);
      aFillet.SetLaw(1, anEdges[0], aLaw);

      occ::handle<Law_Function> aBack = aFillet.GetLaw(1, anEdges[0]);
      printf("  radius law %.1f: read back value(first)=%.9f value(last)=%.9f\n",
             aNewRadius,
             aBack.IsNull() ? -1.0 : aBack->Value(aF),
             aBack.IsNull() ? -1.0 : aBack->Value(aL));

      aFillet.Build();
      printf("  rebuild: IsDone=%d HasResult=%d volume before=%.6f after=%.6f changed=%d\n",
             (int)aFillet.IsDone(),
             (int)aFillet.HasResult(),
             aBefore,
             aFillet.HasResult() ? volumeOf(aFillet.Shape()) : -1.0,
             (int)(aFillet.HasResult() && std::abs(aBefore - volumeOf(aFillet.Shape())) > 1e-6));
    });
  }

  // ---- case 7: is there an order in which SetLaw reaches the geometry? ----------------------
  // ChangeLaw needs SplitDone(), which Build() sets, so SetLaw cannot precede the first Build.
  // Simulate(IC) performs the same spine split without building the surfaces, so try it as the
  // way in.
  printf("case 7: Simulate, SetLaw, then Build\n");
  runCase("simulate then setlaw", [] {
    const TopoDS_Shape aBox = makeBox();
    TopoDS_Edge        anEdges[4];
    collectEdges(aBox, anEdges, 4);

    BRepFilletAPI_MakeFillet aReference(aBox);
    aReference.Add(3.0, anEdges[0]);
    aReference.Build();
    printf("  reference Add(3.0) volume=%.6f\n",
           aReference.IsDone() ? volumeOf(aReference.Shape()) : -1.0);

    BRepFilletAPI_MakeFillet aFillet(aBox);
    aFillet.Add(0.5, 2.0, anEdges[0]);
    try
    {
      aFillet.Simulate(1);
      printf("  Simulate(1) ok, NbSurf=%d\n", aFillet.NbSurf(1));
    }
    catch (const Standard_Failure& aFail)
    {
      printf("  Simulate(1) threw: %s\n", aFail.GetMessageString() ? aFail.GetMessageString() : "");
    }

    double aF = 0.0, aL = 1.0;
    try
    {
      const bool anOk = aFillet.GetBounds(1, anEdges[0], aF, aL);
      printf("  GetBounds after Simulate=%d [%.9f, %.9f]\n", (int)anOk, aF, aL);
      occ::handle<Law_Linear> aLaw = new Law_Linear();
      aLaw->Set(aF, 3.0, aL, 3.0);
      aFillet.SetLaw(1, anEdges[0], aLaw);
      printf("  SetLaw after Simulate ok\n");
    }
    catch (const Standard_Failure& aFail)
    {
      printf("  GetBounds/SetLaw after Simulate threw: %s\n",
             aFail.GetMessageString() ? aFail.GetMessageString() : "");
      return;
    }

    aFillet.Build();
    printf("  Build after SetLaw: IsDone=%d volume=%.6f\n",
           (int)aFillet.IsDone(),
           aFillet.IsDone() ? volumeOf(aFillet.Shape()) : -1.0);
  });

  // ---- case 8: what Shape() is after the second Build ---------------------------------------
  printf("case 8: the shape a post-SetLaw rebuild hands back\n");
  runCase("rebuilt shape identity", [] {
    const TopoDS_Shape aBox = makeBox();
    TopoDS_Edge        anEdges[4];
    collectEdges(aBox, anEdges, 4);

    BRepFilletAPI_MakeFillet aFillet(aBox);
    aFillet.Add(0.5, 2.0, anEdges[0]);
    aFillet.Build();
    const TopoDS_Shape aFilleted = aFillet.Shape();
    printf("  first build : volume=%.6f IsSame(box)=%d\n",
           volumeOf(aFilleted),
           (int)aFilleted.IsSame(aBox));

    double aF = 0.0, aL = 1.0;
    aFillet.GetBounds(1, anEdges[0], aF, aL);
    occ::handle<Law_Linear> aLaw = new Law_Linear();
    aLaw->Set(aF, 3.0, aL, 3.0);
    aFillet.SetLaw(1, anEdges[0], aLaw);
    aFillet.Build();
    const TopoDS_Shape aRebuilt = aFillet.Shape();
    printf("  second build: volume=%.6f IsSame(box)=%d IsSame(first)=%d IsDone=%d\n",
           volumeOf(aRebuilt),
           (int)aRebuilt.IsSame(aBox),
           (int)aRebuilt.IsSame(aFilleted),
           (int)aFillet.IsDone());
  });

  // ---- case 9: out-of-range contour indices --------------------------------------------------
  // ChFi3d_FilBuilder::GetBounds guards IC <= NbElements() but not IC >= 1, and Value(IC) has no
  // live bounds check either.
  printf("case 9: out-of-range contour indices\n");
  for (const int aContour : {0, -1, 2, 99})
  {
    runCase("contour index", [aContour] {
      const TopoDS_Shape aBox = makeBox();
      TopoDS_Edge        anEdges[4];
      collectEdges(aBox, anEdges, 4);

      BRepFilletAPI_MakeFillet aFillet(aBox);
      aFillet.Add(0.5, 2.0, anEdges[0]);
      aFillet.Build();

      double aF = -1.0, aL = -1.0;
      printf("  GetBounds(%d, e0) ...\n", aContour);
      fflush(stdout);
      const bool anOk = aFillet.GetBounds(aContour, anEdges[0], aF, aL);
      printf("  GetBounds(%d, e0)=%d [%.9f, %.9f]\n", aContour, (int)anOk, aF, aL);
    });
  }

  printf("done\n");
  return 0;
}
