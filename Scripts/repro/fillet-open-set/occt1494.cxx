// Source: the program posted in Open-Cascade-SAS/OCCT#1494 by its reporter, quoted unchanged for replay (not ours).
#include <BRepFilletAPI_MakeFillet.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <Message_ProgressIndicator.hxx>
#include <Message_ProgressScope.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <iostream>

namespace
{
class BreakAtOnce : public Message_ProgressIndicator
{
public:
  bool UserBreak() override { ++myPolls; return true; }
  int  Polls() const { return myPolls; }

protected:
  void Show(const Message_ProgressScope&, const bool) override {}

private:
  int myPolls = 0;
};
} // namespace

int main()
{
  BRepPrimAPI_MakeBox aBoxMaker(10.0, 10.0, 10.0);
  const TopoDS_Shape& aBox = aBoxMaker.Shape();

  BRepFilletAPI_MakeFillet aMaker(aBox);
  for (TopExp_Explorer anExp(aBox, TopAbs_EDGE); anExp.More(); anExp.Next())
    aMaker.Add(1.0, TopoDS::Edge(anExp.Current()));

  occ::handle<BreakAtOnce> aProgress = new BreakAtOnce();
  aMaker.Build(aProgress->Start());

  std::cout << "polled " << aProgress->Polls() << ", IsDone() = " << aMaker.IsDone() << "\n";
  return 0;
}
