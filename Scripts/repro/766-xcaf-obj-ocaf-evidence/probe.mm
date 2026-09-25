// Kernel-parity probe for #766 (OCCTXCAFTests). Calls the OCCT API the bridge calls, with the
// test's inputs, and prints what the kernel returns. Build line: CLAUDE.md "Compile a Ground
// Truth C++ Test", headers/lib from the pinned OCCT.xcframework.
#include <BRepPrimAPI_MakeBox.hxx>
#include <TDocStd_Application.hxx>
#include <TDocStd_Document.hxx>
#include <TDF_Label.hxx>
#include <TDF_LabelSequence.hxx>
#include <TDF_Tool.hxx>
#include <TCollection_AsciiString.hxx>
#include <TCollection_ExtendedString.hxx>
#include <XCAFDoc_DocumentTool.hxx>
#include <XCAFDoc_ShapeTool.hxx>
#include <XCAFDoc_ColorTool.hxx>
#include <XCAFDoc_VisMaterialTool.hxx>
#include <TopoDS_Shape.hxx>
#include <cstdio>

// OCCTDocument(): a private TDocStd_Application (#371), NewDocument("MDTV-XCAF"), then the three
// XCAF tools occtDocumentInit fetches.
static Handle(TDocStd_Document) newDoc(Handle(TDocStd_Application)& app)
{
  app = new TDocStd_Application();
  Handle(TDocStd_Document) d;
  app->NewDocument("MDTV-XCAF", d);
  XCAFDoc_DocumentTool::ShapeTool(d->Main());
  XCAFDoc_DocumentTool::ColorTool(d->Main());
  XCAFDoc_DocumentTool::VisMaterialTool(d->Main());
  return d;
}

// getLabelForTag: tag 0 is Main, otherwise Main().FindChild(tag, create).
static TDF_Label tagLabel(const Handle(TDocStd_Document)& d, int tag)
{
  return tag == 0 ? d->Main() : d->Main().FindChild(tag, Standard_True);
}

// OCCTShapeCreateBox: centred on the origin.
static TopoDS_Shape centredBox(double w, double h, double dp)
{
  return BRepPrimAPI_MakeBox(gp_Pnt(-w / 2, -h / 2, -dp / 2), w, h, dp).Shape();
}

static const char* tf(bool b) { return b ? "true" : "false"; }

#include <BRepMesh_IncrementalMesh.hxx>
#include <Message_ProgressRange.hxx>
#include <NCollection_IndexedDataMap.hxx>
#include <NCollection_Sequence.hxx>
#include <RWMesh_CoordinateSystem.hxx>
#include <RWObj_CafReader.hxx>
#include <RWObj_CafWriter.hxx>
#include <fstream>

// Kernel-parity probe for OBJDocumentIOTests (#766). Each scenario mirrors what the bridge does for the test's
// call, with the test's inputs: the input file is written the way Shape.writeOBJ writes it (OCCTExportOBJ ->
// occtExportCafImpl, deflection 0.1), the loads are OCCTDocumentLoadOBJ / LoadOBJWithOptions / LoadOBJWithCS on a
// document initialised like OCCTDocument() (occtDocumentInit), and the write is OCCTDocumentWriteOBJ
// (occtDocumentWriteImpl, deflection 1.0). The earlier probe in 766-xcaf-obj-ocaf/ used a hand-written OBJ.
static bool fileExists(const char* path)
{
  std::ifstream f(path);
  return f.good();
}

// Shape.writeOBJ(to:) on a 10 x 20 x 30 box
static bool exportBoxObj(const char* path)
{
  std::remove(path);
  TopoDS_Shape             box = centredBox(10, 20, 30);
  BRepMesh_IncrementalMesh mesher(box, 0.1);
  mesher.Perform();
  Handle(TDocStd_Application) app;
  Handle(TDocStd_Document)    doc       = newDoc(app);
  Handle(XCAFDoc_ShapeTool)   shapeTool = XCAFDoc_DocumentTool::ShapeTool(doc->Main());
  shapeTool->AddShape(box);
  NCollection_Sequence<TDF_Label> rootLabels;
  TDF_LabelSequence               freeShapes;
  shapeTool->GetFreeShapes(freeShapes);
  for (int i = 1; i <= freeShapes.Length(); ++i)
    rootLabels.Append(freeShapes.Value(i));
  RWObj_CafWriter                                                              writer(path);
  NCollection_IndexedDataMap<TCollection_AsciiString, TCollection_AsciiString> fileInfo;
  const bool ok = writer.Perform(doc, rootLabels, nullptr, fileInfo, Message_ProgressRange());
  app->Close(doc);
  return ok;
}

// AssemblyNode.shape (OCCTDocumentGetShapeWithLocation) for a label: the shape a reference points at, or the label's own
static bool nodeHasShape(const Handle(XCAFDoc_ShapeTool)& st, const TDF_Label& l)
{
  TopoDS_Shape s;
  if (st->IsReference(l))
  {
    TDF_Label referred;
    if (st->GetReferredShape(l, referred))
      s = st->GetShape(referred);
  }
  else
  {
    s = st->GetShape(l);
  }
  return !s.IsNull();
}

// Document.allShapes(): rootNodes are the free shapes, children are the components, recursively
static int collectShapes(const Handle(XCAFDoc_ShapeTool)& st, const TDF_Label& l)
{
  int n = nodeHasShape(st, l) ? 1 : 0;
  TDF_LabelSequence components;
  st->GetComponents(l, components);
  for (int i = 1; i <= components.Length(); i++)
    n += collectShapes(st, components.Value(i));
  return n;
}

struct Loaded
{
  Handle(TDocStd_Application) app;
  Handle(TDocStd_Document)    doc;
  Handle(XCAFDoc_ShapeTool)   shapeTool;
  bool                        ok = false;
};

// mode 0: OCCTDocumentLoadOBJ, 1: OCCTDocumentLoadOBJWithOptions(singlePrecision true, unit 0), 2: OCCTDocumentLoadOBJWithCS(zUp, yUp, units 0)
static void loadObj(Loaded& L, const char* path, int mode)
{
  L.doc       = newDoc(L.app);
  L.shapeTool = XCAFDoc_DocumentTool::ShapeTool(L.doc->Main());
  RWObj_CafReader reader;
  reader.SetDocument(L.doc);
  if (mode == 1)
    reader.SetSinglePrecision(true);
  if (mode == 2)
  {
    reader.SetFileCoordinateSystem(static_cast<RWMesh_CoordinateSystem>(0));
    reader.SetSystemCoordinateSystem(static_cast<RWMesh_CoordinateSystem>(1));
  }
  L.ok = reader.Perform(TCollection_AsciiString(path), Message_ProgressRange());
}

static void report(const char* tag, Loaded& L)
{
  TDF_LabelSequence roots;
  L.shapeTool->GetFreeShapes(roots);
  int shapes = 0;
  for (int i = 1; i <= roots.Length(); i++)
    shapes += collectShapes(L.shapeTool, roots.Value(i));
  printf("%s: RWObj_CafReader::Perform=%s (the bridge returns a document exactly when this is true) free shapes=%d allShapes count=%d has shapes=%s\n",
         tag, tf(L.ok), roots.Length(), shapes, tf(shapes > 0));
}

int main()
{
  {
    const char* p  = "/tmp/766-xcaf-obj-ocaf-evidence-a.obj";
    const bool  ex = exportBoxObj(p);
    printf("[load OBJ] Shape.writeOBJ of the box: RWObj_CafWriter::Perform=%s file exists=%s\n", tf(ex), tf(fileExists(p)));
    Loaded L;
    loadObj(L, p, 0);
    report("[load OBJ] Document.loadOBJ(from:)", L);
  }
  {
    const char* p  = "/tmp/766-xcaf-obj-ocaf-evidence-b.obj";
    const bool  ex = exportBoxObj(p);
    printf("[load OBJ single precision] Shape.writeOBJ of the box: Perform=%s file exists=%s\n", tf(ex), tf(fileExists(p)));
    Loaded L;
    loadObj(L, p, 1);
    report("[load OBJ single precision] Document.loadOBJ(from:singlePrecision: true)", L);
  }
  {
    const char* src = "/tmp/766-xcaf-obj-ocaf-evidence-c-src.obj";
    const char* out = "/tmp/766-xcaf-obj-ocaf-evidence-c-out.obj";
    const bool  ex  = exportBoxObj(src);
    printf("[write OBJ] Shape.writeOBJ of the box: Perform=%s file exists=%s\n", tf(ex), tf(fileExists(src)));
    Loaded L;
    loadObj(L, src, 0);
    report("[write OBJ] Document.loadOBJ(fromPath:)", L);
    std::remove(out);
    // OCCTDocumentWriteOBJ(doc, path, 1.0): re-mesh each free shape at 1.0, then RWObj_CafWriter on the document
    TDF_LabelSequence freeShapes;
    L.shapeTool->GetFreeShapes(freeShapes);
    for (int i = 1; i <= freeShapes.Length(); i++)
    {
      TopoDS_Shape s = L.shapeTool->GetShape(freeShapes.Value(i));
      if (!s.IsNull())
      {
        BRepMesh_IncrementalMesh mesher(s, 1.0);
        mesher.Perform();
      }
    }
    RWObj_CafWriter                                                              writer(out);
    NCollection_IndexedDataMap<TCollection_AsciiString, TCollection_AsciiString> fileInfo;
    const bool                                                                   wok = writer.Perform(L.doc, fileInfo, Message_ProgressRange());
    printf("[write OBJ] Document.writeOBJ(to:): RWObj_CafWriter::Perform=%s output file exists=%s\n", tf(wok), tf(fileExists(out)));
  }
  {
    const char* p  = "/tmp/766-xcaf-obj-ocaf-evidence-d.obj";
    const bool  ex = exportBoxObj(p);
    printf("[load OBJ with coordinate system] Shape.writeOBJ of the box: Perform=%s file exists=%s\n", tf(ex), tf(fileExists(p)));
    Loaded L;
    loadObj(L, p, 2);
    printf("[load OBJ with coordinate system] MeshCoordinateSystem .zUp = 0 and .yUp = 1 cast to RWMesh_CoordinateSystem: Zup=%d Yup=%d\n",
           (int)RWMesh_CoordinateSystem_Zup, (int)RWMesh_CoordinateSystem_Yup);
    report("[load OBJ with coordinate system] Document.loadOBJ(from:inputCS: .zUp, outputCS: .yUp)", L);
  }
  return 0;
}
