// Kernel-parity probe for #1986 (Epic #766): Issue617FaceGridLayoutTests. Builds the test's
// asymmetric 4x3 Bezier patch, makes a face of it, and evaluates the grid slots
// OCCTBRepGraphSampleFaceUVGrid writes (BRepTools::UVBounds + GeomLProp_SLProps), printing
// the U-major index (iu * vSamples + iv) next to each (u, v), so a transposed layout is
// visible as a slot whose position belongs to a different (u, v).
#include <Geom_BezierSurface.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepTools.hxx>
#include <BRep_Tool.hxx>
#include <GeomLProp_SLProps.hxx>
#include <Precision.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Face.hxx>
#include <NCollection_Array2.hxx>
#include <BRepGraph.hxx>
#include <BRepGraph_ShapesView.hxx>
#include <BRepGraph_Tool.hxx>
#include <cstdio>

int main()
{
  const double P[4][3][3] = {{{0, 0, 0}, {0, 4, 3}, {0, 8, 0}},
                             {{7, 0, 5}, {7, 4, 11}, {7, 8, 4}},
                             {{14, 0, 2}, {14, 4, 9}, {14, 8, 1}},
                             {{21, 0, 0}, {21, 4, 6}, {21, 8, 3}}};
  NCollection_Array2<gp_Pnt> poles(1, 4, 1, 3);
  for (int i = 0; i < 4; ++i)
    for (int j = 0; j < 3; ++j)
      poles.SetValue(i + 1, j + 1, gp_Pnt(P[i][j][0], P[i][j][1], P[i][j][2]));
  Handle(Geom_BezierSurface) s = new Geom_BezierSurface(poles);
  TopoDS_Face                f = BRepBuilderAPI_MakeFace(s, 0.0, 1.0, 0.0, 1.0, 1e-6).Face(); // Surface.toFace(): domain, tol 1e-6

  BRepGraph g;
  g.Clear();
  BRepGraph::ShapesView::Options opts;
  opts.Parallel          = false;
  opts.CreateAutoProduct = false;
  (void)g.Shapes().Add(f, opts);
  TopoDS_Face gf =
    TopoDS::Face(g.Shapes().Shape(BRepGraph_NodeId(BRepGraph_NodeId::Kind::Face, 0)));
  double u0, u1, v0, v1;
  BRepTools::UVBounds(gf, u0, u1, v0, v1);
  printf("uv bounds [%.6f, %.6f] x [%.6f, %.6f]\n", u0, u1, v0, v1);
  auto& gs = BRepGraph_Tool::Face::Surface(g, BRepGraph_FaceId(0));

  for (auto dims : {std::pair<int, int>(10, 3), std::pair<int, int>(3, 10)})
  {
    int nu = dims.first, nv = dims.second;
    printf("grid %dx%d:\n", nu, nv);
    for (int iu = 0; iu < nu; ++iu)
      for (int iv = 0; iv < nv; ++iv)
      {
        if (!((iu == 0 && iv == 0) || (iu == nu - 1 && iv == nv - 1) || (iu == 1 && iv == 2)
              || (iu == 2 && iv == 1)))
          continue;
        double            u = u0 + iu * (u1 - u0) / (nu - 1), v = v0 + iv * (v1 - v0) / (nv - 1);
        GeomLProp_SLProps pr(gs, u, v, 2, Precision::Confusion());
        gp_Pnt            p = pr.Value();
        gp_Dir            n = pr.Normal();
        printf("  slot %2d (iu %d, iv %d) uv=(%.4f, %.4f) pos=(%.9f, %.9f, %.9f) "
               "nrm=(%.6f, %.6f, %.6f)\n",
               iu * nv + iv, iu, iv, u, v, p.X(), p.Y(), p.Z(), n.X(), n.Y(), n.Z());
      }
  }
  return 0;
}
