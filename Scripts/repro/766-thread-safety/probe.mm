// #1990 kernel parity for the six thread-safety suites in Tests/OCCTThreadTests
// (Issue298, Issue341, Issue359, Issue361, Issue367, Issue1404). Each section calls the OCCT API
// the bridge function calls, with the test's inputs, and prints what the Swift test observes.
// Where the test is concurrent, the section also runs the same work on 8 threads against the
// pinned kernel, so the kernel's own behaviour under that load is on record next to the Swift one.
//
// Build: see transcript.txt's header. Run: probe <dir holding fillet298_in1.brep/in2.brep>
#include <atomic>
#include <cmath>
#include <cstdio>
#include <mutex>
#include <string>
#include <thread>
#include <vector>

#include <BRepAlgoAPI_BuilderAlgo.hxx>
#include <BRepFilletAPI_MakeFillet.hxx>
#include <BRepGProp.hxx>
#include <BRepMesh_IncrementalMesh.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeSphere.hxx>
#include <BRepTools.hxx>
#include <BRep_Builder.hxx>
#include <Font_FontMgr.hxx>
#include <Font_SystemFont.hxx>
#include <GProp_GProps.hxx>
#include <Interface_Static.hxx>
#include <Message_ProgressRange.hxx>
#include <RWObj_CafReader.hxx>
#include <RWObj_CafWriter.hxx>
#include <STEPControl_Reader.hxx>
#include <STEPControl_Writer.hxx>
#include <TDF_LabelSequence.hxx>
#include <TDocStd_Application.hxx>
#include <TDocStd_Document.hxx>
#include <TNaming_Scope.hxx>
#include <TObj_Application.hxx>
#include <TopExp.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopTools_ListOfShape.hxx>
#include <TopoDS.hxx>
#include <XCAFDoc_DocumentTool.hxx>
#include <XCAFDoc_ShapeTool.hxx>

static TopoDS_Shape centeredBox(double w, double h, double d)
{
  // OCCTShapeCreateBox: centred at the origin.
  return BRepPrimAPI_MakeBox(gp_Pnt(-w / 2, -h / 2, -d / 2), w, h, d).Shape();
}

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

// ---- #298: OCCTShapeFilletEdges -> BRepFilletAPI_MakeFillet::Add(radius, edge) ----
// The two inputs are the exact shapes SheetMetal.Builder handed OCCTShapeFilletEdges for the
// U-channel (dumped from a Swift run), with the edge indices it passed.
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

static void probe298(const std::string& dir, const std::vector<int>& idx1,
                     const std::vector<int>& idx2, double r)
{
  BRep_Builder b;
  TopoDS_Shape in1, in2;
  BRepTools::Read(in1, (dir + "/fillet298_in1.brep").c_str(), b);
  BRepTools::Read(in2, (dir + "/fillet298_in2.brep").c_str(), b);
  if (in1.IsNull() || in2.IsNull())
  {
    printf("298 inputs missing\n");
    return;
  }
  TopoDS_Shape out1 = fillet(in1, idx1, r);
  printf("298 fillet1 volume=%.10f (Swift input2 volume=%.10f)\n", volumeOf(out1), volumeOf(in2));
  TopoDS_Shape out2 = fillet(in2, idx2, r);
  printf("298 fillet2 (final) volume=%.10f solids=%d faces=%d\n",
         volumeOf(out2), countOf(out2, TopAbs_SOLID), countOf(out2, TopAbs_FACE));
  const double ref = volumeOf(out2);
  std::atomic<int> wrong{0}, fail{0};
  std::vector<std::thread> th;
  for (int t = 0; t < 8; ++t)
    th.emplace_back([&] {
      for (int k = 0; k < 25; ++k)
      {
        TopoDS_Shape s = fillet(in2, idx2, r);
        if (s.IsNull()) { fail++; continue; }
        if (std::fabs(volumeOf(s) - ref) > std::max(1e-3, ref * 1e-6)) wrong++;
      }
    });
  for (auto& x : th) x.join();
  printf("298 concurrent 8x25 fillets on the pinned kernel: failed=%d wrongVolume=%d\n",
         fail.load(), wrong.load());
}

// ---- #341: OCCTExportOBJ (occtExportCafImpl) + OCCTDocumentLoadOBJ ----
static bool objRoundTrip(const std::string& path, int* outFree, int* outFaces)
{
  TopoDS_Shape box = centeredBox(10, 20, 30);
  BRepMesh_IncrementalMesh mesher(box, 0.1); // Exporter.writeOBJ default deflection
  mesher.Perform();
  Handle(TDocStd_Application) app = new TDocStd_Application();
  Handle(TDocStd_Document) doc;
  app->NewDocument("MDTV-XCAF", doc);
  Handle(XCAFDoc_ShapeTool) st = XCAFDoc_DocumentTool::ShapeTool(doc->Main());
  st->AddShape(box);
  TDF_LabelSequence freeShapes;
  st->GetFreeShapes(freeShapes);
  NCollection_Sequence<TDF_Label> roots;
  for (int i = 1; i <= freeShapes.Length(); ++i) roots.Append(freeShapes.Value(i));
  NCollection_IndexedDataMap<TCollection_AsciiString, TCollection_AsciiString> info;
  RWObj_CafWriter writer(path.c_str());
  if (!writer.Perform(doc, roots, nullptr, info, Message_ProgressRange())) return false;
  app->Close(doc);

  Handle(TDocStd_Application) rapp = new TDocStd_Application();
  Handle(TDocStd_Document) rdoc;
  rapp->NewDocument("MDTV-XCAF", rdoc);
  RWObj_CafReader reader;
  reader.SetDocument(rdoc);
  if (!reader.Perform(TCollection_AsciiString(path.c_str()), Message_ProgressRange())) return false;
  Handle(XCAFDoc_ShapeTool) rst = XCAFDoc_DocumentTool::ShapeTool(rdoc->Main());
  TDF_LabelSequence rfree;
  rst->GetFreeShapes(rfree);
  // Document.allShapes() walks root labels and their component children, so count both.
  int tree = 0;
  for (int i = 1; i <= rfree.Length(); ++i)
  {
    ++tree;
    TDF_LabelSequence comps;
    rst->GetComponents(rfree.Value(i), comps, true);
    tree += comps.Length();
  }
  if (outFree) *outFree = tree;
  if (outFaces && rfree.Length() > 0) *outFaces = countOf(rst->GetShape(rfree.Value(1)), TopAbs_FACE);
  std::remove(path.c_str());
  return rfree.Length() > 0;
}

static void probe341()
{
  int nFree = -1, nFaces = -1;
  bool ok = objRoundTrip("/tmp/probe766_341.obj", &nFree, &nFaces);
  printf("341 OBJ round trip ok=%d freeShapes+components=%d facesOfFirst=%d\n", ok, nFree, nFaces);
  std::atomic<int> failed{0};
  std::vector<std::thread> th;
  for (int t = 0; t < 8; ++t)
    th.emplace_back([&, t] {
      for (int i = 0; i < 15; ++i)
        if (!objRoundTrip("/tmp/probe766_341_" + std::to_string(t) + "_" + std::to_string(i) + ".obj",
                          nullptr, nullptr))
          failed++;
    });
  for (auto& x : th) x.join();
  printf("341 concurrent 8x15 OBJ round trips on the pinned kernel: failed=%d\n", failed.load());
}

// ---- #359: OCCTExportSTEPWithMode + OCCTImportSTEPProgress ----
static std::mutex gIges;
static bool stepRoundTrip(const std::string& path, bool lock, int* outFaces, double* outVol)
{
  TopoDS_Shape box = centeredBox(10, 20, 30);
  {
    std::unique_lock<std::mutex> l(gIges, std::defer_lock);
    if (lock) l.lock();
    STEPControl_Writer w;
    Interface_Static::SetCVal("write.step.schema", "AP214");
    if (w.Transfer(box, STEPControl_AsIs) != IFSelect_RetDone) return false;
    if (w.Write(path.c_str()) != IFSelect_RetDone) return false;
  }
  std::unique_lock<std::mutex> l(gIges, std::defer_lock);
  if (lock) l.lock();
  STEPControl_Reader r;
  if (r.ReadFile(path.c_str()) != IFSelect_RetDone) return false;
  r.TransferRoots(Message_ProgressRange());
  TopoDS_Shape s = r.OneShape();
  std::remove(path.c_str());
  if (s.IsNull()) return false;
  if (outFaces) *outFaces = countOf(s, TopAbs_FACE);
  if (outVol) *outVol = volumeOf(s);
  return countOf(s, TopAbs_FACE) > 0;
}

static void probe359()
{
  int f = -1;
  double v = -1;
  bool ok = stepRoundTrip("/tmp/probe766_359.step", true, &f, &v);
  printf("359 STEP round trip ok=%d faces=%d volume=%.10f\n", ok, f, v);
  for (int lock = 1; lock >= 0; --lock)
  {
    std::atomic<int> failed{0};
    std::vector<std::thread> th;
    for (int t = 0; t < 8; ++t)
      th.emplace_back([&, t] {
        for (int i = 0; i < 15; ++i)
          if (!stepRoundTrip("/tmp/probe766_359_" + std::to_string(t) + "_" + std::to_string(i) + ".step",
                             lock, nullptr, nullptr))
            failed++;
      });
    for (auto& x : th) x.join();
    printf("359 concurrent 8x15 STEP round trips, %s: failed=%d\n",
           lock ? "serialized like igesMutex()" : "unserialized", failed.load());
  }
}

// ---- #361: OCCTDocumentNamingScope* -> TNaming_Scope; OCCTFontMgr* -> Font_FontMgr ----
static void probe361()
{
  Handle(TDocStd_Application) app = new TDocStd_Application();
  Handle(TDocStd_Document) docA, docB;
  app->NewDocument("MDTV-XCAF", docA);
  app->NewDocument("MDTV-XCAF", docB);
  TDF_Label la = XCAFDoc_DocumentTool::ShapeTool(docA->Main())->AddShape(centeredBox(5, 5, 5), false);
  TDF_Label lb = XCAFDoc_DocumentTool::ShapeTool(docB->Main())->AddShape(centeredBox(7, 7, 7), false);
  TNaming_Scope sa(true), sb(true); // one per OCCTDocument, as OCCTDocument::namingScope
  sa.Valid(la);
  sa.Valid(la);
  printf("361 isolation: A.count=%d B.count=%d A.isValid(la)=%d B.isValid(lb)=%d\n",
         sa.GetValid().Extent(), sb.GetValid().Extent(), sa.IsValid(la), sb.IsValid(lb));
  sb.Valid(lb);
  sa.ClearValid();
  printf("361 isolation: after B.Valid + A.Clear: A.count=%d B.count=%d\n",
         sa.GetValid().Extent(), sb.GetValid().Extent());

  TNaming_Scope s(true);
  s.Valid(la);
  int c1 = s.GetValid().Extent();
  s.ValidChildren(la, true);
  int c2 = s.GetValid().Extent();
  s.Unvalid(la);
  int v3 = s.IsValid(la);
  s.ClearValid();
  printf("361 sequence: afterValid=%d afterValidChildren=%d afterUnvalid.isValid=%d afterClear=%d\n",
         c1, c2, v3, s.GetValid().Extent());

  Handle(Font_FontMgr) mgr = Font_FontMgr::GetInstance();
  mgr->InitFontDataBase();
  NCollection_List<Handle(Font_SystemFont)> fonts = mgr->GetAvailableFonts();
  printf("361 fonts: count=%d first=%s\n", fonts.Size(),
         fonts.IsEmpty() ? "none" : fonts.First()->FontName().ToCString());
}

// ---- #367: OCCTShapeFuseMulti -> BRepAlgoAPI_BuilderAlgo ----
static TopoDS_Shape fuseMulti(bool parallel)
{
  TopTools_ListOfShape args;
  args.Append(centeredBox(10, 10, 10));
  args.Append(BRepPrimAPI_MakeSphere(gp_Pnt(5, 5, 5), 6).Shape());
  BRepAlgoAPI_BuilderAlgo b;
  b.SetArguments(args);
  b.SetRunParallel(parallel);
  b.Build();
  return b.IsDone() ? b.Shape() : TopoDS_Shape();
}

static void probe367()
{
  TopoDS_Shape r = fuseMulti(false);
  const int base = countOf(r, TopAbs_FACE);
  printf("367 General Fuse faces=%d solids=%d volume=%.10f\n", base, countOf(r, TopAbs_SOLID),
         volumeOf(r));
  for (int par = 0; par <= 1; ++par)
  {
    std::atomic<int> failed{0}, wrong{0};
    std::vector<std::thread> th;
    for (int t = 0; t < 8; ++t)
      th.emplace_back([&] {
        for (int i = 0; i < 50; ++i)
        {
          TopoDS_Shape s = fuseMulti(par);
          if (s.IsNull()) { failed++; continue; }
          if (countOf(s, TopAbs_FACE) != base) wrong++;
        }
      });
    for (auto& x : th) x.join();
    printf("367 concurrent 8x50, SetRunParallel(%s): failed=%d wrongFaceCount=%d\n",
           par ? "true" : "false", failed.load(), wrong.load());
  }
}

// ---- #1404: OCCTTObjApplication* -> TObj_Application ----
static void probe1404()
{
  Handle(TObj_Application) app = TObj_Application::GetInstance();
  const bool orig = app->IsVerbose();
  app->SetVerbose(true);
  const bool t = app->IsVerbose();
  app->SetVerbose(false);
  const bool f = app->IsVerbose();
  app->SetVerbose(orig);
  Handle(TDocStd_Document) doc;
  const bool created = app->CreateNewDocument(doc, "BinOcaf");
  printf("1404 IsVerbose after SetVerbose(true)=%d after SetVerbose(false)=%d CreateNewDocument=%d\n",
         t, f, created && !doc.IsNull());
}

int main(int argc, char** argv)
{
  const std::string dir = argc > 1 ? argv[1] : ".";
  // Edge indices and radius as SheetMetal.Builder passed them to OCCTShapeFilletEdges
  // (dumped with the shapes; see transcript.txt).
  std::vector<int> idx1, idx2;
  double r = 0;
  if (FILE* fp = fopen((dir + "/fillet298_args.txt").c_str(), "r"))
  {
    int n1, n2;
    if (fscanf(fp, "%lf %d", &r, &n1) == 2)
      for (int i = 0, v; i < n1 && fscanf(fp, "%d", &v) == 1; ++i) idx1.push_back(v);
    if (fscanf(fp, "%d", &n2) == 1)
      for (int i = 0, v; i < n2 && fscanf(fp, "%d", &v) == 1; ++i) idx2.push_back(v);
    fclose(fp);
  }
  printf("298 args: radius=%g idx1.size=%zu idx2.size=%zu\n", r, idx1.size(), idx2.size());
  probe298(dir, idx1, idx2, r);
  probe341();
  probe359();
  probe361();
  probe367();
  probe1404();
  return 0;
}
