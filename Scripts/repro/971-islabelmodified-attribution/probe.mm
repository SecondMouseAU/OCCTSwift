// Ground truth for #971: does OCCTDocumentIsLabelModified's mechanism go through the
// TDocStd_Modified attribute on the root label, or through some other document-owned map?
//
// The bridge calls TDocStd_Document::GetModified().Contains(label). #971 claims that is
// "a different mechanism from the root-label TDocStd_Modified attribute". This probe
// measures the claim from outside the kernel: mark a label through the document API, then
// read it back through the TDocStd_Modified attribute API and through the raw attribute
// found on the root label. If all three agree, and the same TDocStd_Modified instance
// backs GetModified()'s returned map, there is one mechanism, not two.
//
// Build (from the repo root, after `ln -s <main checkout>/Libraries Libraries`):
//   clang++ -std=c++17 -ObjC++ -w \
//     -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
//     -L"Libraries/OCCT.xcframework/macos-arm64" \
//     -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
//     Scripts/repro/971-islabelmodified-attribution/probe.mm -o /tmp/occt_971_probe
#include <TDF_Label.hxx>
#include <TDF_TagSource.hxx>
#include <TDocStd_Application.hxx>
#include <TDocStd_Document.hxx>
#include <TDocStd_Modified.hxx>
#include <Standard_DomainError.hxx>
#include <iostream>

int main()
{
  occ::handle<TDocStd_Application> app = new TDocStd_Application();
  occ::handle<TDocStd_Document>    doc;
  app->NewDocument("BinXCAF", doc);

  TDF_Label mainLabel = doc->Main();
  TDF_Label child     = TDF_TagSource::NewChild(mainLabel);

  // 1. Before any SetModified: the root carries no TDocStd_Modified attribute yet.
  std::cout << "before SetModified:\n";
  try
  {
    const NCollection_Map<TDF_Label>& m = doc->GetModified();
    std::cout << "  doc->GetModified().Extent()          = " << m.Extent() << "\n";
  }
  catch (const Standard_DomainError& f)
  {
    std::cout << "  doc->GetModified() threw             : Standard_DomainError: "
              << f.GetMessageString() << "\n";
  }
  occ::handle<TDocStd_Modified> attrBefore;
  std::cout << "  root has TDocStd_Modified attribute  : "
            << (mainLabel.Root().FindAttribute(TDocStd_Modified::GetID(), attrBefore) ? "yes"
                                                                                      : "no")
            << "\n";
  std::cout << "  TDocStd_Modified::Contains(child)    = "
            << (TDocStd_Modified::Contains(child) ? "true" : "false") << "\n";

  // 2. Mark it through the document API that OCCTDocumentSetModified uses.
  doc->SetModified(child);

  std::cout << "after doc->SetModified(child):\n";
  occ::handle<TDocStd_Modified> attrAfter;
  const bool found = mainLabel.Root().FindAttribute(TDocStd_Modified::GetID(), attrAfter);
  std::cout << "  root has TDocStd_Modified attribute  : " << (found ? "yes" : "no") << "\n";

  const NCollection_Map<TDF_Label>& viaDoc  = doc->GetModified();
  const NCollection_Map<TDF_Label>& viaAttr = attrAfter->Get();
  std::cout << "  doc->GetModified().Contains(child)   = "
            << (viaDoc.Contains(child) ? "true" : "false") << "\n";
  std::cout << "  attr->Get().Contains(child)          = "
            << (viaAttr.Contains(child) ? "true" : "false") << "\n";
  std::cout << "  TDocStd_Modified::Contains(child)    = "
            << (TDocStd_Modified::Contains(child) ? "true" : "false") << "\n";
  std::cout << "  &doc->GetModified() == &attr->Get()  = "
            << ((&viaDoc == &viaAttr) ? "true (one map, one mechanism)" : "false (distinct maps)")
            << "\n";

  // 3. Clear through the document API and re-read both ways.
  doc->PurgeModified();
  std::cout << "after doc->PurgeModified():\n";
  std::cout << "  doc->GetModified().Contains(child)   = "
            << (doc->GetModified().Contains(child) ? "true" : "false") << "\n";
  std::cout << "  attr->Get().Contains(child)          = "
            << (attrAfter->Get().Contains(child) ? "true" : "false") << "\n";

  // 4. Mark through the attribute API; the document API must see it.
  TDocStd_Modified::Add(child);
  std::cout << "after TDocStd_Modified::Add(child):\n";
  std::cout << "  doc->GetModified().Contains(child)   = "
            << (doc->GetModified().Contains(child) ? "true" : "false") << "\n";
  return 0;
}
