// Epic #766, OCCTFoundationTests.swift "OCCT signal handling (#175)" (1 test) and "Color OCCT
// Operations Tests" (27 tests): kernel parity. Same inputs as the Swift tests, straight to OCCT:
// BRepBuilderAPI_MakePolygon + BRepOffsetAPI_ThruSections(CheckCompatibility) as
// OCCTWireCreateFastPolygon / OCCTShapeCreateLoft build them, BRepMesh_IncrementalMesh on the
// unit box, and Quantity_Color / Quantity_ColorRGBA for the OCCTColor* bridge functions in
// OCCTBridge_Visualization_Appearance.mm. "Color Tests" and "Material Tests" are pure Swift
// value types with no kernel call, so they have no parity line here.
#include <BRepBuilderAPI_MakePolygon.hxx>
#include <BRepMesh_IncrementalMesh.hxx>
#include <BRepOffsetAPI_ThruSections.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRep_Tool.hxx>
#include <Poly_Triangulation.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <Quantity_Color.hxx>
#include <Quantity_ColorRGBA.hxx>
#include <TCollection_AsciiString.hxx>
#include <cstdio>

static void rgb(const char* label, const Quantity_Color& c)
{
  printf("%s: r=%.17g g=%.17g b=%.17g\n", label, c.Red(), c.Green(), c.Blue());
}

static TopoDS_Wire poly(std::initializer_list<gp_Pnt> pts, bool& ok)
{
  BRepBuilderAPI_MakePolygon p;
  for (const gp_Pnt& q : pts)
    p.Add(q);
  p.Close();
  ok = p.IsDone();
  return ok ? p.Wire() : TopoDS_Wire();
}

int main()
{
  {
    bool        okSq = false, okCol = false;
    TopoDS_Wire sq   = poly({gp_Pnt(0, 0, 0), gp_Pnt(10, 0, 0), gp_Pnt(10, 10, 0), gp_Pnt(0, 10, 0)}, okSq);
    TopoDS_Wire col  = poly({gp_Pnt(0, 0, 5), gp_Pnt(1, 0, 5), gp_Pnt(2, 0, 5)}, okCol);
    printf("signal: square polygon IsDone=%d, collinear polygon IsDone=%d\n", okSq, okCol);
    if (okSq && okCol)
    {
      try
      {
        BRepOffsetAPI_ThruSections maker(Standard_True);
        maker.CheckCompatibility(Standard_True);
        maker.AddWire(sq);
        maker.AddWire(col);
        maker.Build();
        printf("signal: ThruSections(solid) IsDone=%d\n", (int)maker.IsDone());
      }
      catch (Standard_Failure& e)
      {
        printf("signal: ThruSections threw: %s\n", e.what());
      }
    }
    TopoDS_Shape box = BRepPrimAPI_MakeBox(1, 1, 1).Shape();
    BRepMesh_IncrementalMesh(box, 0.01, Standard_False, 0.5);
    int tris = 0;
    for (TopExp_Explorer ex(box, TopAbs_FACE); ex.More(); ex.Next())
    {
      TopLoc_Location loc;
      Handle(Poly_Triangulation) t = BRep_Tool::Triangulation(TopoDS::Face(ex.Current()), loc);
      if (!t.IsNull())
        tris += t->NbTriangles();
    }
    printf("signal: unit box meshed at 0.01/0.5: triangles=%d\n", tris);
  }

  Quantity_Color c;
  bool           ok = Quantity_Color::ColorFromName("RED", c);
  printf("fromName(RED): ok=%d ", ok);
  rgb("", c);
  ok = Quantity_Color::ColorFromName("BLUE", c);
  printf("fromName(BLUE): ok=%d ", ok);
  rgb("", c);
  printf("fromName(NOTACOLOR_XYZ): ok=%d\n", Quantity_Color::ColorFromName("NOTACOLOR_XYZ", c));
  ok = Quantity_Color::ColorFromHex("#FF0000", c);
  printf("fromHex(#FF0000): ok=%d ", ok);
  rgb("", c);
  printf("fromHex(NOT_HEX): ok=%d\n", Quantity_Color::ColorFromHex("NOT_HEX", c));

  Quantity_Color red(1, 0, 0, Quantity_TOC_RGB);
  printf("toHex(red, prefix=true)=[%s] toHex(red, prefix=false)=[%s]\n",
         Quantity_Color::ColorToHex(red, true).ToCString(),
         Quantity_Color::ColorToHex(red, false).ToCString());

  Quantity_ColorRGBA rgba;
  ok = Quantity_ColorRGBA::ColorFromHex("#FF000080", rgba);
  printf("fromHexRGBA(#FF000080): ok=%d r=%.17g g=%.17g b=%.17g a=%.17g\n",
         ok, rgba.GetRGB().Red(), rgba.GetRGB().Green(), rgba.GetRGB().Blue(), (double)rgba.Alpha());
  Quantity_ColorRGBA half(Quantity_Color(0.5, 0.5, 0.5, Quantity_TOC_RGB), 0.5f);
  printf("toHexRGBA(0.5,0.5,0.5,0.5)=[%s]\n", Quantity_ColorRGBA::ColorToHex(half, true).ToCString());
  Quantity_ColorRGBA redA(red, 1.0f);
  printf("toHexRGBA(red,1, prefix=true)=[%s] prefix=false=[%s]\n",
         Quantity_ColorRGBA::ColorToHex(redA, true).ToCString(),
         Quantity_ColorRGBA::ColorToHex(redA, false).ToCString());

  Quantity_Color blue(0, 0, 1, Quantity_TOC_RGB), green(0, 1, 0, Quantity_TOC_RGB);
  printf("distance(red, blue)=%.17g\n", red.Distance(blue));
  printf("squareDistance(red, green)=%.17g\n", red.SquareDistance(green));
  Quantity_Color d1(0.5, 0, 0, Quantity_TOC_RGB), d2(0.6, 0, 0, Quantity_TOC_RGB);
  printf("deltaE2000((0.5,0,0), (0.6,0,0))=%.17g\n", d1.DeltaE2000(d2));
  Quantity_Color same(0.3, 0.5, 0.7, Quantity_TOC_RGB);
  printf("deltaE2000(same (0.3,0.5,0.7))=%.17g\n", same.DeltaE2000(same));
  printf("hls(red): hue=%.17g light=%.17g sat=%.17g\n", red.Hue(), red.Light(), red.Saturation());

  Quantity_Color orig(0.4, 0.6, 0.2, Quantity_TOC_RGB);
  Quantity_Color back(orig.Hue(), orig.Light(), orig.Saturation(), Quantity_TOC_HLS);
  printf("hls(0.4,0.6,0.2): hue=%.17g light=%.17g sat=%.17g ", orig.Hue(), orig.Light(), orig.Saturation());
  rgb("-> back", back);

  Quantity_Color gray(0.5, 0.5, 0.5, Quantity_TOC_RGB);
  Quantity_Color gi = gray;
  gi.ChangeIntensity(0.1);
  rgb("changeIntensity(gray 0.5, +0.1)", gi);
  Quantity_Color gc = gray;
  gc.ChangeContrast(10.0);
  rgb("changeContrast(gray 0.5, +10)", gc);
  Quantity_Color cc(0.8, 0.3, 0.2, Quantity_TOC_RGB);
  cc.ChangeContrast(10.0);
  rgb("changeContrast((0.8,0.3,0.2), +10)", cc);

  NCollection_Vec3<float> half3(0.5f, 0.5f, 0.5f);
  NCollection_Vec3<float> s = Quantity_Color::Convert_LinearRGB_To_sRGB(half3);
  printf("linearToSRGB(0.5)=%.9g\n", s.r());
  NCollection_Vec3<float> l = Quantity_Color::Convert_sRGB_To_LinearRGB(half3);
  printf("sRGBToLinear(0.5)=%.9g\n", l.r());
  NCollection_Vec3<float> o(0.3f, 0.6f, 0.9f);
  NCollection_Vec3<float> rt = Quantity_Color::Convert_sRGB_To_LinearRGB(Quantity_Color::Convert_LinearRGB_To_sRGB(o));
  printf("sRGB roundtrip (0.3,0.6,0.9): r=%.9g g=%.9g b=%.9g\n", rt.r(), rt.g(), rt.b());
  NCollection_Vec3<float> lab = Quantity_Color::Convert_LinearRGB_To_Lab(half3);
  printf("lab(gray 0.5): L=%.9g a=%.9g b=%.9g\n", lab.x(), lab.y(), lab.z());
  printf("StringName(0)=[%s]\n", Quantity_Color::StringName((Quantity_NameOfColor)0));
  printf("Epsilon=%.17g\n", Quantity_Color::Epsilon());
  return 0;
}
