// #766 kernel parity: Issue446UnifyInputMutationTests, Issue484ConnectedFacesTests,
// Issue484FaceFixContextTests. ShapeUpgrade_UnifySameDomain on a BRepBuilderAPI_Copy
// (occtUnifySameDomain), ShapeFix_FaceConnect per shell (OCCTShapeFixFaceConnect), and
// ShapeFix_Face with a ReShape context (OCCTFaceFix) on the box and cylinder faces.
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <BRepAlgoAPI_Fuse.hxx>
#include <BRepBuilderAPI_Copy.hxx>
#include <BRepBuilderAPI_MakePolygon.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepCheck_Analyzer.hxx>
#include <BRepGProp.hxx>
#include <GProp_GProps.hxx>
#include <BRep_Builder.hxx>
#include <ShapeUpgrade_UnifySameDomain.hxx>
#include <ShapeFix_FaceConnect.hxx>
#include <ShapeFix_Face.hxx>
#include <ShapeBuild_ReShape.hxx>
#include <TopExp.hxx>
#include <TopExp_Explorer.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopoDS.hxx>
#include <cstdio>
#include <vector>

static int unique(const TopoDS_Shape& s, TopAbs_ShapeEnum t)
{
  TopTools_IndexedMapOfShape m;
  TopExp::MapShapes(s, t, m);
  return m.Extent();
}

static double vol(const TopoDS_Shape& s)
{
  GProp_GProps g;
  BRepGProp::VolumeProperties(s, g);
  return g.Mass();
}

static TopoDS_Shape connect(const TopoDS_Shape& s)
{
  std::vector<TopoDS_Shape> out;
  for (TopExp_Explorer se(s, TopAbs_SHELL); se.More(); se.Next())
  {
    Handle(ShapeFix_FaceConnect) c = new ShapeFix_FaceConnect();
    std::vector<TopoDS_Face> faces;
    for (TopExp_Explorer fe(se.Current(), TopAbs_FACE); fe.More(); fe.Next())
      faces.push_back(TopoDS::Face(fe.Current()));
    for (size_t i = 0; i + 1 < faces.size(); i++)
      c->Add(faces[i], faces[i + 1]);
    out.push_back(c->Build(TopoDS::Shell(se.Current()), 1e-4, 1e-4));
  }
  if (out.size() == 1)
    return out[0];
  BRep_Builder    b;
  TopoDS_Compound comp;
  b.MakeCompound(comp);
  for (auto& s2 : out)
    b.Add(comp, s2);
  return comp;
}

int main()
{
  // #446
  TopoDS_Shape lower = BRepPrimAPI_MakeCylinder(5, 10).Shape();
  TopoDS_Shape upper = BRepPrimAPI_MakeCylinder(gp_Ax2(gp_Pnt(0, 0, 10), gp_Dir(0, 0, 1)), 5, 10).Shape();
  TopoDS_Shape body  = BRepAlgoAPI_Fuse(lower, upper).Shape();
  printf("stacked cylinders: faces=%d volume=%.9f\n", unique(body, TopAbs_FACE), vol(body));
  BRepBuilderAPI_Copy          copier(body);
  Handle(ShapeUpgrade_UnifySameDomain) u = new ShapeUpgrade_UnifySameDomain(copier.Shape(), true, true, true);
  u->Build();
  printf("unify on a copy: result faces=%d volume=%.9f; input faces after=%d volume=%.9f\n",
         unique(u->Shape(), TopAbs_FACE), vol(u->Shape()), unique(body, TopAbs_FACE), vol(body));
  TopoDS_Shape                 box = BRepPrimAPI_MakeBox(gp_Pnt(-5, -5, -5), 10, 10, 10).Shape();
  BRepBuilderAPI_Copy          bc(box);
  Handle(ShapeUpgrade_UnifySameDomain) ub = new ShapeUpgrade_UnifySameDomain(bc.Shape(), true, true, true);
  ub->Build();
  TopTools_IndexedMapOfShape in, outm;
  TopExp::MapShapes(box, TopAbs_FACE, in);
  TopExp::MapShapes(ub->Shape(), TopAbs_FACE, outm);
  int shared = 0;
  for (int i = 1; i <= in.Extent(); i++)
    if (outm.Contains(in(i)))
      shared++;
  printf("unify box on a copy: faces=%d sharedWithInput=%d isSame=%d\n", outm.Extent(), shared,
         (int)ub.Shape().IsSame(box));

  // #484 connectedFaces
  printf("box connect: faces=%d\n", unique(connect(box), TopAbs_FACE));
  TopoDS_Shape cyl = BRepPrimAPI_MakeCylinder(4, 9).Shape();
  printf("cylinder r4 h9 connect: faces=%d\n", unique(connect(cyl), TopAbs_FACE));
  {
    BRepBuilderAPI_MakePolygon pa(gp_Pnt(0, 0, 0), gp_Pnt(10, 0, 0), gp_Pnt(10, 10, 0), gp_Pnt(0, 10, 0), true);
    BRepBuilderAPI_MakePolygon pb(gp_Pnt(10, 0, 0), gp_Pnt(20, 0, 0), gp_Pnt(20, 10, 0), gp_Pnt(10, 10, 0), true);
    BRep_Builder               b;
    TopoDS_Shell               sh;
    b.MakeShell(sh);
    b.Add(sh, BRepBuilderAPI_MakeFace(pa.Wire()).Face());
    b.Add(sh, BRepBuilderAPI_MakeFace(pb.Wire()).Face());
    TopoDS_Shape c = connect(sh);
    printf("two squares shell: edges before=%d after=%d faces after=%d\n", unique(sh, TopAbs_EDGE),
           unique(c, TopAbs_EDGE), unique(c, TopAbs_FACE));
  }
  // #484 Face.fixed on box (10x20x30) and cylinder (r5 h12) faces
  for (int k = 0; k < 2; k++)
  {
    TopoDS_Shape s = k == 0 ? BRepPrimAPI_MakeBox(gp_Pnt(-5, -10, -15), 10, 20, 30).Shape()
                            : BRepPrimAPI_MakeCylinder(5, 12).Shape();
    int valid = 0, n = 0;
    for (TopExp_Explorer fe(s, TopAbs_FACE); fe.More(); fe.Next(), n++)
    {
      Handle(ShapeFix_Face) f = new ShapeFix_Face(TopoDS::Face(fe.Current()));
      f->SetContext(new ShapeBuild_ReShape());
      f->SetPrecision(1e-6);
      f->FixWireMode() = f->FixOrientationMode() = f->FixAddNaturalBoundMode() = f->FixMissingSeamMode() =
        f->FixSmallAreaWireMode()                  = 1;
      f->Perform();
      TopoDS_Shape r = f->Face();
      if (BRepCheck_Analyzer(r).IsValid() && unique(r, TopAbs_FACE) == 1)
        valid++;
    }
    printf("%s: ShapeFix_Face per face -> %d of %d valid single faces\n", k == 0 ? "box 10x20x30" : "cylinder r5 h12",
           valid, n);
  }
  return 0;
}
