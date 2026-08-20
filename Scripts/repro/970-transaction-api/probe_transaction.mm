// Ground truth for #970: what TDocStd_Document / TDF_Data actually report for a
// transaction number, and where a transaction name can live.
//
// Build (from the repo root):
//   clang++ -std=c++17 -ObjC++ -w \
//     -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
//     -L"Libraries/OCCT.xcframework/macos-arm64" \
//     -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
//     Scripts/repro/970-transaction-api/probe_transaction.mm -o /tmp/occt_970_probe
#include <TDocStd_Document.hxx>
#include <TDF_Data.hxx>
#include <TDF_Delta.hxx>
#include <TDF_Transaction.hxx>
#include <TDataStd_Integer.hxx>
#include <Standard_Failure.hxx>
#include <iostream>

static void row(const char* what, const occ::handle<TDocStd_Document>& d)
{
  std::cout << what << " | HasOpenCommand=" << (d->HasOpenCommand() ? 1 : 0)
            << " | bridgeFlagExpr=" << (d->HasOpenCommand() ? 1 : 0)
            << " | Data->Transaction()=" << d->GetData()->Transaction()
            << " | Data->Time()=" << d->GetData()->Time() << " | undoLimit=" << d->GetUndoLimit()
            << " | undos=" << d->GetAvailableUndos() << std::endl;
}

int main()
{
  {
    std::cout << "--- A: default undo limit (0) ---" << std::endl;
    occ::handle<TDocStd_Document> d = new TDocStd_Document("BinOcaf");
    row("fresh                ", d);
    d->OpenCommand();
    row("after OpenCommand    ", d);
    d->CommitCommand();
    row("after CommitCommand  ", d);
  }

  {
    std::cout << "--- B: undo limit 10, flat ---" << std::endl;
    occ::handle<TDocStd_Document> d = new TDocStd_Document("BinOcaf");
    d->SetUndoLimit(10);
    row("fresh                ", d);
    d->OpenCommand();
    row("after OpenCommand    ", d);
    TDataStd_Integer::Set(d->Main().NewChild(), 42);
    d->CommitCommand();
    row("after CommitCommand  ", d);
    d->NewCommand();
    row("after NewCommand     ", d);
    d->AbortCommand();
    row("after AbortCommand   ", d);
  }

  {
    std::cout << "--- C: undo limit 10, nested transaction mode ---" << std::endl;
    occ::handle<TDocStd_Document> d = new TDocStd_Document("BinOcaf");
    d->SetUndoLimit(10);
    d->SetNestedTransactionMode(true);
    row("fresh nested         ", d);
    d->OpenCommand();
    row("open #1              ", d);
    d->OpenCommand();
    row("open #2 (nested)     ", d);
    d->OpenCommand();
    row("open #3 (nested)     ", d);
    d->CommitCommand();
    row("commit (1 of 3)      ", d);
    d->CommitCommand();
    row("commit (2 of 3)      ", d);
    d->CommitCommand();
    row("commit (3 of 3)      ", d);
  }

  {
    std::cout << "--- D: a second OpenCommand without nested mode ---" << std::endl;
    occ::handle<TDocStd_Document> d = new TDocStd_Document("BinOcaf");
    d->SetUndoLimit(10);
    d->OpenCommand();
    row("open #1              ", d);
    try
    {
      d->OpenCommand();
      row("open #2 (no throw)   ", d);
    }
    catch (const Standard_Failure& f)
    {
      std::cout << "open #2 threw: " << f.GetMessageString() << std::endl;
      row("after the throw      ", d);
    }
  }

  {
    std::cout << "--- E: raw TDF_Transaction stack on the document's own TDF_Data ---" << std::endl;
    occ::handle<TDocStd_Document> d = new TDocStd_Document("BinOcaf");
    d->SetUndoLimit(10);
    d->OpenCommand();
    row("doc open             ", d);
    TDF_Transaction t1(d->GetData(), "outer");
    std::cout << "t1.Open() -> " << t1.Open() << " name='" << t1.Name()
              << "' Data->Transaction()=" << d->GetData()->Transaction()
              << " HasOpenCommand=" << (d->HasOpenCommand() ? 1 : 0) << std::endl;
    TDF_Transaction t2(d->GetData(), "inner");
    std::cout << "t2.Open() -> " << t2.Open() << " name='" << t2.Name()
              << "' Data->Transaction()=" << d->GetData()->Transaction()
              << " HasOpenCommand=" << (d->HasOpenCommand() ? 1 : 0) << std::endl;
    t2.Abort();
    t1.Abort();
    row("after aborting t2,t1 ", d);
  }

  {
    std::cout << "--- F: where a transaction name can live ---" << std::endl;
    occ::handle<TDocStd_Document> d = new TDocStd_Document("BinOcaf");
    d->SetUndoLimit(10);
    d->OpenCommand();
    TDataStd_Integer::Set(d->Main().NewChild(), 7);
    d->CommitCommand();
    if (!d->GetUndos().IsEmpty())
    {
      occ::handle<TDF_Delta> last = d->GetUndos().Last();
      std::cout << "delta name before SetName = '" << last->Name() << "'" << std::endl;
      last->SetName("add part");
      std::cout << "delta name after  SetName = '" << last->Name() << "'" << std::endl;
      std::cout << "delta BeginTime=" << last->BeginTime() << " EndTime=" << last->EndTime()
                << " Data->Time()=" << d->GetData()->Time() << std::endl;
    }
  }

  {
    std::cout << "--- G: does Data->Time() advance per committed transaction? ---" << std::endl;
    occ::handle<TDocStd_Document> d = new TDocStd_Document("BinOcaf");
    d->SetUndoLimit(10);
    for (int i = 0; i < 4; ++i)
    {
      std::cout << "before open #" << i << " Time()=" << d->GetData()->Time()
                << " Transaction()=" << d->GetData()->Transaction() << std::endl;
      d->OpenCommand();
      TDataStd_Integer::Set(d->Main().NewChild(), i);
      d->CommitCommand();
    }
    std::cout << "after 4 commits Time()=" << d->GetData()->Time()
              << " undos=" << d->GetAvailableUndos() << std::endl;
    d->Undo();
    std::cout << "after Undo      Time()=" << d->GetData()->Time()
              << " undos=" << d->GetAvailableUndos() << " redos=" << d->GetAvailableRedos()
              << std::endl;
    d->Redo();
    std::cout << "after Redo      Time()=" << d->GetData()->Time()
              << " undos=" << d->GetAvailableUndos() << " redos=" << d->GetAvailableRedos()
              << std::endl;
    std::cout << "--- H: empty transaction (nothing changed) ---" << std::endl;
    int t = d->GetData()->Time();
    d->OpenCommand();
    bool ok = d->CommitCommand();
    std::cout << "empty commit returned " << ok << " Time() " << t << " -> "
              << d->GetData()->Time() << " undos=" << d->GetAvailableUndos() << std::endl;
  }

  {
    std::cout << "--- I: what OCCTDocumentCommitWithDelta actually does ---" << std::endl;
    occ::handle<TDocStd_Document> d = new TDocStd_Document("BinOcaf");
    d->SetUndoLimit(10);
    d->OpenCommand();
    TDataStd_Integer::Set(d->Main().NewChild(), 7);
    std::cout << "before: HasOpenCommand=" << (d->HasOpenCommand() ? 1 : 0)
              << " undos=" << d->GetAvailableUndos() << std::endl;
    // The bridge's own first statement, verbatim.
    d->SetUndoLimit(100);
    std::cout << "after SetUndoLimit(100): HasOpenCommand=" << (d->HasOpenCommand() ? 1 : 0)
              << " undos=" << d->GetAvailableUndos() << std::endl;
    bool ok = d->CommitCommand();
    std::cout << "CommitCommand() -> " << ok << " undos=" << d->GetAvailableUndos()
              << "   (the bridge returns nullptr when this is false)" << std::endl;
  }

  {
    std::cout << "--- J: does a delta name survive undo and redo? ---" << std::endl;
    occ::handle<TDocStd_Document> d = new TDocStd_Document("BinOcaf");
    d->SetUndoLimit(10);
    d->OpenCommand();
    TDataStd_Integer::Set(d->Main().NewChild(), 5);
    d->CommitCommand();
    d->GetUndos().Last()->SetName("add part");
    std::cout << "undo delta name = '" << d->GetUndos().Last()->Name() << "'" << std::endl;
    d->Undo();
    std::cout << "after Undo, redo delta name = '" << d->GetRedos().First()->Name() << "'"
              << std::endl;
    d->Redo();
    std::cout << "after Redo, undo delta name = '" << d->GetUndos().Last()->Name() << "'"
              << std::endl;
  }

  return 0;
}
