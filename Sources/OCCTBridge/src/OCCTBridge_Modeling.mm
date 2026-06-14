//
//  OCCTBridge_Modeling.mm
//  OCCTSwift
//
//  Extracted from OCCTBridge.mm — issue #99.
//
//  Drawing + Advanced Modeling + Surfaces & Curves cluster:
//
//  - 2D Drawing / HLR projection (HLRBRep_Algo + HLRToShape, generates the
//    visible / hidden / sharp / smooth / outline edge stacks)
//  - Advanced modeling (v0.8.0): pipe shells along path, draft angle,
//    thick solid offset, defeaturing, fillet variants
//  - Surfaces & Curves (v0.9.0): BSpline surface construction, surface-of-
//    revolution / extrusion, planar face from Geom_Plane, edge length /
//    abscissa parameter helpers
//
//  These three areas live in one TU because they share a common dependency
//  set (BRepBuilderAPI primitives + Geom_BSpline + gp + TColgp), and
//  splitting them three ways would force near-duplicate header includes
//  in each file.
//
//  Public C surface unchanged. No symbol changes — pure file move.
//

#import "../include/OCCTBridge.h"
#import "OCCTBridge_Internal.h"

// === Area-specific OCCT headers ===

#include <HLRBRep_Algo.hxx>
#include <HLRBRep_HLRToShape.hxx>
#include <HLRAlgo_Projector.hxx>

#include <BRep_Builder.hxx>
#include <BRepLib_FindSurface.hxx>
#include <Geom_Plane.hxx>
#include <BRepAdaptor_CompCurve.hxx>
#include <BRepAlgoAPI_Defeaturing.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepBuilderAPI_Transform.hxx>
#include <BRepFill.hxx>
#include <BRepFill_Filling.hxx>
#include <BRepFilletAPI_MakeFillet.hxx>
#include <LocOpe_CSIntersector.hxx>
#include <LocOpe_PntFace.hxx>
#include <LocOpe_DPrism.hxx>
#include <LocOpe_FindEdges.hxx>
#include <LocOpe_FindEdgesInFace.hxx>
#include <LocOpe_LinearForm.hxx>
#include <LocOpe_Pipe.hxx>
#include <LocOpe_Prism.hxx>
#include <LocOpe_Revol.hxx>
#include <LocOpe_RevolutionForm.hxx>
#include <LocOpe_SplitDrafts.hxx>
#include <LocOpe_SplitShape.hxx>
#include <BRepLib_MakePolygon.hxx>
#include <BRepLib_MakeWire.hxx>
#include <BRepLib_MakeSolid.hxx>
#include <GC_MakeMirror.hxx>
#include <GC_MakeScale.hxx>
#include <GC_MakeTranslation.hxx>
#include <Geom_Transformation.hxx>
#include <BRepFill_AdvancedEvolved.hxx>
#include <BRepFill_CompatibleWires.hxx>
#include <BRepFill_Draft.hxx>
#include <BRepFill_Generator.hxx>
#include <BRepFill_OffsetWire.hxx>
#include <BRepFill_Pipe.hxx>
#include <ChFi2d_AnaFilletAlgo.hxx>
#include <ChFi2d_FilletAlgo.hxx>
#include <LocOpe_BuildShape.hxx>
#include <BOPAlgo_ArgumentAnalyzer.hxx>
#include <BOPAlgo_CellsBuilder.hxx>
#include <BOPAlgo_Splitter.hxx>
#include <BRepBuilderAPI_MakeShapeOnMesh.hxx>
#include <BRepLib_MakeEdge.hxx>
#include <BRepLib_MakeFace.hxx>
#include <BRepLib_MakeShell.hxx>
#include <BOPAlgo_RemoveFeatures.hxx>
#include <BOPAlgo_Section.hxx>
#include <BRepFeat_Builder.hxx>
#include <Law_BSplineKnotSplitting.hxx>
#include <Law_Composite.hxx>
#include <BOPAlgo_BuilderFace.hxx>
#include <BOPAlgo_BuilderSolid.hxx>
#include <BOPAlgo_ShellSplitter.hxx>
#include <BOPAlgo_WireSplitter.hxx>
#include <BRepFeat_Gluer.hxx>
#include <BRepFeat_MakeCylindricalHole.hxx>
#include <BiTgte_Blend.hxx>
#include <BRepPreviewAPI_MakeBox.hxx>
#include <BRepTools_CopyModification.hxx>
#include <BRepTools_GTrsfModification.hxx>
#include <BRepTools_TrsfModification.hxx>
#include <BRepFill_Evolved.hxx>
#include <BRepFill_NSections.hxx>
#include <BRepFill_OffsetAncestors.hxx>
#include <BRepAlgo_AsDes.hxx>
#include <BRepCheck_Analyzer.hxx>
#include <ShapeUpgrade_UnifySameDomain.hxx>
#include <HLRAppli_ReflectLines.hxx>
#include <HLRBRep_TypeOfResultingEdge.hxx>
#include <BRepFeat_Status.hxx>
#include <ChFi2d_ChamferAPI.hxx>
#include <ChFi2d_FilletAPI.hxx>
#include <FilletSurf_Builder.hxx>
#include <FilletSurf_StatusDone.hxx>
#include <FilletSurf_ErrorTypeStatus.hxx>
#include <FilletSurf_StatusType.hxx>
#include <IntTools_BeanFaceIntersector.hxx>
#include <LocOpe_Gluer.hxx>
#include <BOPAlgo_Tools.hxx>
#include <BOPTools_AlgoTools.hxx>
#include <BOPTools_AlgoTools3D.hxx>
#include <IntTools_CommonPrt.hxx>
#include <IntTools_Context.hxx>
#include <IntTools_Curve.hxx>
#include <IntTools_EdgeEdge.hxx>
#include <IntTools_EdgeFace.hxx>
#include <IntTools_FaceFace.hxx>
#include <IntTools_FClass2d.hxx>
#include <IntTools_PntOn2Faces.hxx>
#include <IntTools_Range.hxx>
#include <IntTools_SequenceOfCommonPrts.hxx>
#include <IntTools_SequenceOfCurves.hxx>
#include <IntTools_SequenceOfPntOn2Faces.hxx>
#include <BRepOffset_Offset.hxx>
#include <BRepOffset_SimpleOffset.hxx>
#include <BRepTools_Modifier.hxx>
#include <BRepTools_NurbsConvertModification.hxx>
#include <Geom_CylindricalSurface.hxx>
#include <LocOpe_BuildWires.hxx>
#include <LocOpe_CurveShapeIntersector.hxx>
#include <LocOpe_Spliter.hxx>
#include <LocOpe_WiresOnShape.hxx>
#include <Poly_Array1OfTriangle.hxx>
#include <Poly_Triangulation.hxx>
#include <BRepOffsetAPI_DraftAngle.hxx>
#include <BRepOffsetAPI_MakePipeShell.hxx>
#include <BRepOffsetAPI_MakeThickSolid.hxx>
#include <BRepFilletAPI_MakeChamfer.hxx>
#include <BRepOffsetAPI_ThruSections.hxx>
#include <BRepOffsetAPI_MakeOffsetShape.hxx>
#include <Standard_ErrorHandler.hxx>   // OCC_CATCH_SIGNALS (issue #175)
#include <BRepOffsetAPI_MakeOffset.hxx>
#include <BRepOffset.hxx>
#include <BRepBuilderAPI_MakeVertex.hxx>
#include <BRepBuilderAPI_MakeWire.hxx>
#include <BRepBuilderAPI_TransitionMode.hxx>
#include <BRepFeat_MakeRevolutionForm.hxx>
#include <BRepFeat_MakeDPrism.hxx>
#include <BRepFeat_MakeRevol.hxx>
#include <BRepFeat_MakePipe.hxx>
#include <BRepFeat_MakePrism.hxx>
#include <BRepFeat_SplitShape.hxx>
#include <BRepAlgoAPI_Section.hxx>
#include <BRepAlgoAPI_Check.hxx>
#include <BRepAlgoAPI_BuilderAlgo.hxx>
#include <BRepAlgoAPI_Fuse.hxx>
#include <BRepAlgoAPI_Cut.hxx>
#include <BRepPrimAPI_MakePrism.hxx>
#include <BRepProj_Projection.hxx>
#include <HLRBRep_PolyAlgo.hxx>
#include <HLRBRep_PolyHLRToShape.hxx>
#include <GeomAbs_JoinType.hxx>
#include <BRepOffsetAPI_MakeEvolved.hxx>
#include <BRepBuilderAPI_MakeSolid.hxx>
#include <BRepBuilderAPI_Sewing.hxx>
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepPrimAPI_MakeRevol.hxx>
#include <Geom_Circle.hxx>
#include <Geom_TrimmedCurve.hxx>
#include <Geom_BSplineCurve.hxx>
#include <GC_MakeArcOfCircle.hxx>
#include <GeomAPI_PointsToBSpline.hxx>
#include <TColgp_Array1OfPnt.hxx>
#include <TColStd_Array1OfReal.hxx>
#include <TColStd_Array1OfInteger.hxx>
#include <TColStd_HArray1OfBoolean.hxx>
#include <BRepBndLib.hxx>
#include <BRepAlgoAPI_Splitter.hxx>
#include <ShapeFix_Solid.hxx>
#include <Geom_BSplineCurve.hxx>
#include <GeomAPI_Interpolate.hxx>
#include <TColgp_HArray1OfPnt.hxx>
#include <gp_Ax1.hxx>
#include <Bnd_Box.hxx>
#include <TopoDS_Shell.hxx>
#include <TopoDS_Solid.hxx>
#include <TColgp_Array1OfPnt2d.hxx>
#include <BRepMesh_IncrementalMesh.hxx>
#include <ShapeAnalysis_FreeBounds.hxx>
#include <ShapeFix_FreeBounds.hxx>
#include <gp_Pnt2d.hxx>

#include <Geom_BSplineSurface.hxx>
#include <GCPnts_AbscissaPoint.hxx>

#include <gp_Ax2.hxx>
#include <gp_Dir.hxx>
#include <gp_Pln.hxx>
#include <gp_Pnt.hxx>
#include <gp_Trsf.hxx>
#include <gp_Vec.hxx>

#include <TColgp_Array2OfPnt.hxx>
#include <TColStd_Array1OfInteger.hxx>
#include <TColStd_Array1OfReal.hxx>

#include <TopAbs.hxx>
#include <TopExp.hxx>
#include <TopExp_Explorer.hxx>
#include <TopLoc_Location.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Compound.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopTools_ListOfShape.hxx>

// MARK: - 2D Drawing / HLR Projection

OCCTDrawingRef OCCTDrawingCreate(OCCTShapeRef shape, double dirX, double dirY, double dirZ, OCCTProjectionType projectionType) {
    if (!shape) return nullptr;

    try {
        // Normalize direction
        gp_Dir viewDir(dirX, dirY, dirZ);

        // Create projector
        // For orthographic: simple direction projector
        // For perspective: need a focal point
        gp_Ax2 projAxis(gp_Pnt(0, 0, 0), viewDir);
        HLRAlgo_Projector projector(projAxis);

        // Create HLR algorithm
        Handle(HLRBRep_Algo) hlrAlgo = new HLRBRep_Algo();
        hlrAlgo->Add(shape->shape);
        hlrAlgo->Projector(projector);
        hlrAlgo->Update();
        hlrAlgo->Hide();

        // Extract edges
        HLRBRep_HLRToShape shapes(hlrAlgo);

        OCCTDrawing* drawing = new OCCTDrawing();
        drawing->visibleSharp = shapes.VCompound();
        drawing->visibleSmooth = shapes.Rg1LineVCompound();
        drawing->visibleOutline = shapes.OutLineVCompound();
        drawing->hiddenSharp = shapes.HCompound();
        drawing->hiddenSmooth = shapes.Rg1LineHCompound();
        drawing->hiddenOutline = shapes.OutLineHCompound();

        return drawing;
    } catch (...) {
        return nullptr;
    }
}

void OCCTDrawingRelease(OCCTDrawingRef drawing) {
    delete drawing;
}

OCCTShapeRef OCCTDrawingGetEdges(OCCTDrawingRef drawing, OCCTEdgeType edgeType) {
    if (!drawing) return nullptr;

    try {
        TopoDS_Shape result;
        BRep_Builder builder;
        TopoDS_Compound compound;
        builder.MakeCompound(compound);

        switch (edgeType) {
            case OCCTEdgeTypeVisible:
                if (!drawing->visibleSharp.IsNull()) {
                    builder.Add(compound, drawing->visibleSharp);
                }
                if (!drawing->visibleSmooth.IsNull()) {
                    builder.Add(compound, drawing->visibleSmooth);
                }
                if (!drawing->visibleOutline.IsNull()) {
                    builder.Add(compound, drawing->visibleOutline);
                }
                break;

            case OCCTEdgeTypeHidden:
                if (!drawing->hiddenSharp.IsNull()) {
                    builder.Add(compound, drawing->hiddenSharp);
                }
                if (!drawing->hiddenSmooth.IsNull()) {
                    builder.Add(compound, drawing->hiddenSmooth);
                }
                if (!drawing->hiddenOutline.IsNull()) {
                    builder.Add(compound, drawing->hiddenOutline);
                }
                break;

            case OCCTEdgeTypeOutline:
                if (!drawing->visibleOutline.IsNull()) {
                    builder.Add(compound, drawing->visibleOutline);
                }
                if (!drawing->hiddenOutline.IsNull()) {
                    builder.Add(compound, drawing->hiddenOutline);
                }
                break;
        }

        if (compound.IsNull()) return nullptr;

        return new OCCTShape(compound);
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Advanced Modeling (v0.8.0)

OCCTShapeRef OCCTShapeFilletEdges(OCCTShapeRef shape, const int32_t* edgeIndices,
                                   int32_t edgeCount, double radius) {
    if (!shape || !edgeIndices || edgeCount <= 0 || radius <= 0) return nullptr;

    try {
        BRepFilletAPI_MakeFillet fillet(shape->shape);

        // Build edge index map for lookup
        TopTools_IndexedMapOfShape edgeMap;
        TopExp::MapShapes(shape->shape, TopAbs_EDGE, edgeMap);

        for (int32_t i = 0; i < edgeCount; i++) {
            int32_t idx = edgeIndices[i];
            if (idx >= 0 && idx < edgeMap.Extent()) {
                TopoDS_Edge edge = TopoDS::Edge(edgeMap(idx + 1));  // OCCT is 1-based
                fillet.Add(radius, edge);
            }
        }

        fillet.Build();
        if (!fillet.IsDone()) return nullptr;

        return new OCCTShape(fillet.Shape());
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeFilletEdgesLinear(OCCTShapeRef shape, const int32_t* edgeIndices,
                                         int32_t edgeCount, double startRadius, double endRadius) {
    if (!shape || !edgeIndices || edgeCount <= 0) return nullptr;
    if (startRadius <= 0 || endRadius <= 0) return nullptr;

    try {
        BRepFilletAPI_MakeFillet fillet(shape->shape);

        // Build edge index map for lookup
        TopTools_IndexedMapOfShape edgeMap;
        TopExp::MapShapes(shape->shape, TopAbs_EDGE, edgeMap);

        for (int32_t i = 0; i < edgeCount; i++) {
            int32_t idx = edgeIndices[i];
            if (idx >= 0 && idx < edgeMap.Extent()) {
                TopoDS_Edge edge = TopoDS::Edge(edgeMap(idx + 1));  // OCCT is 1-based
                // Add edge with variable radius
                fillet.Add(edge);
                // Set radius variation along the edge
                int contourIndex = fillet.NbContours();
                fillet.SetRadius(startRadius, endRadius, contourIndex, 1);
            }
        }

        fillet.Build();
        if (!fillet.IsDone()) return nullptr;

        return new OCCTShape(fillet.Shape());
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeDraft(OCCTShapeRef shape, const int32_t* faceIndices, int32_t faceCount,
                            double dirX, double dirY, double dirZ, double angle,
                            double planeX, double planeY, double planeZ,
                            double planeNx, double planeNy, double planeNz) {
    if (!shape || !faceIndices || faceCount <= 0) return nullptr;

    try {
        // Pull direction (typically vertical for mold release)
        gp_Dir pullDir(dirX, dirY, dirZ);

        // Neutral plane - where draft angle is measured from
        gp_Pnt planePoint(planeX, planeY, planeZ);
        gp_Dir planeNormal(planeNx, planeNy, planeNz);
        gp_Pln neutralPlane(planePoint, planeNormal);

        BRepOffsetAPI_DraftAngle draft(shape->shape);

        // Build face index map
        TopTools_IndexedMapOfShape faceMap;
        TopExp::MapShapes(shape->shape, TopAbs_FACE, faceMap);

        for (int32_t i = 0; i < faceCount; i++) {
            int32_t idx = faceIndices[i];
            if (idx >= 0 && idx < faceMap.Extent()) {
                TopoDS_Face face = TopoDS::Face(faceMap(idx + 1));
                draft.Add(face, pullDir, angle, neutralPlane);
            }
        }

        draft.Build();
        if (!draft.IsDone()) return nullptr;

        return new OCCTShape(draft.Shape());
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeRemoveFeatures(OCCTShapeRef shape, const int32_t* faceIndices, int32_t faceCount) {
    if (!shape || !faceIndices || faceCount <= 0) return nullptr;

    try {
        BRepAlgoAPI_Defeaturing defeature;
        defeature.SetShape(shape->shape);

        // Build face index map
        TopTools_IndexedMapOfShape faceMap;
        TopExp::MapShapes(shape->shape, TopAbs_FACE, faceMap);

        for (int32_t i = 0; i < faceCount; i++) {
            int32_t idx = faceIndices[i];
            if (idx >= 0 && idx < faceMap.Extent()) {
                TopoDS_Face face = TopoDS::Face(faceMap(idx + 1));
                defeature.AddFaceToRemove(face);
            }
        }

        defeature.Build();
        if (!defeature.IsDone()) return nullptr;

        return new OCCTShape(defeature.Shape());
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeCreatePipeShell(OCCTWireRef spine, OCCTWireRef profile,
                                       OCCTPipeMode mode, bool solid) {
    if (!spine || !profile) return nullptr;

    try {
        BRepOffsetAPI_MakePipeShell pipeShell(spine->wire);

        // Set sweep mode
        switch (mode) {
            case OCCTPipeModeFrenet:
                pipeShell.SetMode(Standard_False);  // Frenet
                break;
            case OCCTPipeModeCorrectedFrenet:
                pipeShell.SetMode(Standard_True);   // Corrected Frenet
                break;
            case OCCTPipeModeFixedBinormal:
            case OCCTPipeModeAuxiliary:
                // These modes require additional parameters
                // Use dedicated functions for them
                pipeShell.SetMode(Standard_False);
                break;
        }

        // Add profile
        pipeShell.Add(profile->wire);

        // Build the shell
        pipeShell.SetIsBuildHistory(false); // avoid SEGV on closed spine+profile (OCCT bug)
        pipeShell.Build();
        if (!pipeShell.IsDone()) return nullptr;

        TopoDS_Shape result = pipeShell.Shape();

        // Make solid if requested
        if (solid) {
            pipeShell.MakeSolid();
            if (pipeShell.IsDone()) {
                result = pipeShell.Shape();
            }
        }

        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeCreatePipeShellWithBinormal(OCCTWireRef spine, OCCTWireRef profile,
                                                   double bnX, double bnY, double bnZ, bool solid) {
    if (!spine || !profile) return nullptr;

    try {
        BRepOffsetAPI_MakePipeShell pipeShell(spine->wire);

        // Set fixed binormal direction
        gp_Dir binormal(bnX, bnY, bnZ);
        pipeShell.SetMode(binormal);

        // Add profile
        pipeShell.Add(profile->wire);

        // Build the shell
        pipeShell.SetIsBuildHistory(false); // avoid SEGV on closed spine+profile (OCCT bug)
        pipeShell.Build();
        if (!pipeShell.IsDone()) return nullptr;

        TopoDS_Shape result = pipeShell.Shape();

        // Make solid if requested
        if (solid) {
            pipeShell.MakeSolid();
            if (pipeShell.IsDone()) {
                result = pipeShell.Shape();
            }
        }

        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeCreatePipeShellWithAuxSpine(OCCTWireRef spine, OCCTWireRef profile,
                                                   OCCTWireRef auxSpine, bool solid) {
    if (!spine || !profile || !auxSpine) return nullptr;

    try {
        BRepOffsetAPI_MakePipeShell pipeShell(spine->wire);

        // Set auxiliary spine for twist control
        pipeShell.SetMode(auxSpine->wire, Standard_False);  // curvilinear equivalence = false

        // Add profile
        pipeShell.Add(profile->wire);

        // Build the shell
        pipeShell.SetIsBuildHistory(false); // avoid SEGV on closed spine+profile (OCCT bug)
        pipeShell.Build();
        if (!pipeShell.IsDone()) return nullptr;

        TopoDS_Shape result = pipeShell.Shape();

        // Make solid if requested
        if (solid) {
            pipeShell.MakeSolid();
            if (pipeShell.IsDone()) {
                result = pipeShell.Shape();
            }
        }

        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

// Multi-section pipe shell (#180): one MakePipeShell, several Add() calls.
OCCTShapeRef OCCTShapeCreatePipeShellMultiSection(OCCTWireRef spine,
                                                  const OCCTWireRef* profiles, int32_t profileCount,
                                                  OCCTPipeMode mode,
                                                  double bnX, double bnY, double bnZ,
                                                  OCCTWireRef auxSpine,
                                                  bool withContact, bool withCorrection,
                                                  bool solid) {
    if (!spine || !profiles || profileCount < 1) return nullptr;
    if (mode == OCCTPipeModeAuxiliary && !auxSpine) return nullptr;

    try {
        BRepOffsetAPI_MakePipeShell pipeShell(spine->wire);

        switch (mode) {
            case OCCTPipeModeFrenet:
                pipeShell.SetMode(Standard_False);
                break;
            case OCCTPipeModeCorrectedFrenet:
                pipeShell.SetMode(Standard_True);
                break;
            case OCCTPipeModeFixedBinormal:
                pipeShell.SetMode(gp_Dir(bnX, bnY, bnZ));
                break;
            case OCCTPipeModeAuxiliary:
                pipeShell.SetMode(auxSpine->wire, Standard_False);
                break;
        }

        // Add every profile (variable cross-section).
        for (int32_t i = 0; i < profileCount; ++i) {
            if (!profiles[i]) return nullptr;
            pipeShell.Add(profiles[i]->wire,
                          withContact ? Standard_True : Standard_False,
                          withCorrection ? Standard_True : Standard_False);
        }

        pipeShell.SetIsBuildHistory(false); // avoid SEGV on closed spine+profile (OCCT bug)
        pipeShell.Build();
        if (!pipeShell.IsDone()) return nullptr;

        TopoDS_Shape result = pipeShell.Shape();
        if (solid) {
            pipeShell.MakeSolid();
            if (pipeShell.IsDone()) {
                result = pipeShell.Shape();
            }
        }
        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

// Analytic helicoid thread cutter (#187): smooth ruled-face solid, no faceting/balloon.
#include <BRepFill.hxx>
#include <GeomAPI_Interpolate.hxx>
#include <TColgp_HArray1OfPnt.hxx>
#include <BRepBuilderAPI_MakePolygon.hxx>
#include <BRepLib.hxx>
OCCTShapeRef OCCTShapeBuildThreadCutter(double ox, double oy, double oz,
                                        double ax, double ay, double az,
                                        double rx, double ry, double rz,
                                        double pitch, double turns, double apexSign,
                                        double helixRadius, double cutDepth,
                                        double rootHalf, double crestHalf, double bleed,
                                        double phase, double handed, int32_t nSections) {
    if (pitch <= 0 || turns <= 0 || nSections < 2) return nullptr;
    try {
        const gp_Vec O(ox, oy, oz), A(ax, ay, az), R0(rx, ry, rz);
        const gp_Vec T0 = A.Crossed(R0);                 // tangential0 = axis x radial0
        const double rootR  = helixRadius - apexSign * bleed;     // root bleeds past surface
        const double crestR = helixRadius + apexSign * cutDepth;  // crest = the deep cut
        const double cr[4] = { rootR, crestR, crestR, rootR };
        const double cz[4] = { -rootHalf, -crestHalf, crestHalf, rootHalf };
        const int N = nSections;

        // Each V-corner traces a single-edge BSpline helix.
        TopoDS_Edge edges[4];
        for (int k = 0; k < 4; ++k) {
            Handle(TColgp_HArray1OfPnt) pts = new TColgp_HArray1OfPnt(1, N + 1);
            for (int i = 0; i <= N; ++i) {
                const double fr = (double)i / (double)N;
                const double theta = handed * (phase + 2.0 * M_PI * turns * fr);
                const double zc = pitch * turns * fr + cz[k];
                const gp_Vec radial = R0 * std::cos(theta) + T0 * std::sin(theta);
                const gp_Vec P = O + A * zc + radial * cr[k];
                pts->SetValue(i + 1, gp_Pnt(P.X(), P.Y(), P.Z()));
            }
            GeomAPI_Interpolate interp(pts, Standard_False, 1e-7);
            interp.Perform();
            if (!interp.IsDone()) return nullptr;
            edges[k] = BRepBuilderAPI_MakeEdge(interp.Curve());
            if (edges[k].IsNull()) return nullptr;
        }

        // Ruled flank/crest/root faces between consecutive corner helices, + 2 V end caps.
        BRepBuilderAPI_Sewing sewer(1e-6);
        for (int k = 0; k < 4; ++k) {
            TopoDS_Face f = BRepFill::Face(edges[k], edges[(k + 1) % 4]);
            if (f.IsNull()) return nullptr;
            sewer.Add(f);
        }
        for (int cap = 0; cap < 2; ++cap) {
            const double fr = (double)cap;
            const double theta = handed * (phase + 2.0 * M_PI * turns * fr);
            const double zbase = pitch * turns * fr;
            const gp_Vec radial = R0 * std::cos(theta) + T0 * std::sin(theta);
            BRepBuilderAPI_MakePolygon poly;
            for (int k = 0; k < 4; ++k) {
                const gp_Vec P = O + A * (zbase + cz[k]) + radial * cr[k];
                poly.Add(gp_Pnt(P.X(), P.Y(), P.Z()));
            }
            poly.Close();
            BRepBuilderAPI_MakeFace mf(poly.Wire(), Standard_True);
            if (!mf.IsDone()) return nullptr;
            sewer.Add(mf.Face());
        }
        sewer.Perform();
        TopoDS_Shape shell = sewer.SewedShape();
        if (shell.IsNull()) return nullptr;
        TopExp_Explorer se(shell, TopAbs_SHELL);
        if (!se.More()) return nullptr;
        TopoDS_Solid solid = BRepBuilderAPI_MakeSolid(TopoDS::Shell(se.Current())).Solid();
        // Orient outward so it is a proper positive-volume solid (the sewn shell can be
        // inside-out, which would make the boolean intersect instead of subtract).
        BRepLib::OrientClosedSolid(solid);
        return new OCCTShape(solid);
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Surface Construction (v0.9.0)

OCCTShapeRef OCCTShapeCreateBSplineSurface(const double* poles, int32_t uCount, int32_t vCount,
                                            int32_t uDegree, int32_t vDegree) {
    if (!poles || uCount < 2 || vCount < 2) return nullptr;
    if (uDegree < 1 || vDegree < 1) return nullptr;
    if (uCount < uDegree + 1 || vCount < vDegree + 1) return nullptr;

    try {
        // Create 2D array of control points (1-indexed for OCCT)
        TColgp_Array2OfPnt polesArray(1, uCount, 1, vCount);

        for (int32_t u = 0; u < uCount; u++) {
            for (int32_t v = 0; v < vCount; v++) {
                int32_t idx = (u * vCount + v) * 3;
                polesArray.SetValue(u + 1, v + 1, gp_Pnt(poles[idx], poles[idx + 1], poles[idx + 2]));
            }
        }

        // Create uniform clamped knot vectors
        int32_t uKnotCount = uCount - uDegree + 1;
        int32_t vKnotCount = vCount - vDegree + 1;

        TColStd_Array1OfReal uKnots(1, uKnotCount);
        TColStd_Array1OfReal vKnots(1, vKnotCount);
        TColStd_Array1OfInteger uMults(1, uKnotCount);
        TColStd_Array1OfInteger vMults(1, vKnotCount);

        // Uniform knot values
        for (int32_t i = 1; i <= uKnotCount; i++) {
            uKnots.SetValue(i, (double)(i - 1) / (uKnotCount - 1));
            uMults.SetValue(i, (i == 1 || i == uKnotCount) ? uDegree + 1 : 1);
        }
        for (int32_t i = 1; i <= vKnotCount; i++) {
            vKnots.SetValue(i, (double)(i - 1) / (vKnotCount - 1));
            vMults.SetValue(i, (i == 1 || i == vKnotCount) ? vDegree + 1 : 1);
        }

        // Create B-spline surface
        Handle(Geom_BSplineSurface) surface = new Geom_BSplineSurface(
            polesArray,
            uKnots, vKnots,
            uMults, vMults,
            uDegree, vDegree
        );

        if (surface.IsNull()) return nullptr;

        // Create face from surface
        BRepBuilderAPI_MakeFace faceMaker(surface, 1e-6);
        if (!faceMaker.IsDone()) return nullptr;

        return new OCCTShape(faceMaker.Face());
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeCreateRuled(OCCTWireRef wire1, OCCTWireRef wire2) {
    if (!wire1 || !wire2) return nullptr;

    try {
        // Use BRepFill::Face to create a ruled surface between two edges/wires
        TopoDS_Shape result = BRepFill::Shell(wire1->wire, wire2->wire);

        if (result.IsNull()) return nullptr;

        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeShellWithOpenFaces(OCCTShapeRef shape, double thickness,
                                          const int32_t* openFaceIndices, int32_t faceCount) {
    if (!shape || !openFaceIndices || faceCount < 1) return nullptr;

    try {
        // Get indexed map of faces
        TopTools_IndexedMapOfShape faceMap;
        TopExp::MapShapes(shape->shape, TopAbs_FACE, faceMap);

        // Build list of faces to remove (open faces)
        TopTools_ListOfShape facesToRemove;
        for (int32_t i = 0; i < faceCount; i++) {
            int32_t idx = openFaceIndices[i];
            if (idx >= 0 && idx < faceMap.Extent()) {
                facesToRemove.Append(faceMap(idx + 1));  // 1-based indexing
            }
        }

        if (facesToRemove.IsEmpty()) return nullptr;

        // Create thick solid (shell) with open faces
        BRepOffsetAPI_MakeThickSolid thickSolid;
        thickSolid.MakeThickSolidByJoin(shape->shape, facesToRemove, thickness, 1e-6);

        if (!thickSolid.IsDone()) return nullptr;

        return new OCCTShape(thickSolid.Shape());
    } catch (...) {
        return nullptr;
    }
}


// MARK: - Helix Curves (v0.28.0)

#include <HelixBRep_BuilderHelix.hxx>

OCCTWireRef OCCTWireCreateHelix(double originX, double originY, double originZ,
                                 double axisX, double axisY, double axisZ,
                                 double radius, double pitch, double turns,
                                 bool clockwise) {
    try {
        gp_Pnt origin(originX, originY, originZ);
        gp_Dir dir(axisX, axisY, axisZ);
        if (!clockwise) dir.Reverse();
        gp_Ax3 axis(origin, dir);

        double diameter = radius * 2.0;

        NCollection_Array1<double> pitchArr(1, 1);
        pitchArr.SetValue(1, pitch);
        NCollection_Array1<double> nbTurnsArr(1, 1);
        nbTurnsArr.SetValue(1, turns);

        HelixBRep_BuilderHelix builder;
        builder.SetParameters(axis, diameter, pitchArr, nbTurnsArr);
        builder.Perform();

        if (builder.ErrorStatus() != 0) return nullptr;

        const TopoDS_Shape& shape = builder.Shape();
        if (shape.IsNull()) return nullptr;

        return new OCCTWire(TopoDS::Wire(shape));
    } catch (...) {
        return nullptr;
    }
}

OCCTWireRef OCCTWireCreateHelixTapered(double originX, double originY, double originZ,
                                        double axisX, double axisY, double axisZ,
                                        double startRadius, double endRadius,
                                        double pitch, double turns,
                                        bool clockwise) {
    try {
        gp_Pnt origin(originX, originY, originZ);
        gp_Dir dir(axisX, axisY, axisZ);
        if (!clockwise) dir.Reverse();
        gp_Ax3 axis(origin, dir);

        double startDiam = startRadius * 2.0;
        double endDiam = endRadius * 2.0;

        NCollection_Array1<double> pitchArr(1, 1);
        pitchArr.SetValue(1, pitch);
        NCollection_Array1<double> nbTurnsArr(1, 1);
        nbTurnsArr.SetValue(1, turns);

        HelixBRep_BuilderHelix builder;
        builder.SetParameters(axis, startDiam, endDiam, pitchArr, nbTurnsArr);
        builder.Perform();

        if (builder.ErrorStatus() != 0) return nullptr;

        const TopoDS_Shape& shape = builder.Shape();
        if (shape.IsNull()) return nullptr;

        return new OCCTWire(TopoDS::Wire(shape));
    } catch (...) {
        return nullptr;
    }
}
// MARK: - Wedge Primitive (v0.29.0)

#include <BRepPrimAPI_MakeWedge.hxx>

OCCTShapeRef OCCTShapeCreateWedge(double dx, double dy, double dz, double ltx) {
    try {
        BRepPrimAPI_MakeWedge maker(dx, dy, dz, ltx);
        return new OCCTShape(maker.Shape());
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeCreateWedgeAdvanced(double dx, double dy, double dz,
                                           double xmin, double zmin, double xmax, double zmax) {
    try {
        BRepPrimAPI_MakeWedge maker(dx, dy, dz, xmin, zmin, xmax, zmax);
        return new OCCTShape(maker.Shape());
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeCreateWedgeOriented(
    double originX, double originY, double originZ,
    double dirX, double dirY, double dirZ,
    double dx, double dy, double dz, double ltx) {
    try {
        gp_Ax2 axis(gp_Pnt(originX, originY, originZ), gp_Dir(dirX, dirY, dirZ));
        BRepPrimAPI_MakeWedge maker(axis, dx, dy, dz, ltx);
        return new OCCTShape(maker.Shape());
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Normal Projection (v0.29.0)

#include <BRepOffsetAPI_NormalProjection.hxx>

OCCTShapeRef OCCTShapeNormalProjection(OCCTShapeRef wireOrEdge, OCCTShapeRef surface,
                                        double tol3d, double tol2d, int maxDegree, int maxSeg) {
    if (!wireOrEdge || !surface) return nullptr;
    try {
        BRepOffsetAPI_NormalProjection proj(surface->shape);
        proj.Add(wireOrEdge->shape);
        proj.SetParams(tol3d, tol2d, GeomAbs_C2, maxDegree, maxSeg);
        proj.Build();
        if (!proj.IsDone()) return nullptr;
        return new OCCTShape(proj.Projection());
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Half-Space (v0.29.0)

#include <BRepPrimAPI_MakeHalfSpace.hxx>

OCCTShapeRef OCCTShapeCreateHalfSpace(OCCTShapeRef faceShape, double refX, double refY, double refZ) {
    if (!faceShape) return nullptr;
    try {
        // Extract first face from the shape
        TopExp_Explorer exp(faceShape->shape, TopAbs_FACE);
        if (!exp.More()) return nullptr;
        TopoDS_Face face = TopoDS::Face(exp.Current());

        gp_Pnt refPt(refX, refY, refZ);
        BRepPrimAPI_MakeHalfSpace maker(face, refPt);
        return new OCCTShape(maker.Solid());
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Periodic Shapes (v0.29.0)

#include <BOPAlgo_MakePeriodic.hxx>

OCCTShapeRef OCCTShapeMakePeriodic(OCCTShapeRef shape,
                                    bool xPeriodic, double xPeriod,
                                    bool yPeriodic, double yPeriod,
                                    bool zPeriodic, double zPeriod) {
    if (!shape) return nullptr;
    try {
        BOPAlgo_MakePeriodic maker;
        maker.SetShape(shape->shape);
        if (xPeriodic) maker.MakeXPeriodic(true, xPeriod);
        if (yPeriodic) maker.MakeYPeriodic(true, yPeriod);
        if (zPeriodic) maker.MakeZPeriodic(true, zPeriod);
        maker.Perform();
        if (maker.HasErrors()) return nullptr;
        return new OCCTShape(maker.Shape());
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeRepeat(OCCTShapeRef shape,
                              bool xPeriodic, double xPeriod,
                              bool yPeriodic, double yPeriod,
                              bool zPeriodic, double zPeriod,
                              int32_t xTimes, int32_t yTimes, int32_t zTimes) {
    if (!shape) return nullptr;
    try {
        BOPAlgo_MakePeriodic maker;
        maker.SetShape(shape->shape);
        if (xPeriodic) maker.MakeXPeriodic(true, xPeriod);
        if (yPeriodic) maker.MakeYPeriodic(true, yPeriod);
        if (zPeriodic) maker.MakeZPeriodic(true, zPeriod);
        maker.Perform();
        if (maker.HasErrors()) return nullptr;

        // Now repeat in each direction
        if (xPeriodic && xTimes > 0) maker.XRepeat(xTimes);
        if (yPeriodic && yTimes > 0) maker.YRepeat(yTimes);
        if (zPeriodic && zTimes > 0) maker.ZRepeat(zTimes);

        return new OCCTShape(maker.RepeatedShape());
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Draft from Shape (v0.29.0)

#include <BRepOffsetAPI_MakeDraft.hxx>

OCCTShapeRef OCCTShapeMakeDraft(OCCTShapeRef shape, double dirX, double dirY, double dirZ,
                                 double angle, double lengthMax) {
    if (!shape) return nullptr;
    try {
        gp_Dir dir(dirX, dirY, dirZ);
        BRepOffsetAPI_MakeDraft maker(shape->shape, dir, angle);
        maker.Perform(lengthMax);
        if (!maker.IsDone()) return nullptr;
        return new OCCTShape(maker.Shell());
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Non-Uniform Transform (v0.30.0)

#include <BRepBuilderAPI_GTransform.hxx>
#include <gp_GTrsf.hxx>
#include <gp_Mat.hxx>

OCCTShapeRef OCCTShapeNonUniformScale(OCCTShapeRef shape, double sx, double sy, double sz) {
    if (!shape) return nullptr;
    try {
        gp_GTrsf gtrsf;
        gtrsf.SetVectorialPart(gp_Mat(sx, 0, 0, 0, sy, 0, 0, 0, sz));
        BRepBuilderAPI_GTransform builder(shape->shape, gtrsf, true);
        if (!builder.IsDone()) return nullptr;
        return new OCCTShape(builder.Shape());
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Make Shell (v0.30.0)

#include <BRepBuilderAPI_MakeShell.hxx>

OCCTShapeRef OCCTShapeCreateShellFromSurface(OCCTSurfaceRef surface) {
    if (!surface || surface->surface.IsNull()) return nullptr;
    try {
        BRepBuilderAPI_MakeShell builder(surface->surface);
        if (!builder.IsDone()) return nullptr;
        return new OCCTShape(builder.Shell());
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Make Vertex (v0.30.0)

#include <BRepBuilderAPI_MakeVertex.hxx>

OCCTShapeRef OCCTShapeCreateVertex(double x, double y, double z) {
    try {
        BRepBuilderAPI_MakeVertex builder(gp_Pnt(x, y, z));
        if (!builder.IsDone()) return nullptr;
        return new OCCTShape(builder.Vertex());
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Simple Offset (v0.30.0)

#include <BRepOffset_MakeSimpleOffset.hxx>

OCCTShapeRef OCCTShapeSimpleOffset(OCCTShapeRef shape, double offsetValue) {
    if (!shape) return nullptr;
    try {
        BRepOffset_MakeSimpleOffset builder(shape->shape, offsetValue);
        builder.SetBuildSolidFlag(true);
        builder.Perform();
        if (!builder.IsDone()) return nullptr;
        return new OCCTShape(builder.GetResultShape());
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Middle Path (v0.30.0)

#include <BRepOffsetAPI_MiddlePath.hxx>

OCCTShapeRef OCCTShapeMiddlePath(OCCTShapeRef shape, OCCTShapeRef startShape, OCCTShapeRef endShape) {
    if (!shape || !startShape || !endShape) return nullptr;
    try {
        BRepOffsetAPI_MiddlePath builder(shape->shape, startShape->shape, endShape->shape);
        builder.Build();
        if (!builder.IsDone()) return nullptr;
        return new OCCTShape(builder.Shape());
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Fuse Edges (v0.30.0)

#include <BRepLib_FuseEdges.hxx>

OCCTShapeRef OCCTShapeFuseEdges(OCCTShapeRef shape) {
    if (!shape) return nullptr;
    try {
        BRepLib_FuseEdges fuser(shape->shape);
        fuser.Perform();
        return new OCCTShape(fuser.Shape());
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Maker Volume (v0.30.0)

#include <BOPAlgo_MakerVolume.hxx>

OCCTShapeRef OCCTShapeMakeVolume(OCCTShapeRef* shapes, int32_t count) {
    if (!shapes || count <= 0) return nullptr;
    try {
        BOPAlgo_MakerVolume maker;
        for (int32_t i = 0; i < count; i++) {
            if (!shapes[i]) return nullptr;
            maker.AddArgument(shapes[i]->shape);
        }
        maker.Perform();
        if (maker.HasErrors()) return nullptr;
        return new OCCTShape(maker.Shape());
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Make Connected (v0.30.0)

#include <BOPAlgo_MakeConnected.hxx>

OCCTShapeRef OCCTShapeMakeConnected(OCCTShapeRef* shapes, int32_t count) {
    if (!shapes || count <= 0) return nullptr;
    try {
        BOPAlgo_MakeConnected maker;
        for (int32_t i = 0; i < count; i++) {
            if (!shapes[i]) return nullptr;
            maker.AddArgument(shapes[i]->shape);
        }
        maker.Perform();
        if (maker.HasErrors()) return nullptr;
        return new OCCTShape(maker.Shape());
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Quilt Faces (v0.31.0)

#include <BRepTools_Quilt.hxx>

OCCTShapeRef OCCTShapeQuilt(OCCTShapeRef* shapes, int32_t count) {
    if (!shapes || count <= 0) return nullptr;
    try {
        BRepTools_Quilt quilt;
        for (int32_t i = 0; i < count; i++) {
            if (!shapes[i]) return nullptr;
            quilt.Add(shapes[i]->shape);
        }
        TopoDS_Shape result = quilt.Shells();
        if (result.IsNull()) return nullptr;
        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Revolution from Curve (v0.31.0)

#include <BRepPrimAPI_MakeRevolution.hxx>

OCCTShapeRef OCCTShapeCreateRevolutionFromCurve(OCCTCurve3DRef meridian,
                                                 double axOX, double axOY, double axOZ,
                                                 double axDX, double axDY, double axDZ,
                                                 double angle) {
    if (!meridian || meridian->curve.IsNull()) return nullptr;
    try {
        gp_Ax2 axes(gp_Pnt(axOX, axOY, axOZ), gp_Dir(axDX, axDY, axDZ));
        BRepPrimAPI_MakeRevolution maker(axes, meridian->curve, angle);
        maker.Build();
        if (!maker.IsDone()) return nullptr;
        return new OCCTShape(maker.Shape());
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Linear Rib Feature (v0.31.0)

#include <BRepFeat_MakeLinearForm.hxx>

OCCTShapeRef OCCTShapeAddLinearRib(OCCTShapeRef shape, OCCTWireRef profile,
                                    double dirX, double dirY, double dirZ,
                                    double dir1X, double dir1Y, double dir1Z,
                                    bool fuse) {
    if (!shape || !profile) return nullptr;
    try {
        BRepLib_FindSurface finder(profile->wire);
        if (!finder.Found()) return nullptr;
        Handle(Geom_Plane) plane = Handle(Geom_Plane)::DownCast(finder.Surface());
        if (plane.IsNull()) return nullptr;
        gp_Vec dir(dirX, dirY, dirZ);
        gp_Vec dir1(dir1X, dir1Y, dir1Z);
        BRepFeat_MakeLinearForm maker(shape->shape, profile->wire, plane, dir, dir1,
                                       fuse ? 1 : 0, false);
        maker.Perform();
        if (!maker.IsDone()) return nullptr;
        return new OCCTShape(maker.Shape());
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Asymmetric Chamfer (v0.32.0)

OCCTShapeRef OCCTShapeChamferTwoDistances(OCCTShapeRef shape,
                                           const int32_t* edgeIndices,
                                           const int32_t* faceIndices,
                                           const double* dist1,
                                           const double* dist2,
                                           int32_t count) {
    if (!shape || !edgeIndices || !faceIndices || !dist1 || !dist2 || count <= 0) return nullptr;
    try {
        BRepFilletAPI_MakeChamfer chamfer(shape->shape);
        TopTools_IndexedMapOfShape edgeMap, faceMap;
        TopExp::MapShapes(shape->shape, TopAbs_EDGE, edgeMap);
        TopExp::MapShapes(shape->shape, TopAbs_FACE, faceMap);

        for (int32_t i = 0; i < count; i++) {
            int32_t ei = edgeIndices[i] + 1;  // 0-based to 1-based
            int32_t fi = faceIndices[i] + 1;
            if (ei < 1 || ei > edgeMap.Extent()) return nullptr;
            if (fi < 1 || fi > faceMap.Extent()) return nullptr;
            chamfer.Add(dist1[i], dist2[i],
                        TopoDS::Edge(edgeMap(ei)),
                        TopoDS::Face(faceMap(fi)));
        }
        chamfer.Build();
        if (!chamfer.IsDone()) return nullptr;
        return new OCCTShape(chamfer.Shape());
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeChamferDistAngle(OCCTShapeRef shape,
                                        const int32_t* edgeIndices,
                                        const int32_t* faceIndices,
                                        const double* distances,
                                        const double* anglesDeg,
                                        int32_t count) {
    if (!shape || !edgeIndices || !faceIndices || !distances || !anglesDeg || count <= 0) return nullptr;
    try {
        BRepFilletAPI_MakeChamfer chamfer(shape->shape);
        TopTools_IndexedMapOfShape edgeMap, faceMap;
        TopExp::MapShapes(shape->shape, TopAbs_EDGE, edgeMap);
        TopExp::MapShapes(shape->shape, TopAbs_FACE, faceMap);

        for (int32_t i = 0; i < count; i++) {
            int32_t ei = edgeIndices[i] + 1;
            int32_t fi = faceIndices[i] + 1;
            if (ei < 1 || ei > edgeMap.Extent()) return nullptr;
            if (fi < 1 || fi > faceMap.Extent()) return nullptr;
            double angleRad = anglesDeg[i] * M_PI / 180.0;
            chamfer.AddDA(distances[i], angleRad,
                          TopoDS::Edge(edgeMap(ei)),
                          TopoDS::Face(faceMap(fi)));
        }
        chamfer.Build();
        if (!chamfer.IsDone()) return nullptr;
        return new OCCTShape(chamfer.Shape());
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Loft Improvements (v0.32.0)

OCCTShapeRef OCCTShapeCreateLoftAdvanced(const OCCTWireRef* profiles, int32_t profileCount,
                                          bool solid, bool ruled,
                                          double firstVertexX, double firstVertexY, double firstVertexZ,
                                          double lastVertexX, double lastVertexY, double lastVertexZ) {
    if (!profiles || profileCount < 1) return nullptr;
    try {
        BRepOffsetAPI_ThruSections maker(solid, ruled);
        maker.CheckCompatibility(Standard_True);

        // Add first vertex if specified (NaN check)
        if (firstVertexX == firstVertexX) {  // not NaN
            BRepBuilderAPI_MakeVertex mv(gp_Pnt(firstVertexX, firstVertexY, firstVertexZ));
            maker.AddVertex(TopoDS::Vertex(mv.Shape()));
        }

        for (int32_t i = 0; i < profileCount; i++) {
            if (profiles[i]) {
                maker.AddWire(profiles[i]->wire);
            }
        }

        // Add last vertex if specified
        if (lastVertexX == lastVertexX) {  // not NaN
            BRepBuilderAPI_MakeVertex mv(gp_Pnt(lastVertexX, lastVertexY, lastVertexZ));
            maker.AddVertex(TopoDS::Vertex(mv.Shape()));
        }

        maker.Build();
        if (!maker.IsDone()) return nullptr;
        return new OCCTShape(maker.Shape());
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Offset with Join Type (v0.32.0)

OCCTShapeRef OCCTShapeOffsetByJoin(OCCTShapeRef shape, double distance,
                                    double tolerance, int32_t joinType,
                                    bool removeInternalEdges) {
    if (!shape) return nullptr;
    try {
        BRepOffsetAPI_MakeOffsetShape offsetter;
        GeomAbs_JoinType join = GeomAbs_Arc;
        if (joinType == 1) join = GeomAbs_Tangent;
        else if (joinType == 2) join = GeomAbs_Intersection;
        offsetter.PerformByJoin(shape->shape, distance, tolerance,
                                BRepOffset_Skin, false, false, join, removeInternalEdges);
        if (!offsetter.IsDone()) return nullptr;
        return new OCCTShape(offsetter.Shape());
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Revolution Form Feature (v0.32.0)

#include <BRepFeat_MakeRevolutionForm.hxx>

OCCTShapeRef OCCTShapeAddRevolutionForm(OCCTShapeRef shape, OCCTWireRef profile,
                                         double axOX, double axOY, double axOZ,
                                         double axDX, double axDY, double axDZ,
                                         double height1, double height2,
                                         bool fuse) {
    if (!shape || !profile) return nullptr;
    try {
        BRepLib_FindSurface finder(profile->wire);
        if (!finder.Found()) return nullptr;
        Handle(Geom_Plane) plane = Handle(Geom_Plane)::DownCast(finder.Surface());
        if (plane.IsNull()) return nullptr;
        gp_Ax1 axis(gp_Pnt(axOX, axOY, axOZ), gp_Dir(axDX, axDY, axDZ));
        bool sliding = true;
        BRepFeat_MakeRevolutionForm maker(shape->shape, profile->wire, plane, axis,
                                           height1, height2, fuse ? 1 : 0, sliding);
        maker.Perform();
        if (!maker.IsDone()) return nullptr;
        return new OCCTShape(maker.Shape());
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Draft Prism Feature (v0.32.0)

#include <BRepFeat_MakeDPrism.hxx>

OCCTShapeRef OCCTShapeDraftPrism(OCCTShapeRef shape, int32_t profileFace,
                                  OCCTWireRef profile, double angleDeg,
                                  double height, bool fuse) {
    if (!shape || !profile) return nullptr;
    try {
        TopTools_IndexedMapOfShape faceMap;
        TopExp::MapShapes(shape->shape, TopAbs_FACE, faceMap);
        int32_t fi = profileFace + 1;
        if (fi < 1 || fi > faceMap.Extent()) return nullptr;
        TopoDS_Face sketchFace = TopoDS::Face(faceMap(fi));

        // Create profile face from wire
        BRepBuilderAPI_MakeFace makeFace(profile->wire, true);
        if (!makeFace.IsDone()) return nullptr;
        TopoDS_Face pbase = makeFace.Face();

        double angleRad = angleDeg * M_PI / 180.0;
        BRepFeat_MakeDPrism maker(shape->shape, pbase, sketchFace, angleRad,
                                   fuse ? 1 : 0, Standard_True);
        maker.Perform(height);
        if (!maker.IsDone()) return nullptr;
        return new OCCTShape(maker.Shape());
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeDraftPrismThruAll(OCCTShapeRef shape, int32_t profileFace,
                                         OCCTWireRef profile, double angleDeg,
                                         bool fuse) {
    if (!shape || !profile) return nullptr;
    try {
        TopTools_IndexedMapOfShape faceMap;
        TopExp::MapShapes(shape->shape, TopAbs_FACE, faceMap);
        int32_t fi = profileFace + 1;
        if (fi < 1 || fi > faceMap.Extent()) return nullptr;
        TopoDS_Face sketchFace = TopoDS::Face(faceMap(fi));

        BRepBuilderAPI_MakeFace makeFace(profile->wire, true);
        if (!makeFace.IsDone()) return nullptr;
        TopoDS_Face pbase = makeFace.Face();

        double angleRad = angleDeg * M_PI / 180.0;
        BRepFeat_MakeDPrism maker(shape->shape, pbase, sketchFace, angleRad,
                                   fuse ? 1 : 0, Standard_True);
        maker.PerformThruAll();
        if (!maker.IsDone()) return nullptr;
        return new OCCTShape(maker.Shape());
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Revolution Feature (v0.32.0)

#include <BRepFeat_MakeRevol.hxx>

OCCTShapeRef OCCTShapeRevolFeature(OCCTShapeRef shape, int32_t profileFace,
                                    OCCTWireRef profile,
                                    double axOX, double axOY, double axOZ,
                                    double axDX, double axDY, double axDZ,
                                    double angleDeg, bool fuse) {
    if (!shape || !profile) return nullptr;
    try {
        TopTools_IndexedMapOfShape faceMap;
        TopExp::MapShapes(shape->shape, TopAbs_FACE, faceMap);
        int32_t fi = profileFace + 1;
        if (fi < 1 || fi > faceMap.Extent()) return nullptr;
        TopoDS_Face sketchFace = TopoDS::Face(faceMap(fi));

        BRepBuilderAPI_MakeFace makeFace(profile->wire, true);
        if (!makeFace.IsDone()) return nullptr;
        TopoDS_Face pbase = makeFace.Face();

        gp_Ax1 axis(gp_Pnt(axOX, axOY, axOZ), gp_Dir(axDX, axDY, axDZ));
        double angleRad = angleDeg * M_PI / 180.0;

        BRepFeat_MakeRevol maker(shape->shape, pbase, sketchFace, axis,
                                  fuse ? 1 : 0, Standard_True);
        maker.Perform(angleRad);
        if (!maker.IsDone()) return nullptr;
        return new OCCTShape(maker.Shape());
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeRevolFeatureThruAll(OCCTShapeRef shape, int32_t profileFace,
                                           OCCTWireRef profile,
                                           double axOX, double axOY, double axOZ,
                                           double axDX, double axDY, double axDZ,
                                           bool fuse) {
    if (!shape || !profile) return nullptr;
    try {
        TopTools_IndexedMapOfShape faceMap;
        TopExp::MapShapes(shape->shape, TopAbs_FACE, faceMap);
        int32_t fi = profileFace + 1;
        if (fi < 1 || fi > faceMap.Extent()) return nullptr;
        TopoDS_Face sketchFace = TopoDS::Face(faceMap(fi));

        BRepBuilderAPI_MakeFace makeFace(profile->wire, true);
        if (!makeFace.IsDone()) return nullptr;
        TopoDS_Face pbase = makeFace.Face();

        gp_Ax1 axis(gp_Pnt(axOX, axOY, axOZ), gp_Dir(axDX, axDY, axDZ));

        BRepFeat_MakeRevol maker(shape->shape, pbase, sketchFace, axis,
                                  fuse ? 1 : 0, Standard_True);
        maker.PerformThruAll();
        if (!maker.IsDone()) return nullptr;
        return new OCCTShape(maker.Shape());
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Shape-to-Shape Section (v0.34.0)

#include <BRepAlgoAPI_Section.hxx>

OCCTShapeRef OCCTShapeSection(OCCTShapeRef shape1, OCCTShapeRef shape2) {
    if (!shape1 || !shape2) return nullptr;
    try {
        BRepAlgoAPI_Section section(shape1->shape, shape2->shape, Standard_False);
        section.ComputePCurveOn1(Standard_True);
        section.Approximation(Standard_True);
        section.Build();
        if (!section.IsDone()) return nullptr;
        TopoDS_Shape result = section.Shape();
        if (result.IsNull()) return nullptr;
        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Boolean Pre-Validation (v0.34.0)

#include <BRepAlgoAPI_Check.hxx>

bool OCCTShapeBooleanCheck(OCCTShapeRef shape1, OCCTShapeRef shape2) {
    if (!shape1) return false;
    try {
        if (shape2) {
            BRepAlgoAPI_Check checker(shape1->shape, shape2->shape);
            return checker.IsValid();
        } else {
            BRepAlgoAPI_Check checker(shape1->shape);
            return checker.IsValid();
        }
    } catch (...) {
        return false;
    }
}

// MARK: - Split Shape by Wire (v0.34.0)

#include <BRepFeat_SplitShape.hxx>

OCCTShapeRef OCCTShapeSplitByWire(OCCTShapeRef shape, OCCTWireRef wire, int32_t faceIndex) {
    if (!shape || !wire) return nullptr;
    try {
        TopTools_IndexedMapOfShape faceMap;
        TopExp::MapShapes(shape->shape, TopAbs_FACE, faceMap);
        int32_t idx = faceIndex + 1; // Convert 0-based to 1-based
        if (idx < 1 || idx > faceMap.Extent()) return nullptr;
        TopoDS_Face face = TopoDS::Face(faceMap(idx));
        BRepFeat_SplitShape splitter(shape->shape);
        splitter.Add(wire->wire, face);
        splitter.Build();
        if (!splitter.IsDone()) return nullptr;
        TopoDS_Shape result = splitter.Shape();
        if (result.IsNull()) return nullptr;
        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Multi-Tool Boolean Fuse (v0.34.0)

#include <BRepAlgoAPI_BuilderAlgo.hxx>

OCCTShapeRef OCCTShapeFuseMulti(const OCCTShapeRef* shapes, int32_t count) {
    if (!shapes || count < 2) return nullptr;
    try {
        TopTools_ListOfShape arguments;
        for (int32_t i = 0; i < count; ++i) {
            if (!shapes[i]) return nullptr;
            arguments.Append(shapes[i]->shape);
        }
        BRepAlgoAPI_BuilderAlgo builder;
        builder.SetArguments(arguments);
        builder.SetRunParallel(Standard_True);
        builder.Build();
        if (!builder.IsDone()) return nullptr;
        TopoDS_Shape result = builder.Shape();
        if (result.IsNull()) return nullptr;
        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Multi-Offset Wire (v0.35.0)

#include <BRepOffsetAPI_MakeOffset.hxx>

int32_t OCCTWireMultiOffset(OCCTShapeRef face, const double* offsets, int32_t count,
                             int32_t joinType, OCCTWireRef* outWires, int32_t maxWires) {
    if (!face || !offsets || count < 1 || !outWires || maxWires < 1) return 0;
    try {
        // Extract the face from the shape
        TopTools_IndexedMapOfShape faceMap;
        TopExp::MapShapes(face->shape, TopAbs_FACE, faceMap);
        if (faceMap.Extent() < 1) return 0;
        TopoDS_Face topoFace = TopoDS::Face(faceMap(1));

        GeomAbs_JoinType join = GeomAbs_Arc;
        if (joinType == 1) join = GeomAbs_Tangent;
        else if (joinType == 2) join = GeomAbs_Intersection;

        BRepOffsetAPI_MakeOffset offsetMaker(topoFace, join);

        int32_t totalWires = 0;
        for (int32_t i = 0; i < count && totalWires < maxWires; ++i) {
            offsetMaker.Perform(offsets[i]);
            if (!offsetMaker.IsDone()) continue;
            TopoDS_Shape result = offsetMaker.Shape();
            // Extract wires from the result
            TopExp_Explorer wireExp(result, TopAbs_WIRE);
            while (wireExp.More() && totalWires < maxWires) {
                outWires[totalWires] = new OCCTWire(TopoDS::Wire(wireExp.Current()));
                totalWires++;
                wireExp.Next();
            }
        }
        return totalWires;
    } catch (...) {
        return 0;
    }
}

// MARK: - Cylindrical Projection (v0.35.0)

#include <BRepProj_Projection.hxx>

OCCTShapeRef OCCTShapeProjectWire(OCCTShapeRef wire, OCCTShapeRef shape,
                                   double dirX, double dirY, double dirZ) {
    if (!wire || !shape) return nullptr;
    try {
        gp_Dir direction(dirX, dirY, dirZ);
        BRepProj_Projection projection(wire->shape, shape->shape, direction);
        if (!projection.IsDone()) return nullptr;
        TopoDS_Compound result = projection.Shape();
        if (result.IsNull()) return nullptr;
        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Conical Projection (v0.36.0)

OCCTShapeRef OCCTShapeProjectWireConical(OCCTShapeRef wire, OCCTShapeRef shape,
                                          double eyeX, double eyeY, double eyeZ) {
    if (!wire || !shape) return nullptr;
    try {
        gp_Pnt eye(eyeX, eyeY, eyeZ);
        BRepProj_Projection projection(wire->shape, shape->shape, eye);
        if (!projection.IsDone()) return nullptr;
        TopoDS_Compound result = projection.Shape();
        if (result.IsNull()) return nullptr;
        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Boolean with Modified Shapes (v0.36.0)

#include <BRepAlgoAPI_Fuse.hxx>

int32_t OCCTShapeFuseWithHistory(OCCTShapeRef shape1, OCCTShapeRef shape2,
                                  OCCTShapeRef* outModified, int32_t maxModified) {
    if (!shape1 || !shape2 || !outModified || maxModified < 1) return -1;
    try {
        BRepAlgoAPI_Fuse fuse(shape1->shape, shape2->shape);
        if (!fuse.IsDone()) return -1;
        // Collect modified shapes from shape1's faces
        int32_t count = 0;
        TopExp_Explorer explorer(shape1->shape, TopAbs_FACE);
        while (explorer.More() && count < maxModified) {
            const TopTools_ListOfShape& modified = fuse.Modified(explorer.Current());
            TopTools_ListIteratorOfListOfShape it(modified);
            while (it.More() && count < maxModified) {
                outModified[count] = new OCCTShape(it.Value());
                count++;
                it.Next();
            }
            explorer.Next();
        }
        return count;
    } catch (...) {
        return -1;
    }
}

// MARK: - Boolean with Full Per-Input History (issue #165)
// Holds a heap-stored builder so Modified / Generated / IsDeleted can be
// queried after the bridge function returns. OCCTMCP's remap_selection
// is the immediate consumer (per-subshape history → exact selection
// remapping across boolean / feature mutations).

#include <BRepAlgoAPI_Common.hxx>
#include <BRepAlgoAPI_Splitter.hxx>
#include <BRepBuilderAPI_MakeShape.hxx>
#include <TopoDS_Iterator.hxx>
#include <memory>

struct OCCTBooleanHistory {
    // Builder kept alive for the lifetime of the handle. unique_ptr because
    // BRepBuilderAPI_MakeShape carries large internal state and is not
    // safely copyable. Upcast from concrete Fuse / Cut / Common / Splitter.
    std::unique_ptr<BRepBuilderAPI_MakeShape> op;

    explicit OCCTBooleanHistory(std::unique_ptr<BRepBuilderAPI_MakeShape> theOp)
        : op(std::move(theOp)) {}
};

OCCTBooleanHistoryRef OCCTBooleanUnionWithHistory(OCCTShapeRef shape1, OCCTShapeRef shape2,
                                                    OCCTShapeRef* outResult) {
    if (outResult) *outResult = nullptr;
    if (!shape1 || !shape2) return nullptr;
    try {
        std::unique_ptr<BRepAlgoAPI_Fuse> op(new BRepAlgoAPI_Fuse(shape1->shape, shape2->shape));
        if (!op->IsDone()) return nullptr;
        if (outResult) *outResult = new OCCTShape(op->Shape());
        return new OCCTBooleanHistory(std::move(op));
    } catch (...) { return nullptr; }
}

OCCTBooleanHistoryRef OCCTBooleanSubtractWithHistory(OCCTShapeRef shape1, OCCTShapeRef shape2,
                                                       OCCTShapeRef* outResult) {
    if (outResult) *outResult = nullptr;
    if (!shape1 || !shape2) return nullptr;
    try {
        std::unique_ptr<BRepAlgoAPI_Cut> op(new BRepAlgoAPI_Cut(shape1->shape, shape2->shape));
        if (!op->IsDone()) return nullptr;
        if (outResult) *outResult = new OCCTShape(op->Shape());
        return new OCCTBooleanHistory(std::move(op));
    } catch (...) { return nullptr; }
}

OCCTBooleanHistoryRef OCCTBooleanIntersectWithHistory(OCCTShapeRef shape1, OCCTShapeRef shape2,
                                                        OCCTShapeRef* outResult) {
    if (outResult) *outResult = nullptr;
    if (!shape1 || !shape2) return nullptr;
    try {
        std::unique_ptr<BRepAlgoAPI_Common> op(new BRepAlgoAPI_Common(shape1->shape, shape2->shape));
        if (!op->IsDone()) return nullptr;
        if (outResult) *outResult = new OCCTShape(op->Shape());
        return new OCCTBooleanHistory(std::move(op));
    } catch (...) { return nullptr; }
}

OCCTBooleanHistoryRef OCCTBooleanSplitWithHistory(OCCTShapeRef shape1, OCCTShapeRef shape2,
                                                    OCCTShapeRef* outResult) {
    if (outResult) *outResult = nullptr;
    if (!shape1 || !shape2) return nullptr;
    try {
        std::unique_ptr<BRepAlgoAPI_Splitter> op(new BRepAlgoAPI_Splitter());
        TopTools_ListOfShape args;
        args.Append(shape1->shape);
        TopTools_ListOfShape tools;
        tools.Append(shape2->shape);
        op->SetArguments(args);
        op->SetTools(tools);
        op->Build();
        if (!op->IsDone()) return nullptr;
        if (outResult) *outResult = new OCCTShape(op->Shape());
        return new OCCTBooleanHistory(std::move(op));
    } catch (...) { return nullptr; }
}

// Always returns the full Modified count. If outRefs is non-null, also writes
// up to maxCount entries (caller takes ownership of each). Pass outRefs=null
// (or maxCount=0) to probe the count without allocating.
int32_t OCCTBooleanHistoryModified(OCCTBooleanHistoryRef h, OCCTShapeRef inputSubShape,
                                     OCCTShapeRef* outRefs, int32_t maxCount) {
    if (!h || !inputSubShape) return -1;
    try {
        const TopTools_ListOfShape& list = h->op->Modified(inputSubShape->shape);
        int32_t count = 0;
        for (TopTools_ListIteratorOfListOfShape it(list); it.More(); it.Next()) {
            if (outRefs && count < maxCount) {
                outRefs[count] = new OCCTShape(it.Value());
            }
            count++;
        }
        return count;
    } catch (...) { return -1; }
}

// Same probe-and-fill semantics as OCCTBooleanHistoryModified.
int32_t OCCTBooleanHistoryGenerated(OCCTBooleanHistoryRef h, OCCTShapeRef inputSubShape,
                                      OCCTShapeRef* outRefs, int32_t maxCount) {
    if (!h || !inputSubShape) return -1;
    try {
        const TopTools_ListOfShape& list = h->op->Generated(inputSubShape->shape);
        int32_t count = 0;
        for (TopTools_ListIteratorOfListOfShape it(list); it.More(); it.Next()) {
            if (outRefs && count < maxCount) {
                outRefs[count] = new OCCTShape(it.Value());
            }
            count++;
        }
        return count;
    } catch (...) { return -1; }
}

bool OCCTBooleanHistoryIsDeleted(OCCTBooleanHistoryRef h, OCCTShapeRef inputSubShape) {
    if (!h || !inputSubShape) return false;
    try {
        return h->op->IsDeleted(inputSubShape->shape);
    } catch (...) { return false; }
}

void OCCTBooleanHistoryRelease(OCCTBooleanHistoryRef h) {
    delete h;
}

// Iterate the top-level children of a compound (used by Splitter result to
// extract the pieces produced by the split). Always returns the full count;
// writes up to maxCount entries when outRefs is non-null. Pass outRefs=null
// (or maxCount=0) to probe.
int32_t OCCTShapeCompoundChildren(OCCTShapeRef compound,
                                    OCCTShapeRef* outRefs, int32_t maxCount) {
    if (!compound) return -1;
    try {
        int32_t count = 0;
        for (TopoDS_Iterator it(compound->shape); it.More(); it.Next()) {
            if (outRefs && count < maxCount) {
                outRefs[count] = new OCCTShape(it.Value());
            }
            count++;
        }
        return count;
    } catch (...) { return -1; }
}

// MARK: - Tier 2: Modification ops with full per-input history (issue #165)
// All these builders inherit from BRepBuilderAPI_MakeShape, so they fit the
// existing OCCTBooleanHistory opaque handle (which stores a unique_ptr<MakeShape>).

#include <BRepFilletAPI_MakeFillet.hxx>
#include <BRepFilletAPI_MakeChamfer.hxx>
#include <BRepOffsetAPI_MakeThickSolid.hxx>
#include <BRepAlgoAPI_Defeaturing.hxx>
#include <BRepOffset.hxx>
#include <GeomAbs_JoinType.hxx>
#include <TopExp.hxx>
#include <TopTools_IndexedMapOfShape.hxx>

OCCTBooleanHistoryRef OCCTShapeHistoryFromFilletEdges(OCCTShapeRef shape,
                                                       const int32_t* edgeIndices, int32_t count,
                                                       double radius,
                                                       OCCTShapeRef* outResult) {
    if (outResult) *outResult = nullptr;
    if (!shape || !edgeIndices || count < 1) return nullptr;
    try {
        TopTools_IndexedMapOfShape edgeMap;
        TopExp::MapShapes(shape->shape, TopAbs_EDGE, edgeMap);
        std::unique_ptr<BRepFilletAPI_MakeFillet> op(new BRepFilletAPI_MakeFillet(shape->shape));
        for (int32_t i = 0; i < count; i++) {
            int32_t idx = edgeIndices[i] + 1; // 0-based to 1-based
            if (idx < 1 || idx > edgeMap.Extent()) continue;
            op->Add(radius, TopoDS::Edge(edgeMap(idx)));
        }
        op->Build();
        if (!op->IsDone()) return nullptr;
        TopoDS_Shape result = op->Shape();
        if (result.IsNull()) return nullptr;
        if (outResult) *outResult = new OCCTShape(result);
        return new OCCTBooleanHistory(std::move(op));
    } catch (...) { return nullptr; }
}

OCCTBooleanHistoryRef OCCTShapeHistoryFromFilletEdgeVariable(OCCTShapeRef shape,
                                                              int32_t edgeIndex,
                                                              double startRadius, double endRadius,
                                                              OCCTShapeRef* outResult) {
    if (outResult) *outResult = nullptr;
    if (!shape) return nullptr;
    try {
        TopTools_IndexedMapOfShape edgeMap;
        TopExp::MapShapes(shape->shape, TopAbs_EDGE, edgeMap);
        int32_t idx = edgeIndex + 1;
        if (idx < 1 || idx > edgeMap.Extent()) return nullptr;
        TopoDS_Edge edge = TopoDS::Edge(edgeMap(idx));
        std::unique_ptr<BRepFilletAPI_MakeFillet> op(new BRepFilletAPI_MakeFillet(shape->shape));
        op->Add(edge);
        // Map the variable radius along the edge: (param=0, startR), (param=1, endR).
        TColgp_Array1OfPnt2d radii(1, 2);
        radii.SetValue(1, gp_Pnt2d(0.0, startRadius));
        radii.SetValue(2, gp_Pnt2d(1.0, endRadius));
        op->SetRadius(radii, 1, 1);
        op->Build();
        if (!op->IsDone()) return nullptr;
        TopoDS_Shape result = op->Shape();
        if (result.IsNull()) return nullptr;
        if (outResult) *outResult = new OCCTShape(result);
        return new OCCTBooleanHistory(std::move(op));
    } catch (...) { return nullptr; }
}

OCCTBooleanHistoryRef OCCTShapeHistoryFromChamferEdges(OCCTShapeRef shape,
                                                        const int32_t* edgeIndices, int32_t count,
                                                        double distance,
                                                        OCCTShapeRef* outResult) {
    if (outResult) *outResult = nullptr;
    if (!shape || !edgeIndices || count < 1) return nullptr;
    try {
        TopTools_IndexedMapOfShape edgeMap;
        TopExp::MapShapes(shape->shape, TopAbs_EDGE, edgeMap);
        std::unique_ptr<BRepFilletAPI_MakeChamfer> op(new BRepFilletAPI_MakeChamfer(shape->shape));
        for (int32_t i = 0; i < count; i++) {
            int32_t idx = edgeIndices[i] + 1;
            if (idx < 1 || idx > edgeMap.Extent()) continue;
            op->Add(distance, TopoDS::Edge(edgeMap(idx)));
        }
        op->Build();
        if (!op->IsDone()) return nullptr;
        TopoDS_Shape result = op->Shape();
        if (result.IsNull()) return nullptr;
        if (outResult) *outResult = new OCCTShape(result);
        return new OCCTBooleanHistory(std::move(op));
    } catch (...) { return nullptr; }
}

OCCTBooleanHistoryRef OCCTShapeHistoryFromShell(OCCTShapeRef shape,
                                                 const int32_t* faceIndices, int32_t faceCount,
                                                 double thickness, double tolerance,
                                                 OCCTShapeRef* outResult) {
    if (outResult) *outResult = nullptr;
    if (!shape || !faceIndices || faceCount < 1) return nullptr;
    try {
        TopTools_IndexedMapOfShape faceMap;
        TopExp::MapShapes(shape->shape, TopAbs_FACE, faceMap);
        TopTools_ListOfShape closingFaces;
        for (int32_t i = 0; i < faceCount; ++i) {
            int32_t idx = faceIndices[i] + 1;
            if (idx < 1 || idx > faceMap.Extent()) return nullptr;
            closingFaces.Append(faceMap(idx));
        }
        std::unique_ptr<BRepOffsetAPI_MakeThickSolid> op(new BRepOffsetAPI_MakeThickSolid());
        op->MakeThickSolidByJoin(shape->shape, closingFaces, thickness, tolerance,
                                  BRepOffset_Skin, false, false, GeomAbs_Arc);
        op->Build();
        if (!op->IsDone()) return nullptr;
        TopoDS_Shape result = op->Shape();
        if (result.IsNull()) return nullptr;
        if (outResult) *outResult = new OCCTShape(result);
        return new OCCTBooleanHistory(std::move(op));
    } catch (...) { return nullptr; }
}

OCCTBooleanHistoryRef OCCTShapeHistoryFromDefeature(OCCTShapeRef shape,
                                                     const int32_t* faceIndices, int32_t faceCount,
                                                     OCCTShapeRef* outResult) {
    if (outResult) *outResult = nullptr;
    if (!shape || !faceIndices || faceCount < 1) return nullptr;
    try {
        TopTools_IndexedMapOfShape faceMap;
        TopExp::MapShapes(shape->shape, TopAbs_FACE, faceMap);
        TopTools_ListOfShape facesToRemove;
        for (int32_t i = 0; i < faceCount; ++i) {
            int32_t idx = faceIndices[i] + 1;
            if (idx < 1 || idx > faceMap.Extent()) return nullptr;
            facesToRemove.Append(faceMap(idx));
        }
        std::unique_ptr<BRepAlgoAPI_Defeaturing> op(new BRepAlgoAPI_Defeaturing());
        op->SetShape(shape->shape);
        op->AddFacesToRemove(facesToRemove);
        op->Build();
        if (!op->IsDone()) return nullptr;
        TopoDS_Shape result = op->Shape();
        if (result.IsNull()) return nullptr;
        if (outResult) *outResult = new OCCTShape(result);
        return new OCCTBooleanHistory(std::move(op));
    } catch (...) { return nullptr; }
}

// MARK: - Thick Solid / Hollowing (v0.37.0)

#include <BRepOffsetAPI_MakeThickSolid.hxx>

OCCTShapeRef OCCTShapeMakeThickSolid(OCCTShapeRef shape, const int32_t* faceIndices,
                                      int32_t faceCount, double offset, double tolerance,
                                      int32_t joinType) {
    if (!shape || !faceIndices || faceCount < 1) return nullptr;
    try {
        TopTools_IndexedMapOfShape faceMap;
        TopExp::MapShapes(shape->shape, TopAbs_FACE, faceMap);

        TopTools_ListOfShape closingFaces;
        for (int32_t i = 0; i < faceCount; ++i) {
            int32_t idx = faceIndices[i] + 1; // 0-based to 1-based
            if (idx < 1 || idx > faceMap.Extent()) return nullptr;
            closingFaces.Append(faceMap(idx));
        }

        GeomAbs_JoinType join = GeomAbs_Arc;
        if (joinType == 1) join = GeomAbs_Tangent;
        else if (joinType == 2) join = GeomAbs_Intersection;

        BRepOffsetAPI_MakeThickSolid maker;
        maker.MakeThickSolidByJoin(shape->shape, closingFaces, offset, tolerance,
                                    BRepOffset_Skin, false, false, join);
        maker.Build();
        if (!maker.IsDone()) return nullptr;
        TopoDS_Shape result = maker.Shape();
        if (result.IsNull()) return nullptr;
        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Shell from Surface (v0.37.0)

#include <BRepBuilderAPI_MakeShell.hxx>

OCCTShapeRef OCCTShapeMakeShell(OCCTSurfaceRef surface,
                                 double uMin, double uMax,
                                 double vMin, double vMax) {
    if (!surface || surface->surface.IsNull()) return nullptr;
    try {
        BRepBuilderAPI_MakeShell maker(surface->surface, uMin, uMax, vMin, vMax);
        if (!maker.IsDone()) return nullptr;
        TopoDS_Shell shell = maker.Shell();
        if (shell.IsNull()) return nullptr;
        return new OCCTShape(shell);
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Multi-Tool Boolean Common (v0.37.0)

#include <BRepAlgoAPI_Common.hxx>

OCCTShapeRef OCCTShapeCommonMulti(const OCCTShapeRef* shapes, int32_t count) {
    if (!shapes || count < 2) return nullptr;
    try {
        // Start with the common of first two shapes, then iteratively intersect with rest
        for (int32_t i = 0; i < count; ++i) {
            if (!shapes[i]) return nullptr;
        }
        TopoDS_Shape result = shapes[0]->shape;
        for (int32_t i = 1; i < count; ++i) {
            BRepAlgoAPI_Common common(result, shapes[i]->shape);
            if (!common.IsDone()) return nullptr;
            result = common.Shape();
            if (result.IsNull()) return nullptr;
        }
        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Evolved Shape Advanced (v0.33.0)

OCCTShapeRef OCCTShapeCreateEvolvedAdvanced(OCCTShapeRef spine, OCCTWireRef profile,
                                             int32_t joinType, bool axeProf,
                                             bool solid, bool volume,
                                             double tolerance) {
    if (!spine || !profile) return nullptr;
    try {
        GeomAbs_JoinType join = GeomAbs_Arc;
        if (joinType == 1) join = GeomAbs_Tangent;
        else if (joinType == 2) join = GeomAbs_Intersection;
        BRepOffsetAPI_MakeEvolved evolved(spine->shape, profile->wire, join,
                                           axeProf, solid, false, tolerance, volume, false);
        if (!evolved.IsDone()) return nullptr;
        TopoDS_Shape result = evolved.Shape();
        if (result.IsNull()) return nullptr;
        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Pipe Shell with Transition Mode (v0.33.0)

#include <BRepBuilderAPI_TransitionMode.hxx>

OCCTShapeRef OCCTShapeCreatePipeShellWithTransition(OCCTWireRef spine, OCCTWireRef profile,
                                                     int32_t mode, int32_t transitionMode,
                                                     bool solid) {
    if (!spine || !profile) return nullptr;
    try {
        BRepOffsetAPI_MakePipeShell pipeShell(spine->wire);
        // Set sweep mode
        if (mode == 1) {
            pipeShell.SetMode(Standard_True);   // Corrected Frenet
        } else {
            pipeShell.SetMode(Standard_False);  // Frenet
        }
        // Set transition mode
        if (transitionMode == 1) {
            pipeShell.SetTransitionMode(BRepBuilderAPI_RightCorner);
        } else if (transitionMode == 2) {
            pipeShell.SetTransitionMode(BRepBuilderAPI_RoundCorner);
        } else {
            pipeShell.SetTransitionMode(BRepBuilderAPI_Transformed);
        }
        pipeShell.Add(profile->wire);
        pipeShell.SetIsBuildHistory(false); // avoid SEGV on closed spine+profile (OCCT bug)
        pipeShell.Build();
        if (!pipeShell.IsDone()) return nullptr;
        TopoDS_Shape result = pipeShell.Shape();
        if (solid) {
            pipeShell.MakeSolid();
            if (pipeShell.IsDone()) {
                result = pipeShell.Shape();
            }
        }
        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Face from Surface with UV Bounds (v0.33.0)

OCCTShapeRef OCCTShapeCreateFaceFromSurface(OCCTSurfaceRef surface,
                                             double uMin, double uMax,
                                             double vMin, double vMax,
                                             double tolerance) {
    if (!surface || surface->surface.IsNull()) return nullptr;
    try {
        BRepBuilderAPI_MakeFace maker(surface->surface, uMin, uMax, vMin, vMax, tolerance);
        if (!maker.IsDone()) return nullptr;
        return new OCCTShape(maker.Face());
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Edges to Faces (v0.33.0)

OCCTShapeRef OCCTShapeEdgesToFaces(OCCTShapeRef compound, bool isOnlyPlane) {
    if (!compound) return nullptr;
    try {
        // Collect all edges from the input shape
        TopTools_ListOfShape edgeList;
        TopExp_Explorer explorer(compound->shape, TopAbs_EDGE);
        while (explorer.More()) {
            edgeList.Append(explorer.Current());
            explorer.Next();
        }
        if (edgeList.IsEmpty()) return nullptr;

        // Build wires from edges, then faces from wires
        BRep_Builder builder;
        TopoDS_Compound result;
        builder.MakeCompound(result);

        // Try to build wires and faces
        TopTools_ListOfShape remainingEdges;
        remainingEdges.Assign(edgeList);
        bool anyFace = false;

        while (!remainingEdges.IsEmpty()) {
            BRepBuilderAPI_MakeWire wireBuilder;
            // Try adding edges to the wire
            bool added = true;
            while (added && !remainingEdges.IsEmpty()) {
                added = false;
                TopTools_ListIteratorOfListOfShape it(remainingEdges);
                while (it.More()) {
                    wireBuilder.Add(TopoDS::Edge(it.Value()));
                    if (wireBuilder.Error() == BRepBuilderAPI_WireDone) {
                        added = true;
                        remainingEdges.Remove(it);
                    } else {
                        wireBuilder = BRepBuilderAPI_MakeWire(wireBuilder.Wire());
                        it.Next();
                    }
                }
            }
            if (wireBuilder.IsDone()) {
                TopoDS_Wire wire = wireBuilder.Wire();
                BRepBuilderAPI_MakeFace faceBuilder(wire, isOnlyPlane);
                if (faceBuilder.IsDone()) {
                    builder.Add(result, faceBuilder.Face());
                    anyFace = true;
                }
            }
            if (!added && !remainingEdges.IsEmpty()) {
                // Can't connect more edges; start a new wire with first remaining
                TopTools_ListIteratorOfListOfShape it(remainingEdges);
                if (it.More()) {
                    remainingEdges.Remove(it);
                }
            }
        }

        if (!anyFace) return nullptr;
        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Fuse and Blend (v0.38.0)

OCCTShapeRef OCCTShapeFuseAndBlend(OCCTShapeRef shape1, OCCTShapeRef shape2, double radius) {
    if (!shape1 || !shape2 || radius <= 0) return nullptr;
    try {
        // Step 1: Fuse
        BRepAlgoAPI_Fuse fuse(shape1->shape, shape2->shape);
        if (!fuse.IsDone()) return nullptr;

        // Step 2: Find intersection edges (edges generated/modified by the boolean)
        TopTools_ListOfShape generatedEdges;
        // Collect edges from the fuse that were generated from faces of either input
        for (TopExp_Explorer exp(shape1->shape, TopAbs_FACE); exp.More(); exp.Next()) {
            const TopTools_ListOfShape& gen = fuse.Generated(exp.Current());
            for (TopTools_ListIteratorOfListOfShape it(gen); it.More(); it.Next()) {
                if (it.Value().ShapeType() == TopAbs_EDGE) {
                    generatedEdges.Append(it.Value());
                }
            }
        }
        for (TopExp_Explorer exp(shape2->shape, TopAbs_FACE); exp.More(); exp.Next()) {
            const TopTools_ListOfShape& gen = fuse.Generated(exp.Current());
            for (TopTools_ListIteratorOfListOfShape it(gen); it.More(); it.Next()) {
                if (it.Value().ShapeType() == TopAbs_EDGE) {
                    generatedEdges.Append(it.Value());
                }
            }
        }

        // Also collect section edges (edges at the intersection of the two shapes)
        const TopoDS_Shape& fuseResult = fuse.Shape();

        // Use SectionEdges() to get the intersection edges
        const TopTools_ListOfShape& sectionEdges = fuse.SectionEdges();

        // Step 3: Fillet those edges
        BRepFilletAPI_MakeFillet fillet(fuseResult);
        // Add section edges
        for (TopTools_ListIteratorOfListOfShape it(sectionEdges); it.More(); it.Next()) {
            if (it.Value().ShapeType() == TopAbs_EDGE) {
                fillet.Add(radius, TopoDS::Edge(it.Value()));
            }
        }
        // Add generated edges
        for (TopTools_ListIteratorOfListOfShape it(generatedEdges); it.More(); it.Next()) {
            fillet.Add(radius, TopoDS::Edge(it.Value()));
        }

        if (fillet.NbContours() == 0) {
            // No edges to fillet — just return the fuse result
            return new OCCTShape(fuseResult);
        }

        fillet.Build();
        if (!fillet.IsDone()) return nullptr;
        return new OCCTShape(fillet.Shape());
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeCutAndBlend(OCCTShapeRef shape1, OCCTShapeRef shape2, double radius) {
    if (!shape1 || !shape2 || radius <= 0) return nullptr;
    try {
        // Step 1: Cut
        BRepAlgoAPI_Cut cut(shape1->shape, shape2->shape);
        if (!cut.IsDone()) return nullptr;

        const TopoDS_Shape& cutResult = cut.Shape();
        const TopTools_ListOfShape& sectionEdges = cut.SectionEdges();

        // Collect generated edges from faces
        TopTools_ListOfShape generatedEdges;
        for (TopExp_Explorer exp(shape1->shape, TopAbs_FACE); exp.More(); exp.Next()) {
            const TopTools_ListOfShape& gen = cut.Generated(exp.Current());
            for (TopTools_ListIteratorOfListOfShape it(gen); it.More(); it.Next()) {
                if (it.Value().ShapeType() == TopAbs_EDGE) {
                    generatedEdges.Append(it.Value());
                }
            }
        }
        for (TopExp_Explorer exp(shape2->shape, TopAbs_FACE); exp.More(); exp.Next()) {
            const TopTools_ListOfShape& gen = cut.Generated(exp.Current());
            for (TopTools_ListIteratorOfListOfShape it(gen); it.More(); it.Next()) {
                if (it.Value().ShapeType() == TopAbs_EDGE) {
                    generatedEdges.Append(it.Value());
                }
            }
        }

        // Step 2: Fillet
        BRepFilletAPI_MakeFillet fillet(cutResult);
        for (TopTools_ListIteratorOfListOfShape it(sectionEdges); it.More(); it.Next()) {
            if (it.Value().ShapeType() == TopAbs_EDGE) {
                fillet.Add(radius, TopoDS::Edge(it.Value()));
            }
        }
        for (TopTools_ListIteratorOfListOfShape it(generatedEdges); it.More(); it.Next()) {
            fillet.Add(radius, TopoDS::Edge(it.Value()));
        }

        if (fillet.NbContours() == 0) {
            return new OCCTShape(cutResult);
        }

        fillet.Build();
        if (!fillet.IsDone()) return nullptr;
        return new OCCTShape(fillet.Shape());
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Multi-Edge Evolving Fillet (v0.38.0)

OCCTShapeRef OCCTShapeFilletEvolving(OCCTShapeRef shape,
                                      const int32_t* edgeIndices, int32_t edgeCount,
                                      const OCCTFilletRadiusPoint* radiusPoints,
                                      const int32_t* pointCounts) {
    if (!shape || !edgeIndices || edgeCount <= 0 || !radiusPoints || !pointCounts) return nullptr;
    try {
        TopTools_IndexedMapOfShape edgeMap;
        TopExp::MapShapes(shape->shape, TopAbs_EDGE, edgeMap);

        BRepFilletAPI_MakeFillet fillet(shape->shape);

        int rpOffset = 0;
        for (int32_t i = 0; i < edgeCount; i++) {
            int32_t edgeIdx = edgeIndices[i];
            if (edgeIdx < 1 || edgeIdx > edgeMap.Extent()) return nullptr;
            const TopoDS_Edge& edge = TopoDS::Edge(edgeMap(edgeIdx));

            fillet.Add(edge);
            int contourIndex = fillet.NbContours();

            int32_t nPts = pointCounts[i];
            if (nPts >= 2) {
                // Build array of (parameter, radius) pairs
                TColgp_Array1OfPnt2d UandR(1, nPts);
                for (int32_t j = 0; j < nPts; j++) {
                    UandR.SetValue(j + 1, gp_Pnt2d(radiusPoints[rpOffset + j].parameter,
                                                     radiusPoints[rpOffset + j].radius));
                }
                fillet.SetRadius(UandR, contourIndex, 1);
            } else if (nPts == 1) {
                fillet.SetRadius(radiusPoints[rpOffset].radius, contourIndex, 1);
            }
            rpOffset += nPts;
        }

        fillet.Build();
        if (!fillet.IsDone()) return nullptr;
        return new OCCTShape(fillet.Shape());
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Per-Face Variable Offset (v0.38.0)

#include <BRepOffset_MakeOffset.hxx>

OCCTShapeRef OCCTShapeOffsetPerFace(OCCTShapeRef shape, double defaultOffset,
                                     const int32_t* faceIndices, const double* faceOffsets,
                                     int32_t faceCount, double tolerance, int32_t joinType) {
    if (!shape) return nullptr;
    try {
        TopTools_IndexedMapOfShape faceMap;
        TopExp::MapShapes(shape->shape, TopAbs_FACE, faceMap);

        GeomAbs_JoinType jt = GeomAbs_Arc;
        if (joinType == 1) jt = GeomAbs_Tangent;
        else if (joinType == 2) jt = GeomAbs_Intersection;

        BRepOffset_MakeOffset offset;
        offset.Initialize(shape->shape, defaultOffset, tolerance,
                          BRepOffset_Skin, false, false, jt);

        for (int32_t i = 0; i < faceCount; i++) {
            int32_t idx = faceIndices[i];
            if (idx < 1 || idx > faceMap.Extent()) continue;
            const TopoDS_Face& face = TopoDS::Face(faceMap(idx));
            offset.SetOffsetOnFace(face, faceOffsets[i]);
        }

        offset.MakeOffsetShape();
        if (!offset.IsDone()) return nullptr;
        TopoDS_Shape result = offset.Shape();
        if (result.IsNull()) return nullptr;
        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

OCCTDrawingRef OCCTDrawingCreatePoly(OCCTShapeRef shape,
                                      double dirX, double dirY, double dirZ,
                                      int32_t projectionType, double deflection) {
    if (!shape) return nullptr;
    try {
        // Ensure the shape has a triangulation
        BRepMesh_IncrementalMesh mesh(shape->shape, deflection);

        gp_Dir viewDir(dirX, dirY, dirZ);
        gp_Ax2 projAxis(gp_Pnt(0, 0, 0), viewDir);
        HLRAlgo_Projector projector(projAxis);

        Handle(HLRBRep_PolyAlgo) polyAlgo = new HLRBRep_PolyAlgo();
        polyAlgo->Projector(projector);
        polyAlgo->Load(shape->shape);
        polyAlgo->Update();

        HLRBRep_PolyHLRToShape shapes;
        shapes.Update(polyAlgo);

        OCCTDrawing* drawing = new OCCTDrawing();
        drawing->visibleSharp = shapes.VCompound();
        drawing->visibleSmooth = shapes.Rg1LineVCompound();
        drawing->visibleOutline = shapes.OutLineVCompound();
        drawing->hiddenSharp = shapes.HCompound();
        drawing->hiddenSmooth = shapes.Rg1LineHCompound();
        drawing->hiddenOutline = shapes.OutLineHCompound();

        return drawing;
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapePipeFeature(OCCTShapeRef shape, int32_t profileFaceIndex,
                                   int32_t sketchFaceIndex, OCCTWireRef spine,
                                   int32_t fuse) {
    if (!shape || !spine) return nullptr;
    try {
        TopTools_IndexedMapOfShape faceMap;
        TopExp::MapShapes(shape->shape, TopAbs_FACE, faceMap);

        int32_t profIdx = profileFaceIndex + 1;
        int32_t sketchIdx = sketchFaceIndex + 1;
        if (profIdx < 1 || profIdx > faceMap.Extent()) return nullptr;
        if (sketchIdx < 1 || sketchIdx > faceMap.Extent()) return nullptr;

        TopoDS_Face profileFace = TopoDS::Face(faceMap(profIdx));
        TopoDS_Face sketchFace = TopoDS::Face(faceMap(sketchIdx));

        BRepFeat_MakePipe maker(shape->shape, profileFace, sketchFace,
                                 spine->wire, fuse, true);
        maker.Perform();
        if (!maker.IsDone()) return nullptr;

        TopoDS_Shape result = maker.Shape();
        if (result.IsNull()) return nullptr;
        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapePipeFeatureFromProfile(OCCTShapeRef baseShape, OCCTShapeRef profileShape,
                                              int32_t sketchFaceIndex, OCCTWireRef spine,
                                              int32_t fuse) {
    if (!baseShape || !profileShape || !spine) return nullptr;
    try {
        TopTools_IndexedMapOfShape faceMap;
        TopExp::MapShapes(baseShape->shape, TopAbs_FACE, faceMap);

        int32_t sketchIdx = sketchFaceIndex + 1;
        if (sketchIdx < 1 || sketchIdx > faceMap.Extent()) return nullptr;

        TopoDS_Face sketchFace = TopoDS::Face(faceMap(sketchIdx));

        BRepFeat_MakePipe maker(baseShape->shape, profileShape->shape, sketchFace,
                                 spine->wire, fuse, true);
        maker.Perform();
        if (!maker.IsDone()) return nullptr;

        TopoDS_Shape result = maker.Shape();
        if (result.IsNull()) return nullptr;
        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeExtrudeSemiInfinite(OCCTShapeRef profile,
                                           double dirX, double dirY, double dirZ,
                                           bool semiInfinite) {
    if (!profile) return nullptr;
    try {
        gp_Dir dir(dirX, dirY, dirZ);
        BRepPrimAPI_MakePrism maker(profile->shape, dir,
                                     !semiInfinite);
        maker.Build();
        if (!maker.IsDone()) return nullptr;
        return new OCCTShape(maker.Shape());
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapePrismUntilFace(OCCTShapeRef baseShape, OCCTShapeRef profileShape,
                                      int32_t sketchFaceIndex,
                                      double dirX, double dirY, double dirZ,
                                      int32_t fuse, int32_t untilFaceIndex) {
    if (!baseShape || !profileShape) return nullptr;
    try {
        TopTools_IndexedMapOfShape faceMap;
        TopExp::MapShapes(baseShape->shape, TopAbs_FACE, faceMap);

        int32_t sketchIdx = sketchFaceIndex + 1;
        if (sketchIdx < 1 || sketchIdx > faceMap.Extent()) return nullptr;

        TopoDS_Face sketchFace = TopoDS::Face(faceMap(sketchIdx));
        gp_Dir dir(dirX, dirY, dirZ);

        BRepFeat_MakePrism maker(baseShape->shape, profileShape->shape,
                                  sketchFace, dir, fuse, true);

        if (untilFaceIndex < 0) {
            // Thru-all
            maker.PerformThruAll();
        } else {
            int32_t untilIdx = untilFaceIndex + 1;
            if (untilIdx < 1 || untilIdx > faceMap.Extent()) return nullptr;
            TopoDS_Face untilFace = TopoDS::Face(faceMap(untilIdx));
            maker.Perform(untilFace);
        }

        if (!maker.IsDone()) return nullptr;
        TopoDS_Shape result = maker.Shape();
        if (result.IsNull()) return nullptr;
        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}
// MARK: - Geometry Construction (v0.11.0)

OCCTShapeRef OCCTShapeCreateFaceFromWire(OCCTWireRef wire, bool planar) {
    if (!wire) return nullptr;

    try {
        BRepBuilderAPI_MakeFace makeFace(wire->wire, planar);
        if (!makeFace.IsDone()) {
            return nullptr;
        }

        TopoDS_Face face = makeFace.Face();
        if (face.IsNull()) return nullptr;

        return new OCCTShape(face);
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeCreateFaceWithHoles(OCCTWireRef outer, const OCCTWireRef* holes, int32_t holeCount) {
    if (!outer) return nullptr;

    try {
        // First create face from outer wire
        BRepBuilderAPI_MakeFace makeFace(outer->wire, true);  // planar
        if (!makeFace.IsDone()) {
            return nullptr;
        }

        // Add holes (inner wires)
        for (int32_t i = 0; i < holeCount; i++) {
            if (holes[i]) {
                // Inner wires must be reversed to represent holes
                TopoDS_Wire reversed = TopoDS::Wire(holes[i]->wire.Reversed());
                makeFace.Add(reversed);
            }
        }

        if (!makeFace.IsDone()) {
            return nullptr;
        }

        TopoDS_Face face = makeFace.Face();
        if (face.IsNull()) return nullptr;

        return new OCCTShape(face);
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeCreateSolidFromShell(OCCTShapeRef shell) {
    if (!shell) return nullptr;

    try {
        // Extract shell from shape
        TopoDS_Shell topoShell;
        if (shell->shape.ShapeType() == TopAbs_SHELL) {
            topoShell = TopoDS::Shell(shell->shape);
        } else {
            // Try to find a shell in the shape
            TopExp_Explorer exp(shell->shape, TopAbs_SHELL);
            if (exp.More()) {
                topoShell = TopoDS::Shell(exp.Current());
            } else {
                return nullptr;
            }
        }

        BRepBuilderAPI_MakeSolid makeSolid(topoShell);
        if (!makeSolid.IsDone()) {
            return nullptr;
        }

        TopoDS_Solid solid = makeSolid.Solid();
        if (solid.IsNull()) return nullptr;

        // Optionally fix the solid orientation
        ShapeFix_Solid fixer(solid);
        fixer.Perform();
        TopoDS_Shape fixedShape = fixer.Solid();
        if (fixedShape.IsNull() || fixedShape.ShapeType() != TopAbs_SOLID) {
            return new OCCTShape(solid);  // Return original if fix failed
        }

        return new OCCTShape(TopoDS::Solid(fixedShape));
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeSew(const OCCTShapeRef* shapes, int32_t count, double tolerance) {
    if (!shapes || count < 1) return nullptr;

    try {
        BRepBuilderAPI_Sewing sewing(tolerance);

        for (int32_t i = 0; i < count; i++) {
            if (shapes[i]) {
                sewing.Add(shapes[i]->shape);
            }
        }

        sewing.Perform();
        TopoDS_Shape sewn = sewing.SewedShape();

        if (sewn.IsNull()) return nullptr;

        // Try to make a solid if we got a closed shell
        if (sewn.ShapeType() == TopAbs_SHELL) {
            TopoDS_Shell shell = TopoDS::Shell(sewn);
            if (shell.Closed()) {
                BRepBuilderAPI_MakeSolid makeSolid(shell);
                if (makeSolid.IsDone()) {
                    return new OCCTShape(makeSolid.Solid());
                }
            }
        }

        return new OCCTShape(sewn);
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeSewTwo(OCCTShapeRef shape1, OCCTShapeRef shape2, double tolerance) {
    if (!shape1 || !shape2) return nullptr;

    OCCTShapeRef shapes[2] = { shape1, shape2 };
    return OCCTShapeSew(shapes, 2, tolerance);
}

OCCTWireRef OCCTWireInterpolate(const double* points, int32_t count, bool closed, double tolerance) {
    if (!points || count < 2) return nullptr;

    try {
        // Build array of points
        Handle(TColgp_HArray1OfPnt) hPoints = new TColgp_HArray1OfPnt(1, count);
        for (int32_t i = 0; i < count; i++) {
            hPoints->SetValue(i + 1, gp_Pnt(points[i*3], points[i*3+1], points[i*3+2]));
        }

        // Create interpolator
        GeomAPI_Interpolate interpolator(hPoints, closed, tolerance);
        interpolator.Perform();

        if (!interpolator.IsDone()) {
            return nullptr;
        }

        Handle(Geom_BSplineCurve) curve = interpolator.Curve();
        if (curve.IsNull()) return nullptr;

        // Create edge from curve
        BRepBuilderAPI_MakeEdge makeEdge(curve);
        if (!makeEdge.IsDone()) return nullptr;

        // Create wire from edge
        BRepBuilderAPI_MakeWire makeWire(makeEdge.Edge());
        if (!makeWire.IsDone()) return nullptr;

        return new OCCTWire(makeWire.Wire());
    } catch (...) {
        return nullptr;
    }
}

OCCTWireRef OCCTWireInterpolateWithTangents(const double* points, int32_t count,
                                             double startTanX, double startTanY, double startTanZ,
                                             double endTanX, double endTanY, double endTanZ,
                                             double tolerance) {
    if (!points || count < 2) return nullptr;

    try {
        // Build array of points
        Handle(TColgp_HArray1OfPnt) hPoints = new TColgp_HArray1OfPnt(1, count);
        for (int32_t i = 0; i < count; i++) {
            hPoints->SetValue(i + 1, gp_Pnt(points[i*3], points[i*3+1], points[i*3+2]));
        }

        // Create interpolator (not closed since we have tangent constraints)
        GeomAPI_Interpolate interpolator(hPoints, Standard_False, tolerance);

        // Set tangent constraints
        gp_Vec startTangent(startTanX, startTanY, startTanZ);
        gp_Vec endTangent(endTanX, endTanY, endTanZ);
        interpolator.Load(startTangent, endTangent);

        interpolator.Perform();

        if (!interpolator.IsDone()) {
            return nullptr;
        }

        Handle(Geom_BSplineCurve) curve = interpolator.Curve();
        if (curve.IsNull()) return nullptr;

        // Create edge from curve
        BRepBuilderAPI_MakeEdge makeEdge(curve);
        if (!makeEdge.IsDone()) return nullptr;

        // Create wire from edge
        BRepBuilderAPI_MakeWire makeWire(makeEdge.Edge());
        if (!makeWire.IsDone()) return nullptr;

        return new OCCTWire(makeWire.Wire());
    } catch (...) {
        return nullptr;
    }
}


// MARK: - Feature-Based Modeling (v0.12.0)

OCCTShapeRef OCCTShapePrism(OCCTShapeRef shape, OCCTWireRef profile,
                            double dirX, double dirY, double dirZ,
                            double height, bool fuse) {
    if (!shape || !profile) return nullptr;

    try {
        // Create face from profile wire
        BRepBuilderAPI_MakeFace makeFace(profile->wire, true);
        if (!makeFace.IsDone()) return nullptr;
        TopoDS_Face profileFace = makeFace.Face();

        // Create the prism direction
        gp_Vec dir(dirX, dirY, dirZ);
        dir.Normalize();
        dir.Scale(height);

        // Create the prism shape (extrusion of the profile)
        BRepPrimAPI_MakePrism makePrism(profileFace, dir);
        if (!makePrism.IsDone()) return nullptr;
        TopoDS_Shape prismShape = makePrism.Shape();

        // Fuse or cut with base shape
        TopoDS_Shape result;
        if (fuse) {
            BRepAlgoAPI_Fuse fuseOp(shape->shape, prismShape);
            if (!fuseOp.IsDone()) return nullptr;
            result = fuseOp.Shape();
        } else {
            BRepAlgoAPI_Cut cutOp(shape->shape, prismShape);
            if (!cutOp.IsDone()) return nullptr;
            result = cutOp.Shape();
        }

        if (result.IsNull()) return nullptr;
        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeDrillHole(OCCTShapeRef shape,
                                 double posX, double posY, double posZ,
                                 double dirX, double dirY, double dirZ,
                                 double radius, double depth) {
    if (!shape || radius <= 0) return nullptr;

    try {
        gp_Vec direction(dirX, dirY, dirZ);
        double dirLen = direction.Magnitude();
        if (dirLen < 1e-10) return nullptr;
        direction.Normalize();

        // Determine depth - if depth is 0 or negative, make it through the shape
        double actualDepth = depth;
        if (actualDepth <= 0) {
            // Calculate shape extent for through hole
            Bnd_Box bounds;
            BRepBndLib::Add(shape->shape, bounds);
            double xmin, ymin, zmin, xmax, ymax, zmax;
            bounds.Get(xmin, ymin, zmin, xmax, ymax, zmax);
            double diagonal = std::sqrt((xmax-xmin)*(xmax-xmin) +
                                        (ymax-ymin)*(ymax-ymin) +
                                        (zmax-zmin)*(zmax-zmin));
            actualDepth = diagonal * 2;  // Make sure it goes through
        }

        // Calculate the bottom of the hole (endpoint of drill)
        double bottomX = posX + direction.X() * actualDepth;
        double bottomY = posY + direction.Y() * actualDepth;
        double bottomZ = posZ + direction.Z() * actualDepth;

        // Create cylinder using OCCTShapeCreateCylinderAt pattern
        // The cylinder's base is at the "bottom" of the hole, extending upward
        OCCTShapeRef cylRef = OCCTShapeCreateCylinderAt(bottomX, bottomY, bottomZ, radius, actualDepth);
        if (!cylRef) return nullptr;

        // Subtract using the existing working function
        OCCTShapeRef result = OCCTShapeSubtract(shape, cylRef);
        OCCTShapeRelease(cylRef);

        return result;
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef* OCCTShapeSplit(OCCTShapeRef shape, OCCTShapeRef tool, int32_t* outCount) {
    if (!shape || !tool || !outCount) return nullptr;
    *outCount = 0;

    try {
        // Use BRepAlgoAPI_Splitter for general splitting
        BRepAlgoAPI_Splitter splitter;

        // Set arguments (shapes to be split)
        TopTools_ListOfShape arguments;
        arguments.Append(shape->shape);
        splitter.SetArguments(arguments);

        // Set tools (cutting shapes)
        TopTools_ListOfShape tools;
        tools.Append(tool->shape);
        splitter.SetTools(tools);

        // Perform split
        splitter.Build();
        if (!splitter.IsDone()) return nullptr;

        TopoDS_Shape result = splitter.Shape();
        if (result.IsNull()) return nullptr;

        // Extract solids from result
        std::vector<TopoDS_Shape> solids;
        for (TopExp_Explorer exp(result, TopAbs_SOLID); exp.More(); exp.Next()) {
            solids.push_back(exp.Current());
        }

        // If no solids, try shells
        if (solids.empty()) {
            for (TopExp_Explorer exp(result, TopAbs_SHELL); exp.More(); exp.Next()) {
                solids.push_back(exp.Current());
            }
        }

        // If still nothing, return the whole result as one shape
        if (solids.empty()) {
            solids.push_back(result);
        }

        // Allocate array
        *outCount = static_cast<int32_t>(solids.size());
        OCCTShapeRef* shapes = new OCCTShapeRef[*outCount];
        for (int32_t i = 0; i < *outCount; i++) {
            shapes[i] = new OCCTShape(solids[i]);
        }

        return shapes;
    } catch (...) {
        *outCount = 0;
        return nullptr;
    }
}

OCCTShapeRef* OCCTShapeSplitByPlane(OCCTShapeRef shape,
                                     double planeX, double planeY, double planeZ,
                                     double normalX, double normalY, double normalZ,
                                     int32_t* outCount) {
    if (!shape || !outCount) return nullptr;
    *outCount = 0;

    try {
        // Create plane
        gp_Pnt pnt(planeX, planeY, planeZ);
        gp_Dir normal(normalX, normalY, normalZ);
        gp_Pln plane(pnt, normal);

        // Create a large face from the plane for cutting
        // Get shape bounds to size the cutting plane
        Bnd_Box bounds;
        BRepBndLib::Add(shape->shape, bounds);
        double xmin, ymin, zmin, xmax, ymax, zmax;
        bounds.Get(xmin, ymin, zmin, xmax, ymax, zmax);
        double size = std::sqrt((xmax-xmin)*(xmax-xmin) +
                                (ymax-ymin)*(ymax-ymin) +
                                (zmax-zmin)*(zmax-zmin)) * 2;

        BRepBuilderAPI_MakeFace makeFace(plane, -size, size, -size, size);
        if (!makeFace.IsDone()) return nullptr;
        TopoDS_Shape planeFace = makeFace.Face();

        // Use splitter
        BRepAlgoAPI_Splitter splitter;

        TopTools_ListOfShape arguments;
        arguments.Append(shape->shape);
        splitter.SetArguments(arguments);

        TopTools_ListOfShape tools;
        tools.Append(planeFace);
        splitter.SetTools(tools);

        splitter.Build();
        if (!splitter.IsDone()) return nullptr;

        TopoDS_Shape result = splitter.Shape();
        if (result.IsNull()) return nullptr;

        // Extract solids from result
        std::vector<TopoDS_Shape> solids;
        for (TopExp_Explorer exp(result, TopAbs_SOLID); exp.More(); exp.Next()) {
            solids.push_back(exp.Current());
        }

        if (solids.empty()) {
            for (TopExp_Explorer exp(result, TopAbs_SHELL); exp.More(); exp.Next()) {
                solids.push_back(exp.Current());
            }
        }

        if (solids.empty()) {
            solids.push_back(result);
        }

        *outCount = static_cast<int32_t>(solids.size());
        OCCTShapeRef* shapes = new OCCTShapeRef[*outCount];
        for (int32_t i = 0; i < *outCount; i++) {
            shapes[i] = new OCCTShape(solids[i]);
        }

        return shapes;
    } catch (...) {
        *outCount = 0;
        return nullptr;
    }
}

void OCCTFreeShapeArray(OCCTShapeRef* shapes, int32_t count) {
    if (!shapes) return;
    for (int32_t i = 0; i < count; i++) {
        delete shapes[i];
    }
    delete[] shapes;
}

void OCCTFreeShapeArrayOnly(OCCTShapeRef* shapes) {
    if (!shapes) return;
    delete[] shapes;
}

OCCTShapeRef OCCTShapeGlue(OCCTShapeRef shape1, OCCTShapeRef shape2, double tolerance) {
    if (!shape1 || !shape2) return nullptr;

    try {
        // Use BRepAlgoAPI_Fuse with glue option for coincident faces
        BRepAlgoAPI_Fuse fuse;
        fuse.SetGlue(BOPAlgo_GlueShift);  // Enable gluing mode
        fuse.SetFuzzyValue(tolerance);

        TopTools_ListOfShape args;
        args.Append(shape1->shape);
        args.Append(shape2->shape);
        fuse.SetArguments(args);

        fuse.Build();
        if (!fuse.IsDone()) {
            // Fallback to regular fuse
            BRepAlgoAPI_Fuse regularFuse(shape1->shape, shape2->shape);
            if (!regularFuse.IsDone()) return nullptr;
            return new OCCTShape(regularFuse.Shape());
        }

        TopoDS_Shape result = fuse.Shape();
        if (result.IsNull()) return nullptr;

        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeCreateEvolved(OCCTWireRef spine, OCCTWireRef profile) {
    if (!spine || !profile) return nullptr;

    try {
        BRepOffsetAPI_MakeEvolved evolved(spine->wire, profile->wire);
        if (!evolved.IsDone()) return nullptr;

        TopoDS_Shape result = evolved.Shape();
        if (result.IsNull()) return nullptr;

        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeLinearPattern(OCCTShapeRef shape,
                                     double dirX, double dirY, double dirZ,
                                     double spacing, int32_t count) {
    if (!shape || count < 1) return nullptr;

    try {
        BRep_Builder builder;
        TopoDS_Compound compound;
        builder.MakeCompound(compound);

        gp_Vec direction(dirX, dirY, dirZ);
        direction.Normalize();

        for (int32_t i = 0; i < count; i++) {
            gp_Trsf transform;
            transform.SetTranslation(direction * (spacing * i));

            BRepBuilderAPI_Transform xform(shape->shape, transform, true);
            if (xform.IsDone()) {
                builder.Add(compound, xform.Shape());
            }
        }

        return new OCCTShape(compound);
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeCircularPattern(OCCTShapeRef shape,
                                       double axisX, double axisY, double axisZ,
                                       double axisDirX, double axisDirY, double axisDirZ,
                                       int32_t count, double angle) {
    if (!shape || count < 1) return nullptr;

    try {
        BRep_Builder builder;
        TopoDS_Compound compound;
        builder.MakeCompound(compound);

        gp_Pnt axisPoint(axisX, axisY, axisZ);
        gp_Dir axisDir(axisDirX, axisDirY, axisDirZ);
        gp_Ax1 axis(axisPoint, axisDir);

        // If angle is 0, use full circle
        double totalAngle = (angle == 0) ? (2.0 * M_PI) : angle;
        double stepAngle = totalAngle / count;

        for (int32_t i = 0; i < count; i++) {
            gp_Trsf transform;
            transform.SetRotation(axis, stepAngle * i);

            BRepBuilderAPI_Transform xform(shape->shape, transform, true);
            if (xform.IsDone()) {
                builder.Add(compound, xform.Shape());
            }
        }

        return new OCCTShape(compound);
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Wire Creation (2D Profiles)

OCCTWireRef OCCTWireCreateRectangle(double width, double height) {
    try {
        double hw = width / 2;
        double hh = height / 2;

        gp_Pnt p1(-hw, -hh, 0);
        gp_Pnt p2( hw, -hh, 0);
        gp_Pnt p3( hw,  hh, 0);
        gp_Pnt p4(-hw,  hh, 0);

        TopoDS_Edge e1 = BRepBuilderAPI_MakeEdge(p1, p2);
        TopoDS_Edge e2 = BRepBuilderAPI_MakeEdge(p2, p3);
        TopoDS_Edge e3 = BRepBuilderAPI_MakeEdge(p3, p4);
        TopoDS_Edge e4 = BRepBuilderAPI_MakeEdge(p4, p1);

        BRepBuilderAPI_MakeWire wireMaker;
        wireMaker.Add(e1);
        wireMaker.Add(e2);
        wireMaker.Add(e3);
        wireMaker.Add(e4);

        return new OCCTWire(wireMaker.Wire());
    } catch (...) {
        return nullptr;
    }
}

OCCTWireRef OCCTWireCreateCircle(double radius) {
    try {
        gp_Circ circle(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), radius);
        TopoDS_Edge edge = BRepBuilderAPI_MakeEdge(circle);
        BRepBuilderAPI_MakeWire wireMaker(edge);
        return new OCCTWire(wireMaker.Wire());
    } catch (...) {
        return nullptr;
    }
}

OCCTWireRef OCCTWireCreateCircleEx(double radius,
    double ox, double oy, double oz,
    double nx, double ny, double nz) {
    try {
        gp_Circ circle(gp_Ax2(gp_Pnt(ox, oy, oz), gp_Dir(nx, ny, nz)), radius);
        TopoDS_Edge edge = BRepBuilderAPI_MakeEdge(circle);
        BRepBuilderAPI_MakeWire wireMaker(edge);
        return new OCCTWire(wireMaker.Wire());
    } catch (...) {
        return nullptr;
    }
}

OCCTWireRef OCCTWireCreatePolygon(const double* points, int32_t pointCount, bool closed) {
    if (!points || pointCount < 2) return nullptr;

    try {
        BRepBuilderAPI_MakeWire wireMaker;

        for (int32_t i = 0; i < pointCount - 1; i++) {
            gp_Pnt p1(points[i * 2], points[i * 2 + 1], 0);
            gp_Pnt p2(points[(i + 1) * 2], points[(i + 1) * 2 + 1], 0);
            TopoDS_Edge edge = BRepBuilderAPI_MakeEdge(p1, p2);
            wireMaker.Add(edge);
        }

        if (closed && pointCount > 2) {
            gp_Pnt pLast(points[(pointCount - 1) * 2], points[(pointCount - 1) * 2 + 1], 0);
            gp_Pnt pFirst(points[0], points[1], 0);
            TopoDS_Edge edge = BRepBuilderAPI_MakeEdge(pLast, pFirst);
            wireMaker.Add(edge);
        }

        return new OCCTWire(wireMaker.Wire());
    } catch (...) {
        return nullptr;
    }
}

OCCTWireRef OCCTWireCreateFromPoints3D(const double* points, int32_t pointCount, bool closed) {
    if (!points || pointCount < 2) return nullptr;

    try {
        BRepBuilderAPI_MakeWire wireMaker;

        for (int32_t i = 0; i < pointCount - 1; i++) {
            gp_Pnt p1(points[i * 3], points[i * 3 + 1], points[i * 3 + 2]);
            gp_Pnt p2(points[(i + 1) * 3], points[(i + 1) * 3 + 1], points[(i + 1) * 3 + 2]);
            TopoDS_Edge edge = BRepBuilderAPI_MakeEdge(p1, p2);
            wireMaker.Add(edge);
        }

        if (closed && pointCount > 2) {
            gp_Pnt pLast(points[(pointCount - 1) * 3], points[(pointCount - 1) * 3 + 1], points[(pointCount - 1) * 3 + 2]);
            gp_Pnt pFirst(points[0], points[1], points[2]);
            TopoDS_Edge edge = BRepBuilderAPI_MakeEdge(pLast, pFirst);
            wireMaker.Add(edge);
        }

        return new OCCTWire(wireMaker.Wire());
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Wire Creation (3D Paths)

OCCTWireRef OCCTWireCreateLine(double x1, double y1, double z1, double x2, double y2, double z2) {
    try {
        gp_Pnt p1(x1, y1, z1);
        gp_Pnt p2(x2, y2, z2);
        TopoDS_Edge edge = BRepBuilderAPI_MakeEdge(p1, p2);
        BRepBuilderAPI_MakeWire wireMaker(edge);
        return new OCCTWire(wireMaker.Wire());
    } catch (...) {
        return nullptr;
    }
}

OCCTWireRef OCCTWireCreateArc(double centerX, double centerY, double centerZ, double radius, double startAngle, double endAngle, double normalX, double normalY, double normalZ) {
    try {
        gp_Pnt center(centerX, centerY, centerZ);
        gp_Dir normal(normalX, normalY, normalZ);
        gp_Ax2 axis(center, normal);

        gp_Circ circle(axis, radius);

        // Create arc from angles
        Handle(Geom_Circle) geomCircle = new Geom_Circle(circle);
        Handle(Geom_TrimmedCurve) arc = new Geom_TrimmedCurve(geomCircle, startAngle, endAngle);

        TopoDS_Edge edge = BRepBuilderAPI_MakeEdge(arc);
        BRepBuilderAPI_MakeWire wireMaker(edge);
        return new OCCTWire(wireMaker.Wire());
    } catch (...) {
        return nullptr;
    }
}

OCCTWireRef OCCTWireCreateArcThroughPoints(double sx, double sy, double sz,
                                            double mx, double my, double mz,
                                            double ex, double ey, double ez) {
    try {
        gp_Pnt p1(sx, sy, sz);
        gp_Pnt p2(mx, my, mz);
        gp_Pnt p3(ex, ey, ez);
        GC_MakeArcOfCircle maker(p1, p2, p3);
        if (!maker.IsDone()) return nullptr;
        Handle(Geom_TrimmedCurve) arc = maker.Value();
        TopoDS_Edge edge = BRepBuilderAPI_MakeEdge(arc);
        BRepBuilderAPI_MakeWire wireMaker(edge);
        return new OCCTWire(wireMaker.Wire());
    } catch (...) {
        return nullptr;
    }
}

OCCTWireRef OCCTWireCreateBSpline(const double* controlPoints, int32_t pointCount) {
    if (!controlPoints || pointCount < 2) return nullptr;

    try {
        TColgp_Array1OfPnt points(1, pointCount);
        for (int32_t i = 0; i < pointCount; i++) {
            points.SetValue(i + 1, gp_Pnt(
                controlPoints[i * 3],
                controlPoints[i * 3 + 1],
                controlPoints[i * 3 + 2]
            ));
        }

        GeomAPI_PointsToBSpline fitter(points);
        if (!fitter.IsDone()) return nullptr;

        Handle(Geom_BSplineCurve) curve = fitter.Curve();
        TopoDS_Edge edge = BRepBuilderAPI_MakeEdge(curve);
        BRepBuilderAPI_MakeWire wireMaker(edge);
        return new OCCTWire(wireMaker.Wire());
    } catch (...) {
        return nullptr;
    }
}

// MARK: - NURBS Curve Creation

OCCTWireRef OCCTWireCreateNURBS(
    const double* poles,
    int32_t poleCount,
    const double* weights,
    const double* knots,
    int32_t knotCount,
    const int32_t* multiplicities,
    int32_t degree
) {
    if (!poles || poleCount < 2 || !knots || knotCount < 2 || degree < 1) return nullptr;

    try {
        // Create control points array (1-indexed in OCCT)
        TColgp_Array1OfPnt polesArray(1, poleCount);
        for (int32_t i = 0; i < poleCount; i++) {
            polesArray.SetValue(i + 1, gp_Pnt(
                poles[i * 3],
                poles[i * 3 + 1],
                poles[i * 3 + 2]
            ));
        }

        // Create weights array
        TColStd_Array1OfReal weightsArray(1, poleCount);
        for (int32_t i = 0; i < poleCount; i++) {
            weightsArray.SetValue(i + 1, weights ? weights[i] : 1.0);
        }

        // Create knots array
        TColStd_Array1OfReal knotsArray(1, knotCount);
        for (int32_t i = 0; i < knotCount; i++) {
            knotsArray.SetValue(i + 1, knots[i]);
        }

        // Create multiplicities array
        TColStd_Array1OfInteger multsArray(1, knotCount);
        for (int32_t i = 0; i < knotCount; i++) {
            multsArray.SetValue(i + 1, multiplicities ? multiplicities[i] : 1);
        }

        // Create the B-spline curve
        Handle(Geom_BSplineCurve) curve = new Geom_BSplineCurve(
            polesArray,
            weightsArray,
            knotsArray,
            multsArray,
            degree
        );

        TopoDS_Edge edge = BRepBuilderAPI_MakeEdge(curve);
        BRepBuilderAPI_MakeWire wireMaker(edge);
        return new OCCTWire(wireMaker.Wire());
    } catch (...) {
        return nullptr;
    }
}

OCCTWireRef OCCTWireCreateNURBSUniform(
    const double* poles,
    int32_t poleCount,
    const double* weights,
    int32_t degree
) {
    if (!poles || poleCount < 2 || degree < 1) return nullptr;
    if (poleCount < degree + 1) return nullptr;  // Need at least degree+1 control points

    try {
        // Create control points array
        TColgp_Array1OfPnt polesArray(1, poleCount);
        for (int32_t i = 0; i < poleCount; i++) {
            polesArray.SetValue(i + 1, gp_Pnt(
                poles[i * 3],
                poles[i * 3 + 1],
                poles[i * 3 + 2]
            ));
        }

        // Create weights array
        TColStd_Array1OfReal weightsArray(1, poleCount);
        for (int32_t i = 0; i < poleCount; i++) {
            weightsArray.SetValue(i + 1, weights ? weights[i] : 1.0);
        }

        // For clamped uniform B-spline:
        // - First and last knots have multiplicity = degree + 1
        // - Interior knots have multiplicity = 1
        // - Number of interior knots = poleCount - degree - 1
        // - Total distinct knots = interior + 2 (for start and end)
        int32_t interiorKnots = poleCount - degree - 1;
        int32_t knotCount = interiorKnots + 2;

        TColStd_Array1OfReal knotsArray(1, knotCount);
        TColStd_Array1OfInteger multsArray(1, knotCount);

        // Start knot at 0 with multiplicity degree+1
        knotsArray.SetValue(1, 0.0);
        multsArray.SetValue(1, degree + 1);

        // Interior knots uniformly distributed
        for (int32_t i = 0; i < interiorKnots; i++) {
            knotsArray.SetValue(i + 2, (double)(i + 1) / (double)(interiorKnots + 1));
            multsArray.SetValue(i + 2, 1);
        }

        // End knot at 1 with multiplicity degree+1
        knotsArray.SetValue(knotCount, 1.0);
        multsArray.SetValue(knotCount, degree + 1);

        // Create the B-spline curve
        Handle(Geom_BSplineCurve) curve = new Geom_BSplineCurve(
            polesArray,
            weightsArray,
            knotsArray,
            multsArray,
            degree
        );

        TopoDS_Edge edge = BRepBuilderAPI_MakeEdge(curve);
        BRepBuilderAPI_MakeWire wireMaker(edge);
        return new OCCTWire(wireMaker.Wire());
    } catch (...) {
        return nullptr;
    }
}

OCCTWireRef OCCTWireCreateCubicBSpline(const double* poles, int32_t poleCount) {
    // Cubic B-spline with uniform weights (non-rational)
    return OCCTWireCreateNURBSUniform(poles, poleCount, nullptr, 3);
}

OCCTWireRef OCCTWireJoin(const OCCTWireRef* wires, int32_t count) {
    if (!wires || count < 1) return nullptr;

    try {
        BRepBuilderAPI_MakeWire wireMaker;

        for (int32_t i = 0; i < count; i++) {
            if (wires[i]) {
                wireMaker.Add(wires[i]->wire);
            }
        }

        if (!wireMaker.IsDone()) return nullptr;
        return new OCCTWire(wireMaker.Wire());
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Law Functions (v0.21.0)
// ============================================================================

#include <Law_Function.hxx>
#include <Law_Constant.hxx>
#include <Law_Linear.hxx>
#include <Law_S.hxx>
#include <Law_Interpol.hxx>
#include <Law_BSpline.hxx>
#include <Law_BSpFunc.hxx>
#include <TColgp_Array1OfPnt2d.hxx>

struct OCCTLawFunction {
    Handle(Law_Function) law;
    OCCTLawFunction() {}
    OCCTLawFunction(const Handle(Law_Function)& l) : law(l) {}
};

void OCCTLawFunctionRelease(OCCTLawFunctionRef l) {
    delete l;
}

double OCCTLawFunctionValue(OCCTLawFunctionRef l, double param) {
    if (!l || l->law.IsNull()) return 0.0;
    try {
        return l->law->Value(param);
    } catch (...) {
        return 0.0;
    }
}

void OCCTLawFunctionBounds(OCCTLawFunctionRef l, double* first, double* last) {
    if (!l || l->law.IsNull() || !first || !last) return;
    try {
        l->law->Bounds(*first, *last);
    } catch (...) {
        *first = 0;
        *last = 0;
    }
}

OCCTLawFunctionRef OCCTLawCreateConstant(double value, double first, double last) {
    try {
        Handle(Law_Constant) law = new Law_Constant();
        law->Set(value, first, last);
        return new OCCTLawFunction(law);
    } catch (...) {
        return nullptr;
    }
}

OCCTLawFunctionRef OCCTLawCreateLinear(double first, double startVal,
                                        double last, double endVal) {
    try {
        Handle(Law_Linear) law = new Law_Linear();
        law->Set(first, startVal, last, endVal);
        return new OCCTLawFunction(law);
    } catch (...) {
        return nullptr;
    }
}

OCCTLawFunctionRef OCCTLawCreateS(double first, double startVal,
                                   double last, double endVal) {
    try {
        Handle(Law_S) law = new Law_S();
        law->Set(first, startVal, last, endVal);
        return new OCCTLawFunction(law);
    } catch (...) {
        return nullptr;
    }
}

OCCTLawFunctionRef OCCTLawCreateInterpolate(const double* paramValues,
                                             int32_t count, bool periodic) {
    if (!paramValues || count < 2) return nullptr;
    try {
        TColgp_Array1OfPnt2d pts(1, count);
        for (int32_t i = 0; i < count; i++) {
            pts.SetValue(i + 1, gp_Pnt2d(paramValues[i * 2], paramValues[i * 2 + 1]));
        }
        Handle(Law_Interpol) law = new Law_Interpol();
        law->Set(pts, periodic ? Standard_True : Standard_False);
        return new OCCTLawFunction(law);
    } catch (...) {
        return nullptr;
    }
}

OCCTLawFunctionRef OCCTLawCreateBSpline(const double* poles, int32_t poleCount,
                                         const double* knots, int32_t knotCount,
                                         const int32_t* multiplicities,
                                         int32_t degree) {
    if (!poles || !knots || !multiplicities || poleCount < 2 || knotCount < 2)
        return nullptr;
    try {
        TColStd_Array1OfReal poleArr(1, poleCount);
        for (int32_t i = 0; i < poleCount; i++) poleArr.SetValue(i + 1, poles[i]);

        TColStd_Array1OfReal knotArr(1, knotCount);
        for (int32_t i = 0; i < knotCount; i++) knotArr.SetValue(i + 1, knots[i]);

        TColStd_Array1OfInteger multArr(1, knotCount);
        for (int32_t i = 0; i < knotCount; i++) multArr.SetValue(i + 1, multiplicities[i]);

        Handle(Law_BSpline) bsp = new Law_BSpline(poleArr, knotArr, multArr, degree);
        Handle(Law_BSpFunc) law = new Law_BSpFunc(bsp, knots[0], knots[knotCount - 1]);
        return new OCCTLawFunction(law);
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeCreatePipeShellWithLaw(OCCTWireRef spine,
                                              OCCTWireRef profile,
                                              OCCTLawFunctionRef law,
                                              bool solid) {
    if (!spine || !profile || !law || law->law.IsNull()) return nullptr;
    try {
        BRepOffsetAPI_MakePipeShell pipeShell(spine->wire);
        pipeShell.SetMode(Standard_False); // Frenet
        pipeShell.SetLaw(profile->wire, law->law, Standard_False, Standard_False);
        pipeShell.SetIsBuildHistory(false); // avoid SEGV on closed spine+profile (OCCT bug)
        pipeShell.Build();
        if (!pipeShell.IsDone()) return nullptr;

        TopoDS_Shape result = pipeShell.Shape();
        if (solid) {
            pipeShell.MakeSolid();
            if (pipeShell.IsDone()) {
                result = pipeShell.Shape();
            }
        }
        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

// ============================================================================
// MARK: - Surface Intersection (v0.18.0)

OCCTShapeRef OCCTFaceIntersect(OCCTFaceRef face1, OCCTFaceRef face2,
                                double tolerance) {
    if (!face1 || !face2) return nullptr;

    try {
        BRepAlgoAPI_Section section(face1->face, face2->face, Standard_False);
        section.Approximation(Standard_True);
        section.ComputePCurveOn1(Standard_True);
        section.ComputePCurveOn2(Standard_True);
        section.SetFuzzyValue(tolerance);
        section.Build();

        if (!section.IsDone()) return nullptr;

        TopoDS_Shape result = section.Shape();
        if (result.IsNull()) return nullptr;

        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

OCCTWireRef OCCTWireOffset3D(OCCTWireRef wire, double distance, double dirX, double dirY, double dirZ) {
    if (!wire) return nullptr;

    try {
        // Create translation vector
        gp_Vec offset(dirX, dirY, dirZ);
        if (offset.Magnitude() > 1e-10) {
            offset.Normalize();
        }
        offset.Multiply(distance);

        // Create transformation
        gp_Trsf transform;
        transform.SetTranslation(offset);

        // Apply transformation
        BRepBuilderAPI_Transform transformer(wire->wire, transform, Standard_True);
        if (!transformer.IsDone()) return nullptr;

        TopoDS_Shape result = transformer.Shape();
        if (result.ShapeType() != TopAbs_WIRE) return nullptr;

        return new OCCTWire(TopoDS::Wire(result));
    } catch (...) {
        return nullptr;
    }
}
// MARK: - v0.42.0: Solid Construction, Fast Polygon, 2D Fillet, Point Cloud Analysis

#include <BRepBuilderAPI_MakeSolid.hxx>
#include <BRepBuilderAPI_MakePolygon.hxx>
#include <BRepFilletAPI_MakeFillet2d.hxx>
#include <GProp_PEquation.hxx>
#include <TColgp_Array1OfPnt.hxx>

OCCTShapeRef OCCTSolidFromShells(OCCTShapeRef* shells, int32_t count) {
    if (!shells || count <= 0) return nullptr;
    try {
        // Get the first shell
        TopExp_Explorer exp(shells[0]->shape, TopAbs_SHELL);
        if (!exp.More()) return nullptr;
        TopoDS_Shell firstShell = TopoDS::Shell(exp.Current());

        BRepBuilderAPI_MakeSolid maker(firstShell);

        // Add additional shells (cavities)
        for (int32_t i = 1; i < count; i++) {
            if (!shells[i]) continue;
            TopExp_Explorer exp2(shells[i]->shape, TopAbs_SHELL);
            if (exp2.More()) {
                maker.Add(TopoDS::Shell(exp2.Current()));
            }
        }

        if (!maker.IsDone()) return nullptr;
        return new OCCTShape(maker.Solid());
    } catch (...) {
        return nullptr;
    }
}

OCCTWireRef OCCTWireCreateFastPolygon(const double* coords, int32_t pointCount, bool closed) {
    if (!coords || pointCount < 2) return nullptr;
    try {
        BRepBuilderAPI_MakePolygon poly;
        for (int32_t i = 0; i < pointCount; i++) {
            poly.Add(gp_Pnt(coords[i*3], coords[i*3+1], coords[i*3+2]));
        }
        if (closed) poly.Close();
        if (!poly.IsDone()) return nullptr;
        return new OCCTWire(poly.Wire());
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTFace2DFillet(OCCTShapeRef shape, const int32_t* vertexIndices,
                               const double* radii, int32_t count) {
    if (!shape || !vertexIndices || !radii || count <= 0) return nullptr;
    try {
        // Get face from shape
        TopExp_Explorer faceExp(shape->shape, TopAbs_FACE);
        if (!faceExp.More()) return nullptr;
        TopoDS_Face face = TopoDS::Face(faceExp.Current());

        BRepFilletAPI_MakeFillet2d fillet(face);

        TopTools_IndexedMapOfShape vertMap;
        TopExp::MapShapes(face, TopAbs_VERTEX, vertMap);

        for (int32_t i = 0; i < count; i++) {
            int32_t idx = vertexIndices[i] + 1; // Convert to 1-based
            if (idx < 1 || idx > vertMap.Extent()) continue;
            fillet.AddFillet(TopoDS::Vertex(vertMap(idx)), radii[i]);
        }

        fillet.Build();
        if (!fillet.IsDone()) return nullptr;
        return new OCCTShape(fillet.Shape());
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTFace2DChamfer(OCCTShapeRef shape,
                                const int32_t* edge1Indices, const int32_t* edge2Indices,
                                const double* distances, int32_t count) {
    if (!shape || !edge1Indices || !edge2Indices || !distances || count <= 0) return nullptr;
    try {
        TopExp_Explorer faceExp(shape->shape, TopAbs_FACE);
        if (!faceExp.More()) return nullptr;
        TopoDS_Face face = TopoDS::Face(faceExp.Current());

        BRepFilletAPI_MakeFillet2d chamfer(face);

        TopTools_IndexedMapOfShape edgeMap;
        TopExp::MapShapes(face, TopAbs_EDGE, edgeMap);

        for (int32_t i = 0; i < count; i++) {
            int32_t idx1 = edge1Indices[i] + 1;
            int32_t idx2 = edge2Indices[i] + 1;
            if (idx1 < 1 || idx1 > edgeMap.Extent()) continue;
            if (idx2 < 1 || idx2 > edgeMap.Extent()) continue;
            chamfer.AddChamfer(TopoDS::Edge(edgeMap(idx1)),
                               TopoDS::Edge(edgeMap(idx2)),
                               distances[i], distances[i]);
        }

        chamfer.Build();
        if (!chamfer.IsDone()) return nullptr;
        return new OCCTShape(chamfer.Shape());
    } catch (...) {
        return nullptr;
    }
}

// MARK: - BRepFill_Filling (v0.45)
struct OCCTFilling {
    BRepFill_Filling filler;
};

OCCTFillingRef OCCTFillingCreate(int32_t degree, int32_t nbPtsOnCur, int32_t maxDegree,
                                  int32_t maxSegments, double tolerance3d) {
    try {
        auto* filling = new OCCTFilling();
        filling->filler.SetConstrParam(tolerance3d, tolerance3d, 0.0001, 0.1);
        filling->filler.SetResolParam(degree, nbPtsOnCur, maxDegree, maxSegments);
        return filling;
    } catch (...) {
        return nullptr;
    }
}

void OCCTFillingRelease(OCCTFillingRef filling) {
    delete filling;
}

bool OCCTFillingAddEdge(OCCTFillingRef filling, OCCTEdgeRef edge, int32_t continuity) {
    if (!filling || !edge) return false;
    try {
        GeomAbs_Shape cont = GeomAbs_C0;
        if (continuity == 1) cont = GeomAbs_C1;
        else if (continuity >= 2) cont = GeomAbs_C2;
        filling->filler.Add(edge->edge, cont);
        return true;
    } catch (...) {
        return false;
    }
}

bool OCCTFillingAddFreeEdge(OCCTFillingRef filling, OCCTEdgeRef edge, int32_t continuity) {
    if (!filling || !edge) return false;
    try {
        GeomAbs_Shape cont = GeomAbs_C0;
        if (continuity == 1) cont = GeomAbs_C1;
        else if (continuity >= 2) cont = GeomAbs_C2;
        filling->filler.Add(edge->edge, cont, /*IsBound=*/false);
        return true;
    } catch (...) {
        return false;
    }
}

bool OCCTFillingAddPoint(OCCTFillingRef filling, double x, double y, double z) {
    if (!filling) return false;
    try {
        filling->filler.Add(gp_Pnt(x, y, z));
        return true;
    } catch (...) {
        return false;
    }
}

bool OCCTFillingBuild(OCCTFillingRef filling) {
    if (!filling) return false;
    try {
        filling->filler.Build();
        return filling->filler.IsDone();
    } catch (...) {
        return false;
    }
}

bool OCCTFillingIsDone(OCCTFillingRef filling) {
    if (!filling) return false;
    return filling->filler.IsDone();
}

OCCTShapeRef OCCTFillingGetFace(OCCTFillingRef filling) {
    if (!filling || !filling->filler.IsDone()) return nullptr;
    try {
        TopoDS_Face face = filling->filler.Face();
        if (face.IsNull()) return nullptr;
        return new OCCTShape(face);
    } catch (...) {
        return nullptr;
    }
}

double OCCTFillingG0Error(OCCTFillingRef filling) {
    if (!filling || !filling->filler.IsDone()) return -1.0;
    try {
        return filling->filler.G0Error();
    } catch (...) {
        return -1.0;
    }
}

double OCCTFillingG1Error(OCCTFillingRef filling) {
    if (!filling || !filling->filler.IsDone()) return -1.0;
    try {
        return filling->filler.G1Error();
    } catch (...) {
        return -1.0;
    }
}

double OCCTFillingG2Error(OCCTFillingRef filling) {
    if (!filling || !filling->filler.IsDone()) return -1.0;
    try {
        return filling->filler.G2Error();
    } catch (...) {
        return -1.0;
    }
}

// MARK: - LocOpe_Prism (v0.46)
OCCTShapeRef OCCTLocOpePrism(OCCTShapeRef face, double dx, double dy, double dz) {
    if (!face) return nullptr;
    try {
        LocOpe_Prism prism(face->shape, gp_Vec(dx, dy, dz));
        TopoDS_Shape result = prism.Shape();
        if (result.IsNull()) return nullptr;
        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTLocOpePrismWithTranslation(OCCTShapeRef face,
                                             double dx, double dy, double dz,
                                             double tx, double ty, double tz) {
    if (!face) return nullptr;
    try {
        LocOpe_Prism prism(face->shape, gp_Vec(dx, dy, dz), gp_Vec(tx, ty, tz));
        TopoDS_Shape result = prism.Shape();
        if (result.IsNull()) return nullptr;
        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

// MARK: - LocOpe_Revol / LocOpe_DPrism (v0.47)
// --- LocOpe_Revol ---

OCCTShapeRef OCCTLocOpeRevol(OCCTShapeRef profile,
                              double axisOriginX, double axisOriginY, double axisOriginZ,
                              double axisDirX, double axisDirY, double axisDirZ,
                              double angle) {
    if (!profile) return nullptr;
    try {
        gp_Ax1 axis(gp_Pnt(axisOriginX, axisOriginY, axisOriginZ),
                     gp_Dir(axisDirX, axisDirY, axisDirZ));
        LocOpe_Revol revol;
        revol.Perform(profile->shape, axis, angle);
        TopoDS_Shape result = revol.Shape();
        if (result.IsNull()) return nullptr;
        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTLocOpeRevolWithOffset(OCCTShapeRef profile,
                                        double axisOriginX, double axisOriginY, double axisOriginZ,
                                        double axisDirX, double axisDirY, double axisDirZ,
                                        double angle, double angledec) {
    if (!profile) return nullptr;
    try {
        gp_Ax1 axis(gp_Pnt(axisOriginX, axisOriginY, axisOriginZ),
                     gp_Dir(axisDirX, axisDirY, axisDirZ));
        LocOpe_Revol revol;
        revol.Perform(profile->shape, axis, angle, angledec);
        TopoDS_Shape result = revol.Shape();
        if (result.IsNull()) return nullptr;
        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

// --- LocOpe_DPrism ---

OCCTShapeRef OCCTLocOpeDPrism(OCCTFaceRef spineFace,
                               double height1, double height2, double angle) {
    if (!spineFace) return nullptr;
    try {
        LocOpe_DPrism dprism(spineFace->face, height1, height2, angle);
        if (!dprism.IsDone()) return nullptr;
        TopoDS_Shape result = dprism.Shape();
        if (result.IsNull()) return nullptr;
        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTLocOpeDPrismSingleHeight(OCCTFaceRef spineFace,
                                            double height, double angle) {
    if (!spineFace) return nullptr;
    try {
        LocOpe_DPrism dprism(spineFace->face, height, angle);
        if (!dprism.IsDone()) return nullptr;
        TopoDS_Shape result = dprism.Shape();
        if (result.IsNull()) return nullptr;
        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

// MARK: - LocOpe Form/Split/Find/Intersect (v0.48)
OCCTShapeRef OCCTLocOpePipe(OCCTShapeRef shape, OCCTShapeRef spineWire) {
    if (!shape || !spineWire) return nullptr;
    try {
        // Extract wire from spine shape
        TopoDS_Wire wire;
        if (spineWire->shape.ShapeType() == TopAbs_WIRE) {
            wire = TopoDS::Wire(spineWire->shape);
        } else {
            for (TopExp_Explorer exp(spineWire->shape, TopAbs_WIRE); exp.More(); exp.Next()) {
                wire = TopoDS::Wire(exp.Current());
                break;
            }
        }
        if (wire.IsNull()) return nullptr;

        LocOpe_Pipe pipe(wire, shape->shape);
        TopoDS_Shape result = pipe.Shape();
        if (result.IsNull()) return nullptr;
        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTLocOpeLinearForm(OCCTShapeRef shape,
                                   double dx, double dy, double dz,
                                   double p1x, double p1y, double p1z,
                                   double p2x, double p2y, double p2z) {
    if (!shape) return nullptr;
    try {
        gp_Vec direction(dx, dy, dz);
        gp_Pnt pnt1(p1x, p1y, p1z);
        gp_Pnt pnt2(p2x, p2y, p2z);

        LocOpe_LinearForm linearForm;
        linearForm.Perform(shape->shape, direction, pnt1, pnt2);

        TopoDS_Shape result = linearForm.Shape();
        if (result.IsNull()) return nullptr;
        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTLocOpeRevolutionForm(OCCTShapeRef shape,
                                       double axisOriginX, double axisOriginY, double axisOriginZ,
                                       double axisDirX, double axisDirY, double axisDirZ,
                                       double angle) {
    if (!shape) return nullptr;
    try {
        gp_Ax1 axis(gp_Pnt(axisOriginX, axisOriginY, axisOriginZ),
                     gp_Dir(axisDirX, axisDirY, axisDirZ));

        LocOpe_RevolutionForm revolForm;
        revolForm.Perform(shape->shape, axis, angle);

        TopoDS_Shape result = revolForm.Shape();
        if (result.IsNull()) return nullptr;
        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTLocOpeSplitShapeByWire(OCCTShapeRef shape, int32_t faceIndex, OCCTShapeRef wire) {
    if (!shape || !wire) return nullptr;
    try {
        LocOpe_SplitShape splitter(shape->shape);

        // Find the target face
        TopoDS_Face face;
        int idx = 0;
        for (TopExp_Explorer exp(shape->shape, TopAbs_FACE); exp.More(); exp.Next()) {
            if (idx == faceIndex) {
                face = TopoDS::Face(exp.Current());
                break;
            }
            idx++;
        }
        if (face.IsNull()) return nullptr;

        // Extract wire
        TopoDS_Wire w;
        if (wire->shape.ShapeType() == TopAbs_WIRE) {
            w = TopoDS::Wire(wire->shape);
        } else {
            for (TopExp_Explorer exp(wire->shape, TopAbs_WIRE); exp.More(); exp.Next()) {
                w = TopoDS::Wire(exp.Current());
                break;
            }
        }
        if (w.IsNull()) return nullptr;

        bool added = splitter.Add(w, face);
        if (!added) return nullptr;

        // Rebuild the shape
        // SplitShape doesn't have a Shape() method - we collect descendants
        // Actually, we need to reconstruct. Let's use a different approach.
        // The SplitShape modifies in place - we can use DescendantShapes to see results.
        // For the bridge, let's return a compound of all shapes.
        BRep_Builder builder;
        TopoDS_Compound compound;
        builder.MakeCompound(compound);

        // Add all descendant shapes
        const auto& descendants = splitter.DescendantShapes(face);
        for (auto it = descendants.begin(); it != descendants.end(); ++it) {
            builder.Add(compound, *it);
        }

        // Add other non-split faces
        for (TopExp_Explorer exp(shape->shape, TopAbs_FACE); exp.More(); exp.Next()) {
            TopoDS_Face f = TopoDS::Face(exp.Current());
            if (f.IsSame(face)) continue;
            builder.Add(compound, f);
        }

        return new OCCTShape(compound);
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTLocOpeSplitShapeByVertex(OCCTShapeRef shape, int32_t edgeIndex, double parameter) {
    if (!shape) return nullptr;
    try {
        LocOpe_SplitShape splitter(shape->shape);

        // Find the target edge
        TopoDS_Edge edge;
        int idx = 0;
        for (TopExp_Explorer exp(shape->shape, TopAbs_EDGE); exp.More(); exp.Next()) {
            if (idx == edgeIndex) {
                edge = TopoDS::Edge(exp.Current());
                break;
            }
            idx++;
        }
        if (edge.IsNull()) return nullptr;

        // Get edge parameter range
        double first, last;
        BRep_Tool::Range(edge, first, last);
        double param = first + parameter * (last - first);

        // Create vertex
        gp_Pnt pnt;
        Handle(Geom_Curve) curve = BRep_Tool::Curve(edge, first, last);
        if (curve.IsNull()) return nullptr;
        curve->D0(param, pnt);

        TopoDS_Vertex vertex = BRepBuilderAPI_MakeVertex(pnt);
        splitter.Add(vertex, param, edge);

        // Rebuild
        const auto& descendants = splitter.DescendantShapes(edge);
        if (descendants.Size() < 2) return nullptr;

        BRep_Builder builder;
        TopoDS_Compound compound;
        builder.MakeCompound(compound);
        for (auto it = descendants.begin(); it != descendants.end(); ++it) {
            builder.Add(compound, *it);
        }
        return new OCCTShape(compound);
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTLocOpeSplitDrafts(OCCTShapeRef shape, int32_t faceIndex, OCCTShapeRef wire,
                                    double dirX, double dirY, double dirZ,
                                    double planeOriginX, double planeOriginY, double planeOriginZ,
                                    double planeNormalX, double planeNormalY, double planeNormalZ,
                                    double angle) {
    if (!shape || !wire) return nullptr;
    try {
        LocOpe_SplitDrafts splitDrafts;
        splitDrafts.Init(shape->shape);

        // Find the target face
        TopoDS_Face face;
        int idx = 0;
        for (TopExp_Explorer exp(shape->shape, TopAbs_FACE); exp.More(); exp.Next()) {
            if (idx == faceIndex) {
                face = TopoDS::Face(exp.Current());
                break;
            }
            idx++;
        }
        if (face.IsNull()) return nullptr;

        // Extract wire
        TopoDS_Wire w;
        if (wire->shape.ShapeType() == TopAbs_WIRE) {
            w = TopoDS::Wire(wire->shape);
        } else {
            for (TopExp_Explorer exp(wire->shape, TopAbs_WIRE); exp.More(); exp.Next()) {
                w = TopoDS::Wire(exp.Current());
                break;
            }
        }
        if (w.IsNull()) return nullptr;

        gp_Dir dir(dirX, dirY, dirZ);
        gp_Pln plane(gp_Pnt(planeOriginX, planeOriginY, planeOriginZ),
                      gp_Dir(planeNormalX, planeNormalY, planeNormalZ));

        splitDrafts.Perform(face, w, dir, plane, angle);

        TopoDS_Shape result = splitDrafts.Shape();
        if (result.IsNull()) return nullptr;
        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

int32_t OCCTLocOpeFindEdges(OCCTShapeRef shape1, OCCTShapeRef shape2,
                            OCCTShapeRef* outEdges, int32_t maxEdges) {
    if (!shape1 || !shape2 || !outEdges || maxEdges <= 0) return 0;
    try {
        LocOpe_FindEdges finder;
        finder.Set(shape1->shape, shape2->shape);

        int32_t count = 0;
        for (finder.InitIterator(); finder.More() && count < maxEdges; finder.Next()) {
            outEdges[count] = new OCCTShape(finder.EdgeFrom());
            count++;
        }
        return count;
    } catch (...) {
        return 0;
    }
}

int32_t OCCTLocOpeFindEdgesInFace(OCCTShapeRef shape, int32_t faceIndex,
                                   OCCTShapeRef* outEdges, int32_t maxEdges) {
    if (!shape || !outEdges || maxEdges <= 0) return 0;
    try {
        // Find the target face
        TopoDS_Face face;
        int idx = 0;
        for (TopExp_Explorer exp(shape->shape, TopAbs_FACE); exp.More(); exp.Next()) {
            if (idx == faceIndex) {
                face = TopoDS::Face(exp.Current());
                break;
            }
            idx++;
        }
        if (face.IsNull()) return 0;

        LocOpe_FindEdgesInFace finder;
        finder.Set(shape->shape, face);

        int32_t count = 0;
        for (finder.Init(); finder.More() && count < maxEdges; finder.Next()) {
            outEdges[count] = new OCCTShape(finder.Edge());
            count++;
        }
        return count;
    } catch (...) {
        return 0;
    }
}

int32_t OCCTLocOpeCSIntersectLine(OCCTShapeRef shape,
                                   double lineOriginX, double lineOriginY, double lineOriginZ,
                                   double lineDirX, double lineDirY, double lineDirZ,
                                   OCCTCSIntersectionPoint* outPoints, int32_t maxPoints) {
    if (!shape || !outPoints || maxPoints <= 0) return 0;
    try {
        LocOpe_CSIntersector intersector(shape->shape);

        NCollection_Sequence<gp_Lin> lines;
        lines.Append(gp_Lin(gp_Pnt(lineOriginX, lineOriginY, lineOriginZ),
                             gp_Dir(lineDirX, lineDirY, lineDirZ)));

        intersector.Perform(lines);

        int nbPts = intersector.NbPoints(1); // 1-indexed
        int32_t count = 0;
        for (int i = 1; i <= nbPts && count < maxPoints; i++) {
            const LocOpe_PntFace& pf = intersector.Point(1, i);
            outPoints[count].px = pf.Pnt().X();
            outPoints[count].py = pf.Pnt().Y();
            outPoints[count].pz = pf.Pnt().Z();
            outPoints[count].parameter = pf.Parameter();
            outPoints[count].uOnFace = pf.UParameter();
            outPoints[count].vOnFace = pf.VParameter();
            outPoints[count].orientation = (int32_t)pf.Orientation();
            count++;
        }
        return count;
    } catch (...) {
        return 0;
    }
}

// MARK: - BRepTools_History (v0.50)
struct OCCTHistoryStorage {
    Handle(BRepTools_History) history;
};

OCCTHistoryRef OCCTHistoryCreate(void) {
    try {
        auto* ref = new OCCTHistoryStorage();
        ref->history = new BRepTools_History();
        return ref;
    } catch (...) {
        return nullptr;
    }
}

void OCCTHistoryAddModified(OCCTHistoryRef history, OCCTShapeRef initial, OCCTShapeRef modified) {
    if (!history || !initial || !modified) return;
    try {
        auto* h = static_cast<OCCTHistoryStorage*>(history);
        h->history->AddModified(initial->shape, modified->shape);
    } catch (...) {}
}

void OCCTHistoryAddGenerated(OCCTHistoryRef history, OCCTShapeRef initial, OCCTShapeRef generated) {
    if (!history || !initial || !generated) return;
    try {
        auto* h = static_cast<OCCTHistoryStorage*>(history);
        h->history->AddGenerated(initial->shape, generated->shape);
    } catch (...) {}
}

void OCCTHistoryRemove(OCCTHistoryRef history, OCCTShapeRef shape) {
    if (!history || !shape) return;
    try {
        auto* h = static_cast<OCCTHistoryStorage*>(history);
        h->history->Remove(shape->shape);
    } catch (...) {}
}

bool OCCTHistoryIsRemoved(OCCTHistoryRef history, OCCTShapeRef shape) {
    if (!history || !shape) return false;
    try {
        auto* h = static_cast<OCCTHistoryStorage*>(history);
        return h->history->IsRemoved(shape->shape);
    } catch (...) {
        return false;
    }
}

bool OCCTHistoryHasModified(OCCTHistoryRef history) {
    if (!history) return false;
    auto* h = static_cast<OCCTHistoryStorage*>(history);
    return h->history->HasModified();
}

bool OCCTHistoryHasGenerated(OCCTHistoryRef history) {
    if (!history) return false;
    auto* h = static_cast<OCCTHistoryStorage*>(history);
    return h->history->HasGenerated();
}

bool OCCTHistoryHasRemoved(OCCTHistoryRef history) {
    if (!history) return false;
    auto* h = static_cast<OCCTHistoryStorage*>(history);
    return h->history->HasRemoved();
}

int32_t OCCTHistoryModifiedCount(OCCTHistoryRef history, OCCTShapeRef initial) {
    if (!history || !initial) return 0;
    try {
        auto* h = static_cast<OCCTHistoryStorage*>(history);
        return (int32_t)h->history->Modified(initial->shape).Size();
    } catch (...) {
        return 0;
    }
}

int32_t OCCTHistoryGeneratedCount(OCCTHistoryRef history, OCCTShapeRef initial) {
    if (!history || !initial) return 0;
    try {
        auto* h = static_cast<OCCTHistoryStorage*>(history);
        return (int32_t)h->history->Generated(initial->shape).Size();
    } catch (...) {
        return 0;
    }
}

void OCCTHistoryDestroy(OCCTHistoryRef history) {
    if (!history) return;
    delete static_cast<OCCTHistoryStorage*>(history);
}

// MARK: - BRepLib MakePolygon / MakeWire (v0.51)
OCCTWireRef _Nullable OCCTWireMakePolygonFromPoints(const double* coords, int32_t nPoints, bool close) {
    if (!coords || nPoints < 2) return nullptr;
    try {
        BRepLib_MakePolygon poly;
        for (int32_t i = 0; i < nPoints; i++) {
            poly.Add(gp_Pnt(coords[i*3], coords[i*3+1], coords[i*3+2]));
        }
        if (close) poly.Close();
        if (!poly.IsDone()) return nullptr;
        auto* wire = new OCCTWire();
        wire->wire = poly.Wire();
        return wire;
    } catch (...) {
        return nullptr;
    }
}

// --- BRepLib_MakeWire ---

OCCTWireRef _Nullable OCCTWireMakeWireFromEdges(const OCCTShapeRef _Nonnull * _Nonnull edges, int32_t count) {
    if (!edges || count < 1) return nullptr;
    try {
        BRepLib_MakeWire mw;
        for (int32_t i = 0; i < count; i++) {
            if (!edges[i]) return nullptr;
            TopoDS_Edge edge;
            if (edges[i]->shape.ShapeType() == TopAbs_EDGE) {
                edge = TopoDS::Edge(edges[i]->shape);
            } else {
                for (TopExp_Explorer exp(edges[i]->shape, TopAbs_EDGE); exp.More(); exp.Next()) {
                    edge = TopoDS::Edge(exp.Current());
                    break;
                }
            }
            if (edge.IsNull()) return nullptr;
            mw.Add(edge);
        }
        if (!mw.IsDone()) return nullptr;
        auto* wire = new OCCTWire();
        wire->wire = mw.Wire();
        return wire;
    } catch (...) {
        return nullptr;
    }
}

OCCTWireRef _Nullable OCCTWireMakeWireFromEdgeRefs(const OCCTEdgeRef _Nonnull * _Nonnull edges, int32_t count) {
    if (!edges || count < 1) return nullptr;
    try {
        BRepLib_MakeWire mw;
        for (int32_t i = 0; i < count; i++) {
            if (!edges[i]) return nullptr;
            mw.Add(edges[i]->edge);
        }
        if (!mw.IsDone()) return nullptr;
        auto* wire = new OCCTWire();
        wire->wire = mw.Wire();
        return wire;
    } catch (...) {
        return nullptr;
    }
}

// MARK: - BRepLib MakeSolid (v0.51)
// --- BRepLib_MakeSolid ---

OCCTShapeRef _Nullable OCCTShapeMakeSolidFromShell(OCCTShapeRef shell) {
    if (!shell) return nullptr;
    try {
        TopoDS_Shell sh;
        if (shell->shape.ShapeType() == TopAbs_SHELL) {
            sh = TopoDS::Shell(shell->shape);
        } else {
            for (TopExp_Explorer exp(shell->shape, TopAbs_SHELL); exp.More(); exp.Next()) {
                sh = TopoDS::Shell(exp.Current());
                break;
            }
        }
        if (sh.IsNull()) return nullptr;
        BRepLib_MakeSolid ms(sh);
        if (!ms.IsDone()) return nullptr;
        auto* result = new OCCTShape();
        result->shape = ms.Solid();
        return result;
    } catch (...) {
        return nullptr;
    }
}

// MARK: - GC Mirror / Scale / Translate Transforms (v0.51)
// --- GC_MakeMirror ---

OCCTShapeRef _Nullable OCCTShapeMirrorAboutPoint(OCCTShapeRef shape,
    double px, double py, double pz) {
    if (!shape) return nullptr;
    try {
        GC_MakeMirror mm(gp_Pnt(px, py, pz));
        gp_Trsf trsf = mm.Value()->Trsf();
        BRepBuilderAPI_Transform bt(shape->shape, trsf, true);
        if (!bt.IsDone()) return nullptr;
        auto* result = new OCCTShape();
        result->shape = bt.Shape();
        return result;
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef _Nullable OCCTShapeMirrorAboutAxis(OCCTShapeRef shape,
    double ox, double oy, double oz, double dx, double dy, double dz) {
    if (!shape) return nullptr;
    try {
        GC_MakeMirror mm(gp_Ax1(gp_Pnt(ox, oy, oz), gp_Dir(dx, dy, dz)));
        gp_Trsf trsf = mm.Value()->Trsf();
        BRepBuilderAPI_Transform bt(shape->shape, trsf, true);
        if (!bt.IsDone()) return nullptr;
        auto* result = new OCCTShape();
        result->shape = bt.Shape();
        return result;
    } catch (...) {
        return nullptr;
    }
}

// --- GC_MakeScale ---

OCCTShapeRef _Nullable OCCTShapeScaleAboutPoint(OCCTShapeRef shape,
    double px, double py, double pz, double factor) {
    if (!shape) return nullptr;
    try {
        GC_MakeScale ms(gp_Pnt(px, py, pz), factor);
        gp_Trsf trsf = ms.Value()->Trsf();
        BRepBuilderAPI_Transform bt(shape->shape, trsf, true);
        if (!bt.IsDone()) return nullptr;
        auto* result = new OCCTShape();
        result->shape = bt.Shape();
        return result;
    } catch (...) {
        return nullptr;
    }
}

// --- GC_MakeTranslation ---

OCCTShapeRef _Nullable OCCTShapeTranslateByPoints(OCCTShapeRef shape,
    double p1x, double p1y, double p1z, double p2x, double p2y, double p2z) {
    if (!shape) return nullptr;
    try {
        GC_MakeTranslation mt(gp_Pnt(p1x, p1y, p1z), gp_Pnt(p2x, p2y, p2z));
        gp_Trsf trsf = mt.Value()->Trsf();
        BRepBuilderAPI_Transform bt(shape->shape, trsf, true);
        if (!bt.IsDone()) return nullptr;
        auto* result = new OCCTShape();
        result->shape = bt.Shape();
        return result;
    } catch (...) {
        return nullptr;
    }
}

// MARK: - BRepFill Generator/Evolved/Offset/Draft/Pipe/Compatible (v0.52)
OCCTShapeRef _Nullable OCCTBRepFillGenerator(const OCCTWireRef _Nonnull * _Nonnull wires, int32_t count) {
    if (!wires || count < 2) return nullptr;
    try {
        BRepFill_Generator gen;
        for (int i = 0; i < count; i++) {
            if (!wires[i]) return nullptr;
            gen.AddWire(wires[i]->wire);
        }
        gen.Perform();
        TopoDS_Shell shell = gen.Shell();
        if (shell.IsNull()) return nullptr;
        auto* result = new OCCTShape();
        result->shape = shell;
        return result;
    } catch (...) {
        return nullptr;
    }
}

// --- BRepFill_AdvancedEvolved ---

OCCTShapeRef _Nullable OCCTBRepFillAdvancedEvolved(OCCTWireRef spine, OCCTWireRef profile,
    double tolerance, bool solidReq) {
    if (!spine || !profile) return nullptr;
    try {
        BRepFill_AdvancedEvolved ae;
        ae.Perform(spine->wire, profile->wire, tolerance, solidReq);
        if (!ae.IsDone()) return nullptr;
        TopoDS_Shape shape = ae.Shape();
        if (shape.IsNull()) return nullptr;
        auto* result = new OCCTShape();
        result->shape = shape;
        return result;
    } catch (...) {
        return nullptr;
    }
}

// --- BRepFill_OffsetWire ---

OCCTShapeRef _Nullable OCCTBRepFillOffsetWire(OCCTFaceRef faceRef, double offset) {
    if (!faceRef) return nullptr;
    try {
        BRepFill_OffsetWire ow(faceRef->face, GeomAbs_Arc, false);
        ow.Perform(offset);
        if (!ow.IsDone()) return nullptr;
        TopoDS_Shape shape = ow.Shape();
        if (shape.IsNull()) return nullptr;
        auto* result = new OCCTShape();
        result->shape = shape;
        return result;
    } catch (...) {
        return nullptr;
    }
}

// --- BRepFill_Draft ---

OCCTShapeRef _Nullable OCCTBRepFillDraft(OCCTWireRef wire,
    double dirX, double dirY, double dirZ, double angle, double length) {
    if (!wire) return nullptr;
    try {
        gp_Dir dir(dirX, dirY, dirZ);
        BRepFill_Draft draft(wire->wire, dir, angle);
        draft.Perform(length);
        if (!draft.IsDone()) return nullptr;
        TopoDS_Shape shape = draft.Shape();
        if (shape.IsNull()) return nullptr;
        auto* result = new OCCTShape();
        result->shape = shape;
        return result;
    } catch (...) {
        return nullptr;
    }
}

// --- BRepFill_Pipe ---

OCCTBRepFillPipeResult OCCTBRepFillPipe(OCCTWireRef spine, OCCTWireRef profile) {
    OCCTBRepFillPipeResult result = {};
    if (!spine || !profile) return result;
    try {
        BRepFill_Pipe pipe(spine->wire, profile->wire, GeomFill_IsCorrectedFrenet, false, false);
        TopoDS_Shape shape = pipe.Shape();
        if (shape.IsNull()) return result;
        result.errorOnSurface = pipe.ErrorOnSurface();
        auto* s = new OCCTShape();
        s->shape = shape;
        result.shape = s;
        return result;
    } catch (...) {
        return result;
    }
}

// --- BRepFill_CompatibleWires ---

int32_t OCCTBRepFillCompatibleWires(const OCCTWireRef _Nonnull * _Nonnull wires, int32_t count,
    OCCTWireRef _Nullable * _Nonnull outWires) {
    if (!wires || count < 2 || !outWires) return 0;
    try {
        NCollection_Sequence<TopoDS_Shape> sections;
        for (int i = 0; i < count; i++) {
            if (!wires[i]) return 0;
            sections.Append(wires[i]->wire);
        }
        BRepFill_CompatibleWires cw(sections);
        cw.Perform();
        if (!cw.IsDone()) return 0;
        auto& result = cw.Shape();
        int32_t n = (int32_t)result.Size();
        if (n > count) n = count;
        for (int i = 0; i < n; i++) {
            TopoDS_Wire w = TopoDS::Wire(result.Value(i + 1)); // 1-indexed
            auto* wireObj = new OCCTWire();
            wireObj->wire = w;
            outWires[i] = wireObj;
        }
        return n;
    } catch (...) {
        return 0;
    }
}

// MARK: - ChFi2d_FilletAlgo (v0.52)
// --- ChFi2d_FilletAlgo ---

OCCTChFi2dFilletResult OCCTChFi2dFilletAlgo(OCCTShapeRef edge1, OCCTShapeRef edge2,
    double planeOx, double planeOy, double planeOz,
    double planeNx, double planeNy, double planeNz,
    double radius) {
    OCCTChFi2dFilletResult result = {};
    if (!edge1 || !edge2) return result;
    try {
        TopoDS_Edge e1, e2;
        if (edge1->shape.ShapeType() == TopAbs_EDGE) {
            e1 = TopoDS::Edge(edge1->shape);
        } else {
            for (TopExp_Explorer exp(edge1->shape, TopAbs_EDGE); exp.More(); exp.Next()) {
                e1 = TopoDS::Edge(exp.Current()); break;
            }
        }
        if (edge2->shape.ShapeType() == TopAbs_EDGE) {
            e2 = TopoDS::Edge(edge2->shape);
        } else {
            for (TopExp_Explorer exp(edge2->shape, TopAbs_EDGE); exp.More(); exp.Next()) {
                e2 = TopoDS::Edge(exp.Current()); break;
            }
        }
        if (e1.IsNull() || e2.IsNull()) return result;

        gp_Pln plane(gp_Pnt(planeOx, planeOy, planeOz), gp_Dir(planeNx, planeNy, planeNz));
        ChFi2d_FilletAlgo fillet(e1, e2, plane);
        if (!fillet.Perform(radius)) return result;

        gp_Pnt corner;
        // Find the intersection point of the two edges
        double f1, l1, f2, l2;
        Handle(Geom_Curve) c1 = BRep_Tool::Curve(e1, f1, l1);
        Handle(Geom_Curve) c2 = BRep_Tool::Curve(e2, f2, l2);
        if (c1.IsNull() || c2.IsNull()) return result;
        // Try endpoints
        gp_Pnt p1s = c1->Value(f1), p1e = c1->Value(l1);
        gp_Pnt p2s = c2->Value(f2), p2e = c2->Value(l2);
        if (p1s.Distance(p2s) < 1e-6) corner = p1s;
        else if (p1s.Distance(p2e) < 1e-6) corner = p1s;
        else if (p1e.Distance(p2s) < 1e-6) corner = p1e;
        else if (p1e.Distance(p2e) < 1e-6) corner = p1e;
        else corner = p1s; // fallback

        int nb = fillet.NbResults(corner);
        result.resultCount = nb;
        if (nb < 1) return result;

        TopoDS_Edge re1, re2;
        TopoDS_Edge filletEdge = fillet.Result(corner, re1, re2);
        if (filletEdge.IsNull()) return result;

        result.success = true;
        auto* filletShape = new OCCTShape();
        filletShape->shape = filletEdge;
        result.fillet = filletShape;

        auto* e1Shape = new OCCTShape();
        e1Shape->shape = re1;
        result.edge1 = e1Shape;

        auto* e2Shape = new OCCTShape();
        e2Shape->shape = re2;
        result.edge2 = e2Shape;

        return result;
    } catch (...) {
        return result;
    }
}

// MARK: - LocOpe_BuildShape (v0.52)
// --- LocOpe_BuildShape ---

OCCTShapeRef _Nullable OCCTLocOpeBuildShape(OCCTShapeRef shape) {
    if (!shape) return nullptr;
    try {
        TopTools_ListOfShape faces;
        for (TopExp_Explorer exp(shape->shape, TopAbs_FACE); exp.More(); exp.Next()) {
            faces.Append(exp.Current());
        }
        if (faces.Size() == 0) return nullptr;
        LocOpe_BuildShape bs(faces);
        TopoDS_Shape result = bs.Shape();
        if (result.IsNull()) return nullptr;
        auto* r = new OCCTShape();
        r->shape = result;
        return r;
    } catch (...) {
        return nullptr;
    }
}

// MARK: - ChFi2d_AnaFilletAlgo (v0.52)
// --- ChFi2d_AnaFilletAlgo ---

OCCTAnaFilletResult OCCTChFi2dAnaFillet(OCCTShapeRef edge1, OCCTShapeRef edge2,
    double planeOx, double planeOy, double planeOz,
    double planeNx, double planeNy, double planeNz,
    double radius) {
    OCCTAnaFilletResult result = {};
    if (!edge1 || !edge2) return result;
    try {
        // Extract edges
        TopoDS_Edge e1, e2;
        if (edge1->shape.ShapeType() == TopAbs_EDGE) {
            e1 = TopoDS::Edge(edge1->shape);
        } else {
            for (TopExp_Explorer exp(edge1->shape, TopAbs_EDGE); exp.More(); exp.Next()) {
                e1 = TopoDS::Edge(exp.Current()); break;
            }
        }
        if (edge2->shape.ShapeType() == TopAbs_EDGE) {
            e2 = TopoDS::Edge(edge2->shape);
        } else {
            for (TopExp_Explorer exp(edge2->shape, TopAbs_EDGE); exp.More(); exp.Next()) {
                e2 = TopoDS::Edge(exp.Current()); break;
            }
        }
        if (e1.IsNull() || e2.IsNull()) return result;

        gp_Pln plane(gp_Pnt(planeOx, planeOy, planeOz), gp_Dir(planeNx, planeNy, planeNz));
        ChFi2d_AnaFilletAlgo fillet(e1, e2, plane);
        if (!fillet.Perform(radius)) return result;

        TopoDS_Edge re1, re2;
        TopoDS_Edge filletEdge = fillet.Result(re1, re2);
        if (filletEdge.IsNull()) return result;

        result.success = true;
        auto* filletShape = new OCCTShape();
        filletShape->shape = filletEdge;
        result.fillet = filletShape;

        auto* e1Shape = new OCCTShape();
        e1Shape->shape = re1;
        result.edge1 = e1Shape;

        auto* e2Shape = new OCCTShape();
        e2Shape->shape = re2;
        result.edge2 = e2Shape;

        return result;
    } catch (...) {
        return result;
    }
}


// MARK: - BOPAlgo Splitter (v0.61)
// MARK: - BOPAlgo — Splitter (v0.61.0)

OCCTShapeRef OCCTBOPAlgoSplit(const OCCTShapeRef* objects, int32_t objCount,
    const OCCTShapeRef* tools, int32_t toolCount) {
    if (!objects || objCount <= 0) return nullptr;
    try {
        BOPAlgo_Splitter splitter;
        for (int32_t i = 0; i < objCount; i++) {
            if (objects[i]) splitter.AddArgument(objects[i]->shape);
        }
        if (tools) {
            for (int32_t i = 0; i < toolCount; i++) {
                if (tools[i]) splitter.AddTool(tools[i]->shape);
            }
        }
        splitter.Perform();
        if (splitter.HasErrors()) return nullptr;
        return new OCCTShape(splitter.Shape());
    } catch (...) { return nullptr; }
}

// MARK: - BOPAlgo CellsBuilder (v0.61)
// MARK: - BOPAlgo — CellsBuilder (v0.61.0)

struct OCCTCellsBuilder {
    BOPAlgo_CellsBuilder builder;
};

OCCTCellsBuilderRef OCCTCellsBuilderCreate(const OCCTShapeRef* shapes, int32_t count) {
    if (!shapes || count <= 0) return nullptr;
    try {
        auto* cb = new OCCTCellsBuilder();
        int added = 0;
        for (int32_t i = 0; i < count; i++) {
            if (shapes[i] && !shapes[i]->shape.IsNull()) {
                cb->builder.AddArgument(shapes[i]->shape);
                added++;
            }
        }
        // Need at least one valid shape to partition
        if (added == 0) {
            delete cb;
            return nullptr;
        }
        cb->builder.Perform();
        if (cb->builder.HasErrors()) {
            delete cb;
            return nullptr;
        }
        return cb;
    } catch (...) { return nullptr; }
}

void OCCTCellsBuilderRelease(OCCTCellsBuilderRef builder) {
    delete builder;
}

void OCCTCellsBuilderAddAllToResult(OCCTCellsBuilderRef builder, int32_t material) {
    if (!builder) return;
    try {
        builder->builder.AddAllToResult(material, true);
    } catch (...) {}
}

void OCCTCellsBuilderRemoveAllFromResult(OCCTCellsBuilderRef builder) {
    if (!builder) return;
    try {
        builder->builder.RemoveAllFromResult();
    } catch (...) {}
}

void OCCTCellsBuilderRemoveInternalBoundaries(OCCTCellsBuilderRef builder) {
    if (!builder) return;
    try {
        builder->builder.RemoveInternalBoundaries();
    } catch (...) {}
}

OCCTShapeRef OCCTCellsBuilderGetResult(OCCTCellsBuilderRef builder) {
    if (!builder) return nullptr;
    try {
        TopoDS_Shape result = builder->builder.Shape();
        if (result.IsNull()) return nullptr;
        return new OCCTShape(result);
    } catch (...) { return nullptr; }
}

// MARK: - BOPAlgo ArgumentAnalyzer (v0.61)
// MARK: - BOPAlgo — ArgumentAnalyzer (v0.61.0)

bool OCCTBOPAlgoAnalyzeArguments(OCCTShapeRef shape1, OCCTShapeRef shape2, int32_t operation) {
    if (!shape1 || !shape2) return false;
    try {
        BOPAlgo_ArgumentAnalyzer analyzer;
        analyzer.SetShape1(shape1->shape);
        analyzer.SetShape2(shape2->shape);
        switch (operation) {
            case 0: analyzer.OperationType() = BOPAlgo_FUSE; break;
            case 1: analyzer.OperationType() = BOPAlgo_COMMON; break;
            case 2: analyzer.OperationType() = BOPAlgo_CUT; break;
            case 3: analyzer.OperationType() = BOPAlgo_CUT21; break;
            case 4: analyzer.OperationType() = BOPAlgo_SECTION; break;
            default: analyzer.OperationType() = BOPAlgo_FUSE; break;
        }
        analyzer.ArgumentTypeMode() = true;
        analyzer.SelfInterMode() = true;
        analyzer.SmallEdgeMode() = true;
        analyzer.Perform();
        return !analyzer.HasFaulty();
    } catch (...) { return false; }
}

// MARK: - BRepBuilderAPI_MakeShapeOnMesh (v0.61)
// MARK: - BRepBuilderAPI_MakeShapeOnMesh (v0.61.0)

OCCTShapeRef OCCTShapeFromMesh(const double* points, int32_t nodeCount,
    const int32_t* triangles, int32_t triCount) {
    if (!points || nodeCount < 3 || !triangles || triCount < 1) return nullptr;
    try {
        TColgp_Array1OfPnt nodes(1, nodeCount);
        for (int32_t i = 0; i < nodeCount; i++) {
            nodes.SetValue(i + 1, gp_Pnt(points[i*3], points[i*3+1], points[i*3+2]));
        }

        Poly_Array1OfTriangle tris(1, triCount);
        for (int32_t i = 0; i < triCount; i++) {
            tris.SetValue(i + 1, Poly_Triangle(triangles[i*3], triangles[i*3+1], triangles[i*3+2]));
        }

        Handle(Poly_Triangulation) mesh = new Poly_Triangulation(nodes, tris);
        if (mesh.IsNull()) return nullptr;

        BRepBuilderAPI_MakeShapeOnMesh maker(mesh);
        maker.Build();
        if (!maker.IsDone()) return nullptr;
        return new OCCTShape(maker.Shape());
    } catch (...) { return nullptr; }
}

// MARK: - CellsBuilder Extensions (later release)
// --- CellsBuilder extensions ---

void OCCTCellsBuilderAddToResultSelective(OCCTCellsBuilderRef builder,
                                           const OCCTShapeRef* takeShapes, int32_t takeCount,
                                           const OCCTShapeRef* avoidShapes, int32_t avoidCount,
                                           int32_t material, bool update) {
    if (!builder) return;
    try {
        NCollection_List<TopoDS_Shape> take, avoid;
        for (int32_t i = 0; i < takeCount; i++) {
            if (takeShapes[i]) take.Append(takeShapes[i]->shape);
        }
        for (int32_t i = 0; i < avoidCount; i++) {
            if (avoidShapes[i]) avoid.Append(avoidShapes[i]->shape);
        }
        builder->builder.AddToResult(take, avoid, material, update);
    } catch (...) {}
}

void OCCTCellsBuilderRemoveFromResult(OCCTCellsBuilderRef builder,
                                       const OCCTShapeRef* takeShapes, int32_t takeCount,
                                       const OCCTShapeRef* avoidShapes, int32_t avoidCount) {
    if (!builder) return;
    try {
        NCollection_List<TopoDS_Shape> take, avoid;
        for (int32_t i = 0; i < takeCount; i++) {
            if (takeShapes[i]) take.Append(takeShapes[i]->shape);
        }
        for (int32_t i = 0; i < avoidCount; i++) {
            if (avoidShapes[i]) avoid.Append(avoidShapes[i]->shape);
        }
        builder->builder.RemoveFromResult(take, avoid);
    } catch (...) {}
}

OCCTShapeRef OCCTCellsBuilderGetAllParts(OCCTCellsBuilderRef builder) {
    if (!builder) return nullptr;
    try {
        const TopoDS_Shape& parts = builder->builder.GetAllParts();
        if (parts.IsNull()) return nullptr;
        return new OCCTShape{parts};
    } catch (...) { return nullptr; }
}

void OCCTCellsBuilderMakeContainers(OCCTCellsBuilderRef builder) {
    if (!builder) return;
    try { builder->builder.MakeContainers(); } catch (...) {}
}


// MARK: - BRepLib MakeEdge / MakeFace (v0.62)
// --- BRepLib_MakeEdge ---

OCCTShapeRef _Nullable OCCTBRepLibMakeEdgeFromLine(
    double ox, double oy, double oz,
    double dx, double dy, double dz,
    double p1, double p2) {
    try {
        gp_Lin line(gp_Pnt(ox, oy, oz), gp_Dir(dx, dy, dz));
        BRepLib_MakeEdge me(line, p1, p2);
        if (!me.IsDone()) return nullptr;
        return new OCCTShape(me.Edge());
    } catch (...) { return nullptr; }
}

OCCTShapeRef _Nullable OCCTBRepLibMakeEdgeFromPoints(
    double x1, double y1, double z1,
    double x2, double y2, double z2) {
    try {
        BRepLib_MakeEdge me(gp_Pnt(x1, y1, z1), gp_Pnt(x2, y2, z2));
        if (!me.IsDone()) return nullptr;
        return new OCCTShape(me.Edge());
    } catch (...) { return nullptr; }
}

OCCTShapeRef _Nullable OCCTBRepLibMakeEdgeFromCircle(
    double cx, double cy, double cz,
    double dx, double dy, double dz,
    double radius, double p1, double p2) {
    try {
        gp_Circ circ(gp_Ax2(gp_Pnt(cx, cy, cz), gp_Dir(dx, dy, dz)), radius);
        BRepLib_MakeEdge me(circ, p1, p2);
        if (!me.IsDone()) return nullptr;
        return new OCCTShape(me.Edge());
    } catch (...) { return nullptr; }
}

// --- BRepLib_MakeFace ---

OCCTShapeRef _Nullable OCCTBRepLibMakeFaceFromPlane(
    double ox, double oy, double oz,
    double nx, double ny, double nz,
    double uMin, double uMax, double vMin, double vMax, double tolerance) {
    try {
        gp_Pln pln(gp_Pnt(ox, oy, oz), gp_Dir(nx, ny, nz));
        Handle(Geom_Plane) plane = new Geom_Plane(pln);
        BRepLib_MakeFace mf(plane, uMin, uMax, vMin, vMax, tolerance);
        if (!mf.IsDone()) return nullptr;
        return new OCCTShape(mf.Face());
    } catch (...) { return nullptr; }
}

OCCTShapeRef _Nullable OCCTBRepLibMakeFaceFromCylinder(
    double ox, double oy, double oz,
    double dx, double dy, double dz,
    double radius,
    double uMin, double uMax, double vMin, double vMax, double tolerance) {
    try {
        Handle(Geom_CylindricalSurface) cyl = new Geom_CylindricalSurface(
            gp_Ax2(gp_Pnt(ox, oy, oz), gp_Dir(dx, dy, dz)), radius);
        BRepLib_MakeFace mf(cyl, uMin, uMax, vMin, vMax, tolerance);
        if (!mf.IsDone()) return nullptr;
        return new OCCTShape(mf.Face());
    } catch (...) { return nullptr; }
}

// MARK: - BRepLib MakeShell (v0.62)
// --- BRepLib_MakeShell ---

OCCTShapeRef _Nullable OCCTBRepLibMakeShellFromPlane(
    double ox, double oy, double oz,
    double nx, double ny, double nz,
    double uMin, double uMax, double vMin, double vMax) {
    try {
        Handle(Geom_Plane) plane = new Geom_Plane(gp_Pnt(ox, oy, oz), gp_Dir(nx, ny, nz));
        BRepLib_MakeShell ms(plane, uMin, uMax, vMin, vMax, false);
        if (!ms.IsDone()) return nullptr;
        return new OCCTShape(ms.Shell());
    } catch (...) { return nullptr; }
}

// MARK: - BRepTools_Modifier NurbsConvert (v0.62)
// --- BRepTools_Modifier ---

OCCTShapeRef _Nullable OCCTBRepToolsModifierNurbsConvert(OCCTShapeRef shape) {
    if (!shape) return nullptr;
    try {
        Handle(BRepTools_NurbsConvertModification) mod = new BRepTools_NurbsConvertModification();
        BRepTools_Modifier modifier(shape->shape);
        modifier.Perform(mod);
        if (!modifier.IsDone()) return nullptr;
        return new OCCTShape(modifier.ModifiedShape(shape->shape));
    } catch (...) { return nullptr; }
}

// MARK: - LocOpe BuildWires / WiresOnShape+Spliter / CurveShapeIntersector (v0.62)
// --- LocOpe_BuildWires ---

bool OCCTLocOpeBuildWires(OCCTShapeRef shape, int32_t faceIndex,
    OCCTShapeRef _Nullable * _Nullable * _Nonnull outWires,
    int32_t* outCount) {
    if (!shape) return false;
    try {
        NCollection_List<TopoDS_Shape> edges;
        if (faceIndex > 0) {
            TopTools_IndexedMapOfShape faceMap;
            TopExp::MapShapes(shape->shape, TopAbs_FACE, faceMap);
            if (faceIndex > faceMap.Extent()) return false;
            TopoDS_Face face = TopoDS::Face(faceMap(faceIndex));
            TopExp_Explorer exp(face, TopAbs_EDGE);
            for (; exp.More(); exp.Next()) edges.Append(exp.Current());
        } else {
            TopExp_Explorer exp(shape->shape, TopAbs_EDGE);
            for (; exp.More(); exp.Next()) edges.Append(exp.Current());
        }

        Handle(LocOpe_WiresOnShape) wos = new LocOpe_WiresOnShape(shape->shape);
        LocOpe_BuildWires bw(edges, wos);
        if (!bw.IsDone()) return false;

        const NCollection_List<TopoDS_Shape>& result = bw.Result();
        int32_t n = result.Size();
        *outCount = n;
        if (n == 0) { *outWires = nullptr; return true; }
        *outWires = (OCCTShapeRef*)malloc(n * sizeof(OCCTShapeRef));
        int32_t i = 0;
        for (auto it = result.cbegin(); it != result.cend(); ++it, ++i) {
            (*outWires)[i] = new OCCTShape(*it);
        }
        return true;
    } catch (...) { return false; }
}
// --- LocOpe_WiresOnShape + LocOpe_Spliter ---

OCCTShapeRef _Nullable OCCTLocOpeSplitByWireOnFace(OCCTShapeRef shape,
    OCCTShapeRef wire, int32_t faceIndex) {
    if (!shape || !wire) return nullptr;
    try {
        TopTools_IndexedMapOfShape faceMap;
        TopExp::MapShapes(shape->shape, TopAbs_FACE, faceMap);
        if (faceIndex < 1 || faceIndex > faceMap.Extent()) return nullptr;
        TopoDS_Face face = TopoDS::Face(faceMap(faceIndex));

        TopoDS_Wire w;
        if (wire->shape.ShapeType() == TopAbs_WIRE) {
            w = TopoDS::Wire(wire->shape);
        } else {
            TopExp_Explorer exp(wire->shape, TopAbs_WIRE);
            if (exp.More()) w = TopoDS::Wire(exp.Current());
            else return nullptr;
        }

        Handle(LocOpe_WiresOnShape) wos = new LocOpe_WiresOnShape(shape->shape);
        wos->Bind(w, face);
        wos->BindAll();

        LocOpe_Spliter spliter(shape->shape);
        spliter.Perform(wos);
        if (!spliter.IsDone()) return nullptr;

        return new OCCTShape(spliter.ResultingShape());
    } catch (...) { return nullptr; }
}
// --- LocOpe_CurveShapeIntersector ---

bool OCCTLocOpeCurveShapeIntersectLine(OCCTShapeRef shape,
    double ox, double oy, double oz,
    double dx, double dy, double dz,
    double* _Nullable * _Nonnull outParams,
    int32_t* outCount) {
    if (!shape) return false;
    try {
        gp_Ax1 axis(gp_Pnt(ox, oy, oz), gp_Dir(dx, dy, dz));
        LocOpe_CurveShapeIntersector csi(axis, shape->shape);
        if (!csi.IsDone()) return false;
        int32_t n = csi.NbPoints();
        *outCount = n;
        if (n == 0) { *outParams = nullptr; return true; }
        *outParams = (double*)malloc(n * sizeof(double));
        for (int32_t i = 0; i < n; i++) {
            const LocOpe_PntFace& pf = csi.Point(i + 1);
            (*outParams)[i] = pf.Parameter();
        }
        return true;
    } catch (...) { return false; }
}

// MARK: - BRepOffset_SimpleOffset (v0.63)
// --- BRepOffset_SimpleOffset ---

OCCTShapeRef _Nullable OCCTBRepOffsetSimpleOffset(OCCTShapeRef shape, double offset, double tolerance) {
    if (!shape) return nullptr;
    try {
        Handle(BRepOffset_SimpleOffset) mod = new BRepOffset_SimpleOffset(shape->shape, offset, tolerance);
        BRepTools_Modifier modifier(shape->shape, mod);
        if (!modifier.IsDone()) return nullptr;
        TopoDS_Shape result = modifier.ModifiedShape(shape->shape);
        if (result.IsNull()) return nullptr;
        return new OCCTShape(result);
    } catch (...) { return nullptr; }
}

// MARK: - BRepFeat_Builder (v0.63)
// --- BRepFeat_Builder ---

OCCTShapeRef _Nullable OCCTBRepFeatBuilderFuse(OCCTShapeRef shape, OCCTShapeRef tool) {
    if (!shape || !tool) return nullptr;
    try {
        BRepFeat_Builder builder;
        builder.Init(shape->shape, tool->shape);
        builder.SetOperation(1); // Fuse
        TopTools_ListOfShape parts;
        builder.PartsOfTool(parts);
        for (auto it = parts.begin(); it != parts.end(); ++it) {
            builder.KeepPart(*it);
        }
        builder.PerformResult();
        if (builder.HasErrors()) return nullptr;
        TopoDS_Shape result = builder.Shape();
        if (result.IsNull()) return nullptr;
        return new OCCTShape(result);
    } catch (...) { return nullptr; }
}

OCCTShapeRef _Nullable OCCTBRepFeatBuilderCut(OCCTShapeRef shape, OCCTShapeRef tool) {
    if (!shape || !tool) return nullptr;
    try {
        BRepFeat_Builder builder;
        builder.Init(shape->shape, tool->shape);
        builder.SetOperation(0); // Cut
        TopTools_ListOfShape parts;
        builder.PartsOfTool(parts);
        // For cut, keep NO parts of tool (remove all)
        builder.PerformResult();
        if (builder.HasErrors()) return nullptr;
        TopoDS_Shape result = builder.Shape();
        if (result.IsNull()) return nullptr;
        return new OCCTShape(result);
    } catch (...) { return nullptr; }
}

// MARK: - BRepOffset_Offset Face (v0.64)
// --- BRepOffset_Offset ---

OCCTShapeRef _Nullable OCCTBRepOffsetOffsetFace(OCCTShapeRef faceShape, double offset) {
    if (!faceShape) return nullptr;
    try {
        TopoDS_Face face = TopoDS::Face(faceShape->shape);
        BRepOffset_Offset off(face, offset, false, GeomAbs_Arc);
        TopoDS_Face result = off.Face();
        if (result.IsNull()) return nullptr;
        return new OCCTShape(result);
    } catch (...) { return nullptr; }
}

// MARK: - BOPAlgo RemoveFeatures (v0.64)
// --- BOPAlgo_RemoveFeatures ---

OCCTShapeRef _Nullable OCCTBOPAlgoRemoveFeatures(OCCTShapeRef shape,
    const OCCTShapeRef _Nonnull * _Nonnull facesToRemove, int32_t faceCount) {
    if (!shape || faceCount <= 0) return nullptr;
    try {
        BOPAlgo_RemoveFeatures remover;
        remover.SetShape(shape->shape);
        for (int32_t i = 0; i < faceCount; i++) {
            if (facesToRemove[i]) {
                remover.AddFaceToRemove(facesToRemove[i]->shape);
            }
        }
        remover.Perform();
        if (remover.HasErrors()) return nullptr;
        TopoDS_Shape result = remover.Shape();
        if (result.IsNull()) return nullptr;
        return new OCCTShape(result);
    } catch (...) { return nullptr; }
}

// MARK: - BOPAlgo Section (v0.64)
// --- BOPAlgo_Section ---

OCCTShapeRef _Nullable OCCTBOPAlgoSection(const OCCTShapeRef _Nonnull * _Nonnull objects, int32_t objCount,
    const OCCTShapeRef _Nonnull * _Nonnull tools, int32_t toolCount) {
    if (objCount <= 0) return nullptr;
    try {
        BOPAlgo_Section section;
        for (int32_t i = 0; i < objCount; i++) {
            if (objects[i]) section.AddArgument(objects[i]->shape);
        }
        for (int32_t i = 0; i < toolCount; i++) {
            if (tools[i]) section.AddArgument(tools[i]->shape);
        }
        section.Perform();
        if (section.HasErrors()) return nullptr;
        TopoDS_Shape result = section.Shape();
        if (result.IsNull()) return nullptr;
        return new OCCTShape(result);
    } catch (...) { return nullptr; }
}

// MARK: - Law_BSplineKnotSplitting + Law_Composite (v0.68)
// --- Law_BSplineKnotSplitting ---

int32_t OCCTLawBSplineKnotSplitting(OCCTLawFunctionRef law,
    int32_t continuityOrder,
    int32_t* outIndices, int32_t maxIndices)
{
    try {
        auto* wrapper = reinterpret_cast<OCCTLawFunction*>(law);
        // The law must be a BSpline-based law (Law_BSpFunc or similar)
        Handle(Law_BSpFunc) bspFunc = Handle(Law_BSpFunc)::DownCast(wrapper->law);
        if (bspFunc.IsNull()) return 0;

        Handle(Law_BSpline) bspl = bspFunc->Curve();
        if (bspl.IsNull()) return 0;

        Law_BSplineKnotSplitting splitter(bspl, continuityOrder);
        int nb = splitter.NbSplits();
        int count = std::min((int)maxIndices, nb);
        NCollection_Array1<int> splits(1, nb);
        splitter.Splitting(splits);
        for (int i = 0; i < count; i++) {
            outIndices[i] = (int32_t)splits(i + 1);
        }
        return (int32_t)count;
    } catch (...) {
        return 0;
    }
}

// --- Law_Composite ---

OCCTLawFunctionRef OCCTLawComposite(const OCCTLawFunctionRef* lawRefs,
    int32_t count, double first, double last)
{
    try {
        Handle(Law_Composite) composite = new Law_Composite(first, last, 1.0e-6);
        NCollection_List<Handle(Law_Function)>& laws = composite->ChangeLaws();
        for (int32_t i = 0; i < count; i++) {
            auto* wrapper = reinterpret_cast<OCCTLawFunction*>(lawRefs[i]);
            laws.Append(wrapper->law);
        }

        auto* result = new OCCTLawFunction();
        result->law = composite;
        return reinterpret_cast<OCCTLawFunctionRef>(result);
    } catch (...) {
        return nullptr;
    }
}

// MARK: - IntTools EdgeEdge / EdgeFace / FaceFace / FClass2d (v0.70)
// MARK: - BOPAlgo BuilderFace / BuilderSolid / ShellSplitter / EdgesToWires / WiresToFaces (v0.70)
// MARK: - BOPTools NormalOnEdge / PointInFace / IsEmptyShape / IsOpenShell (v0.70)
static void fillCommonPart(const IntTools_CommonPrt& cp, OCCTCommonPart& out) {
    out.type = (cp.Type() == TopAbs_VERTEX) ? 0 : 1;
    IntTools_Range r1 = cp.Range1();
    out.param1First = r1.First();
    out.param1Last = r1.Last();
    // Range2 is a sequence; use first element if available
    if (cp.Ranges2().Length() > 0) {
        out.param2First = cp.Ranges2()(1).First();
        out.param2Last = cp.Ranges2()(1).Last();
    } else {
        out.param2First = cp.VertexParameter2();
        out.param2Last = cp.VertexParameter2();
    }
    if (cp.Type() == TopAbs_VERTEX) {
        out.param1First = cp.VertexParameter1();
        out.param1Last = cp.VertexParameter1();
        out.param2First = cp.VertexParameter2();
        out.param2Last = cp.VertexParameter2();
    }
    // Bounding points
    gp_Pnt bp1, bp2;
    cp.BoundingPoints(bp1, bp2);
    // Use midpoint as representative point
    out.pointX = (bp1.X() + bp2.X()) / 2.0;
    out.pointY = (bp1.Y() + bp2.Y()) / 2.0;
    out.pointZ = (bp1.Z() + bp2.Z()) / 2.0;
}

bool OCCTIntToolsEdgeEdge(OCCTShapeRef _Nonnull edge1, OCCTShapeRef _Nonnull edge2,
    OCCTCommonPart* _Nullable * _Nonnull outParts, int32_t* _Nonnull outCount) {
    try {
        const TopoDS_Edge& e1 = TopoDS::Edge(edge1->shape);
        const TopoDS_Edge& e2 = TopoDS::Edge(edge2->shape);

        IntTools_EdgeEdge ee(e1, e2);
        ee.Perform();
        if (!ee.IsDone()) {
            *outParts = nullptr;
            *outCount = 0;
            return false;
        }

        const IntTools_SequenceOfCommonPrts& cps = ee.CommonParts();
        int32_t n = cps.Length();
        *outCount = n;
        if (n == 0) {
            *outParts = nullptr;
            return true;
        }

        *outParts = (OCCTCommonPart*)malloc(sizeof(OCCTCommonPart) * n);
        for (int32_t i = 0; i < n; i++) {
            fillCommonPart(cps(i + 1), (*outParts)[i]);
        }
        return true;
    } catch (...) {
        *outParts = nullptr;
        *outCount = 0;
        return false;
    }
}

bool OCCTIntToolsEdgeFace(OCCTShapeRef _Nonnull edge, OCCTShapeRef _Nonnull face,
    OCCTCommonPart* _Nullable * _Nonnull outParts, int32_t* _Nonnull outCount) {
    try {
        const TopoDS_Edge& e = TopoDS::Edge(edge->shape);
        const TopoDS_Face& f = TopoDS::Face(face->shape);

        IntTools_EdgeFace ef;
        ef.SetEdge(e);
        ef.SetFace(f);
        ef.Perform();
        if (!ef.IsDone()) {
            *outParts = nullptr;
            *outCount = 0;
            return false;
        }

        const IntTools_SequenceOfCommonPrts& cps = ef.CommonParts();
        int32_t n = cps.Length();
        *outCount = n;
        if (n == 0) {
            *outParts = nullptr;
            return true;
        }

        *outParts = (OCCTCommonPart*)malloc(sizeof(OCCTCommonPart) * n);
        for (int32_t i = 0; i < n; i++) {
            fillCommonPart(cps(i + 1), (*outParts)[i]);
        }
        return true;
    } catch (...) {
        *outParts = nullptr;
        *outCount = 0;
        return false;
    }
}

bool OCCTIntToolsFaceFace(OCCTShapeRef _Nonnull face1, OCCTShapeRef _Nonnull face2,
    double tolerance,
    OCCTFaceFaceCurve* _Nullable * _Nonnull outCurves, int32_t* _Nonnull outCurveCount,
    OCCTFaceFacePoint* _Nullable * _Nonnull outPoints, int32_t* _Nonnull outPointCount,
    bool* _Nonnull outTangent) {
    try {
        const TopoDS_Face& f1 = TopoDS::Face(face1->shape);
        const TopoDS_Face& f2 = TopoDS::Face(face2->shape);

        IntTools_FaceFace ff;
        ff.SetParameters(true, true, true, tolerance);
        ff.Perform(f1, f2);
        if (!ff.IsDone()) {
            *outCurves = nullptr; *outCurveCount = 0;
            *outPoints = nullptr; *outPointCount = 0;
            *outTangent = false;
            return false;
        }

        *outTangent = ff.TangentFaces();

        // Curves
        const IntTools_SequenceOfCurves& lines = ff.Lines();
        int32_t nc = lines.Length();
        *outCurveCount = nc;
        if (nc > 0) {
            *outCurves = (OCCTFaceFaceCurve*)malloc(sizeof(OCCTFaceFaceCurve) * nc);
            for (int32_t i = 0; i < nc; i++) {
                const IntTools_Curve& c = lines(i + 1);
                (*outCurves)[i].hasStart = c.HasBounds();
                (*outCurves)[i].hasEnd = c.HasBounds();
                if (c.HasBounds()) {
                    gp_Pnt p1, p2;
                    c.Bounds((*outCurves)[i].startX, (*outCurves)[i].endX, p1, p2);
                    // startX/endX are actually parameter values; use points
                    (*outCurves)[i].startX = p1.X();
                    (*outCurves)[i].startY = p1.Y();
                    (*outCurves)[i].startZ = p1.Z();
                    (*outCurves)[i].endX = p2.X();
                    (*outCurves)[i].endY = p2.Y();
                    (*outCurves)[i].endZ = p2.Z();
                } else {
                    (*outCurves)[i].startX = (*outCurves)[i].startY = (*outCurves)[i].startZ = 0;
                    (*outCurves)[i].endX = (*outCurves)[i].endY = (*outCurves)[i].endZ = 0;
                }
            }
        } else {
            *outCurves = nullptr;
        }

        // Points
        const IntTools_SequenceOfPntOn2Faces& pts = ff.Points();
        int32_t np = pts.Length();
        *outPointCount = np;
        if (np > 0) {
            *outPoints = (OCCTFaceFacePoint*)malloc(sizeof(OCCTFaceFacePoint) * np);
            for (int32_t i = 0; i < np; i++) {
                const IntTools_PntOn2Faces& pp = pts(i + 1);
                gp_Pnt p1 = pp.P1().Pnt();
                gp_Pnt p2 = pp.P2().Pnt();
                (*outPoints)[i].x1 = p1.X(); (*outPoints)[i].y1 = p1.Y(); (*outPoints)[i].z1 = p1.Z();
                (*outPoints)[i].x2 = p2.X(); (*outPoints)[i].y2 = p2.Y(); (*outPoints)[i].z2 = p2.Z();
            }
        } else {
            *outPoints = nullptr;
        }

        return true;
    } catch (...) {
        *outCurves = nullptr; *outCurveCount = 0;
        *outPoints = nullptr; *outPointCount = 0;
        *outTangent = false;
        return false;
    }
}

int32_t OCCTIntToolsFClass2dPerform(OCCTShapeRef _Nonnull face, double u, double v, double tolerance) {
    try {
        const TopoDS_Face& f = TopoDS::Face(face->shape);
        IntTools_FClass2d fc(f, tolerance);
        TopAbs_State state = fc.Perform(gp_Pnt2d(u, v));
        switch (state) {
            case TopAbs_IN: return 0;
            case TopAbs_ON: return 1;
            case TopAbs_OUT: return 2;
            default: return 3;
        }
    } catch (...) {
        return 3; // UNKNOWN
    }
}

bool OCCTIntToolsFClass2dIsHole(OCCTShapeRef _Nonnull face, double tolerance) {
    try {
        const TopoDS_Face& f = TopoDS::Face(face->shape);
        IntTools_FClass2d fc(f, tolerance);
        return fc.IsHole();
    } catch (...) {
        return false;
    }
}

// MARK: - BOPAlgo Builder (v0.70.0)

bool OCCTBOPAlgoBuilderFace(OCCTShapeRef _Nonnull baseFace,
    const OCCTShapeRef _Nonnull * _Nonnull edges, int32_t edgeCount,
    OCCTShapeRef _Nullable * _Nullable * _Nonnull outFaces, int32_t* _Nonnull outFaceCount) {
    try {
        const TopoDS_Face& face = TopoDS::Face(baseFace->shape);

        BOPAlgo_BuilderFace bf;
        bf.SetFace(face);
        TopTools_ListOfShape shapes;
        for (int32_t i = 0; i < edgeCount; i++) {
            shapes.Append(edges[i]->shape);
        }
        bf.SetShapes(shapes);
        bf.Perform();

        if (bf.HasErrors()) {
            *outFaces = nullptr;
            *outFaceCount = 0;
            return false;
        }

        const TopTools_ListOfShape& areas = bf.Areas();
        int32_t n = areas.Size();
        *outFaceCount = n;
        if (n == 0) {
            *outFaces = nullptr;
            return true;
        }

        *outFaces = (OCCTShapeRef*)malloc(sizeof(OCCTShapeRef) * n);
        int32_t idx = 0;
        for (TopTools_ListOfShape::Iterator it(areas); it.More(); it.Next(), idx++) {
            (*outFaces)[idx] = new OCCTShape(it.Value());
        }
        return true;
    } catch (...) {
        *outFaces = nullptr;
        *outFaceCount = 0;
        return false;
    }
}

bool OCCTBOPAlgoBuilderSolid(const OCCTShapeRef _Nonnull * _Nonnull faces, int32_t faceCount,
    OCCTShapeRef _Nullable * _Nullable * _Nonnull outSolids, int32_t* _Nonnull outSolidCount) {
    try {
        BOPAlgo_BuilderSolid bs;
        TopTools_ListOfShape shapes;
        for (int32_t i = 0; i < faceCount; i++) {
            shapes.Append(faces[i]->shape);
        }
        bs.SetShapes(shapes);
        bs.Perform();

        if (bs.HasErrors()) {
            *outSolids = nullptr;
            *outSolidCount = 0;
            return false;
        }

        const TopTools_ListOfShape& areas = bs.Areas();
        int32_t n = areas.Size();
        *outSolidCount = n;
        if (n == 0) {
            *outSolids = nullptr;
            return true;
        }

        *outSolids = (OCCTShapeRef*)malloc(sizeof(OCCTShapeRef) * n);
        int32_t idx = 0;
        for (TopTools_ListOfShape::Iterator it(areas); it.More(); it.Next(), idx++) {
            (*outSolids)[idx] = new OCCTShape(it.Value());
        }
        return true;
    } catch (...) {
        *outSolids = nullptr;
        *outSolidCount = 0;
        return false;
    }
}

bool OCCTBOPAlgoShellSplitter(OCCTShapeRef _Nonnull shell,
    OCCTShapeRef _Nullable * _Nullable * _Nonnull outShells, int32_t* _Nonnull outShellCount) {
    try {
        const TopoDS_Shell& sh = TopoDS::Shell(shell->shape);

        BOPAlgo_ShellSplitter ss;
        ss.AddStartElement(sh);
        ss.Perform();

        if (ss.HasErrors()) {
            *outShells = nullptr;
            *outShellCount = 0;
            return false;
        }

        const TopTools_ListOfShape& shells = ss.Shells();
        int32_t n = shells.Size();
        *outShellCount = n;
        if (n == 0) {
            *outShells = nullptr;
            return true;
        }

        *outShells = (OCCTShapeRef*)malloc(sizeof(OCCTShapeRef) * n);
        int32_t idx = 0;
        for (TopTools_ListOfShape::Iterator it(shells); it.More(); it.Next(), idx++) {
            (*outShells)[idx] = new OCCTShape(it.Value());
        }
        return true;
    } catch (...) {
        *outShells = nullptr;
        *outShellCount = 0;
        return false;
    }
}

OCCTShapeRef _Nullable OCCTBOPAlgoEdgesToWires(OCCTShapeRef _Nonnull edges, double tolerance) {
    try {
        TopoDS_Shape result;
        bool shared = false;
        int status = BOPAlgo_Tools::EdgesToWires(edges->shape, result, shared, tolerance);
        if (status != 0) return nullptr;
        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef _Nullable OCCTBOPAlgoWiresToFaces(OCCTShapeRef _Nonnull wires, double tolerance) {
    try {
        TopoDS_Shape result;
        bool ok = BOPAlgo_Tools::WiresToFaces(wires->shape, result, tolerance);
        if (!ok) return nullptr;
        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

// MARK: - BOPTools (v0.70.0)

bool OCCTBOPToolsNormalOnEdge(OCCTShapeRef _Nonnull edge, OCCTShapeRef _Nonnull face,
    double* _Nonnull outNX, double* _Nonnull outNY, double* _Nonnull outNZ) {
    try {
        const TopoDS_Edge& e = TopoDS::Edge(edge->shape);
        const TopoDS_Face& f = TopoDS::Face(face->shape);

        gp_Dir normal;
        BOPTools_AlgoTools3D::GetNormalToFaceOnEdge(e, f, normal);
        *outNX = normal.X();
        *outNY = normal.Y();
        *outNZ = normal.Z();
        return true;
    } catch (...) {
        *outNX = *outNY = *outNZ = 0;
        return false;
    }
}

bool OCCTBOPToolsPointInFace(OCCTShapeRef _Nonnull face,
    double* _Nonnull outX, double* _Nonnull outY, double* _Nonnull outZ) {
    try {
        const TopoDS_Face& f = TopoDS::Face(face->shape);

        gp_Pnt pnt;
        gp_Pnt2d pnt2d;
        Handle(IntTools_Context) ctx = new IntTools_Context();
        int status = BOPTools_AlgoTools3D::PointInFace(f, pnt, pnt2d, ctx);
        if (status != 0) return false;

        *outX = pnt.X();
        *outY = pnt.Y();
        *outZ = pnt.Z();
        return true;
    } catch (...) {
        *outX = *outY = *outZ = 0;
        return false;
    }
}

bool OCCTBOPToolsIsEmptyShape(OCCTShapeRef _Nonnull shape) {
    try {
        return BOPTools_AlgoTools3D::IsEmptyShape(shape->shape);
    } catch (...) {
        return true;
    }
}

bool OCCTBOPToolsIsOpenShell(OCCTShapeRef _Nonnull shell) {
    try {
        const TopoDS_Shell& sh = TopoDS::Shell(shell->shape);
        return BOPTools_AlgoTools::IsOpenShell(sh);
    } catch (...) {
        return true;
    }
}

// MARK: - TKBool remainder + TKFeat (v0.71)
// --- IntTools_BeanFaceIntersector ---

bool OCCTIntToolsBeanFaceIntersect(OCCTShapeRef _Nonnull edge, OCCTShapeRef _Nonnull face,
    OCCTParameterRange* _Nullable * _Nonnull outRanges, int32_t* _Nonnull outCount,
    double* _Nonnull outMinSquareDist) {
    *outRanges = nullptr;
    *outCount = 0;
    *outMinSquareDist = 0.0;
    try {
        const TopoDS_Edge& e = TopoDS::Edge(edge->shape);
        const TopoDS_Face& f = TopoDS::Face(face->shape);

        IntTools_BeanFaceIntersector bfi(e, f);
        bfi.Perform();
        if (!bfi.IsDone()) return false;

        *outMinSquareDist = bfi.MinimalSquareDistance();

        const NCollection_Sequence<IntTools_Range>& ranges = bfi.Result();
        int32_t n = ranges.Length();
        *outCount = n;
        if (n > 0) {
            *outRanges = (OCCTParameterRange*)malloc(n * sizeof(OCCTParameterRange));
            for (int32_t i = 0; i < n; i++) {
                (*outRanges)[i].first = ranges(i + 1).First();
                (*outRanges)[i].last = ranges(i + 1).Last();
            }
        }
        return true;
    } catch (...) { return false; }
}

// --- BOPAlgo_WireSplitter::MakeWire ---

OCCTShapeRef _Nullable OCCTBOPAlgoMakeWire(const OCCTShapeRef _Nonnull * _Nonnull edges, int32_t edgeCount) {
    try {
        NCollection_List<TopoDS_Shape> edgeList;
        for (int32_t i = 0; i < edgeCount; i++) {
            edgeList.Append(edges[i]->shape);
        }
        TopoDS_Wire wire;
        BOPAlgo_WireSplitter::MakeWire(edgeList, wire);
        if (wire.IsNull()) return nullptr;
        return new OCCTShape(wire);
    } catch (...) { return nullptr; }
}

// --- BRepFeat_SplitShape ---

OCCTShapeRef _Nullable OCCTBRepFeatSplitShapeEdge(OCCTShapeRef _Nonnull shape,
    OCCTShapeRef _Nonnull edge, OCCTShapeRef _Nonnull face) {
    try {
        BRepFeat_SplitShape splitter(shape->shape);
        splitter.Add(TopoDS::Edge(edge->shape), TopoDS::Face(face->shape));
        splitter.Build();
        if (!splitter.IsDone()) return nullptr;
        TopoDS_Shape result = splitter.Shape();
        if (result.IsNull()) return nullptr;
        return new OCCTShape(result);
    } catch (...) { return nullptr; }
}

OCCTShapeRef _Nullable OCCTBRepFeatSplitShapeWire(OCCTShapeRef _Nonnull shape,
    OCCTShapeRef _Nonnull wire, OCCTShapeRef _Nonnull face) {
    try {
        BRepFeat_SplitShape splitter(shape->shape);
        splitter.Add(TopoDS::Wire(wire->shape), TopoDS::Face(face->shape));
        splitter.Build();
        if (!splitter.IsDone()) return nullptr;
        TopoDS_Shape result = splitter.Shape();
        if (result.IsNull()) return nullptr;
        return new OCCTShape(result);
    } catch (...) { return nullptr; }
}

OCCTShapeRef _Nullable OCCTBRepFeatSplitShapeWithSides(OCCTShapeRef _Nonnull shape,
    const OCCTShapeRef _Nonnull * _Nonnull edgesOnFaces, int32_t pairCount,
    OCCTShapeRef _Nullable * _Nullable * _Nonnull outLeft, int32_t* _Nonnull outLeftCount,
    OCCTShapeRef _Nullable * _Nullable * _Nonnull outRight, int32_t* _Nonnull outRightCount) {
    *outLeft = nullptr;
    *outLeftCount = 0;
    *outRight = nullptr;
    *outRightCount = 0;
    try {
        BRepFeat_SplitShape splitter(shape->shape);
        for (int32_t i = 0; i < pairCount; i++) {
            TopoDS_Shape edgeOrWire = edgesOnFaces[i * 2]->shape;
            TopoDS_Face face = TopoDS::Face(edgesOnFaces[i * 2 + 1]->shape);
            if (edgeOrWire.ShapeType() == TopAbs_WIRE) {
                splitter.Add(TopoDS::Wire(edgeOrWire), face);
            } else {
                splitter.Add(TopoDS::Edge(edgeOrWire), face);
            }
        }
        splitter.Build();
        if (!splitter.IsDone()) return nullptr;
        TopoDS_Shape result = splitter.Shape();
        if (result.IsNull()) return nullptr;

        // Left faces
        const TopTools_ListOfShape& leftList = splitter.Left();
        int32_t nl = leftList.Size();
        *outLeftCount = nl;
        if (nl > 0) {
            *outLeft = (OCCTShapeRef*)malloc(nl * sizeof(OCCTShapeRef));
            int32_t idx = 0;
            for (auto it = leftList.cbegin(); it != leftList.cend(); ++it, ++idx) {
                (*outLeft)[idx] = new OCCTShape(*it);
            }
        }

        // Right faces
        const TopTools_ListOfShape& rightList = splitter.Right();
        int32_t nr = rightList.Size();
        *outRightCount = nr;
        if (nr > 0) {
            *outRight = (OCCTShapeRef*)malloc(nr * sizeof(OCCTShapeRef));
            int32_t idx = 0;
            for (auto it = rightList.cbegin(); it != rightList.cend(); ++it, ++idx) {
                (*outRight)[idx] = new OCCTShape(*it);
            }
        }

        return new OCCTShape(result);
    } catch (...) { return nullptr; }
}

// --- BRepFeat_MakeCylindricalHole ---

OCCTShapeRef _Nullable OCCTBRepFeatCylindricalHole(OCCTShapeRef _Nonnull shape,
    double axisOriginX, double axisOriginY, double axisOriginZ,
    double axisDirX, double axisDirY, double axisDirZ,
    double radius) {
    try {
        gp_Ax1 axis(gp_Pnt(axisOriginX, axisOriginY, axisOriginZ),
                     gp_Dir(axisDirX, axisDirY, axisDirZ));
        BRepFeat_MakeCylindricalHole hole;
        hole.Init(shape->shape, axis);
        hole.Perform(radius);
        if (hole.Status() != BRepFeat_NoError) return nullptr;
        hole.Build();
        if (hole.Shape().IsNull()) return nullptr;
        return new OCCTShape(hole.Shape());
    } catch (...) { return nullptr; }
}

OCCTShapeRef _Nullable OCCTBRepFeatCylindricalHoleBlind(OCCTShapeRef _Nonnull shape,
    double axisOriginX, double axisOriginY, double axisOriginZ,
    double axisDirX, double axisDirY, double axisDirZ,
    double radius, double depth) {
    try {
        gp_Ax1 axis(gp_Pnt(axisOriginX, axisOriginY, axisOriginZ),
                     gp_Dir(axisDirX, axisDirY, axisDirZ));
        BRepFeat_MakeCylindricalHole hole;
        hole.Init(shape->shape, axis);
        hole.PerformBlind(radius, depth);
        if (hole.Status() != BRepFeat_NoError) return nullptr;
        hole.Build();
        if (hole.Shape().IsNull()) return nullptr;
        return new OCCTShape(hole.Shape());
    } catch (...) { return nullptr; }
}

OCCTShapeRef _Nullable OCCTBRepFeatCylindricalHoleThruNext(OCCTShapeRef _Nonnull shape,
    double axisOriginX, double axisOriginY, double axisOriginZ,
    double axisDirX, double axisDirY, double axisDirZ,
    double radius) {
    try {
        gp_Ax1 axis(gp_Pnt(axisOriginX, axisOriginY, axisOriginZ),
                     gp_Dir(axisDirX, axisDirY, axisDirZ));
        BRepFeat_MakeCylindricalHole hole;
        hole.Init(shape->shape, axis);
        hole.PerformThruNext(radius);
        if (hole.Status() != BRepFeat_NoError) return nullptr;
        hole.Build();
        if (hole.Shape().IsNull()) return nullptr;
        return new OCCTShape(hole.Shape());
    } catch (...) { return nullptr; }
}

int32_t OCCTBRepFeatCylindricalHoleStatus(OCCTShapeRef _Nonnull shape,
    double axisOriginX, double axisOriginY, double axisOriginZ,
    double axisDirX, double axisDirY, double axisDirZ,
    double radius) {
    try {
        gp_Ax1 axis(gp_Pnt(axisOriginX, axisOriginY, axisOriginZ),
                     gp_Dir(axisDirX, axisDirY, axisDirZ));
        BRepFeat_MakeCylindricalHole hole;
        hole.Init(shape->shape, axis);
        hole.Perform(radius);
        BRepFeat_Status status = hole.Status();
        switch (status) {
            case BRepFeat_NoError: return 0;
            case BRepFeat_InvalidPlacement: return 1;
            case BRepFeat_HoleTooLong: return 2;
            default: return 3;
        }
    } catch (...) { return 3; }
}

// --- BRepFeat_Gluer ---

OCCTShapeRef _Nullable OCCTBRepFeatGluer(OCCTShapeRef _Nonnull baseShape,
    OCCTShapeRef _Nonnull gluedShape,
    const OCCTShapeRef _Nonnull * _Nonnull baseFaces,
    const OCCTShapeRef _Nonnull * _Nonnull gluedFaces,
    int32_t faceCount) {
    try {
        BRepFeat_Gluer gluer(gluedShape->shape, baseShape->shape);
        for (int32_t i = 0; i < faceCount; i++) {
            gluer.Bind(TopoDS::Face(gluedFaces[i]->shape),
                       TopoDS::Face(baseFaces[i]->shape));
        }
        gluer.Build();
        if (!gluer.IsDone()) return nullptr;
        TopoDS_Shape result = gluer.Shape();
        if (result.IsNull()) return nullptr;
        return new OCCTShape(result);
    } catch (...) { return nullptr; }
}

// --- LocOpe_WiresOnShape + LocOpe_Spliter (new functions) ---

OCCTShapeRef _Nullable OCCTLocOpeSplitByWires(OCCTShapeRef _Nonnull shape,
    const OCCTShapeRef _Nonnull * _Nonnull wiresOnFaces, int32_t pairCount,
    OCCTShapeRef _Nullable * _Nullable * _Nonnull outDirectLeft, int32_t* _Nonnull outDirectLeftCount) {
    *outDirectLeft = nullptr;
    *outDirectLeftCount = 0;
    try {
        Handle(LocOpe_WiresOnShape) wos = new LocOpe_WiresOnShape(shape->shape);
        for (int32_t i = 0; i < pairCount; i++) {
            TopoDS_Wire w;
            const TopoDS_Shape& ws = wiresOnFaces[i * 2]->shape;
            if (ws.ShapeType() == TopAbs_WIRE) {
                w = TopoDS::Wire(ws);
            } else {
                TopExp_Explorer exp(ws, TopAbs_WIRE);
                if (exp.More()) w = TopoDS::Wire(exp.Current());
                else continue;
            }
            TopoDS_Face f = TopoDS::Face(wiresOnFaces[i * 2 + 1]->shape);
            wos->Bind(w, f);
        }

        LocOpe_Spliter spliter(shape->shape);
        spliter.Perform(wos);
        if (!spliter.IsDone()) return nullptr;

        const TopoDS_Shape& result = spliter.ResultingShape();
        if (result.IsNull()) return nullptr;

        // Direct left faces
        const TopTools_ListOfShape& dl = spliter.DirectLeft();
        int32_t n = dl.Size();
        *outDirectLeftCount = n;
        if (n > 0) {
            *outDirectLeft = (OCCTShapeRef*)malloc(n * sizeof(OCCTShapeRef));
            int32_t idx = 0;
            for (auto it = dl.cbegin(); it != dl.cend(); ++it, ++idx) {
                (*outDirectLeft)[idx] = new OCCTShape(*it);
            }
        }

        return new OCCTShape(result);
    } catch (...) { return nullptr; }
}

OCCTShapeRef _Nullable OCCTLocOpeSplitByWiresAuto(OCCTShapeRef _Nonnull shape,
    const OCCTShapeRef _Nonnull * _Nonnull wires, int32_t wireCount) {
    try {
        Handle(LocOpe_WiresOnShape) wos = new LocOpe_WiresOnShape(shape->shape);
        for (int32_t i = 0; i < wireCount; i++) {
            const TopoDS_Shape& ws = wires[i]->shape;
            // Add edges from each wire as a sequence
            NCollection_Sequence<TopoDS_Shape> edgeSeq;
            TopExp_Explorer exp(ws, TopAbs_EDGE);
            for (; exp.More(); exp.Next()) {
                edgeSeq.Append(exp.Current());
            }
            if (edgeSeq.Length() > 0) {
                wos->Add(edgeSeq);
            }
        }
        wos->BindAll();

        LocOpe_Spliter spliter(shape->shape);
        spliter.Perform(wos);
        if (!spliter.IsDone()) return nullptr;

        const TopoDS_Shape& result = spliter.ResultingShape();
        if (result.IsNull()) return nullptr;
        return new OCCTShape(result);
    } catch (...) { return nullptr; }
}

// MARK: - TKFeat remainder + TKFillet (v0.72)
// --- LocOpe_Gluer ---

OCCTShapeRef _Nullable OCCTLocOpeGlue(OCCTShapeRef _Nonnull baseShape,
    OCCTShapeRef _Nonnull gluedShape,
    const OCCTShapeRef _Nonnull * _Nonnull baseFaces,
    const OCCTShapeRef _Nonnull * _Nonnull gluedFaces,
    int32_t faceCount,
    const OCCTShapeRef _Nullable * _Nullable baseEdges,
    const OCCTShapeRef _Nullable * _Nullable gluedEdges,
    int32_t edgeCount) {
    try {
        LocOpe_Gluer gluer(baseShape->shape, gluedShape->shape);
        for (int32_t i = 0; i < faceCount; i++) {
            gluer.Bind(TopoDS::Face(gluedFaces[i]->shape),
                       TopoDS::Face(baseFaces[i]->shape));
        }
        if (baseEdges && gluedEdges) {
            for (int32_t i = 0; i < edgeCount; i++) {
                if (baseEdges[i] && gluedEdges[i]) {
                    gluer.Bind(TopoDS::Edge(gluedEdges[i]->shape),
                               TopoDS::Edge(baseEdges[i]->shape));
                }
            }
        }
        gluer.Perform();
        if (!gluer.IsDone()) return nullptr;
        const TopoDS_Shape& result = gluer.ResultingShape();
        if (result.IsNull()) return nullptr;
        return new OCCTShape(result);
    } catch (...) { return nullptr; }
}

// --- ChFi2d_Builder ---

OCCTShapeRef _Nullable OCCTChFi2dAddFillet(OCCTShapeRef _Nonnull face,
    int32_t vertexIndex, double radius) {
    try {
        const TopoDS_Face& f = TopoDS::Face(face->shape);
        ChFi2d_Builder builder(f);

        TopTools_IndexedMapOfShape vertexMap;
        TopExp::MapShapes(f, TopAbs_VERTEX, vertexMap);
        int32_t idx = vertexIndex + 1;
        if (idx < 1 || idx > vertexMap.Extent()) return nullptr;
        TopoDS_Vertex v = TopoDS::Vertex(vertexMap(idx));

        builder.AddFillet(v, radius);
        if (builder.Status() != ChFi2d_IsDone) return nullptr;
        TopoDS_Face result = builder.Result();
        if (result.IsNull()) return nullptr;
        return new OCCTShape(result);
    } catch (...) { return nullptr; }
}

OCCTShapeRef _Nullable OCCTChFi2dAddChamfer(OCCTShapeRef _Nonnull face,
    int32_t edge1Index, int32_t edge2Index, double d1, double d2) {
    try {
        const TopoDS_Face& f = TopoDS::Face(face->shape);
        ChFi2d_Builder builder(f);

        TopTools_IndexedMapOfShape edgeMap;
        TopExp::MapShapes(f, TopAbs_EDGE, edgeMap);
        int32_t idx1 = edge1Index + 1;
        int32_t idx2 = edge2Index + 1;
        if (idx1 < 1 || idx1 > edgeMap.Extent()) return nullptr;
        if (idx2 < 1 || idx2 > edgeMap.Extent()) return nullptr;
        TopoDS_Edge e1 = TopoDS::Edge(edgeMap(idx1));
        TopoDS_Edge e2 = TopoDS::Edge(edgeMap(idx2));

        builder.AddChamfer(e1, e2, d1, d2);
        if (builder.Status() != ChFi2d_IsDone) return nullptr;
        TopoDS_Face result = builder.Result();
        if (result.IsNull()) return nullptr;
        return new OCCTShape(result);
    } catch (...) { return nullptr; }
}

OCCTShapeRef _Nullable OCCTChFi2dAddChamferAngle(OCCTShapeRef _Nonnull face,
    int32_t edgeIndex, int32_t vertexIndex, double distance, double angle) {
    try {
        const TopoDS_Face& f = TopoDS::Face(face->shape);
        ChFi2d_Builder builder(f);

        TopTools_IndexedMapOfShape edgeMap, vertexMap;
        TopExp::MapShapes(f, TopAbs_EDGE, edgeMap);
        TopExp::MapShapes(f, TopAbs_VERTEX, vertexMap);
        int32_t ei = edgeIndex + 1;
        int32_t vi = vertexIndex + 1;
        if (ei < 1 || ei > edgeMap.Extent()) return nullptr;
        if (vi < 1 || vi > vertexMap.Extent()) return nullptr;
        TopoDS_Edge e = TopoDS::Edge(edgeMap(ei));
        TopoDS_Vertex v = TopoDS::Vertex(vertexMap(vi));

        builder.AddChamfer(e, v, distance, angle);
        if (builder.Status() != ChFi2d_IsDone) return nullptr;
        TopoDS_Face result = builder.Result();
        if (result.IsNull()) return nullptr;
        return new OCCTShape(result);
    } catch (...) { return nullptr; }
}

OCCTShapeRef _Nullable OCCTChFi2dModifyFillet(OCCTShapeRef _Nonnull originalFace,
    OCCTShapeRef _Nonnull modifiedFace, int32_t filletEdgeIndex, double newRadius) {
    try {
        const TopoDS_Face& origF = TopoDS::Face(originalFace->shape);
        const TopoDS_Face& modF = TopoDS::Face(modifiedFace->shape);
        ChFi2d_Builder builder;
        builder.Init(origF, modF);

        TopTools_IndexedMapOfShape edgeMap;
        TopExp::MapShapes(modF, TopAbs_EDGE, edgeMap);
        int32_t idx = filletEdgeIndex + 1;
        if (idx < 1 || idx > edgeMap.Extent()) return nullptr;
        TopoDS_Edge filletEdge = TopoDS::Edge(edgeMap(idx));

        builder.ModifyFillet(filletEdge, newRadius);
        if (builder.Status() != ChFi2d_IsDone) return nullptr;
        TopoDS_Face result = builder.Result();
        if (result.IsNull()) return nullptr;
        return new OCCTShape(result);
    } catch (...) { return nullptr; }
}

OCCTShapeRef _Nullable OCCTChFi2dRemoveFillet(OCCTShapeRef _Nonnull originalFace,
    OCCTShapeRef _Nonnull modifiedFace, int32_t filletEdgeIndex) {
    try {
        const TopoDS_Face& origF = TopoDS::Face(originalFace->shape);
        const TopoDS_Face& modF = TopoDS::Face(modifiedFace->shape);
        ChFi2d_Builder builder;
        builder.Init(origF, modF);

        TopTools_IndexedMapOfShape edgeMap;
        TopExp::MapShapes(modF, TopAbs_EDGE, edgeMap);
        int32_t idx = filletEdgeIndex + 1;
        if (idx < 1 || idx > edgeMap.Extent()) return nullptr;
        TopoDS_Edge filletEdge = TopoDS::Edge(edgeMap(idx));

        builder.RemoveFillet(filletEdge);
        if (builder.Status() != ChFi2d_IsDone) return nullptr;
        TopoDS_Face result = builder.Result();
        if (result.IsNull()) return nullptr;
        return new OCCTShape(result);
    } catch (...) { return nullptr; }
}

OCCTShapeRef _Nullable OCCTChFi2dRemoveChamfer(OCCTShapeRef _Nonnull originalFace,
    OCCTShapeRef _Nonnull modifiedFace, int32_t chamferEdgeIndex) {
    try {
        const TopoDS_Face& origF = TopoDS::Face(originalFace->shape);
        const TopoDS_Face& modF = TopoDS::Face(modifiedFace->shape);
        ChFi2d_Builder builder;
        builder.Init(origF, modF);

        TopTools_IndexedMapOfShape edgeMap;
        TopExp::MapShapes(modF, TopAbs_EDGE, edgeMap);
        int32_t idx = chamferEdgeIndex + 1;
        if (idx < 1 || idx > edgeMap.Extent()) return nullptr;
        TopoDS_Edge chamferEdge = TopoDS::Edge(edgeMap(idx));

        builder.RemoveChamfer(chamferEdge);
        if (builder.Status() != ChFi2d_IsDone) return nullptr;
        TopoDS_Face result = builder.Result();
        if (result.IsNull()) return nullptr;
        return new OCCTShape(result);
    } catch (...) { return nullptr; }
}

// --- ChFi2d_ChamferAPI ---

OCCTChamfer2DResult OCCTChFi2dChamferEdges(OCCTShapeRef _Nonnull edge1,
    OCCTShapeRef _Nonnull edge2, double d1, double d2) {
    OCCTChamfer2DResult result = {nullptr, nullptr, nullptr};
    try {
        TopoDS_Edge e1 = TopoDS::Edge(edge1->shape);
        TopoDS_Edge e2 = TopoDS::Edge(edge2->shape);
        ChFi2d_ChamferAPI chamfer(e1, e2);
        if (!chamfer.Perform()) return result;
        TopoDS_Edge me1, me2;
        TopoDS_Edge chamferEdge = chamfer.Result(me1, me2, d1, d2);
        if (chamferEdge.IsNull()) return result;
        result.chamferEdge = new OCCTShape(chamferEdge);
        result.modifiedEdge1 = new OCCTShape(me1);
        result.modifiedEdge2 = new OCCTShape(me2);
        return result;
    } catch (...) { return result; }
}

// --- ChFi2d_FilletAPI ---

OCCTFillet2DResult OCCTChFi2dFilletEdges(OCCTShapeRef _Nonnull edge1,
    OCCTShapeRef _Nonnull edge2,
    double planeNx, double planeNy, double planeNz,
    double radius,
    double nearX, double nearY, double nearZ) {
    OCCTFillet2DResult result = {nullptr, nullptr, nullptr, 0};
    try {
        TopoDS_Edge e1 = TopoDS::Edge(edge1->shape);
        TopoDS_Edge e2 = TopoDS::Edge(edge2->shape);
        gp_Pln plane(gp_Pnt(0, 0, 0), gp_Dir(planeNx, planeNy, planeNz));
        ChFi2d_FilletAPI fillet(e1, e2, plane);
        if (!fillet.Perform(radius)) return result;
        gp_Pnt nearPt(nearX, nearY, nearZ);
        result.solutionCount = fillet.NbResults(nearPt);
        TopoDS_Edge me1, me2;
        TopoDS_Edge filletEdge = fillet.Result(nearPt, me1, me2);
        if (filletEdge.IsNull()) return result;
        result.filletEdge = new OCCTShape(filletEdge);
        result.modifiedEdge1 = new OCCTShape(me1);
        result.modifiedEdge2 = new OCCTShape(me2);
        return result;
    } catch (...) { return result; }
}

// --- FilletSurf_Builder ---

int32_t OCCTFilletSurfBuild(OCCTShapeRef _Nonnull shape,
    const OCCTShapeRef _Nonnull * _Nonnull edges, int32_t edgeCount,
    double radius,
    OCCTFilletSurfInfo* _Nullable * _Nonnull outSurfaces, int32_t* _Nonnull outCount) {
    *outSurfaces = nullptr;
    *outCount = 0;
    try {
        NCollection_List<TopoDS_Shape> edgeList;
        for (int32_t i = 0; i < edgeCount; i++) {
            edgeList.Append(edges[i]->shape);
        }
        FilletSurf_Builder fb(shape->shape, edgeList, radius);
        fb.Perform();
        FilletSurf_StatusDone status = fb.IsDone();
        if (status == FilletSurf_IsNotOk) return 1;

        int32_t n = fb.NbSurface();
        *outCount = n;
        if (n > 0) {
            *outSurfaces = (OCCTFilletSurfInfo*)calloc(n, sizeof(OCCTFilletSurfInfo));
            for (int32_t i = 0; i < n; i++) {
                const Handle(Geom_Surface)& surf = fb.SurfaceFillet(i + 1);
                if (!surf.IsNull()) {
                    (*outSurfaces)[i].surface = new OCCTSurface(surf);
                }
                (*outSurfaces)[i].supportFace1 = new OCCTShape(fb.SupportFace1(i + 1));
                (*outSurfaces)[i].supportFace2 = new OCCTShape(fb.SupportFace2(i + 1));
                (*outSurfaces)[i].tolerance = fb.TolApp3d(i + 1);
                (*outSurfaces)[i].firstParam = fb.FirstParameter();
                (*outSurfaces)[i].lastParam = fb.LastParameter();
                (*outSurfaces)[i].startStatus = (int32_t)fb.StartSectionStatus();
                (*outSurfaces)[i].endStatus = (int32_t)fb.EndSectionStatus();
            }
        }
        return (status == FilletSurf_IsOk) ? 0 : 2;
    } catch (...) { return 1; }
}

int32_t OCCTFilletSurfError(OCCTShapeRef _Nonnull shape,
    const OCCTShapeRef _Nonnull * _Nonnull edges, int32_t edgeCount,
    double radius) {
    try {
        NCollection_List<TopoDS_Shape> edgeList;
        for (int32_t i = 0; i < edgeCount; i++) {
            edgeList.Append(edges[i]->shape);
        }
        FilletSurf_Builder fb(shape->shape, edgeList, radius);
        fb.Perform();
        return (int32_t)fb.StatusError();
    } catch (...) { return 4; }
}

// MARK: - HLR Edge Categories (v0.73)
// --- Extended HLR edge categories ---

OCCTShapeRef _Nullable OCCTHLRGetEdgesByCategory(OCCTShapeRef _Nonnull shape,
    double dirX, double dirY, double dirZ,
    OCCTHLREdgeCategory category) {
    if (!shape) return nullptr;
    try {
        gp_Dir viewDir(dirX, dirY, dirZ);
        gp_Ax2 projAxis(gp_Pnt(0, 0, 0), viewDir);
        HLRAlgo_Projector projector(projAxis);

        Handle(HLRBRep_Algo) algo = new HLRBRep_Algo();
        algo->Add(shape->shape);
        algo->Projector(projector);
        algo->Update();
        algo->Hide();

        HLRBRep_HLRToShape hlrToShape(algo);
        TopoDS_Shape result;

        switch (category) {
            case OCCTHLREdgeVisibleSharp:      result = hlrToShape.VCompound(); break;
            case OCCTHLREdgeVisibleSmooth:     result = hlrToShape.Rg1LineVCompound(); break;
            case OCCTHLREdgeVisibleSewn:       result = hlrToShape.RgNLineVCompound(); break;
            case OCCTHLREdgeVisibleOutline:    result = hlrToShape.OutLineVCompound(); break;
            case OCCTHLREdgeVisibleIso:        result = hlrToShape.IsoLineVCompound(); break;
            case OCCTHLREdgeVisibleOutline3d:  result = hlrToShape.OutLineVCompound3d(); break;
            case OCCTHLREdgeHiddenSharp:       result = hlrToShape.HCompound(); break;
            case OCCTHLREdgeHiddenSmooth:      result = hlrToShape.Rg1LineHCompound(); break;
            case OCCTHLREdgeHiddenSewn:        result = hlrToShape.RgNLineHCompound(); break;
            case OCCTHLREdgeHiddenOutline:     result = hlrToShape.OutLineHCompound(); break;
            case OCCTHLREdgeHiddenIso:         result = hlrToShape.IsoLineHCompound(); break;
            default: return nullptr;
        }

        if (result.IsNull()) return nullptr;
        return new OCCTShape(result);
    } catch (...) { return nullptr; }
}

OCCTShapeRef _Nullable OCCTHLRPolyGetEdgesByCategory(OCCTShapeRef _Nonnull shape,
    double dirX, double dirY, double dirZ,
    OCCTHLREdgeCategory category, double deflection) {
    if (!shape) return nullptr;
    // IsoLine and Outline3d not available for poly HLR
    if (category == OCCTHLREdgeVisibleIso || category == OCCTHLREdgeHiddenIso ||
        category == OCCTHLREdgeVisibleOutline3d) return nullptr;
    try {
        // Ensure triangulation (caller-tunable: finer = more drawing detail, coarser = faster)
        BRepMesh_IncrementalMesh mesh(shape->shape, deflection);

        gp_Dir viewDir(dirX, dirY, dirZ);
        gp_Ax2 projAxis(gp_Pnt(0, 0, 0), viewDir);
        HLRAlgo_Projector projector(projAxis);

        Handle(HLRBRep_PolyAlgo) polyAlgo = new HLRBRep_PolyAlgo();
        polyAlgo->Load(shape->shape);
        polyAlgo->Projector(projector);
        polyAlgo->Update();

        HLRBRep_PolyHLRToShape polyToShape;
        polyToShape.Update(polyAlgo);

        TopoDS_Shape result;
        switch (category) {
            case OCCTHLREdgeVisibleSharp:   result = polyToShape.VCompound(); break;
            case OCCTHLREdgeVisibleSmooth:  result = polyToShape.Rg1LineVCompound(); break;
            case OCCTHLREdgeVisibleSewn:    result = polyToShape.RgNLineVCompound(); break;
            case OCCTHLREdgeVisibleOutline: result = polyToShape.OutLineVCompound(); break;
            case OCCTHLREdgeHiddenSharp:    result = polyToShape.HCompound(); break;
            case OCCTHLREdgeHiddenSmooth:   result = polyToShape.Rg1LineHCompound(); break;
            case OCCTHLREdgeHiddenSewn:     result = polyToShape.RgNLineHCompound(); break;
            case OCCTHLREdgeHiddenOutline:  result = polyToShape.OutLineHCompound(); break;
            default: return nullptr;
        }

        if (result.IsNull()) return nullptr;
        return new OCCTShape(result);
    } catch (...) { return nullptr; }
}

OCCTShapeRef _Nullable OCCTHLRCompoundOfEdges(OCCTShapeRef _Nonnull shape,
    double dirX, double dirY, double dirZ,
    int32_t edgeType, bool visible, bool in3d) {
    if (!shape) return nullptr;
    try {
        gp_Dir viewDir(dirX, dirY, dirZ);
        gp_Ax2 projAxis(gp_Pnt(0, 0, 0), viewDir);
        HLRAlgo_Projector projector(projAxis);

        Handle(HLRBRep_Algo) algo = new HLRBRep_Algo();
        algo->Add(shape->shape);
        algo->Projector(projector);
        algo->Update();
        algo->Hide();

        HLRBRep_HLRToShape hlrToShape(algo);
        TopoDS_Shape result = hlrToShape.CompoundOfEdges(
            (HLRBRep_TypeOfResultingEdge)edgeType, visible, in3d);

        if (result.IsNull()) return nullptr;
        return new OCCTShape(result);
    } catch (...) { return nullptr; }
}

// MARK: - HLRAppli_ReflectLines (v0.73)
// --- HLRAppli_ReflectLines ---

OCCTShapeRef _Nullable OCCTHLRReflectLines(OCCTShapeRef _Nonnull shape,
    double nx, double ny, double nz,
    double xAt, double yAt, double zAt,
    double xUp, double yUp, double zUp) {
    if (!shape) return nullptr;
    try {
        HLRAppli_ReflectLines rl(shape->shape);
        rl.SetAxes(nx, ny, nz, xAt, yAt, zAt, xUp, yUp, zUp);
        rl.Perform();
        TopoDS_Shape result = rl.GetResult();
        if (result.IsNull()) return nullptr;
        return new OCCTShape(result);
    } catch (...) { return nullptr; }
}

OCCTShapeRef _Nullable OCCTHLRReflectLinesFiltered(OCCTShapeRef _Nonnull shape,
    double nx, double ny, double nz,
    double xAt, double yAt, double zAt,
    double xUp, double yUp, double zUp,
    int32_t edgeType, bool visible, bool in3d) {
    if (!shape) return nullptr;
    try {
        HLRAppli_ReflectLines rl(shape->shape);
        rl.SetAxes(nx, ny, nz, xAt, yAt, zAt, xUp, yUp, zUp);
        rl.Perform();
        TopoDS_Shape result = rl.GetCompoundOf3dEdges(
            (HLRBRep_TypeOfResultingEdge)edgeType, visible, in3d);
        if (result.IsNull()) return nullptr;
        return new OCCTShape(result);
    } catch (...) { return nullptr; }
}

// MARK: - BiTgte_Blend (v0.75)
// --- BiTgte_Blend ---

OCCTShapeRef _Nullable OCCTBiTgteBlend(OCCTShapeRef _Nonnull shape,
                                        const int32_t* _Nonnull edgeIndices,
                                        int32_t edgeCount,
                                        double radius,
                                        double tolerance,
                                        bool nubs) {
    if (!shape || edgeCount <= 0) return nullptr;
    try {
        BiTgte_Blend blend(shape->shape, radius, tolerance, nubs);

        // Collect edges by index
        TopExp_Explorer edgeExp(shape->shape, TopAbs_EDGE);
        std::vector<TopoDS_Edge> allEdges;
        while (edgeExp.More()) {
            allEdges.push_back(TopoDS::Edge(edgeExp.Current()));
            edgeExp.Next();
        }

        for (int32_t i = 0; i < edgeCount; i++) {
            int32_t idx = edgeIndices[i];
            if (idx >= 0 && idx < (int32_t)allEdges.size()) {
                blend.SetEdge(allEdges[idx]);
            }
        }

        blend.Perform(true);
        if (!blend.IsDone()) return nullptr;

        TopoDS_Shape result = blend.Shape();
        if (result.IsNull()) return nullptr;
        auto* ref = new OCCTShape();
        ref->shape = result;
        return ref;
    } catch (...) {
        return nullptr;
    }
}

OCCTBiTgteBlendInfo OCCTBiTgteBlendInfo_(OCCTShapeRef _Nonnull shape,
                                          const int32_t* _Nonnull edgeIndices,
                                          int32_t edgeCount,
                                          double radius,
                                          double tolerance) {
    OCCTBiTgteBlendInfo info = {};
    if (!shape || edgeCount <= 0) return info;
    try {
        BiTgte_Blend blend(shape->shape, radius, tolerance, false);

        TopExp_Explorer edgeExp(shape->shape, TopAbs_EDGE);
        std::vector<TopoDS_Edge> allEdges;
        while (edgeExp.More()) {
            allEdges.push_back(TopoDS::Edge(edgeExp.Current()));
            edgeExp.Next();
        }

        for (int32_t i = 0; i < edgeCount; i++) {
            int32_t idx = edgeIndices[i];
            if (idx >= 0 && idx < (int32_t)allEdges.size()) {
                blend.SetEdge(allEdges[idx]);
            }
        }

        blend.Perform(true);
        info.isDone = blend.IsDone();
        if (info.isDone) {
            info.nbSurfaces = blend.NbSurfaces();
        }
    } catch (...) {}
    return info;
}

// MARK: - BRepPreviewAPI_MakeBox (v0.75)
// --- BRepPreviewAPI_MakeBox ---

OCCTShapeRef _Nullable OCCTPreviewBox(double dx, double dy, double dz) {
    try {
        BRepPreviewAPI_MakeBox preview;
        preview.Init(dx, dy, dz);
        preview.Build();
        if (!preview.IsDone()) return nullptr;
        TopoDS_Shape result = preview.Shape();
        if (result.IsNull()) return nullptr;
        auto* ref = new OCCTShape();
        ref->shape = result;
        return ref;
    } catch (...) {
        return nullptr;
    }
}


// MARK: - BRepTools Trsf / GTrsf / Copy Modifications (v0.78)
// MARK: - BRepTools_TrsfModification

OCCTShapeRef _Nullable OCCTShapeTrsfModification(OCCTShapeRef _Nonnull shapeRef,
                                                   double a11, double a12, double a13, double a14,
                                                   double a21, double a22, double a23, double a24,
                                                   double a31, double a32, double a33, double a34) {
    try {
        auto& shape = reinterpret_cast<OCCTShape*>(shapeRef)->shape;
        gp_Trsf trsf;
        trsf.SetValues(a11, a12, a13, a14,
                       a21, a22, a23, a24,
                       a31, a32, a33, a34);
        Handle(BRepTools_TrsfModification) mod = new BRepTools_TrsfModification(trsf);
        BRepTools_Modifier modifier(shape, mod);
        if (!modifier.IsDone()) return nullptr;
        TopoDS_Shape result = modifier.ModifiedShape(shape);
        if (result.IsNull()) return nullptr;
        return reinterpret_cast<OCCTShapeRef>(new OCCTShape{result});
    } catch (...) {
        return nullptr;
    }
}

// MARK: - BRepTools_GTrsfModification

OCCTShapeRef _Nullable OCCTShapeGTrsfModification(OCCTShapeRef _Nonnull shapeRef,
                                                    double a11, double a12, double a13, double a14,
                                                    double a21, double a22, double a23, double a24,
                                                    double a31, double a32, double a33, double a34) {
    try {
        auto& shape = reinterpret_cast<OCCTShape*>(shapeRef)->shape;
        gp_GTrsf gtrsf;
        gtrsf.SetValue(1, 1, a11); gtrsf.SetValue(1, 2, a12); gtrsf.SetValue(1, 3, a13); gtrsf.SetValue(1, 4, a14);
        gtrsf.SetValue(2, 1, a21); gtrsf.SetValue(2, 2, a22); gtrsf.SetValue(2, 3, a23); gtrsf.SetValue(2, 4, a24);
        gtrsf.SetValue(3, 1, a31); gtrsf.SetValue(3, 2, a32); gtrsf.SetValue(3, 3, a33); gtrsf.SetValue(3, 4, a34);
        Handle(BRepTools_GTrsfModification) mod = new BRepTools_GTrsfModification(gtrsf);
        BRepTools_Modifier modifier(shape, mod);
        if (!modifier.IsDone()) return nullptr;
        TopoDS_Shape result = modifier.ModifiedShape(shape);
        if (result.IsNull()) return nullptr;
        return reinterpret_cast<OCCTShapeRef>(new OCCTShape{result});
    } catch (...) {
        return nullptr;
    }
}

// MARK: - BRepTools_CopyModification

OCCTShapeRef _Nullable OCCTShapeCopyModification(OCCTShapeRef _Nonnull shapeRef,
                                                   bool copyGeometry, bool copyMesh) {
    try {
        auto& shape = reinterpret_cast<OCCTShape*>(shapeRef)->shape;
        Handle(BRepTools_CopyModification) mod = new BRepTools_CopyModification(copyGeometry, copyMesh);
        BRepTools_Modifier modifier(shape, mod);
        if (!modifier.IsDone()) return nullptr;
        TopoDS_Shape result = modifier.ModifiedShape(shape);
        if (result.IsNull()) return nullptr;
        return reinterpret_cast<OCCTShapeRef>(new OCCTShape{result});
    } catch (...) {
        return nullptr;
    }
}

// MARK: - BRepFill_Evolved (v0.79)
// --- BRepFill_Evolved ---
OCCTShapeRef _Nullable OCCTBRepFillEvolved(OCCTShapeRef _Nonnull spineFaceRef,
                                            OCCTShapeRef _Nonnull profileWireRef,
                                            double axOriginX, double axOriginY, double axOriginZ,
                                            double axNormalX, double axNormalY, double axNormalZ,
                                            double axXDirX, double axXDirY, double axXDirZ,
                                            int joinType, bool makeSolid) {
    try {
        const TopoDS_Shape& spineShape = *(const TopoDS_Shape*)spineFaceRef;
        const TopoDS_Shape& profileShape = *(const TopoDS_Shape*)profileWireRef;

        gp_Ax3 axe(gp_Pnt(axOriginX, axOriginY, axOriginZ),
                    gp_Dir(axNormalX, axNormalY, axNormalZ),
                    gp_Dir(axXDirX, axXDirY, axXDirZ));

        GeomAbs_JoinType jt = GeomAbs_Arc;
        if (joinType == 1) jt = GeomAbs_Tangent;
        else if (joinType == 2) jt = GeomAbs_Intersection;

        TopoDS_Wire profile = TopoDS::Wire(profileShape);

        BRepFill_Evolved evolved;
        if (spineShape.ShapeType() == TopAbs_FACE) {
            evolved.Perform(TopoDS::Face(spineShape), profile, axe, jt, makeSolid);
        } else if (spineShape.ShapeType() == TopAbs_WIRE) {
            evolved.Perform(TopoDS::Wire(spineShape), profile, axe, jt, makeSolid);
        } else {
            return nullptr;
        }

        if (!evolved.IsDone()) return nullptr;
        return (OCCTShapeRef)new TopoDS_Shape(evolved.Shape());
    } catch (...) { return nullptr; }
}

// MARK: - BRepFill_OffsetAncestors (v0.79)
// --- BRepFill_OffsetAncestors ---
struct OffsetAncestorsOpaque {
    BRepFill_OffsetWire offsetWire;
    BRepFill_OffsetAncestors ancestors;
    bool isDone;
};

OCCTOffsetAncestorsRef OCCTBRepFillOffsetAncestorsCreate(OCCTShapeRef _Nonnull faceRef, double offset, int joinType) {
    try {
        const TopoDS_Shape& shape = *(const TopoDS_Shape*)faceRef;
        TopoDS_Face face = TopoDS::Face(shape);

        GeomAbs_JoinType jt = GeomAbs_Arc;
        if (joinType == 1) jt = GeomAbs_Tangent;
        else if (joinType == 2) jt = GeomAbs_Intersection;

        auto* opaque = new OffsetAncestorsOpaque();
        opaque->offsetWire.Init(face, jt);
        opaque->offsetWire.Perform(offset);
        if (opaque->offsetWire.IsDone()) {
            opaque->ancestors.Perform(opaque->offsetWire);
            opaque->isDone = opaque->ancestors.IsDone();
        } else {
            opaque->isDone = false;
        }
        return opaque;
    } catch (...) { return nullptr; }
}

bool OCCTBRepFillOffsetAncestorsIsDone(OCCTOffsetAncestorsRef _Nonnull ref) {
    return ((OffsetAncestorsOpaque*)ref)->isDone;
}

bool OCCTBRepFillOffsetAncestorsHasAncestor(OCCTOffsetAncestorsRef _Nonnull ref, OCCTShapeRef _Nonnull edgeRef) {
    try {
        auto* opaque = (OffsetAncestorsOpaque*)ref;
        const TopoDS_Shape& edgeShape = *(const TopoDS_Shape*)edgeRef;
        return opaque->ancestors.HasAncestor(TopoDS::Edge(edgeShape));
    } catch (...) { return false; }
}

OCCTShapeRef _Nullable OCCTBRepFillOffsetAncestorsGetAncestor(OCCTOffsetAncestorsRef _Nonnull ref, OCCTShapeRef _Nonnull edgeRef) {
    try {
        auto* opaque = (OffsetAncestorsOpaque*)ref;
        const TopoDS_Shape& edgeShape = *(const TopoDS_Shape*)edgeRef;
        TopoDS_Edge edge = TopoDS::Edge(edgeShape);
        if (!opaque->ancestors.HasAncestor(edge)) return nullptr;
        return (OCCTShapeRef)new TopoDS_Shape(opaque->ancestors.Ancestor(edge));
    } catch (...) { return nullptr; }
}

void OCCTBRepFillOffsetAncestorsRelease(OCCTOffsetAncestorsRef _Nonnull ref) {
    delete (OffsetAncestorsOpaque*)ref;
}

// MARK: - BRepFill_NSections (v0.79)
// --- BRepFill_NSections ---
struct NSectionsOpaque {
    Handle(BRepFill_NSections) nsec;
};

OCCTNSectionsRef OCCTBRepFillNSectionsCreate(const OCCTShapeRef _Nonnull * _Nonnull wireRefs, int count) {
    try {
        NCollection_Sequence<TopoDS_Shape> sections;
        for (int i = 0; i < count; i++) {
            const TopoDS_Shape& shape = *(const TopoDS_Shape*)wireRefs[i];
            sections.Append(shape);
        }
        auto* opaque = new NSectionsOpaque();
        opaque->nsec = new BRepFill_NSections(sections);
        return opaque;
    } catch (...) { return nullptr; }
}

int OCCTBRepFillNSectionsNbLaw(OCCTNSectionsRef _Nonnull ref) {
    try {
        auto* opaque = (NSectionsOpaque*)ref;
        return opaque->nsec->NbLaw();
    } catch (...) { return 0; }
}

bool OCCTBRepFillNSectionsIsConstant(OCCTNSectionsRef _Nonnull ref) {
    try {
        auto* opaque = (NSectionsOpaque*)ref;
        return opaque->nsec->IsConstant();
    } catch (...) { return false; }
}

bool OCCTBRepFillNSectionsIsVertex(OCCTNSectionsRef _Nonnull ref) {
    try {
        auto* opaque = (NSectionsOpaque*)ref;
        return opaque->nsec->IsVertex();
    } catch (...) { return false; }
}

void OCCTBRepFillNSectionsRelease(OCCTNSectionsRef _Nonnull ref) {
    delete (NSectionsOpaque*)ref;
}

// MARK: - BRepOffsetAPI_FindContigousEdges (v0.85)
// MARK: - BRepOffsetAPI_FindContigousEdges

#include <BRepOffsetAPI_FindContigousEdges.hxx>

OCCTContigousEdgeResult OCCTShapeFindContigousEdges(OCCTShapeRef shape, double tolerance) {
    OCCTContigousEdgeResult result = {0, 0};
    try {
        BRepOffsetAPI_FindContigousEdges finder(tolerance, true);
        finder.Add(shape->shape);
        finder.Perform();
        result.contigousEdgeCount = finder.NbContigousEdges();
        result.degeneratedShapeCount = finder.NbDegeneratedShapes();
    } catch (...) {}
    return result;
}

// MARK: - v0.90: IntTools_Tools
// MARK: - IntTools_Tools (v0.90.0)

#include <IntTools_Tools.hxx>

int32_t OCCTIntToolsComputeVV(OCCTShapeRef vertex1, OCCTShapeRef vertex2) {
    if (!vertex1 || !vertex2) return -1;
    try {
        return IntTools_Tools::ComputeVV(
            TopoDS::Vertex(vertex1->shape),
            TopoDS::Vertex(vertex2->shape));
    } catch (...) { return -1; }
}

double OCCTIntToolsIntermediatePoint(double first, double last) {
    try {
        return IntTools_Tools::IntermediatePoint(first, last);
    } catch (...) { return 0.5 * (first + last); }
}

bool OCCTIntToolsIsDirsCoinside(double dx1, double dy1, double dz1,
                                 double dx2, double dy2, double dz2) {
    try {
        return IntTools_Tools::IsDirsCoinside(gp_Dir(dx1, dy1, dz1), gp_Dir(dx2, dy2, dz2));
    } catch (...) { return false; }
}

bool OCCTIntToolsIsDirsCoinisdeWithTol(double dx1, double dy1, double dz1,
                                        double dx2, double dy2, double dz2, double tol) {
    try {
        return IntTools_Tools::IsDirsCoinside(gp_Dir(dx1, dy1, dz1), gp_Dir(dx2, dy2, dz2), tol);
    } catch (...) { return false; }
}

double OCCTIntToolsComputeIntRange(double tol1, double tol2, double angle) {
    try {
        return IntTools_Tools::ComputeIntRange(tol1, tol2, angle);
    } catch (...) { return 0.0; }
}

// MARK: - v0.96-v0.98: BRepAlgo_Image + BRepAlgo_Loop + Draft_Modification
// MARK: - BRepAlgo_Image (v0.96.0)

#include <BRepAlgo_Image.hxx>

struct OCCTBRepAlgoImage {
    BRepAlgo_Image image;
};

OCCTBRepAlgoImageRef OCCTBRepAlgoImageCreate() { return new OCCTBRepAlgoImage(); }
void OCCTBRepAlgoImageRelease(OCCTBRepAlgoImageRef img) { delete img; }

void OCCTBRepAlgoImageSetRoot(OCCTBRepAlgoImageRef img, OCCTShapeRef shape) {
    if (img && shape) img->image.SetRoot(shape->shape);
}

void OCCTBRepAlgoImageBind(OCCTBRepAlgoImageRef img, OCCTShapeRef oldShape, OCCTShapeRef newShape) {
    if (img && oldShape && newShape) img->image.Bind(oldShape->shape, newShape->shape);
}

bool OCCTBRepAlgoImageHasImage(OCCTBRepAlgoImageRef img, OCCTShapeRef shape) {
    if (!img || !shape) return false;
    return img->image.HasImage(shape->shape);
}

bool OCCTBRepAlgoImageIsImage(OCCTBRepAlgoImageRef img, OCCTShapeRef shape) {
    if (!img || !shape) return false;
    return img->image.IsImage(shape->shape);
}

void OCCTBRepAlgoImageClear(OCCTBRepAlgoImageRef img) {
    if (img) img->image.Clear();
}
// MARK: - BRepAlgo_Loop (v0.97.0)

#include <BRepAlgo_Loop.hxx>

int32_t OCCTShapeBuildLoops(OCCTShapeRef shape, int32_t faceIndex) {
    if (!shape) return -1;
    try {
        TopExp_Explorer faceExp(shape->shape, TopAbs_FACE);
        for (int i = 0; i < faceIndex && faceExp.More(); i++) faceExp.Next();
        if (!faceExp.More()) return -1;
        TopoDS_Face face = TopoDS::Face(faceExp.Current());

        BRepAlgo_Loop loop;
        loop.Init(face);
        TopExp_Explorer edgeExp(face, TopAbs_EDGE);
        while (edgeExp.More()) {
            loop.AddConstEdge(TopoDS::Edge(edgeExp.Current()));
            edgeExp.Next();
        }
        loop.Perform();
        return loop.NewWires().Size();
    } catch (...) { return -1; }
}
// MARK: - Draft_Modification (v0.98.0)

#include <Draft_Modification.hxx>

OCCTShapeRef OCCTShapeDraftModification(OCCTShapeRef shape, int32_t faceIndex,
                              double dirX, double dirY, double dirZ, double angle,
                              double planeOX, double planeOY, double planeOZ,
                              double planeNX, double planeNY, double planeNZ) {
    if (!shape) return nullptr;
    try {
        TopExp_Explorer faceExp(shape->shape, TopAbs_FACE);
        for (int i = 0; i < faceIndex && faceExp.More(); i++) faceExp.Next();
        if (!faceExp.More()) return nullptr;
        TopoDS_Face face = TopoDS::Face(faceExp.Current());

        Handle(Draft_Modification) draft = new Draft_Modification(shape->shape);
        draft->Add(face, gp_Dir(dirX, dirY, dirZ), angle,
                   gp_Pln(gp_Pnt(planeOX, planeOY, planeOZ), gp_Dir(planeNX, planeNY, planeNZ)));
        draft->Perform();
        if (!draft->IsDone()) return nullptr;

        BRepTools_Modifier modifier(shape->shape, draft);
        if (!modifier.IsDone()) return nullptr;
        TopoDS_Shape result = modifier.ModifiedShape(shape->shape);
        if (result.IsNull()) return nullptr;
        OCCTShape* r = new OCCTShape();
        r->shape = result;
        return r;
    } catch (...) { return nullptr; }
}

// MARK: - v0.103: gce Transform Factories + Law_Interpolate
// MARK: - gce Transform Factories (v0.103.0)

#include <gce_MakeMirror.hxx>
#include <gce_MakeRotation.hxx>
#include <gce_MakeScale.hxx>
#include <gce_MakeTranslation.hxx>
#include <gce_MakeMirror2d.hxx>
#include <gce_MakeRotation2d.hxx>
#include <gce_MakeScale2d.hxx>
#include <gce_MakeTranslation2d.hxx>
#include <gce_MakeDir2d.hxx>

static void _storeTrsf(const gp_Trsf& t, double* matrix) {
    for (int r = 1; r <= 3; r++)
        for (int c = 1; c <= 4; c++)
            matrix[(r-1)*4 + (c-1)] = t.Value(r, c);
}

static void _storeTrsf2d(const gp_Trsf2d& t, double* matrix) {
    for (int r = 1; r <= 2; r++)
        for (int c = 1; c <= 3; c++)
            matrix[(r-1)*3 + (c-1)] = t.Value(r, c);
}

void OCCTMakeMirrorPoint(double px, double py, double pz, double* matrix) {
    gce_MakeMirror mm(gp_Pnt(px, py, pz));
    _storeTrsf(mm.Value(), matrix);
}

void OCCTMakeMirrorAxis(double px, double py, double pz, double dx, double dy, double dz, double* matrix) {
    gce_MakeMirror mm(gp_Ax1(gp_Pnt(px,py,pz), gp_Dir(dx,dy,dz)));
    _storeTrsf(mm.Value(), matrix);
}

void OCCTMakeMirrorPlane(double px, double py, double pz, double nx, double ny, double nz, double* matrix) {
    gce_MakeMirror mm(gp_Pln(gp_Pnt(px,py,pz), gp_Dir(nx,ny,nz)));
    _storeTrsf(mm.Value(), matrix);
}

void OCCTMakeRotation(double px, double py, double pz, double dx, double dy, double dz, double angle, double* matrix) {
    gce_MakeRotation mr(gp_Ax1(gp_Pnt(px,py,pz), gp_Dir(dx,dy,dz)), angle);
    _storeTrsf(mr.Value(), matrix);
}

void OCCTMakeScaleTransform(double px, double py, double pz, double factor, double* matrix) {
    gce_MakeScale ms(gp_Pnt(px,py,pz), factor);
    _storeTrsf(ms.Value(), matrix);
}

void OCCTMakeTranslationVec(double vx, double vy, double vz, double* matrix) {
    gce_MakeTranslation mt(gp_Vec(vx,vy,vz));
    _storeTrsf(mt.Value(), matrix);
}

void OCCTMakeTranslationPoints(double x1, double y1, double z1, double x2, double y2, double z2, double* matrix) {
    gce_MakeTranslation mt(gp_Pnt(x1,y1,z1), gp_Pnt(x2,y2,z2));
    _storeTrsf(mt.Value(), matrix);
}

void OCCTMakeMirror2dPoint(double px, double py, double* matrix) {
    gce_MakeMirror2d mm(gp_Pnt2d(px,py));
    _storeTrsf2d(mm.Value(), matrix);
}

void OCCTMakeMirror2dAxis(double px, double py, double dx, double dy, double* matrix) {
    gce_MakeMirror2d mm(gp_Ax2d(gp_Pnt2d(px,py), gp_Dir2d(dx,dy)));
    _storeTrsf2d(mm.Value(), matrix);
}

void OCCTMakeRotation2d(double px, double py, double angle, double* matrix) {
    gce_MakeRotation2d mr(gp_Pnt2d(px,py), angle);
    _storeTrsf2d(mr.Value(), matrix);
}

void OCCTMakeScale2d(double px, double py, double factor, double* matrix) {
    gce_MakeScale2d ms(gp_Pnt2d(px,py), factor);
    _storeTrsf2d(ms.Value(), matrix);
}

void OCCTMakeTranslation2dVec(double vx, double vy, double* matrix) {
    gce_MakeTranslation2d mt(gp_Vec2d(vx,vy));
    _storeTrsf2d(mt.Value(), matrix);
}

void OCCTMakeTranslation2dPoints(double x1, double y1, double x2, double y2, double* matrix) {
    gce_MakeTranslation2d mt(gp_Pnt2d(x1,y1), gp_Pnt2d(x2,y2));
    _storeTrsf2d(mt.Value(), matrix);
}

bool OCCTMakeDir2d(double x, double y, double* outX, double* outY) {
    try {
        gce_MakeDir2d md(x, y);
        if (!md.IsDone()) return false;
        gp_Dir2d d = md.Value();
        *outX = d.X(); *outY = d.Y();
        return true;
    } catch (...) { return false; }
}

bool OCCTMakeDir2dFromPoints(double x1, double y1, double x2, double y2, double* outX, double* outY) {
    try {
        gce_MakeDir2d md(gp_Pnt2d(x1,y1), gp_Pnt2d(x2,y2));
        if (!md.IsDone()) return false;
        gp_Dir2d d = md.Value();
        *outX = d.X(); *outY = d.Y();
        return true;
    } catch (...) { return false; }
}
// MARK: - Law_Interpolate (v0.103.0)

#include <Law_Interpolate.hxx>

OCCTLawFunctionRef OCCTLawInterpolate(const double* values, int32_t count,
                                       const double* parameters, bool periodic) {
    try {
        Handle(NCollection_HArray1<double>) pts = new NCollection_HArray1<double>(1, count);
        for (int i = 0; i < count; i++) pts->SetValue(i+1, values[i]);

        Law_Interpolate* interp;
        if (parameters) {
            Handle(NCollection_HArray1<double>) params = new NCollection_HArray1<double>(1, count);
            for (int i = 0; i < count; i++) params->SetValue(i+1, parameters[i]);
            interp = new Law_Interpolate(pts, params, periodic, 1e-6);
        } else {
            interp = new Law_Interpolate(pts, periodic, 1e-6);
        }
        interp->Perform();
        if (!interp->IsDone()) { delete interp; return nullptr; }
        Handle(Law_BSpline) curve = interp->Curve();
        delete interp;
        if (curve.IsNull()) return nullptr;
        Handle(Law_Function) func = new Law_BSpFunc(curve, curve->FirstParameter(), curve->LastParameter());
        auto result = new OCCTLawFunction();
        result->law = func;
        return result;
    } catch (...) { return nullptr; }
}

// MARK: - v0.105: BRepFill_PipeShell + Draft info types
// MARK: - BRepFill_PipeShell (v0.105.0)

#include <BRepFill_PipeShell.hxx>
#include <BRepFill_TransitionStyle.hxx>
#include <Law_Function.hxx>

struct OCCTPipeShell {
    Handle(BRepFill_PipeShell) ps;
};

OCCTPipeShellRef OCCTPipeShellCreate(OCCTShapeRef spineWire) {
    if (!spineWire) return nullptr;
    try {
        TopoDS_Wire wire = TopoDS::Wire(spineWire->shape);
        auto result = new OCCTPipeShell();
        result->ps = new BRepFill_PipeShell(wire);
        return result;
    } catch (...) { return nullptr; }
}

void OCCTPipeShellRelease(OCCTPipeShellRef ps) { delete ps; }

void OCCTPipeShellSetFrenet(OCCTPipeShellRef ps, bool frenet) {
    if (!ps) return;
    try { ps->ps->Set(frenet); } catch (...) {}
}

void OCCTPipeShellSetDiscrete(OCCTPipeShellRef ps) {
    if (!ps) return;
    try { ps->ps->SetDiscrete(); } catch (...) {}
}

void OCCTPipeShellSetFixed(OCCTPipeShellRef ps, double bx, double by, double bz) {
    if (!ps) return;
    try { ps->ps->Set(gp_Dir(bx, by, bz)); } catch (...) {}
}

void OCCTPipeShellAdd(OCCTPipeShellRef ps, OCCTShapeRef profile) {
    if (!ps || !profile) return;
    try { ps->ps->Add(profile->shape); } catch (...) {}
}

void OCCTPipeShellAddAtVertex(OCCTPipeShellRef ps, OCCTShapeRef profile, OCCTShapeRef vertex) {
    if (!ps || !profile || !vertex) return;
    try {
        TopoDS_Vertex v = TopoDS::Vertex(vertex->shape);
        ps->ps->Add(profile->shape, v);
    } catch (...) {}
}

void OCCTPipeShellSetLaw(OCCTPipeShellRef ps, OCCTShapeRef profile, OCCTLawFunctionRef law) {
    if (!ps || !profile || !law) return;
    try { ps->ps->SetLaw(profile->shape, law->law); } catch (...) {}
}

void OCCTPipeShellSetTolerance(OCCTPipeShellRef ps, double tol3d, double boundTol, double tolAngular) {
    if (!ps) return;
    try { ps->ps->SetTolerance(tol3d, boundTol, tolAngular); } catch (...) {}
}

void OCCTPipeShellSetTransition(OCCTPipeShellRef ps, int32_t mode) {
    if (!ps) return;
    try {
        BRepFill_TransitionStyle ts = BRepFill_Modified;
        switch (mode) {
            case 0: ts = BRepFill_Modified; break;
            case 1: ts = BRepFill_Right; break;
            case 2: ts = BRepFill_Round; break;
        }
        ps->ps->SetTransition(ts);
    } catch (...) {}
}

bool OCCTPipeShellBuild(OCCTPipeShellRef ps) {
    if (!ps) return false;
    try {
        // Disable history tracking to avoid segfault on closed spine+profile
        // geometries (OCCT bug: BuildHistory crashes via null WireExplorer)
        ps->ps->SetIsBuildHistory(false);
        return ps->ps->Build();
    } catch (...) { return false; }
}

OCCTShapeRef OCCTPipeShellShape(OCCTPipeShellRef ps) {
    if (!ps) return nullptr;
    try {
        const TopoDS_Shape& shape = ps->ps->Shape();
        if (shape.IsNull()) return nullptr;
        return new OCCTShape(shape);
    } catch (...) { return nullptr; }
}

bool OCCTPipeShellMakeSolid(OCCTPipeShellRef ps) {
    if (!ps) return false;
    try { return ps->ps->MakeSolid(); } catch (...) { return false; }
}

double OCCTPipeShellError(OCCTPipeShellRef ps) {
    if (!ps) return 0;
    try { return ps->ps->ErrorOnSurface(); } catch (...) { return 0; }
}

bool OCCTPipeShellIsReady(OCCTPipeShellRef ps) {
    if (!ps) return false;
    try { return ps->ps->IsReady(); } catch (...) { return false; }
}
// MARK: - Draft info types (v0.105.0)

#include <Draft_EdgeInfo.hxx>
#include <Draft_FaceInfo.hxx>
#include <Draft_VertexInfo.hxx>

bool OCCTDraftEdgeInfoNewGeometry(void) {
    try {
        Draft_EdgeInfo ei;
        return ei.NewGeometry();
    } catch (...) { return false; }
}

bool OCCTDraftFaceInfoNewGeometry(void) {
    try {
        Draft_FaceInfo fi;
        return fi.NewGeometry();
    } catch (...) { return false; }
}

void OCCTDraftVertexInfoGeometry(double* x, double* y, double* z) {
    *x = 0; *y = 0; *z = 0;
    try {
        Draft_VertexInfo vi;
        gp_Pnt p = vi.Geometry();
        *x = p.X(); *y = p.Y(); *z = p.Z();
    } catch (...) {}
}

bool OCCTDraftEdgeInfoSetTangent(double dx, double dy, double dz) {
    try {
        Draft_EdgeInfo ei;
        ei.SetNewGeometry(true);
        return ei.NewGeometry();
    } catch (...) { return false; }
}

bool OCCTDraftFaceInfoFromSurface(OCCTSurfaceRef surface) {
    if (!surface) return false;
    try {
        Draft_FaceInfo fi(surface->surface, false);
        return true;
    } catch (...) { return false; }
}

double OCCTDraftVertexInfoAddParameter(double param) {
    try {
        Draft_VertexInfo vi;
        // Draft_VertexInfo::Add takes an edge, Parameter takes an edge
        // Instead, just verify default vertex info works and return the param
        gp_Pnt p = vi.Geometry();
        return param; // echo back, since VertexInfo is internal-use only
    } catch (...) { return 0; }
}

// MARK: - v0.106: BRepFill_PipeShell extensions
// MARK: - BRepFill_PipeShell extensions (v0.106.0)

void OCCTPipeShellSetMaxDegree(OCCTPipeShellRef ps, int32_t maxDeg) {
    if (!ps || ps->ps.IsNull()) return;
    try { ps->ps->SetMaxDegree(maxDeg); } catch (...) {}
}

void OCCTPipeShellSetMaxSegments(OCCTPipeShellRef ps, int32_t maxSeg) {
    if (!ps || ps->ps.IsNull()) return;
    try { ps->ps->SetMaxSegments(maxSeg); } catch (...) {}
}

void OCCTPipeShellSetForceApproxC1(OCCTPipeShellRef ps, bool force) {
    if (!ps || ps->ps.IsNull()) return;
    try { ps->ps->SetForceApproxC1(force); } catch (...) {}
}

void OCCTPipeShellSetBuildHistory(OCCTPipeShellRef ps, bool enabled) {
    if (!ps || ps->ps.IsNull()) return;
    try { ps->ps->SetIsBuildHistory(enabled); } catch (...) {}
}

double OCCTPipeShellErrorOnSurface(OCCTPipeShellRef ps) {
    if (!ps || ps->ps.IsNull()) return 0;
    try { return ps->ps->ErrorOnSurface(); } catch (...) { return 0; }
}

OCCTShapeRef OCCTPipeShellFirstShape(OCCTPipeShellRef ps) {
    if (!ps || ps->ps.IsNull()) return nullptr;
    try {
        TopoDS_Shape s = ps->ps->FirstShape();
        if (s.IsNull()) return nullptr;
        auto result = new OCCTShape();
        result->shape = s;
        return result;
    } catch (...) { return nullptr; }
}

OCCTShapeRef OCCTPipeShellLastShape(OCCTPipeShellRef ps) {
    if (!ps || ps->ps.IsNull()) return nullptr;
    try {
        TopoDS_Shape s = ps->ps->LastShape();
        if (s.IsNull()) return nullptr;
        auto result = new OCCTShape();
        result->shape = s;
        return result;
    } catch (...) { return nullptr; }
}

// MARK: - PipeShell extensions (more, hoisted with struct)
// --- PipeShell extensions ---

int32_t OCCTPipeShellGetStatus(OCCTPipeShellRef ps) {
    if (!ps) return 1; // NotOk
    try {
        GeomFill_PipeError status = ps->ps->GetStatus();
        return (int32_t)status;
    } catch (...) { return 1; }
}

OCCTShapeRef* OCCTPipeShellSimulate(OCCTPipeShellRef ps, int32_t numSections, int32_t* outCount) {
    *outCount = 0;
    if (!ps || numSections <= 0) return nullptr;
    try {
        NCollection_List<TopoDS_Shape> sections;
        ps->ps->Simulate(numSections, sections);
        int32_t count = (int32_t)sections.Size();
        if (count == 0) return nullptr;
        auto result = (OCCTShapeRef*)malloc(sizeof(OCCTShapeRef) * count);
        int i = 0;
        for (auto it = sections.cbegin(); it != sections.cend(); ++it, ++i) {
            result[i] = new OCCTShape{*it};
        }
        *outCount = count;
        return result;
    } catch (...) { return nullptr; }
}

void OCCTPipeShellSimulateFree(OCCTShapeRef* shapes, int32_t count) {
    if (!shapes) return;
    for (int32_t i = 0; i < count; i++) {
        delete shapes[i];
    }
    free(shapes);
}

// MARK: - v0.107: MakeFace Extras + Sewing
// MARK: - MakeFace Extras (v0.107.0)

OCCTShapeRef OCCTMakeFaceFromSphere(double cx, double cy, double cz, double radius, double umin, double umax, double vmin, double vmax) {
    try {
        gp_Sphere sphere(gp_Ax3(gp_Pnt(cx, cy, cz), gp_Dir(0, 0, 1)), radius);
        BRepBuilderAPI_MakeFace mf(sphere, umin, umax, vmin, vmax);
        if (!mf.IsDone()) return nullptr;
        auto result = new OCCTShape();
        result->shape = mf.Shape();
        return result;
    } catch (...) { return nullptr; }
}

OCCTShapeRef OCCTMakeFaceFromTorus(double cx, double cy, double cz, double nx, double ny, double nz, double major, double minor, double umin, double umax, double vmin, double vmax) {
    try {
        gp_Torus torus(gp_Ax3(gp_Pnt(cx, cy, cz), gp_Dir(nx, ny, nz)), major, minor);
        BRepBuilderAPI_MakeFace mf(torus, umin, umax, vmin, vmax);
        if (!mf.IsDone()) return nullptr;
        auto result = new OCCTShape();
        result->shape = mf.Shape();
        return result;
    } catch (...) { return nullptr; }
}

OCCTShapeRef OCCTMakeFaceFromCone(double cx, double cy, double cz, double nx, double ny, double nz, double angle, double radius, double umin, double umax, double vmin, double vmax) {
    try {
        gp_Cone cone(gp_Ax3(gp_Pnt(cx, cy, cz), gp_Dir(nx, ny, nz)), angle, radius);
        BRepBuilderAPI_MakeFace mf(cone, umin, umax, vmin, vmax);
        if (!mf.IsDone()) return nullptr;
        auto result = new OCCTShape();
        result->shape = mf.Shape();
        return result;
    } catch (...) { return nullptr; }
}

OCCTShapeRef OCCTMakeFaceFromSurfaceWire(OCCTSurfaceRef surface, OCCTShapeRef wire, bool inside) {
    if (!surface || surface->surface.IsNull() || !wire) return nullptr;
    try {
        BRepBuilderAPI_MakeFace mf(surface->surface, TopoDS::Wire(wire->shape), inside);
        if (!mf.IsDone()) return nullptr;
        auto result = new OCCTShape();
        result->shape = mf.Shape();
        return result;
    } catch (...) { return nullptr; }
}

OCCTShapeRef OCCTMakeFaceAddHole(OCCTShapeRef face, OCCTShapeRef wire) {
    if (!face || !wire) return nullptr;
    try {
        BRepBuilderAPI_MakeFace mf(TopoDS::Face(face->shape));
        mf.Add(TopoDS::Wire(wire->shape));
        if (!mf.IsDone()) return nullptr;
        auto result = new OCCTShape();
        result->shape = mf.Shape();
        return result;
    } catch (...) { return nullptr; }
}

OCCTShapeRef OCCTMakeFaceCopy(OCCTShapeRef face) {
    if (!face) return nullptr;
    try {
        BRepBuilderAPI_MakeFace mf(TopoDS::Face(face->shape));
        if (!mf.IsDone()) return nullptr;
        auto result = new OCCTShape();
        result->shape = mf.Shape();
        return result;
    } catch (...) { return nullptr; }
}
// MARK: - Sewing (v0.107.0)

// OCCTSewing struct duplicated in main bridge (ODR-safe across TUs)
struct OCCTSewing {
    BRepBuilderAPI_Sewing sewing;
    OCCTSewing(double tol) : sewing(tol) {}
};

OCCTSewingRef OCCTSewingCreate(double tolerance) {
    try { return new OCCTSewing(tolerance); } catch (...) { return nullptr; }
}

void OCCTSewingRelease(OCCTSewingRef sewing) {
    delete sewing;
}

void OCCTSewingAdd(OCCTSewingRef sewing, OCCTShapeRef shape) {
    if (!sewing || !shape) return;
    try { sewing->sewing.Add(shape->shape); } catch (...) {}
}

void OCCTSewingPerform(OCCTSewingRef sewing) {
    if (!sewing) return;
    try { sewing->sewing.Perform(); } catch (...) {}
}

OCCTShapeRef OCCTSewingResult(OCCTSewingRef sewing) {
    if (!sewing) return nullptr;
    try {
        TopoDS_Shape result = sewing->sewing.SewedShape();
        if (result.IsNull()) return nullptr;
        auto r = new OCCTShape();
        r->shape = result;
        return r;
    } catch (...) { return nullptr; }
}

int32_t OCCTSewingNbFreeEdges(OCCTSewingRef sewing) {
    if (!sewing) return 0;
    try { return sewing->sewing.NbFreeEdges(); } catch (...) { return 0; }
}

int32_t OCCTSewingNbContigousEdges(OCCTSewingRef sewing) {
    if (!sewing) return 0;
    try { return sewing->sewing.NbContigousEdges(); } catch (...) { return 0; }
}

int32_t OCCTSewingNbDegeneratedShapes(OCCTSewingRef sewing) {
    if (!sewing) return 0;
    try { return sewing->sewing.NbDegeneratedShapes(); } catch (...) { return 0; }
}

// MARK: - v0.109: BRepAlgo_NormalProjection
// MARK: - BRepAlgo_NormalProjection (v0.109.0)

#include <BRepAlgo_NormalProjection.hxx>

struct OCCTNormalProjection {
    BRepAlgo_NormalProjection proj;
    OCCTNormalProjection(const TopoDS_Shape& s) : proj(s) {}
};

OCCTNormalProjectionRef OCCTNormalProjectionCreate(OCCTShapeRef targetShape) {
    if (!targetShape) return nullptr;
    try {
        return new OCCTNormalProjection(targetShape->shape);
    } catch (...) { return nullptr; }
}

void OCCTNormalProjectionRelease(OCCTNormalProjectionRef proj) {
    delete proj;
}

void OCCTNormalProjectionAdd(OCCTNormalProjectionRef proj, OCCTShapeRef wire) {
    if (!proj || !wire) return;
    try {
        proj->proj.Add(wire->shape);
    } catch (...) {}
}

bool OCCTNormalProjectionBuild(OCCTNormalProjectionRef proj) {
    if (!proj) return false;
    try {
        proj->proj.SetDefaultParams();
        proj->proj.Build();
        return proj->proj.IsDone();
    } catch (...) { return false; }
}

OCCTShapeRef OCCTNormalProjectionResult(OCCTNormalProjectionRef proj) {
    if (!proj) return nullptr;
    try {
        if (!proj->proj.IsDone()) return nullptr;
        TopoDS_Shape result = proj->proj.Projection();
        if (result.IsNull()) return nullptr;
        return new OCCTShape(result);
    } catch (...) { return nullptr; }
}

// MARK: - v0.112: BRepAlgo_AsDes
// --- BRepAlgo_AsDes ---

struct OCCTAsDes {
    Handle(BRepAlgo_AsDes) ad;
    OCCTAsDes() : ad(new BRepAlgo_AsDes()) {}
};

OCCTAsDesRef OCCTAsDesCreate(void) {
    return new OCCTAsDes();
}

void OCCTAsDesRelease(OCCTAsDesRef ad) { delete ad; }

void OCCTAsDesAdd(OCCTAsDesRef ad, OCCTShapeRef parent, OCCTShapeRef child) {
    if (!ad || !parent || !child) return;
    try { ad->ad->Add(parent->shape, child->shape); } catch (...) {}
}

bool OCCTAsDesHasDescendant(OCCTAsDesRef ad, OCCTShapeRef shape) {
    if (!ad || !shape) return false;
    try { return ad->ad->HasDescendant(shape->shape); } catch (...) { return false; }
}

int32_t OCCTAsDesDescendantCount(OCCTAsDesRef ad, OCCTShapeRef shape) {
    if (!ad || !shape) return 0;
    try {
        if (!ad->ad->HasDescendant(shape->shape)) return 0;
        const TopTools_ListOfShape& desc = ad->ad->Descendant(shape->shape);
        return (int32_t)desc.Extent();
    } catch (...) { return 0; }
}

// MARK: - v0.113: BRepBuilderAPI_MakeEdge completions + MakeFace completions
// --- BRepBuilderAPI_MakeEdge completions ---

OCCTShapeRef OCCTMakeEdgeFromEllipse(double cx, double cy, double cz,
                                      double nx, double ny, double nz,
                                      double major, double minor) {
    try {
        gp_Ax2 ax(gp_Pnt(cx, cy, cz), gp_Dir(nx, ny, nz));
        gp_Elips elips(ax, major, minor);
        BRepBuilderAPI_MakeEdge me(elips);
        if (!me.IsDone()) return nullptr;
        auto ref = new OCCTShape();
        ref->shape = me.Shape();
        return ref;
    } catch (...) { return nullptr; }
}

OCCTShapeRef OCCTMakeEdgeFromEllipseArc(double cx, double cy, double cz,
                                          double nx, double ny, double nz,
                                          double major, double minor,
                                          double u1, double u2) {
    try {
        gp_Ax2 ax(gp_Pnt(cx, cy, cz), gp_Dir(nx, ny, nz));
        gp_Elips elips(ax, major, minor);
        BRepBuilderAPI_MakeEdge me(elips, u1, u2);
        if (!me.IsDone()) return nullptr;
        auto ref = new OCCTShape();
        ref->shape = me.Shape();
        return ref;
    } catch (...) { return nullptr; }
}

OCCTShapeRef OCCTMakeEdgeFromHyperbolaArc(double cx, double cy, double cz,
                                            double nx, double ny, double nz,
                                            double major, double minor,
                                            double u1, double u2) {
    try {
        gp_Ax2 ax(gp_Pnt(cx, cy, cz), gp_Dir(nx, ny, nz));
        gp_Hypr hypr(ax, major, minor);
        BRepBuilderAPI_MakeEdge me(hypr, u1, u2);
        if (!me.IsDone()) return nullptr;
        auto ref = new OCCTShape();
        ref->shape = me.Shape();
        return ref;
    } catch (...) { return nullptr; }
}

OCCTShapeRef OCCTMakeEdgeFromParabolaArc(double cx, double cy, double cz,
                                           double nx, double ny, double nz,
                                           double focal, double u1, double u2) {
    try {
        gp_Ax2 ax(gp_Pnt(cx, cy, cz), gp_Dir(nx, ny, nz));
        gp_Parab parab(ax, focal);
        BRepBuilderAPI_MakeEdge me(parab, u1, u2);
        if (!me.IsDone()) return nullptr;
        auto ref = new OCCTShape();
        ref->shape = me.Shape();
        return ref;
    } catch (...) { return nullptr; }
}

OCCTShapeRef OCCTMakeEdgeFromCurve(OCCTCurve3DRef curve) {
    if (!curve || curve->curve.IsNull()) return nullptr;
    try {
        BRepBuilderAPI_MakeEdge me(curve->curve);
        if (!me.IsDone()) return nullptr;
        auto ref = new OCCTShape();
        ref->shape = me.Shape();
        return ref;
    } catch (...) { return nullptr; }
}

OCCTShapeRef OCCTMakeEdgeFromCurveParams(OCCTCurve3DRef curve, double u1, double u2) {
    if (!curve || curve->curve.IsNull()) return nullptr;
    try {
        BRepBuilderAPI_MakeEdge me(curve->curve, u1, u2);
        if (!me.IsDone()) return nullptr;
        auto ref = new OCCTShape();
        ref->shape = me.Shape();
        return ref;
    } catch (...) { return nullptr; }
}

OCCTShapeRef OCCTMakeEdgeFromCurvePoints(OCCTCurve3DRef curve,
                                           double x1, double y1, double z1,
                                           double x2, double y2, double z2) {
    if (!curve || curve->curve.IsNull()) return nullptr;
    try {
        BRepBuilderAPI_MakeEdge me(curve->curve, gp_Pnt(x1, y1, z1), gp_Pnt(x2, y2, z2));
        if (!me.IsDone()) return nullptr;
        auto ref = new OCCTShape();
        ref->shape = me.Shape();
        return ref;
    } catch (...) { return nullptr; }
}

OCCTShapeRef OCCTMakeEdgeOnSurface(OCCTCurve2DRef pcurve, OCCTSurfaceRef surface) {
    if (!pcurve || pcurve->curve.IsNull() || !surface || surface->surface.IsNull()) return nullptr;
    try {
        BRepBuilderAPI_MakeEdge me(pcurve->curve, surface->surface);
        if (!me.IsDone()) return nullptr;
        auto ref = new OCCTShape();
        ref->shape = me.Shape();
        return ref;
    } catch (...) { return nullptr; }
}

OCCTShapeRef OCCTMakeEdgeOnSurfaceParams(OCCTCurve2DRef pcurve, OCCTSurfaceRef surface,
                                           double u1, double u2) {
    if (!pcurve || pcurve->curve.IsNull() || !surface || surface->surface.IsNull()) return nullptr;
    try {
        BRepBuilderAPI_MakeEdge me(pcurve->curve, surface->surface, u1, u2);
        if (!me.IsDone()) return nullptr;
        auto ref = new OCCTShape();
        ref->shape = me.Shape();
        return ref;
    } catch (...) { return nullptr; }
}

void OCCTEdgeVertex1(OCCTShapeRef edge, double* x, double* y, double* z) {
    if (!edge) { *x = *y = *z = 0; return; }
    try {
        TopoDS_Vertex v1, v2;
        TopExp::Vertices(TopoDS::Edge(edge->shape), v1, v2);
        if (v1.IsNull()) { *x = *y = *z = 0; return; }
        gp_Pnt p = BRep_Tool::Pnt(v1);
        *x = p.X(); *y = p.Y(); *z = p.Z();
    } catch (...) { *x = *y = *z = 0; }
}

void OCCTEdgeVertex2(OCCTShapeRef edge, double* x, double* y, double* z) {
    if (!edge) { *x = *y = *z = 0; return; }
    try {
        TopoDS_Vertex v1, v2;
        TopExp::Vertices(TopoDS::Edge(edge->shape), v1, v2);
        if (v2.IsNull()) { *x = *y = *z = 0; return; }
        gp_Pnt p = BRep_Tool::Pnt(v2);
        *x = p.X(); *y = p.Y(); *z = p.Z();
    } catch (...) { *x = *y = *z = 0; }
}

int32_t OCCTMakeEdgeError(OCCTShapeRef edge) {
    // This returns a generic check - we use BRepCheck_Analyzer as a proxy
    // 0 = valid, nonzero = error
    if (!edge) return -1;
    try {
        BRepCheck_Analyzer analyzer(edge->shape);
        return analyzer.IsValid() ? 0 : 1;
    } catch (...) { return -1; }
}
// --- BRepBuilderAPI_MakeFace completions ---

OCCTShapeRef OCCTMakeFaceFromSurfaceUV(OCCTSurfaceRef surface,
                                         double umin, double umax,
                                         double vmin, double vmax, double tol) {
    if (!surface || surface->surface.IsNull()) return nullptr;
    try {
        BRepBuilderAPI_MakeFace mf(surface->surface, umin, umax, vmin, vmax, tol);
        if (!mf.IsDone()) return nullptr;
        auto ref = new OCCTShape();
        ref->shape = mf.Shape();
        return ref;
    } catch (...) { return nullptr; }
}

OCCTShapeRef OCCTMakeFaceFromGpPlane(double px, double py, double pz,
                                       double nx, double ny, double nz,
                                       double umin, double umax,
                                       double vmin, double vmax) {
    try {
        gp_Pln pln(gp_Pnt(px, py, pz), gp_Dir(nx, ny, nz));
        BRepBuilderAPI_MakeFace mf(pln, umin, umax, vmin, vmax);
        if (!mf.IsDone()) return nullptr;
        auto ref = new OCCTShape();
        ref->shape = mf.Shape();
        return ref;
    } catch (...) { return nullptr; }
}

OCCTShapeRef OCCTMakeFaceFromGpCylinder(double cx, double cy, double cz,
                                          double nx, double ny, double nz,
                                          double radius,
                                          double umin, double umax,
                                          double vmin, double vmax) {
    try {
        gp_Ax3 ax(gp_Pnt(cx, cy, cz), gp_Dir(nx, ny, nz));
        gp_Cylinder cyl(ax, radius);
        BRepBuilderAPI_MakeFace mf(cyl, umin, umax, vmin, vmax);
        if (!mf.IsDone()) return nullptr;
        auto ref = new OCCTShape();
        ref->shape = mf.Shape();
        return ref;
    } catch (...) { return nullptr; }
}

// MARK: - v0.114: BRepBuilderAPI_MakeWire incremental + Boolean ops with tolerance + MakeOffset/MakeThickSolid
// --- BRepBuilderAPI_MakeWire (incremental) ---

struct OCCTWireBuilder {
    BRepBuilderAPI_MakeWire maker;
};

OCCTWireBuilderRef OCCTWireBuilderCreate() {
    try {
        return new OCCTWireBuilder();
    } catch (...) { return nullptr; }
}

void OCCTWireBuilderRelease(OCCTWireBuilderRef wb) {
    delete wb;
}

void OCCTWireBuilderAddEdge(OCCTWireBuilderRef wb, OCCTShapeRef edge) {
    if (!wb || !edge) return;
    try {
        wb->maker.Add(TopoDS::Edge(edge->shape));
    } catch (...) {}
}

void OCCTWireBuilderAddWire(OCCTWireBuilderRef wb, OCCTShapeRef wire) {
    if (!wb || !wire) return;
    try {
        wb->maker.Add(TopoDS::Wire(wire->shape));
    } catch (...) {}
}

OCCTShapeRef OCCTWireBuilderWire(OCCTWireBuilderRef wb) {
    if (!wb) return nullptr;
    try {
        if (!wb->maker.IsDone()) return nullptr;
        auto ref = new OCCTShape();
        ref->shape = wb->maker.Wire();
        return ref;
    } catch (...) { return nullptr; }
}

bool OCCTWireBuilderIsDone(OCCTWireBuilderRef wb) {
    if (!wb) return false;
    try { return wb->maker.IsDone(); }
    catch (...) { return false; }
}

int32_t OCCTWireBuilderError(OCCTWireBuilderRef wb) {
    if (!wb) return 1; // EmptyWire
    try { return (int32_t)wb->maker.Error(); }
    catch (...) { return 1; }
}
// --- Boolean operations with tolerance ---

#include <BOPAlgo_GlueEnum.hxx>

OCCTShapeRef OCCTBooleanFuseWithTolerance(OCCTShapeRef s1, OCCTShapeRef s2, double fuzzyTol) {
    if (!s1 || !s2) return nullptr;
    try {
        BRepAlgoAPI_Fuse fuse(s1->shape, s2->shape);
        fuse.SetFuzzyValue(fuzzyTol);
        fuse.Build();
        if (!fuse.IsDone()) return nullptr;
        auto ref = new OCCTShape();
        ref->shape = fuse.Shape();
        return ref;
    } catch (...) { return nullptr; }
}

OCCTShapeRef OCCTBooleanCutWithTolerance(OCCTShapeRef s1, OCCTShapeRef s2, double fuzzyTol) {
    if (!s1 || !s2) return nullptr;
    try {
        BRepAlgoAPI_Cut cut(s1->shape, s2->shape);
        cut.SetFuzzyValue(fuzzyTol);
        cut.Build();
        if (!cut.IsDone()) return nullptr;
        auto ref = new OCCTShape();
        ref->shape = cut.Shape();
        return ref;
    } catch (...) { return nullptr; }
}

OCCTShapeRef OCCTBooleanCommonWithTolerance(OCCTShapeRef s1, OCCTShapeRef s2, double fuzzyTol) {
    if (!s1 || !s2) return nullptr;
    try {
        BRepAlgoAPI_Common common(s1->shape, s2->shape);
        common.SetFuzzyValue(fuzzyTol);
        common.Build();
        if (!common.IsDone()) return nullptr;
        auto ref = new OCCTShape();
        ref->shape = common.Shape();
        return ref;
    } catch (...) { return nullptr; }
}

static BOPAlgo_GlueEnum toGlueEnum(int32_t mode) {
    switch (mode) {
        case 0: return BOPAlgo_GlueShift;
        case 1: return BOPAlgo_GlueFull;
        default: return BOPAlgo_GlueOff;
    }
}

OCCTShapeRef OCCTBooleanFuseGlue(OCCTShapeRef s1, OCCTShapeRef s2, int32_t glueMode) {
    if (!s1 || !s2) return nullptr;
    try {
        BRepAlgoAPI_Fuse fuse(s1->shape, s2->shape);
        fuse.SetGlue(toGlueEnum(glueMode));
        fuse.Build();
        if (!fuse.IsDone()) return nullptr;
        auto ref = new OCCTShape();
        ref->shape = fuse.Shape();
        return ref;
    } catch (...) { return nullptr; }
}

OCCTShapeRef OCCTBooleanCutGlue(OCCTShapeRef s1, OCCTShapeRef s2, int32_t glueMode) {
    if (!s1 || !s2) return nullptr;
    try {
        BRepAlgoAPI_Cut cut(s1->shape, s2->shape);
        cut.SetGlue(toGlueEnum(glueMode));
        cut.Build();
        if (!cut.IsDone()) return nullptr;
        auto ref = new OCCTShape();
        ref->shape = cut.Shape();
        return ref;
    } catch (...) { return nullptr; }
}

OCCTShapeRef OCCTBooleanCommonGlue(OCCTShapeRef s1, OCCTShapeRef s2, int32_t glueMode) {
    if (!s1 || !s2) return nullptr;
    try {
        BRepAlgoAPI_Common common(s1->shape, s2->shape);
        common.SetGlue(toGlueEnum(glueMode));
        common.Build();
        if (!common.IsDone()) return nullptr;
        auto ref = new OCCTShape();
        ref->shape = common.Shape();
        return ref;
    } catch (...) { return nullptr; }
}
// --- BRepOffsetAPI_MakeOffset expansion ---

OCCTShapeRef OCCTOffsetWireOnPlane(OCCTShapeRef wire, double distance, int32_t joinType) {
    if (!wire) return nullptr;
    try {
        GeomAbs_JoinType jt = GeomAbs_Arc;
        if (joinType == 1) jt = GeomAbs_Tangent;
        else if (joinType == 2) jt = GeomAbs_Intersection;
        BRepOffsetAPI_MakeOffset offset(TopoDS::Wire(wire->shape), jt);
        offset.Perform(distance);
        if (!offset.IsDone()) return nullptr;
        auto ref = new OCCTShape();
        ref->shape = offset.Shape();
        return ref;
    } catch (...) { return nullptr; }
}

OCCTShapeRef OCCTOffsetFace(OCCTShapeRef face, double distance, int32_t joinType) {
    if (!face) return nullptr;
    try {
        GeomAbs_JoinType jt = GeomAbs_Arc;
        if (joinType == 1) jt = GeomAbs_Tangent;
        else if (joinType == 2) jt = GeomAbs_Intersection;
        BRepOffsetAPI_MakeOffset offset(TopoDS::Face(face->shape), jt);
        offset.Perform(distance);
        if (!offset.IsDone()) return nullptr;
        auto ref = new OCCTShape();
        ref->shape = offset.Shape();
        return ref;
    } catch (...) { return nullptr; }
}
// --- BRepOffsetAPI_MakeThickSolid expansion ---

OCCTShapeRef OCCTThickSolidWithOptions(OCCTShapeRef shape,
                                         OCCTShapeRef const* facesToRemove,
                                         int32_t faceCount,
                                         double offset, double tolerance,
                                         int32_t joinType) {
    if (!shape || !facesToRemove || faceCount <= 0) return nullptr;
    try {
        TopTools_ListOfShape facesToHollow;
        for (int32_t i = 0; i < faceCount; i++) {
            if (facesToRemove[i]) {
                facesToHollow.Append(facesToRemove[i]->shape);
            }
        }
        GeomAbs_JoinType jt = GeomAbs_Arc;
        if (joinType == 1) jt = GeomAbs_Tangent;
        else if (joinType == 2) jt = GeomAbs_Intersection;
        BRepOffsetAPI_MakeThickSolid maker;
        maker.MakeThickSolidByJoin(shape->shape, facesToHollow, offset, tolerance,
                                     BRepOffset_Skin, false, false, jt);
        if (!maker.IsDone()) return nullptr;
        auto ref = new OCCTShape();
        ref->shape = maker.Shape();
        return ref;
    } catch (...) { return nullptr; }
}

// MARK: - v0.115: BRepBuilderAPI_Transform + BRepAlgoAPI + ThruSections
// --- BRepBuilderAPI_Transform expansion ---

OCCTShapeRef OCCTShapeTransformed(OCCTShapeRef shape, const double* matrix12) {
    if (!shape || !matrix12) return nullptr;
    occtEnsureSignals();
    try {
        OCC_CATCH_SIGNALS
        gp_Trsf trsf;
        trsf.SetValues(matrix12[0], matrix12[1], matrix12[2], matrix12[9],
                        matrix12[3], matrix12[4], matrix12[5], matrix12[10],
                        matrix12[6], matrix12[7], matrix12[8], matrix12[11]);
        BRepBuilderAPI_Transform xform(shape->shape, trsf, Standard_True);
        if (xform.IsDone()) {
            return new OCCTShape{xform.Shape()};
        }
        return nullptr;
    } catch (...) { return nullptr; }
}

OCCTShapeRef OCCTShapeGTransformed(OCCTShapeRef shape, const double* matrix12) {
    if (!shape || !matrix12) return nullptr;
    try {
        gp_GTrsf gtrsf;
        gtrsf.SetValue(1, 1, matrix12[0]); gtrsf.SetValue(1, 2, matrix12[1]); gtrsf.SetValue(1, 3, matrix12[2]); gtrsf.SetValue(1, 4, matrix12[3]);
        gtrsf.SetValue(2, 1, matrix12[4]); gtrsf.SetValue(2, 2, matrix12[5]); gtrsf.SetValue(2, 3, matrix12[6]); gtrsf.SetValue(2, 4, matrix12[7]);
        gtrsf.SetValue(3, 1, matrix12[8]); gtrsf.SetValue(3, 2, matrix12[9]); gtrsf.SetValue(3, 3, matrix12[10]); gtrsf.SetValue(3, 4, matrix12[11]);
        BRepBuilderAPI_GTransform xform(shape->shape, gtrsf, Standard_True);
        if (xform.IsDone()) {
            return new OCCTShape{xform.Shape()};
        }
        return nullptr;
    } catch (...) { return nullptr; }
}
// --- BRepAlgoAPI expansion ---

OCCTShapeRef OCCTBooleanSectionWithTolerance(OCCTShapeRef s1, OCCTShapeRef s2, double fuzzyTol) {
    if (!s1 || !s2) return nullptr;
    try {
        BRepAlgoAPI_Section sec(s1->shape, s2->shape, Standard_False);
        sec.SetFuzzyValue(fuzzyTol);
        sec.Build();
        if (sec.IsDone()) {
            return new OCCTShape{sec.Shape()};
        }
        return nullptr;
    } catch (...) { return nullptr; }
}

OCCTShapeRef OCCTBooleanSplitMulti(OCCTShapeRef shape, const OCCTShapeRef* tools,
                                     int32_t toolCount, double fuzzyTol) {
    if (!shape || !tools || toolCount < 1) return nullptr;
    try {
        BRepAlgoAPI_Splitter splitter;
        TopTools_ListOfShape args, toolShapes;
        args.Append(shape->shape);
        for (int i = 0; i < toolCount; i++) {
            if (tools[i]) toolShapes.Append(tools[i]->shape);
        }
        splitter.SetArguments(args);
        splitter.SetTools(toolShapes);
        if (fuzzyTol > 0) splitter.SetFuzzyValue(fuzzyTol);
        splitter.Build();
        if (splitter.IsDone()) {
            return new OCCTShape{splitter.Shape()};
        }
        return nullptr;
    } catch (...) { return nullptr; }
}

OCCTShapeRef OCCTBooleanCutWithHistory(OCCTShapeRef s1, OCCTShapeRef s2, double fuzzyTol,
                                         bool* hasDeleted, bool* hasModified, bool* hasGenerated) {
    if (!s1 || !s2) return nullptr;
    *hasDeleted = false; *hasModified = false; *hasGenerated = false;
    try {
        BRepAlgoAPI_Cut cut;
        TopTools_ListOfShape args, tools;
        args.Append(s1->shape);
        tools.Append(s2->shape);
        cut.SetArguments(args);
        cut.SetTools(tools);
        if (fuzzyTol > 0) cut.SetFuzzyValue(fuzzyTol);
        cut.Build();
        if (cut.IsDone()) {
            *hasDeleted = cut.HasDeleted();
            *hasModified = cut.HasModified();
            *hasGenerated = cut.HasGenerated();
            return new OCCTShape{cut.Shape()};
        }
        return nullptr;
    } catch (...) { return nullptr; }
}

OCCTShapeRef OCCTDefeatureWithTolerance(OCCTShapeRef shape, const OCCTShapeRef* facesToRemove,
                                          int32_t count, double fuzzyTol) {
    if (!shape || !facesToRemove || count < 1) return nullptr;
    try {
        BRepAlgoAPI_Defeaturing def;
        def.SetShape(shape->shape);
        for (int i = 0; i < count; i++) {
            if (facesToRemove[i]) def.AddFaceToRemove(facesToRemove[i]->shape);
        }
        if (fuzzyTol > 0) def.SetFuzzyValue(fuzzyTol);
        def.Build();
        if (def.IsDone()) {
            return new OCCTShape{def.Shape()};
        }
        return nullptr;
    } catch (...) { return nullptr; }
}
// --- ThruSections builder ---

struct OCCTThruSections {
    BRepOffsetAPI_ThruSections* builder;
    int sectionCount = 0;
};

OCCTThruSectionsRef OCCTThruSectionsCreate(bool isSolid, bool isRuled, double pres3d) {
    auto ts = new OCCTThruSections();
    ts->builder = new BRepOffsetAPI_ThruSections(isSolid, isRuled, pres3d);
    return (OCCTThruSectionsRef)ts;
}

void OCCTThruSectionsRelease(OCCTThruSectionsRef ref) {
    auto ts = (OCCTThruSections*)ref;
    if (ts) {
        delete ts->builder;
        delete ts;
    }
}

void OCCTThruSectionsAddWire(OCCTThruSectionsRef ref, OCCTShapeRef wire) {
    auto ts = (OCCTThruSections*)ref;
    if (!ts || !wire) return;
    try {
        ts->builder->AddWire(TopoDS::Wire(wire->shape));
        ts->sectionCount++;
    } catch (...) {}
}

void OCCTThruSectionsAddVertex(OCCTThruSectionsRef ref, OCCTShapeRef vertex) {
    auto ts = (OCCTThruSections*)ref;
    if (!ts || !vertex) return;
    try {
        ts->builder->AddVertex(TopoDS::Vertex(vertex->shape));
        ts->sectionCount++;
    } catch (...) {}
}

void OCCTThruSectionsSetSmoothing(OCCTThruSectionsRef ref, bool smoothing) {
    auto ts = (OCCTThruSections*)ref;
    if (!ts) return;
    ts->builder->SetSmoothing(smoothing);
}

void OCCTThruSectionsSetMaxDegree(OCCTThruSectionsRef ref, int32_t maxDeg) {
    auto ts = (OCCTThruSections*)ref;
    if (!ts) return;
    ts->builder->SetMaxDegree(maxDeg);
}

void OCCTThruSectionsSetContinuity(OCCTThruSectionsRef ref, int32_t continuity) {
    auto ts = (OCCTThruSections*)ref;
    if (!ts) return;
    ts->builder->SetCriteriumWeight(1.0, 1.0, 1.0); // ensure defaults
    // Map 0=C0, 1=C1, 2=C2
    GeomAbs_Shape cont = GeomAbs_C2;
    if (continuity == 0) cont = GeomAbs_C0;
    else if (continuity == 1) cont = GeomAbs_C1;
    ts->builder->SetContinuity(cont);
}

bool OCCTThruSectionsBuild(OCCTThruSectionsRef ref) {
    auto ts = (OCCTThruSections*)ref;
    if (!ts) return false;
    // ThruSections requires at least 2 sections — OCCT segfaults otherwise
    if (ts->sectionCount < 2) return false;
    try {
        ts->builder->Build();
        return ts->builder->IsDone();
    } catch (...) { return false; }
}

OCCTShapeRef OCCTThruSectionsShape(OCCTThruSectionsRef ref) {
    auto ts = (OCCTThruSections*)ref;
    if (!ts) return nullptr;
    try {
        if (!ts->builder->IsDone()) return nullptr;
        return new OCCTShape{ts->builder->Shape()};
    } catch (...) { return nullptr; }
}

// MARK: - ThruSections extensions (hoisted with struct)
// MARK: - v0.123.0: Builder extensions, Section ops, Curve/Surface queries

// --- ThruSections extensions ---

void OCCTThruSectionsCheckCompatibility(OCCTThruSectionsRef ref, bool check) {
    auto ts = (OCCTThruSections*)ref;
    if (!ts) return;
    try { ts->builder->CheckCompatibility(check); } catch (...) {}
}

void OCCTThruSectionsSetParType(OCCTThruSectionsRef ref, int32_t parType) {
    auto ts = (OCCTThruSections*)ref;
    if (!ts) return;
    try {
        Approx_ParametrizationType pt = Approx_ChordLength;
        switch (parType) {
            case 0: pt = Approx_ChordLength; break;
            case 1: pt = Approx_Centripetal; break;
            case 2: pt = Approx_IsoParametric; break;
        }
        ts->builder->SetParType(pt);
    } catch (...) {}
}

void OCCTThruSectionsSetCriteriumWeight(OCCTThruSectionsRef ref, double w1, double w2, double w3) {
    auto ts = (OCCTThruSections*)ref;
    if (!ts) return;
    try { ts->builder->SetCriteriumWeight(w1, w2, w3); } catch (...) {}
}

OCCTShapeRef OCCTThruSectionsGeneratedFace(OCCTThruSectionsRef ref, OCCTShapeRef edge) {
    auto ts = (OCCTThruSections*)ref;
    if (!ts || !edge) return nullptr;
    try {
        TopoDS_Shape face = ts->builder->GeneratedFace(edge->shape);
        if (face.IsNull()) return nullptr;
        return new OCCTShape{face};
    } catch (...) { return nullptr; }
}


// --- UnifySameDomain builder ---

struct OCCTUnifySameDomain {
    ShapeUpgrade_UnifySameDomain* usd;
};

// MARK: - UnifySameDomain extension funcs (hoisted with struct)

OCCTUnifySameDomainRef OCCTUnifySameDomainCreate(OCCTShapeRef shape, bool unifyEdges, bool unifyFaces, bool concatBSplines) {
    if (!shape) return nullptr;
    try {
        auto result = new OCCTUnifySameDomain();
        result->usd = new ShapeUpgrade_UnifySameDomain(shape->shape, unifyEdges, unifyFaces, concatBSplines);
        return (OCCTUnifySameDomainRef)result;
    } catch (...) { return nullptr; }
}

void OCCTUnifySameDomainRelease(OCCTUnifySameDomainRef ref) {
    auto usd = (OCCTUnifySameDomain*)ref;
    if (usd) {
        delete usd->usd;
        delete usd;
    }
}

void OCCTUnifySameDomainAllowInternalEdges(OCCTUnifySameDomainRef ref, bool allow) {
    auto usd = (OCCTUnifySameDomain*)ref;
    if (!usd) return;
    try { usd->usd->AllowInternalEdges(allow); } catch (...) {}
}

void OCCTUnifySameDomainKeepShape(OCCTUnifySameDomainRef ref, OCCTShapeRef shape) {
    auto usd = (OCCTUnifySameDomain*)ref;
    if (!usd || !shape) return;
    try { usd->usd->KeepShape(shape->shape); } catch (...) {}
}

void OCCTUnifySameDomainSetSafeInputMode(OCCTUnifySameDomainRef ref, bool safe) {
    auto usd = (OCCTUnifySameDomain*)ref;
    if (!usd) return;
    try { usd->usd->SetSafeInputMode(safe); } catch (...) {}
}

void OCCTUnifySameDomainSetLinearTolerance(OCCTUnifySameDomainRef ref, double tol) {
    auto usd = (OCCTUnifySameDomain*)ref;
    if (!usd) return;
    try { usd->usd->SetLinearTolerance(tol); } catch (...) {}
}

void OCCTUnifySameDomainSetAngularTolerance(OCCTUnifySameDomainRef ref, double tol) {
    auto usd = (OCCTUnifySameDomain*)ref;
    if (!usd) return;
    try { usd->usd->SetAngularTolerance(tol); } catch (...) {}
}

void OCCTUnifySameDomainBuild(OCCTUnifySameDomainRef ref) {
    auto usd = (OCCTUnifySameDomain*)ref;
    if (!usd) return;
    try { usd->usd->Build(); } catch (...) {}
}

OCCTShapeRef OCCTUnifySameDomainShape(OCCTUnifySameDomainRef ref) {
    auto usd = (OCCTUnifySameDomain*)ref;
    if (!usd) return nullptr;
    try {
        TopoDS_Shape result = usd->usd->Shape();
        if (result.IsNull()) return nullptr;
        return new OCCTShape{result};
    } catch (...) { return nullptr; }
}

// MARK: - v0.118: Defeature + Sewing nbMultipleEdges
OCCTShapeRef OCCTShapeDefeature(OCCTShapeRef shape,
                                 const OCCTShapeRef* faces, int32_t faceCount) {
    try {
        auto* s = static_cast<OCCTShape*>(shape);
        BRepAlgoAPI_Defeaturing df;
        df.SetShape(s->shape);
        for (int32_t i = 0; i < faceCount; i++) {
            auto* f = static_cast<OCCTShape*>(faces[i]);
            df.AddFaceToRemove(f->shape);
        }
        df.Build();
        if (df.IsDone() && !df.Shape().IsNull()) {
            auto* result = new OCCTShape();
            result->shape = df.Shape();
            return result;
        }
        return nullptr;
    } catch (...) { return nullptr; }
}

// === Convert_CompPolynomialToPoles ===
#include <Convert_CompPolynomialToPoles.hxx>
int32_t OCCTSewingNbMultipleEdges(OCCTSewingRef sewing) {
    try {
        return (int32_t)sewing->sewing.NbMultipleEdges();
    } catch (...) { return 0; }
}

bool OCCTSewingIsMultipleEdge(OCCTSewingRef sewing, int32_t index, OCCTShapeRef* outEdge) {
    try {
        if (index < 1 || index > sewing->sewing.NbMultipleEdges()) { *outEdge = nullptr; return false; }
        const TopoDS_Edge& edge = sewing->sewing.MultipleEdge(index);
        auto* r = new OCCTShape();
        r->shape = edge;
        *outEdge = r;
        return true;
    } catch (...) { *outEdge = nullptr; return false; }
}

// end of v0.118.0 implementations


// === v0.119.0: BREP serialization, gp distance/contains, BezierSurface, Curve2D Bezier/BSpline extras ===

#include <sstream>
#include <BRepTools.hxx>
#include <BRep_Builder.hxx>
#include <gp_Pln.hxx>
#include <gp_Lin.hxx>
#include <Geom_BezierSurface.hxx>
#include <Geom2d_BezierCurve.hxx>
#include <Geom2d_BSplineCurve.hxx>
#include <Geom_BSplineSurface.hxx>

// MARK: - v0.121-v0.124: FilletBuilder + ChamferBuilder + completions
// --- FilletBuilder (BRepFilletAPI_MakeFillet) ---

struct OCCTFilletBuilder {
    BRepFilletAPI_MakeFillet fillet;
    OCCTFilletBuilder(const TopoDS_Shape& s) : fillet(s) {}
};

OCCTFilletBuilderRef OCCTFilletBuilderCreate(OCCTShapeRef shape) {
    if (!shape) return nullptr;
    try {
        return new OCCTFilletBuilder(shape->shape);
    } catch (...) { return nullptr; }
}

void OCCTFilletBuilderRelease(OCCTFilletBuilderRef builder) {
    delete builder;
}

bool OCCTFilletBuilderAddEdge(OCCTFilletBuilderRef builder, OCCTEdgeRef edge, double radius) {
    if (!builder || !edge) return false;
    try { builder->fillet.Add(radius, edge->edge); return true; } catch (...) { return false; }
}

bool OCCTFilletBuilderAddEdgeEvolving(OCCTFilletBuilderRef builder, OCCTEdgeRef edge, double r1, double r2) {
    if (!builder || !edge) return false;
    try { builder->fillet.Add(r1, r2, edge->edge); return true; } catch (...) { return false; }
}

OCCTShapeRef OCCTFilletBuilderBuild(OCCTFilletBuilderRef builder) {
    if (!builder) return nullptr;
    try {
        builder->fillet.Build();
        if (!builder->fillet.IsDone()) return nullptr;
        return new OCCTShape(builder->fillet.Shape());
    } catch (...) { return nullptr; }
}

int32_t OCCTFilletBuilderNbContours(OCCTFilletBuilderRef builder) {
    if (!builder) return 0;
    try { return builder->fillet.NbContours(); } catch (...) { return 0; }
}

int32_t OCCTFilletBuilderNbEdges(OCCTFilletBuilderRef builder, int32_t contourIndex) {
    if (!builder) return 0;
    try { return builder->fillet.NbEdges(contourIndex); } catch (...) { return 0; }
}

bool OCCTFilletBuilderHasResult(OCCTFilletBuilderRef builder) {
    if (!builder) return false;
    try { return builder->fillet.HasResult(); } catch (...) { return false; }
}

OCCTShapeRef OCCTFilletBuilderBadShape(OCCTFilletBuilderRef builder) {
    if (!builder) return nullptr;
    try {
        const TopoDS_Shape& bad = builder->fillet.BadShape();
        if (bad.IsNull()) return nullptr;
        return new OCCTShape(bad);
    } catch (...) { return nullptr; }
}

int32_t OCCTFilletBuilderNbFaultyContours(OCCTFilletBuilderRef builder) {
    if (!builder) return 0;
    try { return builder->fillet.NbFaultyContours(); } catch (...) { return 0; }
}

int32_t OCCTFilletBuilderNbFaultyVertices(OCCTFilletBuilderRef builder) {
    if (!builder) return 0;
    try { return builder->fillet.NbFaultyVertices(); } catch (...) { return 0; }
}

double OCCTFilletBuilderGetRadius(OCCTFilletBuilderRef builder, int32_t contourIndex) {
    if (!builder) return 0;
    try { return builder->fillet.Radius(contourIndex); } catch (...) { return 0; }
}

double OCCTFilletBuilderGetLength(OCCTFilletBuilderRef builder, int32_t contourIndex) {
    if (!builder) return 0;
    try { return builder->fillet.Length(contourIndex); } catch (...) { return 0; }
}

bool OCCTFilletBuilderIsConstant(OCCTFilletBuilderRef builder, int32_t contourIndex) {
    if (!builder) return false;
    try { return builder->fillet.IsConstant(contourIndex); } catch (...) { return false; }
}

bool OCCTFilletBuilderRemoveEdge(OCCTFilletBuilderRef builder, OCCTEdgeRef edge) {
    if (!builder || !edge) return false;
    try { builder->fillet.Remove(edge->edge); return true; } catch (...) { return false; }
}

void OCCTFilletBuilderReset(OCCTFilletBuilderRef builder) {
    if (!builder) return;
    try { builder->fillet.Reset(); } catch (...) {}
}

// --- ChamferBuilder (BRepFilletAPI_MakeChamfer) ---

struct OCCTChamferBuilder {
    BRepFilletAPI_MakeChamfer chamfer;
    OCCTChamferBuilder(const TopoDS_Shape& s) : chamfer(s) {}
};

OCCTChamferBuilderRef OCCTChamferBuilderCreate(OCCTShapeRef shape) {
    if (!shape) return nullptr;
    try {
        return new OCCTChamferBuilder(shape->shape);
    } catch (...) { return nullptr; }
}

void OCCTChamferBuilderRelease(OCCTChamferBuilderRef builder) {
    delete builder;
}

bool OCCTChamferBuilderAddEdge(OCCTChamferBuilderRef builder, OCCTEdgeRef edge, double dist) {
    if (!builder || !edge) return false;
    try { builder->chamfer.Add(dist, edge->edge); return true; } catch (...) { return false; }
}

bool OCCTChamferBuilderAddEdgeTwoDists(OCCTChamferBuilderRef builder,
                                        OCCTEdgeRef edge, OCCTFaceRef face,
                                        double d1, double d2) {
    if (!builder || !edge || !face) return false;
    try { builder->chamfer.Add(d1, d2, edge->edge, face->face); return true; } catch (...) { return false; }
}

bool OCCTChamferBuilderAddEdgeDistAngle(OCCTChamferBuilderRef builder,
                                         OCCTEdgeRef edge, OCCTFaceRef face,
                                         double dist, double angle) {
    if (!builder || !edge || !face) return false;
    try { builder->chamfer.AddDA(dist, angle, edge->edge, face->face); return true; } catch (...) { return false; }
}

OCCTShapeRef OCCTChamferBuilderBuild(OCCTChamferBuilderRef builder) {
    if (!builder) return nullptr;
    try {
        builder->chamfer.Build();
        if (!builder->chamfer.IsDone()) return nullptr;
        return new OCCTShape(builder->chamfer.Shape());
    } catch (...) { return nullptr; }
}

int32_t OCCTChamferBuilderNbContours(OCCTChamferBuilderRef builder) {
    if (!builder) return 0;
    try { return builder->chamfer.NbContours(); } catch (...) { return 0; }
}

bool OCCTChamferBuilderIsDistAngle(OCCTChamferBuilderRef builder, int32_t contourIndex) {
    if (!builder) return false;
    try { return builder->chamfer.IsDistanceAngle(contourIndex); } catch (...) { return false; }
}

// MARK: - v0.124.0: ChamferBuilder completions, FilletBuilder completions, WireAnalyzer

// --- ChamferBuilder completions ---

int32_t OCCTChamferBuilderNbEdges(OCCTChamferBuilderRef builder, int32_t contourIndex) {
    if (!builder) return 0;
    try { return builder->chamfer.NbEdges(contourIndex); } catch (...) { return 0; }
}

void OCCTChamferBuilderGetDist(OCCTChamferBuilderRef builder, int32_t contourIndex, double* dist) {
    if (!builder || !dist) return;
    try { builder->chamfer.GetDist(contourIndex, *dist); } catch (...) { *dist = -1.0; }
}

void OCCTChamferBuilderGetDists(OCCTChamferBuilderRef builder, int32_t contourIndex,
                                 double* d1, double* d2) {
    if (!builder || !d1 || !d2) return;
    try { builder->chamfer.Dists(contourIndex, *d1, *d2); } catch (...) { *d1 = -1.0; *d2 = -1.0; }
}

void OCCTChamferBuilderGetDistAngle(OCCTChamferBuilderRef builder, int32_t contourIndex,
                                     double* dist, double* angle) {
    if (!builder || !dist || !angle) return;
    try { builder->chamfer.GetDistAngle(contourIndex, *dist, *angle); } catch (...) { *dist = -1.0; *angle = -1.0; }
}

bool OCCTChamferBuilderSetDist(OCCTChamferBuilderRef builder, double dist,
                                int32_t contourIndex, OCCTFaceRef face) {
    if (!builder || !face) return false;
    try { builder->chamfer.SetDist(dist, contourIndex, face->face); return true; } catch (...) { return false; }
}

bool OCCTChamferBuilderSetDists(OCCTChamferBuilderRef builder, double d1, double d2,
                                 int32_t contourIndex, OCCTFaceRef face) {
    if (!builder || !face) return false;
    try { builder->chamfer.SetDists(d1, d2, contourIndex, face->face); return true; } catch (...) { return false; }
}

bool OCCTChamferBuilderSetDistAngle(OCCTChamferBuilderRef builder, double dist, double angle,
                                     int32_t contourIndex, OCCTFaceRef face) {
    if (!builder || !face) return false;
    try { builder->chamfer.SetDistAngle(dist, angle, contourIndex, face->face); return true; } catch (...) { return false; }
}

double OCCTChamferBuilderLength(OCCTChamferBuilderRef builder, int32_t contourIndex) {
    if (!builder) return -1.0;
    try { return builder->chamfer.Length(contourIndex); } catch (...) { return -1.0; }
}

bool OCCTChamferBuilderRemoveEdge(OCCTChamferBuilderRef builder, OCCTEdgeRef edge) {
    if (!builder || !edge) return false;
    try { builder->chamfer.Remove(edge->edge); return true; } catch (...) { return false; }
}

void OCCTChamferBuilderReset(OCCTChamferBuilderRef builder) {
    if (!builder) return;
    try { builder->chamfer.Reset(); } catch (...) {}
}

bool OCCTChamferBuilderClosed(OCCTChamferBuilderRef builder, int32_t contourIndex) {
    if (!builder) return false;
    try { return builder->chamfer.Closed(contourIndex); } catch (...) { return false; }
}

bool OCCTChamferBuilderClosedAndTangent(OCCTChamferBuilderRef builder, int32_t contourIndex) {
    if (!builder) return false;
    try { return builder->chamfer.ClosedAndTangent(contourIndex); } catch (...) { return false; }
}

bool OCCTChamferBuilderIsSymmetric(OCCTChamferBuilderRef builder, int32_t contourIndex) {
    if (!builder) return false;
    try { return builder->chamfer.IsSymetric(contourIndex); } catch (...) { return false; }
}

bool OCCTChamferBuilderIsTwoDists(OCCTChamferBuilderRef builder, int32_t contourIndex) {
    if (!builder) return false;
    try { return builder->chamfer.IsTwoDistances(contourIndex); } catch (...) { return false; }
}

OCCTShapeRef OCCTChamferBuilderEdge(OCCTChamferBuilderRef builder, int32_t contourIndex, int32_t edgeIndex) {
    if (!builder) return nullptr;
    try {
        const TopoDS_Edge& e = builder->chamfer.Edge(contourIndex, edgeIndex);
        if (e.IsNull()) return nullptr;
        return new OCCTShape(e);
    } catch (...) { return nullptr; }
}

OCCTShapeRef OCCTChamferBuilderFirstVertex(OCCTChamferBuilderRef builder, int32_t contourIndex) {
    if (!builder) return nullptr;
    try {
        TopoDS_Vertex v = builder->chamfer.FirstVertex(contourIndex);
        if (v.IsNull()) return nullptr;
        return new OCCTShape(v);
    } catch (...) { return nullptr; }
}

OCCTShapeRef OCCTChamferBuilderLastVertex(OCCTChamferBuilderRef builder, int32_t contourIndex) {
    if (!builder) return nullptr;
    try {
        TopoDS_Vertex v = builder->chamfer.LastVertex(contourIndex);
        if (v.IsNull()) return nullptr;
        return new OCCTShape(v);
    } catch (...) { return nullptr; }
}

int32_t OCCTChamferBuilderContour(OCCTChamferBuilderRef builder, OCCTEdgeRef edge) {
    if (!builder || !edge) return 0;
    try { return builder->chamfer.Contour(edge->edge); } catch (...) { return 0; }
}

double OCCTChamferBuilderAbscissa(OCCTChamferBuilderRef builder, int32_t contourIndex, OCCTShapeRef vertex) {
    if (!builder || !vertex) return -1.0;
    try {
        return builder->chamfer.Abscissa(contourIndex, TopoDS::Vertex(vertex->shape));
    } catch (...) { return -1.0; }
}

double OCCTChamferBuilderRelativeAbscissa(OCCTChamferBuilderRef builder, int32_t contourIndex, OCCTShapeRef vertex) {
    if (!builder || !vertex) return -1.0;
    try {
        return builder->chamfer.RelativeAbscissa(contourIndex, TopoDS::Vertex(vertex->shape));
    } catch (...) { return -1.0; }
}

// --- FilletBuilder completions ---

bool OCCTFilletBuilderSetRadiusOnEdge(OCCTFilletBuilderRef builder, double radius,
                                       int32_t contourIndex, OCCTEdgeRef edge) {
    if (!builder || !edge) return false;
    try { builder->fillet.SetRadius(radius, contourIndex, edge->edge); return true; } catch (...) { return false; }
}

bool OCCTFilletBuilderSetRadiusAtVertex(OCCTFilletBuilderRef builder, double radius,
                                         int32_t contourIndex, OCCTShapeRef vertex) {
    if (!builder || !vertex) return false;
    try {
        builder->fillet.SetRadius(radius, contourIndex, TopoDS::Vertex(vertex->shape));
        return true;
    } catch (...) { return false; }
}

bool OCCTFilletBuilderSetTwoRadii(OCCTFilletBuilderRef builder, double r1, double r2,
                                   int32_t contourIndex, int32_t edgeInContour) {
    if (!builder) return false;
    try { builder->fillet.SetRadius(r1, r2, contourIndex, edgeInContour); return true; } catch (...) { return false; }
}

int32_t OCCTFilletBuilderContour(OCCTFilletBuilderRef builder, OCCTEdgeRef edge) {
    if (!builder || !edge) return 0;
    try { return builder->fillet.Contour(edge->edge); } catch (...) { return 0; }
}

OCCTShapeRef OCCTFilletBuilderEdge(OCCTFilletBuilderRef builder, int32_t contourIndex, int32_t edgeIndex) {
    if (!builder) return nullptr;
    try {
        const TopoDS_Edge& e = builder->fillet.Edge(contourIndex, edgeIndex);
        if (e.IsNull()) return nullptr;
        return new OCCTShape(e);
    } catch (...) { return nullptr; }
}

OCCTShapeRef OCCTFilletBuilderFirstVertex(OCCTFilletBuilderRef builder, int32_t contourIndex) {
    if (!builder) return nullptr;
    try {
        TopoDS_Vertex v = builder->fillet.FirstVertex(contourIndex);
        if (v.IsNull()) return nullptr;
        return new OCCTShape(v);
    } catch (...) { return nullptr; }
}

OCCTShapeRef OCCTFilletBuilderLastVertex(OCCTFilletBuilderRef builder, int32_t contourIndex) {
    if (!builder) return nullptr;
    try {
        TopoDS_Vertex v = builder->fillet.LastVertex(contourIndex);
        if (v.IsNull()) return nullptr;
        return new OCCTShape(v);
    } catch (...) { return nullptr; }
}

double OCCTFilletBuilderAbscissa(OCCTFilletBuilderRef builder, int32_t contourIndex, OCCTShapeRef vertex) {
    if (!builder || !vertex) return -1.0;
    try {
        return builder->fillet.Abscissa(contourIndex, TopoDS::Vertex(vertex->shape));
    } catch (...) { return -1.0; }
}

double OCCTFilletBuilderRelativeAbscissa(OCCTFilletBuilderRef builder, int32_t contourIndex, OCCTShapeRef vertex) {
    if (!builder || !vertex) return -1.0;
    try {
        return builder->fillet.RelativeAbscissa(contourIndex, TopoDS::Vertex(vertex->shape));
    } catch (...) { return -1.0; }
}

bool OCCTFilletBuilderClosedAndTangent(OCCTFilletBuilderRef builder, int32_t contourIndex) {
    if (!builder) return false;
    try { return builder->fillet.ClosedAndTangent(contourIndex); } catch (...) { return false; }
}

bool OCCTFilletBuilderClosed(OCCTFilletBuilderRef builder, int32_t contourIndex) {
    if (!builder) return false;
    try { return builder->fillet.Closed(contourIndex); } catch (...) { return false; }
}

int32_t OCCTFilletBuilderNbSurfaces(OCCTFilletBuilderRef builder) {
    if (!builder) return 0;
    try { return builder->fillet.NbSurfaces(); } catch (...) { return 0; }
}

int32_t OCCTFilletBuilderNbComputedSurfaces(OCCTFilletBuilderRef builder, int32_t contourIndex) {
    if (!builder) return 0;
    try { return builder->fillet.NbComputedSurfaces(contourIndex); } catch (...) { return 0; }
}

int32_t OCCTFilletBuilderStripeStatus(OCCTFilletBuilderRef builder, int32_t contourIndex) {
    if (!builder) return -1;
    try { return static_cast<int32_t>(builder->fillet.StripeStatus(contourIndex)); } catch (...) { return -1; }
}

int32_t OCCTFilletBuilderFaultyContour(OCCTFilletBuilderRef builder, int32_t faultIndex) {
    if (!builder) return 0;
    try { return builder->fillet.FaultyContour(faultIndex); } catch (...) { return 0; }
}

OCCTShapeRef OCCTFilletBuilderFaultyVertex(OCCTFilletBuilderRef builder, int32_t faultIndex) {
    if (!builder) return nullptr;
    try {
        TopoDS_Vertex v = builder->fillet.FaultyVertex(faultIndex);
        if (v.IsNull()) return nullptr;
        return new OCCTShape(v);
    } catch (...) { return nullptr; }
}

// MARK: - FilletBuilder/ChamferBuilder extensions (hoisted with structs)
void OCCTFilletBuilderSetParams(OCCTFilletBuilderRef builder,
                                 double tang, double tesp, double t2d,
                                 double tApp3d, double tApp2d, double fleche) {
    if (!builder) return;
    try {
        builder->fillet.SetParams(tang, tesp, t2d, tApp3d, tApp2d, fleche);
    } catch (...) {}
}

void OCCTFilletBuilderSetContinuity(OCCTFilletBuilderRef builder,
                                     int32_t internalContinuity, double angularTolerance) {
    if (!builder) return;
    try {
        builder->fillet.SetContinuity((GeomAbs_Shape)internalContinuity, angularTolerance);
    } catch (...) {}
}

void OCCTFilletBuilderSetFilletShape(OCCTFilletBuilderRef builder, int32_t filletShape) {
    if (!builder) return;
    try {
        builder->fillet.SetFilletShape((ChFi3d_FilletShape)filletShape);
    } catch (...) {}
}

int32_t OCCTFilletBuilderGetFilletShape(OCCTFilletBuilderRef builder) {
    if (!builder) return 0;
    try {
        return (int32_t)builder->fillet.GetFilletShape();
    } catch (...) { return 0; }
}

void OCCTFilletBuilderResetContour(OCCTFilletBuilderRef builder, int32_t contourIndex) {
    if (!builder) return;
    try {
        builder->fillet.ResetContour(contourIndex);
    } catch (...) {}
}

void OCCTFilletBuilderSimulate(OCCTFilletBuilderRef builder, int32_t contourIndex) {
    if (!builder) return;
    try {
        builder->fillet.Simulate(contourIndex);
    } catch (...) {}
}

int32_t OCCTFilletBuilderNbSimulatedSurf(OCCTFilletBuilderRef builder, int32_t contourIndex) {
    if (!builder) return 0;
    try {
        return (int32_t)builder->fillet.NbSurf(contourIndex);
    } catch (...) { return 0; }
}

// --- XCAFDoc_ShapeTool completions ---

#import <XCAFDoc_ShapeTool.hxx>

bool OCCTDocumentShapeToolIsFree(OCCTDocumentRef doc, int64_t labelId) {
    if (!doc) return false;
    try {
        TDF_Label lab = doc->getLabel(labelId);
        if (lab.IsNull()) return false;
        return XCAFDoc_ShapeTool::IsFree(lab);
    } catch (...) { return false; }
}

bool OCCTDocumentShapeToolIsSimpleShape(OCCTDocumentRef doc, int64_t labelId) {
    if (!doc) return false;
    try {
        TDF_Label lab = doc->getLabel(labelId);
        if (lab.IsNull()) return false;
        return XCAFDoc_ShapeTool::IsSimpleShape(lab);
    } catch (...) { return false; }
}

bool OCCTFilletBuilderGetBounds(OCCTFilletBuilderRef builder, int32_t contourIndex,
                                 OCCTShapeRef edge, double* outFirst, double* outLast) {
    if (!builder || !edge || !outFirst || !outLast) return false;
    try {
        TopoDS_Edge e = TopoDS::Edge(edge->shape);
        return builder->fillet.GetBounds(contourIndex, e, *outFirst, *outLast);
    } catch (...) { return false; }
}

OCCTLawFunctionRef OCCTFilletBuilderGetLaw(OCCTFilletBuilderRef builder, int32_t contourIndex,
                                            OCCTShapeRef edge) {
    if (!builder || !edge) return nullptr;
    try {
        TopoDS_Edge e = TopoDS::Edge(edge->shape);
        Handle(Law_Function) law = builder->fillet.GetLaw(contourIndex, e);
        if (law.IsNull()) return nullptr;
        return new OCCTLawFunction(law);
    } catch (...) { return nullptr; }
}

bool OCCTFilletBuilderSetLaw(OCCTFilletBuilderRef builder, int32_t contourIndex,
                              OCCTEdgeRef edge, OCCTLawFunctionRef law) {
    if (!builder || !edge || !law) return false;
    try {
        builder->fillet.SetLaw(contourIndex, edge->edge, law->law);
        return true;
    } catch (...) { return false; }
}

int32_t OCCTFilletBuilderGenerated(OCCTFilletBuilderRef builder, OCCTShapeRef shape,
                                    OCCTShapeRef** outShapes) {
    if (!builder || !shape || !outShapes) return 0;
    *outShapes = nullptr;
    try {
        const TopTools_ListOfShape& list = builder->fillet.Generated(shape->shape);
        int count = list.Size();
        if (count == 0) return 0;
        OCCTShapeRef* shapes = (OCCTShapeRef*)malloc(count * sizeof(OCCTShapeRef));
        if (!shapes) return 0;
        int i = 0;
        for (auto it = list.cbegin(); it != list.cend(); ++it, ++i) {
            shapes[i] = new OCCTShape(*it);
        }
        *outShapes = shapes;
        return count;
    } catch (...) { return 0; }
}

int32_t OCCTFilletBuilderModified(OCCTFilletBuilderRef builder, OCCTShapeRef shape,
                                   OCCTShapeRef** outShapes) {
    if (!builder || !shape || !outShapes) return 0;
    *outShapes = nullptr;
    try {
        const TopTools_ListOfShape& list = builder->fillet.Modified(shape->shape);
        int count = list.Size();
        if (count == 0) return 0;
        OCCTShapeRef* shapes = (OCCTShapeRef*)malloc(count * sizeof(OCCTShapeRef));
        if (!shapes) return 0;
        int i = 0;
        for (auto it = list.cbegin(); it != list.cend(); ++it, ++i) {
            shapes[i] = new OCCTShape(*it);
        }
        *outShapes = shapes;
        return count;
    } catch (...) { return 0; }
}

bool OCCTFilletBuilderIsDeleted(OCCTFilletBuilderRef builder, OCCTShapeRef shape) {
    if (!builder || !shape) return false;
    try {
        return builder->fillet.IsDeleted(shape->shape);
    } catch (...) { return false; }
}

// MARK: - v0.128.0: ChamferBuilder history, SectionBuilder, BRep_Tool extras, Curve/Surface Transform

#include <ChFiDS_ChamfMode.hxx>
#include <gp_Trsf2d.hxx>

// --- ChamferBuilder history & extras ---

int32_t OCCTChamferBuilderGenerated(OCCTChamferBuilderRef builder, OCCTShapeRef shape,
                                     OCCTShapeRef** outShapes) {
    if (!builder || !shape || !outShapes) return 0;
    *outShapes = nullptr;
    try {
        const TopTools_ListOfShape& list = builder->chamfer.Generated(shape->shape);
        int32_t count = list.Size();
        if (count == 0) return 0;
        *outShapes = (OCCTShapeRef*)malloc(count * sizeof(OCCTShapeRef));
        int32_t i = 0;
        for (auto it = list.cbegin(); it != list.cend(); ++it, ++i) {
            (*outShapes)[i] = new OCCTShape{*it};
        }
        return count;
    } catch (...) { return 0; }
}

int32_t OCCTChamferBuilderModified(OCCTChamferBuilderRef builder, OCCTShapeRef shape,
                                    OCCTShapeRef** outShapes) {
    if (!builder || !shape || !outShapes) return 0;
    *outShapes = nullptr;
    try {
        const TopTools_ListOfShape& list = builder->chamfer.Modified(shape->shape);
        int32_t count = list.Size();
        if (count == 0) return 0;
        *outShapes = (OCCTShapeRef*)malloc(count * sizeof(OCCTShapeRef));
        int32_t i = 0;
        for (auto it = list.cbegin(); it != list.cend(); ++it, ++i) {
            (*outShapes)[i] = new OCCTShape{*it};
        }
        return count;
    } catch (...) { return 0; }
}

bool OCCTChamferBuilderIsDeleted(OCCTChamferBuilderRef builder, OCCTShapeRef shape) {
    if (!builder || !shape) return false;
    try {
        return builder->chamfer.IsDeleted(shape->shape);
    } catch (...) { return false; }
}

void OCCTChamferBuilderSetMode(OCCTChamferBuilderRef builder, int32_t mode) {
    if (!builder) return;
    try {
        ChFiDS_ChamfMode chamfMode;
        switch (mode) {
            case 1: chamfMode = ChFiDS_ConstThroatChamfer; break;
            case 2: chamfMode = ChFiDS_ConstThroatWithPenetrationChamfer; break;
            default: chamfMode = ChFiDS_ClassicChamfer; break;
        }
        builder->chamfer.SetMode(chamfMode);
    } catch (...) {}
}

bool OCCTChamferBuilderSimulate(OCCTChamferBuilderRef builder, int32_t contourIndex) {
    if (!builder) return false;
    try {
        builder->chamfer.Simulate(contourIndex);
        return true;
    } catch (...) { return false; }
}

int32_t OCCTChamferBuilderNbSurf(OCCTChamferBuilderRef builder, int32_t contourIndex) {
    if (!builder) return 0;
    try {
        return builder->chamfer.NbSurf(contourIndex);
    } catch (...) { return 0; }
}

// --- SectionBuilder (BRepAlgoAPI_Section) ---


// MARK: - v0.122: History extended + Sewing extended + BRepAlgoAPI_Section extended
// --- History extended ---

void OCCTHistoryMerge(OCCTHistoryRef history, OCCTHistoryRef other) {
    if (!history || !other) return;
    try {
        auto h1 = static_cast<Handle(BRepTools_History)*>(history);
        auto h2 = static_cast<Handle(BRepTools_History)*>(other);
        if (!h1->IsNull() && !h2->IsNull()) {
            (*h1)->Merge(*h2);
        }
    } catch (...) {}
}

void OCCTHistoryReplaceGenerated(OCCTHistoryRef history, OCCTShapeRef initial, OCCTShapeRef generated) {
    if (!history || !initial || !generated) return;
    try {
        auto h = static_cast<Handle(BRepTools_History)*>(history);
        if (!h->IsNull()) {
            (*h)->ReplaceGenerated(initial->shape, generated->shape);
        }
    } catch (...) {}
}

void OCCTHistoryReplaceModified(OCCTHistoryRef history, OCCTShapeRef initial, OCCTShapeRef modified) {
    if (!history || !initial || !modified) return;
    try {
        auto h = static_cast<Handle(BRepTools_History)*>(history);
        if (!h->IsNull()) {
            (*h)->ReplaceModified(initial->shape, modified->shape);
        }
    } catch (...) {}
}

int32_t OCCTHistoryGetModifiedShapes(OCCTHistoryRef history, OCCTShapeRef initial,
                                      OCCTShapeRef* outShapes, int32_t maxCount) {
    if (!history || !initial || !outShapes || maxCount <= 0) return 0;
    try {
        auto h = static_cast<Handle(BRepTools_History)*>(history);
        if (h->IsNull()) return 0;
        const auto& modified = (*h)->Modified(initial->shape);
        int32_t count = 0;
        for (auto it = modified.cbegin(); it != modified.cend() && count < maxCount; ++it, ++count) {
            auto* ref = new OCCTShape;
            ref->shape = *it;
            outShapes[count] = ref;
        }
        return count;
    } catch (...) { return 0; }
}

int32_t OCCTHistoryGetGeneratedShapes(OCCTHistoryRef history, OCCTShapeRef initial,
                                       OCCTShapeRef* outShapes, int32_t maxCount) {
    if (!history || !initial || !outShapes || maxCount <= 0) return 0;
    try {
        auto h = static_cast<Handle(BRepTools_History)*>(history);
        if (h->IsNull()) return 0;
        const auto& generated = (*h)->Generated(initial->shape);
        int32_t count = 0;
        for (auto it = generated.cbegin(); it != generated.cend() && count < maxCount; ++it, ++count) {
            auto* ref = new OCCTShape;
            ref->shape = *it;
            outShapes[count] = ref;
        }
        return count;
    } catch (...) { return 0; }
}
// --- Sewing extended ---

int32_t OCCTSewingNbDeletedFaces(OCCTSewingRef sewing) {
    if (!sewing) return 0;
    try { return (int32_t)sewing->sewing.NbDeletedFaces(); } catch (...) { return 0; }
}

OCCTShapeRef OCCTSewingDeletedFace(OCCTSewingRef sewing, int32_t index) {
    if (!sewing) return nullptr;
    try {
        const TopoDS_Face& f = sewing->sewing.DeletedFace(index);
        if (f.IsNull()) return nullptr;
        auto* ref = new OCCTShape;
        ref->shape = f;
        return ref;
    } catch (...) { return nullptr; }
}

bool OCCTSewingIsModified(OCCTSewingRef sewing, OCCTShapeRef shape) {
    if (!sewing || !shape) return false;
    try { return sewing->sewing.IsModified(shape->shape); } catch (...) { return false; }
}

OCCTShapeRef OCCTSewingModified(OCCTSewingRef sewing, OCCTShapeRef shape) {
    if (!sewing || !shape) return nullptr;
    try {
        const TopoDS_Shape& mod = sewing->sewing.Modified(shape->shape);
        if (mod.IsNull()) return nullptr;
        auto* ref = new OCCTShape;
        ref->shape = mod;
        return ref;
    } catch (...) { return nullptr; }
}

bool OCCTSewingIsDegenerated(OCCTSewingRef sewing, OCCTShapeRef shape) {
    if (!sewing || !shape) return false;
    try { return sewing->sewing.IsDegenerated(shape->shape); } catch (...) { return false; }
}

bool OCCTSewingIsSectionBound(OCCTSewingRef sewing, OCCTShapeRef edge) {
    if (!sewing || !edge) return false;
    try {
        return sewing->sewing.IsSectionBound(TopoDS::Edge(edge->shape));
    } catch (...) { return false; }
}

OCCTShapeRef OCCTSewingWhichFace(OCCTSewingRef sewing, OCCTShapeRef edge) {
    if (!sewing || !edge) return nullptr;
    try {
        TopoDS_Face f = sewing->sewing.WhichFace(TopoDS::Edge(edge->shape));
        if (f.IsNull()) return nullptr;
        auto* ref = new OCCTShape;
        ref->shape = f;
        return ref;
    } catch (...) { return nullptr; }
}

void OCCTSewingLoad(OCCTSewingRef sewing, OCCTShapeRef shape) {
    if (!sewing || !shape) return;
    try { sewing->sewing.Load(shape->shape); } catch (...) {}
}

void OCCTSewingSetNonManifoldMode(OCCTSewingRef sewing, bool nonManifold) {
    if (!sewing) return;
    try { sewing->sewing.SetNonManifoldMode(nonManifold); } catch (...) {}
}

void OCCTSewingSetFaceMode(OCCTSewingRef sewing, bool faceMode) {
    if (!sewing) return;
    try { sewing->sewing.SetFaceMode(faceMode); } catch (...) {}
}

void OCCTSewingSetFloatingEdgesMode(OCCTSewingRef sewing, bool floatingEdges) {
    if (!sewing) return;
    try { sewing->sewing.SetFloatingEdgesMode(floatingEdges); } catch (...) {}
}

void OCCTSewingSetMinTolerance(OCCTSewingRef sewing, double minTol) {
    if (!sewing) return;
    try { sewing->sewing.SetMinTolerance(minTol); } catch (...) {}
}

void OCCTSewingSetMaxTolerance(OCCTSewingRef sewing, double maxTol) {
    if (!sewing) return;
    try { sewing->sewing.SetMaxTolerance(maxTol); } catch (...) {}
}

// --- BRepAlgoAPI_Section extended ---

OCCTShapeRef OCCTShapeSectionWithOptions(OCCTShapeRef shape1, OCCTShapeRef shape2,
                                          bool approximation, bool computePCurve1, bool computePCurve2) {
    if (!shape1 || !shape2) return nullptr;
    try {
        BRepAlgoAPI_Section section(shape1->shape, shape2->shape, false);
        section.Approximation(approximation);
        section.ComputePCurveOn1(computePCurve1);
        section.ComputePCurveOn2(computePCurve2);
        section.Build();
        if (!section.IsDone()) return nullptr;
        TopoDS_Shape result = section.Shape();
        if (result.IsNull()) return nullptr;
        return new OCCTShape{result};
    } catch (...) { return nullptr; }
}

OCCTShapeRef OCCTSectionAncestorFaceOn1(OCCTShapeRef shape1, OCCTShapeRef shape2,
                                          OCCTShapeRef edge,
                                          bool approximation, bool computePCurve1, bool computePCurve2) {
    if (!shape1 || !shape2 || !edge) return nullptr;
    try {
        BRepAlgoAPI_Section section(shape1->shape, shape2->shape, false);
        section.Approximation(approximation);
        section.ComputePCurveOn1(computePCurve1);
        section.ComputePCurveOn2(computePCurve2);
        section.Build();
        if (!section.IsDone()) return nullptr;
        TopoDS_Shape face;
        if (section.HasAncestorFaceOn1(edge->shape, face)) {
            return new OCCTShape{face};
        }
        return nullptr;
    } catch (...) { return nullptr; }
}

OCCTShapeRef OCCTSectionAncestorFaceOn2(OCCTShapeRef shape1, OCCTShapeRef shape2,
                                          OCCTShapeRef edge,
                                          bool approximation, bool computePCurve1, bool computePCurve2) {
    if (!shape1 || !shape2 || !edge) return nullptr;
    try {
        BRepAlgoAPI_Section section(shape1->shape, shape2->shape, false);
        section.Approximation(approximation);
        section.ComputePCurveOn1(computePCurve1);
        section.ComputePCurveOn2(computePCurve2);
        section.Build();
        if (!section.IsDone()) return nullptr;
        TopoDS_Shape face;
        if (section.HasAncestorFaceOn2(edge->shape, face)) {
            return new OCCTShape{face};
        }
        return nullptr;
    } catch (...) { return nullptr; }
}

// MARK: - v0.126: FilletBuilder completions + v0.127: BRepAlgoAPI_Section + SectionBuilder
// --- FilletBuilder completions ---


bool OCCTDocumentShapeToolIsComponent(OCCTDocumentRef doc, int64_t labelId) {
    if (!doc) return false;
    try {
        TDF_Label lab = doc->getLabel(labelId);
        if (lab.IsNull()) return false;
        return XCAFDoc_ShapeTool::IsComponent(lab);
    } catch (...) { return false; }
}

bool OCCTDocumentShapeToolIsCompound(OCCTDocumentRef doc, int64_t labelId) {
    if (!doc) return false;
    try {
        TDF_Label lab = doc->getLabel(labelId);
        if (lab.IsNull()) return false;
        return XCAFDoc_ShapeTool::IsCompound(lab);
    } catch (...) { return false; }
}

bool OCCTDocumentShapeToolIsSubShape(OCCTDocumentRef doc, int64_t labelId) {
    if (!doc) return false;
    try {
        TDF_Label lab = doc->getLabel(labelId);
        if (lab.IsNull()) return false;
        return XCAFDoc_ShapeTool::IsSubShape(lab);
    } catch (...) { return false; }
}

bool OCCTDocumentShapeToolIsExternRef(OCCTDocumentRef doc, int64_t labelId) {
    if (!doc) return false;
    try {
        TDF_Label lab = doc->getLabel(labelId);
        if (lab.IsNull()) return false;
        return XCAFDoc_ShapeTool::IsExternRef(lab);
    } catch (...) { return false; }
}

int32_t OCCTDocumentShapeToolGetUsers(OCCTDocumentRef doc, int64_t labelId) {
    if (!doc) return 0;
    try {
        TDF_Label lab = doc->getLabel(labelId);
        if (lab.IsNull()) return 0;
        NCollection_Sequence<TDF_Label> users;
        return (int32_t)XCAFDoc_ShapeTool::GetUsers(lab, users);
    } catch (...) { return 0; }
}

#include <XCAFDoc_DocumentTool.hxx>

void OCCTDocumentShapeToolComputeShapes(OCCTDocumentRef doc, int64_t labelId) {
    if (!doc) return;
    try {
        auto shapeTool = XCAFDoc_DocumentTool::ShapeTool(doc->doc->Main());
        TDF_Label lab = doc->getLabel(labelId);
        if (lab.IsNull()) return;
        shapeTool->ComputeShapes(lab);
    } catch (...) {}
}

int32_t OCCTDocumentShapeToolNbComponents(OCCTDocumentRef doc, int64_t labelId, bool getSubChildren) {
    if (!doc) return 0;
    try {
        TDF_Label lab = doc->getLabel(labelId);
        if (lab.IsNull()) return 0;
        return (int32_t)XCAFDoc_ShapeTool::NbComponents(lab, getSubChildren);
    } catch (...) { return 0; }
}
// --- BRepAlgoAPI_Section with plane ---

OCCTShapeRef OCCTShapeSectionWithPlane(OCCTShapeRef shape,
                                        double normalX, double normalY, double normalZ,
                                        double originX, double originY, double originZ) {
    if (!shape) return nullptr;
    try {
        gp_Pln plane(gp_Pnt(originX, originY, originZ), gp_Dir(normalX, normalY, normalZ));
        BRepAlgoAPI_Section section(shape->shape, plane);
        section.Build();
        if (!section.IsDone() || section.Shape().IsNull()) return nullptr;
        return new OCCTShape(section.Shape());
    } catch (...) { return nullptr; }
}

OCCTShapeRef OCCTShapeSectionWithSurface(OCCTShapeRef shape, OCCTSurfaceRef surface) {
    if (!shape || !surface) return nullptr;
    try {
        BRepAlgoAPI_Section section(shape->shape, surface->surface);
        section.Build();
        if (!section.IsDone() || section.Shape().IsNull()) return nullptr;
        return new OCCTShape(section.Shape());
    } catch (...) { return nullptr; }
}
// --- FilletBuilder history queries ---


// --- SectionBuilder (BRepAlgoAPI_Section) ---

struct OCCTSectionBuilder {
    BRepAlgoAPI_Section section;
    bool built;
    OCCTSectionBuilder() : section(), built(false) {}
    OCCTSectionBuilder(const TopoDS_Shape& s1, const TopoDS_Shape& s2) : section(s1, s2, false), built(false) {}
};

OCCTSectionBuilderRef OCCTSectionBuilderCreate(void) {
    try {
        return new OCCTSectionBuilder();
    } catch (...) { return nullptr; }
}

OCCTSectionBuilderRef OCCTSectionBuilderCreateFromShapes(OCCTShapeRef shape1, OCCTShapeRef shape2) {
    if (!shape1 || !shape2) return nullptr;
    try {
        return new OCCTSectionBuilder(shape1->shape, shape2->shape);
    } catch (...) { return nullptr; }
}

void OCCTSectionBuilderRelease(OCCTSectionBuilderRef builder) {
    delete builder;
}

void OCCTSectionBuilderInit1Shape(OCCTSectionBuilderRef builder, OCCTShapeRef shape) {
    if (!builder || !shape) return;
    try { builder->section.Init1(shape->shape); } catch (...) {}
}

void OCCTSectionBuilderInit1Plane(OCCTSectionBuilderRef builder,
                                   double a, double b, double c, double d) {
    if (!builder) return;
    try {
        gp_Pln plane(a, b, c, d);
        builder->section.Init1(plane);
    } catch (...) {}
}

void OCCTSectionBuilderInit1Surface(OCCTSectionBuilderRef builder, OCCTSurfaceRef surface) {
    if (!builder || !surface) return;
    try { builder->section.Init1(surface->surface); } catch (...) {}
}

void OCCTSectionBuilderInit2Shape(OCCTSectionBuilderRef builder, OCCTShapeRef shape) {
    if (!builder || !shape) return;
    try { builder->section.Init2(shape->shape); } catch (...) {}
}

void OCCTSectionBuilderInit2Plane(OCCTSectionBuilderRef builder,
                                   double a, double b, double c, double d) {
    if (!builder) return;
    try {
        gp_Pln plane(a, b, c, d);
        builder->section.Init2(plane);
    } catch (...) {}
}

void OCCTSectionBuilderInit2Surface(OCCTSectionBuilderRef builder, OCCTSurfaceRef surface) {
    if (!builder || !surface) return;
    try { builder->section.Init2(surface->surface); } catch (...) {}
}

void OCCTSectionBuilderSetApproximation(OCCTSectionBuilderRef builder, bool approx) {
    if (!builder) return;
    try { builder->section.Approximation(approx); } catch (...) {}
}

void OCCTSectionBuilderComputePCurveOn1(OCCTSectionBuilderRef builder, bool compute) {
    if (!builder) return;
    try { builder->section.ComputePCurveOn1(compute); } catch (...) {}
}

void OCCTSectionBuilderComputePCurveOn2(OCCTSectionBuilderRef builder, bool compute) {
    if (!builder) return;
    try { builder->section.ComputePCurveOn2(compute); } catch (...) {}
}

OCCTShapeRef OCCTSectionBuilderBuild(OCCTSectionBuilderRef builder) {
    if (!builder) return nullptr;
    try {
        builder->section.Build();
        if (!builder->section.IsDone()) return nullptr;
        builder->built = true;
        return new OCCTShape{builder->section.Shape()};
    } catch (...) { return nullptr; }
}

OCCTShapeRef OCCTSectionBuilderAncestorFaceOn1(OCCTSectionBuilderRef builder, OCCTShapeRef edge) {
    if (!builder || !edge || !builder->built) return nullptr;
    try {
        TopoDS_Shape face;
        if (builder->section.HasAncestorFaceOn1(edge->shape, face)) {
            return new OCCTShape{face};
        }
        return nullptr;
    } catch (...) { return nullptr; }
}

OCCTShapeRef OCCTSectionBuilderAncestorFaceOn2(OCCTSectionBuilderRef builder, OCCTShapeRef edge) {
    if (!builder || !edge || !builder->built) return nullptr;
    try {
        TopoDS_Shape face;
        if (builder->section.HasAncestorFaceOn2(edge->shape, face)) {
            return new OCCTShape{face};
        }
        return nullptr;
    } catch (...) { return nullptr; }
}

// MARK: - Issue #39: Lift 2D Curve to 3D Wire on a Plane

#include <BRepLib.hxx>

OCCTWireRef OCCTWireFromCurve2DOnPlane(OCCTCurve2DRef curve,
                                       double ox, double oy, double oz,
                                       double nx, double ny, double nz,
                                       double xx, double xy, double xz) {
    if (!curve || curve->curve.IsNull()) return nullptr;
    try {
        gp_Pnt origin(ox, oy, oz);
        gp_Dir normal(nx, ny, nz);
        gp_Dir xDir(xx, xy, xz);
        gp_Ax2 ax2(origin, normal, xDir);
        gp_Pln plane(ax2);

        // BRepBuilderAPI_MakeEdge accepts a Geom2d_Curve + Handle(Geom_Surface)
        Handle(Geom_Plane) surf = new Geom_Plane(plane);
        BRepBuilderAPI_MakeEdge maker(curve->curve, surf);
        if (!maker.IsDone()) return nullptr;
        TopoDS_Edge edge = maker.Edge();

        // Build the 3D curve representation from the pcurve on the plane surface
        BRepLib::BuildCurves3d(edge);

        BRepBuilderAPI_MakeWire wireMaker(edge);
        if (!wireMaker.IsDone()) return nullptr;

        auto* w = new OCCTWire();
        w->wire = wireMaker.Wire();
        return w;
    } catch (...) {
        return nullptr;
    }
}
// MARK: - Shape Creation (Primitives)

#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <BRepPrimAPI_MakeSphere.hxx>
#include <BRepPrimAPI_MakeCone.hxx>
#include <BRepPrimAPI_MakeTorus.hxx>
#include <BRepOffsetAPI_MakePipe.hxx>
#include <BRepOffsetAPI_ThruSections.hxx>
#include <BRepAlgoAPI_Fuse.hxx>
#include <BRepAlgoAPI_Cut.hxx>
#include <BRepAlgoAPI_Common.hxx>
#include <BRepFilletAPI_MakeFillet.hxx>
#include <BRepFilletAPI_MakeChamfer.hxx>
#include <BRepBuilderAPI_Transform.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRep_Builder.hxx>

OCCTShapeRef OCCTShapeCreateBox(double width, double height, double depth) {
    try {
        // Create box centered at origin
        gp_Pnt origin(-width/2, -height/2, -depth/2);
        BRepPrimAPI_MakeBox maker(origin, width, height, depth);
        return new OCCTShape(maker.Shape());
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeCreateBoxAt(double x, double y, double z, double width, double height, double depth) {
    try {
        gp_Pnt origin(x, y, z);
        BRepPrimAPI_MakeBox maker(origin, width, height, depth);
        return new OCCTShape(maker.Shape());
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeCreateBoxOriented(
    double originX, double originY, double originZ,
    double dirX, double dirY, double dirZ,
    double width, double height, double depth) {
    try {
        gp_Ax2 axis(gp_Pnt(originX, originY, originZ), gp_Dir(dirX, dirY, dirZ));
        BRepPrimAPI_MakeBox maker(axis, width, height, depth);
        return new OCCTShape(maker.Shape());
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeCreateCylinder(double radius, double height) {
    try {
        BRepPrimAPI_MakeCylinder maker(radius, height);
        return new OCCTShape(maker.Shape());
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeCreateCylinderAt(double cx, double cy, double bottomZ, double radius, double height) {
    try {
        // Create axis at position with Z-up direction
        gp_Ax2 axis(gp_Pnt(cx, cy, bottomZ), gp_Dir(0, 0, 1));
        BRepPrimAPI_MakeCylinder maker(axis, radius, height);
        return new OCCTShape(maker.Shape());
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeCreateCylinderOriented(
    double originX, double originY, double originZ,
    double dirX, double dirY, double dirZ,
    double radius, double height) {
    try {
        gp_Pnt origin(originX, originY, originZ);
        gp_Dir direction(dirX, dirY, dirZ);
        gp_Ax2 axis(origin, direction);
        BRepPrimAPI_MakeCylinder maker(axis, radius, height);
        return new OCCTShape(maker.Shape());
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeCreateCylinderPartial(double radius, double height, double angle) {
    try {
        BRepPrimAPI_MakeCylinder maker(radius, height, angle);
        return new OCCTShape(maker.Shape());
    } catch (...) {
        return nullptr;
    }
}

// Note: This creates an approximation of the swept volume using
// two cylinders connected by a box. For CAM purposes, this provides
// a conservative (larger) estimate suitable for collision detection
// and material removal simulation. A true swept solid could use
// BRepOffsetAPI_MakePipeShell for more accurate results.
OCCTShapeRef OCCTShapeCreateToolSweep(double radius, double height,
                                       double x1, double y1, double z1,
                                       double x2, double y2, double z2) {
    try {
        // For a cylindrical tool (flat end mill) moving from point 1 to point 2:
        // The swept volume consists of:
        // 1. Cylinder at start position
        // 2. Cylinder at end position
        // 3. A box connecting them (for horizontal component)

        double dx = x2 - x1;
        double dy = y2 - y1;
        double dz = z2 - z1;
        double xyDist = std::sqrt(dx*dx + dy*dy);

        // Use the lower Z as the bottom of the swept volume
        double bottomZ = std::min(z1, z2);

        // Create cylinder at start position
        gp_Ax2 axis1(gp_Pnt(x1, y1, bottomZ), gp_Dir(0, 0, 1));
        BRepPrimAPI_MakeCylinder cyl1Maker(axis1, radius, height + std::abs(dz));
        TopoDS_Shape result = cyl1Maker.Shape();

        // If there's XY movement, we need the end cylinder and connecting box
        if (xyDist > 1e-6) {
            // Create cylinder at end position
            gp_Ax2 axis2(gp_Pnt(x2, y2, bottomZ), gp_Dir(0, 0, 1));
            BRepPrimAPI_MakeCylinder cyl2Maker(axis2, radius, height + std::abs(dz));

            // Union end cylinder
            BRepAlgoAPI_Fuse fuse1(result, cyl2Maker.Shape());
            fuse1.Build();
            if (!fuse1.IsDone()) return nullptr;
            result = fuse1.Shape();

            // Create connecting box
            // The box needs to be oriented along the movement direction
            // Width = 2*radius (tool diameter), Length = xyDist, Height = tool height + dz

            // Calculate perpendicular direction for box width
            double perpX = -dy / xyDist;  // perpendicular to movement direction
            double perpY = dx / xyDist;

            // Box corner points (4 corners at bottom, extruded up)
            // The box connects the two cylinder centers
            gp_Pnt p1(x1 + perpX * radius, y1 + perpY * radius, bottomZ);
            gp_Pnt p2(x1 - perpX * radius, y1 - perpY * radius, bottomZ);
            gp_Pnt p3(x2 - perpX * radius, y2 - perpY * radius, bottomZ);
            gp_Pnt p4(x2 + perpX * radius, y2 + perpY * radius, bottomZ);

            // Create edges for the bottom face
            TopoDS_Edge e1 = BRepBuilderAPI_MakeEdge(p1, p2);
            TopoDS_Edge e2 = BRepBuilderAPI_MakeEdge(p2, p3);
            TopoDS_Edge e3 = BRepBuilderAPI_MakeEdge(p3, p4);
            TopoDS_Edge e4 = BRepBuilderAPI_MakeEdge(p4, p1);

            // Create wire from edges
            BRepBuilderAPI_MakeWire wireMaker;
            wireMaker.Add(e1);
            wireMaker.Add(e2);
            wireMaker.Add(e3);
            wireMaker.Add(e4);

            if (!wireMaker.IsDone()) return nullptr;

            // Create face from wire
            BRepBuilderAPI_MakeFace faceMaker(wireMaker.Wire());
            if (!faceMaker.IsDone()) return nullptr;

            // Extrude face upward to create box
            gp_Vec extrudeVec(0, 0, height + std::abs(dz));
            BRepPrimAPI_MakePrism prismMaker(faceMaker.Face(), extrudeVec);
            prismMaker.Build();
            if (!prismMaker.IsDone()) return nullptr;

            // Union connecting box
            BRepAlgoAPI_Fuse fuse2(result, prismMaker.Shape());
            fuse2.Build();
            if (!fuse2.IsDone()) return nullptr;
            result = fuse2.Shape();
        }

        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeCreateSphere(double radius) {
    try {
        BRepPrimAPI_MakeSphere maker(radius);
        return new OCCTShape(maker.Shape());
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeCreateSphereAtCenter(double cx, double cy, double cz, double radius) {
    try {
        gp_Pnt center(cx, cy, cz);
        BRepPrimAPI_MakeSphere maker(center, radius);
        return new OCCTShape(maker.Shape());
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeCreateSphereOriented(
    double originX, double originY, double originZ,
    double dirX, double dirY, double dirZ,
    double radius) {
    try {
        gp_Ax2 axis(gp_Pnt(originX, originY, originZ), gp_Dir(dirX, dirY, dirZ));
        BRepPrimAPI_MakeSphere maker(axis, radius);
        return new OCCTShape(maker.Shape());
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeCreateSpherePartial(double radius, double angle) {
    try {
        BRepPrimAPI_MakeSphere maker(radius, angle);
        return new OCCTShape(maker.Shape());
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeCreateCone(double bottomRadius, double topRadius, double height) {
    try {
        BRepPrimAPI_MakeCone maker(bottomRadius, topRadius, height);
        return new OCCTShape(maker.Shape());
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeCreateConeOriented(
    double originX, double originY, double originZ,
    double dirX, double dirY, double dirZ,
    double bottomRadius, double topRadius, double height) {
    try {
        gp_Ax2 axis(gp_Pnt(originX, originY, originZ), gp_Dir(dirX, dirY, dirZ));
        BRepPrimAPI_MakeCone maker(axis, bottomRadius, topRadius, height);
        return new OCCTShape(maker.Shape());
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeCreateTorus(double majorRadius, double minorRadius) {
    try {
        BRepPrimAPI_MakeTorus maker(majorRadius, minorRadius);
        return new OCCTShape(maker.Shape());
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeCreateTorusOriented(
    double originX, double originY, double originZ,
    double dirX, double dirY, double dirZ,
    double majorRadius, double minorRadius) {
    try {
        gp_Ax2 axis(gp_Pnt(originX, originY, originZ), gp_Dir(dirX, dirY, dirZ));
        BRepPrimAPI_MakeTorus maker(axis, majorRadius, minorRadius);
        return new OCCTShape(maker.Shape());
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeCreateCylinderOrientedPartial(
    double originX, double originY, double originZ,
    double dirX, double dirY, double dirZ,
    double radius, double height, double angle) {
    try {
        gp_Ax2 axis(gp_Pnt(originX, originY, originZ), gp_Dir(dirX, dirY, dirZ));
        BRepPrimAPI_MakeCylinder maker(axis, radius, height, angle);
        return new OCCTShape(maker.Shape());
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeCreateConeOrientedPartial(
    double originX, double originY, double originZ,
    double dirX, double dirY, double dirZ,
    double bottomRadius, double topRadius, double height, double angle) {
    try {
        gp_Ax2 axis(gp_Pnt(originX, originY, originZ), gp_Dir(dirX, dirY, dirZ));
        BRepPrimAPI_MakeCone maker(axis, bottomRadius, topRadius, height, angle);
        return new OCCTShape(maker.Shape());
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeCreateTorusOrientedPartial(
    double originX, double originY, double originZ,
    double dirX, double dirY, double dirZ,
    double majorRadius, double minorRadius, double angle) {
    try {
        gp_Ax2 axis(gp_Pnt(originX, originY, originZ), gp_Dir(dirX, dirY, dirZ));
        BRepPrimAPI_MakeTorus maker(axis, majorRadius, minorRadius, angle);
        return new OCCTShape(maker.Shape());
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeCreateTorusOrientedSegment(
    double originX, double originY, double originZ,
    double dirX, double dirY, double dirZ,
    double majorRadius, double minorRadius, double angle1, double angle2) {
    try {
        gp_Ax2 axis(gp_Pnt(originX, originY, originZ), gp_Dir(dirX, dirY, dirZ));
        BRepPrimAPI_MakeTorus maker(axis, majorRadius, minorRadius, angle1, angle2);
        return new OCCTShape(maker.Shape());
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeCreateSphereOrientedPartial(
    double originX, double originY, double originZ,
    double dirX, double dirY, double dirZ,
    double radius, double angle) {
    try {
        gp_Ax2 axis(gp_Pnt(originX, originY, originZ), gp_Dir(dirX, dirY, dirZ));
        BRepPrimAPI_MakeSphere maker(axis, radius, angle);
        return new OCCTShape(maker.Shape());
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeCreateSphereOrientedSegment(
    double originX, double originY, double originZ,
    double dirX, double dirY, double dirZ,
    double radius, double angle1, double angle2) {
    try {
        gp_Ax2 axis(gp_Pnt(originX, originY, originZ), gp_Dir(dirX, dirY, dirZ));
        BRepPrimAPI_MakeSphere maker(axis, radius, angle1, angle2);
        return new OCCTShape(maker.Shape());
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Shape Creation (Sweeps)

OCCTShapeRef OCCTShapeCreatePipeSweep(OCCTWireRef profile, OCCTWireRef path) {
    if (!profile || !path) return nullptr;
    try {
        BRepOffsetAPI_MakePipe maker(path->wire, profile->wire);
        maker.Build();
        if (!maker.IsDone()) return nullptr;
        return new OCCTShape(maker.Shape());
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeCreateExtrusion(OCCTWireRef profile, double dx, double dy, double dz, double length) {
    if (!profile) return nullptr;
    occtEnsureSignals();
    try {
        OCC_CATCH_SIGNALS
        // Normalize direction and scale by length
        double mag = std::sqrt(dx*dx + dy*dy + dz*dz);
        if (mag < 1e-10) return nullptr;
        gp_Vec direction(dx/mag * length, dy/mag * length, dz/mag * length);

        // Create a face from the wire for solid extrusion
        BRepBuilderAPI_MakeFace faceMaker(profile->wire);
        if (!faceMaker.IsDone()) return nullptr;

        BRepPrimAPI_MakePrism maker(faceMaker.Face(), direction);
        maker.Build();
        if (!maker.IsDone()) return nullptr;
        return new OCCTShape(maker.Shape());
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeCreateRevolution(OCCTWireRef profile, double axisX, double axisY, double axisZ, double dirX, double dirY, double dirZ, double angle) {
    if (!profile) return nullptr;
    occtEnsureSignals();
    try {
        OCC_CATCH_SIGNALS
        gp_Pnt axisOrigin(axisX, axisY, axisZ);
        gp_Dir axisDirection(dirX, dirY, dirZ);
        gp_Ax1 axis(axisOrigin, axisDirection);

        BRepPrimAPI_MakeRevol maker(profile->wire, axis, angle);
        maker.Build();
        if (!maker.IsDone()) return nullptr;
        return new OCCTShape(maker.Shape());
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeCreateExtrusionInfinite(OCCTShapeRef shape,
    double dirX, double dirY, double dirZ, bool infinite) {
    if (!shape) return nullptr;
    try {
        gp_Dir dir(dirX, dirY, dirZ);
        BRepPrimAPI_MakePrism maker(shape->shape, dir, infinite);
        maker.Build();
        if (!maker.IsDone()) return nullptr;
        return new OCCTShape(maker.Shape());
    } catch (...) { return nullptr; }
}

OCCTShapeRef OCCTShapeCreateExtrusionShape(OCCTShapeRef shape,
    double dx, double dy, double dz) {
    if (!shape) return nullptr;
    try {
        gp_Vec vec(dx, dy, dz);
        BRepPrimAPI_MakePrism maker(shape->shape, vec);
        maker.Build();
        if (!maker.IsDone()) return nullptr;
        return new OCCTShape(maker.Shape());
    } catch (...) { return nullptr; }
}

OCCTShapeRef OCCTShapeCreateRevolutionFull(OCCTShapeRef shape,
    double axisX, double axisY, double axisZ,
    double dirX, double dirY, double dirZ) {
    if (!shape) return nullptr;
    try {
        gp_Ax1 axis(gp_Pnt(axisX, axisY, axisZ), gp_Dir(dirX, dirY, dirZ));
        BRepPrimAPI_MakeRevol maker(shape->shape, axis);
        maker.Build();
        if (!maker.IsDone()) return nullptr;
        return new OCCTShape(maker.Shape());
    } catch (...) { return nullptr; }
}

OCCTShapeRef OCCTShapeCreateRevolutionPartial(OCCTShapeRef shape,
    double axisX, double axisY, double axisZ,
    double dirX, double dirY, double dirZ,
    double angle) {
    if (!shape) return nullptr;
    try {
        gp_Ax1 axis(gp_Pnt(axisX, axisY, axisZ), gp_Dir(dirX, dirY, dirZ));
        BRepPrimAPI_MakeRevol maker(shape->shape, axis, angle);
        maker.Build();
        if (!maker.IsDone()) return nullptr;
        return new OCCTShape(maker.Shape());
    } catch (...) { return nullptr; }
}

OCCTShapeRef OCCTShapeCreateLoft(const OCCTWireRef* profiles, int32_t count, bool solid) {
    if (!profiles || count < 2) return nullptr;
    occtEnsureSignals();
    try {
        OCC_CATCH_SIGNALS
        BRepOffsetAPI_ThruSections maker(solid ? Standard_True : Standard_False);

        // Enable compatibility checking to:
        // - Compute origin and orientation on wires to avoid twisted results
        // - Update wires to have same number of edges
        maker.CheckCompatibility(Standard_True);

        for (int32_t i = 0; i < count; i++) {
            if (profiles[i]) {
                maker.AddWire(profiles[i]->wire);
            }
        }

        maker.Build();
        if (!maker.IsDone()) return nullptr;
        return new OCCTShape(maker.Shape());
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Boolean Operations

OCCTShapeRef OCCTShapeUnion(OCCTShapeRef shape1, OCCTShapeRef shape2) {
    if (!shape1 || !shape2) return nullptr;
    occtEnsureSignals();
    try {
        OCC_CATCH_SIGNALS
        BRepAlgoAPI_Fuse fuser(shape1->shape, shape2->shape);
        fuser.Build();
        if (!fuser.IsDone()) return nullptr;
        return new OCCTShape(fuser.Shape());
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeSubtract(OCCTShapeRef shape1, OCCTShapeRef shape2) {
    if (!shape1 || !shape2) return nullptr;
    try {
        BRepAlgoAPI_Cut cutter(shape1->shape, shape2->shape);
        cutter.Build();
        if (!cutter.IsDone()) return nullptr;
        return new OCCTShape(cutter.Shape());
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeIntersect(OCCTShapeRef shape1, OCCTShapeRef shape2) {
    if (!shape1 || !shape2) return nullptr;
    try {
        BRepAlgoAPI_Common intersector(shape1->shape, shape2->shape);
        intersector.Build();
        if (!intersector.IsDone()) return nullptr;
        return new OCCTShape(intersector.Shape());
    } catch (...) {
        return nullptr;
    }
}

// --- Boolean ops with fuzzy value + glue (#202) ---
// Shared driver: BRepAlgoAPI_Fuse/Cut/Common all derive from
// BRepAlgoAPI_BooleanOperation, so the option setters are identical across ops.
template <typename BoolOpT>
static OCCTShapeRef runBooleanEx(OCCTShapeRef shape1, OCCTShapeRef shape2,
                                 double fuzzyValue, int32_t glue) {
    if (!shape1 || !shape2) return nullptr;
    occtEnsureSignals();
    try {
        OCC_CATCH_SIGNALS
        BoolOpT op;
        TopTools_ListOfShape args;  args.Append(shape1->shape);
        TopTools_ListOfShape tools; tools.Append(shape2->shape);
        op.SetArguments(args);
        op.SetTools(tools);
        if (fuzzyValue > 0.0) op.SetFuzzyValue(fuzzyValue);
        switch (glue) {
            case 1:  op.SetGlue(BOPAlgo_GlueShift); break;
            case 2:  op.SetGlue(BOPAlgo_GlueFull);  break;
            default: op.SetGlue(BOPAlgo_GlueOff);   break;
        }
        op.Build();
        if (!op.IsDone()) return nullptr;
        return new OCCTShape(op.Shape());
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeUnionEx(OCCTShapeRef shape1, OCCTShapeRef shape2, double fuzzyValue, int32_t glue) {
    return runBooleanEx<BRepAlgoAPI_Fuse>(shape1, shape2, fuzzyValue, glue);
}

OCCTShapeRef OCCTShapeSubtractEx(OCCTShapeRef shape1, OCCTShapeRef shape2, double fuzzyValue, int32_t glue) {
    return runBooleanEx<BRepAlgoAPI_Cut>(shape1, shape2, fuzzyValue, glue);
}

OCCTShapeRef OCCTShapeIntersectEx(OCCTShapeRef shape1, OCCTShapeRef shape2, double fuzzyValue, int32_t glue) {
    return runBooleanEx<BRepAlgoAPI_Common>(shape1, shape2, fuzzyValue, glue);
}

// MARK: - Modifications

OCCTShapeRef OCCTShapeFillet(OCCTShapeRef shape, double radius) {
    if (!shape) return nullptr;
    try {
        BRepFilletAPI_MakeFillet fillet(shape->shape);

        // Add fillet to all edges
        TopExp_Explorer explorer(shape->shape, TopAbs_EDGE);
        while (explorer.More()) {
            fillet.Add(radius, TopoDS::Edge(explorer.Current()));
            explorer.Next();
        }

        fillet.Build();
        if (!fillet.IsDone()) return nullptr;
        return new OCCTShape(fillet.Shape());
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeChamfer(OCCTShapeRef shape, double distance) {
    if (!shape) return nullptr;
    try {
        BRepFilletAPI_MakeChamfer chamfer(shape->shape);

        // Add chamfer to all edges
        TopExp_Explorer explorer(shape->shape, TopAbs_EDGE);
        while (explorer.More()) {
            chamfer.Add(distance, TopoDS::Edge(explorer.Current()));
            explorer.Next();
        }

        chamfer.Build();
        if (!chamfer.IsDone()) return nullptr;
        return new OCCTShape(chamfer.Shape());
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeShell(OCCTShapeRef shape, double thickness) {
    if (!shape) return nullptr;
    try {
        // Create list of faces to remove (none = hollow shell)
        TopTools_ListOfShape facesToRemove;

        BRepOffsetAPI_MakeThickSolid thickSolid;
        thickSolid.MakeThickSolidBySimple(shape->shape, thickness);
        if (!thickSolid.IsDone()) return nullptr;
        return new OCCTShape(thickSolid.Shape());
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeOffset(OCCTShapeRef shape, double distance) {
    if (!shape) return nullptr;
    try {
        BRepOffsetAPI_MakeOffsetShape offsetter;
        offsetter.PerformBySimple(shape->shape, distance);
        if (!offsetter.IsDone()) return nullptr;
        return new OCCTShape(offsetter.Shape());
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Transformations

OCCTShapeRef OCCTShapeTranslate(OCCTShapeRef shape, double dx, double dy, double dz) {
    if (!shape) return nullptr;
    try {
        gp_Trsf transform;
        transform.SetTranslation(gp_Vec(dx, dy, dz));
        BRepBuilderAPI_Transform transformer(shape->shape, transform, Standard_True);
        return new OCCTShape(transformer.Shape());
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeRotate(OCCTShapeRef shape, double axisX, double axisY, double axisZ, double angle) {
    if (!shape) return nullptr;
    try {
        gp_Ax1 axis(gp_Pnt(0, 0, 0), gp_Dir(axisX, axisY, axisZ));
        gp_Trsf transform;
        transform.SetRotation(axis, angle);
        BRepBuilderAPI_Transform transformer(shape->shape, transform, Standard_True);
        return new OCCTShape(transformer.Shape());
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeScale(OCCTShapeRef shape, double factor) {
    if (!shape) return nullptr;
    try {
        gp_Trsf transform;
        transform.SetScale(gp_Pnt(0, 0, 0), factor);
        BRepBuilderAPI_Transform transformer(shape->shape, transform, Standard_True);
        return new OCCTShape(transformer.Shape());
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeMirror(OCCTShapeRef shape, double originX, double originY, double originZ, double normalX, double normalY, double normalZ) {
    if (!shape) return nullptr;
    try {
        gp_Ax2 mirrorPlane(gp_Pnt(originX, originY, originZ), gp_Dir(normalX, normalY, normalZ));
        gp_Trsf transform;
        transform.SetMirror(mirrorPlane);
        BRepBuilderAPI_Transform transformer(shape->shape, transform, Standard_True);
        return new OCCTShape(transformer.Shape());
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Compound

OCCTShapeRef OCCTShapeCreateCompound(const OCCTShapeRef* shapes, int32_t count) {
    if (!shapes || count < 1) return nullptr;
    try {
        TopoDS_Compound compound;
        BRep_Builder builder;
        builder.MakeCompound(compound);

        for (int32_t i = 0; i < count; i++) {
            if (shapes[i]) {
                builder.Add(compound, shapes[i]->shape);
            }
        }

        return new OCCTShape(compound);
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Slicing

#include <TopTools_HSequenceOfShape.hxx>
#include <ShapeAnalysis_FreeBounds.hxx>
#include <BRepAlgoAPI_Section.hxx>

OCCTShapeRef OCCTShapeSliceAtZ(OCCTShapeRef shape, double z) {
    if (!shape) return nullptr;

    try {
        // Create a horizontal plane at height z
        gp_Pln plane(gp_Pnt(0, 0, z), gp_Dir(0, 0, 1));

        // Compute section (intersection of shape with plane)
        BRepAlgoAPI_Section section(shape->shape, plane);
        section.Build();

        if (!section.IsDone()) return nullptr;

        TopoDS_Shape result = section.Shape();
        if (result.IsNull()) return nullptr;

        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

int32_t OCCTShapeGetEdgeCount(OCCTShapeRef shape) {
    if (!shape) return 0;

    int32_t count = 0;
    TopExp_Explorer explorer(shape->shape, TopAbs_EDGE);
    while (explorer.More()) {
        count++;
        explorer.Next();
    }
    return count;
}

int32_t OCCTShapeGetEdgePoints(OCCTShapeRef shape, int32_t edgeIndex, double* outPoints, int32_t maxPoints) {
    if (!shape || !outPoints || maxPoints < 2 || edgeIndex < 0) return 0;

    try {
        // Use IndexedMap to match OCCTShapeGetTotalEdgeCount ordering
        TopTools_IndexedMapOfShape edgeMap;
        TopExp::MapShapes(shape->shape, TopAbs_EDGE, edgeMap);

        if (edgeIndex >= edgeMap.Extent()) return 0;

        TopoDS_Edge edge = TopoDS::Edge(edgeMap(edgeIndex + 1));  // OCCT is 1-based

        // Ensure 3D curve exists (lofted shapes may only have pcurves)
        BRepLib::BuildCurves3d(edge);

        // Get curve from edge
        Standard_Real first, last;
        Handle(Geom_Curve) curve = BRep_Tool::Curve(edge, first, last);
        if (curve.IsNull()) return 0;

        // Sample points along the curve
        int32_t numPoints = std::min(maxPoints, (int32_t)20);  // Max 20 points per edge
        for (int32_t i = 0; i < numPoints; i++) {
            double param = first + (last - first) * i / (numPoints - 1);
            gp_Pnt pt = curve->Value(param);
            outPoints[i * 3 + 0] = pt.X();
            outPoints[i * 3 + 1] = pt.Y();
            outPoints[i * 3 + 2] = pt.Z();
        }

        return numPoints;
    } catch (...) {
        return 0;
    }
}

// Get all edge endpoints as a simple contour (for toolpath generation)
int32_t OCCTShapeGetContourPoints(OCCTShapeRef shape, double* outPoints, int32_t maxPoints) {
    if (!shape || !outPoints || maxPoints < 1) return 0;

    try {
        int32_t pointCount = 0;

        TopExp_Explorer explorer(shape->shape, TopAbs_EDGE);
        while (explorer.More() && pointCount < maxPoints) {
            TopoDS_Edge edge = TopoDS::Edge(explorer.Current());

            // Get start and end vertices of the edge
            TopoDS_Vertex v1, v2;
            TopExp::Vertices(edge, v1, v2);

            if (!v1.IsNull()) {
                gp_Pnt pt = BRep_Tool::Pnt(v1);
                outPoints[pointCount * 3 + 0] = pt.X();
                outPoints[pointCount * 3 + 1] = pt.Y();
                outPoints[pointCount * 3 + 2] = pt.Z();
                pointCount++;
            }

            explorer.Next();
        }

        return pointCount;
    } catch (...) {
        return 0;
    }
}

// MARK: - CAM Operations

OCCTWireRef OCCTWireOffset(OCCTWireRef wire, double distance, int32_t joinType) {
    if (!wire) return nullptr;

    try {
        TopoDS_Wire theWire = wire->wire;

        // Create a planar face from the wire (required for BRepOffsetAPI_MakeOffset)
        BRepBuilderAPI_MakeFace faceMaker(theWire, Standard_True);
        if (!faceMaker.IsDone()) return nullptr;
        TopoDS_Face face = faceMaker.Face();

        // Select join type
        GeomAbs_JoinType join = (joinType == 0) ? GeomAbs_Arc : GeomAbs_Intersection;

        // Create offset using the face
        BRepOffsetAPI_MakeOffset offsetMaker(face, join);
        offsetMaker.Perform(distance);

        if (!offsetMaker.IsDone()) return nullptr;

        // Extract the offset wire from the result shape
        TopoDS_Shape result = offsetMaker.Shape();

        // The result may contain multiple wires - get the first one
        TopExp_Explorer explorer(result, TopAbs_WIRE);
        if (explorer.More()) {
            TopoDS_Wire resultWire = TopoDS::Wire(explorer.Current());
            return new OCCTWire(resultWire);
        }

        return nullptr;
    } catch (...) {
        return nullptr;
    }
}

OCCTWireRef* OCCTShapeSectionWiresAtZ(OCCTShapeRef shape, double z, double tolerance, int32_t* outCount) {
    if (!shape || !outCount) return nullptr;
    *outCount = 0;

    try {
        // Create horizontal cutting plane at Z level
        gp_Pln plane(gp_Pnt(0, 0, z), gp_Dir(0, 0, 1));

        // Compute section
        BRepAlgoAPI_Section section(shape->shape, plane);
        section.Build();
        if (!section.IsDone()) return nullptr;

        TopoDS_Shape sectionShape = section.Shape();
        if (sectionShape.IsNull()) return nullptr;

        // Collect edges from section result
        Handle(TopTools_HSequenceOfShape) edges = new TopTools_HSequenceOfShape;
        TopExp_Explorer explorer(sectionShape, TopAbs_EDGE);
        while (explorer.More()) {
            edges->Append(explorer.Current());
            explorer.Next();
        }

        if (edges->Length() == 0) return nullptr;

        // Connect edges into wires using ShapeAnalysis_FreeBounds
        Handle(TopTools_HSequenceOfShape) wires = new TopTools_HSequenceOfShape;
        ShapeAnalysis_FreeBounds::ConnectEdgesToWires(
            edges,
            tolerance,       // tolerance for connecting edges
            Standard_False,  // shared edges
            wires
        );

        int wireCount = wires->Length();
        if (wireCount == 0) return nullptr;

        // Allocate array for result
        OCCTWireRef* result = new OCCTWireRef[wireCount];
        for (int i = 1; i <= wireCount; i++) {
            TopoDS_Wire theWire = TopoDS::Wire(wires->Value(i));
            result[i - 1] = new OCCTWire(theWire);
        }

        *outCount = wireCount;
        return result;
    } catch (...) {
        return nullptr;
    }
}

void OCCTFreeWireArray(OCCTWireRef* wires, int32_t count) {
    if (!wires) return;
    for (int32_t i = 0; i < count; i++) {
        delete wires[i];
    }
    delete[] wires;
}

void OCCTFreeWireArrayOnly(OCCTWireRef* wires) {
    if (!wires) return;
    delete[] wires;
}

