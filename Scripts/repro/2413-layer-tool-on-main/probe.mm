// Ground truth for #2413: what does XCAFDoc_LayerTool::Set(Main()) enumerate, and what does
// XCAFDoc_DocumentTool::LayerTool(Main()) enumerate, on the same document?
//
// OCCTDocumentGetLayerCount / OCCTDocumentGetLayerName used the first, while
// OCCTDocumentSetLayer and its five neighbours use the second. XCAFDoc_DocumentTool::LayerTool(L)
// is literally XCAFDoc_LayerTool::Set(LayersLabel(L)) (XCAFDoc_DocumentTool.cxx:259-262), so the
// two differ only in which label the tool attaches to: Main() itself (0:1) versus the Layers
// label (0:1:3). XCAFDoc_LayerTool::GetLayerLabels iterates the children of its own label and
// keeps those for which IsLayer() holds (XCAFDoc_LayerTool.cxx:182-194), and IsLayer is
// GetLayer, which accepts any child carrying a TDataStd_Name. On Main() the children are the
// XCAF tool labels, all of them named.
//
// The document is built exactly as occtDocumentInit does it (OCCTBridge_Internal.h:241).
//
// Build: see the ground-truth-probe skill; link against the resolved pinned xcframework.

#include <BRepPrimAPI_MakeBox.hxx>
#include <TDF_Label.hxx>
#include <TDF_Tool.hxx>
#include <TDataStd_Name.hxx>
#include <TDocStd_Application.hxx>
#include <TDocStd_Document.hxx>
#include <TCollection_AsciiString.hxx>
#include <TCollection_ExtendedString.hxx>
#include <XCAFApp_Application.hxx>
#include <XCAFDoc_ColorTool.hxx>
#include <XCAFDoc_DocumentTool.hxx>
#include <XCAFDoc_LayerTool.hxx>
#include <XCAFDoc_ShapeTool.hxx>
#include <XCAFDoc_VisMaterialTool.hxx>

#include <cstdio>

static TCollection_AsciiString entryOf(const TDF_Label& label)
{
  TCollection_AsciiString entry;
  TDF_Tool::Entry(label, entry);
  return entry;
}

static void dump(const char* what, const Handle(XCAFDoc_LayerTool) & tool)
{
  NCollection_Sequence<TDF_Label> labels;
  tool->GetLayerLabels(labels);
  printf("%s\n  tool label %s, %d layer(s)\n",
         what,
         entryOf(tool->BaseLabel()).ToCString(),
         labels.Length());
  for (int i = 1; i <= labels.Length(); ++i)
  {
    TCollection_ExtendedString name;
    tool->GetLayer(labels.Value(i), name);
    TCollection_AsciiString ascii(name);
    printf("    [%d] %s length=%d name=\"%s\"\n",
           i - 1,
           entryOf(labels.Value(i)).ToCString(),
           ascii.Length(),
           ascii.ToCString());
  }
}

int main()
{
  Handle(TDocStd_Application) app = XCAFApp_Application::GetApplication();
  Handle(TDocStd_Document)    doc;
  app->NewDocument("MDTV-XCAF", doc);
  // occtDocumentInit's three eager tools, and nothing else.
  Handle(XCAFDoc_ShapeTool) shapeTool = XCAFDoc_DocumentTool::ShapeTool(doc->Main());
  XCAFDoc_DocumentTool::ColorTool(doc->Main());
  XCAFDoc_DocumentTool::VisMaterialTool(doc->Main());

  printf("Main() = %s\n\n", entryOf(doc->Main()).ToCString());

  // Taken first, before anything has forced the remaining tool labels into existence, so the
  // count is order-dependent: only Shapes, Colors and VisMaterials exist at this point.
  printf("=== fresh document, read side taken first ===\n");
  dump("XCAFDoc_LayerTool::Set(Main())  [what the READ side used]",
       XCAFDoc_LayerTool::Set(doc->Main()));

  printf("\nLayersLabel(Main()) = %s\n\n",
         entryOf(XCAFDoc_DocumentTool::LayersLabel(doc->Main())).ToCString());

  printf("=== fresh document, after the other tool labels exist ===\n");
  dump("XCAFDoc_LayerTool::Set(Main())  [what the READ side used]",
       XCAFDoc_LayerTool::Set(doc->Main()));
  dump("XCAFDoc_DocumentTool::LayerTool(Main())  [what the WRITE side uses]",
       XCAFDoc_DocumentTool::LayerTool(doc->Main()));

  // Write one real layer through the same tool OCCTDocumentSetLayer uses.
  TopoDS_Shape box   = BRepPrimAPI_MakeBox(10.0, 10.0, 10.0).Shape();
  TDF_Label    shape = shapeTool->AddShape(box, false);
  XCAFDoc_DocumentTool::LayerTool(doc->Main())
    ->SetLayer(shape, TCollection_ExtendedString("Sheet Metal"));

  printf("\n=== after SetLayer(box, \"Sheet Metal\") through DocumentTool::LayerTool ===\n");
  dump("XCAFDoc_LayerTool::Set(Main())  [what the READ side used]",
       XCAFDoc_LayerTool::Set(doc->Main()));
  dump("XCAFDoc_DocumentTool::LayerTool(Main())  [what the WRITE side uses]",
       XCAFDoc_DocumentTool::LayerTool(doc->Main()));

  return 0;
}
