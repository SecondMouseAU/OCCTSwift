// Epic #766, Tests/OCCTModelingTests/HistoryExtendedTests.swift: kernel parity for all three
// tests. Shape.History is one BRepTools_History (OCCTHistoryCreate); AddModified, AddGenerated,
// Merge, ReplaceGenerated, ReplaceModified, HasModified, HasGenerated, Modified, Generated are
// that class's members. Same inputs: three boxes of 10, 5 and 3 mm centred at the origin.
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepTools_History.hxx>
#include <cstdio>

static TopoDS_Shape box(double s) { return BRepPrimAPI_MakeBox(gp_Pnt(-s / 2, -s / 2, -s / 2), s, s, s).Shape(); }

int main()
{
  TopoDS_Shape b1 = box(10), b2 = box(5), b3 = box(3);
  {
    Handle(BRepTools_History) h1 = new BRepTools_History, h2 = new BRepTools_History;
    h1->AddModified(b1, b2);
    h2->AddGenerated(b2, b3);
    printf("mergeHistories: before merge h1 hasModified=%d hasGenerated=%d\n", h1->HasModified(),
           h1->HasGenerated());
    h1->Merge(h2);
    printf("mergeHistories: after merge hasModified=%d hasGenerated=%d generated(b1)=%d modified(b1)=%d\n",
           h1->HasModified(), h1->HasGenerated(), h1->Generated(b1).Size(), h1->Modified(b1).Size());
  }
  {
    Handle(BRepTools_History) h = new BRepTools_History;
    h->AddGenerated(b1, b2);
    h->ReplaceGenerated(b1, b3);
    const auto& g = h->Generated(b1);
    printf("replaceGeneratedModified: hasGenerated=%d generated(b1)=%d firstIsB3=%d\n", h->HasGenerated(),
           g.Size(), g.Size() > 0 && g.First().IsSame(b3));
    h->AddModified(b1, b2);
    h->ReplaceModified(b1, b3);
    const auto& m = h->Modified(b1);
    printf("replaceGeneratedModified: hasModified=%d modified(b1)=%d firstIsB3=%d\n", h->HasModified(),
           m.Size(), m.Size() > 0 && m.First().IsSame(b3));
  }
  {
    Handle(BRepTools_History) h = new BRepTools_History;
    h->AddModified(b1, b2);
    printf("getModifiedGeneratedShapes: modified(b1)=%d\n", h->Modified(b1).Size());
    h->AddGenerated(b1, b3);
    printf("getModifiedGeneratedShapes: generated(b1)=%d\n", h->Generated(b1).Size());
  }
  return 0;
}
