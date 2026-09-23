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

#include <TNaming_Builder.hxx>
#include <TNaming_NamedShape.hxx>
#include <TNaming_Tool.hxx>
#include <TNaming_Iterator.hxx>
#include <TNaming_Selector.hxx>
#include <TNaming_CopyShape.hxx>
#include <TNaming_Translator.hxx>
#include <TNaming_Naming.hxx>
#include <TNaming_Scope.hxx>
#include <TNaming_NewShapeIterator.hxx>
#include <TNaming_OldShapeIterator.hxx>
#include <TNaming_SameShapeIterator.hxx>
#include <TNaming_OldShapeIterator.hxx>
#include <TNaming_UsedShapes.hxx>
#include <BRepPrimAPI_MakeSphere.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <BRepBuilderAPI_Copy.hxx>
#include <TopExp_Explorer.hxx>
#include <TopTools_DataMapOfShapeShape.hxx>

// TNaming* tests: TNaming_Builder records, TNaming_Tool / iterators, TNaming_Selector, CopyShape,
// Translator, Naming, Scope and the forward / backward tracing walks.
int main()
{
  Handle(TDocStd_Application) app;
  Handle(TDocStd_Document)    d = newDoc(app);
  d->SetUndoLimit(10);
  d->OpenCommand();
  TopoDS_Shape box = centredBox(10, 10, 10);
  TDF_Label    l1  = d->Main().NewChild();
  { TNaming_Builder b(l1); b.Generated(box); }
  Handle(TNaming_NamedShape) ns;
  l1.FindAttribute(TNaming_NamedShape::GetID(), ns);
  printf("primitive: evolution=%d (PRIMITIVE=%d) IsEmpty=%s current same as box=%s stored same=%s version=%d\n", (int)ns->Evolution(),
         (int)TNaming_PRIMITIVE, tf(ns->IsEmpty()), tf(TNaming_Tool::CurrentShape(ns).IsSame(box)), tf(ns->Get().IsSame(box)),
         ns->Version());
  int h = 0;
  bool hasOld = false, hasNew = false;
  for (TNaming_Iterator it(ns); it.More(); it.Next(), h++)
  {
    hasOld = !it.OldShape().IsNull();
    hasNew = !it.NewShape().IsNull();
  }
  printf("primitive history entries=%d hasOld=%s hasNew=%s\n", h, tf(hasOld), tf(hasNew));
  printf("fresh label NamedShape=%s\n", tf(d->Main().NewChild().IsAttribute(TNaming_NamedShape::GetID())));
  ns->SetVersion(42);
  printf("SetVersion(42) -> %d\n", ns->Version());
  printf("HasLabel(box)=%s FindLabel IsEqual l1=%s ValidUntil=%d\n", tf(TNaming_Tool::HasLabel(d->Main(), box)),
         tf(TNaming_Tool::Label(d->Main(), box, *(new int(0))).IsEqual(l1)), TNaming_Tool::ValidUntil(d->Main(), box));
  TopoDS_Shape bigger = centredBox(20, 20, 20);
  TDF_Label    lm     = d->Main().NewChild();
  { TNaming_Builder b(lm); b.Generated(box); }
  { TNaming_Builder b(lm); b.Modify(box, bigger); }
  Handle(TNaming_NamedShape) nm;
  lm.FindAttribute(TNaming_NamedShape::GetID(), nm);
  printf("modify: evolution=%d (MODIFY=%d) OriginalShape same as box=%s\n", (int)nm->Evolution(), (int)TNaming_MODIFY,
         tf(TNaming_Tool::OriginalShape(nm).IsSame(box)));
  TDF_Label ld = d->Main().NewChild();
  { TNaming_Builder b(ld); b.Delete(centredBox(3, 3, 3)); }
  Handle(TNaming_NamedShape) nd;
  ld.FindAttribute(TNaming_NamedShape::GetID(), nd);
  printf("delete: evolution=%d (DELETE=%d)\n", (int)nd->Evolution(), (int)TNaming_DELETE);
  TopoDS_Shape sphere = BRepPrimAPI_MakeSphere(5).Shape();
  TDF_Label    lg     = d->Main().NewChild();
  { TNaming_Builder b(lg); b.Generated(box, sphere); }
  Handle(TNaming_NamedShape) ng;
  lg.FindAttribute(TNaming_NamedShape::GetID(), ng);
  int gh = 0;
  bool gOld = false, gNew = false;
  for (TNaming_Iterator it(ng); it.More(); it.Next(), gh++)
  {
    gOld = !it.OldShape().IsNull();
    gNew = !it.NewShape().IsNull();
  }
  printf("generated(box -> sphere): evolution=%d (GENERATED=%d) entries=%d hasOld=%s hasNew=%s\n", (int)ng->Evolution(),
         (int)TNaming_GENERATED, gh, tf(gOld), tf(gNew));
  int fwd = 0;
  bool fwdHasSource = false;
  for (TNaming_NewShapeIterator it(box, d->Main()); it.More(); it.Next(), fwd++)
    fwdHasSource = fwdHasSource || it.Shape().IsSame(box);
  int bwd = 0;
  bool bwdHasGenerated = false;
  for (TNaming_OldShapeIterator it(sphere, d->Main()); it.More(); it.Next(), bwd++)
    bwdHasGenerated = bwdHasGenerated || it.Shape().IsSame(sphere);
  // An unrelated shape is not in the document's used-shape table at all (the iterator's lookup
  // throws), so the walk has nothing to start from.
  TopoDS_Shape cyl       = BRepPrimAPI_MakeCylinder(1, 1).Shape();
  int          unrelated = 0;
  if (TNaming_Tool::HasLabel(d->Main(), cyl))
    for (TNaming_NewShapeIterator it(cyl, d->Main()); it.More(); it.Next())
      unrelated++;
  printf("trace: forward from box=%d (includes source=%s) backward from sphere=%d (includes itself=%s) unrelated=%d\n", fwd,
         tf(fwdHasSource), bwd, tf(bwdHasGenerated), unrelated);
  int same = 0;
  for (TNaming_SameShapeIterator it(box, d->Main()); it.More(); it.Next())
    same++;
  printf("SameShapeIterator(box) labels=%d\n", same);
  NCollection_IndexedDataMap<Handle(Standard_Transient), Handle(Standard_Transient)> map;
  TopoDS_Shape                 copy;
  TNaming_CopyShape::CopyTool(box, map, copy);
  printf("CopyShape: non-null=%s IsSame(box)=%s\n", tf(!copy.IsNull()), tf(copy.IsSame(box)));
  TNaming_Translator tr;
  tr.Add(box);
  tr.Perform();
  printf("Translator: IsDone=%s copy IsSame(box)=%s\n", tf(tr.IsDone()), tf(tr.Copied(box).IsSame(box)));
  TopoDS_Shape face;
  for (TopExp_Explorer e(box, TopAbs_FACE); e.More(); e.Next())
  {
    face = e.Current();
    break;
  }
  TDF_Label        sel = d->Main().NewChild();
  TNaming_Selector s(sel);
  bool             ok = s.Select(face, box);
  NCollection_Map<TDF_Label> valid;
  bool             solved = s.Solve(valid);
  TopoDS_Shape     res    = TNaming_Tool::CurrentShape(s.NamedShape());
  int              nf     = 0;
  for (TopExp_Explorer e(res, TopAbs_FACE); e.More(); e.Next())
    nf++;
  printf("Selector: Select(face, box)=%s Solve=%s resolved null=%s type=%d faces=%d evolution=%d (SELECTED=%d)\n", tf(ok), tf(solved),
         tf(res.IsNull()), res.IsNull() ? -1 : (int)res.ShapeType(), nf, (int)s.NamedShape()->Evolution(), (int)TNaming_SELECTED);
  TDF_Label nl = d->Main().NewChild();
  Handle(TNaming_Naming) nmg = TNaming_Naming::Insert(nl);
  printf("Naming::Insert non-null=%s IsDefined=%s\n", tf(!nmg.IsNull()), tf(nmg->IsDefined()));
  TNaming_Scope sc(true);
  TDF_Label     v1 = d->Main().NewChild(), v2 = d->Main().NewChild();
  sc.Valid(v1);
  printf("Scope: Valid(v1) IsValid=%s", tf(sc.IsValid(v1)));
  sc.Valid(v2);
  printf(" count=%d", sc.GetValid().Extent());
  sc.Unvalid(v1);
  printf(" Unvalid(v1) IsValid=%s", tf(sc.IsValid(v1)));
  sc.ClearValid();
  printf(" after ClearValid count=%d\n", sc.GetValid().Extent());
  d->CommitCommand();
  return 0;
}
