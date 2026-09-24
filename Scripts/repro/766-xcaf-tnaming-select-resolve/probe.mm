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
#include <TNaming_Naming.hxx>
#include <TNaming_Selector.hxx>
#include <TNaming_Tool.hxx>
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepBuilderAPI_MakeWire.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <TDF_Tool.hxx>
#include <NCollection_Map.hxx>

// Supplement to 766-xcaf-tnaming for TNamingNamingTests and TNamingSelectResolveTests. The shared
// probe selected a face OF the box with one selector object and read Solve from that same object,
// which is not what the tests or the bridge do. Here:
//  - selectSubShape / selectedEvolution select the UNRELATED planar rectangle face
//    (Wire.rectangle(10, 10) -> Shape.face(from:)) within the box, with a selector built on the label,
//    as OCCTDocumentNamingSelect does (no command is open: the tests never open one with an undo limit);
//  - resolveShape selects a real face of the box with one selector, then resolves with a NEW
//    TNaming_Selector on the same label and Solve(empty map), as OCCTDocumentNamingResolve does;
//  - insertNaming / namingIsDefined: TNaming_Naming::Insert, then IsDefined on the attribute.
// The bridge's evolution codes are OCCTNamingPrimitive 0, Generated 1, Modify 2, Delete 3,
// Selected 4, mapped by a switch from the kernel enum, whose SELECTED is 5.
static const char* evoName(TNaming_Evolution e)
{
  switch (e)
  {
    case TNaming_PRIMITIVE: return "PRIMITIVE";
    case TNaming_GENERATED: return "GENERATED";
    case TNaming_MODIFY: return "MODIFY";
    case TNaming_DELETE: return "DELETE";
    case TNaming_REPLACE: return "REPLACE";
    case TNaming_SELECTED: return "SELECTED";
  }
  return "?";
}

static TopoDS_Shape rectangleFace(double w, double h)
{
  double hw = w / 2, hh = h / 2;
  gp_Pnt p1(-hw, -hh, 0), p2(hw, -hh, 0), p3(hw, hh, 0), p4(-hw, hh, 0);
  BRepBuilderAPI_MakeWire mw;
  mw.Add(BRepBuilderAPI_MakeEdge(p1, p2));
  mw.Add(BRepBuilderAPI_MakeEdge(p2, p3));
  mw.Add(BRepBuilderAPI_MakeEdge(p3, p4));
  mw.Add(BRepBuilderAPI_MakeEdge(p4, p1));
  BRepBuilderAPI_MakeFace mf(mw.Wire(), true);
  return mf.Face();
}

int main()
{
  {
    // insertNaming, namingIsDefined
    Handle(TDocStd_Application) app;
    Handle(TDocStd_Document)    d    = newDoc(app);
    TDF_Label                   node = d->Main().NewChild();
    Handle(TNaming_Naming)      naming = TNaming_Naming::Insert(node);
    Handle(TNaming_Naming)      found;
    bool                        has = node.FindAttribute(TNaming_Naming::GetID(), found);
    TCollection_AsciiString nodeEntry, namingEntry;
    TDF_Tool::Entry(node, nodeEntry);
    if (!naming.IsNull())
      TDF_Tool::Entry(naming->Label(), namingEntry);
    printf("insertNaming: Insert non-null=%s, inserted attribute lives on %s (the label passed in is %s); a FindAttribute on the "
           "label passed in finds it=%s; namingIsDefined: IsDefined of the inserted attribute=%s, and the bridge's lookup result "
           "(false when not found)=%s\n",
           tf(!naming.IsNull()), namingEntry.ToCString(), nodeEntry.ToCString(), tf(has), tf(!naming.IsNull() && naming->IsDefined()),
           tf(has && found->IsDefined()));
  }
  {
    // selectSubShape and selectedEvolution: the unrelated rectangle face, selected within the box.
    Handle(TDocStd_Application) app;
    Handle(TDocStd_Document)    d      = newDoc(app);
    TopoDS_Shape                box    = centredBox(10, 10, 10);
    TDF_Label                   l1     = d->Main().NewChild();
    {
      TNaming_Builder b(l1);
      b.Generated(box);
    }
    TopoDS_Shape rect      = rectangleFace(10, 10);
    TDF_Label    selectLbl = d->Main().NewChild();
    bool         ok        = false;
    {
      TNaming_Selector selector(selectLbl);
      ok = selector.Select(rect, box);
    }
    Handle(TNaming_NamedShape) ns;
    bool                       hasNs = selectLbl.FindAttribute(TNaming_NamedShape::GetID(), ns);
    printf("selectSubShape: rectangle face non-null=%s, Select(rectangle face, box)=%s; selectedEvolution: NamedShape present=%s "
           "evolution=%s (kernel ordinal %d)\n",
           tf(!rect.IsNull()), tf(ok), tf(hasNs), hasNs ? evoName(ns->Evolution()) : "-", hasNs ? (int)ns->Evolution() : -1);
  }
  {
    // resolveShape: a real face of the box, resolved through a fresh selector as the bridge does.
    Handle(TDocStd_Application) app;
    Handle(TDocStd_Document)    d   = newDoc(app);
    TopoDS_Shape                box = centredBox(10, 10, 10);
    TDF_Label                   l1  = d->Main().NewChild();
    {
      TNaming_Builder b(l1);
      b.Generated(box);
    }
    TopoDS_Shape face;
    for (TopExp_Explorer e(box, TopAbs_FACE); e.More(); e.Next())
    {
      face = e.Current();
      break;
    }
    TDF_Label selectLbl = d->Main().NewChild();
    bool      ok        = false;
    bool      sameSolve = false;
    {
      TNaming_Selector selector(selectLbl);
      ok = selector.Select(face, box);
      NCollection_Map<TDF_Label> valid;
      sameSolve = selector.Solve(valid);
    }
    // A new selector on the same label, as OCCTDocumentNamingResolve builds.
    TNaming_Selector           resolver(selectLbl);
    NCollection_Map<TDF_Label> valid2;
    bool                       solved = resolver.Solve(valid2);
    Handle(TNaming_NamedShape) ns     = resolver.NamedShape();
    bool                       nsOk   = !ns.IsNull() && !ns->IsEmpty();
    TopoDS_Shape               cur    = nsOk ? TNaming_Tool::CurrentShape(ns) : TopoDS_Shape();
    int                        nf     = 0;
    for (TopExp_Explorer e(cur, TopAbs_FACE); e.More(); e.Next())
      nf++;
    printf("resolveShape: Select(box face, box)=%s; same selector Solve=%s; NEW selector Solve=%s NamedShape non-empty=%s "
           "CurrentShape null=%s type=%d faces=%d\n",
           tf(ok), tf(sameSolve), tf(solved), tf(nsOk), tf(cur.IsNull()), cur.IsNull() ? -1 : (int)cur.ShapeType(), nf);
  }
  return 0;
}
