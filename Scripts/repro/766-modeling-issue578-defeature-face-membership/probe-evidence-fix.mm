// Epic #766 evidence fix, Tests/OCCTModelingTests/Issue578DefeatureFaceMembershipTests.swift.
// probe.mm printed each kernel answer at %.9f and did not run every request the tests refuse. This probe
// hands the kernel, at %.17g, the faces each request explodes to, the way the bridge would if its #578
// membership check (occtDefeaturingFacesFromShapes) and its #497 index check (occtDefeaturingFacesByIndex)
// were absent: BRepAlgoAPI_Defeaturing with SetShape, AddFacesToRemove and Build, and a result only when
// IsDone() and the shape is not null (occtDefeaturePerform). "produced" is that result.
#include <BRepAlgoAPI_Defeaturing.hxx>
#include <BRepFilletAPI_MakeFillet.hxx>
#include <BRepGProp.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRep_Builder.hxx>
#include <GProp_GProps.hxx>
#include <TopExp.hxx>
#include <TopExp_Explorer.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopTools_ListOfShape.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Compound.hxx>
#include <cmath>
#include <cstdio>

static double vol(const TopoDS_Shape& s)
{
  GProp_GProps p;
  BRepGProp::VolumeProperties(s, p);
  return p.Mass();
}

static int nfaces(const TopoDS_Shape& s)
{
  TopTools_IndexedMapOfShape m;
  TopExp::MapShapes(s, TopAbs_FACE, m);
  return m.Extent();
}

// Shape.box(width:height:depth:) is centred on the origin; one edge (the first) filleted with radius 2.
static TopoDS_Shape filleted()
{
  TopoDS_Shape               b = BRepPrimAPI_MakeBox(gp_Pnt(-10, -10, -10), 20, 20, 20).Shape();
  TopTools_IndexedMapOfShape e;
  TopExp::MapShapes(b, TopAbs_EDGE, e);
  BRepFilletAPI_MakeFillet f(b);
  f.Add(2, TopoDS::Edge(e(1)));
  f.Build();
  return f.Shape();
}

static void kernel(const char* label, const TopoDS_Shape& s, const TopTools_ListOfShape& faces)
{
  BRepAlgoAPI_Defeaturing d;
  d.SetShape(s);
  d.AddFacesToRemove(faces);
  d.Build();
  bool produced = d.IsDone() && !d.Shape().IsNull();
  printf("%s: produced=%d", label, produced);
  if (produced)
    printf(" faces=%d volume=%.17g", nfaces(d.Shape()), vol(d.Shape()));
  printf("\n");
}

static TopTools_ListOfShape facesOf(std::initializer_list<TopoDS_Shape> carriers)
{
  TopTools_ListOfShape l;
  for (const TopoDS_Shape& c : carriers)
    for (TopExp_Explorer e(c, TopAbs_FACE); e.More(); e.Next())
      l.Append(e.Current());
  return l;
}

int main()
{
  TopoDS_Shape               a = filleted();
  TopTools_IndexedMapOfShape af;
  TopExp::MapShapes(a, TopAbs_FACE, af);
  int filletIdx = -1;
  for (int i = 1; i <= af.Extent(); i++)
  {
    TopTools_ListOfShape l;
    l.Append(af(i));
    BRepAlgoAPI_Defeaturing d;
    d.SetShape(a);
    d.AddFacesToRemove(l);
    d.Build();
    if (d.IsDone() && std::abs(vol(d.Shape()) - 8000) < 1e-6)
    {
      filletIdx = i - 1;
      break;
    }
  }
  printf("fixture: faces=%d filletIndex=%d volume=%.17g\n", af.Extent(), filletIdx, vol(a));
  TopoDS_Shape fillet  = af(filletIdx + 1);
  TopoDS_Shape other   = BRepPrimAPI_MakeBox(gp_Pnt(-5.5, -5.5, -5.5), 11, 11, 11).Shape();
  TopoDS_Shape foreign = TopExp_Explorer(other, TopAbs_FACE).Current();

  // foreignFaceInMixedRequestFails
  kernel("t1 [fillet]", a, facesOf({fillet}));
  kernel("t1 [fillet, foreign]", a, facesOf({fillet, foreign}));
  kernel("t1 [foreign, fillet]", a, facesOf({foreign, fillet}));
  kernel("t1 [foreign]", a, facesOf({foreign}));

  // mixedCarrierFails
  BRep_Builder    bb;
  TopoDS_Compound mixed, clean;
  bb.MakeCompound(mixed);
  bb.Add(mixed, fillet);
  bb.Add(mixed, foreign);
  bb.MakeCompound(clean);
  bb.Add(clean, fillet);
  kernel("t2 compound(fillet, foreign)", a, facesOf({mixed}));
  kernel("t2 compound(fillet)", a, facesOf({clean}));

  // membershipIsIdentityNotGeometry
  TopoDS_Shape               b = filleted();
  TopTools_IndexedMapOfShape bf;
  TopExp::MapShapes(b, TopAbs_FACE, bf);
  printf("t3 twin: faces=%d twinFilletIsSameAsA=%d\n", bf.Extent(), bf(filletIdx + 1).IsSame(fillet));
  kernel("t3 [twin fillet]", a, facesOf({bf(filletIdx + 1)}));
  kernel("t3 [fillet, twin fillet]", a, facesOf({fillet, bf(filletIdx + 1)}));
  kernel("t3 [fillet]", a, facesOf({fillet}));

  // elementWithNoFaceFails: an edge and a vertex of the shape carry no face
  TopoDS_Shape edge = TopExp_Explorer(a, TopAbs_EDGE).Current();
  TopoDS_Shape vert = TopExp_Explorer(a, TopAbs_VERTEX).Current();
  TopTools_ListOfShape edgeOnly, filletEdge, filletVertex;
  edgeOnly.Append(edge);
  filletEdge.Append(fillet);
  filletEdge.Append(edge);
  filletVertex.Append(fillet);
  filletVertex.Append(vert);
  kernel("t4 [edge]", a, edgeOnly);
  kernel("t4 [fillet, edge]", a, filletEdge);
  kernel("t4 [fillet, vertex]", a, filletVertex);

  // reversedFaceStillBelongs
  kernel("t5 [fillet reversed]", a, facesOf({fillet.Reversed()}));
  kernel("t5 [fillet]", a, facesOf({fillet}));
  printf("t5 reversed IsSame=%d IsEqual=%d\n", fillet.Reversed().IsSame(fillet), fillet.Reversed().IsEqual(fillet));

  // wholeShapeCarriersAreAccepted
  printf("t6 input: faces=%d volume=%.17g\n", af.Extent(), vol(a));
  kernel("t6 [solid]", a, facesOf({a}));
  kernel("t6 [shell]", a, facesOf({TopExp_Explorer(a, TopAbs_SHELL).Current()}));

  // bothSpellingsRefuseAFaceThatDoesNotBelong: the ghost index names nothing on the plain 20 mm box, so
  // the request reduces to its first face alone.
  TopoDS_Shape               plain = BRepPrimAPI_MakeBox(gp_Pnt(-10, -10, -10), 20, 20, 20).Shape();
  TopTools_IndexedMapOfShape pf;
  TopExp::MapShapes(plain, TopAbs_FACE, pf);
  kernel("t7 byIndexGhost: plain box, [face 0]", plain, facesOf({pf(1)}));
  kernel("t7 byShapeForeign [fillet, foreign]", a, facesOf({fillet, foreign}));
  kernel("t7 byShape [fillet]", a, facesOf({fillet}));
  kernel("t7 byIndex [face filletIndex]", a, facesOf({af(filletIdx + 1)}));
  return 0;
}
