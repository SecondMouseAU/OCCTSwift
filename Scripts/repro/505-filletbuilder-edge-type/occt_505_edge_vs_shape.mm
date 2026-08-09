// OCCTSwift#505 ground truth, probe 1: is a TopoDS_Edge reached through a TopoDS_Shape copy the
// same argument, as far as BRepFilletAPI_MakeFillet's three edge-keyed accessors are concerned?
//
// The bridge hands GetBounds/GetLaw an OCCTShapeRef (generic TopoDS_Shape, downcast with
// TopoDS::Edge at the call site) and SetLaw an OCCTEdgeRef (a TopoDS_Edge already). All three OCCT
// functions take const TopoDS_Edge&. This probe measures whether the two routes are observably
// equivalent, and what the downcast route does when the shape is not an edge.
//
// Compile:
//   clang++ -std=c++17 -ObjC++ -w \
//     -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
//     -L"Libraries/OCCT.xcframework/macos-arm64" \
//     -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
//     Scripts/repro/505-filletbuilder-edge-type/occt_505_edge_vs_shape.mm -o /tmp/occt_505_edge_vs_shape

#include <BRepFilletAPI_MakeFillet.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <Law_Function.hxx>
#include <Standard_Failure.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Edge.hxx>
#include <TopoDS_Face.hxx>
#include <TopoDS_Shape.hxx>

#include <cstdio>
#include <typeinfo>

static TopoDS_Shape makeBox()
{
  return BRepPrimAPI_MakeBox(10.0, 10.0, 10.0).Shape();
}

static TopoDS_Edge firstEdge(const TopoDS_Shape& theShape)
{
  TopExp_Explorer anExp(theShape, TopAbs_EDGE);
  return TopoDS::Edge(anExp.Current());
}

static TopoDS_Face firstFace(const TopoDS_Shape& theShape)
{
  TopExp_Explorer anExp(theShape, TopAbs_FACE);
  return TopoDS::Face(anExp.Current());
}

int main()
{
  // ---- case 1: the two argument routes, on a built evolving-radius contour -----------------
  {
    const TopoDS_Shape aBox  = makeBox();
    const TopoDS_Edge  anEdge = firstEdge(aBox);

    BRepFilletAPI_MakeFillet aFillet(aBox);
    aFillet.Add(0.5, 2.0, anEdge);
    aFillet.Build();
    printf("case 1: IsDone=%d NbContours=%d\n", (int)aFillet.IsDone(), aFillet.NbContours());

    // route A: the TopoDS_Edge itself, which is what OCCTEdgeRef holds (SetLaw's route)
    double aFirstA = -1.0, aLastA = -1.0;
    const bool anOkA = aFillet.GetBounds(1, anEdge, aFirstA, aLastA);
    occ::handle<Law_Function> aLawA = aFillet.GetLaw(1, anEdge);

    // route B: a TopoDS_Shape copy, downcast back with TopoDS::Edge, which is what OCCTShapeRef
    // holds plus what the GetBounds/GetLaw bridge implementations do to it
    const TopoDS_Shape aShapeCopy = anEdge;
    const TopoDS_Edge& anEdgeB    = TopoDS::Edge(aShapeCopy);
    double             aFirstB = -1.0, aLastB = -1.0;
    const bool         anOkB = aFillet.GetBounds(1, anEdgeB, aFirstB, aLastB);
    occ::handle<Law_Function> aLawB = aFillet.GetLaw(1, anEdgeB);

    printf("  route A (TopoDS_Edge)       : GetBounds=%d [%.9f, %.9f] GetLaw=%p\n",
           (int)anOkA,
           aFirstA,
           aLastA,
           (void*)aLawA.get());
    printf("  route B (Shape -> downcast) : GetBounds=%d [%.9f, %.9f] GetLaw=%p\n",
           (int)anOkB,
           aFirstB,
           aLastB,
           (void*)aLawB.get());
    printf("  identical: bounds=%d lawHandle=%d IsSame=%d IsEqual=%d\n",
           (int)(anOkA == anOkB && aFirstA == aFirstB && aLastA == aLastB),
           (int)(aLawA.get() == aLawB.get()),
           (int)anEdge.IsSame(anEdgeB),
           (int)anEdge.IsEqual(anEdgeB));

    if (!aLawA.IsNull())
    {
      double aLF = 0.0, aLL = 0.0;
      aLawA->Bounds(aLF, aLL);
      printf("  law A: bounds [%.9f, %.9f] value(first)=%.9f value(last)=%.9f\n",
             aLF,
             aLL,
             aLawA->Value(aLF),
             aLawA->Value(aLL));
    }
  }

  // ---- case 2: an edge that belongs to no contour ------------------------------------------
  {
    const TopoDS_Shape aBox = makeBox();
    TopExp_Explorer     anExp(aBox, TopAbs_EDGE);
    const TopoDS_Edge   anEdge0 = TopoDS::Edge(anExp.Current());
    anExp.Next();
    const TopoDS_Edge anEdge1 = TopoDS::Edge(anExp.Current());

    BRepFilletAPI_MakeFillet aFillet(aBox);
    aFillet.Add(0.5, 2.0, anEdge0);
    aFillet.Build();

    double aF = -1.0, aL = -1.0;
    bool   anOk = false;
    try
    {
      anOk = aFillet.GetBounds(1, anEdge1, aF, aL);
      printf("case 2: foreign edge GetBounds=%d [%.9f, %.9f]\n", (int)anOk, aF, aL);
    }
    catch (const Standard_Failure& aFail)
    {
      printf("case 2: foreign edge GetBounds threw %s: %s\n",
             typeid(aFail).name(),
             aFail.GetMessageString() ? aFail.GetMessageString() : "");
    }
    try
    {
      occ::handle<Law_Function> aLaw = aFillet.GetLaw(1, anEdge1);
      printf("case 2: foreign edge GetLaw=%p\n", (void*)aLaw.get());
    }
    catch (const Standard_Failure& aFail)
    {
      printf("case 2: foreign edge GetLaw threw %s: %s\n",
             typeid(aFail).name(),
             aFail.GetMessageString() ? aFail.GetMessageString() : "");
    }
  }

  // ---- case 3: what the downcast does with a non-edge shape --------------------------------
  // This translation unit does not define No_Exception, which is how Sources/OCCTBridge is
  // compiled too (Package.swift defines only OCCT_AVAILABLE and OCCT_NO_DEPRECATED), so the
  // Standard_TypeMismatch_Raise_if inside the inline TopoDS::Edge is live here.
  {
    const TopoDS_Shape aBox  = makeBox();
    const TopoDS_Face  aFace = firstFace(aBox);
    try
    {
      const TopoDS_Edge& aBogus = TopoDS::Edge(aFace);
      printf("case 3: TopoDS::Edge(face) did NOT throw, ShapeType=%d\n", (int)aBogus.ShapeType());
    }
    catch (const Standard_Failure& aFail)
    {
      printf("case 3: TopoDS::Edge(face) threw %s: %s\n",
             typeid(aFail).name(),
             aFail.GetMessageString() ? aFail.GetMessageString() : "");
    }

    // A null shape is not rejected by that check at all (it tests ShapeType only when non-null).
    const TopoDS_Shape aNull;
    try
    {
      const TopoDS_Edge& aNullEdge = TopoDS::Edge(aNull);
      printf("case 3: TopoDS::Edge(null shape) did NOT throw, IsNull=%d\n", (int)aNullEdge.IsNull());
    }
    catch (const Standard_Failure& aFail)
    {
      printf("case 3: TopoDS::Edge(null shape) threw %s\n", typeid(aFail).name());
    }
  }

  printf("done\n");
  return 0;
}
