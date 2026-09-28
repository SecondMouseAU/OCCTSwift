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

#include <BinDrivers.hxx>
#include <BinLDrivers.hxx>
#include <BinXCAFDrivers.hxx>
#include <PCDM_ReaderStatus.hxx>
#include <PCDM_StoreStatus.hxx>
#include <TColStd_SequenceOfAsciiString.hxx>
#include <TDataStd_Integer.hxx>
#include <TDataStd_Name.hxx>
#include <TDataStd_Real.hxx>
#include <TDataXtd_Shape.hxx>
#include <TNaming_Builder.hxx>
#include <XmlDrivers.hxx>
#include <XmlLDrivers.hxx>
#include <XmlXCAFDrivers.hxx>
#include <cstdio>
#include <string>

// Kernel-parity probe for the OCAF format, save, load and PCDM status tests (#766). Each scenario mirrors what the
// bridge does for the test's calls: Document.create(format:) is OCCTDocumentCreateWithFormat (a private application
// with Bin, Xml, BinXCAF and XmlXCAF defined, NewDocument(format), and the XCAF tools when the format names XCAF),
// Document.create() is OCCTDocument() (occtDocumentInit), createLabel() is Main().NewChild(), saveOCAF is
// SaveAs, saveOCAFInPlace is the IsSaved guard then Save, loadOCAF is a fresh application with the same four
// formats and Open. The earlier probe in 766-xcaf-obj-ocaf/ defined six formats on the writing application and
// never ran a document created the way the tests create it.
struct D
{
  Handle(TDocStd_Application) app;
  Handle(TDocStd_Document)    doc;
};

static void createWithFormat(D& d, const char* format)
{
  d.app = new TDocStd_Application();
  BinDrivers::DefineFormat(d.app);
  XmlDrivers::DefineFormat(d.app);
  BinXCAFDrivers::DefineFormat(d.app);
  XmlXCAFDrivers::DefineFormat(d.app);
  d.app->NewDocument(TCollection_ExtendedString(format, true), d.doc);
  const TCollection_AsciiString ascii(format);
  if (ascii.Search("XCAF") >= 0 || ascii.Search("xcaf") >= 0)
  {
    XCAFDoc_DocumentTool::ShapeTool(d.doc->Main());
    XCAFDoc_DocumentTool::ColorTool(d.doc->Main());
    XCAFDoc_DocumentTool::VisMaterialTool(d.doc->Main());
  }
}

static int saveOcaf(D& d, const char* path)
{
  std::remove(path);
  return (int)d.app->SaveAs(d.doc, TCollection_ExtendedString(path, true));
}

// OCCTDocumentLoadOCAF: a fresh application, four formats, Open; a document comes back only for status OK
static void loadOcaf(const char* path, int& status, bool& gotDoc, std::string& storageFormat)
{
  Handle(TDocStd_Application) app = new TDocStd_Application();
  BinDrivers::DefineFormat(app);
  XmlDrivers::DefineFormat(app);
  BinXCAFDrivers::DefineFormat(app);
  XmlXCAFDrivers::DefineFormat(app);
  Handle(TDocStd_Document) loaded;
  status = (int)app->Open(TCollection_ExtendedString(path, true), loaded);
  gotDoc = status == (int)PCDM_RS_OK && !loaded.IsNull();
  storageFormat = loaded.IsNull() ? "" : TCollection_AsciiString(loaded->StorageFormat()).ToCString();
}

static void formats()
{
  Handle(TDocStd_Application) app;
  Handle(TDocStd_Document)    doc = newDoc(app);
  TColStd_SequenceOfAsciiString r0, w0;
  app->ReadingFormats(r0);
  app->WritingFormats(w0);
  printf("[formats] Document.create(), before defineAllFormats: reading=%d writing=%d\n", r0.Length(), w0.Length());
  BinDrivers::DefineFormat(app);
  BinLDrivers::DefineFormat(app);
  XmlDrivers::DefineFormat(app);
  XmlLDrivers::DefineFormat(app);
  BinXCAFDrivers::DefineFormat(app);
  XmlXCAFDrivers::DefineFormat(app);
  TColStd_SequenceOfAsciiString r, w;
  app->ReadingFormats(r);
  app->WritingFormats(w);
  printf("[formats] after defineAllFormats (Bin, BinL, Xml, XmlL, BinXCAF, XmlXCAF): reading=%d writing=%d reading >= 4=%s reading not empty=%s "
         "writing not empty=%s\n",
         r.Length(), w.Length(), tf(r.Length() >= 4), tf(r.Length() > 0), tf(w.Length() > 0));
}

static void inPlaceAfterSave()
{
  D d;
  createWithFormat(d, "BinOcaf");
  TDF_Label l = d.doc->Main().NewChild();
  TDataStd_Name::Set(l, "Initial");
  const int s1 = saveOcaf(d, "/tmp/766-xcaf-ocaf-saveload-evidence-inplace.cbf");
  TDataStd_Integer::Set(l, 100);
  const bool saved = d.doc->IsSaved();
  const int  s2    = saved ? (int)d.app->Save(d.doc) : -1;
  printf("[in place] Document.create(format: \"BinOcaf\"): SaveAs status=%d IsSaved=%s, then Save in place status=%d\n", s1, tf(saved), s2);
}

static void inPlaceWithoutSave()
{
  D d;
  createWithFormat(d, "BinOcaf");
  const bool saved = d.doc->IsSaved();
  printf("[in place, no save] Document.create(format: \"BinOcaf\"): IsSaved=%s, so the bridge guard returns -1 (Swift reads it as .failure = 3)\n", tf(saved));
  const int kernel = (int)d.app->Save(d.doc);
  printf("[in place, no save] the kernel's own Save before any SaveAs: status=%d (ok=%d) status not ok=%s\n", kernel, (int)PCDM_SS_OK,
         tf(kernel != (int)PCDM_SS_OK));
}

static void binOcaf()
{
  D d;
  createWithFormat(d, "BinOcaf");
  TDF_Label l = d.doc->Main().NewChild();
  TCollection_AsciiString entry;
  TDF_Tool::Entry(l, entry);
  TDataStd_Name::Set(l, "TestBin");
  TDataStd_Integer::Set(l, 42);
  const int  st    = saveOcaf(d, "/tmp/766-xcaf-ocaf-saveload-evidence.cbf");
  const bool saved = d.doc->IsSaved();
  int        rs;
  bool       got;
  std::string fmt;
  loadOcaf("/tmp/766-xcaf-ocaf-saveload-evidence.cbf", rs, got, fmt);
  printf("[bin ocaf] label %s: SaveAs status=%d IsSaved=%s; load: Open status=%d document returned=%s storage format=\"%s\" (present=%s)\n",
         entry.ToCString(), st, tf(saved), rs, tf(got), fmt.c_str(), tf(!fmt.empty()));
}

static void binXcaf()
{
  D d;
  createWithFormat(d, "BinXCAF");
  TopoDS_Shape box = centredBox(10, 20, 30);
  TDF_Label    l   = d.doc->Main().NewChild();
  TCollection_AsciiString entry;
  TDF_Tool::Entry(l, entry);
  TDataStd_Name::Set(l, "MyBox");
  // OCCTDocumentSetShapeAttr
  Handle(TDataXtd_Shape) attr;
  if (!l.FindAttribute(TDataXtd_Shape::GetID(), attr))
  {
    attr = new TDataXtd_Shape();
    l.AddAttribute(attr);
  }
  TNaming_Builder builder(l);
  builder.Generated(box);
  const int  st = saveOcaf(d, "/tmp/766-xcaf-ocaf-saveload-evidence.xbf");
  int        rs;
  bool       got;
  std::string fmt;
  loadOcaf("/tmp/766-xcaf-ocaf-saveload-evidence.xbf", rs, got, fmt);
  printf("[bin xcaf] label %s: SaveAs status=%d; load: Open status=%d document returned=%s storage format=\"%s\"\n", entry.ToCString(), st, rs,
         tf(got), fmt.c_str());
}

static void xmlOcaf()
{
  D d;
  createWithFormat(d, "XmlOcaf");
  TDF_Label l = d.doc->Main().NewChild();
  TCollection_AsciiString entry;
  TDF_Tool::Entry(l, entry);
  TDataStd_Name::Set(l, "TestXml");
  TDataStd_Real::Set(l, 3.14);
  const int  st = saveOcaf(d, "/tmp/766-xcaf-ocaf-saveload-evidence.xml");
  int        rs;
  bool       got;
  std::string fmt;
  loadOcaf("/tmp/766-xcaf-ocaf-saveload-evidence.xml", rs, got, fmt);
  printf("[xml ocaf] label %s: SaveAs status=%d; load: Open status=%d document returned=%s storage format=\"%s\"\n", entry.ToCString(), st, rs,
         tf(got), fmt.c_str());
}

static void statusEnums()
{
  printf("[status enums] PCDM_StoreStatus: OK=%d DriverFailure=%d WriteFailure=%d Failure=%d\n", (int)PCDM_SS_OK, (int)PCDM_SS_DriverFailure,
         (int)PCDM_SS_WriteFailure, (int)PCDM_SS_Failure);
  printf("[status enums] PCDM_ReaderStatus: OK=%d NoDriver=%d OpenError=%d UnrecognizedFileFormat=%d\n", (int)PCDM_RS_OK, (int)PCDM_RS_NoDriver,
         (int)PCDM_RS_OpenError, (int)PCDM_RS_UnrecognizedFileFormat);
}

static void nonexistent()
{
  int         rs;
  bool        got;
  std::string fmt;
  loadOcaf("/nonexistent/file.cbf", rs, got, fmt);
  printf("[nonexistent] Open /nonexistent/file.cbf: status=%d (ok=%d) document returned=%s status not ok=%s\n", rs, (int)PCDM_RS_OK, tf(got),
         tf(rs != (int)PCDM_RS_OK));
}

int main()
{
  formats();
  inPlaceAfterSave();
  inPlaceWithoutSave();
  binOcaf();
  binXcaf();
  xmlOcaf();
  statusEnums();
  nonexistent();
  return 0;
}
