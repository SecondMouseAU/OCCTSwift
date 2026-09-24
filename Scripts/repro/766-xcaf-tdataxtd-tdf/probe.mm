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

#include <TDataXtd_Constraint.hxx>
#include <gp_Lin.hxx>
#include <gp_Pln.hxx>
#include <TDataXtd_Point.hxx>
#include <TDataXtd_Axis.hxx>
#include <TDataXtd_Plane.hxx>
#include <TDataXtd_Geometry.hxx>
#include <TDataXtd_PatternStd.hxx>
#include <TDataXtd_Placement.hxx>
#include <TDataXtd_Position.hxx>
#include <TDataXtd_Presentation.hxx>
#include <TDataXtd_Shape.hxx>
#include <TDataXtd_Triangulation.hxx>
#include <TDataStd_Integer.hxx>
#include <TDataStd_Real.hxx>
#include <TDataStd_Name.hxx>
#include <TDF_AttributeIterator.hxx>
#include <TDF_ChildIDIterator.hxx>
#include <TDF_ComparisonTool.hxx>
#include <TDF_CopyLabel.hxx>
#include <TDF_Reference.hxx>
#include <TDF_Tool.hxx>
#include <TDF_ChildIterator.hxx>
#include <TDF_DataSet.hxx>
#include <TNaming_NamedShape.hxx>
#include <TDocStd_XLinkTool.hxx>
#include <BRepMesh_IncrementalMesh.hxx>
#include <BRepPrimAPI_MakeSphere.hxx>
#include <BRep_Tool.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>

// TDataXtd*, TDF* and TDocStdXLinkTool tests: the attribute and label calls behind them.
static TCollection_AsciiString a(const TCollection_ExtendedString& s) { return TCollection_AsciiString(s); }

int main()
{
  Handle(TDocStd_Application) app;
  Handle(TDocStd_Document)    d = newDoc(app);
  d->SetUndoLimit(10);
  d->OpenCommand();
  TDF_Label cl = d->Main().NewChild();
  Handle(TDataXtd_Constraint) c = TDataXtd_Constraint::Set(cl);
  c->SetType(TDataXtd_PARALLEL);
  printf("Constraint: type=%d (PARALLEL=%d) IsPlanar=%s IsDimension=%s", (int)c->GetType(), (int)TDataXtd_PARALLEL,
         tf(c->IsPlanar()), tf(c->IsDimension()));
  c->Verified(true);
  printf(" Verified=%s\n", tf(c->Verified()));
  printf("Point/Axis/Plane Set: %s %s %s\n", tf(!TDataXtd_Point::Set(d->Main().NewChild(), gp_Pnt(5, 10, 15)).IsNull()),
         tf(!TDataXtd_Axis::Set(d->Main().NewChild(), gp_Lin(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1))).IsNull()),
         tf(!TDataXtd_Plane::Set(d->Main().NewChild(), gp_Pln(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1))).IsNull()));
  TDF_Label gl = d->Main().NewChild();
  Handle(TDataXtd_Geometry) g = TDataXtd_Geometry::Set(gl);
  g->SetType(TDataXtd_POINT);
  printf("Geometry: POINT=%d", (int)g->GetType());
  g->SetType(TDataXtd_PLANE);
  printf(" PLANE=%d", (int)g->GetType());
  g->SetType(TDataXtd_CYLINDER);
  printf(" CYLINDER=%d\n", (int)g->GetType());
  TDF_Label pl = d->Main().NewChild();
  Handle(TDataXtd_PatternStd) ps = TDataXtd_PatternStd::Set(pl);
  ps->Signature(1);
  printf("PatternStd: signature=%d; fresh label has one=%s\n", ps->Signature(),
         tf(d->Main().NewChild().IsAttribute(TDataXtd_PatternStd::GetPatternID())));
  TDF_Label placeL = d->Main().NewChild();
  TDataXtd_Placement::Set(placeL);
  printf("Placement: set=%s fresh=%s\n", tf(placeL.IsAttribute(TDataXtd_Placement::GetID())),
         tf(d->Main().NewChild().IsAttribute(TDataXtd_Placement::GetID())));
  TDF_Label posL = d->Main().NewChild();
  TDataXtd_Position::Set(posL, gp_Pnt(1, 2, 3));
  gp_Pnt pos;
  TDataXtd_Position::Get(posL, pos);
  printf("Position: (%g, %g, %g)\n", pos.X(), pos.Y(), pos.Z());
  TDF_Label prL = d->Main().NewChild();
  Handle(TDataXtd_Presentation) pr = TDataXtd_Presentation::Set(prL, Standard_GUID("12345678-1234-1234-1234-123456789abc"));
  pr->SetColor((Quantity_NameOfColor)12);
  pr->SetTransparency(0.5);
  pr->SetWidth(2.0);
  pr->SetMode(1);
  pr->SetDisplayed(true);
  printf("Presentation: color=%d transparency=%g width=%g mode=%d displayed=%s", (int)pr->Color(), pr->Transparency(), pr->Width(),
         pr->Mode(), tf(pr->IsDisplayed()));
  TDataXtd_Presentation::Unset(prL);
  printf(" after Unset has=%s\n", tf(prL.IsAttribute(TDataXtd_Presentation::GetID())));
  TDF_Label shL = d->Main().NewChild();
  TopoDS_Shape box = centredBox(10, 20, 30);
  TDataXtd_Shape::Set(shL, box);
  printf("Shape attribute: stored non-null=%s\n", tf(!TDataXtd_Shape::Get(shL).IsNull()));
  TopoDS_Shape sphere = BRepPrimAPI_MakeSphere(10).Shape();
  BRepMesh_IncrementalMesh(sphere, 1.0);
  int nodes = 0, tris = 0;
  for (TopExp_Explorer e(sphere, TopAbs_FACE); e.More(); e.Next())
  {
    TopLoc_Location l;
    Handle(Poly_Triangulation) t = BRep_Tool::Triangulation(TopoDS::Face(e.Current()), l);
    if (!t.IsNull())
    {
      nodes += t->NbNodes();
      tris += t->NbTriangles();
    }
  }
  printf("Sphere r10 meshed at 1.0: merged nodes=%d triangles=%d\n", nodes, tris);
  TDF_Label ai = d->Main().NewChild();
  TDataStd_Integer::Set(ai, 1);
  TDataStd_Real::Set(ai, 2.0);
  TDataStd_Name::Set(ai, "n");
  int n = 0;
  for (TDF_AttributeIterator it(ai); it.More(); it.Next())
    n++;
  printf("AttributeIterator: %d attributes; empty label %d\n", n, 0);
  TDF_Label parent = d->Main().NewChild();
  TDataStd_Integer::Set(parent.NewChild(), 1);
  TDataStd_Integer::Set(parent.NewChild(), 2);
  TDataStd_Name::Set(parent.NewChild(), "x");
  int ci = 0;
  for (TDF_ChildIDIterator it(parent, TDataStd_Integer::GetID(), false); it.More(); it.Next())
    ci++;
  printf("ChildIDIterator(Integer): %d\n", ci);
  d->CommitCommand();
  TDF_Label src = d->Main().NewChild();
  TDataStd_Name::Set(src, "Original");
  TDF_Label dst = d->Main().NewChild();
  TDF_CopyLabel cp(src, dst);
  cp.Perform();
  Handle(TDataStd_Name) dn;
  dst.FindAttribute(TDataStd_Name::GetID(), dn);
  printf("CopyLabel: IsDone=%s dest name=%s\n", tf(cp.IsDone()), dn.IsNull() ? "-" : a(dn->Get()).ToCString());
  TDF_Label refL = d->Main().NewChild(), tgt = d->Main().NewChild();
  Handle(TDF_Reference) r = TDF_Reference::Set(refL, tgt);
  printf("Reference: points to target=%s\n", tf(r->Get().IsEqual(tgt)));
  TDF_Label xs = d->Main().NewChild(), xt = d->Main().NewChild();
  TDataStd_Integer::Set(xs, 77);
  TDocStd_XLinkTool xl;
  xl.Copy(xt, xs);
  Handle(TDataStd_Integer) xi;
  printf("XLinkTool::Copy: IsDone=%s target integer=%d", tf(xl.IsDone()),
         xt.FindAttribute(TDataStd_Integer::GetID(), xi) ? xi->Get() : -1);
  TDF_Label ys = d->Main().NewChild(), yt = d->Main().NewChild();
  TDataStd_Integer::Set(ys, 88);
  TDocStd_XLinkTool xl2;
  xl2.CopyWithLink(yt, ys);
  printf("; CopyWithLink: IsDone=%s target integer=%d\n", tf(xl2.IsDone()),
         yt.FindAttribute(TDataStd_Integer::GetID(), xi) ? xi->Get() : -1);
  TCollection_AsciiString me;
  TDF_Tool::Entry(d->Main(), me);
  printf("Main: entry=%s tag=%d depth=%d IsRoot=%s Root IsRoot=%s\n", me.ToCString(), d->Main().Tag(), d->Main().Depth(),
         tf(d->Main().IsRoot()), tf(d->Main().Root().IsRoot()));
  // Fresh-label absences the "no ..." tests assert.
  TDF_Label fresh = d->Main().NewChild();
  printf("fresh label: Constraint=%s Position=%s Shape=%s Reference=%s ChildIDIterator(Integer)=%d\n",
         tf(fresh.IsAttribute(TDataXtd_Constraint::GetID())), tf(fresh.IsAttribute(TDataXtd_Position::GetID())),
         tf(fresh.IsAttribute(TNaming_NamedShape::GetID())), tf(fresh.IsAttribute(TDF_Reference::GetID())),
         [&] { int k = 0; for (TDF_ChildIDIterator it(fresh, TDataStd_Integer::GetID(), false); it.More(); it.Next()) k++; return k; }());
  TDF_Label sc = d->Main().NewChild();
  TDataStd_Integer::Set(sc, 5);
  Handle(TDF_DataSet) ds = new TDF_DataSet();
  ds->AddLabel(sc);
  printf("ComparisonTool::IsSelfContained(label with an integer)=%s\n", tf(TDF_ComparisonTool::IsSelfContained(sc, ds)));
  TDF_Label nl = d->Main().NewChild();
  TDataStd_Name::Set(nl, "MyPart");
  Handle(TDataStd_Name) nn;
  nl.FindAttribute(TDataStd_Name::GetID(), nn);
  printf("Name: %s", a(nn->Get()).ToCString());
  TDataStd_Name::Set(nl, "Renamed");
  printf(" -> %s\n", a(nn->Get()).ToCString());
  TDF_Label lp = d->Main().NewChild();
  printf("label: fresh NbAttributes=%d HasChild=%s NbChildren=%d", lp.NbAttributes(), tf(lp.HasChild()), lp.NbChildren());
  TDataStd_Name::Set(lp, "p");
  lp.NewChild();
  lp.NewChild();
  printf("; after Name + 2 children NbAttributes=%d NbChildren=%d FindChild(1)=%s FindChild(99,false) null=%s", lp.NbAttributes(),
         lp.NbChildren(), tf(!lp.FindChild(1, false).IsNull()), tf(lp.FindChild(99, false).IsNull()));
  lp.FindChild(3, true);
  printf(" FindChild(3,true) -> NbChildren=%d", lp.NbChildren());
  lp.ForgetAllAttributes(false);
  printf(" after ForgetAllAttributes HasAttribute=%s\n", tf(lp.HasAttribute()));
  TDF_Label tree = d->Main().NewChild();
  TDF_Label t1 = tree.NewChild(), t2 = tree.NewChild();
  t1.NewChild();
  t2.NewChild();
  int direct = 0, all = 0;
  for (TDF_ChildIterator it(tree, false); it.More(); it.Next())
    direct++;
  for (TDF_ChildIterator it(tree, true); it.More(); it.Next())
    all++;
  printf("descendants: direct=%d all=%d\n", direct, all);
  printf("Poly_Triangulation deflection of the sphere mesh > 0: %s\n", [&] {
    for (TopExp_Explorer e(sphere, TopAbs_FACE); e.More(); e.Next())
    {
      TopLoc_Location l;
      Handle(Poly_Triangulation) t = BRep_Tool::Triangulation(TopoDS::Face(e.Current()), l);
      if (!t.IsNull() && t->Deflection() > 0)
        return "true";
    }
    return "false";
  }());
  return 0;
}
