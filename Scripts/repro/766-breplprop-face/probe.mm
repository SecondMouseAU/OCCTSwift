// Kernel parity probe for Tests/OCCTAnalysisTests/BRepLPropFaceTests.swift (#766).
//
// Same inputs as the tests: BRepPrimAPI_MakeSphere(5), its first face, and BRepLProp_SLProps
// over a BRepAdaptor_Surface at (u, v) = (0.5, 0.5), order 2, resolution
// Precision::Confusion(), which is what occtFaceLocalProps passes for every OCCTFaceLProp*
// bridge function.
#include <BRepPrimAPI_MakeSphere.hxx>
#include <BRepAdaptor_Surface.hxx>
#include <BRepLProp_SLProps.hxx>
#include <TopExp.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopoDS.hxx>
#include <Precision.hxx>
#include <cstdio>

int main()
{
  TopoDS_Shape              sphere = BRepPrimAPI_MakeSphere(5).Shape();
  TopTools_IndexedMapOfShape faces;
  TopExp::MapShapes(sphere, TopAbs_FACE, faces);
  printf("face count=%d\n", faces.Extent());
  TopoDS_Face face = TopoDS::Face(faces(1));
  printf("face orientation=%d (0=FORWARD, 1=REVERSED)\n", (int)face.Orientation());

  BRepAdaptor_Surface as(face);
  BRepLProp_SLProps   props(as, 0.5, 0.5, 2, Precision::Confusion());

  gp_Pnt p = props.Value();
  printf("faceValue: (%.17g, %.17g, %.17g) |p|=%.17g\n", p.X(), p.Y(), p.Z(),
         p.Distance(gp_Pnt(0, 0, 0)));

  printf("IsNormalDefined=%d\n", props.IsNormalDefined());
  gp_Dir n = props.Normal();
  printf("faceNormal: (%.17g, %.17g, %.17g)\n", n.X(), n.Y(), n.Z());

  printf("IsCurvatureDefined=%d\n", props.IsCurvatureDefined());
  printf("faceCurvature: max=%.17g min=%.17g\n", props.MaxCurvature(), props.MinCurvature());
  printf("faceMeanAndGaussianCurvature: mean=%.17g gauss=%.17g\n", props.MeanCurvature(),
         props.GaussianCurvature());
  printf("faceIsUmbilic: IsUmbilic=%d\n", props.IsUmbilic());

  printf("IsTangentUDefined=%d\n", props.IsTangentUDefined());
  gp_Dir tu;
  props.TangentU(tu);
  printf("faceTangentU: (%.17g, %.17g, %.17g)\n", tu.X(), tu.Y(), tu.Z());
  return 0;
}
