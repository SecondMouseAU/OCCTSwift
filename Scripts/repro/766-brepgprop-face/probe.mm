// Epic #766, BRepGPropFaceTests.swift: kernel parity for all four tests.
// Same inputs as the Swift tests, straight to OCCT. Shape.box is centred (BRepPrimAPI_MakeBox
// from (-w/2, -h/2, -d/2)), Shape.cylinder is BRepPrimAPI_MakeCylinder(r, h), and faces() is
// TopExp::MapShapes(TopAbs_FACE) order. Face.naturalBounds is BRepGProp_Face::Bounds
// (OCCTFaceGetNaturalBounds) and Face.evaluateGProp is BRepGProp_Face::Normal
// (OCCTFaceEvaluateNormalAtUV).
#include <BRepGProp_Face.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <TopExp.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopoDS.hxx>
#include <cstdio>

static TopTools_IndexedMapOfShape facesOf(const TopoDS_Shape& s)
{
  TopTools_IndexedMapOfShape m;
  TopExp::MapShapes(s, TopAbs_FACE, m);
  return m;
}

static void evalAt(const char* tag, const TopoDS_Face& f, double u, double v)
{
  BRepGProp_Face g(f);
  gp_Pnt         p;
  gp_Vec         n;
  g.Normal(u, v, p, n);
  printf("%s: uv=(%.17g, %.17g) point=(%.17g, %.17g, %.17g) normal=(%.17g, %.17g, %.17g) "
         "|normal|=%.17g\n",
         tag, u, v, p.X(), p.Y(), p.Z(), n.X(), n.Y(), n.Z(), n.Magnitude());
}

int main()
{
  {
    TopoDS_Shape box = BRepPrimAPI_MakeBox(gp_Pnt(-5, -10, -15), 10, 20, 30).Shape();
    auto         fm  = facesOf(box);
    TopoDS_Face  f   = TopoDS::Face(fm(1));
    double       u0, u1, v0, v1;
    BRepGProp_Face(f).Bounds(u0, u1, v0, v1);
    printf("naturalBounds: nFaces=%d face[0] u=[%.17g, %.17g] v=[%.17g, %.17g]\n", fm.Extent(), u0,
           u1, v0, v1);
    evalAt("evaluateBoxFace", f, (u0 + u1) / 2, (v0 + v1) / 2);
  }
  {
    TopoDS_Shape cyl = BRepPrimAPI_MakeCylinder(5, 10).Shape();
    auto         fm  = facesOf(cyl);
    printf("evaluateCylinderFace: nFaces=%d\n", fm.Extent());
    for (int i = 1; i <= fm.Extent(); i++)
    {
      TopoDS_Face f = TopoDS::Face(fm(i));
      double      u0, u1, v0, v1;
      BRepGProp_Face(f).Bounds(u0, u1, v0, v1);
      char tag[64];
      snprintf(tag, sizeof tag, "  cyl face[%d] u=[%g,%g] v=[%g,%g]", i - 1, u0, u1, v0, v1);
      evalAt(tag, f, (u0 + u1) / 2, (v0 + v1) / 2);
    }
  }
  {
    TopoDS_Shape box = BRepPrimAPI_MakeBox(gp_Pnt(-5, -5, -5), 10, 10, 10).Shape();
    TopoDS_Face  f   = TopoDS::Face(facesOf(box)(1));
    double       u0, u1, v0, v1;
    BRepGProp_Face(f).Bounds(u0, u1, v0, v1);
    printf("normalMagnitudeIsAreaElement: face[0] u=[%.17g, %.17g] v=[%.17g, %.17g]\n", u0, u1, v0,
           v1);
    evalAt("  eval1", f, u0 + 0.1, v0 + 0.1);
    evalAt("  eval2", f, u1 - 0.1, v1 - 0.1);
  }
  return 0;
}
