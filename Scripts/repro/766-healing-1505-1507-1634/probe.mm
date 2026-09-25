// #766 kernel parity: Issue1505BareWireSelfIntersectionGuardTests, Issue1507SewingNullGuardTests,
// Issue1634ConvertToRevolutionDirectionTests.
// #1505: what BRepCheck_Analyzer says about the bowtie as a bare wire and as a planar face (the
// two inputs occtHasSelfIntersectingWire examines). #1507: BRepBuilderAPI_Sewing counters on a
// box's six faces (OCCTSewing*). #1634: Geom subclass of each face through ConvertToRevolution
// and back through SweptToElementary (OCCTShapeCustomConvertToRevolution / OCCTShapeSweptToElementary).
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <BRepBuilderAPI_MakePolygon.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepBuilderAPI_Sewing.hxx>
#include <BRepCheck_Analyzer.hxx>
#include <BRepCheck_Result.hxx>
#include <BRepCheck_ListOfStatus.hxx>
#include <BRepGProp.hxx>
#include <GProp_GProps.hxx>
#include <BRep_Tool.hxx>
#include <ShapeCustom.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <cstdio>
#include <cstring>

static bool selfIntersecting(const BRepCheck_Analyzer& a, const TopoDS_Shape& s)
{
  for (TopExp_Explorer we(s, TopAbs_WIRE); we.More(); we.Next())
  {
    Handle(BRepCheck_Result) r = a.Result(we.Current());
    if (r.IsNull())
      continue;
    for (BRepCheck_ListIteratorOfListOfStatus it(r->Status()); it.More(); it.Next())
      if (it.Value() == BRepCheck_SelfIntersectingWire)
        return true;
  }
  return false;
}

static void wireReport(const char* label, const TopoDS_Wire& w)
{
  BRepCheck_Analyzer bare(w);
  printf("%s as bare wire: valid=%d selfIntersectingFlag=%d\n", label, (int)bare.IsValid(),
         (int)selfIntersecting(bare, w));
  BRepBuilderAPI_MakeFace mf(w, Standard_True);
  if (!mf.IsDone())
  {
    printf("%s: planar face not built\n", label);
    return;
  }
  BRepCheck_Analyzer fa(mf.Face());
  printf("%s as planar face: valid=%d selfIntersectingFlag=%d\n", label, (int)fa.IsValid(),
         (int)selfIntersecting(fa, mf.Face()));
}

static int revolutionFaces(const TopoDS_Shape& s)
{
  int n = 0;
  for (TopExp_Explorer e(s, TopAbs_FACE); e.More(); e.Next())
    if (strcmp(BRep_Tool::Surface(TopoDS::Face(e.Current()))->DynamicType()->Name(), "Geom_SurfaceOfRevolution") == 0)
      n++;
  return n;
}

static double volume(const TopoDS_Shape& s)
{
  GProp_GProps p;
  BRepGProp::VolumeProperties(s, p);
  return p.Mass();
}

int main()
{
  BRepBuilderAPI_MakePolygon bow(gp_Pnt(0, 0, 0), gp_Pnt(1, 1, 0), gp_Pnt(1, 0, 0), gp_Pnt(0, 1, 0), Standard_True);
  BRepBuilderAPI_MakePolygon sq(gp_Pnt(0, 0, 0), gp_Pnt(1, 0, 0), gp_Pnt(1, 1, 0), gp_Pnt(0, 1, 0), Standard_True);
  wireReport("bowtie", bow.Wire());
  wireReport("clean square", sq.Wire());

  {
    TopoDS_Shape          box = BRepPrimAPI_MakeBox(gp_Pnt(-5, -5, -5), 10, 10, 10).Shape();
    BRepBuilderAPI_Sewing sw(1e-6);
    for (TopExp_Explorer e(box, TopAbs_FACE); e.More(); e.Next())
      sw.Add(e.Current());
    sw.Perform();
    TopoDS_Shape r  = sw.SewedShape();
    int          nf = 0;
    for (TopExp_Explorer e(r, TopAbs_FACE); e.More(); e.Next())
      nf++;
    printf("Sewing(box faces): NbFreeEdges=%d NbContigousEdges=%d NbMultipleEdges=%d NbDegeneratedShapes=%d "
           "sewedType=%d sewedFaces=%d\n",
           sw.NbFreeEdges(), sw.NbContigousEdges(), sw.NbMultipleEdges(), sw.NbDegeneratedShapes(),
           (int)r.ShapeType(), nf);
  }
  {
    TopoDS_Shape cyl  = BRepPrimAPI_MakeCylinder(5, 10).Shape();
    TopoDS_Shape rev  = ShapeCustom::ConvertToRevolution(cyl);
    TopoDS_Shape back = ShapeCustom::SweptToElementary(rev);
    printf("cylinder: revolutionFaces=%d volume=%.9f\n", revolutionFaces(cyl), volume(cyl));
    printf("ConvertToRevolution: revolutionFaces=%d volume=%.9f valid=%d\n", revolutionFaces(rev), volume(rev),
           (int)BRepCheck_Analyzer(rev).IsValid());
    printf("SweptToElementary(converted): revolutionFaces=%d volume=%.9f\n", revolutionFaces(back), volume(back));
  }
  return 0;
}
