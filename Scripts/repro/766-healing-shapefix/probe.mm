// #766 kernel parity: ShapeFixComposeShell, ShapeFixEdgeConnect, ShapeFixEdgeExtended,
// ShapeFixEdgeProjAux, ShapeFixEdge, ShapeFixerBuilder, ShapeFixing, ShapeFixIntersectionTool,
// ShapeFixSmallSolid, ShapeFixSolid, ShapeFixSplitCommonVertex, ShapeFixTolerance,
// ShapeFixWireframeExt, ShapeFixWireVertex tests. The same ShapeFix_* calls on the same inputs as
// the bridge functions (box = the centred 10 box; indices are TopExp::MapShapes order).
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepBuilderAPI_MakePolygon.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepBuilderAPI_Copy.hxx>
#include <BRepCheck_Analyzer.hxx>
#include <BRepGProp.hxx>
#include <GProp_GProps.hxx>
#include <BRep_Builder.hxx>
#include <BRep_Tool.hxx>
#include <ShapeBuild_ReShape.hxx>
#include <ShapeFix_Edge.hxx>
#include <ShapeFix_EdgeProjAux.hxx>
#include <ShapeFix_FixSmallSolid.hxx>
#include <ShapeFix_IntersectionTool.hxx>
#include <ShapeFix_Shape.hxx>
#include <ShapeFix_ShapeTolerance.hxx>
#include <ShapeFix_Solid.hxx>
#include <ShapeFix_SplitCommonVertex.hxx>
#include <ShapeFix_Wireframe.hxx>
#include <ShapeFix_WireVertex.hxx>
#include <ShapeAnalysis_ShapeTolerance.hxx>
#include <TopExp.hxx>
#include <TopExp_Explorer.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopoDS.hxx>
#include <cstdio>

static int unique(const TopoDS_Shape& s, TopAbs_ShapeEnum t)
{
  TopTools_IndexedMapOfShape m;
  TopExp::MapShapes(s, t, m);
  return m.Extent();
}

static double vol(const TopoDS_Shape& s)
{
  GProp_GProps g;
  BRepGProp::VolumeProperties(s, g);
  return g.Mass();
}

static TopoDS_Shape box(double x = -5, double y = -5, double z = -5, double w = 10, double h = 10, double d = 10)
{
  return BRepPrimAPI_MakeBox(gp_Pnt(x, y, z), w, h, d).Shape();
}

int main()
{
  {
    TopoDS_Shape               b = box();
    TopTools_IndexedMapOfShape e, f;
    TopExp::MapShapes(b, TopAbs_EDGE, e);
    TopExp::MapShapes(b, TopAbs_FACE, f);
    TopoDS_Edge   e0 = TopoDS::Edge(e(1));
    TopoDS_Face   f0 = TopoDS::Face(f(1));
    ShapeFix_Edge sfe;
    printf("edge0: FixRemoveCurve3d=%d FixAddCurve3d=%d FixAddPCurve(face0)=%d FixRemovePCurve(face0)=%d FixReversed2d(face0)=%d\n",
           (int)sfe.FixRemoveCurve3d(e0), (int)sfe.FixAddCurve3d(e0), (int)sfe.FixAddPCurve(e0, f0, false),
           (int)sfe.FixRemovePCurve(e0, f0), (int)sfe.FixReversed2d(e0, f0));
  }
  {
    TopoDS_Shape b = box();
    TopoDS_Face  f0 = TopoDS::Face(TopExp_Explorer(b, TopAbs_FACE).Current());
    TopoDS_Edge  e0 = TopoDS::Edge(TopExp_Explorer(f0, TopAbs_EDGE).Current());
    Handle(ShapeFix_EdgeProjAux) aux = new ShapeFix_EdgeProjAux(f0, e0);
    aux->Compute(1e-6);
    printf("EdgeProjAux(face0, edge0): firstDone=%d first=%g lastDone=%d last=%g\n", (int)aux->IsFirstDone(),
           aux->FirstParam(), (int)aux->IsLastDone(), aux->LastParam());
  }
  {
    TopoDS_Shape b     = box();
    int          sp    = 0, vt = 0;
    Handle(ShapeFix_Edge) sfe = new ShapeFix_Edge();
    for (TopExp_Explorer x(b, TopAbs_EDGE); x.More(); x.Next())
    {
      if (sfe->FixSameParameter(TopoDS::Edge(x.Current()), 0))
        sp++;
      if (sfe->FixVertexTolerance(TopoDS::Edge(x.Current())))
        vt++;
    }
    printf("box edges (explored, 24): FixSameParameter count=%d FixVertexTolerance count=%d\n", sp, vt);
  }
  {
    TopoDS_Shape           b  = box();
    Handle(ShapeFix_Shape) sf = new ShapeFix_Shape(b);
    sf->SetPrecision(1e-7);
    sf->SetMaxTolerance(1.0);
    sf->SetMinTolerance(1e-10);
    bool done = sf->Perform();
    printf("ShapeFixer(box) Perform=%d valid=%d type=%d volume=%.9f FAIL=%d\n", (int)done,
           (int)BRepCheck_Analyzer(sf->Shape()).IsValid(), (int)sf->Shape().ShapeType(), vol(sf->Shape()),
           (int)sf->Status(ShapeExtend_FAIL));
  }
  for (int mode = 0; mode < 2; mode++)
  {
    TopoDS_Shape           b  = box();
    Handle(ShapeFix_Shape) sf = new ShapeFix_Shape(b);
    sf->SetPrecision(0.001);
    sf->FixSolidMode()     = mode == 0 ? 1 : 0;
    sf->FixFreeShellMode() = 1;
    sf->FixFreeFaceMode()  = 1;
    sf->FixFreeWireMode()  = 1;
    sf->Perform();
    printf("fixed(0.001, fixSolid=%d): valid=%d type=%d volume=%.9f\n", mode == 0, (int)BRepCheck_Analyzer(sf->Shape()).IsValid(),
           (int)sf->Shape().ShapeType(), vol(sf->Shape()));
  }
  {
    TopoDS_Shape           b  = box();
    Handle(ShapeFix_Shape) sf = new ShapeFix_Shape(b);
    sf->Perform();
    printf("healed(box) (ShapeFix_Shape): valid=%d volume=%.9f\n", (int)BRepCheck_Analyzer(sf->Shape()).IsValid(), vol(sf->Shape()));
  }
  {
    TopoDS_Shape b = box();
    TopoDS_Face  f0 = TopoDS::Face(TopExp_Explorer(b, TopAbs_FACE).Current());
    Handle(ShapeBuild_ReShape) ctx = new ShapeBuild_ReShape();
    ShapeFix_IntersectionTool  tool(ctx, 1e-6, 1.0);
    printf("IntersectionTool FixIntersectingWires(box face0)=%d\n", (int)tool.FixIntersectingWires(f0));
  }
  {
    BRepBuilderAPI_MakePolygon po(gp_Pnt(-10, -10, 0), gp_Pnt(10, -10, 0), gp_Pnt(10, 10, 0), gp_Pnt(-10, 10, 0), true);
    BRepBuilderAPI_MakePolygon ph(gp_Pnt(5, -5, 0), gp_Pnt(15, -5, 0), gp_Pnt(15, 5, 0), gp_Pnt(5, 5, 0), true);
    BRepBuilderAPI_MakeFace    mf(po.Wire(), true);
    TopoDS_Wire                h = ph.Wire();
    h.Reverse();
    mf.Add(h);
    TopoDS_Shape s = mf.Face();
    int          before = unique(s, TopAbs_EDGE);
    Handle(ShapeBuild_ReShape) ctx = new ShapeBuild_ReShape();
    ShapeFix_IntersectionTool  tool(ctx, 1e-6, 1.0);
    bool                       done = tool.FixIntersectingWires(TopoDS::Face(s));
    s                               = ctx->Apply(s);
    printf("overlapping hole face: edges before=%d FixIntersectingWires=%d edges after=%d\n", before, (int)done,
           unique(s, TopAbs_EDGE));
  }
  {
    BRep_Builder    bb;
    TopoDS_Compound c;
    bb.MakeCompound(c);
    bb.Add(c, box());
    bb.Add(c, box(20 - 0.005, -0.005, -0.005, 0.01, 0.01, 0.01));
    Handle(ShapeFix_FixSmallSolid) fx = new ShapeFix_FixSmallSolid();
    fx->SetVolumeThreshold(1.0);
    Handle(ShapeBuild_ReShape) ctx = new ShapeBuild_ReShape();
    TopoDS_Shape               r   = fx->Remove(c, ctx);
    printf("FixSmallSolid Remove(big + tiny, 1.0): solids=%d volume=%.6f\n", unique(r, TopAbs_SOLID), vol(r));
    TopoDS_Compound c2;
    bb.MakeCompound(c2);
    bb.Add(c2, box(0, 0, 0, 10, 10, 10));
    bb.Add(c2, box(10, 0, 0, 0.01, 10, 10));
    Handle(ShapeFix_FixSmallSolid) fm = new ShapeFix_FixSmallSolid();
    fm->SetWidthFactorThreshold(1.0);
    Handle(ShapeBuild_ReShape) ctx2 = new ShapeBuild_ReShape();
    TopoDS_Shape               r2   = fm->Merge(c2, ctx2);
    printf("FixSmallSolid Merge(big + thin slab, 1.0): null=%d solids=%d valid=%d volume=%.6f\n", (int)r2.IsNull(),
           r2.IsNull() ? -1 : unique(r2, TopAbs_SOLID), r2.IsNull() ? -1 : (int)BRepCheck_Analyzer(r2).IsValid(),
           r2.IsNull() ? 0.0 : vol(r2));
  }
  {
    TopoDS_Shape b = box();
    ShapeFix_Solid fs(TopoDS::Solid(b));
    fs.Perform();
    ShapeFix_Solid fs2;
    TopoDS_Solid   so = fs2.SolidFromShell(TopoDS::Shell(TopExp_Explorer(b, TopAbs_SHELL).Current()));
    printf("ShapeFix_Solid(box): type=%d valid=%d volume=%.6f; SolidFromShell: type=%d volume=%.6f\n",
           (int)fs.Shape().ShapeType(), (int)BRepCheck_Analyzer(fs.Shape()).IsValid(), vol(fs.Shape()), (int)so.ShapeType(),
           vol(so));
  }
  {
    TopoDS_Shape               b = box();
    ShapeFix_SplitCommonVertex sp;
    sp.Init(b);
    sp.Perform();
    printf("SplitCommonVertex(box): valid=%d vertices=%d volume=%.6f\n", (int)BRepCheck_Analyzer(sp.Shape()).IsValid(),
           unique(sp.Shape(), TopAbs_VERTEX), vol(sp.Shape()));
  }
  {
    TopoDS_Shape            b = box();
    ShapeFix_ShapeTolerance st;
    st.SetTolerance(b, 1e-5);
    ShapeAnalysis_ShapeTolerance sat;
    printf("SetTolerance(box, 1e-5): valid=%d max=%.3e min=%.3e\n", (int)BRepCheck_Analyzer(b).IsValid(),
           sat.Tolerance(b, 1), sat.Tolerance(b, -1));
    TopoDS_Shape b2 = box();
    bool         l  = st.LimitTolerance(b2, 1e-7, 1e-3);
    printf("LimitTolerance(box, 1e-7, 1e-3)=%d valid=%d max=%.3e\n", (int)l, (int)BRepCheck_Analyzer(b2).IsValid(),
           sat.Tolerance(b2, 1));
    TopoDS_Shape b3 = box();
    st.SetTolerance(b3, 0.5);
    printf("SetTolerance(box, 0.5): max=%.3e min=%.3e\n", sat.Tolerance(b3, 1), sat.Tolerance(b3, -1));
  }
  {
    TopoDS_Shape               b  = box(0, 0, 0);
    Handle(ShapeFix_Wireframe) fw = new ShapeFix_Wireframe(b);
    fw->SetPrecision(1e-7);
    fw->FixWireGaps();
    printf("FixWireGaps(box): valid=%d edges=%d volume=%.6f\n", (int)BRepCheck_Analyzer(fw->Shape()).IsValid(),
           unique(fw->Shape(), TopAbs_EDGE), vol(fw->Shape()));
    for (int drop = 1; drop >= 0; drop--)
    {
      Handle(ShapeFix_Wireframe) fs = new ShapeFix_Wireframe(b);
      fs->SetPrecision(1e-7);
      fs->ModeDropSmallEdges() = drop;
      if (!drop)
        fs->SetLimitAngle(0.01);
      fs->FixSmallEdges();
      printf("FixSmallEdges(box, drop=%d): valid=%d edges=%d volume=%.6f\n", drop, (int)BRepCheck_Analyzer(fs->Shape()).IsValid(),
             unique(fs->Shape(), TopAbs_EDGE), vol(fs->Shape()));
    }
  }
  {
    TopoDS_Shape b     = box();
    int          total = 0;
    for (TopExp_Explorer x(b, TopAbs_WIRE); x.More(); x.Next())
    {
      ShapeFix_WireVertex wv;
      wv.Init(TopoDS::Wire(x.Current()), 1e-4);
      total += wv.Fix();
    }
    printf("WireVertex Fix(box wires, 1e-4) total=%d\n", total);
  }
  return 0;
}
