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

#include <TFunction_Logbook.hxx>
#include <TFunction_Scope.hxx>
#include <TDataStd_Tick.hxx>

// Supplement to 766-xcaf-textlabel-function for TFunctionLogbookTests, TFunctionScopeTests and
// TickTests: each test's own scenario through the calls the bridge makes. The bridge sets the scope
// and the logbook through the root label (TFunction_Scope::Set(Data->Root()),
// logLabel.Root().FindAttribute(TFunction_Logbook::GetID())), and ticks on tag labels
// (Main().FindChild(tag, true)). createLabel is Main().NewChild().
int main()
{
  {
    // logbookBasic
    Handle(TDocStd_Application) app;
    Handle(TDocStd_Document)    d      = newDoc(app);
    TDF_Label                   log    = d->Main().NewChild();
    TDF_Label                   t1     = d->Main().NewChild();
    TDF_Label                   t2     = d->Main().NewChild();
    Handle(TFunction_Logbook)   lb     = TFunction_Logbook::Set(log);
    Handle(TFunction_Logbook)   onRoot;
    bool                        onRootFound = log.Root().FindAttribute(TFunction_Logbook::GetID(), onRoot);
    printf("logbookBasic: Set non-null=%s found on Root=%s fresh IsEmpty=%s", tf(!lb.IsNull()), tf(onRootFound), tf(lb->IsEmpty()));
    lb->SetTouched(t1);
    printf("; after SetTouched(t1) IsEmpty=%s IsModified(t1)=%s IsModified(t2)=%s\n", tf(lb->IsEmpty()), tf(lb->IsModified(t1)),
           tf(lb->IsModified(t2)));
  }
  {
    // logbookImpactedAndClear
    Handle(TDocStd_Application) app;
    Handle(TDocStd_Document)    d   = newDoc(app);
    TDF_Label                   log = d->Main().NewChild();
    TDF_Label                   tgt = d->Main().NewChild();
    Handle(TFunction_Logbook)   lb  = TFunction_Logbook::Set(log);
    bool                        threw = false;
    try
    {
      lb->SetImpacted(tgt);
    }
    catch (const Standard_Failure&)
    {
      threw = true;
    }
    printf("logbookImpactedAndClear: SetImpacted raised=%s IsEmpty after SetImpacted=%s", tf(threw), tf(lb->IsEmpty()));
    lb->Clear();
    printf("; after Clear IsEmpty=%s\n", tf(lb->IsEmpty()));
  }
  {
    // setFunctionScope, addAndHasFunction, removeFunction, removeAllFunctions, freeID
    Handle(TDocStd_Application) app;
    Handle(TDocStd_Document)    d     = newDoc(app);
    TDF_Label                   root  = d->GetData()->Root();
    Handle(TFunction_Scope)     scope = TFunction_Scope::Set(root);
    printf("setFunctionScope: TFunction_Scope::Set(Root) non-null=%s\n", tf(!scope.IsNull()));
    TDF_Label a = d->Main().NewChild();
    printf("addAndHasFunction: AddFunction=%s HasFunction=%s\n", tf(scope->AddFunction(a)), tf(scope->HasFunction(a)));
    printf("removeFunction: RemoveFunction=%s HasFunction after=%s\n", tf(scope->RemoveFunction(a)), tf(scope->HasFunction(a)));
    TDF_Label l1 = d->Main().NewChild(), l2 = d->Main().NewChild();
    scope->AddFunction(l1);
    scope->AddFunction(l2);
    int before = scope->GetFunctions().Extent();
    scope->RemoveAllFunctions();
    printf("removeAllFunctions: count before=%d after RemoveAllFunctions=%d\n", before, scope->GetFunctions().Extent());
  }
  {
    // freeID: a fresh scope, then one function added.
    Handle(TDocStd_Application) app;
    Handle(TDocStd_Document)    d     = newDoc(app);
    Handle(TFunction_Scope)     scope = TFunction_Scope::Set(d->GetData()->Root());
    int                         f1    = scope->GetFreeID();
    TDF_Label                   node  = d->Main().NewChild();
    scope->AddFunction(node);
    int f2 = scope->GetFreeID();
    printf("freeID: fresh GetFreeID=%d after AddFunction GetFreeID=%d (at least 1: %s; increased: %s)\n", f1, f2, tf(f1 >= 1),
           tf(f2 > f1));
  }
  {
    // TickTests: tags 500, 501 and 502 as the tests use them.
    Handle(TDocStd_Application) app;
    Handle(TDocStd_Document)    d = newDoc(app);
    Handle(TDataStd_Tick)       tk;
    TDF_Label                   l500 = tagLabel(d, 500);
    bool                        b500 = l500.FindAttribute(TDataStd_Tick::GetID(), tk);
    TDataStd_Tick::Set(l500);
    printf("setAndHas: tag 500 has Tick before=%s after Set=%s\n", tf(b500), tf(l500.FindAttribute(TDataStd_Tick::GetID(), tk)));
    TDF_Label l501 = tagLabel(d, 501);
    TDataStd_Tick::Set(l501);
    bool foundBefore = l501.FindAttribute(TDataStd_Tick::GetID(), tk);
    l501.ForgetAttribute(TDataStd_Tick::GetID());
    printf("remove: tag 501 Tick found before remove=%s, present after ForgetAttribute=%s\n", tf(foundBefore),
           tf(l501.FindAttribute(TDataStd_Tick::GetID(), tk)));
    TDF_Label l502 = tagLabel(d, 502);
    printf("removeNonExistent: tag 502 has Tick=%s\n", tf(l502.FindAttribute(TDataStd_Tick::GetID(), tk)));
  }
  return 0;
}
