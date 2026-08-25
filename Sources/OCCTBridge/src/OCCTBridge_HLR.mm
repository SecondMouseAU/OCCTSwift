//
//  OCCTBridge_HLR.mm
//  OCCTSwift
//
//  Objective-C++ bridge implementations for the HLR (Hidden Line Removal) / Drawing domain.
//  Split from OCCTBridge_Modeling.mm (#1071).
//

#import "../include/OCCTBridge.h"
#import "OCCTBridge_Internal.h"

#include <HLRBRep_Algo.hxx>
#include <HLRBRep_HLRToShape.hxx>
#include <HLRAlgo_Projector.hxx>
#include <HLRBRep_PolyAlgo.hxx>
#include <HLRBRep_PolyHLRToShape.hxx>
#include <BRepMesh_IncrementalMesh.hxx>
#include <Bnd_Box.hxx>
#include <BRepBndLib.hxx>
#include <BRep_Builder.hxx>
#include <TopoDS_Compound.hxx>

// Helper: compute how far a shape reaches along a view direction from the world origin.
// Returns false for a shape with no bounds. Used by OCCTDrawingCreate for perspective guard (#1036).
static bool occtDrawingReachAlongDirection(const TopoDS_Shape& shape,
                                           const gp_Dir&       viewDir,
                                           double&             outReach)
{
  Bnd_Box bounds;
  BRepBndLib::Add(shape, bounds);
  if (bounds.IsVoid())
    return false;

  double xmin, ymin, zmin, xmax, ymax, zmax;
  bounds.Get(xmin, ymin, zmin, xmax, ymax, zmax);
  outReach = (viewDir.X() > 0 ? xmax : xmin) * viewDir.X()
             + (viewDir.Y() > 0 ? ymax : ymin) * viewDir.Y()
             + (viewDir.Z() > 0 ? zmax : zmin) * viewDir.Z();
  return true;
}

OCCTDrawingRef OCCTDrawingCreate(OCCTShapeRef       shape,
                                 double             dirX,
                                 double             dirY,
                                 double             dirZ,
                                 OCCTProjectionType projectionType,
                                 double             focus)
{
  if (!shape)
    return nullptr;

  // #999: projectionType used to be read by nothing, so a caller asking for perspective got the
  // orthographic projection silently. focus is what the perspective constructor needs and there is
  // no defensible default for it, so it is a parameter rather than a literal. Reject a
  // non-positive or NaN focus outright: it is a distance, and OCCT does not raise on one. Measured
  // on a 100x50x30 box viewed down +Z, focus 0 and 1e-12 return an empty VCompound and a negative
  // focus returns a real but differently-scaled projection, so neither reads as failure at the call
  // site. (#1036 trimmed this list rather than corrected it: focus 5 and 15 were cited here too,
  // and they do return an empty VCompound on that fixture, but both are positive and both pass this
  // test, so they were never evidence for it. That box spans z [-15, 15], so 5 and 15 put the eye
  // inside it or on its face: they were measuring the straddling case, which this test never
  // rejected and the reach guard below now does. Re-measured in
  // Scripts/repro/1036-perspective-eye-anchor/guard_comment_probe.mm.)
  if (projectionType == OCCTProjectionPerspective && !(focus > 0))
    return nullptr;

  try
  {
    // Normalize direction
    gp_Dir viewDir(dirX, dirY, dirZ);

    // #1036: the projection frame below is anchored at the WORLD origin, so the eye sits at
    // focus * viewDir and the picture plane passes through the origin. HLRAlgo_Projector::Project
    // divides by R = 1 - Z/focus, with Z the point's coordinate in that frame, so a point at or
    // beyond the eye has R <= 0 and comes back mirrored through the origin instead of not at all.
    // Measured on a box spanning x [20,30], z [1000,1010] viewed down +Z: focus 50 returns seven
    // edges spanning x [-1.579, -1.042] where the correct answer is [40, 60.606], focus landing
    // exactly on a face returns coordinates of order 1e17, and an eye plane cutting the shape
    // returns one half mirrored against the other (x [-24.444, 20] for a box at x [20,30]). All
    // three report success, which is the same hazard the focus > 0 test above rejects. The bound is
    // the shape's reach along the view direction from the origin, not its own extent.
    if (projectionType == OCCTProjectionPerspective)
    {
      double reach = 0.0;
      if (!occtDrawingReachAlongDirection(shape->shape, viewDir, reach) || reach >= focus)
        return nullptr;
    }

    gp_Ax2            projAxis(gp_Pnt(0, 0, 0), viewDir);
    HLRAlgo_Projector projector = projectionType == OCCTProjectionPerspective
                                    ? HLRAlgo_Projector(projAxis, focus)
                                    : HLRAlgo_Projector(projAxis);

    // Create HLR algorithm
    Handle(HLRBRep_Algo) hlrAlgo = new HLRBRep_Algo();
    hlrAlgo->Add(shape->shape);
    hlrAlgo->Projector(projector);
    hlrAlgo->Update();
    hlrAlgo->Hide();

    // Extract edges
    HLRBRep_HLRToShape shapes(hlrAlgo);

    OCCTDrawing* drawing    = new OCCTDrawing();
    drawing->visibleSharp   = shapes.VCompound();
    drawing->visibleSmooth  = shapes.Rg1LineVCompound();
    drawing->visibleOutline = shapes.OutLineVCompound();
    drawing->hiddenSharp    = shapes.HCompound();
    drawing->hiddenSmooth   = shapes.Rg1LineHCompound();
    drawing->hiddenOutline  = shapes.OutLineHCompound();

    return drawing;
  }
  catch (...)
  {
    return nullptr;
  }
}

void OCCTDrawingRelease(OCCTDrawingRef drawing)
{
  delete drawing;
}

OCCTShapeRef OCCTDrawingGetEdges(OCCTDrawingRef drawing, OCCTEdgeType edgeType)
{
  if (!drawing)
    return nullptr;

  try
  {
    TopoDS_Shape    result;
    BRep_Builder    builder;
    TopoDS_Compound compound;
    builder.MakeCompound(compound);

    switch (edgeType)
    {
      case OCCTEdgeTypeVisible:
        if (!drawing->visibleSharp.IsNull())
        {
          builder.Add(compound, drawing->visibleSharp);
        }
        if (!drawing->visibleSmooth.IsNull())
        {
          builder.Add(compound, drawing->visibleSmooth);
        }
        if (!drawing->visibleOutline.IsNull())
        {
          builder.Add(compound, drawing->visibleOutline);
        }
        break;

      case OCCTEdgeTypeHidden:
        if (!drawing->hiddenSharp.IsNull())
        {
          builder.Add(compound, drawing->hiddenSharp);
        }
        if (!drawing->hiddenSmooth.IsNull())
        {
          builder.Add(compound, drawing->hiddenSmooth);
        }
        if (!drawing->hiddenOutline.IsNull())
        {
          builder.Add(compound, drawing->hiddenOutline);
        }
        break;

      case OCCTEdgeTypeOutline:
        if (!drawing->visibleOutline.IsNull())
        {
          builder.Add(compound, drawing->visibleOutline);
        }
        if (!drawing->hiddenOutline.IsNull())
        {
          builder.Add(compound, drawing->hiddenOutline);
        }
        break;
    }

    if (compound.IsNull())
      return nullptr;

    return new OCCTShape(compound);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTDrawingRef OCCTDrawingCreatePoly(OCCTShapeRef shape,
                                     double       dirX,
                                     double       dirY,
                                     double       dirZ,
                                     double       deflection)
{
  if (!shape)
    return nullptr;
  try
  {
    // Ensure the shape has a triangulation
    BRepMesh_IncrementalMesh mesh(shape->shape, deflection);

    gp_Dir            viewDir(dirX, dirY, dirZ);
    gp_Ax2            projAxis(gp_Pnt(0, 0, 0), viewDir);
    HLRAlgo_Projector projector(projAxis);

    Handle(HLRBRep_PolyAlgo) polyAlgo = new HLRBRep_PolyAlgo();
    polyAlgo->Projector(projector);
    polyAlgo->Load(shape->shape);
    polyAlgo->Update();

    HLRBRep_PolyHLRToShape shapes;
    shapes.Update(polyAlgo);

    OCCTDrawing* drawing    = new OCCTDrawing();
    drawing->visibleSharp   = shapes.VCompound();
    drawing->visibleSmooth  = shapes.Rg1LineVCompound();
    drawing->visibleOutline = shapes.OutLineVCompound();
    drawing->hiddenSharp    = shapes.HCompound();
    drawing->hiddenSmooth   = shapes.Rg1LineHCompound();
    drawing->hiddenOutline  = shapes.OutLineHCompound();

    return drawing;
  }
  catch (...)
  {
    return nullptr;
  }
}
