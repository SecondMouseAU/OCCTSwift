// Kernel parity probe for Tests/OCCTAnalysisTests/FaceSurfacePropertiesTests.swift (#766).
//
// Replays each test's inputs against the pinned kernel through the same OCCT calls the bridge
// makes: BRepPrimAPI_MakeBox from the centred corner (OCCTShapeCreateBox), TopExp::MapShapes for
// faces() ordering (OCCTShapeGetFaces), BRepTools::UVBounds (OCCTFaceGetUVBounds),
// Geom_Surface::D0 (OCCTFaceEvaluateAtUV), GeomLProp_SLProps with Precision::Confusion()
// (OCCTFaceGetNormalAtUV / GaussianCurvature / MeanCurvature / PrincipalCurvatures),
// BRepAdaptor_Surface::GetType (OCCTFaceGetSurfaceType) and BRepGProp::SurfaceProperties
// (OCCTFaceGetArea).
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <BRepPrimAPI_MakeSphere.hxx>
#include <BRepTools.hxx>
#include <BRep_Tool.hxx>
#include <BRepAdaptor_Surface.hxx>
#include <BRepGProp.hxx>
#include <GProp_GProps.hxx>
#include <GeomLProp_SLProps.hxx>
#include <Geom_Surface.hxx>
#include <Precision.hxx>
#include <TopExp.hxx>
#include <TopoDS.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <cstdio>

static void faceReport(const char* label, const TopoDS_Face& f)
{
  double u0, u1, v0, v1;
  BRepTools::UVBounds(f, u0, u1, v0, v1);
  double um = (u0 + u1) / 2, vm = (v0 + v1) / 2;
  Handle(Geom_Surface) s = BRep_Tool::Surface(f);
  gp_Pnt p;
  s->D0(um, vm, p);
  // Mirror the bridge: IsCurvatureDefined() is called before any curvature accessor. That order
  // matters in the pinned kernel, see staleFirstRead() below.
  GeomLProp_SLProps props(s, um, vm, 2, Precision::Confusion());
  gp_Dir            n = props.Normal();
  if (f.Orientation() == TopAbs_REVERSED)
    n.Reverse();
  const bool   defined = props.IsCurvatureDefined();
  const double gauss   = props.GaussianCurvature();
  const double mean    = props.MeanCurvature();
  const double kMin    = props.MinCurvature();
  const double kMax    = props.MaxCurvature();
  gp_Dir       maxD, minD;
  props.CurvatureDirections(maxD, minD);
  printf("%s uv=[%.17g, %.17g] x [%.17g, %.17g] mid=(%.17g, %.17g)\n", label, u0, u1, v0, v1, um, vm);
  printf("%s point=(%.17g, %.17g, %.17g)\n", label, p.X(), p.Y(), p.Z());
  printf("%s normal=(%.17g, %.17g, %.17g) orient=%d\n", label, n.X(), n.Y(), n.Z(), (int)f.Orientation());
  printf("%s curvatureDefined=%d gaussian=%.17g mean=%.17g kMin=%.17g kMax=%.17g\n",
         label,
         (int)defined,
         gauss,
         mean,
         kMin,
         kMax);
  printf("%s dirMin=(%.17g, %.17g, %.17g) dirMax=(%.17g, %.17g, %.17g)\n",
         label,
         minD.X(),
         minD.Y(),
         minD.Z(),
         maxD.X(),
         maxD.Y(),
         maxD.Z());
  printf("%s type=%d\n", label, (int)BRepAdaptor_Surface(f).GetType());
}

// Found while writing this probe, not by the Swift tests: in the pinned 8.0.1 kernel
// GeomLProp_SLProps::GaussianCurvature() is `RequireCurvature(*this, myGausCurv)`, and
// RequireCurvature takes the value BY VALUE, so the member is read before RequireCurvature calls
// IsCurvatureDefined() to compute it. On a freshly constructed props object the first
// GaussianCurvature() (likewise Min/MaxCurvature, MeanCurvature, IsUmbilic) returns the
// uncomputed member. The bridge is not exposed: every OCCTFaceGet*Curvature calls
// IsCurvatureDefined() first. This prints the first and second reads on the sphere face.
static void staleFirstRead(const TopoDS_Face& f)
{
  double u0, u1, v0, v1;
  BRepTools::UVBounds(f, u0, u1, v0, v1);
  Handle(Geom_Surface) s = BRep_Tool::Surface(f);
  GeomLProp_SLProps props(s, (u0 + u1) / 2, (v0 + v1) / 2, 2, Precision::Confusion());
  const double first  = props.GaussianCurvature();
  const double second = props.GaussianCurvature();
  printf("staleFirstRead sphere5 gaussian first=%.17g second=%.17g\n", first, second);
}

int main()
{
  {
    BRepPrimAPI_MakeBox        mk(gp_Pnt(-5, -5, -5), 10, 10, 10);
    TopTools_IndexedMapOfShape m;
    TopExp::MapShapes(mk.Shape(), TopAbs_FACE, m);
    printf("box10 faces=%d\n", m.Extent());
    faceReport("box10.face[0]", TopoDS::Face(m(1)));
  }
  {
    BRepPrimAPI_MakeSphere     mk(5.0);
    TopTools_IndexedMapOfShape m;
    TopExp::MapShapes(mk.Shape(), TopAbs_FACE, m);
    printf("sphere5 faces=%d\n", m.Extent());
    faceReport("sphere5.face[0]", TopoDS::Face(m(1)));
    staleFirstRead(TopoDS::Face(m(1)));
  }
  {
    BRepPrimAPI_MakeCylinder   mk(5.0, 10.0);
    TopTools_IndexedMapOfShape m;
    TopExp::MapShapes(mk.Shape(), TopAbs_FACE, m);
    printf("cyl5x10 faces=%d\n", m.Extent());
    for (int i = 1; i <= m.Extent(); i++)
    {
      char label[64];
      snprintf(label, sizeof label, "cyl5x10.face[%d]", i - 1);
      faceReport(label, TopoDS::Face(m(i)));
    }
  }
  {
    BRepPrimAPI_MakeBox        mk(gp_Pnt(-5, -10, -15), 10, 20, 30);
    TopTools_IndexedMapOfShape m;
    TopExp::MapShapes(mk.Shape(), TopAbs_FACE, m);
    double total = 0;
    for (int i = 1; i <= m.Extent(); i++)
    {
      GProp_GProps g;
      BRepGProp::SurfaceProperties(m(i), g, 1e-6);
      printf("box10x20x30.face[%d] area=%.17g\n", i - 1, g.Mass());
      total += g.Mass();
    }
    printf("box10x20x30 faces=%d total_area=%.17g\n", m.Extent(), total);
  }
  return 0;
}
