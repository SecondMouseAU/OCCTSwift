// Epic #766, BinToolsTests.swift and BRepAdaptorTests.swift: kernel parity for all nine tests.
// Same inputs as the Swift tests, straight to OCCT: the centred box OCCTShapeCreateBox builds,
// sub-shapes by TopExp::MapShapes (occtMapSubShapes), BinTools_ShapeWriter/Reader over a string
// stream and a file, BRepAdaptor_Curve on edge 1 and BRepAdaptor_Surface on face 1.
#include <BRepAdaptor_Curve.hxx>
#include <BRepAdaptor_Surface.hxx>
#include <BRepCheck_Analyzer.hxx>
#include <BRepGProp.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeSphere.hxx>
#include <BinTools_ShapeReader.hxx>
#include <BinTools_ShapeWriter.hxx>
#include <GProp_GProps.hxx>
#include <TopExp.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopoDS.hxx>
#include <cstdio>
#include <fstream>
#include <sstream>

static TopoDS_Shape centredBox(double w, double h, double d)
{
  return BRepPrimAPI_MakeBox(gp_Pnt(-w / 2, -h / 2, -d / 2), w, h, d).Shape();
}

static void report(const char* tag, const TopoDS_Shape& s)
{
  GProp_GProps g;
  BRepGProp::VolumeProperties(s, g);
  TopTools_IndexedMapOfShape faces;
  TopExp::MapShapes(s, TopAbs_FACE, faces);
  printf("%s: null=%d valid=%d volume=%.17g faces=%d\n", tag, s.IsNull(),
         BRepCheck_Analyzer(s).IsValid(), g.Mass(), faces.Extent());
}

int main()
{
  TopoDS_Shape box = centredBox(10, 20, 30);
  {
    std::ostringstream oss;
    BinTools_ShapeWriter().Write(box, oss);
    std::string bytes = oss.str();
    printf("writeAndReadBinaryData: bytes=%zu\n", bytes.size());
    std::istringstream iss(bytes);
    TopoDS_Shape       back;
    BinTools_ShapeReader().Read(iss, back);
    report("writeAndReadBinaryData read", back);
  }
  {
    const char* path = "/tmp/probe766_bintools.brep";
    {
      std::ofstream f(path, std::ios::binary);
      BinTools_ShapeWriter().Write(box, f);
    }
    std::ifstream fin(path, std::ios::binary);
    TopoDS_Shape  back;
    BinTools_ShapeReader().Read(fin, back);
    report("writeAndReadBinaryFile read", back);
    remove(path);
  }
  {
    TopoDS_Shape       sphere = BRepPrimAPI_MakeSphere(5).Shape();
    std::ostringstream oss;
    BinTools_ShapeWriter().Write(sphere, oss);
    std::istringstream iss(oss.str());
    TopoDS_Shape       back;
    BinTools_ShapeReader().Read(iss, back);
    report("sphereRoundtrip original", sphere);
    report("sphereRoundtrip read", back);
  }

  TopoDS_Shape               cube = centredBox(10, 10, 10);
  TopTools_IndexedMapOfShape edges, faces;
  TopExp::MapShapes(cube, TopAbs_EDGE, edges);
  TopExp::MapShapes(cube, TopAbs_FACE, faces);
  BRepAdaptor_Curve c(TopoDS::Edge(edges(1)));
  gp_Pnt            p0 = c.Value(c.FirstParameter());
  gp_Pnt            p1 = c.Value(c.LastParameter());
  printf("edge1: domain=[%.17g, %.17g] type=%d value(first)=(%.17g, %.17g, %.17g) "
         "value(last)=(%.17g, %.17g, %.17g)\n",
         c.FirstParameter(), c.LastParameter(), (int)c.GetType(), p0.X(), p0.Y(), p0.Z(), p1.X(),
         p1.Y(), p1.Z());
  BRepAdaptor_Surface s(TopoDS::Face(faces(1)));
  double              mu = (s.FirstUParameter() + s.LastUParameter()) / 2;
  double              mv = (s.FirstVParameter() + s.LastVParameter()) / 2;
  gp_Pnt              pm = s.Value(mu, mv);
  printf("face1: u=[%.17g, %.17g] v=[%.17g, %.17g] type=%d value(mid)=(%.17g, %.17g, %.17g)\n",
         s.FirstUParameter(), s.LastUParameter(), s.FirstVParameter(), s.LastVParameter(),
         (int)s.GetType(), pm.X(), pm.Y(), pm.Z());
  return 0;
}
