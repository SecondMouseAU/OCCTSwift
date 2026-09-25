// Epic #766 evidence fix, Tests/OCCTModelingTests/Issue568IndexSkipTests.swift.
// probe.mm printed the kernel's answer at %.6f and only for some of the requests the tests refuse.
// This probe repeats the bridge's calls (OCCTShapeDraft, OCCTShapeShellWithOpenFaces,
// OCCTShapeHistoryFromChamferEdges, OCCTFace2DFillet, OCCTFace2DChamfer) at %.17g, for every request
// the 13 tests make, with each unresolvable index removed the way the pre-#568 bridge removed it. A
// request that reduces to no Add() call is measured too. The three duplicate-pair requests of
// chamfer2DRejectsDuplicatePair each run in a forked child, because the unpatched kernel SIGSEGVed.
#include <BRepAdaptor_Surface.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepBuilderAPI_MakePolygon.hxx>
#include <BRepCheck_Analyzer.hxx>
#include <BRepFilletAPI_MakeChamfer.hxx>
#include <BRepFilletAPI_MakeFillet2d.hxx>
#include <BRepGProp.hxx>
#include <BRepLProp_SLProps.hxx>
#include <BRepOffsetAPI_DraftAngle.hxx>
#include <BRepOffsetAPI_MakeThickSolid.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <GProp_GProps.hxx>
#include <TopExp.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopTools_ListOfShape.hxx>
#include <TopoDS.hxx>
#include <cstdio>
#include <gp_Pln.hxx>
#include <sys/wait.h>
#include <unistd.h>

static double vol(const TopoDS_Shape& s)
{
  GProp_GProps p;
  BRepGProp::VolumeProperties(s, p);
  return p.Mass();
}

// Shape.box(width:height:depth:) is centred on the origin (OCCTShapeCreateBox).
static TopoDS_Shape box(double w, double h, double d)
{
  return BRepPrimAPI_MakeBox(gp_Pnt(-w / 2, -h / 2, -d / 2), w, h, d).Shape();
}

static gp_Dir normalOf(const TopoDS_Face& f)
{
  BRepAdaptor_Surface s(f);
  BRepLProp_SLProps   p(s, (s.FirstUParameter() + s.LastUParameter()) / 2,
                      (s.FirstVParameter() + s.LastVParameter()) / 2, 1, 1e-6);
  gp_Dir n = p.Normal();
  if (f.Orientation() == TopAbs_REVERSED)
    n.Reverse();
  return n;
}

static int count(const TopoDS_Shape& s, TopAbs_ShapeEnum t)
{
  TopTools_IndexedMapOfShape m;
  TopExp::MapShapes(s, t, m);
  return m.Extent();
}

// Shape.face(from: Wire.rectangle(width: 20, height: 20)) in the plane z = 0.
static TopoDS_Face rect()
{
  BRepBuilderAPI_MakePolygon p(gp_Pnt(-10, -10, 0), gp_Pnt(10, -10, 0), gp_Pnt(10, 10, 0),
                               gp_Pnt(-10, 10, 0), Standard_True);
  return BRepBuilderAPI_MakeFace(p.Wire()).Face();
}

// One duplicate-pair request, in a child process. pairs are 0-based edge indices as the tests pass them.
static void duplicateRequest(const char* label, const TopoDS_Face& f, int n, const int (*pairs)[2],
                             const double* dist)
{
  TopTools_IndexedMapOfShape edges;
  TopExp::MapShapes(f, TopAbs_EDGE, edges);
  fflush(stdout);
  pid_t pid = fork();
  if (pid == 0)
  {
    try
    {
      BRepFilletAPI_MakeFillet2d ch(f);
      for (int i = 0; i < n; i++)
        ch.AddChamfer(TopoDS::Edge(edges(pairs[i][0] + 1)), TopoDS::Edge(edges(pairs[i][1] + 1)), dist[i], dist[i]);
      ch.Build();
      printf("%s: done=%d status=%d edges=%d\n", label, ch.IsDone(), (int)ch.Status(),
             ch.IsDone() ? count(ch.Shape(), TopAbs_EDGE) : -1);
    }
    catch (Standard_Failure& e)
    {
      printf("%s: done=0 threw %s\n", label, e.GetMessageString());
    }
    fflush(stdout);
    _exit(0);
  }
  int st = 0;
  waitpid(pid, &st, 0);
  printf("%s: child exited=%d signal=%d\n", label, WIFEXITED(st), WIFSIGNALED(st) ? WTERMSIG(st) : 0);
}

int main()
{
  // Draft: OCCTShapeDraft on Shape.box(20, 20, 30), pull +Z, 3 degrees, neutral plane z = 0.
  {
    TopoDS_Shape               b = box(20, 20, 30);
    TopTools_IndexedMapOfShape faces;
    TopExp::MapShapes(b, TopAbs_FACE, faces);
    gp_Pln plane(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1));
    double angle = 3.0 * M_PI / 180.0;
    BRepOffsetAPI_DraftAngle own(b), none(b), one(b);
    int                      vertical = 0;
    for (int i = 1; i <= faces.Extent(); i++)
      if (std::abs(normalOf(TopoDS::Face(faces(i))).Z()) < std::sin(0.01))
      {
        own.Add(TopoDS::Face(faces(i)), gp_Dir(0, 0, 1), angle, plane);
        if (vertical == 0)
          one.Add(TopoDS::Face(faces(i)), gp_Dir(0, 0, 1), angle, plane);
        vertical++;
      }
    own.Build();
    none.Build();
    one.Build();
    printf("draftAcceptsOwnFaces: vertical=%d done=%d volume=%.17g\n", vertical, own.IsDone(), vol(own.Shape()));
    printf("draftRejectsWhollyForeignFaceList [foreign] -> no face: done=%d volume=%.17g\n", none.IsDone(), vol(none.Shape()));
    printf("draftRejectsPartiallyForeignFaceList [own, foreign] -> [own]: done=%d volume=%.17g\n", one.IsDone(), vol(one.Shape()));
  }
  // Shell: OCCTShapeShellWithOpenFaces on Shape.box(20, 20, 20), thickness 2.0, MakeThickSolidByJoin(1e-6).
  {
    TopoDS_Shape               b = box(20, 20, 20);
    TopTools_IndexedMapOfShape faces;
    TopExp::MapShapes(b, TopAbs_FACE, faces);
    TopTools_ListOfShape top, empty;
    for (int i = 1; i <= faces.Extent(); i++)
      if (normalOf(TopoDS::Face(faces(i))).Z() > std::cos(0.01))
        top.Append(faces(i));
    BRepOffsetAPI_MakeThickSolid ts;
    ts.MakeThickSolidByJoin(b, top, 2.0, 1e-6);
    printf("shellAcceptsOwnFaces / shellRejectsPartiallyForeignFaceList [own, foreign] -> [own]: upward=%d done=%d valid=%d volume=%.17g\n",
           top.Extent(), ts.IsDone(), ts.IsDone() ? BRepCheck_Analyzer(ts.Shape()).IsValid() : 0,
           ts.IsDone() ? vol(ts.Shape()) : 0.0);
    BRepOffsetAPI_MakeThickSolid te;
    try
    {
      te.MakeThickSolidByJoin(b, empty, 2.0, 1e-6);
      printf("shellRejectsPartiallyForeignFaceList [foreign] -> no open face: done=%d valid=%d volume=%.17g\n", te.IsDone(),
             te.IsDone() ? BRepCheck_Analyzer(te.Shape()).IsValid() : 0, te.IsDone() ? vol(te.Shape()) : 0.0);
    }
    catch (Standard_Failure& e)
    {
      printf("shellRejectsPartiallyForeignFaceList [foreign] -> no open face: threw %s\n", e.GetMessageString());
    }
  }
  // History chamfer: OCCTShapeHistoryFromChamferEdges on Shape.box(20, 20, 20), distance 1.0.
  {
    TopoDS_Shape               b = box(20, 20, 20);
    TopTools_IndexedMapOfShape edges;
    TopExp::MapShapes(b, TopAbs_EDGE, edges);
    BRepFilletAPI_MakeChamfer two(b), one(b);
    two.Add(1.0, TopoDS::Edge(edges(1)));
    two.Add(1.0, TopoDS::Edge(edges(2)));
    one.Add(1.0, TopoDS::Edge(edges(1)));
    two.Build();
    one.Build();
    printf("historyChamferAcceptsResolvableIndices [0, 1]: done=%d volume=%.17g\n", two.IsDone(), vol(two.Shape()));
    printf("historyChamferAcceptsResolvableIndices [0]: done=%d volume=%.17g\n", one.IsDone(), vol(one.Shape()));
    printf("historyChamferRejectsOutOfRangeIndex [0, 99999] -> [0]: done=%d volume=%.17g\n", one.IsDone(), vol(one.Shape()));
    BRepFilletAPI_MakeChamfer nothing(b);
    try
    {
      nothing.Build();
      printf("historyChamferRejectsOutOfRangeIndex [-1] -> no edge: done=%d\n", nothing.IsDone());
    }
    catch (Standard_Failure& e)
    {
      printf("historyChamferRejectsOutOfRangeIndex [-1] -> no edge: threw %s\n", e.GetMessageString());
    }
  }
  // 2D fillet and chamfer on the 20 x 20 rectangle face.
  {
    TopoDS_Face                f = rect();
    TopTools_IndexedMapOfShape verts, edges;
    TopExp::MapShapes(f, TopAbs_VERTEX, verts);
    TopExp::MapShapes(f, TopAbs_EDGE, edges);
    printf("rectangle face: vertices=%d edges=%d\n", verts.Extent(), edges.Extent());

    BRepFilletAPI_MakeFillet2d fl(f);
    for (int i = 1; i <= 4; i++)
      fl.AddFillet(TopoDS::Vertex(verts(i)), 2.0);
    fl.Build();
    printf("fillet2DAcceptsResolvableVertices [0,1,2,3] r=2: done=%d edges=%d\n", fl.IsDone(), fl.IsDone() ? count(fl.Shape(), TopAbs_EDGE) : -1);
    BRepFilletAPI_MakeFillet2d fl1(f);
    fl1.AddFillet(TopoDS::Vertex(verts(1)), 3.0);
    fl1.Build();
    printf("fillet2DRejectsOutOfRangeVertex [0, 99999] -> [0]: done=%d edges=%d\n", fl1.IsDone(), fl1.IsDone() ? count(fl1.Shape(), TopAbs_EDGE) : -1);
    BRepFilletAPI_MakeFillet2d fl0(f);
    try
    {
      fl0.Build();
      printf("fillet2DRejectsOutOfRangeVertex [-1] -> no vertex: done=%d edges=%d\n", fl0.IsDone(), fl0.IsDone() ? count(fl0.Shape(), TopAbs_EDGE) : -1);
    }
    catch (Standard_Failure& e)
    {
      printf("fillet2DRejectsOutOfRangeVertex [-1] -> no vertex: threw %s\n", e.GetMessageString());
    }

    BRepFilletAPI_MakeFillet2d ch(f);
    ch.AddChamfer(TopoDS::Edge(edges(1)), TopoDS::Edge(edges(2)), 2.0, 2.0);
    ch.AddChamfer(TopoDS::Edge(edges(3)), TopoDS::Edge(edges(4)), 2.0, 2.0);
    ch.Build();
    printf("chamfer2DAcceptsResolvablePairs [(0,1),(2,3)] d=2: done=%d edges=%d\n", ch.IsDone(), ch.IsDone() ? count(ch.Shape(), TopAbs_EDGE) : -1);
    BRepFilletAPI_MakeFillet2d ch4(f);
    int                        pairs4[4][2] = {{1, 2}, {2, 3}, {3, 4}, {4, 1}};
    for (auto& p : pairs4)
      ch4.AddChamfer(TopoDS::Edge(edges(p[0])), TopoDS::Edge(edges(p[1])), 1.0, 1.0);
    ch4.Build();
    printf("chamfer2DAcceptsSharedEdgeAcrossDifferentPairs [(0,1),(1,2),(2,3),(3,0)] d=1: done=%d edges=%d\n", ch4.IsDone(),
           ch4.IsDone() ? count(ch4.Shape(), TopAbs_EDGE) : -1);
    BRepFilletAPI_MakeFillet2d ch1(f);
    ch1.AddChamfer(TopoDS::Edge(edges(1)), TopoDS::Edge(edges(2)), 2.0, 2.0);
    ch1.Build();
    printf("chamfer2DRejectsOutOfRangePairMember [(0,1),(2,99999)] and [(0,1),(99999,3)] -> [(0,1)]: done=%d edges=%d\n", ch1.IsDone(),
           ch1.IsDone() ? count(ch1.Shape(), TopAbs_EDGE) : -1);
    BRepFilletAPI_MakeFillet2d chn(f);
    try
    {
      chn.Build();
      printf("chamfer2DRejectsOutOfRangePairMember [(-1,1)] -> no pair: done=%d edges=%d\n", chn.IsDone(), chn.IsDone() ? count(chn.Shape(), TopAbs_EDGE) : -1);
    }
    catch (Standard_Failure& e)
    {
      printf("chamfer2DRejectsOutOfRangePairMember [(-1,1)] -> no pair: threw %s\n", e.GetMessageString());
    }

    // chamfer2DRejectsDuplicatePair: the bridge refuses before any kernel call, so these are what the
    // kernel does with the request if it were passed through.
    int    dupA[2][2] = {{0, 1}, {0, 1}};
    double dupAd[2]   = {1.0, 2.0};
    duplicateRequest("chamfer2DRejectsDuplicatePair [(0,1),(0,1)] d=[1,2]", f, 2, dupA, dupAd);
    int    dupB[2][2] = {{0, 1}, {1, 0}};
    duplicateRequest("chamfer2DRejectsDuplicatePair [(0,1),(1,0)] d=[1,2]", f, 2, dupB, dupAd);
    int    dupC[3][2] = {{0, 1}, {0, 1}, {0, 1}};
    double dupCd[3]   = {1.0, 1.0, 1.0};
    duplicateRequest("chamfer2DRejectsDuplicatePair [(0,1),(0,1),(0,1)] d=[1,1,1]", f, 3, dupC, dupCd);
  }
  return 0;
}
