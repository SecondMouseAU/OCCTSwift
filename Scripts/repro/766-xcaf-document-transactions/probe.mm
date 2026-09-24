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

#include <TDataStd_Name.hxx>
#include <TDF_TagSource.hxx>

// DocumentModifiedTests, DocumentTransactionTests, DocumentUndoRedoTests: TDocStd_Document's
// command / undo API with the same sequences the tests drive. createLabel is
// Main().NewChild() (OCCTDocumentCreateLabel) and setName is TDataStd_Name::Set.
static TDF_Label named(const Handle(TDocStd_Document)& d, const char* n)
{
  TDF_Label l = d->Main().NewChild();
  TDataStd_Name::Set(l, TCollection_ExtendedString(n));
  return l;
}

static Handle(TDocStd_Document) fresh(Handle(TDocStd_Application)& app)
{
  Handle(TDocStd_Document) d = newDoc(app);
  d->SetUndoLimit(10);
  return d;
}

int main()
{
  Handle(TDocStd_Application) app;
  // --- DocumentModifiedTests
  {
    Handle(TDocStd_Document) d = fresh(app);
    d->OpenCommand();
    TDF_Label l = named(d, "Part1");
    d->CommitCommand();
    d->SetModified(l);
    printf("modified: after SetModified contains=%s\n", tf(d->GetModified().Contains(l)));
    d->PurgeModified();
    printf("modified: after PurgeModified contains=%s\n", tf(d->GetModified().Contains(l)));
  }
  // --- DocumentTransactionTests
  {
    Handle(TDocStd_Document) d = fresh(app);
    printf("txn: initial HasOpenCommand=%s\n", tf(d->HasOpenCommand()));
    d->OpenCommand();
    printf("txn: after OpenCommand=%s\n", tf(d->HasOpenCommand()));
    named(d, "InTransaction");
    bool ok = d->CommitCommand();
    printf("txn: CommitCommand=%s HasOpenCommand=%s\n", tf(ok), tf(d->HasOpenCommand()));
    d->OpenCommand();
    named(d, "WillBeAborted");
    d->AbortCommand();
    printf("txn: after AbortCommand HasOpenCommand=%s\n", tf(d->HasOpenCommand()));
  }
  // --- DocumentUndoRedoTests
  {
    Handle(TDocStd_Document) d = fresh(app);
    printf("undo: GetUndoLimit=%d undos=%d redos=%d\n", d->GetUndoLimit(), d->GetAvailableUndos(),
           d->GetAvailableRedos());
    d->OpenCommand(); named(d, "T1"); d->CommitCommand();
    printf("undo: after 1 commit undos=%d\n", d->GetAvailableUndos());
    d->OpenCommand(); named(d, "T2"); d->CommitCommand();
    printf("undo: after 2 commits undos=%d\n", d->GetAvailableUndos());
    bool u = d->Undo();
    printf("undo: Undo=%s undos=%d redos=%d\n", tf(u), d->GetAvailableUndos(), d->GetAvailableRedos());
    bool r = d->Redo();
    printf("redo: Redo=%s undos=%d redos=%d\n", tf(r), d->GetAvailableUndos(), d->GetAvailableRedos());
  }
  {
    Handle(TDocStd_Document) d = fresh(app);
    printf("undoNothing: Undo=%s\n", tf(d->Undo()));
  }
  {
    Handle(TDocStd_Document) d = fresh(app);
    for (int i = 0; i < 3; i++) { d->OpenCommand(); named(d, "L"); d->CommitCommand(); }
    printf("multi: undos=%d\n", d->GetAvailableUndos());
    d->Undo(); d->Undo(); d->Undo();
    printf("multi: after 3 Undo undos=%d redos=%d\n", d->GetAvailableUndos(), d->GetAvailableRedos());
    d->Redo(); d->Redo();
    printf("multi: after 2 Redo undos=%d redos=%d\n", d->GetAvailableUndos(), d->GetAvailableRedos());
  }
  {
    Handle(TDocStd_Document) d = fresh(app);
    d->OpenCommand(); named(d, "T1"); d->CommitCommand();
    d->OpenCommand(); named(d, "Aborted"); d->AbortCommand();
    printf("abortNoUndo: undos=%d\n", d->GetAvailableUndos());
  }
  return 0;
}
