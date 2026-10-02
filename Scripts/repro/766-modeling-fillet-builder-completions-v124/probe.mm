// Epic #766, Tests/OCCTModelingTests/FilletBuilderCompletionsV124Tests.swift: kernel parity for
// all six tests. FilletBuilder wraps one BRepFilletAPI_MakeFillet (OCCTFilletBuilderCreate); each
// accessor is the same-named MakeFillet member (Contour, Edge, FirstVertex, LastVertex, Abscissa,
// RelativeAbscissa, Closed, ClosedAndTangent, SetRadius, NbSurfaces, StripeStatus,
// NbComputedSurfaces, NbFaultyContours, NbFaultyVertices). Each test gets a fresh builder on a
// 10 mm box centred at the origin, radius 1 on the first TopExp::MapShapes edge, as in Swift.
#include <BRepFilletAPI_MakeFillet.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRep_Tool.hxx>
#include <TopExp.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopoDS.hxx>
#include <cstdio>

static TopoDS_Shape box() { return BRepPrimAPI_MakeBox(gp_Pnt(-5, -5, -5), 10, 10, 10).Shape(); }

static TopoDS_Edge firstEdge(const TopoDS_Shape& s)
{
  TopTools_IndexedMapOfShape m;
  TopExp::MapShapes(s, TopAbs_EDGE, m);
  return TopoDS::Edge(m(1));
}

int main()
{
  {
    TopoDS_Shape             b = box();
    TopoDS_Edge              e = firstEdge(b);
    BRepFilletAPI_MakeFillet f(b);
    f.Add(1.0, e);
    printf("filletContourAccess: contour=%d nbContours=%d nbEdges=%d\n", f.Contour(e), f.NbContours(),
           f.NbEdges(1));
  }
  {
    TopoDS_Shape             b = box();
    TopoDS_Edge              e = firstEdge(b);
    BRepFilletAPI_MakeFillet f(b);
    f.Add(1.0, e);
    int           ci = f.Contour(e);
    TopoDS_Edge   ce = f.Edge(ci, 1);
    TopoDS_Vertex fv = f.FirstVertex(ci), lv = f.LastVertex(ci);
    gp_Pnt        pf = BRep_Tool::Pnt(fv), pl = BRep_Tool::Pnt(lv);
    printf("filletEdgeVertexQueries: edgeNull=%d sameAsInput=%d firstNull=%d lastNull=%d "
           "first=(%g,%g,%g) last=(%g,%g,%g) abscissa(first)=%.17g relAbscissa(first)=%.17g "
           "abscissa(last)=%.17g relAbscissa(last)=%.17g\n",
           ce.IsNull(), ce.IsSame(e), fv.IsNull(), lv.IsNull(), pf.X(), pf.Y(), pf.Z(), pl.X(), pl.Y(),
           pl.Z(), f.Abscissa(ci, fv), f.RelativeAbscissa(ci, fv), f.Abscissa(ci, lv),
           f.RelativeAbscissa(ci, lv));
  }
  {
    TopoDS_Shape             b = box();
    TopoDS_Edge              e = firstEdge(b);
    BRepFilletAPI_MakeFillet f(b);
    f.Add(1.0, e);
    int ci = f.Contour(e);
    printf("filletClosedAndTangent: closed=%d closedAndTangent=%d\n", f.Closed(ci), f.ClosedAndTangent(ci));
  }
  {
    TopoDS_Shape             b = box();
    TopoDS_Edge              e = firstEdge(b);
    BRepFilletAPI_MakeFillet f(b);
    f.Add(1.0, e);
    f.Build();
    printf("filletSurfaces: done=%d nbSurfaces=%d\n", f.IsDone(), f.IsDone() ? f.NbSurfaces() : -1);
  }
  {
    TopoDS_Shape             b = box();
    TopoDS_Edge              e = firstEdge(b);
    BRepFilletAPI_MakeFillet f(b);
    f.Add(1.0, e);
    int ci = f.Contour(e);
    try
    {
      f.SetRadius(2.0, ci, e);
      printf("filletSetRadius: SetRadius(2, ic, E) ok\n");
    }
    catch (Standard_Failure& ex)
    {
      printf("filletSetRadius: SetRadius(2, ic, E) threw %s\n", ex.what());
    }
    try
    {
      f.SetRadius(1.0, 3.0, ci, 1);
      printf("filletSetRadius: SetRadius(1, 3, ic, 1) ok\n");
    }
    catch (Standard_Failure& ex)
    {
      printf("filletSetRadius: SetRadius(1, 3, ic, 1) threw %s\n", ex.what());
    }
    f.Build();
    printf("filletSetRadius: build after both done=%d\n", f.IsDone());
  }
  {
    TopoDS_Shape             b = box();
    TopoDS_Edge              e = firstEdge(b);
    BRepFilletAPI_MakeFillet f(b);
    f.Add(1.0, e);
    f.Build();
    int ci = f.Contour(e);
    printf("filletStripeAndFaulty: done=%d contour=%d stripeStatus=%d nbComputedSurfaces=%d "
           "nbFaultyContours=%d nbFaultyVertices=%d\n",
           f.IsDone(), ci, (int)f.StripeStatus(ci), f.NbComputedSurfaces(ci), f.NbFaultyContours(),
           f.NbFaultyVertices());
  }
  return 0;
}
