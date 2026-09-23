// Kernel-parity probe for #1986 (Epic #766): BRepGraphStatsTests, BRepGraphSupplementVertexTests,
// BRepGraphTransformTests, BRepGraphUVGridTests, BRepGraphValidateTests,
// BRepGraphVertexGeometryTests, BRepGraphVertexQueryTests, BRepGraphWireExtendedTests.
// Each block calls the OCCT API the named bridge function calls, on the Swift test's inputs.
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeSphere.hxx>
#include <BRepBuilderAPI_MakeVertex.hxx>
#include <BRepTools.hxx>
#include <GeomLProp_SLProps.hxx>
#include <Precision.hxx>
#include <TopoDS.hxx>
#include <BRepGraph.hxx>
#include <BRepGraph_TopoView.hxx>
#include <BRepGraph_Tool.hxx>
#include <BRepGraph_ShapesView.hxx>
#include <BRepGraph_EditorView.hxx>
#include <BRepGraph_ReverseIterator.hxx>
#include <BRepGraph_Validate.hxx>
#include <BRepGraph_Copy.hxx>
#include <BRepGraph_Transform.hxx>
#include <BRepGraph_SupplementEditor.hxx>
#include <BRepGraph_SupplementIterator.hxx>
#include <BRepGraph_LayerTopoSupplement.hxx>
#include <BRepGraphInc_Relations.hxx>
#include <cmath>
#include <cstdio>

static TopoDS_Shape box(double w, double h, double d)
{
  return BRepPrimAPI_MakeBox(gp_Pnt(-w / 2, -h / 2, -d / 2), w, h, d).Shape(); // OCCTShapeCreateBox
}

static void build(BRepGraph& g, const TopoDS_Shape& s) // OCCTBRepGraphCreate
{
  g.Clear();
  BRepGraph::ShapesView::Options opts;
  opts.Parallel          = false;
  opts.CreateAutoProduct = false;
  (void)g.Shapes().Add(s, opts);
}

static int faceDirectCount(const BRepGraph& g, int face) // bgSupplementCount
{
  int n = 0;
  for (BRepGraph_SupplementIterator it(g, BRepGraph_NodeId(BRepGraph_NodeId::Kind::Face, face));
       it.More(); it.Next())
    if (it.Value().Kind == BRepGraph_LayerTopoSupplement::AttachmentKind::FaceDirectVertex)
      ++n;
  return n;
}

static void grid(BRepGraph& g, int faceIndex, int nu, int nv, const char* label)
{ // OCCTBRepGraphSampleFaceUVGrid
  TopoDS_Shape fs = g.Shapes().Shape(BRepGraph_NodeId(BRepGraph_NodeId::Kind::Face, faceIndex));
  if (fs.IsNull() || nu < 1 || nv < 1)
  {
    printf("%s: no sample (null face or zero count)\n", label);
    return;
  }
  double u0, u1, v0, v1;
  BRepTools::UVBounds(TopoDS::Face(fs), u0, u1, v0, v1);
  auto&  s  = BRepGraph_Tool::Face::Surface(g, BRepGraph_FaceId(faceIndex));
  double du = nu > 1 ? (u1 - u0) / (nu - 1) : 0, dv = nv > 1 ? (v1 - v0) / (nv - 1) : 0;
  printf("%s: count=%d uv=[%.6f,%.6f]x[%.6f,%.6f]\n", label, nu * nv, u0, u1, v0, v1);
  for (int iu = 0; iu < nu; ++iu)
    for (int iv = 0; iv < nv; ++iv)
    {
      GeomLProp_SLProps p(s, u0 + iu * du, v0 + iv * dv, 2, Precision::Confusion());
      gp_Pnt            q = p.Value();
      gp_Dir            n = p.IsNormalDefined() ? p.Normal() : gp_Dir(0, 0, 1);
      printf("  [%d] pos=(%.6f,%.6f,%.6f) nrm=(%.6f,%.6f,%.6f)%s K=%.9f H=%.9f%s\n",
             iu * nv + iv, q.X(), q.Y(), q.Z(), n.X(), n.Y(), n.Z(),
             p.IsNormalDefined() ? "" : "(undef)", p.IsCurvatureDefined() ? p.GaussianCurvature() : 0.0,
             p.IsCurvatureDefined() ? p.MeanCurvature() : 0.0, p.IsCurvatureDefined() ? "" : " (curv undef)");
    }
}

int main()
{
  BRepGraph g;
  build(g, box(10, 10, 10));

  // OCCTBRepGraphGetStats
  auto& t = g.Topo();
  printf("stats: solids=%d shells=%d faces=%d wires=%d edges=%d vertices=%d coedges=%d "
         "compounds=%d totalNodes=%d surfaces=%d curves3d=%d curves2d=%d\n",
         (int)t.Solids().Nb(), (int)t.Shells().Nb(), (int)t.Faces().Nb(), (int)t.Wires().Nb(),
         (int)t.Edges().Nb(), (int)t.Vertices().Nb(), (int)t.CoEdges().Nb(),
         (int)t.Compounds().Nb(), (int)t.Gen().NbNodes(), (int)t.Geometry().NbFaceSurfaces(),
         (int)t.Geometry().NbEdgeCurves3D(), (int)t.Geometry().NbCoEdgeCurves2D());

  // Supplement: OCCTBRepGraphFaceNbVertexRefs / FaceAddVertex / FaceRemoveVertex /
  // EdgeAddInternalVertex / FaceIsNaturalRestriction
  {
    BRepGraph sg;
    build(sg, box(10, 10, 10));
    printf("supplement: faceDirect(0) before=%d\n", faceDirectCount(sg, 0));
    TopoDS_Vertex v = BRepBuilderAPI_MakeVertex(
                        BRepGraph_Tool::Vertex::Pnt(sg, BRepGraph_VertexId(0)))
                        .Vertex();
    uint64_t uid = sg.Editor().Supplement().AttachToFace(
      BRepGraph_FaceId(0), v, BRepGraph_LayerTopoSupplement::AttachmentKind::FaceDirectVertex);
    printf("supplement: face uid=%llu after add=%d\n", (unsigned long long)uid,
           faceDirectCount(sg, 0));
    bool r1 = sg.Editor().Supplement().RemoveAttachment(uid);
    printf("supplement: remove1=%d after=%d\n", r1 ? 1 : 0, faceDirectCount(sg, 0));
    bool r2 = sg.Editor().Supplement().RemoveAttachment(uid);
    printf("supplement: remove2=%d\n", r2 ? 1 : 0);
    uint64_t euid = sg.Editor().Supplement().AttachToEdge(
      BRepGraph_EdgeId(0), v, BRepGraph_LayerTopoSupplement::AttachmentKind::EdgeInternalVertex);
    printf("supplement: edge uid=%llu\n", (unsigned long long)euid);
    for (int i = 0; i < (int)sg.Topo().Faces().Nb(); ++i)
      printf("naturalRestriction(%d)=%d nbWires=%d\n", i,
             BRepGraph_Tool::Face::NbWires(sg, BRepGraph_FaceId(i)) == 0 ? 1 : 0,
             (int)BRepGraph_Tool::Face::NbWires(sg, BRepGraph_FaceId(i)));
  }

  // OCCTBRepGraphTransformTranslation
  for (int copy = 1; copy >= 0; --copy)
  {
    double  dx = copy ? 100 : 10, dy = copy ? 200 : 0, dz = copy ? 300 : 0;
    gp_Trsf tr;
    tr.SetTranslation(gp_Vec(dx, dy, dz));
    BRepGraph out;
    bool      ok = BRepGraph_Transform::Perform(
      g, out, tr, copy ? BRepGraph_Copy::GeomPolicy::Copy : BRepGraph_Copy::GeomPolicy::Share);
    gp_Pnt p0 = BRepGraph_Tool::Vertex::Pnt(g, BRepGraph_VertexId(0));
    gp_Pnt p1 = BRepGraph_Tool::Vertex::Pnt(out, BRepGraph_VertexId(0));
    printf("transform copy=%d ok=%d faces=%d edges=%d vertices=%d v0=(%.6f,%.6f,%.6f) -> "
           "(%.6f,%.6f,%.6f)\n",
           copy, ok ? 1 : 0, (int)out.Topo().Faces().Nb(), (int)out.Topo().Edges().Nb(),
           (int)out.Topo().Vertices().Nb(), p0.X(), p0.Y(), p0.Z(), p1.X(), p1.Y(), p1.Z());
  }

  // OCCTBRepGraphValidate / OCCTBRepGraphValidateDetailed
  {
    auto r = BRepGraph_Validate::Perform(g);
    printf("validate: isValid=%d errors=%d warnings=%d\n", r.IsValid() ? 1 : 0,
           r.NbIssues(BRepGraph_Validate::Severity::Error),
           r.NbIssues(BRepGraph_Validate::Severity::Warning));
  }

  // OCCTBRepGraphVertexPoint on box(10,20,30), OCCTBRepGraphVertexTolerance on box(10,10,10)
  {
    BRepGraph vg;
    build(vg, box(10, 20, 30));
    gp_Pnt p = BRepGraph_Tool::Vertex::Pnt(vg, BRepGraph_VertexId(0));
    printf("vertexPoint(0) box10x20x30=(%.6f,%.6f,%.6f)\n", p.X(), p.Y(), p.Z());
    printf("vertexTolerance(0)=%.3e\n", BRepGraph_Tool::Vertex::Tolerance(g, BRepGraph_VertexId(0)));
    printf("vertexEdges(0) count=%d\n", (int)g.Topo().Vertices().Edges(BRepGraph_VertexId(0)).Size());
  }

  // OCCTBRepGraphWireIsClosed / WireNbCoEdges / WireFaceCount / WireFaceIndices
  for (int w = 0; w < (int)g.Topo().Wires().Nb(); ++w)
  {
    const auto& rel = g.Topo().Wires().Relations(BRepGraph_WireId(w));
    int         n = 0, first = -1;
    for (BRepGraph_FacesOfWire it(g, rel.ParentWireRefIds); it.More(); it.Next())
    {
      if (n == 0)
        first = (int)it.CurrentId().Index;
      ++n;
    }
    printf("wire %d: closed=%d coedges=%d faces=%d firstFace=%d\n", w,
           BRepGraph_Tool::Wire::IsClosed(g, BRepGraph_WireId(w)) ? 1 : 0,
           (int)BRepGraph_Tool::Wire::NbCoEdges(g, BRepGraph_WireId(w)), n, first);
  }

  // OCCTBRepGraphSampleFaceUVGrid
  grid(g, 0, 5, 5, "sampleBoxFace");
  grid(g, 0, 1, 1, "sampleSinglePoint");
  printf("sampleInvalidFace: faces=%d, face 999 -> Shape() null=%d\n", (int)g.Topo().Faces().Nb(),
         (int)(999 >= (int)g.Topo().Faces().Nb()));
  grid(g, 0, 0, 5, "sampleZeroCounts");
  {
    BRepGraph sp;
    build(sp, BRepPrimAPI_MakeSphere(5).Shape());
    printf("sphere faces=%d\n", (int)sp.Topo().Faces().Nb());
    grid(sp, 0, 4, 4, "sampleSphereFace");
  }
  return 0;
}
