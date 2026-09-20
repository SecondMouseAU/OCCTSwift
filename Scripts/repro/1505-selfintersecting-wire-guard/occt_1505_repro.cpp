// #1505: occtHasSelfIntersectingWire never actually checks a bare TopoDS_Wire for
// self-intersection, because BRepCheck_Wire::SelfIntersect() requires a TopoDS_Face context.
//
// This prototypes the fix (wrap a face-less wire in a synthesized planar face before checking)
// against the exact bowtie fixture the issue describes, and proves the *current* function body
// misses it first.
//
// Compile (macOS arm64, matches CLAUDE.md's "Compile a Ground Truth C++ Test"):
//   clang++ -std=c++17 -ObjC++ -w \
//     -I"../../../Libraries/OCCT.xcframework/macos-arm64/Headers" \
//     -L"../../../Libraries/OCCT.xcframework/macos-arm64" \
//     -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
//     occt_1505_repro.cpp -o /tmp/occt_1505_repro
//   /tmp/occt_1505_repro

#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepBuilderAPI_MakeWire.hxx>
#include <BRepCheck_Analyzer.hxx>
#include <BRepCheck_ListOfStatus.hxx>
#include <BRepCheck_Result.hxx>
#include <TopExp.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Face.hxx>
#include <TopoDS_Shape.hxx>
#include <TopoDS_Wire.hxx>
#include <TopTools_IndexedDataMapOfShapeListOfShape.hxx>
#include <TopTools_ListOfShape.hxx>
#include <gp_Pnt.hxx>

#include <cstdio>

// Build a planar, self-intersecting 4-edge "bowtie" wire:
// (0,0,0) -> (1,1,0) -> (1,0,0) -> (0,1,0) -> close back to (0,0,0).
// The two diagonals cross in the middle, so the wire self-intersects.
static TopoDS_Wire bowtieWire()
{
  gp_Pnt p0(0, 0, 0), p1(1, 1, 0), p2(1, 0, 0), p3(0, 1, 0);
  BRepBuilderAPI_MakeWire wireMaker;
  wireMaker.Add(BRepBuilderAPI_MakeEdge(p0, p1));
  wireMaker.Add(BRepBuilderAPI_MakeEdge(p1, p2));
  wireMaker.Add(BRepBuilderAPI_MakeEdge(p2, p3));
  wireMaker.Add(BRepBuilderAPI_MakeEdge(p3, p0));
  return wireMaker.Wire();
}

static TopoDS_Wire cleanSquareWire()
{
  gp_Pnt p0(0, 0, 0), p1(1, 0, 0), p2(1, 1, 0), p3(0, 1, 0);
  BRepBuilderAPI_MakeWire wireMaker;
  wireMaker.Add(BRepBuilderAPI_MakeEdge(p0, p1));
  wireMaker.Add(BRepBuilderAPI_MakeEdge(p1, p2));
  wireMaker.Add(BRepBuilderAPI_MakeEdge(p2, p3));
  wireMaker.Add(BRepBuilderAPI_MakeEdge(p3, p0));
  return wireMaker.Wire();
}

// --- CURRENT (buggy) implementation, copied verbatim from OCCTBridge.mm ---
static bool occtHasSelfIntersectingWire_CURRENT(const TopoDS_Shape &s)
{
  if (s.IsNull())
    return false;
  try
  {
    BRepCheck_Analyzer analyzer(s);
    if (analyzer.IsValid())
      return false;
    for (TopExp_Explorer we(s, TopAbs_WIRE); we.More(); we.Next())
    {
      Handle(BRepCheck_Result) res = analyzer.Result(we.Current());
      if (res.IsNull())
        continue;
      for (BRepCheck_ListIteratorOfListOfStatus it(res->Status()); it.More(); it.Next())
      {
        if (it.Value() == BRepCheck_SelfIntersectingWire)
          return true;
      }
    }
  }
  catch (...)
  {
    return true;
  }
  return false;
}

// --- PROPOSED fix ---
static bool occtHasSelfIntersectingWire_FIXED(const TopoDS_Shape &s)
{
  if (s.IsNull())
    return false;
  try
  {
    BRepCheck_Analyzer analyzer(s);
    if (!analyzer.IsValid())
    {
      for (TopExp_Explorer we(s, TopAbs_WIRE); we.More(); we.Next())
      {
        Handle(BRepCheck_Result) res = analyzer.Result(we.Current());
        if (res.IsNull())
          continue;
        for (BRepCheck_ListIteratorOfListOfStatus it(res->Status()); it.More(); it.Next())
        {
          if (it.Value() == BRepCheck_SelfIntersectingWire)
            return true;
        }
      }
    }

    // A wire with no enclosing face anywhere in `s` is never checked above, because
    // BRepCheck_Wire::SelfIntersect() needs a TopoDS_Face context. If `s` carries no face at
    // all (the bare-wire case this bridge actually produces via Shape.fromWire), synthesize a
    // planar face per wire and check that instead.
    if (TopExp_Explorer(s, TopAbs_FACE).More())
      return false;

    for (TopExp_Explorer we(s, TopAbs_WIRE); we.More(); we.Next())
    {
      const TopoDS_Wire &wire = TopoDS::Wire(we.Current());
      try
      {
        BRepBuilderAPI_MakeFace faceMaker(wire, /*OnlyPlane=*/true);
        if (!faceMaker.IsDone())
          continue; // not planar (or otherwise can't be faced): no verdict from this path
        BRepCheck_Analyzer wireAnalyzer(faceMaker.Face());
        if (wireAnalyzer.IsValid())
          continue;
        for (TopExp_Explorer fwe(faceMaker.Face(), TopAbs_WIRE); fwe.More(); fwe.Next())
        {
          Handle(BRepCheck_Result) res = wireAnalyzer.Result(fwe.Current());
          if (res.IsNull())
            continue;
          for (BRepCheck_ListIteratorOfListOfStatus it(res->Status()); it.More(); it.Next())
          {
            if (it.Value() == BRepCheck_SelfIntersectingWire)
              return true;
          }
        }
      }
      catch (...)
      {
        continue;
      }
    }
  }
  catch (...)
  {
    return true;
  }
  return false;
}

int main()
{
  TopoDS_Wire bowtie = bowtieWire();
  TopoDS_Wire clean  = cleanSquareWire();

  bool bowtieBareCurrent = occtHasSelfIntersectingWire_CURRENT(bowtie);
  bool bowtieBareFixed   = occtHasSelfIntersectingWire_FIXED(bowtie);
  bool cleanBareFixed    = occtHasSelfIntersectingWire_FIXED(clean);

  BRepBuilderAPI_MakeFace bowtieFaceMaker(bowtie, true);
  bool bowtieFaceIsDone     = bowtieFaceMaker.IsDone();
  bool bowtieFaceCurrent    = false;
  bool bowtieFaceFixed      = false;
  if (bowtieFaceIsDone)
  {
    bowtieFaceCurrent = occtHasSelfIntersectingWire_CURRENT(bowtieFaceMaker.Face());
    bowtieFaceFixed   = occtHasSelfIntersectingWire_FIXED(bowtieFaceMaker.Face());
  }

  std::printf("bowtie bare wire:  CURRENT=%d (want 0, the bug)  FIXED=%d (want 1)\n",
              bowtieBareCurrent, bowtieBareFixed);
  std::printf("clean  bare wire:  FIXED=%d (want 0, no false positive)\n", cleanBareFixed);
  std::printf("bowtie as face:    IsDone=%d  CURRENT=%d (want 1, already worked)  FIXED=%d (want 1, unchanged)\n",
              bowtieFaceIsDone, bowtieFaceCurrent, bowtieFaceFixed);

  bool ok = (bowtieBareCurrent == false) && (bowtieBareFixed == true) && (cleanBareFixed == false) &&
            (bowtieFaceIsDone == true) && (bowtieFaceCurrent == true) && (bowtieFaceFixed == true);
  std::printf(ok ? "RESULT: PASS\n" : "RESULT: FAIL\n");
  return ok ? 0 : 1;
}
