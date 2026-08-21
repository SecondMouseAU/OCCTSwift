// #1035 ground truth: for every OCCT entry point the bridge hands a caller-supplied TopoDS_Shape
// into, does a NULL shape crash with an uncatchable signal, raise a catchable Standard_Failure, or
// return normally?
//
// This is the shape-side equivalent of Scripts/repro/556-null-handle-guard-sweep, which asked the
// same question of a null geometry Handle and is what #1026's own README names as the missing
// measurement. #1035 proposes replacing every `x->shape` with a throwing accessor on the grounds
// that the population of unmeasured consumers is unknown; this measures it instead.
//
// The entry points come from Scripts/repro/1026-null-shape-type-guard/unwrap_sweep.py, resolved to
// the receiver's declared type rather than the local variable name, taken in descending order of
// how many bridge sites reach each one. Each probe runs in a forked child, so a crash is reported
// rather than ending the run.
#include <BRepAdaptor_CompCurve.hxx>
#include <BRepAdaptor_Curve.hxx>
#include <BRepAdaptor_Curve2d.hxx>
#include <BRepAdaptor_Surface.hxx>
#include <BRepGProp_Face.hxx>
#include <ShapeAnalysis_Edge.hxx>
#include <ShapeAnalysis_Wire.hxx>
#include <TopLoc_Location.hxx>
#include <TopoDS_Vertex.hxx>
#include <BRepAlgoAPI_Check.hxx>
#include <BRepAlgoAPI_Common.hxx>
#include <BRepAlgoAPI_Cut.hxx>
#include <BRepAlgoAPI_Fuse.hxx>
#include <BRepAlgoAPI_Section.hxx>
#include <BRepAlgo_Image.hxx>
#include <BRepBndLib.hxx>
#include <BRepBuilderAPI_Copy.hxx>
#include <BRepBuilderAPI_GTransform.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepBuilderAPI_MakeSolid.hxx>
#include <BRepBuilderAPI_MakeWire.hxx>
#include <BRepBuilderAPI_Sewing.hxx>
#include <BRepBuilderAPI_Transform.hxx>
#include <BRepCheck_Analyzer.hxx>
#include <BRepExtrema_DistShapeShape.hxx>
#include <BRepFilletAPI_MakeFillet.hxx>
#include <BRepGProp.hxx>
#include <BRepLib_FindSurface.hxx>
#include <BRepMesh_IncrementalMesh.hxx>
#include <BRepPrimAPI_MakePrism.hxx>
#include <BRepTools.hxx>
#include <BRepTools_Quilt.hxx>
#include <BRepTools_WireExplorer.hxx>
#include <BRep_Builder.hxx>
#include <BRep_Tool.hxx>
#include <GProp_GProps.hxx>
#include <ShapeAnalysis_FreeBounds.hxx>
#include <ShapeAnalysis_ShapeTolerance.hxx>
#include <ShapeFix_Shape.hxx>
#include <ShapeFix_Wireframe.hxx>
#include <ShapeUpgrade_UnifySameDomain.hxx>
#include <STEPControl_Writer.hxx>
#include <TopExp.hxx>
#include <TopExp_Explorer.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopTools_IndexedDataMapOfShapeListOfShape.hxx>
#include <TopTools_ListOfShape.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Compound.hxx>
#include <TopoDS_Iterator.hxx>
#include <TopoDS_Shape.hxx>
#include <Standard_Failure.hxx>
#include <gp_Trsf.hxx>
#include <gp_GTrsf.hxx>
#include <gp_Vec.hxx>

#include <cstdio>
#include <functional>
#include <sstream>
#include <sys/wait.h>
#include <unistd.h>

static int uncatchable = 0, catchable = 0, benign = 0;

static void probe(const char* sites, const char* call, const std::function<void()>& body)
{
  fflush(stdout);
  pid_t pid = fork();
  if (pid == 0)
  {
    try
    {
      body();
    }
    catch (Standard_Failure const&)
    {
      _exit(3);
    }
    catch (...)
    {
      _exit(4);
    }
    _exit(0);
  }
  int st = 0;
  waitpid(pid, &st, 0);
  const char* verdict;
  if (WIFSIGNALED(st))
  {
    verdict = "SIGNAL (uncatchable)";
    uncatchable++;
  }
  else if (WEXITSTATUS(st) == 3)
  {
    verdict = "Standard_Failure";
    catchable++;
  }
  else if (WEXITSTATUS(st) == 4)
  {
    verdict = "other exception";
    catchable++;
  }
  else
  {
    verdict = "returned";
    benign++;
  }
  printf("  %-6s %-52s %s\n", sites, call, verdict);
}

int main()
{
  TopoDS_Shape  ns;  // null, exactly what Shape.nullified wraps
  TopoDS_Face   nf;  // a null TopoDS_Face, what TopoDS::Face(ns) hands back
  TopoDS_Edge   ne;
  TopoDS_Wire   nw;
  TopoDS_Vertex nv;

  printf("#1035: a NULL TopoDS_Shape at every OCCT entry point the bridge hands one to\n");
  printf("(pinned kernel. 'Standard_Failure'/'returned' = the bridge's own catch(...) copes.)\n\n");
  printf("  %-6s %-52s %s\n", "sites", "OCCT entry point", "result");
  printf("  %-6s %-52s %s\n", "------", "----------------------------------------------------",
         "------");

  // --- the casts, 324 sites: #1027 measured these safe across 345 sites, re-measured here ---
  probe("135", "TopoDS::Edge(null)", [&] { (void)TopoDS::Edge(ns); });
  probe("131", "TopoDS::Face(null)", [&] { (void)TopoDS::Face(ns); });
  probe("35", "TopoDS::Wire(null)", [&] { (void)TopoDS::Wire(ns); });
  probe("23", "TopoDS::Vertex(null)", [&] { (void)TopoDS::Vertex(ns); });

  // --- traversal, 68 sites ---
  probe("21", "TopExp::MapShapes(null, TopAbs_FACE, map)", [&] {
    TopTools_IndexedMapOfShape m;
    TopExp::MapShapes(ns, TopAbs_FACE, m);
  });
  probe("5", "TopExp::MapShapesAndAncestors(null, ...)", [&] {
    TopTools_IndexedDataMapOfShapeListOfShape m;
    TopExp::MapShapesAndAncestors(ns, TopAbs_EDGE, TopAbs_FACE, m);
  });
  probe("17", "TopExp_Explorer(null, TopAbs_FACE)", [&] {
    for (TopExp_Explorer e(ns, TopAbs_FACE); e.More(); e.Next())
      (void)e.Current();
  });
  probe("2", "TopoDS_Iterator(null)", [&] {
    for (TopoDS_Iterator it(ns); it.More(); it.Next())
      (void)it.Value();
  });
  probe("3", "BRepTools_WireExplorer(nullWire)", [&] {
    for (BRepTools_WireExplorer e(nw); e.More(); e.Next())
      (void)e.Current();
  });

  // --- the builder, the fourth spelling #1026 found by hand ---
  probe("4", "BRep_Builder::Add(compound, null)", [&] {
    BRep_Builder     b;
    TopoDS_Compound  c;
    b.MakeCompound(c);
    b.Add(c, ns);
  });

  // --- containers ---
  probe("27", "TopTools_ListOfShape::Append(null)", [&] {
    TopTools_ListOfShape l;
    l.Append(ns);
  });

  // --- meshing / IO ---
  probe("15", "BRepMesh_IncrementalMesh(null, 0.1)",
        [&] { BRepMesh_IncrementalMesh m(ns, 0.1); (void)m; });
  probe("7", "STEPControl_Writer::Transfer(null, AsIs)", [&] {
    STEPControl_Writer w;
    (void)w.Transfer(ns, STEPControl_AsIs);
  });
  probe("6", "BRepTools::Write(null, stream)", [&] {
    std::ostringstream os;
    BRepTools::Write(ns, os);
  });

  // --- booleans ---
  probe("14", "BRepAlgoAPI_Section(null, null, false)",
        [&] { BRepAlgoAPI_Section s(ns, ns, Standard_False); (void)s; });
  probe("8", "BRepAlgoAPI_Fuse(null, null)", [&] { BRepAlgoAPI_Fuse f(ns, ns); (void)f; });
  probe("8", "BRepAlgoAPI_Cut(null, null)", [&] { BRepAlgoAPI_Cut f(ns, ns); (void)f; });
  probe("6", "BRepAlgoAPI_Common(null, null)", [&] { BRepAlgoAPI_Common f(ns, ns); (void)f; });
  probe("5", "BRepAlgoAPI_Check(null)", [&] { BRepAlgoAPI_Check c(ns); (void)c; });

  // --- construction / transformation ---
  probe("13", "BRepBuilderAPI_MakeFace(nullWire, true)",
        [&] { BRepBuilderAPI_MakeFace m(nw, Standard_True); (void)m; });
  probe("13", "BRepBuilderAPI_Transform(null, trsf, false)", [&] {
    gp_Trsf t;
    BRepBuilderAPI_Transform x(ns, t, Standard_False);
    (void)x;
  });
  probe("4", "BRepBuilderAPI_Copy(null)", [&] { BRepBuilderAPI_Copy c(ns); (void)c; });
  probe("2", "BRepBuilderAPI_GTransform(null, gtrsf, false)", [&] {
    gp_GTrsf g;
    BRepBuilderAPI_GTransform x(ns, g, Standard_False);
    (void)x;
  });
  probe("2", "BRepPrimAPI_MakePrism(null, vec)",
        [&] { BRepPrimAPI_MakePrism p(ns, gp_Vec(0, 0, 1)); (void)p; });
  probe("1", "BRepBuilderAPI_MakeSolid(nullShell)", [&] {
    BRepBuilderAPI_MakeSolid m;
    m.Add(TopoDS::Shell(ns));
    (void)m;
  });
  probe("1", "BRepBuilderAPI_MakeWire::Add(nullEdge)", [&] {
    BRepBuilderAPI_MakeWire m;
    m.Add(ne);
    (void)m;
  });

  // --- analysis / properties ---
  probe("10", "BRepCheck_Analyzer(null, true)",
        [&] { BRepCheck_Analyzer a(ns, Standard_True); (void)a.IsValid(); });
  probe("10", "BRepExtrema_DistShapeShape(null, null)",
        [&] { BRepExtrema_DistShapeShape d(ns, ns); (void)d; });
  probe("10", "BRepGProp::VolumeProperties(null, props)", [&] {
    GProp_GProps g;
    BRepGProp::VolumeProperties(ns, g);
  });
  probe("6", "BRepBndLib::Add(null, box)", [&] {
    Bnd_Box b;
    BRepBndLib::Add(ns, b);
  });
  probe("8", "ShapeAnalysis_ShapeTolerance::Tolerance(null, 1)", [&] {
    ShapeAnalysis_ShapeTolerance t;
    (void)t.Tolerance(ns, 1);
  });
  probe("4", "ShapeAnalysis_FreeBounds(null)",
        [&] { ShapeAnalysis_FreeBounds f(ns); (void)f; });
  probe("3", "BRepLib_FindSurface(null)", [&] { BRepLib_FindSurface f(ns); (void)f; });

  // --- adaptors and BRep_Tool, reached with a null Edge/Face/Wire from the casts above ---
  probe("9", "BRep_Tool::Curve(nullEdge, f, l)", [&] {
    double f = 0, l = 0;
    (void)BRep_Tool::Curve(ne, f, l);
  });
  probe("7", "BRep_Tool::Surface(nullFace)", [&] { (void)BRep_Tool::Surface(nf); });
  probe("8", "BRep_Tool::Tolerance(nullFace)", [&] { (void)BRep_Tool::Tolerance(nf); });
  probe("7", "BRepAdaptor_Curve(nullEdge)", [&] { BRepAdaptor_Curve a(ne); (void)a; });
  probe("5", "BRepAdaptor_Surface(nullFace)", [&] { BRepAdaptor_Surface a(nf); (void)a; });
  probe("6", "BRepAdaptor_CompCurve(nullWire)", [&] { BRepAdaptor_CompCurve a(nw); (void)a; });

  // --- healing ---
  probe("2", "ShapeFix_Shape(null)  <- OCCTShapeFixerCreate", [&] {
    Handle(ShapeFix_Shape) f = new ShapeFix_Shape(ns);
    (void)f;
  });
  probe("4", "ShapeFix_Wireframe(null)", [&] { ShapeFix_Wireframe w(ns); (void)w; });
  probe("2", "ShapeUpgrade_UnifySameDomain(null)",
        [&] { ShapeUpgrade_UnifySameDomain u(ns); (void)u; });
  probe("1", "BRepBuilderAPI_Sewing::Add(null)", [&] {
    BRepBuilderAPI_Sewing s;
    s.Add(ns);
  });
  probe("1", "BRepTools_Quilt::Add(null)  <- occtQuiltShells", [&] {
    BRepTools_Quilt q;
    q.Add(ns);
  });
  probe("4", "BRepAlgo_Image::SetRoot/Bind/HasImage/IsImage(null)", [&] {
    BRepAlgo_Image i;
    i.SetRoot(ns);
    i.Bind(ns, ns);
    (void)i.HasImage(ns);
    (void)i.IsImage(ns);
  });
  probe("4", "BRepFilletAPI_MakeFillet(null)",
        [&] { BRepFilletAPI_MakeFillet f(ns); (void)f; });

  // --- the rest of BRep_Tool, which is where the cast result usually goes next ---
  probe("2", "BRep_Tool::CurveOnSurface(nullEdge, nullFace, f, l)", [&] {
    double f = 0, l = 0;
    (void)BRep_Tool::CurveOnSurface(ne, nf, f, l);
  });
  probe("1", "BRep_Tool::Pnt(nullVertex)", [&] { (void)BRep_Tool::Pnt(nv); });
  probe("1", "BRep_Tool::Triangulation(nullFace, loc)", [&] {
    TopLoc_Location l;
    (void)BRep_Tool::Triangulation(nf, l);
  });
  probe("1", "BRep_Tool::Degenerated(nullEdge)", [&] { (void)BRep_Tool::Degenerated(ne); });
  probe("1", "BRep_Tool::Range(nullEdge, f, l)", [&] {
    double f = 0, l = 0;
    BRep_Tool::Range(ne, f, l);
  });
  probe("1", "BRep_Tool::IsClosed(null)", [&] { (void)BRep_Tool::IsClosed(ns); });
  probe("1", "BRep_Tool::Polygon3D(nullEdge, loc)", [&] {
    TopLoc_Location l;
    (void)BRep_Tool::Polygon3D(ne, l);
  });
  probe("2", "BRepAdaptor_Curve2d(nullEdge, nullFace)",
        [&] { BRepAdaptor_Curve2d a(ne, nf); (void)a; });
  probe("1", "BRepGProp_Face(nullFace)", [&] { BRepGProp_Face g(nf); (void)g; });
  probe("1", "TopExp::Vertices(nullEdge, v1, v2)", [&] {
    TopoDS_Vertex a, b;
    TopExp::Vertices(ne, a, b);
  });
  probe("1", "ShapeAnalysis_Edge::HasCurve3d(nullEdge)", [&] {
    ShapeAnalysis_Edge s;
    (void)s.HasCurve3d(ne);
  });
  probe("1", "ShapeAnalysis_Wire(nullWire, nullFace, tol)", [&] {
    ShapeAnalysis_Wire s(nw, nf, 1e-7);
    (void)s;
  });
  probe("1", "ShapeFix_Shape(null) then Perform()", [&] {
    Handle(ShapeFix_Shape) f = new ShapeFix_Shape(ns);
    (void)f->Perform();
  });
  probe("1", "ShapeUpgrade_UnifySameDomain(null) then Build()", [&] {
    ShapeUpgrade_UnifySameDomain u(ns);
    u.Build();
  });
  probe("1", "BRepMesh_IncrementalMesh(nullFace, 0.1)",
        [&] { BRepMesh_IncrementalMesh m(nf, 0.1); (void)m; });

  printf("\n%d uncatchable, %d catchable, %d returned\n", uncatchable, catchable, benign);
  return 0;
}
