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

#include <TDataStd_Real.hxx>
#include <TDataStd_ReferenceArray.hxx>
#include <TDataStd_ReferenceList.hxx>
#include <TDataStd_Relation.hxx>
#include <TDataStd_TreeNode.hxx>

// Kernel-parity probe for the Relation, ReferenceArray, ReferenceList and TreeNode tests (#766). Each scenario is a
// fresh document (Document.create()) and mirrors the bridge function the test calls: tag labels are
// Main().FindChild(tag, true), createLabel() is Main().NewChild() (so the first three calls return the existing
// ShapeTool, ColorTool and then a new label, 0:1:1, 0:1:2 and 0:1:3), the reference array is Set(label, 1, count)
// holding Main().FindChild(tag) labels, the tree node is TDataStd_TreeNode::Set(label) with Append through the
// default tree id, and the reads are FindAttribute then the accessor. The earlier probe in 766-xcaf-tdatastd/ built
// every attribute in one accumulated document (so its NewChild labels were not the ones the tests get), used the
// relation "a = b" where the setAndGet test uses "x + y = z", and printed no has-attribute state after a Set.
static TCollection_AsciiString entryOf(const TDF_Label& l)
{
  TCollection_AsciiString e;
  TDF_Tool::Entry(l, e);
  return e;
}

int main()
{
  {
    Handle(TDocStd_Application) app;
    Handle(TDocStd_Document)    d = newDoc(app);
    // setRelation(tag: 390, relation: "x + y = z") then relation(tag: 390)
    Handle(TDataStd_Relation) rel = TDataStd_Relation::Set(tagLabel(d, 390));
    rel->SetRelation(TCollection_ExtendedString("x + y = z", true));
    Handle(TDataStd_Relation) got;
    const bool                found = tagLabel(d, 390).FindAttribute(TDataStd_Relation::GetID(), got);
    printf("[relation set/get] tag 390: found=%s relation=\"%s\"\n", tf(found), TCollection_AsciiString(got->GetRelation()).ToCString());
  }
  {
    Handle(TDocStd_Application) app;
    Handle(TDocStd_Document)    d = newDoc(app);
    Handle(TDataStd_Relation)   a;
    const bool                  before = tagLabel(d, 391).FindAttribute(TDataStd_Relation::GetID(), a);
    Handle(TDataStd_Relation)   rel    = TDataStd_Relation::Set(tagLabel(d, 391));
    rel->SetRelation(TCollection_ExtendedString("a = b", true));
    const bool after = tagLabel(d, 391).FindAttribute(TDataStd_Relation::GetID(), a);
    printf("[relation has] tag 391: FindAttribute before Set=%s, after setRelation(\"a = b\")=%s\n", tf(before), tf(after));
  }
  {
    Handle(TDocStd_Application) app;
    Handle(TDocStd_Document)    d = newDoc(app);
    Handle(TDataStd_ReferenceArray) a;
    const bool before = tagLabel(d, 371).FindAttribute(TDataStd_ReferenceArray::GetID(), a);
    Handle(TDataStd_ReferenceArray) arr = TDataStd_ReferenceArray::Set(tagLabel(d, 371), 1, 1);
    arr->SetValue(1, d->Main().FindChild(500));
    const bool after = tagLabel(d, 371).FindAttribute(TDataStd_ReferenceArray::GetID(), a);
    printf("[reference array has] tag 371: FindAttribute before Set=%s, after setReferenceArray([500])=%s\n", tf(before), tf(after));
  }
  {
    Handle(TDocStd_Application) app;
    Handle(TDocStd_Document)    d = newDoc(app);
    Handle(TDataStd_ReferenceList) a;
    const bool before = tagLabel(d, 382).FindAttribute(TDataStd_ReferenceList::GetID(), a);
    Handle(TDataStd_ReferenceList) lst = TDataStd_ReferenceList::Set(tagLabel(d, 382));
    lst->Clear();
    lst->Append(d->Main().FindChild(500));
    const bool after = tagLabel(d, 382).FindAttribute(TDataStd_ReferenceList::GetID(), a);
    printf("[reference list has] tag 382: FindAttribute before Set=%s, after setReferenceList([500])=%s\n", tf(before), tf(after));
  }
  {
    // Create tree node: createLabel(), setTreeNode(), then treeNodeHasFather and treeNodeDepth
    Handle(TDocStd_Application) app;
    Handle(TDocStd_Document)    d = newDoc(app);
    TDF_Label                   l = d->Main().NewChild();
    Handle(TDataStd_TreeNode)   t = TDataStd_TreeNode::Set(l);
    Handle(TDataStd_TreeNode)   node;
    const bool                  found = l.FindAttribute(TDataStd_TreeNode::GetDefaultTreeID(), node);
    printf("[tree node create] label %s: Set returned a node=%s found by the default tree id=%s HasFather=%s Depth=%d\n", entryOf(l).ToCString(),
           tf(!t.IsNull()), tf(found), tf(node->HasFather()), node->Depth());
  }
  {
    // Parent-child: three createLabel() calls, three setTreeNode(), root.appendTreeChild(child1) and (child2)
    Handle(TDocStd_Application) app;
    Handle(TDocStd_Document)    d     = newDoc(app);
    TDF_Label                   root  = d->Main().NewChild();
    TDF_Label                   c1    = d->Main().NewChild();
    TDF_Label                   c2    = d->Main().NewChild();
    TDataStd_TreeNode::Set(root);
    TDataStd_TreeNode::Set(c1);
    TDataStd_TreeNode::Set(c2);
    Handle(TDataStd_TreeNode) rn, n1, n2;
    root.FindAttribute(TDataStd_TreeNode::GetDefaultTreeID(), rn);
    c1.FindAttribute(TDataStd_TreeNode::GetDefaultTreeID(), n1);
    c2.FindAttribute(TDataStd_TreeNode::GetDefaultTreeID(), n2);
    const bool a1 = rn->Append(n1);
    const bool a2 = rn->Append(n2);
    printf("[tree node parent-child] labels root=%s child1=%s child2=%s; Append(child1)=%s Append(child2)=%s\n", entryOf(root).ToCString(),
           entryOf(c1).ToCString(), entryOf(c2).ToCString(), tf(a1), tf(a2));
    const bool fatherIsRoot = n1->HasFather() && n1->Father()->Label() == root;
    const bool firstIsC1    = rn->HasFirst() && rn->First()->Label() == c1;
    const bool nextIsC2     = n1->HasNext() && n1->Next()->Label() == c2;
    printf("[tree node parent-child] child1 HasFather=%s Depth=%d root NbChildren=%d child1 father is root=%s root first is child1=%s "
           "child1 next is child2=%s child2 HasNext=%s\n",
           tf(n1->HasFather()), n1->Depth(), rn->NbChildren(), tf(fatherIsRoot), tf(firstIsC1), tf(nextIsC2), tf(n2->HasNext()));
  }
  {
    // Set and get real / change real value, on the first createLabel()
    Handle(TDocStd_Application) app;
    Handle(TDocStd_Document)    d = newDoc(app);
    TDF_Label                   l = d->Main().NewChild();
    TDataStd_Real::Set(l, 3.14);
    Handle(TDataStd_Real) r;
    l.FindAttribute(TDataStd_Real::GetID(), r);
    const double first = r->Get();
    TDataStd_Real::Set(l, 2.718);
    l.FindAttribute(TDataStd_Real::GetID(), r);
    printf("[real] label %s: after Set(3.14) Get=%g, after Set(2.718) Get=%g\n", entryOf(l).ToCString(), first, r->Get());
  }
  return 0;
}
