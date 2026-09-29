// Epic #766 evidence correction, Thread domain. Two kernel measurements the #1990 thread-safety parity
// records were missing, taken with the same OCCT calls as Scripts/repro/766-thread-safety/probe.mm (whose inputs
// directory is reused unchanged):
//
//  - #298 (OCCTShapeFilletEdges): BRepCheck_Analyzer validity of the final fillet, and the four outcome counters the
//    Swift test counts over its 8 x 25 concurrent builds (threw, BRepCheck-invalid, solid count != 1, volume off the
//    reference), here counted over 8 threads x 25 fillets of the same input.
//  - #341 (OCCTExportOBJ + OCCTDocumentLoadOBJ): the face count of every shape Document.allShapes() would walk (each
//    free shape and each of its components), not only the first.
//
// Build: see the CLAUDE.md ground-truth line (-std=c++17). Run: probe <dir holding fillet298_in1.brep/in2.brep/args>,
// e.g. Scripts/repro/766-thread-safety/inputs
#include <atomic>
#include <cmath>
#include <cstdio>
#include <string>
#include <thread>
#include <vector>

#include <BRepCheck_Analyzer.hxx>
#include <BRepFilletAPI_MakeFillet.hxx>
#include <BRepGProp.hxx>
#include <BRepMesh_IncrementalMesh.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepTools.hxx>
#include <BRep_Builder.hxx>
#include <GProp_GProps.hxx>
#include <Message_ProgressRange.hxx>
#include <RWObj_CafReader.hxx>
#include <RWObj_CafWriter.hxx>
#include <TDF_LabelSequence.hxx>
#include <TDocStd_Application.hxx>
#include <TDocStd_Document.hxx>
#include <TopExp.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopoDS.hxx>
#include <XCAFDoc_DocumentTool.hxx>
#include <XCAFDoc_ShapeTool.hxx>

static double volumeOf(const TopoDS_Shape& s)
{
  GProp_GProps p;
  BRepGProp::VolumeProperties(s, p);
  return p.Mass();
}

static int countOf(const TopoDS_Shape& s, TopAbs_ShapeEnum t)
{
  TopTools_IndexedMapOfShape m;
  TopExp::MapShapes(s, t, m);
  return m.Extent();
}

static TopoDS_Shape fillet(const TopoDS_Shape& in, const std::vector<int>& idx, double r)
{
  TopTools_IndexedMapOfShape edges;
  TopExp::MapShapes(in, TopAbs_EDGE, edges);
  BRepFilletAPI_MakeFillet mk(in);
  for (int i : idx)
    mk.Add(r, TopoDS::Edge(edges(i + 1)));
  mk.Build();
  return mk.IsDone() ? mk.Shape() : TopoDS_Shape();
}

static void probe298(const std::string& dir, const std::vector<int>& idx1, const std::vector<int>& idx2, double r)
{
  BRep_Builder b;
  TopoDS_Shape in1, in2;
  BRepTools::Read(in1, (dir + "/fillet298_in1.brep").c_str(), b);
  BRepTools::Read(in2, (dir + "/fillet298_in2.brep").c_str(), b);
  TopoDS_Shape out2 = fillet(in2, idx2, r);
  printf("298 final fillet: volume=%.10f solids=%d faces=%d BRepCheck_Analyzer valid=%d\n", volumeOf(out2),
         countOf(out2, TopAbs_SOLID), countOf(out2, TopAbs_FACE), BRepCheck_Analyzer(out2).IsValid() ? 1 : 0);
  const double     ref       = volumeOf(out2);
  const double     tolerance = std::max(1e-3, ref * 1e-6);
  std::atomic<int> failed{0}, invalid{0}, wrongSolids{0}, wrongVolume{0};
  std::vector<std::thread> th;
  for (int t = 0; t < 8; ++t)
    th.emplace_back([&] {
      for (int k = 0; k < 25; ++k)
      {
        TopoDS_Shape s = fillet(in2, idx2, r);
        if (s.IsNull())
        {
          failed++;
          continue;
        }
        if (!BRepCheck_Analyzer(s).IsValid())
          invalid++;
        if (countOf(s, TopAbs_SOLID) != 1)
          wrongSolids++;
        if (std::fabs(volumeOf(s) - ref) > tolerance)
          wrongVolume++;
      }
    });
  for (auto& x : th)
    x.join();
  printf("298 concurrent 8x25 fillets: failed=%d invalid=%d wrongSolidCount=%d wrongVolume=%d\n", failed.load(),
         invalid.load(), wrongSolids.load(), wrongVolume.load());
}

static void probe341()
{
  const std::string path = "/tmp/probe766_evidence_341.obj";
  TopoDS_Shape      box  = BRepPrimAPI_MakeBox(gp_Pnt(-5, -10, -15), 10, 20, 30).Shape();  // OCCTShapeCreateBox, centred
  BRepMesh_IncrementalMesh mesher(box, 0.1);
  mesher.Perform();
  Handle(TDocStd_Application) app = new TDocStd_Application();
  Handle(TDocStd_Document)    doc;
  app->NewDocument("MDTV-XCAF", doc);
  Handle(XCAFDoc_ShapeTool) st = XCAFDoc_DocumentTool::ShapeTool(doc->Main());
  st->AddShape(box);
  TDF_LabelSequence freeShapes;
  st->GetFreeShapes(freeShapes);
  NCollection_Sequence<TDF_Label> roots;
  for (int i = 1; i <= freeShapes.Length(); ++i)
    roots.Append(freeShapes.Value(i));
  NCollection_IndexedDataMap<TCollection_AsciiString, TCollection_AsciiString> info;
  RWObj_CafWriter                                                              writer(path.c_str());
  writer.Perform(doc, roots, nullptr, info, Message_ProgressRange());
  app->Close(doc);

  Handle(TDocStd_Application) rapp = new TDocStd_Application();
  Handle(TDocStd_Document)    rdoc;
  rapp->NewDocument("MDTV-XCAF", rdoc);
  RWObj_CafReader reader;
  reader.SetDocument(rdoc);
  reader.Perform(TCollection_AsciiString(path.c_str()), Message_ProgressRange());
  Handle(XCAFDoc_ShapeTool) rst = XCAFDoc_DocumentTool::ShapeTool(rdoc->Main());
  TDF_LabelSequence         rfree;
  rst->GetFreeShapes(rfree);
  // Document.allShapes() walks root labels and their component children.
  std::vector<int> faces;
  for (int i = 1; i <= rfree.Length(); ++i)
  {
    faces.push_back(countOf(rst->GetShape(rfree.Value(i)), TopAbs_FACE));
    TDF_LabelSequence comps;
    rst->GetComponents(rfree.Value(i), comps, true);
    for (int c = 1; c <= comps.Length(); ++c)
      faces.push_back(countOf(rst->GetShape(comps.Value(c)), TopAbs_FACE));
  }
  printf("341 OBJ round trip: shapes(free + components)=%zu faces per shape=[", faces.size());
  for (size_t i = 0; i < faces.size(); ++i)
    printf("%s%d", i ? ", " : "", faces[i]);
  printf("]\n");
  std::remove(path.c_str());
}

int main(int argc, char** argv)
{
  const std::string dir = argc > 1 ? argv[1] : ".";
  std::vector<int>  idx1, idx2;
  double            r = 0;
  if (FILE* fp = fopen((dir + "/fillet298_args.txt").c_str(), "r"))
  {
    int n1, n2;
    if (fscanf(fp, "%lf %d", &r, &n1) == 2)
      for (int i = 0, v; i < n1 && fscanf(fp, "%d", &v) == 1; ++i)
        idx1.push_back(v);
    if (fscanf(fp, "%d", &n2) == 1)
      for (int i = 0, v; i < n2 && fscanf(fp, "%d", &v) == 1; ++i)
        idx2.push_back(v);
    fclose(fp);
  }
  probe298(dir, idx1, idx2, r);
  probe341();
  return 0;
}
