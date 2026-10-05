// #3029: OCCT prints its STEP write statistics to stdout on every export. What carries them, at
// what gravity, and which of OCCT's own controls reaches them?
//
//   probe write      [--trace LEVEL] [--per-writer]   STEPControl_Writer, one shape
//   probe write-caf  [--trace LEVEL]                  STEPCAFControl_Writer, one XDE document
//   probe write-iges [--trace LEVEL]                  IGESControl_Writer, one shape
//   probe read-bad   [--trace LEVEL]                  STEPControl_Reader on a malformed file
//
// stdout is left to OCCT: whatever its default messenger prints ends up there and nothing else does,
// so a caller counts the lines OCCT printed by redirecting it. This program's own findings go to
// stderr.
//
// A recording printer is added to the default messenger at trace level `Trace` so it receives every
// message whatever the other printers' levels are, and reports the gravity and text of each. It is
// a second printer and changes nothing about the ones OCCT attached.
//
//   --trace LEVEL   (trace|info|warning|alarm|fail) sets the trace level of every printer the
//                   default messenger had before the recorder was added. That is what OCCT's own
//                   DRAW command does (src/Draw/TKDraw/Draw/Draw_BasicCommands.cxx, the loop that
//                   calls aPrinter->SetTraceLevel(aLevel) over the default messenger's printers).
//   --per-writer    the issue's proposal: give the writer's own Transfer_FinderProcess a messenger
//                   with no printers, so the writer stops printing without the default messenger
//                   being touched.
#include <BRepPrimAPI_MakeBox.hxx>
#include <IGESControl_Writer.hxx>
#include <Message.hxx>
#include <Message_Messenger.hxx>
#include <Message_Printer.hxx>
#include <NCollection_Sequence.hxx>
#include <STEPCAFControl_Writer.hxx>
#include <STEPControl_Reader.hxx>
#include <STEPControl_Writer.hxx>
#include <TDocStd_Document.hxx>
#include <Transfer_FinderProcess.hxx>
#include <XCAFApp_Application.hxx>
#include <XCAFDoc_DocumentTool.hxx>
#include <XCAFDoc_ShapeTool.hxx>
#include <XSControl_TransferWriter.hxx>
#include <XSControl_WorkSession.hxx>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <fstream>
#include <string>
#include <unistd.h>
#include <vector>

class RecordingPrinter : public Message_Printer
{
  DEFINE_STANDARD_RTTI_INLINE(RecordingPrinter, Message_Printer)
public:
  RecordingPrinter() { myTraceLevel = Message_Trace; }
  mutable std::vector<std::pair<int, std::string>> lines;

protected:
  void send(const TCollection_AsciiString& theString, const Message_Gravity theGravity) const override
  {
    lines.emplace_back((int)theGravity, theString.ToCString());
  }
};

static const char* gravityName(int g)
{
  switch (g)
  {
    case Message_Trace: return "trace";
    case Message_Info: return "info";
    case Message_Warning: return "warning";
    case Message_Alarm: return "alarm";
    case Message_Fail: return "fail";
  }
  return "?";
}

static bool parseLevel(const char* s, Message_Gravity& out)
{
  if (!strcmp(s, "trace")) { out = Message_Trace; return true; }
  if (!strcmp(s, "info")) { out = Message_Info; return true; }
  if (!strcmp(s, "warning")) { out = Message_Warning; return true; }
  if (!strcmp(s, "alarm")) { out = Message_Alarm; return true; }
  if (!strcmp(s, "fail")) { out = Message_Fail; return true; }
  return false;
}

static void report(const RecordingPrinter& rec)
{
  int counts[5] = {0, 0, 0, 0, 0};
  for (auto& l : rec.lines)
    counts[l.first]++;
  fprintf(stderr, "messages sent to the default messenger: %zu (trace %d, info %d, warning %d, alarm %d, fail %d)\n",
          rec.lines.size(), counts[0], counts[1], counts[2], counts[3], counts[4]);
  for (auto& l : rec.lines)
  {
    std::string text = l.second;
    for (char& c : text)
      if (c == '\n') c = '|';
    fprintf(stderr, "  [%s] %s\n", gravityName(l.first), text.c_str());
  }
}

int main(int argc, char** argv)
{
  if (argc < 2)
  {
    fprintf(stderr, "usage: probe write|read-bad [--trace LEVEL] [--per-writer]\n");
    return 2;
  }
  const std::string mode = argv[1];
  bool              haveLevel = false, perWriter = false;
  Message_Gravity   level = Message_Info;
  for (int i = 2; i < argc; i++)
  {
    if (!strcmp(argv[i], "--trace") && i + 1 < argc)
      haveLevel = parseLevel(argv[++i], level);
    else if (!strcmp(argv[i], "--per-writer"))
      perWriter = true;
  }

  const occ::handle<Message_Messenger>& messenger = Message::DefaultMessenger();
  fprintf(stderr, "default messenger printers before: %d\n", (int)messenger->Printers().Size());
  if (haveLevel)
    for (int i = 1; i <= messenger->Printers().Size(); i++)
      messenger->ChangePrinters().ChangeValue(i)->SetTraceLevel(level);
  occ::handle<RecordingPrinter> rec = new RecordingPrinter();
  messenger->AddPrinter(rec);

  char path[] = "/tmp/occt3029.XXXXXX";
  int  fd = mkstemp(path);
  if (fd >= 0)
    close(fd);

  if (mode == "write")
  {
    TopoDS_Shape       box = BRepPrimAPI_MakeBox(10, 20, 30).Shape();
    STEPControl_Writer writer;
    if (perWriter)
    {
      occ::handle<Message_Messenger> quiet = new Message_Messenger();
      quiet->ChangePrinters().Clear();
      occ::handle<Transfer_FinderProcess> fp = writer.WS()->TransferWriter()->FinderProcess();
      fprintf(stderr, "writer's FinderProcess before Transfer: %s\n", fp.IsNull() ? "null" : "present");
      if (!fp.IsNull())
        fp->SetMessenger(quiet);
    }
    IFSelect_ReturnStatus t = writer.Transfer(box, STEPControl_AsIs);
    IFSelect_ReturnStatus w = writer.Write(path);
    fprintf(stderr, "Transfer status %d, Write status %d\n", (int)t, (int)w);
  }
  else if (mode == "write-caf")
  {
    occ::handle<TDocStd_Document> doc;
    XCAFApp_Application::GetApplication()->NewDocument("BinXCAF", doc);
    XCAFDoc_DocumentTool::ShapeTool(doc->Main())->AddShape(BRepPrimAPI_MakeBox(10, 20, 30).Shape());
    STEPCAFControl_Writer writer;
    bool                  t = writer.Transfer(doc);
    IFSelect_ReturnStatus w = writer.Write(path);
    fprintf(stderr, "Transfer %d, Write status %d\n", (int)t, (int)w);
  }
  else if (mode == "write-iges")
  {
    IGESControl_Writer writer;
    writer.AddShape(BRepPrimAPI_MakeBox(10, 20, 30).Shape());
    writer.ComputeModel();
    bool w = writer.Write(path);
    fprintf(stderr, "Write %d\n", (int)w);
  }
  else if (mode == "read-bad")
  {
    std::ofstream(path) << "ISO-10303-21;\nHEADER;\nENDSEC;\nDATA;\n#1 = NOT_A_STEP_ENTITY(;\nENDSEC;\nEND-ISO-10303-21;\n";
    STEPControl_Reader reader;
    IFSelect_ReturnStatus r = reader.ReadFile(path);
    fprintf(stderr, "ReadFile status %d\n", (int)r);
  }
  else
  {
    fprintf(stderr, "unknown mode %s\n", mode.c_str());
    return 2;
  }
  unlink(path);
  fflush(stdout);
  report(*rec);
  return 0;
}
