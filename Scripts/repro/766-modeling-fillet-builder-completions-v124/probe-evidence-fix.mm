// Epic #766 evidence correction for PR #2691 (Tests/OCCTModelingTests/FilletBuilderCompletionsV124Tests.swift).
// probe.mm printed the kernel side under the OCCT member names (Contour, NbContours, NbEdges(1), ...)
// and as prose ("no exception", "ChFiDS_Ok (0)"); the bridge side used the Swift names. The parity
// records now carry the same keys and types on both sides, so this probe repeats the same calls and
// prints them under those keys, every flag as true/false and every double at %.17g, one
// `label: key=value ...` line per test. Mapping to the OCCT members: contour = Contour(E),
// contourCount = NbContours(), edgeCount = NbEdges(1), firstVertex/lastVertex = the points of
// FirstVertex(1)/LastVertex(1), abscissa/relativeAbscissa = Abscissa/RelativeAbscissa(1, V),
// closed = Closed(1), closedAndTangent = ClosedAndTangent(1), done = IsDone() after Build(),
// surfaceCount = NbSurfaces(), setRadius/setTwoRadii = the SetRadius overload did not throw,
// stripeStatus = StripeStatus(1) ordinal, computedSurfaceCount = NbComputedSurfaces(1),
// faultyContours = NbFaultyContours(), faultyVertices = NbFaultyVertices().
// Each test gets a fresh builder on a 10 mm box centred at the origin, radius 1 on the first
// TopExp::MapShapes edge, as in Swift.
#include <BRepFilletAPI_MakeFillet.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRep_Tool.hxx>
#include <TopExp.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopoDS.hxx>
#include <cstdio>

static const char* tf(bool b) { return b ? "true" : "false"; }

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
    printf("filletContourAccess: contour=%d contourCount=%d edgeCount=%d\n", f.Contour(e), f.NbContours(),
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
    printf("filletEdgeVertexQueries: edgeSameAsInput=%s firstVertex=[%.17g,%.17g,%.17g] "
           "lastVertex=[%.17g,%.17g,%.17g] abscissa(first)=%.17g relativeAbscissa(first)=%.17g "
           "abscissa(last)=%.17g relativeAbscissa(last)=%.17g\n",
           tf(!ce.IsNull() && ce.IsSame(e)), pf.X(), pf.Y(), pf.Z(), pl.X(), pl.Y(), pl.Z(),
           f.Abscissa(ci, fv), f.RelativeAbscissa(ci, fv), f.Abscissa(ci, lv), f.RelativeAbscissa(ci, lv));
  }
  {
    TopoDS_Shape             b = box();
    TopoDS_Edge              e = firstEdge(b);
    BRepFilletAPI_MakeFillet f(b);
    f.Add(1.0, e);
    int ci = f.Contour(e);
    printf("filletClosedAndTangent: closed=%s closedAndTangent=%s\n", tf(f.Closed(ci)),
           tf(f.ClosedAndTangent(ci)));
  }
  {
    TopoDS_Shape             b = box();
    TopoDS_Edge              e = firstEdge(b);
    BRepFilletAPI_MakeFillet f(b);
    f.Add(1.0, e);
    f.Build();
    printf("filletSurfaces: done=%s surfaceCount=%d\n", tf(f.IsDone()), f.IsDone() ? f.NbSurfaces() : -1);
  }
  {
    TopoDS_Shape             b = box();
    TopoDS_Edge              e = firstEdge(b);
    BRepFilletAPI_MakeFillet f(b);
    f.Add(1.0, e);
    int  ci       = f.Contour(e);
    bool setOne   = true;
    bool setTwo   = true;
    try
    {
      f.SetRadius(2.0, ci, e);
    }
    catch (Standard_Failure&)
    {
      setOne = false;
    }
    try
    {
      f.SetRadius(1.0, 3.0, ci, 1);
    }
    catch (Standard_Failure&)
    {
      setTwo = false;
    }
    f.Build();
    printf("filletSetRadius: setRadius=%s setTwoRadii=%s builtAfter=%s\n", tf(setOne), tf(setTwo),
           tf(f.IsDone()));
  }
  {
    TopoDS_Shape             b = box();
    TopoDS_Edge              e = firstEdge(b);
    BRepFilletAPI_MakeFillet f(b);
    f.Add(1.0, e);
    f.Build();
    int ci = f.Contour(e);
    printf("filletStripeAndFaulty: stripeStatus=%d computedSurfaceCount=%d faultyContours=%d faultyVertices=%d\n",
           (int)f.StripeStatus(ci), f.NbComputedSurfaces(ci), f.NbFaultyContours(), f.NbFaultyVertices());
  }
  return 0;
}
