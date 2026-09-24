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

#include <TDataStd_Integer.hxx>
#include <TDF_Delta.hxx>
#include <TDF_Data.hxx>

// Issue970TransactionAPITests: TDocStd_Document command numbering, and TDF_Delta naming, with the
// bridge's own pending-name bookkeeping modelled as a local string.
int main()
{
  Handle(TDocStd_Application) app;
  Handle(TDocStd_Document)    d = newDoc(app);
  printf("undo limit 0: OpenCommand -> HasOpenCommand=%s Transaction=%d\n", (d->OpenCommand(), tf(d->HasOpenCommand())),
         d->GetData()->Transaction());
  d->SetUndoLimit(10);
  printf("undo limit 10: Transaction before=%d", d->GetData()->Transaction());
  d->OpenCommand();
  printf(" after OpenCommand=%d", d->GetData()->Transaction());
  bool threw = false;
  try
  {
    d->OpenCommand();
  }
  catch (const Standard_Failure&)
  {
    threw = true;
  }
  printf(" second OpenCommand throws=%s Transaction=%d", tf(threw), d->GetData()->Transaction());
  TDataStd_Integer::Set(d->Main().NewChild(), 42);
  d->CommitCommand();
  printf(" after CommitCommand=%d undos=%d\n", d->GetData()->Transaction(), d->GetAvailableUndos());
  Handle(TDF_Delta) delta = d->GetUndos().Last();
  printf("committed delta: attribute deltas=%d begin=%d end=%d name=\"%s\"\n", delta->AttributeDeltas().Extent(),
         delta->BeginTime(), delta->EndTime(), TCollection_AsciiString(delta->Name()).ToCString());
  delta->SetName(TCollection_ExtendedString("add part"));
  printf("after SetName(\"add part\"): name=\"%s\"\n", TCollection_AsciiString(delta->Name()).ToCString());
  d->OpenCommand();
  TDataStd_Integer::Set(d->Main().NewChild(), 1);
  d->AbortCommand();
  printf("after AbortCommand: HasOpenCommand=%s undos still=%d\n", tf(d->HasOpenCommand()), d->GetAvailableUndos());
  return 0;
}
