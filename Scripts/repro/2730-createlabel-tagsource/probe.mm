// Ground-truth probe for #2730 (Document.createLabel() on an XCAF document returns the existing
// ShapeTool/ColorTool labels). Calls the OCCT API the bridge calls, with the candidate fix
// applied, and prints what the kernel returns. Build line: CLAUDE.md "Compile a Ground Truth C++
// Test" / the ground-truth-probe skill, headers/lib from the pinned OCCT.xcframework.
//
// Reuses the reproduction shape from Scripts/repro/766-xcaf-evidence-fix/probe.mm (branch
// exec/766-evidence-fix-xcaf, PR #2716), then goes further: measures every tag
// XCAFDoc_DocumentTool actually reserves under Main() (not just the four the issue names),
// measures that the fix (seed TDF_TagSource past that range before the first NewChild) holds
// under every call order between createLabel() and a lazy tool accessor, and measures that a
// TDF_TagSource is ordinary OCAF-persisted state, so a document round-tripped through a native
// OCAF file keeps whatever counter it left with, seed included.

#include <BinDrivers.hxx>
#include <BinXCAFDrivers.hxx>
#include <TCollection_AsciiString.hxx>
#include <TCollection_ExtendedString.hxx>
#include <TDF_AttributeIterator.hxx>
#include <TDF_ChildIterator.hxx>
#include <TDF_Label.hxx>
#include <TDF_Tool.hxx>
#include <TDF_TagSource.hxx>
#include <TDocStd_Application.hxx>
#include <TDocStd_Document.hxx>
#include <XCAFDoc_ClippingPlaneTool.hxx>
#include <XCAFDoc_ColorTool.hxx>
#include <XCAFDoc_DimTolTool.hxx>
#include <XCAFDoc_DocumentTool.hxx>
#include <XCAFDoc_LayerTool.hxx>
#include <XCAFDoc_MaterialTool.hxx>
#include <XCAFDoc_NotesTool.hxx>
#include <XCAFDoc_ShapeTool.hxx>
#include <XCAFDoc_ViewTool.hxx>
#include <XCAFDoc_VisMaterialTool.hxx>

#include <cstdio>
#include <cstdlib>
#include <string>

// The fix under test: seed Main()'s TDF_TagSource past every tag XCAFDoc_DocumentTool reserves,
// before the first NewChild(). Idempotent (never lowers an existing counter), mirrors the
// candidate change to OCCTDocumentCreateLabel in
// Sources/OCCTBridge/src/OCCTBridge_Document_DocumentLifecycle.mm.
static const int kXCAFReservedMainTag = 10; // XCAFDoc_DocumentTool::VisMaterialLabel -- measured below, not assumed

static void seedPastReserved(const TDF_Label& main)
{
  Handle(TDF_TagSource) ts = TDF_TagSource::Set(main);
  if (ts->Get() < kXCAFReservedMainTag)
    ts->Set(kXCAFReservedMainTag);
}

static std::string entryOf(const TDF_Label& l)
{
  TCollection_AsciiString e;
  TDF_Tool::Entry(l, e);
  return std::string(e.ToCString());
}

static std::string attrNames(const TDF_Label& l)
{
  std::string out;
  for (TDF_AttributeIterator it(l); it.More(); it.Next())
  {
    if (!out.empty())
      out += ", ";
    out += it.Value()->DynamicType()->Name();
  }
  return out.empty() ? "none" : out;
}

static int tagSourceGet(const TDF_Label& l)
{
  Handle(TDF_TagSource) ts;
  if (!l.FindAttribute(TDF_TagSource::GetID(), ts))
    return -1;
  return ts->Get();
}

static const char* tf(bool b) { return b ? "true" : "false"; }

// OCCTDocument()/occtDocumentInit(): a private TDocStd_Application (#371), NewDocument("MDTV-XCAF"),
// then the three XCAF tools occtDocumentInit fetches eagerly.
static Handle(TDocStd_Document) newXCAFDoc(Handle(TDocStd_Application)& app)
{
  app = new TDocStd_Application();
  Handle(TDocStd_Document) d;
  app->NewDocument("MDTV-XCAF", d);
  XCAFDoc_DocumentTool::ShapeTool(d->Main());
  XCAFDoc_DocumentTool::ColorTool(d->Main());
  XCAFDoc_DocumentTool::VisMaterialTool(d->Main());
  return d;
}

int main()
{
  // === Part 1: reproduce the bug as filed (#766's own probe, condensed) ===
  {
    Handle(TDocStd_Application) app;
    Handle(TDocStd_Document)    doc  = newXCAFDoc(app);
    TDF_Label                   main = doc->Main();

    printf("[part1 reproduce] Main=%s, children:", entryOf(main).c_str());
    for (TDF_ChildIterator it(main, false); it.More(); it.Next())
      printf(" %s [%s]", entryOf(it.Value()).c_str(), attrNames(it.Value()).c_str());
    printf("; TDF_TagSource present=%s\n", tf(tagSourceGet(main) != -1));

    for (int i = 1; i <= 4; i++)
    {
      TDF_Label l = main.NewChild();
      printf("[part1 reproduce] NewChild call %d -> entry %s, NbAttributes=%d [%s], TagSource "
             "Get()=%d\n",
             i, entryOf(l).c_str(), l.NbAttributes(), attrNames(l).c_str(), tagSourceGet(main));
    }
  }

  // === Part 2: measure every tag XCAFDoc_DocumentTool actually reserves under Main(), by
  // calling every accessor and reading back the resulting label's own Tag(), not by trusting the
  // header's doc comments. ===
  {
    Handle(TDocStd_Application) app;
    Handle(TDocStd_Document)    doc  = newXCAFDoc(app); // ShapeTool/ColorTool/VisMaterialTool already forced
    TDF_Label                   main = doc->Main();

    // Force every remaining lazy tool too, so every possible reserved tag exists as a child.
    XCAFDoc_DocumentTool::LayerTool(main);
    XCAFDoc_DocumentTool::DimTolTool(main);
    XCAFDoc_DocumentTool::MaterialTool(main);
    XCAFDoc_DocumentTool::ViewTool(main);
    XCAFDoc_DocumentTool::ClippingPlaneTool(main);
    XCAFDoc_DocumentTool::NotesTool(main);

    int maxTag = 0;
    printf("[part2 reserved-tags] Main children after forcing every XCAFDoc_DocumentTool "
           "accessor:");
    for (TDF_ChildIterator it(main, false); it.More(); it.Next())
    {
      int tag = it.Value().Tag();
      if (tag > maxTag)
        maxTag = tag;
      printf(" tag=%d[%s]", tag, attrNames(it.Value()).c_str());
    }
    printf("\n[part2 reserved-tags] highest reserved tag measured = %d (kXCAFReservedMainTag = "
           "%d, %s)\n",
           maxTag, kXCAFReservedMainTag, maxTag == kXCAFReservedMainTag ? "MATCH" : "MISMATCH");
    // TagSource is still absent: none of the tool accessors above touch it, they all go through
    // FindChild(<fixed tag>, true) directly.
    printf("[part2 reserved-tags] TDF_TagSource present after forcing every tool = %s\n",
           tf(tagSourceGet(main) != -1));
  }

  // === Part 3: the fix on a fresh document, createLabel() calls only. ===
  {
    Handle(TDocStd_Application) app;
    Handle(TDocStd_Document)    doc  = newXCAFDoc(app);
    TDF_Label                   main = doc->Main();

    seedPastReserved(main);
    printf("[part3 fix-fresh] after seed, TagSource Get()=%d\n", tagSourceGet(main));
    for (int i = 1; i <= 4; i++)
    {
      TDF_Label l = main.NewChild();
      printf("[part3 fix-fresh] NewChild call %d -> entry %s, NbAttributes=%d [%s], is a tool "
             "label=%s\n",
             i, entryOf(l).c_str(), l.NbAttributes(), attrNames(l).c_str(),
             tf(l.Tag() <= kXCAFReservedMainTag));
    }
  }

  // === Part 4: robustness to call order -- createLabel() BEFORE a lazy tool claims its tag. ===
  {
    Handle(TDocStd_Application) app;
    Handle(TDocStd_Document)    doc  = newXCAFDoc(app);
    TDF_Label                   main = doc->Main();

    seedPastReserved(main); // seeded once, before ANYTHING touches Main's children
    TDF_Label created[3];
    for (int i = 0; i < 3; i++)
      created[i] = main.NewChild();
    printf("[part4 order] createLabel x3 before any lazy tool -> entries %s %s %s\n",
           entryOf(created[0]).c_str(), entryOf(created[1]).c_str(), entryOf(created[2]).c_str());

    // Now claim every remaining lazy tool tag, in an order that has nothing to do with the
    // createLabel calls above.
    Handle(XCAFDoc_NotesTool)         notes  = XCAFDoc_DocumentTool::NotesTool(main);
    Handle(XCAFDoc_ClippingPlaneTool) clip   = XCAFDoc_DocumentTool::ClippingPlaneTool(main);
    Handle(XCAFDoc_ViewTool)          view   = XCAFDoc_DocumentTool::ViewTool(main);
    Handle(XCAFDoc_MaterialTool)      mat    = XCAFDoc_DocumentTool::MaterialTool(main);
    Handle(XCAFDoc_DimTolTool)        dimtol = XCAFDoc_DocumentTool::DimTolTool(main);
    Handle(XCAFDoc_LayerTool)         layer  = XCAFDoc_DocumentTool::LayerTool(main);

    bool anyCollision = false;
    for (int i = 0; i < 3; i++)
    {
      // A collision would mean the earlier createLabel() label picked up a tool attribute, or a
      // tool's fixed-tag label landed above the reserved range and stole a createLabel() tag.
      bool stillEmpty = created[i].NbAttributes() == 0;
      if (!stillEmpty)
        anyCollision = true;
      printf("[part4 order] createLabel label %s still empty after every lazy tool claimed its "
             "tag = %s [%s]\n",
             entryOf(created[i]).c_str(), tf(stillEmpty), attrNames(created[i]).c_str());
    }
    printf("[part4 order] any collision between createLabel() and a later-claimed tool tag = %s\n",
           tf(anyCollision));

    // And a 4th createLabel() call after the tools exist still lands above the reserved range.
    TDF_Label after = main.NewChild();
    printf("[part4 order] createLabel after every lazy tool exists -> entry %s, tag=%d "
           "(> reserved max %d = %s)\n",
           entryOf(after).c_str(), after.Tag(), kXCAFReservedMainTag,
           tf(after.Tag() > kXCAFReservedMainTag));
  }

  // === Part 5: idempotency -- seeding twice does not move an already-advanced counter, and does
  // not lower it. ===
  {
    Handle(TDocStd_Application) app;
    Handle(TDocStd_Document)    doc  = newXCAFDoc(app);
    TDF_Label                   main = doc->Main();

    seedPastReserved(main);
    int afterFirstSeed = tagSourceGet(main);
    seedPastReserved(main); // idempotent: already >= threshold
    int afterSecondSeed = tagSourceGet(main);
    printf("[part5 idempotent] Get() after 1st seed=%d, after 2nd seed=%d (%s)\n", afterFirstSeed,
           afterSecondSeed, afterFirstSeed == afterSecondSeed ? "MATCH" : "MISMATCH");

    for (int i = 0; i < 4; i++)
      main.NewChild();
    int advanced = tagSourceGet(main);
    seedPastReserved(main); // must NOT renumber -- counter is already above threshold
    int afterThirdSeed = tagSourceGet(main);
    printf("[part5 idempotent] Get() after 4 real creates=%d, after re-seeding=%d (%s, no "
           "lowering)\n",
           advanced, afterThirdSeed, advanced == afterThirdSeed ? "MATCH" : "MISMATCH");
  }

  // === Part 6: a document round-tripped through a native OCAF file keeps its TagSource counter,
  // seed included -- so seeding at the point of use (createLabel) covers a reloaded document with
  // no separate "on open" code path needed.
  //
  // Measured: OCCTDocumentSaveOCAF/OCCTDocumentLoadOCAF only work on a document whose app has
  // DefineFormat-registered drivers, i.e. one created via OCCTDocumentCreateWithFormat("BinXCAF")
  // (Document.create(format:) on the Swift side, what every existing OCAFSaveLoad*Tests suite
  // uses). A plain Document()/OCCTDocumentCreate() document (format "MDTV-XCAF") has no driver
  // registered on its app and SaveAs fails with "Could not found the resource definition" in this
  // environment (no CSF_PluginDefaults resource files ship with the xcframework) -- reproduced
  // once, then this probe switches to the format every real save/load test already uses, matching
  // OCCTDocumentCreateWithFormat's own DefineFormat + NewDocument order. ===
  {
    Handle(TDocStd_Application) app = new TDocStd_Application();
    BinDrivers::DefineFormat(app);
    BinXCAFDrivers::DefineFormat(app);
    Handle(TDocStd_Document) doc;
    app->NewDocument("BinXCAF", doc);
    XCAFDoc_DocumentTool::ShapeTool(doc->Main());
    XCAFDoc_DocumentTool::ColorTool(doc->Main());
    XCAFDoc_DocumentTool::VisMaterialTool(doc->Main());

    TDF_Label main = doc->Main();
    seedPastReserved(main);
    TDF_Label saved0 = main.NewChild();
    TDF_Label saved1 = main.NewChild();
    int       savedGet = tagSourceGet(main);
    printf("[part6 reload] before save: created %s, %s, TagSource Get()=%d\n",
           entryOf(saved0).c_str(), entryOf(saved1).c_str(), savedGet);

    const char*                path = "/tmp/occt-2730-probe.xbf";
    TCollection_ExtendedString ePath(path, true);
    PCDM_StoreStatus            storeStatus = app->SaveAs(doc, ePath);
    printf("[part6 reload] SaveAs status=%d (0=PCDM_SS_OK)\n", static_cast<int>(storeStatus));

    Handle(TDocStd_Application) app2 = new TDocStd_Application();
    BinDrivers::DefineFormat(app2);
    BinXCAFDrivers::DefineFormat(app2);
    Handle(TDocStd_Document) reloaded;
    PCDM_ReaderStatus         readStatus = app2->Open(ePath, reloaded);
    printf("[part6 reload] Open status=%d (0=PCDM_RS_OK)\n", static_cast<int>(readStatus));
    if (readStatus == PCDM_RS_OK && !reloaded.IsNull())
    {
      // occtDocumentInit-equivalent for a loaded doc (OCCTDocumentLoadOCAF's own lines).
      XCAFDoc_DocumentTool::ShapeTool(reloaded->Main());
      XCAFDoc_DocumentTool::ColorTool(reloaded->Main());
      XCAFDoc_DocumentTool::VisMaterialTool(reloaded->Main());

      int reloadedGet = tagSourceGet(reloaded->Main());
      printf("[part6 reload] after reload, TagSource Get()=%d (%s, no reseed applied yet)\n",
             reloadedGet, reloadedGet == savedGet ? "PRESERVED" : "LOST");

      // createLabel() on the reloaded doc, running through the SAME seed-at-point-of-use logic,
      // must not renumber the 2 already-saved labels and must keep issuing fresh tags above them.
      seedPastReserved(reloaded->Main());
      TDF_Label next = reloaded->Main().NewChild();
      printf("[part6 reload] createLabel() after reload -> entry %s, tag=%d (fresh, > previous "
             "max=%s)\n",
             entryOf(next).c_str(), next.Tag(), tf(next.Tag() > saved1.Tag()));
    }
  }

  return 0;
}
