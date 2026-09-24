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

#include <TFunction_DriverTable.hxx>
#include <TFunction_Function.hxx>
#include <TFunction_GraphNode.hxx>
#include <TFunction_IFunction.hxx>
#include <TFunction_Logbook.hxx>
#include <TFunction_Scope.hxx>
#include <TDataStd_Tick.hxx>
#include <TDataStd_UAttribute.hxx>
#include <TDataStd_Variable.hxx>
#include <TObj_Application.hxx>
#include <Prs3d_TextAspect.hxx>
#include <Graphic3d_ArrayOfPoints.hxx>
#include <Bnd_Box.hxx>
#include <Standard_GUID.hxx>

// TextLabelAndPointCloudTests, TFunction* tests, TickTests, TObjApplicationTests, UAttributeTests,
// VariableTests: the OCCT objects the bridge builds and reads.
int main()
{
  Handle(Prs3d_TextAspect) ta = new Prs3d_TextAspect();
  printf("Prs3d_TextAspect default height=%g", ta->Height());
  ta->SetHeight(30);
  printf(" after SetHeight(30)=%g\n", ta->Height());
  Handle(Graphic3d_ArrayOfPoints) pts = new Graphic3d_ArrayOfPoints(3);
  pts->AddVertex(gp_Pnt(-1, 0, 2));
  pts->AddVertex(gp_Pnt(4, 5, 0));
  pts->AddVertex(gp_Pnt(0, 2, 6));
  Bnd_Box bb;
  for (int i = 1; i <= pts->VertexNumber(); i++)
    bb.Add(pts->Vertice(i));
  double x0, y0, z0, x1, y1, z1;
  bb.Get(x0, y0, z0, x1, y1, z1);
  printf("point cloud of 3: count=%d bounds x[%g, %g] y[%g, %g]\n", pts->VertexNumber(), x0, x1, y0, y1);

  printf("TFunction_DriverTable::HasDriver(unknown)=%s\n",
         tf(TFunction_DriverTable::Get()->HasDriver(Standard_GUID("aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"))));
  Handle(TDocStd_Application) app;
  Handle(TDocStd_Document)    d = newDoc(app);
  TDF_Label                   fl = d->Main().NewChild();
  Handle(TFunction_Function)  f = TFunction_Function::Set(fl);
  printf("Function: fresh Failed=%s", tf(f->Failed()));
  f->SetFailure(1);
  printf(" after SetFailure(1) Failed=%s GetFailure=%d\n", tf(f->Failed()), f->GetFailure());
  TDF_Label gl = d->Main().NewChild();
  Handle(TFunction_GraphNode) gn = TFunction_GraphNode::Set(gl);
  gn->SetStatus(TFunction_ES_NotExecuted);
  printf("GraphNode: NotExecuted=%d", (int)gn->GetStatus());
  gn->SetStatus(TFunction_ES_Succeeded);
  printf(" Succeeded=%d", (int)gn->GetStatus());
  printf(" AddNext(2)=%s AddPrevious(1)=%s RemoveAllNext ok\n", tf(gn->AddNext(2)), tf(gn->AddPrevious(1)));
  gn->RemoveAllNext();
  TFunction_Scope::Set(d->Main());
  Handle(TFunction_Scope) sc = TFunction_Scope::Set(d->Main());
  TDF_Label s1 = d->Main().NewChild(), s2 = d->Main().NewChild();
  printf("Scope: AddFunction=%s HasFunction=%s", tf(sc->AddFunction(s1)), tf(sc->HasFunction(s1)));
  sc->AddFunction(s2);
  printf(" count=%d", sc->GetFunctions().Extent());
  printf(" RemoveFunction=%s HasFunction after=%s", tf(sc->RemoveFunction(s1)), tf(sc->HasFunction(s1)));
  sc->RemoveAllFunctions();
  printf(" after RemoveAll count=%d FreeID=%d\n", sc->GetFunctions().Extent(), sc->GetFreeID());
  Handle(TFunction_Logbook) lb = TFunction_Logbook::Set(d->Main().NewChild());
  TDF_Label t1 = d->Main().NewChild(), t2 = d->Main().NewChild();
  printf("Logbook: fresh IsEmpty=%s", tf(lb->IsEmpty()));
  lb->SetTouched(t1);
  printf(" after SetTouched IsEmpty=%s IsModified(t1)=%s IsModified(t2)=%s", tf(lb->IsEmpty()), tf(lb->IsModified(t1)),
         tf(lb->IsModified(t2)));
  lb->Clear();
  printf(" after Clear IsEmpty=%s\n", tf(lb->IsEmpty()));
  TDF_Label tk = tagLabel(d, 500);
  printf("Tick: before=%s", tf(tk.IsAttribute(TDataStd_Tick::GetID())));
  TDataStd_Tick::Set(tk);
  printf(" after Set=%s", tf(tk.IsAttribute(TDataStd_Tick::GetID())));
  tk.ForgetAttribute(TDataStd_Tick::GetID());
  printf(" after Forget=%s\n", tf(tk.IsAttribute(TDataStd_Tick::GetID())));
  const Standard_GUID g1("12345678-1234-1234-1234-123456789012"), g2("11111111-2222-3333-4444-555555555555");
  TDataStd_UAttribute::Set(tagLabel(d, 300), g1);
  Handle(TDataStd_UAttribute) ua;
  printf("UAttribute: has g1=%s has g2=%s\n", tf(tagLabel(d, 300).FindAttribute(g1, ua)), tf(tagLabel(d, 300).FindAttribute(g2, ua)));
  Handle(TDataStd_Variable) var = TDataStd_Variable::Set(tagLabel(d, 1));
  var->Name("velocity");
  var->Set(42.5);
  var->Unit("m/s");
  var->Constant(true);
  printf("Variable: name=%s valued=%s value=%g unit=%s constant=%s", TCollection_AsciiString(var->Name()).ToCString(),
         tf(var->IsValued()), var->Get(), var->Unit().ToCString(), tf(var->IsConstant()));
  var->Constant(false);
  printf("->%s", tf(var->IsConstant()));
  var->Assign();
  printf(" assigned=%s", tf(var->IsAssigned()));
  var->Desassign();
  printf("->%s\n", tf(var->IsAssigned()));
  Handle(TObj_Application) to = TObj_Application::GetInstance();
  printf("TObj_Application::GetInstance null=%s\n", tf(to.IsNull()));
  return 0;
}
