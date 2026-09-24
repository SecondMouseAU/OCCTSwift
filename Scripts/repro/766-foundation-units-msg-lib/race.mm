// Does ShapeExtend::Init() return before its messages are loaded when a second thread calls it
// concurrently? Mirrors OCCTMessageMsgFileLoadDefault: Init(), then HasMsg.
#include <Message_MsgFile.hxx>
#include <ShapeExtend.hxx>
#include <TCollection_AsciiString.hxx>
#include <atomic>
#include <cstdio>
#include <thread>

int main()
{
  std::atomic<bool> go{false};
  bool              r[2] = {false, false};
  std::thread       t[2];
  for (int i = 0; i < 2; ++i)
    t[i] = std::thread([&, i] {
      while (!go)
      {
      }
      ShapeExtend::Init();
      r[i] = Message_MsgFile::HasMsg(TCollection_AsciiString("ShapeFix.FixSmallSolid.MSG0"));
    });
  go = true;
  t[0].join();
  t[1].join();
  printf("thread0 HasMsg after Init = %d, thread1 HasMsg after Init = %d\n", (int)r[0], (int)r[1]);
  return 0;
}
