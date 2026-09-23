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

#include <RWObj_CafReader.hxx>
#include <RWObj_CafWriter.hxx>
#include <RWMesh_CoordinateSystem.hxx>
#include <BRepMesh_IncrementalMesh.hxx>
#include <StlAPI_Writer.hxx>
#include <BinDrivers.hxx>
#include <BinLDrivers.hxx>
#include <XmlDrivers.hxx>
#include <XmlLDrivers.hxx>
#include <BinXCAFDrivers.hxx>
#include <XmlXCAFDrivers.hxx>
#include <TDataStd_Name.hxx>
#include <TDataStd_Integer.hxx>
#include <TDataStd_Real.hxx>
#include <PCDM_StoreStatus.hxx>
#include <PCDM_ReaderStatus.hxx>
#include <TColStd_SequenceOfAsciiString.hxx>
#include <TColStd_IndexedDataMapOfStringString.hxx>
#include <Message_ProgressRange.hxx>
#include <fstream>

// OBJDocumentIOTests / OCAF* tests / PCDMStatusEnumTests: RWObj reader and writer on a meshed box,
// a TDocStd_Application with the standard drivers defined, save / save-in-place / open for the
// three formats, and the PCDM status enum values the Swift enums mirror.
static void writeObj(const char* path)
{
  // A triangulated box as OBJ text (8 nodes, 12 triangles), the input the tests write first.
  std::ofstream f(path);
  const double v[8][3] = {{0, 0, 0}, {10, 0, 0}, {10, 20, 0}, {0, 20, 0}, {0, 0, 30}, {10, 0, 30}, {10, 20, 30}, {0, 20, 30}};
  for (auto& p : v)
    f << "v " << p[0] << " " << p[1] << " " << p[2] << "\n";
  const int t[12][3] = {{1, 3, 2}, {1, 4, 3}, {5, 6, 7}, {5, 7, 8}, {1, 2, 6}, {1, 6, 5}, {2, 3, 7}, {2, 7, 6}, {3, 4, 8}, {3, 8, 7}, {4, 1, 5}, {4, 5, 8}};
  for (auto& tr : t)
    f << "f " << tr[0] << " " << tr[1] << " " << tr[2] << "\n";
}

int main()
{
  const char* obj = "/tmp/766-xcaf-obj-ocaf.obj";
  writeObj(obj);
  {
    Handle(TDocStd_Application) app;
    Handle(TDocStd_Document)    d = newDoc(app);
    RWObj_CafReader             r;
    r.SetDocument(d);
    bool ok = r.Perform(TCollection_AsciiString(obj), Message_ProgressRange());
    TDF_LabelSequence roots;
    XCAFDoc_DocumentTool::ShapeTool(d->Main())->GetFreeShapes(roots);
    printf("RWObj_CafReader: Perform=%s free shapes=%d\n", tf(ok), roots.Length());
    RWObj_CafWriter w(TCollection_AsciiString("/tmp/766-xcaf-obj-ocaf-out.obj"));
    TColStd_IndexedDataMapOfStringString info;
    bool wok = w.Perform(d, info, Message_ProgressRange());
    printf("RWObj_CafWriter: Perform=%s\n", tf(wok));
  }
  {
    Handle(TDocStd_Application) app = new TDocStd_Application();
    BinDrivers::DefineFormat(app);
    BinLDrivers::DefineFormat(app);
    XmlDrivers::DefineFormat(app);
    XmlLDrivers::DefineFormat(app);
    BinXCAFDrivers::DefineFormat(app);
    XmlXCAFDrivers::DefineFormat(app);
    TColStd_SequenceOfAsciiString rf, wf;
    app->ReadingFormats(rf);
    app->WritingFormats(wf);
    printf("formats after defining Bin, BinL, Xml, XmlL, BinXCAF, XmlXCAF: reading=%d writing=%d\n", rf.Length(), wf.Length());
    Handle(TDocStd_Document) doc;
    app->NewDocument("BinOcaf", doc);
    printf("NewDocument(BinOcaf): StorageFormat=%s IsSaved=%s NbDocuments=%d\n",
           TCollection_AsciiString(doc->StorageFormat()).ToCString(), tf(doc->IsSaved()), app->NbDocuments());
    doc->ChangeStorageFormat("XmlOcaf");
    printf("ChangeStorageFormat(XmlOcaf): StorageFormat=%s\n", TCollection_AsciiString(doc->StorageFormat()).ToCString());
    doc->ChangeStorageFormat("BinOcaf");
    PCDM_StoreStatus inPlace = app->Save(doc);
    printf("Save in place before any SaveAs: status=%d (ok=%d)\n", (int)inPlace, (int)PCDM_SS_OK);
    TDataStd_Name::Set(doc->Main().NewChild(), "TestBin");
    PCDM_StoreStatus s = app->SaveAs(doc, "/tmp/766-xcaf-ocaf.cbf");
    printf("SaveAs cbf: status=%d IsSaved=%s", (int)s, tf(doc->IsSaved()));
    TDataStd_Integer::Set(doc->Main().NewChild(), 100);
    printf(" then Save in place: status=%d\n", (int)app->Save(doc));
    // OCCTDocumentLoadOCAF opens with a fresh application carrying Bin, Xml, BinXCAF, XmlXCAF.
    Handle(TDocStd_Application) reader = new TDocStd_Application();
    BinDrivers::DefineFormat(reader);
    XmlDrivers::DefineFormat(reader);
    BinXCAFDrivers::DefineFormat(reader);
    XmlXCAFDrivers::DefineFormat(reader);
    Handle(TDocStd_Document) back;
    PCDM_ReaderStatus rs = reader->Open("/tmp/766-xcaf-ocaf.cbf", back);
    printf("Open cbf: status=%d loaded=%s\n", (int)rs, tf(!back.IsNull()));
    Handle(TDocStd_Document) xdoc;
    app->NewDocument("XmlOcaf", xdoc);
    TDataStd_Real::Set(xdoc->Main().NewChild(), 3.14);
    printf("SaveAs xml: status=%d", (int)app->SaveAs(xdoc, "/tmp/766-xcaf-ocaf.xml"));
    Handle(TDocStd_Document) xback;
    printf(" Open xml: status=%d\n", (int)reader->Open("/tmp/766-xcaf-ocaf.xml", xback));
    Handle(TDocStd_Document) bx;
    app->NewDocument("BinXCAF", bx);
    XCAFDoc_DocumentTool::ShapeTool(bx->Main());
    TDataStd_Name::Set(bx->Main().NewChild(), "MyBox");
    printf("NewDocument(BinXCAF): StorageFormat=%s", TCollection_AsciiString(bx->StorageFormat()).ToCString());
    printf(" SaveAs xbf: status=%d", (int)app->SaveAs(bx, "/tmp/766-xcaf-ocaf.xbf"));
    Handle(TDocStd_Document) bxback;
    printf(" Open xbf: status=%d\n", (int)reader->Open("/tmp/766-xcaf-ocaf.xbf", bxback));
    Handle(TDocStd_Document) none;
    printf("Open /nonexistent/file.cbf: status=%d loaded=%s\n", (int)reader->Open("/nonexistent/file.cbf", none), tf(!none.IsNull()));
  }
  printf("PCDM_StoreStatus: OK=%d DriverFailure=%d WriteFailure=%d Failure=%d\n", (int)PCDM_SS_OK, (int)PCDM_SS_DriverFailure,
         (int)PCDM_SS_WriteFailure, (int)PCDM_SS_Failure);
  printf("PCDM_ReaderStatus: OK=%d NoDriver=%d OpenError=%d UnrecognizedFileFormat=%d\n", (int)PCDM_RS_OK,
         (int)PCDM_RS_NoDriver, (int)PCDM_RS_OpenError, (int)PCDM_RS_UnrecognizedFileFormat);
  return 0;
}
