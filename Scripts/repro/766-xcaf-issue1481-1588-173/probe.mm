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

#include <XCAFDoc_DimTolTool.hxx>
#include <XCAFDoc_Dimension.hxx>
#include <TObj_Application.hxx>
#include <STEPCAFControl_Writer.hxx>
#include <STEPCAFControl_Reader.hxx>
#include <Interface_Static.hxx>
#include <fstream>
#include <sstream>

// Issue1481DimensionRefCountTests: SetDimension(shape, dim) vs SetDimension(seq, seq, dim).
// Issue1588TObjApplicationReleaseTests: TObj_Application::GetInstance verbose flag and document.
// Issue173AssemblySTEP: one part instanced N times under an assembly, written with STEPCAFControl.
static int count(const std::string& text, const char* what)
{
  int n = 0;
  for (size_t p = text.find(what); p != std::string::npos; p = text.find(what, p + 1))
    n++;
  return n;
}

int main()
{
  {
    Handle(TDocStd_Application) app;
    Handle(TDocStd_Document)    d = newDoc(app);
    Handle(XCAFDoc_DimTolTool)  t = XCAFDoc_DocumentTool::DimTolTool(d->Main());
    TDF_Label s1 = XCAFDoc_DocumentTool::ShapeTool(d->Main())->AddShape(centredBox(10, 10, 10), false);
    TDF_Label s2 = XCAFDoc_DocumentTool::ShapeTool(d->Main())->AddShape(centredBox(20, 20, 20), false);
    TDF_Label d1 = t->AddDimension();
    t->SetDimension(s1, d1);
    TDF_Label d2 = t->AddDimension();
    TDF_LabelSequence seq;
    seq.Append(s2);
    t->SetDimension(seq, seq, d2);
    TDF_LabelSequence r1, r2;
    t->GetRefDimensionLabels(s1, r1);
    t->GetRefDimensionLabels(s2, r2);
    printf("#1481: SetDimension(shape, dim) refs=%d; SetDimension(seq, seq, dim) refs=%d\n", r1.Length(), r2.Length());
  }
  {
    Handle(TObj_Application) a = TObj_Application::GetInstance();
    a->SetVerbose(true);
    printf("#1588: GetInstance null=%s verbose after SetVerbose(true)=%s", tf(a.IsNull()), tf(a->IsVerbose()));
    a->SetVerbose(false);
    printf(", after false=%s", tf(a->IsVerbose()));
    Handle(TDocStd_Document) doc;
    a->NewDocument("TObjBin", doc);
    printf(", NewDocument(\"TObjBin\") null=%s, same instance on second GetInstance=%s\n", tf(doc.IsNull()),
           tf(TObj_Application::GetInstance() == a));
  }
  const int ns[2] = {20, 8};
  for (int n : ns)
  {
    Handle(TDocStd_Application) app;
    Handle(TDocStd_Document)    d  = newDoc(app);
    Handle(XCAFDoc_ShapeTool)   st = XCAFDoc_DocumentTool::ShapeTool(d->Main());
    TDF_Label part = st->AddShape(centredBox(10, 10, 10), false);
    TDF_Label asmL = st->NewShape();
    for (int i = 0; i < n; i++)
    {
      gp_Trsf tr;
      tr.SetTranslation(gp_Vec(i * 20.0, 0, 0));
      st->AddComponent(asmL, part, TopLoc_Location(tr));
    }
    st->UpdateAssemblies();
    const std::string path = "/tmp/766-xcaf-issue173-" + std::to_string(n) + ".step";
    STEPCAFControl_Writer w;
    w.Transfer(d, STEPControl_AsIs);
    w.Write(path.c_str());
    std::ifstream in(path);
    std::stringstream ss;
    ss << in.rdbuf();
    const std::string text = ss.str();
    printf("#173 n=%d: MANIFOLD_SOLID_BREP=%d NEXT_ASSEMBLY_USAGE_OCCURRENCE=%d", n, count(text, "MANIFOLD_SOLID_BREP"),
           count(text, "NEXT_ASSEMBLY_USAGE_OCCURRENCE"));
    Handle(TDocStd_Application) app2;
    Handle(TDocStd_Document)    back = newDoc(app2);
    STEPCAFControl_Reader       r;
    r.ReadFile(path.c_str());
    r.Transfer(back);
    TDF_LabelSequence roots;
    XCAFDoc_DocumentTool::ShapeTool(back->Main())->GetFreeShapes(roots);
    int maxChildren = 0;
    for (int i = 1; i <= roots.Length(); i++)
    {
      TDF_LabelSequence comps;
      XCAFDoc_ShapeTool::GetComponents(roots.Value(i), comps);
      maxChildren = std::max(maxChildren, comps.Length());
    }
    printf("; read back max components under a root=%d\n", maxChildren);
  }
  return 0;
}
