// #3487 probe: BRepTools::Read on damaged BREP text, bridge guard NOT applied.
//   probe gen <dir>               write the corpus of valid BREP files into <dir>
//   probe read <mode> <file>      read one file; prints one RESULT line, or a backtrace and exit 139
// Modes: path    BRepTools::Read(shape, path, builder)            (what OCCTImportBREP does)
//        str     BRepTools::Read(shape, istringstream, builder)   (what OCCTShapeFromBREPString does)
//        strx    as str, with the stream set to throw on failbit/badbit
//        strxe   as strx, plus eofbit
//        bin     BinTools_ShapeReader::Read on a binary file (OCCTBinToolsReadShape's reader)
//        binset  BinTools::Read, the BinTools_ShapeSet reader (a file BinTools::Write made; #3494)
//        bridge  strxe through the word-length limit the bridge reads through (a copy of
//                OcctBrepWordLimitBuf in OCCTBridge_IO_NativeFormats.mm: keep the two in step)
#include <BRepAlgoAPI_Fuse.hxx>
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepBuilderAPI_MakeWire.hxx>
#include <BRepBuilderAPI_Transform.hxx>
#include <BRepCheck_Analyzer.hxx>
#include <BRepMesh_IncrementalMesh.hxx>
#include <BRepOffsetAPI_ThruSections.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <BRepPrimAPI_MakeSphere.hxx>
#include <BRepTools.hxx>
#include <BinTools.hxx>
#include <BinTools_ShapeReader.hxx>
#include <BinTools_ShapeWriter.hxx>
#include <BRep_Builder.hxx>
#include <GeomAPI_Interpolate.hxx>
#include <GeomAPI_PointsToBSplineSurface.hxx>
#include <Geom_BSplineCurve.hxx>
#include <Geom_BSplineSurface.hxx>
#include <NCollection_Array2.hxx>
#include <NCollection_HArray1.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Compound.hxx>
#include <TopTools_FormatVersion.hxx>
#include <execinfo.h>
#include <signal.h>
#include <sys/time.h>
#include <sys/wait.h>
#include <unistd.h>
#include <cstdio>
#include <cstdlib>
#include <fstream>
#include <iterator>
#include <sstream>
#include <string>
#include <vector>

static void onSig(int s)
{
  void* f[60];
  int   n = backtrace(f, 60);
  fprintf(stderr, "SIGNAL %d\n", s);
  backtrace_symbols_fd(f, n, 2);
  _exit(139);
}

static void put(const TopoDS_Shape& s, const std::string& dir, const char* name, bool tri, int ver)
{
  std::string p  = dir + "/" + name + ".brep";
  bool        ok = BRepTools::Write(s, p.c_str(), tri, false, (TopTools_FormatVersion)ver);
  printf("%s %d\n", p.c_str(), (int)ok);
}

static TopoDS_Shape bsplineFace()
{
  NCollection_Array2<gp_Pnt> pts(1, 5, 1, 5);
  for (int i = 1; i <= 5; i++)
    for (int j = 1; j <= 5; j++)
      pts(i, j) = gp_Pnt(i * 2.0, j * 2.0, ((i * 7 + j * 3) % 5) * 0.4);
  GeomAPI_PointsToBSplineSurface b(pts);
  return BRepBuilderAPI_MakeFace(b.Surface(), 1e-6).Face();
}

static TopoDS_Shape bsplineLoft()
{
  occ::handle<NCollection_HArray1<gp_Pnt>> a = new NCollection_HArray1<gp_Pnt>(1, 4);
  occ::handle<NCollection_HArray1<gp_Pnt>> b = new NCollection_HArray1<gp_Pnt>(1, 4);
  for (int i = 1; i <= 4; i++)
  {
    a->SetValue(i, gp_Pnt(i * 3.0, (i % 2) * 2.0, 0));
    b->SetValue(i, gp_Pnt(i * 3.0, (i % 2) * 1.5, 5));
  }
  GeomAPI_Interpolate ia(a, false, 1e-6), ib(b, false, 1e-6);
  ia.Perform();
  ib.Perform();
  TopoDS_Edge          ea = BRepBuilderAPI_MakeEdge(ia.Curve());
  TopoDS_Edge          eb = BRepBuilderAPI_MakeEdge(ib.Curve());
  BRepOffsetAPI_ThruSections t(false, true);
  t.AddWire(BRepBuilderAPI_MakeWire(ea));
  t.AddWire(BRepBuilderAPI_MakeWire(eb));
  t.Build();
  return t.Shape();
}

static int gen(const std::string& dir)
{
  TopoDS_Shape box  = BRepPrimAPI_MakeBox(10, 20, 30).Shape();
  TopoDS_Shape cyl  = BRepPrimAPI_MakeCylinder(5, 12).Shape();
  TopoDS_Shape sph  = BRepPrimAPI_MakeSphere(7).Shape();
  TopoDS_Shape bsf  = bsplineFace();
  TopoDS_Shape bsl  = bsplineLoft();
  TopoDS_Shape mbox = BRepPrimAPI_MakeBox(10, 20, 30).Shape();
  BRepMesh_IncrementalMesh(mbox, 0.5);
  TopoDS_Shape mcyl = BRepPrimAPI_MakeCylinder(5, 12).Shape();
  BRepMesh_IncrementalMesh(mcyl, 0.3);
  TopoDS_Shape msph = BRepPrimAPI_MakeSphere(7).Shape();
  BRepMesh_IncrementalMesh(msph, 0.5);
  gp_Trsf tr;
  tr.SetTranslation(gp_Vec(30, 0, 0));
  TopoDS_Shape box2 = BRepBuilderAPI_Transform(box, tr, true).Shape();
  gp_Trsf      rot;
  rot.SetRotation(gp_Ax1(gp::Origin(), gp::DZ()), 0.7);
  TopoDS_Shape    rbox = BRepBuilderAPI_Transform(box, rot, false).Shape();
  TopoDS_Compound comp;
  BRep_Builder    bb;
  bb.MakeCompound(comp);
  bb.Add(comp, box);
  bb.Add(comp, box2);
  bb.Add(comp, cyl);
  TopoDS_Shape fused = BRepAlgoAPI_Fuse(box, cyl).Shape();
  put(box, dir, "box", false, 3);
  put(cyl, dir, "cylinder", false, 3);
  put(sph, dir, "sphere", false, 3);
  put(bsf, dir, "bsplineface", false, 3);
  put(bsl, dir, "bsplineloft", false, 3);
  put(mbox, dir, "meshedbox", true, 3);
  put(mcyl, dir, "meshedcylinder", true, 3);
  put(msph, dir, "meshedsphere", true, 3);
  put(comp, dir, "compound", false, 3);
  put(fused, dir, "fused", false, 3);
  put(rbox, dir, "locatedbox", false, 3);
  put(box, dir, "box_v1", false, 1);
  put(box, dir, "box_v2", false, 2);
  put(cyl, dir, "cylinder_v1", false, 1);
  put(cyl, dir, "cylinder_v2", false, 2);
  put(bsl, dir, "bsplineloft_v1", false, 1);
  put(mcyl, dir, "meshedcylinder_v2", true, 2);
  put(comp, dir, "compound_v1", false, 1);
  // The BinTools (binary) writer, the sibling reader the bridge exposes as OCCTBinToolsReadShape.
  const std::pair<const char*, TopoDS_Shape> bins[] = {{"box", box}, {"cylinder", cyl}, {"compound", comp}};
  for (const auto& b : bins)
  {
    std::ostringstream   oss;
    BinTools_ShapeWriter w;
    w.Write(b.second, oss);
    std::ofstream out(dir + "/" + b.first + ".bin", std::ios::binary);
    out << oss.str();
  }
  return 0;
}

static std::string gResult;

// Copy of OcctBrepWordLimitBuf (OCCTBridge_IO_NativeFormats.mm): refuses a word of 255 bytes or more.
class WordLimitBuf : public std::streambuf
{
public:
  explicit WordLimitBuf(std::streambuf* src) : mySource(src), myChunk(65536) {}

protected:
  int_type underflow() override
  {
    if (gptr() < egptr())
      return traits_type::to_int_type(*gptr());
    const std::streamsize n = mySource->sgetn(myChunk.data(), myChunk.size());
    if (n <= 0)
      return traits_type::eof();
    for (std::streamsize i = 0; i < n; i++)
    {
      const char c = myChunk[i];
      if (c == ' ' || c == '\n' || c == '\t' || c == '\r' || c == '\v' || c == '\f')
        myWord = 0;
      else if (++myWord > 254)
        throw std::ios_base::failure("word too long");
    }
    setg(myChunk.data(), myChunk.data(), myChunk.data() + n);
    return traits_type::to_int_type(*gptr());
  }

private:
  std::streambuf*   mySource;
  std::vector<char> myChunk;
  size_t            myWord = 0;
};

static void report(const TopoDS_Shape& sh, bool ret)
{
  char line[128];
  if (sh.IsNull())
  {
    snprintf(line, sizeof line, "null ret=%d", (int)ret);
    gResult = line;
    printf("RESULT %s\n", line);
    return;
  }
  int nf = 0;
  for (TopExp_Explorer e(sh, TopAbs_FACE); e.More(); e.Next())
    nf++;
  // The reader returned; a fault after this line is in the use of the shape (the validity check
  // below), not in the reader.
  printf("READ returned faces=%d\n", nf);
  fflush(stdout);
  bool valid = BRepCheck_Analyzer(sh).IsValid();
  snprintf(line, sizeof line, "shape ret=%d faces=%d valid=%d", (int)ret, nf, (int)valid);
  gResult = line;
  printf("RESULT %s\n", line);
}

static void readOne(const std::string& mode, const std::string& file)
{
  TopoDS_Shape sh;
  BRep_Builder b;
  try
  {
    if (mode == "path")
    {
      bool r = BRepTools::Read(sh, file.c_str(), b);
      report(sh, r);
    }
    else if (mode == "binset")
    {
      std::ifstream      in(file, std::ios::binary);
      std::string        text((std::istreambuf_iterator<char>(in)), std::istreambuf_iterator<char>());
      std::istringstream iss(text);
      BinTools::Read(sh, iss);
      report(sh, true);
    }
    else if (mode == "bin")
    {
      std::ifstream      in(file, std::ios::binary);
      std::string        text((std::istreambuf_iterator<char>(in)), std::istreambuf_iterator<char>());
      std::istringstream iss(text);
      BinTools_ShapeReader reader;
      reader.Read(iss, sh);
      report(sh, true);
    }
    else
    {
      std::ifstream      in(file, std::ios::binary);
      std::string        text((std::istreambuf_iterator<char>(in)), std::istreambuf_iterator<char>());
      std::istringstream iss(text);
      if (mode == "strx")
        iss.exceptions(std::ios::failbit | std::ios::badbit);
      if (mode == "strxe") // eofbit too: a token ended by the end of the file throws at its extraction
        iss.exceptions(std::ios::failbit | std::ios::badbit | std::ios::eofbit);
      if (mode == "bridge")
      {
        WordLimitBuf limited(iss.rdbuf());
        std::istream guarded(&limited);
        guarded.exceptions(std::ios::failbit | std::ios::badbit | std::ios::eofbit);
        BRepTools::Read(sh, guarded, b);
      }
      else
        BRepTools::Read(sh, iss, b);
      report(sh, true);
    }
  }
  catch (const std::exception& e)
  {
    printf("RESULT threw %s\n", e.what());
  }
  catch (...)
  {
    printf("RESULT threw other\n");
  }
}

// batch <mode> <list>: one forked child per listed file, so a fault ends only that child.
// Prints "<index> <class> <detail> <path>" per file, class one of ok/null/threw/SIG<n>/HANG.
static int batch(const std::string& mode, const char* listFile)
{
  std::ifstream list(listFile);
  std::string   path;
  int           idx = 0;
  while (std::getline(list, path))
  {
    fflush(stdout);
    int fds[2];
    pipe(fds);
    pid_t pid = fork();
    if (pid == 0)
    {
      close(fds[0]);
      dup2(fds[1], 1);
      signal(SIGSEGV, SIG_DFL); // the parent reads the signal off the wait status
      signal(SIGBUS, SIG_DFL);
      signal(SIGABRT, SIG_DFL);
      // 0.1 s of this process's own CPU time: a spin ends as SIGVTALRM whatever the machine load,
      // and a valid read of the largest corpus file takes a few milliseconds.
      struct itimerval tm = {{0, 0}, {0, 100000}};
      setitimer(ITIMER_VIRTUAL, &tm, nullptr);
      readOne(mode, path);
      fflush(stdout);
      _exit(0);
    }
    close(fds[1]);
    std::string out;
    char        buf[256];
    ssize_t     n;
    while ((n = read(fds[0], buf, sizeof buf)) > 0)
      out.append(buf, n);
    close(fds[0]);
    int st = 0;
    waitpid(pid, &st, 0);
    std::string cls;
    bool returned = out.find("READ returned") != std::string::npos;
    if (WIFSIGNALED(st))
    {
      bool spin = WTERMSIG(st) == SIGVTALRM || WTERMSIG(st) == SIGALRM;
      cls       = std::string(returned ? "USE-" : "") + (spin ? "HANG" : "SIG" + std::to_string(WTERMSIG(st)));
    }
    else if (WIFEXITED(st) && WEXITSTATUS(st) != 0)
      cls = "EXIT" + std::to_string(WEXITSTATUS(st));
    else
    {
      size_t r = out.find("RESULT ");
      std::string res = r == std::string::npos ? "noresult" : out.substr(r + 7, out.find('\n', r) - r - 7);
      cls = res;
    }
    printf("%d | %s | %s\n", idx++, cls.c_str(), path.c_str());
  }
  return 0;
}

int main(int argc, char** argv)
{
  // A stack overflow has no stack to run the handler on: give it one (#3494).
  static char altStack[1 << 16];
  stack_t     ss = {};
  ss.ss_sp       = altStack;
  ss.ss_size     = sizeof altStack;
  sigaltstack(&ss, nullptr);
  struct sigaction sa = {};
  sa.sa_handler       = onSig;
  sa.sa_flags         = SA_ONSTACK;
  sigaction(SIGSEGV, &sa, nullptr);
  sigaction(SIGBUS, &sa, nullptr);
  signal(SIGABRT, onSig);
  signal(SIGALRM, onSig);
  if (argc >= 3 && std::string(argv[1]) == "gen")
    return gen(argv[2]);
  if (argc < 4)
    return 2;
  std::string mode = argv[2], file = argv[3];
  if (std::string(argv[1]) == "batch")
    return batch(mode, argv[3]);
  alarm(20);
  readOne(mode, file);
  return 0;
}
