// Epic #766, StressFormatRoundTripTests.swift: kernel parity for every test in the file.
// Each standard fixture is written and read back with the classes the bridge uses:
// STEPControl_Writer (AP214, as-is) / STEPControl_Reader::OneShape, BRepTools::Write (with
// triangles) / BRepTools::Read, BRepTools::Write/Read on a string stream, BRepMesh at 0.1 +
// StlAPI_Writer (binary) / StlAPI_Reader, RWObj_CafWriter / RWObj_CafReader through an XCAF
// document, and IGESControl_Writer / IGESControl_Reader::OneShape.
#include <BRepAlgoAPI_Cut.hxx>
#include <BRepAlgoAPI_Fuse.hxx>
#include <BRepBndLib.hxx>
#include <BRepBuilderAPI_Sewing.hxx>
#include <BRepCheck_Analyzer.hxx>
#include <BRepFilletAPI_MakeFillet.hxx>
#include <BRepGProp.hxx>
#include <BRepMesh_IncrementalMesh.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeCone.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <BRepPrimAPI_MakeSphere.hxx>
#include <BRepPrimAPI_MakeTorus.hxx>
#include <BRepTools.hxx>
#include <BRep_Builder.hxx>
#include <BRep_Tool.hxx>
#include <Bnd_Box.hxx>
#include <GProp_GProps.hxx>
#include <IGESControl_Controller.hxx>
#include <IGESControl_Reader.hxx>
#include <IGESControl_Writer.hxx>
#include <Interface_Static.hxx>
#include <Message_ProgressRange.hxx>
#include <Poly_Triangulation.hxx>
#include <RWObj_CafReader.hxx>
#include <RWObj_CafWriter.hxx>
#include <STEPControl_Reader.hxx>
#include <STEPControl_Writer.hxx>
#include <StlAPI_Reader.hxx>
#include <StlAPI_Writer.hxx>
#include <TColStd_IndexedDataMapOfStringString.hxx>
#include <TDocStd_Application.hxx>
#include <TDocStd_Document.hxx>
#include <TopExp.hxx>
#include <TopExp_Explorer.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopoDS.hxx>
#include <XCAFDoc_DocumentTool.hxx>
#include <XCAFDoc_ShapeTool.hxx>
#include <cmath>
#include <cstdio>
#include <sstream>
#include <string>
#include <utility>
#include <vector>

static bool gHas;
static double vol(const TopoDS_Shape& s)
{
  GProp_GProps p;
  BRepGProp::VolumeProperties(s, p, true);
  gHas = p.Mass() != 0.0 && p.Mass() >= 0;
  return p.Mass();
}

static double area(const TopoDS_Shape& s)
{
  GProp_GProps p;
  BRepGProp::SurfaceProperties(s, p);
  return p.Mass();
}

static int count(const TopoDS_Shape& s, TopAbs_ShapeEnum t)
{
  TopTools_IndexedMapOfShape m;
  TopExp::MapShapes(s, t, m);
  return m.Extent();
}

static void extent(const TopoDS_Shape& s, double& dx, double& dy, double& dz)
{
  Bnd_Box b;
  BRepBndLib::Add(s, b, true);
  double x0, y0, z0, x1, y1, z1;
  b.Get(x0, y0, z0, x1, y1, z1);
  dx = x1 - x0;
  dy = y1 - y0;
  dz = z1 - z0;
}

static TopoDS_Shape centredBox(double w, double h, double d)
{
  return BRepPrimAPI_MakeBox(gp_Pnt(-w / 2, -h / 2, -d / 2), w, h, d).Shape();
}

static std::vector<std::pair<const char*, TopoDS_Shape>> fixtures()
{
  TopoDS_Shape box = centredBox(10, 10, 10);
  TopoDS_Shape cyl = BRepPrimAPI_MakeCylinder(5, 10).Shape();

  BRepFilletAPI_MakeFillet f(box);
  for (TopExp_Explorer e(box, TopAbs_EDGE); e.More(); e.Next())
    f.Add(1.0, TopoDS::Edge(e.Current()));
  f.Build();

  TopoDS_Shape plate = centredBox(50, 50, 5);
  Bnd_Box      pb;
  BRepBndLib::Add(plate, pb);
  double x0, y0, z0, x1, y1, z1;
  pb.Get(x0, y0, z0, x1, y1, z1);
  double depth = 2 * std::sqrt((x1 - x0) * (x1 - x0) + (y1 - y0) * (y1 - y0) + (z1 - z0) * (z1 - z0));
  TopoDS_Shape drilled =
    BRepAlgoAPI_Cut(plate, BRepPrimAPI_MakeCylinder(gp_Ax2(gp_Pnt(0, 0, 5), gp_Dir(0, 0, -1)), 3, depth).Shape())
      .Shape();

  return {{"box", box},
          {"cylinder", cyl},
          {"sphere", BRepPrimAPI_MakeSphere(5).Shape()},
          {"cone", BRepPrimAPI_MakeCone(5, 2, 10).Shape()},
          {"torus", BRepPrimAPI_MakeTorus(10, 3).Shape()},
          {"filletedBox", f.Shape()},
          {"drilledPlate", drilled},
          {"compound", BRepAlgoAPI_Fuse(box, cyl).Shape()}};
}

int main()
{
  const std::string dir = "/tmp/occt766_fmt_probe_";
  auto              all = fixtures();

  printf("== originals\n");
  for (auto& [name, s] : all)
  {
    double v = vol(s);
    double dx, dy, dz;
    extent(s, dx, dy, dz);
    printf("%s: volume=%.10g area=%.10g faces=%d edges=%d valid=%d size=(%.6g, %.6g, %.6g)\n", name, v, area(s),
           count(s, TopAbs_FACE), count(s, TopAbs_EDGE), BRepCheck_Analyzer(s).IsValid(), dx, dy, dz);
  }

  printf("== STEP (AP214, as-is)\n");
  for (auto& [name, s] : all)
  {
    std::string        path = dir + name + ".step";
    STEPControl_Writer w;
    Interface_Static::SetCVal("write.step.schema", "AP214");
    w.Transfer(s, STEPControl_AsIs);
    w.Write(path.c_str());
    STEPControl_Reader r;
    r.ReadFile(path.c_str());
    r.TransferRoots();
    TopoDS_Shape back = r.OneShape();
    double       v    = vol(back);
    printf("%s: valid=%d volume=%s%.10g area=%.10g faces=%d edges=%d\n", name, BRepCheck_Analyzer(back).IsValid(),
           gHas ? "" : "nil/", v, area(back), count(back, TopAbs_FACE), count(back, TopAbs_EDGE));
  }

  printf("== BREP file\n");
  for (auto& [name, s] : all)
  {
    std::string path = dir + name + ".brep";
    BRepTools::Write(s, path.c_str(), true, false, TopTools_FormatVersion_CURRENT);
    TopoDS_Shape back;
    BRep_Builder bb;
    BRepTools::Read(back, path.c_str(), bb);
    double v = vol(back);
    printf("%s: valid=%d volume=%.10g faces=%d edges=%d\n", name, BRepCheck_Analyzer(back).IsValid(), v,
           count(back, TopAbs_FACE), count(back, TopAbs_EDGE));
  }

  printf("== BREP string\n");
  for (auto& [name, s] : all)
  {
    std::ostringstream os;
    BRepTools::Write(s, os);
    std::istringstream is(os.str());
    TopoDS_Shape       back;
    BRep_Builder       bb;
    BRepTools::Read(back, is, bb);
    printf("%s: string length=%zu valid=%d volume=%.10g faces=%d\n", name, os.str().size(),
           BRepCheck_Analyzer(back).IsValid(), vol(back), count(back, TopAbs_FACE));
  }

  printf("== STL (BRepMesh 0.1, binary)\n");
  for (int i = 0; i < 6; ++i)
  {
    auto&       name = all[i].first;
    auto&       s    = all[i].second;
    std::string path = dir + name + ".stl";
    BRepMesh_IncrementalMesh m(s, 0.1);
    StlAPI_Writer            w;
    w.ASCIIMode() = false;
    w.Write(s, path.c_str());
    TopoDS_Shape  back;
    StlAPI_Reader r;
    r.Read(back, path.c_str());
    double dx, dy, dz, ox, oy, oz;
    extent(back, dx, dy, dz);
    extent(s, ox, oy, oz);
    printf("%s: faces=%d valid=%d size=(%.6g, %.6g, %.6g) original size.x=%.6g\n", name, count(back, TopAbs_FACE),
           BRepCheck_Analyzer(back).IsValid(), dx, dy, dz, ox);
  }

  printf("== OBJ (RWObj_CafWriter / RWObj_CafReader)\n");
  {
    const char* names[4] = {"box", "cylinder", "sphere", "filletedBox"};
    for (auto nm : names)
    {
      TopoDS_Shape s;
      for (auto& [n, sh] : all)
        if (std::string(n) == nm)
          s = sh;
      Handle(TDocStd_Application) app = new TDocStd_Application();
      Handle(TDocStd_Document)    doc;
      app->NewDocument("BinXCAF", doc);
      Handle(XCAFDoc_ShapeTool) st = XCAFDoc_DocumentTool::ShapeTool(doc->Main());
      st->AddShape(s);
      BRepMesh_IncrementalMesh m(s, 0.1);
      std::string              path = dir + nm + ".obj";
      RWObj_CafWriter          w(path.c_str());
      TColStd_IndexedDataMapOfStringString info;
      w.Perform(doc, info, Message_ProgressRange());

      Handle(TDocStd_Document) doc2;
      app->NewDocument("BinXCAF", doc2);
      RWObj_CafReader r;
      r.SetDocument(doc2);
      r.Perform(TCollection_AsciiString(path.c_str()), Message_ProgressRange());
      TopoDS_Shape back = XCAFDoc_DocumentTool::ShapeTool(doc2->Main())->GetOneShape();
      int          tris = 0;
      for (TopExp_Explorer e(back, TopAbs_FACE); e.More(); e.Next())
      {
        TopLoc_Location loc;
        auto            t = BRep_Tool::Triangulation(TopoDS::Face(e.Current()), loc);
        tris += t.IsNull() ? 0 : t->NbTriangles();
      }
      double dx, dy, dz;
      extent(back, dx, dy, dz);
      printf("%s: null=%d faces=%d triangles=%d size=(%.6g, %.6g, %.6g)\n", nm, back.IsNull(), count(back, TopAbs_FACE),
             tris, dx, dy, dz);
    }
  }

  printf("== IGES (IGESControl_Writer default / IGESControl_Reader::OneShape)\n");
  IGESControl_Controller::Init();
  for (int i = 0; i < 5; ++i)
  {
    auto&              name = all[i].first;
    auto&              s    = all[i].second;
    std::string        path = dir + name + ".iges";
    IGESControl_Writer w;
    w.AddShape(s);
    w.ComputeModel();
    w.Write(path.c_str());
    IGESControl_Reader r;
    r.ReadFile(path.c_str());
    r.TransferRoots();
    TopoDS_Shape back = r.OneShape();
    printf("%s: faces=%d solids=%d ", name, count(back, TopAbs_FACE), count(back, TopAbs_SOLID));
    BRepBuilderAPI_Sewing sew(1e-6);
    for (TopExp_Explorer e(back, TopAbs_FACE); e.More(); e.Next())
      sew.Add(e.Current());
    sew.Perform();
    double v = vol(sew.SewedShape());
    printf("sewn volume=%s%.10g\n", gHas ? "" : "nil/", v);
  }
  return 0;
}
