// Epic #766, Tests/OCCTModelingTests/Issue568IndexSkipTests.swift: kernel parity for all 13 tests.
// The five entry points resolve indices through TopExp::MapShapes (occtUseSubShapesByIndex /
// occtMappedSubShapeAt) and then drive BRepOffsetAPI_DraftAngle (OCCTShapeDraft),
// BRepOffsetAPI_MakeThickSolid (OCCTShapeShellWithOpenFaces), BRepFilletAPI_MakeChamfer
// (OCCTShapeHistoryFromChamferEdges) and BRepFilletAPI_MakeFillet2d (OCCTFace2DFillet,
// OCCTFace2DChamfer). This probe prints what the kernel does with the resolvable requests the
// tests accept, and what it does with the partial/empty requests the bridge now refuses (the
// behaviour the refusal exists to prevent). The duplicate 2D chamfer pair (#705) runs in a child
// process because it SIGSEGVed the unpatched kernel.
#include <BRepAlgoAPI_Cut.hxx>
#include <BRepAdaptor_Surface.hxx>
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepBuilderAPI_MakePolygon.hxx>
#include <BRepBuilderAPI_Transform.hxx>
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

static TopoDS_Face rect()
{
  BRepBuilderAPI_MakePolygon p(gp_Pnt(-10, -10, 0), gp_Pnt(10, -10, 0), gp_Pnt(10, 10, 0), gp_Pnt(-10, 10, 0), Standard_True);
  return BRepBuilderAPI_MakeFace(p.Wire()).Face();
}

int main()
{
  // Fixture: the cut box has more faces than a plain box.
  {
    gp_Trsf t;
    t.SetTranslation(gp_Vec(10, 10, 10));
    TopoDS_Shape cut = BRepAlgoAPI_Cut(box(20, 20, 20), BRepBuilderAPI_Transform(box(20, 20, 20), t, Standard_True).Shape()).Shape();
    printf("cutBox: faces=%d boxFaces=%d edges=%d\n", count(cut, TopAbs_FACE), count(box(20, 20, 30), TopAbs_FACE),
           count(box(20, 20, 20), TopAbs_EDGE));
  }
  // Draft: own vertical faces, and an empty request (what an all-foreign list reduced to).
  {
    TopoDS_Shape               b = box(20, 20, 30);
    TopTools_IndexedMapOfShape faces;
    TopExp::MapShapes(b, TopAbs_FACE, faces);
    BRepOffsetAPI_DraftAngle own(b), none(b), one(b);
    int                      vertical = 0;
    for (int i = 1; i <= faces.Extent(); i++)
      if (std::abs(normalOf(TopoDS::Face(faces(i))).Z()) < std::sin(0.01))
      {
        own.Add(TopoDS::Face(faces(i)), gp_Dir(0, 0, 1), 3.0 * M_PI / 180.0, gp_Pln(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)));
        if (vertical == 0)
          one.Add(TopoDS::Face(faces(i)), gp_Dir(0, 0, 1), 3.0 * M_PI / 180.0, gp_Pln(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)));
        vertical++;
      }
    own.Build();
    none.Build();
    one.Build();
    printf("draftAcceptsOwnFaces: vertical=%d done=%d volume=%.6f (box 12000)\n", vertical, own.IsDone(), vol(own.Shape()));
    printf("draft, no faces (all-foreign request once skipped): done=%d volume=%.6f\n", none.IsDone(), vol(none.Shape()));
    printf("draft, one own face (partially-foreign request once skipped): done=%d volume=%.6f\n", one.IsDone(), vol(one.Shape()));
  }
  // Shell: top face open, and with no open face.
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
    printf("shellAcceptsOwnFaces: upward=%d done=%d valid=%d volume=%.6f\n", top.Extent(), ts.IsDone(),
           ts.IsDone() ? BRepCheck_Analyzer(ts.Shape()).IsValid() : 0, ts.IsDone() ? vol(ts.Shape()) : 0.0);
    BRepOffsetAPI_MakeThickSolid te;
    try
    {
      te.MakeThickSolidByJoin(b, empty, 2.0, 1e-6);
      printf("shell, no open face (all-foreign once skipped): done=%d\n", te.IsDone());
    }
    catch (...)
    {
      printf("shell, no open face: threw\n");
    }
  }
  // History chamfer: edges [0,1] against [0].
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
    printf("historyChamferAcceptsResolvableIndices: both done=%d volume=%.6f one done=%d volume=%.6f\n", two.IsDone(),
           vol(two.Shape()), one.IsDone(), vol(one.Shape()));
    BRepFilletAPI_MakeChamfer nothing(b);
    try
    {
      nothing.Build();
      printf("chamfer with no edge: done=%d\n", nothing.IsDone());
    }
    catch (Standard_Failure& e)
    {
      printf("chamfer with no edge: threw %s\n", e.GetMessageString());
    }
  }
  // 2D fillet and chamfer on the 20x20 rectangle face.
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
    printf("fillet2DAcceptsResolvableVertices: done=%d edges=%d\n", fl.IsDone(), fl.IsDone() ? count(fl.Shape(), TopAbs_EDGE) : -1);
    BRepFilletAPI_MakeFillet2d fl1(f);
    fl1.AddFillet(TopoDS::Vertex(verts(1)), 3.0);
    fl1.Build();
    printf("fillet2D, vertex 0 only ([0, 99999] once skipped): done=%d edges=%d\n", fl1.IsDone(), fl1.IsDone() ? count(fl1.Shape(), TopAbs_EDGE) : -1);

    BRepFilletAPI_MakeFillet2d ch(f);
    ch.AddChamfer(TopoDS::Edge(edges(1)), TopoDS::Edge(edges(2)), 2.0, 2.0);
    ch.AddChamfer(TopoDS::Edge(edges(3)), TopoDS::Edge(edges(4)), 2.0, 2.0);
    ch.Build();
    printf("chamfer2DAcceptsResolvablePairs: done=%d edges=%d\n", ch.IsDone(), ch.IsDone() ? count(ch.Shape(), TopAbs_EDGE) : -1);
    BRepFilletAPI_MakeFillet2d ch4(f);
    int pairs[4][2] = {{1, 2}, {2, 3}, {3, 4}, {4, 1}};
    for (auto& p : pairs)
      ch4.AddChamfer(TopoDS::Edge(edges(p[0])), TopoDS::Edge(edges(p[1])), 1.0, 1.0);
    ch4.Build();
    printf("chamfer2DAcceptsSharedEdgeAcrossDifferentPairs: done=%d edges=%d\n", ch4.IsDone(), ch4.IsDone() ? count(ch4.Shape(), TopAbs_EDGE) : -1);
    BRepFilletAPI_MakeFillet2d ch1(f);
    ch1.AddChamfer(TopoDS::Edge(edges(1)), TopoDS::Edge(edges(2)), 2.0, 2.0);
    ch1.Build();
    printf("chamfer2D, pair (0,1) only ((0,1),(2,99999) once skipped): done=%d edges=%d\n", ch1.IsDone(), ch1.IsDone() ? count(ch1.Shape(), TopAbs_EDGE) : -1);

    fflush(stdout);
    pid_t pid = fork();
    if (pid == 0)
    {
      BRepFilletAPI_MakeFillet2d dup(f);
      dup.AddChamfer(TopoDS::Edge(edges(1)), TopoDS::Edge(edges(2)), 1.0, 1.0);
      TopoDS_Edge e1 = TopoDS::Edge(edges(1)), e2 = TopoDS::Edge(edges(2));
      try
      {
        dup.AddChamfer(e1, e2, 2.0, 2.0);
        dup.Build();
        printf("duplicate pair (0,1),(0,1) in the pinned kernel: no crash, status=%d done=%d\n", (int)dup.Status(), dup.IsDone());
      }
      catch (Standard_Failure& e)
      {
        printf("duplicate pair (0,1),(0,1) in the pinned kernel: threw %s\n", e.GetMessageString());
      }
      fflush(stdout);
      _exit(0);
    }
    int st = 0;
    waitpid(pid, &st, 0);
    printf("duplicate pair child: exited=%d signal=%d\n", WIFEXITED(st), WIFSIGNALED(st) ? WTERMSIG(st) : 0);
  }
  return 0;
}
