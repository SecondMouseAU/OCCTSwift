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

#include <XCAFPrs_Style.hxx>
#include <XCAFDoc_VisMaterialCommon.hxx>
#include <XCAFDoc_VisMaterialPBR.hxx>
#include <XCAFDoc_AssemblyGraph.hxx>
#include <XCAFDoc_AssemblyItemId.hxx>
#include <XCAFDoc_AssemblyItemRef.hxx>
#include <XCAFDoc_AssemblyIterator.hxx>
#include <XCAFDoc_ClippingPlaneTool.hxx>
#include <XCAFDoc_Color.hxx>
#include <XCAFDoc_DimTol.hxx>
#include <XCAFDoc_GraphNode.hxx>
#include <XCAFDoc_Location.hxx>
#include <XCAFDoc_Material.hxx>
#include <XCAFDoc_NotesTool.hxx>
#include <XCAFDoc_NoteComment.hxx>
#include <XCAFDoc_NoteBalloon.hxx>
#include <XCAFDoc_NoteBinData.hxx>
#include <XCAFDoc_ShapeMapTool.hxx>
#include <XCAFNoteObjects_NoteObject.hxx>
#include <XCAFView_Object.hxx>
#include <TColStd_HArray1OfReal.hxx>
#include <TColStd_HArray1OfByte.hxx>
#include <TCollection_HAsciiString.hxx>
#include <TCollection_HExtendedString.hxx>
#include <TopExp_Explorer.hxx>
#include <gp_Pln.hxx>

// VisMaterial*, XCAFPrsStyle, XCAFComponentMatrix and XCAFDoc* / XCAFNoteObjects / XCAFView tests.
static TCollection_AsciiString a(const TCollection_ExtendedString& s) { return TCollection_AsciiString(s); }

int main()
{
  XCAFPrs_Style empty;
  printf("Style: default IsEmpty=%s", tf(empty.IsEmpty()));
  XCAFPrs_Style s1;
  s1.SetColorSurf(Quantity_ColorRGBA(Quantity_Color(0, 0, 1, Quantity_TOC_RGB), 1.0f));
  printf(" surf IsEmpty=%s", tf(s1.IsEmpty()));
  XCAFPrs_Style inv = s1, vis = s1;
  inv.SetVisibility(false);
  printf(" visible vs invisible IsEqual=%s", tf(inv.IsEqual(vis)));
  XCAFPrs_Style c1, c2, c3;
  c1.SetColorCurv(Quantity_Color(0, 1, 0, Quantity_TOC_RGB));
  c2.SetColorCurv(Quantity_Color(0, 1, 0, Quantity_TOC_RGB));
  c3.SetColorCurv(Quantity_Color(1, 0, 0, Quantity_TOC_RGB));
  printf(" curve-only IsEmpty=%s same=%s different=%s\n", tf(c1.IsEmpty()), tf(c1.IsEqual(c2)), tf(c1.IsEqual(c3)));

  XCAFDoc_VisMaterialCommon cm;
  printf("VisMaterialCommon default: IsDefined=%s diffuse.r=%g", tf(cm.IsDefined), cm.DiffuseColor.Red());
  XCAFDoc_VisMaterialCommon cmA = cm, cmB = cm;
  cmA.Shininess = 0.5f;
  cmB.Shininess = 0.6f;
  printf(" shininess 0.5 vs 0.6 IsEqual=%s, same IsEqual=%s\n", tf(cmA.IsEqual(cmB)), tf(cmA.IsEqual(cmA)));
  XCAFDoc_VisMaterialPBR pbr;
  printf("VisMaterialPBR default: IsDefined=%s metallic=%g roughness=%g refraction=%g", tf(pbr.IsDefined), pbr.Metallic, pbr.Roughness,
         pbr.RefractionIndex);
  XCAFDoc_VisMaterialPBR pA = pbr, pB = pbr;
  pA.Roughness = 0.5f;
  pB.Roughness = 0.6f;
  printf(" roughness 0.5 vs 0.6 IsEqual=%s\n", tf(pA.IsEqual(pB)));

  XCAFDoc_AssemblyItemId id("0:1:1:1/0:1:1:2");
  printf("AssemblyItemId(\"0:1:1:1/0:1:1:2\"): IsNull=%s path=%d; empty IsNull=%s; equal=%s unequal=%s\n", tf(id.IsNull()),
         id.GetPath().Length(), tf(XCAFDoc_AssemblyItemId().IsNull()), tf(id.IsEqual(XCAFDoc_AssemblyItemId("0:1:1:1/0:1:1:2"))),
         tf(id.IsEqual(XCAFDoc_AssemblyItemId("0:1:1:1/0:1:1:3"))));

  Handle(TDocStd_Application) app;
  Handle(TDocStd_Document)    d  = newDoc(app);
  Handle(XCAFDoc_ShapeTool)   st = XCAFDoc_DocumentTool::ShapeTool(d->Main());
  TDF_Label part = st->AddShape(centredBox(5, 5, 5), false);
  TDF_Label sub  = st->NewShape();
  st->AddComponent(sub, part, TopLoc_Location());
  TDF_Label top = st->NewShape();
  st->AddComponent(top, sub, TopLoc_Location());
  st->UpdateAssemblies();
  Handle(XCAFDoc_AssemblyGraph) g = new XCAFDoc_AssemblyGraph(d);
  printf("AssemblyGraph (part in sub in top): nodes=%d links=%d roots=%d types:", g->NbNodes(), g->NbLinks(), g->GetRoots().Extent());
  for (int i = 1; i <= g->NbNodes(); i++)
    printf(" %d", (int)g->GetNodeType(i));
  printf(" (AssemblyRoot=%d Subassembly=%d Occurrence=%d Part=%d)\n", (int)XCAFDoc_AssemblyGraph::NodeType_AssemblyRoot,
         (int)XCAFDoc_AssemblyGraph::NodeType_Subassembly, (int)XCAFDoc_AssemblyGraph::NodeType_Occurrence,
         (int)XCAFDoc_AssemblyGraph::NodeType_Part);
  int items = 0;
  for (XCAFDoc_AssemblyIterator it(d); it.More(); it.Next())
    items++;
  printf("AssemblyIterator items=%d\n", items);
  gp_Trsf rot;
  rot.SetRotation(gp_Ax1(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), M_PI / 2);
  TDF_Label asm2 = st->NewShape();
  st->AddComponent(asm2, part, TopLoc_Location(rot));
  gp_Trsf refl;
  refl.SetMirror(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(1, 0, 0)));
  TDF_Label c2l = st->AddComponent(asm2, part, TopLoc_Location(refl));
  printf("component with a reflection location: added=%s components=%d\n", tf(!c2l.IsNull()), XCAFDoc_ShapeTool::NbComponents(asm2));

  TDF_Label ir = d->Main().NewChild();
  Handle(XCAFDoc_AssemblyItemRef) ref = XCAFDoc_AssemblyItemRef::Set(ir, XCAFDoc_AssemblyItemId("0:1:1:1"));
  printf("AssemblyItemRef: path=%s", ref->GetItem().ToString().ToCString());
  ref->SetSubshapeIndex(3);
  printf(" HasExtra=%s subshape=%d", tf(ref->HasExtraRef()), ref->GetSubshapeIndex());
  ref->ClearExtraRef();
  printf(" after ClearExtraRef HasExtra=%s IsOrphan=%s\n", tf(ref->HasExtraRef()), tf(ref->IsOrphan()));

  Handle(XCAFDoc_ClippingPlaneTool) cpt = XCAFDoc_DocumentTool::ClippingPlaneTool(d->Main());
  TDF_Label cp = cpt->AddClippingPlane(gp_Pln(gp_Pnt(0, 0, 5), gp_Dir(0, 0, 1)), TCollection_ExtendedString("clip"), true);
  gp_Pln pl;
  TCollection_ExtendedString nm;
  bool cap = false;
  cpt->GetClippingPlane(cp, pl, nm, cap);
  printf("ClippingPlane: IsClippingPlane=%s origin.z=%g normal.z=%g capping=%s", tf(cpt->IsClippingPlane(cp)), pl.Location().Z(),
         pl.Axis().Direction().Z(), tf(cap));
  printf(" Remove=%s\n", tf(cpt->RemoveClippingPlane(cp)));

  TDF_Label cl = d->Main().NewChild();
  Handle(XCAFDoc_Color) col = XCAFDoc_Color::Set(cl, Quantity_Color(1, 0, 0, Quantity_TOC_RGB));
  printf("XCAFDoc_Color: rgb=(%g, %g, %g) alpha=%g NOC=%d", col->GetColor().Red(), col->GetColor().Green(), col->GetColor().Blue(),
         col->GetAlpha(), (int)col->GetNOC());
  XCAFDoc_Color::Set(cl, Quantity_ColorRGBA(Quantity_Color(0.5, 0.6, 0.7, Quantity_TOC_RGB), 0.8f));
  printf("; RGBA alpha=%g\n", col->GetAlpha());

  TDF_Label dl = d->Main().NewChild();
  Handle(TColStd_HArray1OfReal) vals = new TColStd_HArray1OfReal(1, 2);
  vals->SetValue(1, 0.01);
  vals->SetValue(2, 0.05);
  Handle(XCAFDoc_DimTol) dt = XCAFDoc_DimTol::Set(dl, 1, vals, new TCollection_HAsciiString("Flatness"),
                                                   new TCollection_HAsciiString("Surface flatness tolerance"));
  printf("DimTol: kind=%d name=%s desc=%s values=%d (%g, %g)\n", dt->GetKind(), dt->GetName()->ToCString(),
         dt->GetDescription()->ToCString(), dt->GetVal()->Length(), dt->GetVal()->Value(1), dt->GetVal()->Value(2));

  TDF_Label g1 = d->Main().NewChild(), g2 = d->Main().NewChild();
  Handle(XCAFDoc_GraphNode) n1 = XCAFDoc_GraphNode::Set(g1), n2 = XCAFDoc_GraphNode::Set(g2);
  n1->SetChild(n2);
  n2->SetFather(n1);
  printf("GraphNode: children=%d fathers=%d IsFather=%s IsChild=%s", n1->NbChildren(), n2->NbFathers(), tf(n1->IsFather(n2)),
         tf(n1->IsChild(n2)));
  n1->UnSetChild(n2);
  n2->UnSetFather(n1);
  printf(" after UnSet children=%d fathers=%d\n", n1->NbChildren(), n2->NbFathers());

  TDF_Label ll = d->Main().NewChild();
  gp_Trsf   t;
  t.SetTranslation(gp_Vec(10, 20, 30));
  XCAFDoc_Location::Set(ll, TopLoc_Location(t));
  Handle(XCAFDoc_Location) loc;
  ll.FindAttribute(XCAFDoc_Location::GetID(), loc);
  gp_XYZ tv = loc->Get().Transformation().TranslationPart();
  printf("Location: (%g, %g, %g)\n", tv.X(), tv.Y(), tv.Z());

  TDF_Label ml = d->Main().NewChild();
  Handle(XCAFDoc_Material) mat = XCAFDoc_Material::Set(ml, new TCollection_HAsciiString("Steel"), new TCollection_HAsciiString("Carbon steel"),
                                                       7850.0, new TCollection_HAsciiString("density"), new TCollection_HAsciiString("POSITIVE_RATIO_MEASURE"));
  printf("Material: name=%s desc=%s density=%g\n", mat->GetName()->ToCString(), mat->GetDescription()->ToCString(), mat->GetDensity());

  Handle(XCAFDoc_NotesTool) nt = XCAFDoc_DocumentTool::NotesTool(d->Main());
  printf("NotesTool: fresh notes=%d", nt->NbNotes());
  nt->CreateComment("TestUser", "2024", "This is a comment");
  printf(" after comment=%d", nt->NbNotes());
  nt->CreateBalloon("u", "t", "balloon");
  Handle(TColStd_HArray1OfByte) bytes = new TColStd_HArray1OfByte(1, 4);
  for (int i = 1; i <= 4; i++)
    bytes->SetValue(i, (Standard_Byte)i);
  Handle(XCAFDoc_NoteBinData) bd = Handle(XCAFDoc_NoteBinData)::DownCast(nt->CreateBinData("u", "t", "data", "application/octet-stream", bytes));
  printf(" after balloon + bindata=%d bindata size=%d orphans=%d", nt->NbNotes(), bd->Size(), nt->NbOrphanNotes());
  printf(" DeleteAllNotes=%d after=%d\n", nt->DeleteAllNotes(), nt->NbNotes());

  TDF_Label sml = d->Main().NewChild();
  Handle(XCAFDoc_ShapeMapTool) smt = XCAFDoc_ShapeMapTool::Set(sml);
  TopoDS_Shape box = centredBox(10, 10, 10);
  smt->SetShape(box);
  TopExp_Explorer fe(box, TopAbs_FACE);
  printf("ShapeMapTool: extent=%d IsSubShape(face)=%s\n", smt->GetMap().Extent(), tf(smt->IsSubShape(fe.Current())));

  Handle(XCAFNoteObjects_NoteObject) no = new XCAFNoteObjects_NoteObject();
  printf("NoteObject: fresh HasPlane=%s HasPoint=%s HasPointText=%s", tf(no->HasPlane()), tf(no->HasPoint()), tf(no->HasPointText()));
  no->SetPlane(gp_Ax2(gp_Pnt(1, 2, 3), gp_Dir(0, 0, 1)));
  no->SetPoint(gp_Pnt(10, 20, 30));
  no->SetPresentation(box);
  printf(" after set: plane.x=%g point.x=%g presentation=%s", no->GetPlane().Location().X(), no->GetPoint().X(),
         tf(!no->GetPresentation().IsNull()));
  no->Reset();
  printf(" after Reset HasPlane=%s HasPoint=%s\n", tf(no->HasPlane()), tf(no->HasPoint()));

  Handle(XCAFView_Object) v = new XCAFView_Object();
  v->SetType(XCAFView_ProjectionType_Central);
  printf("View: Central=%d", (int)v->Type());
  v->SetType(XCAFView_ProjectionType_Parallel);
  printf(" Parallel=%d NoCamera=%d", (int)v->Type(), (int)XCAFView_ProjectionType_NoCamera);
  v->SetViewDirection(gp_Dir(1, 0, 0));
  v->SetUpDirection(gp_Dir(0, 0, 1));
  v->SetWindowHorizontalSize(800);
  v->SetWindowVerticalSize(600);
  v->SetFrontPlaneDistance(1.0);
  v->SetBackPlaneDistance(1000.0);
  v->SetName(new TCollection_HAsciiString("TopView"));
  printf(" dir.x=%g up.z=%g window=%gx%g front=%s(%g) back=%s(%g)", v->ViewDirection().X(), v->UpDirection().Z(), v->WindowHorizontalSize(),
         v->WindowVerticalSize(), tf(v->HasFrontPlaneClipping()), v->FrontPlaneDistance(), tf(v->HasBackPlaneClipping()), v->BackPlaneDistance());
  v->UnsetFrontPlaneClipping();
  printf(" after UnsetFront=%s name=%s\n", tf(v->HasFrontPlaneClipping()), v->Name()->ToCString());
  return 0;
}
