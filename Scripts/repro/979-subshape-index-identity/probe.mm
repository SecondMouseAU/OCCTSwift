/*
 * Probe: can one ELEMENT of a sub-shape enumeration fail, leaving a hole?
 *
 * Shape.faces(), Shape.edges() and Shape.subShapes(ofType:) each drop an element whose bridge
 * handle came back null, which shifts every later ordinal (#979). Before choosing a fix, measure
 * what actually produces a null at position i.
 *
 * All three enumerations bottom out in occtMapSubShapes (OCCTBridge_Internal.h), which is
 * TopExp::MapShapes into a TopTools_IndexedMapOfShape, plus a per-element allocation. So the
 * questions this probe answers, per shape, are:
 *
 *   Q1  Can TopTools_IndexedMapOfShape hold a null entry, so map(i + 1) is null mid-range?
 *   Q2  Is Extent() stable across repeated calls, so a count taken by one call can be a valid
 *       index for a later one? (Shape.edges() takes its count and its elements from separate
 *       bridge calls, one map build each.)
 *   Q3  Can map(i + 1) hold something the per-element TopoDS::Face / TopoDS::Edge downcast
 *       rejects, so the element throws while its neighbours succeed?
 *
 * Battery is deliberately hostile: null shape, empty compound, shared sub-shapes, an unclosed
 * solid, degenerate edges, an INTERNAL-orientation face, and a large compound.
 *
 * Compile against the pinned xcframework:
 *   clang++ -std=c++17 -ObjC++ -w \
 *     -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
 *     -L"Libraries/OCCT.xcframework/macos-arm64" \
 *     -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
 *     Scripts/repro/979-subshape-index-identity/probe.mm -o /tmp/probe979
 *
 * Run: /tmp/probe979
 */

#include <BRepBuilderAPI_MakeSolid.hxx>
#include <BRepBuilderAPI_MakeVertex.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeCone.hxx>
#include <BRepPrimAPI_MakeSphere.hxx>
#include <BRepAlgoAPI_Common.hxx>
#include <BRep_Builder.hxx>
#include <TopExp.hxx>
#include <TopExp_Explorer.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Compound.hxx>
#include <TopoDS_Face.hxx>
#include <TopoDS_Shape.hxx>
#include <gp_Pnt.hxx>

#include <iostream>
#include <string>
#include <vector>

static int gHoles       = 0;
static int gUnstable    = 0;
static int gDowncastBad = 0;

// The exact enumeration all three Swift call sites read: occtMapSubShapes.
static int mapSubShapes(const TopoDS_Shape& shape, TopAbs_ShapeEnum type,
                        TopTools_IndexedMapOfShape& outMap)
{
  TopExp::MapShapes(shape, type, outMap);
  return outMap.Extent();
}

static void probeType(const std::string& name, const TopoDS_Shape& shape, TopAbs_ShapeEnum type,
                      const char* typeName)
{
  TopTools_IndexedMapOfShape map;
  int                        extent = 0;
  try
  {
    extent = mapSubShapes(shape, type, map);
  }
  catch (const Standard_Failure& f)
  {
    std::cout << "  " << name << " / " << typeName << ": MAP THREW (" << f.GetMessageString()
              << ")" << std::endl;
    return;
  }

  // Q1: any null entry in the middle of the range?
  int holes = 0;
  for (int i = 1; i <= extent; i++)
  {
    if (map(i).IsNull())
      holes++;
  }

  // Q2: is Extent() stable? Shape.edges() takes count from one bridge call and each element from
  // another, so a count that outruns a later map is exactly how an in-range index goes null.
  TopTools_IndexedMapOfShape map2;
  int                        extent2 = mapSubShapes(shape, type, map2);
  TopTools_IndexedMapOfShape map3;
  int                        extent3 = mapSubShapes(shape, type, map3);
  bool                       stable  = (extent == extent2 && extent == extent3);

  // ...and does the same index name the same sub-shape in a second, independently built map?
  int reordered = 0;
  for (int i = 1; i <= extent && i <= extent2; i++)
  {
    if (!map(i).IsSame(map2(i)))
      reordered++;
  }

  // Q3: does every entry survive the per-element downcast the bridge performs?
  int badType = 0;
  for (int i = 1; i <= extent; i++)
  {
    if (map(i).ShapeType() != type)
      badType++;
  }

  gHoles += holes;
  gUnstable += (stable ? 0 : 1) + reordered;
  gDowncastBad += badType;

  std::cout << "  " << name << " / " << typeName << ": extent=" << extent << " nullEntries=" << holes
            << " extentStable=" << (stable ? "yes" : "NO") << " reorderedEntries=" << reordered
            << " wrongType=" << badType << std::endl;
}

static void probe(const std::string& name, const TopoDS_Shape& shape)
{
  probeType(name, shape, TopAbs_FACE, "FACE");
  probeType(name, shape, TopAbs_EDGE, "EDGE");
  probeType(name, shape, TopAbs_VERTEX, "VERTEX");
}

int main()
{
  std::cout << "#979: can one element of a sub-shape enumeration be null?" << std::endl
            << std::endl;

  // 1. A null TopoDS_Shape. OCCTShape can wrap one, and every bridge entry point guards the
  //    POINTER, not the shape.
  probe("nullShape", TopoDS_Shape());

  // 2. An empty compound: a valid shape with no sub-shapes at all.
  {
    TopoDS_Compound c;
    BRep_Builder    b;
    b.MakeCompound(c);
    probe("emptyCompound", c);
  }

  // 3. Baseline.
  TopoDS_Shape box = BRepPrimAPI_MakeBox(10.0, 10.0, 10.0).Shape();
  probe("box", box);

  // 4. One body compounded with ITSELF: every sub-shape reachable twice, deduplicated to one
  //    entry. #502's own divergence case.
  {
    TopoDS_Compound c;
    BRep_Builder    b;
    b.MakeCompound(c);
    b.Add(c, box);
    b.Add(c, box);
    probe("boxWithItself", c);
  }

  // 5. Two solids sharing a cut face: #541's fixture, 12 face occurrences over 11 distinct faces,
  //    and the duplicate is not last.
  {
    TopoDS_Shape big   = BRepPrimAPI_MakeBox(gp_Pnt(-5, -5, -5), 10.0, 10.0, 10.0).Shape();
    TopoDS_Shape small = BRepPrimAPI_MakeBox(gp_Pnt(0, 0, 0), 10.0, 10.0, 10.0).Shape();
    TopoDS_Shape common;
    try
    {
      common = BRepAlgoAPI_Common(big, small).Shape();
    }
    catch (const Standard_Failure&)
    {
    }
    if (!common.IsNull())
      probe("booleanCommon", common);

    TopoDS_Compound c;
    BRep_Builder    b;
    b.MakeCompound(c);
    b.Add(c, big);
    b.Add(c, small);
    probe("twoOverlappingBoxes", c);
  }

  // 6. A solid built from ONE face: structurally unclosed, i.e. an invalid solid a caller can
  //    reach without trying.
  {
    TopExp_Explorer ex(box, TopAbs_FACE);
    if (ex.More())
    {
      TopoDS_Shell shell;
      BRep_Builder b;
      b.MakeShell(shell);
      b.Add(shell, TopoDS::Face(ex.Current()));
      try
      {
        probe("openShellSolid", BRepBuilderAPI_MakeSolid(shell).Shape());
      }
      catch (const Standard_Failure& f)
      {
        std::cout << "  openShellSolid: build threw (" << f.GetMessageString() << ")" << std::endl;
      }
    }
  }

  // 7. Degenerate edges: a sphere's poles and seam, a cone's apex.
  probe("sphere", BRepPrimAPI_MakeSphere(5.0).Shape());
  probe("coneToApex", BRepPrimAPI_MakeCone(5.0, 0.0, 10.0).Shape());

  // 8. A shell holding a face and its own REVERSED twin: the two occurrences the IsSame map
  //    collapses (#614).
  {
    TopExp_Explorer ex(box, TopAbs_FACE);
    if (ex.More())
    {
      TopoDS_Face  f = TopoDS::Face(ex.Current());
      TopoDS_Shell shell;
      BRep_Builder b;
      b.MakeShell(shell);
      b.Add(shell, f);
      b.Add(shell, TopoDS::Face(f.Reversed()));
      probe("faceAndItsReverse", shell);
    }
  }

  // 9. An INTERNAL-orientation face inside a compound.
  {
    TopExp_Explorer ex(box, TopAbs_FACE);
    if (ex.More())
    {
      TopoDS_Shape internal = ex.Current();
      internal.Orientation(TopAbs_INTERNAL);
      TopoDS_Compound c;
      BRep_Builder    b;
      b.MakeCompound(c);
      b.Add(c, internal);
      probe("internalOrientationFace", c);
    }
  }

  // 10. A vertex-only compound: a shape with no faces or edges at all.
  {
    TopoDS_Compound c;
    BRep_Builder    b;
    b.MakeCompound(c);
    b.Add(c, BRepBuilderAPI_MakeVertex(gp_Pnt(0, 0, 0)).Shape());
    probe("vertexOnly", c);
  }

  // 11. A large compound: 2000 boxes, 12000 faces, so the per-element allocation loop runs at a
  //     scale where an allocation failure would show up if it were going to.
  {
    TopoDS_Compound c;
    BRep_Builder    b;
    b.MakeCompound(c);
    for (int i = 0; i < 2000; i++)
      b.Add(c, BRepPrimAPI_MakeBox(gp_Pnt(i * 20.0, 0, 0), 10.0, 10.0, 10.0).Shape());
    probe("compound2000Boxes", c);
  }

  std::cout << std::endl
            << "TOTALS: nullEntries=" << gHoles << " unstableEnumerations=" << gUnstable
            << " wrongTypeEntries=" << gDowncastBad << std::endl;

  return (gHoles == 0 && gUnstable == 0 && gDowncastBad == 0) ? 0 : 1;
}
