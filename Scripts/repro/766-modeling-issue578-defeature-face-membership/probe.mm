// Epic #766, Tests/OCCTModelingTests/Issue578DefeatureFaceMembershipTests.swift: kernel parity for
// all seven tests. OCCTShapeDefeature explodes each carrier for faces, checks membership by IsSame
// (occtDefeaturingFacesFromShapes), then runs BRepAlgoAPI_Defeaturing (SetShape, AddFacesToRemove,
// Build). The probe runs the kernel directly on the same fixture: what it answers for each accepted
// request, and what it does with the requests the bridge now refuses (the foreign face it silently
// ignores, which is the behaviour #578 replaced).
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

// Kernel answer for a list of faces handed straight to BRepAlgoAPI_Defeaturing.
static void kernel(const char* label, const TopoDS_Shape& s, const TopTools_ListOfShape& faces)
{
  BRepAlgoAPI_Defeaturing d;
  d.SetShape(s);
  d.AddFacesToRemove(faces);
  d.Build();
  printf("%s: done=%d", label, d.IsDone());
  if (d.IsDone())
    printf(" faces=%d volume=%.9f warnings=%d", nfaces(d.Shape()), vol(d.Shape()), d.HasWarnings());
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
  printf("fixture: faces=%d filletIndex=%d volume=%.9f\n", af.Extent(), filletIdx, vol(a));
  TopoDS_Shape fillet  = af(filletIdx + 1);
  TopoDS_Shape other   = BRepPrimAPI_MakeBox(gp_Pnt(-5.5, -5.5, -5.5), 11, 11, 11).Shape();
  TopoDS_Shape foreign = TopExp_Explorer(other, TopAbs_FACE).Current();

  kernel("fillet face alone", a, facesOf({fillet}));
  kernel("fillet + foreign (kernel ignores the foreign face; bridge now refuses)", a, facesOf({fillet, foreign}));
  kernel("foreign alone", a, facesOf({foreign}));

  BRep_Builder    bb;
  TopoDS_Compound mixed, clean;
  bb.MakeCompound(mixed);
  bb.Add(mixed, fillet);
  bb.Add(mixed, foreign);
  bb.MakeCompound(clean);
  bb.Add(clean, fillet);
  kernel("compound(fillet, foreign) exploded", a, facesOf({mixed}));
  kernel("compound(fillet) exploded", a, facesOf({clean}));

  TopoDS_Shape               b = filleted();
  TopTools_IndexedMapOfShape bf;
  TopExp::MapShapes(b, TopAbs_FACE, bf);
  printf("twin: faces=%d twinFilletIsSameAsA=%d\n", bf.Extent(), bf(filletIdx + 1).IsSame(fillet));
  kernel("twin's fillet alone", a, facesOf({bf(filletIdx + 1)}));
  kernel("own fillet + twin's fillet", a, facesOf({fillet, bf(filletIdx + 1)}));

  TopTools_ListOfShape edgeOnly;
  edgeOnly.Append(TopExp_Explorer(a, TopAbs_EDGE).Current());
  kernel("an edge as the only element (not a face)", a, edgeOnly);

  kernel("fillet face reversed", a, facesOf({fillet.Reversed()}));
  printf("reversed IsSame=%d IsEqual=%d\n", fillet.Reversed().IsSame(fillet), fillet.Reversed().IsEqual(fillet));

  kernel("whole solid (every face)", a, facesOf({a}));
  kernel("its shell (every face)", a, facesOf({TopExp_Explorer(a, TopAbs_SHELL).Current()}));

  // Index spelling: fillet face by its index gives the same removal.
  kernel("by index (withoutFeatures)", a, facesOf({af(filletIdx + 1)}));
  return 0;
}
