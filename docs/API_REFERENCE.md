---
title: API Map (Swift ↔ OCCT)
nav_order: 4
---

# API Map (Swift ↔ OCCT)

Complete mapping of OCCTSwift operations to OCCT C++ classes. For the detailed per-type function
reference (signatures, parameters, examples), see [API Reference](reference/).

## Wrapped Operations Summary

| Category | Count | Examples |
|----------|-------|----------|
| **Primitives** | 13 | box, cylinder, cylinder(at:), sphere, cone, torus, surface, wedge, halfSpace, vertex, shell(from surface), shell(from Surface), nonUniformScale |
| **Sweeps** | 23 | pipe sweep, pipeShell, pipeShellWithTransition, pipeShellWithLaw, extrude, revolve, loft, loft(ruled+vertex), ruled, revolutionFromCurve, ruledShell, advancedEvolved, pipeSweep, compatibleWires, thruSectionsCreate, thruSectionsAddWire, thruSectionsAddVertex, thruSectionsSetSmoothing, thruSectionsSetMaxDegree, thruSectionsSetContinuity, thruSectionsBuild, thruSectionsShape, thruSectionsRelease |
| **Booleans** | 13 | union (+), subtract (-), intersect (&), section, booleanCheck, fuseAll, commonAll, fusedAndBlended, cutAndBlended, sectionWithTolerance, splitMulti, cutWithHistory, defeatureWithTolerance |
| **Modifications** | 33 | fillet, selective fillet, variable fillet, multi-edge blend, chamfer, chamferTwoDistances, chamferDistAngle, shell, offset, offsetByJoin, draft, defeature, convertToNURBS, makeDraft, hollowed, filletEvolving, offsetPerFace, fillet2DFace, chamfer2DFace, anaFillet, anaFillet(edge/wire), filletAlgo, filletAlgo(edge/wire), offsetWire, draftFromWire, addFillet2d, addChamfer2d, addChamfer2dAngle, modifyFillet2d, removeFillet2d, removeChamfer2d |
| **Transforms** | 10 | translate, rotate, scale, mirror, mirrorAboutPoint, mirrorAboutAxis, scaleAboutPoint, translated(from:to:), transformed(matrix:), gTransformed(matrix:) |
| **Wires** | 30 | rectangle, circle, polygon, polygon3D, line, arc, bspline, nurbs, path, join, offset, offset3D, interpolate, fillet2D, filletAll2D, chamfer2D, chamferAll2D, helix, helixTapered, orderedEdgeCount, orderedEdgePoints, orderedEdgePointCount, analyze, wireFromEdges, edges, allEdgePolylines, edgePolyline, bounds |
| **Curve Analysis** | 6 | length, curveInfo, point(at:), tangent(at:), curvature(at:), curvePoint(at:) |
| **2D Curves (Curve2D)** | 97 | line, segment, circle, arc, ellipse, parabola, hyperbola, bspline, bezier, interpolate, fit, trim, offset, reverse, translate, rotate, scale, mirror, curvature, normal, inflection, intersect, project, Gcc solver, hatch, bisector, draw, evaluateGrid, evaluateGridD1, lineThroughPoints, lineParallel, isLinear, convertToLine, simplifyBSpline, approximated, GccAna bisectors (point/line/circle), GccAna line solvers (parallel/perpendicular/oblique), Geom2dGcc circle/line on-constraint solvers, IntAna2d intersections, Extrema2d distances, curvatureExtremaDetailed, inflectionPointsDetailed, Bisector_BisecAna |
| **3D Curves (Curve3D)** | 84 | line, segment, circle, arc, ellipse, parabola, hyperbola, bspline, bezier, interpolate, fit, trim, reverse, translate, rotate, scale, mirror, length, curvature, tangent, normal, torsion, toBSpline, toBezierSegments, join, approximate, drawAdaptive, drawUniform, drawDeflection, projectedOnPlane, evaluateGrid, evaluateGridD1, planeNormal, minDistance(toCurve), extrema, intersectSurface, distanceToSurface, toAnalytical, quasiUniformParameters, quasiUniformDeflectionPoints, continuityBreaks, arcOfEllipse(angles), arcOfEllipse(points), joined(curves), projectPoint, validateRange, samplePoints, arcOfHyperbola, arcOfParabola, convertToPeriodic, splitAt, ellipseThreePoints, hyperbolaThreePoints |
| **Surfaces (Surface)** | 86 | plane, cylinder, cone, sphere, torus, extrusion, revolution, bezier, bspline, trim, offset, translate, rotate, scale, mirror, toBSpline, approximate, uIso, vIso, pipe, drawGrid, drawMesh, curvatures, projectCurve, projectCurveSegments, projectCurve3D, projectPoint, plateThrough, nlPlateDeformed, nlPlateDeformedG1, nlPlateDeformedG2, nlPlateDeformedG3, nlPlateDeformedIncremental, nlPlateDerivative, evaluateGrid, intersections, toAnalytical, bezierFill(4-curve), bezierFill(2-curve), singularityCount, isDegenerated, hasSingularities, toBezierPatchGrid, bsplineFill(2-curve), bsplineFill(4-curve), extrema, valueOfUV, nextValueOfUV, conicalSurface(axis), conicalSurface(points), cylindricalSurface(axis), cylindricalSurface(points), planeFromPoints, planeFromPointNormal, trimmedCone, trimmedCylinder, knotSplitting, joinBezierPatches, convertToAnalytical, splitByContinuity, generatedFromSections, degeneratedBoundaryValue, isDegeneratedBoundary, boundaryWithSurfaceEvaluate, averagePlane, plateErrors |
| **Face Analysis** | 20 | uvBounds, point(atU:v:), normal, gaussianCurvature, meanCurvature, principalCurvatures, surfaceType, area, project, allProjections, intersection |
| **Edge Analysis** | 26 | parameterBounds, curveType, point(at:), curvature, tangent, normal, centerOfCurvature, torsion, project, hasCurve3D, isClosed3D, isSeam, adjacentFaces, dihedralAngle, split |
| **Feature-Based** | 36 | boss, pocket, prism, drilled, split, glue, evolved, evolvedAdvanced, linearPattern, circularPattern, linearRib, revolutionForm, draftPrism, draftPrismThruAll, revolFeature, revolFeatureThruAll, pipeFeature, extrudedSemiInfinite, prismUntilFace, pipeFeatureFromProfile, localRevolution, localRevolutionWithOffset, locOpeDraftPrism, localPipe, localLinearForm, localRevolutionForm, splitFace, splitEdge, splitDrafts, commonEdges, edgesInFace, cylindricalHole, cylindricalHoleBlind, cylindricalHoleThruNext, cylindricalHoleStatus, locOpeGlue |
| **Healing/Analysis** | 69 | analyze, fixed, unified, simplified, withoutSmallFaces, wire.fixed, face.fixed, divided, directFaces, scaledGeometry, bsplineRestriction, sweptToElementary, revolutionToElementary, convertedToBSpline, sewn, upgraded, fastSewn, normalProjection, fixedWireframe, removingInternalWires, fusedEdges, simpleOffset, fixingSmallFaces, removingLocations, quilt, splitByAngle, droppingSmallEdges, splittingFace, freeBounds, fixedFreeBounds, withSurfacesAsBSpline, withSurfacesAsRevolution, checkSmallFaces, purgedLocations, curveOnSurfaceCheck, connectedEdges, convertedToBezier, limitTolerance, setTolerance, splitCommonVertices, connectedFaces, fixEdgeSameParameter, fixEdgeVertexTolerance, fixWireVertices, removeSmallSolids, mergeSmallSolids, bsplineRestriction(advanced), freeBoundsAnalysis, closedFreeBoundInfo, openFreeBoundInfo, closedFreeBoundWire, openFreeBoundWire, wireVertexAnalysis, wireVertexStatus, nearestPlane, shellSewing, trsfModification, gtrsfModification, deepCopy(modifier), bsplineRestrictionConfigurable, convertToBSplineConfigurable |
| **Measurement** | 36 | volume, surfaceArea, centerOfMass, properties, distance, distance(wire/edge/face), minDistance, intersects, intersects(wire/edge/face), inertiaProperties, surfaceInertiaProperties, allDistanceSolutions, isInside, findSurfaceEx, findPlane, analyzePointCloud, edgeEdgeExtrema, pointFaceExtrema, faceFaceExtrema, pointEdgeExtrema, edgeFaceExtrema, polyhedralDistance |
| **Point Classification** | 3 | classify(point:) on solid, classify(point:) on face, classify(u:v:) on face |
| **Shape Proximity** | 2 | proximityFaces, selfIntersects |
| **Law Functions** | 7 | constant, linear, sCurve, interpolate, bspline, value(at:), bounds |
| **Plate Solver** | 10 | create, loadPinpoint, loadDerivativeConstraint, loadGtoC, solve, isDone, evaluate, evaluateDerivative, uvBox, continuity |
| **Import/Export** | 17 | STL, STEP, IGES, BREP, OBJ import; STL, STEP, IGES, BREP, OBJ, PLY export; STEP optimize; mesh |
| **Shape Editing** | 19 | replacingSubShape, removingSubShape, makePeriodic, repeated, makeVolume, makeConnected, middlePath, copy, removingSubShapes, replacingSubShapes, dividedClosedEdges, faceRestricted, dividedByArea, dividedByParts, dividedClosedFaces, dividedByContinuity, intersectLine, substituted, builtFromFaces |
| **Polynomial Solver** | 3 | quadratic, cubic, quartic |
| **Hatch Pattern** | 1 | generate |
| **Geometry Construction** | 12 | face from wire, face with holes, solid from shell, solidFromShell(BRepLib), solidFromShells, sew, fill, plateSurface, plateCurves, plateSurfaceAdvanced, plateSurfaceMixed, constrainedFill |
| **Bounds/Topology** | 17 | bounds, orientedBoundingBox, orientedBoundingBoxCorners, size, center, vertices, edges, faces, solids, shells, wires, subShapeCount, subShape, subShapes, fromEdge, fromFace, projectWire(Wire) |
| **Slicing** | 4 | sliceAtZ, sectionWiresAtZ, edgePoints, contourPoints |
| **Validation** | 14 | isValid, heal, checkResult, detailedCheckStatuses, faceCheckResult, checkSolid, checkShape, checkShapeDetailed, analyzeValidity, isSubShapeValid, checkEdge, checkWire, checkShell, checkVertex |
| **XDE/Document** | 28 | Document.load, rootNodes, AssemblyNode, colors, materials, setColor, setMaterial, dimensions, geomTolerances, datums, lengthUnit, layerCount, layerName, layerNames, materialCount, materialInfo, materials |
| **Shape Census** | 2 | contents, recognizeCanonical |
| **Find Surface** | 2 | findSurface, contiguousEdgeCount |
| **2D Drawing** | 8 | project, topView, frontView, visibleEdges, hiddenEdges, projectFast, fastTopView, fastIsometricView |
| **Camera** | 14 | eye, center, up, projectionType, fieldOfView, scale, zRange, aspect, projectionMatrix, viewMatrix, project, unproject, fit |
| **Selection** | 11 | add, remove, clear, activateMode, deactivateMode, isModeActive, pixelTolerance, pick, pickRect, pickPoly |
| **Presentation Mesh** | 2 | shadedMesh, edgeMesh |
| **Medial Axis** | 12 | compute, arcCount, nodeCount, basicElementCount, node(at:), arc(at:), nodes, arcs, minThickness, distanceToBoundary, drawArc, drawAll |
| **Topological Naming** | 13 | createLabel, recordNaming, currentShape, storedShape, namingEvolution, namingHistory, oldShape, newShape, tracedForward, tracedBackward, selectShape, resolveShape, deepCopy |
| **TDF/OCAF Framework** | 31 | mainLabel, tag, depth, isNull, isRoot, father, root, hasAttribute, attributeCount, hasChild, childCount, findChild, forgetAllAttributes, descendants, setName, setReference, referencedLabel, copyLabel, openTransaction, commitTransaction, abortTransaction, hasOpenTransaction, setUndoLimit, undoLimit, undo, redo, availableUndos, availableRedos, setModified, clearModified, isModified |
| **TDataStd Attributes** | 25 | setInteger, integer, setReal, real, setAsciiString, asciiString, setComment, comment, initIntegerArray, setIntegerArrayValue, integerArrayValue, integerArrayBounds, initRealArray, setRealArrayValue, realArrayValue, realArrayBounds, setTreeNode, appendTreeChild, treeNodeFather, treeNodeFirstChild, treeNodeNext, treeNodeHasFather, treeNodeDepth, treeNodeChildCount, namedData(set/get/has integer/real/string) |
| **TDataXtd Attributes** | 16 | setShapeAttr, shapeAttribute, hasShapeAttribute, setPositionAttr, positionAttribute, hasPositionAttribute, setGeometryType, geometryType, hasGeometryAttribute, setTriangulationFromShape, triangulationNodeCount, triangulationTriangleCount, triangulationDeflection, setPointAttr, setAxisAttr, setPlaneAttr |
| **TFunction Framework** | 13 | setLogbook, logbookSetTouched, logbookSetImpacted, logbookIsModified, logbookClear, logbookIsEmpty, setGraphNode, graphNodeAddPrevious, graphNodeAddNext, setGraphNodeStatus, graphNodeStatus, graphNodeRemoveAllPrevious, graphNodeRemoveAllNext |
| **TFunction Function** | 4 | setFunctionAttribute, functionIsFailed, functionFailure, setFunctionFailure |
| **OCAF Persistence** | 17 | defineFormatBin, defineFormatBinL, defineFormatXml, defineFormatXmlL, defineFormatBinXCAF, defineFormatXmlXCAF, defineAllFormats, saveOCAF, loadOCAF, saveOCAFInPlace, createWithFormat, isSaved, storageFormat, setStorageFormat, documentCount, readingFormats, writingFormats |
| **STEP Full Coverage** | 25 | StepModelType enum (7 values), writeSTEP(modelType:), writeSTEP(modelType:tolerance:), writeSTEPCleanDuplicates, stepRootCount, loadSTEPRoot, loadSTEP(unitInMeters:), stepShapeCount, STEPReaderModes, STEPWriterModes, Document.loadSTEP(modes:), Document.writeSTEP(modelType:modes:), fromPath variants |
| **IGES/OBJ/PLY Full Coverage** | 23 | igesRootCount, loadIGESRoot, igesShapeCount, loadIGESVisible, writeIGES(unit:), writeIGESBRep, writeIGES(shapes:), Document.loadOBJ, Document.loadOBJ(singlePrecision:), Document.loadOBJ(inputCS:outputCS:), Document.writeOBJ, Document.writePLY(normals:colors:texCoords:), writePLY(options:), MeshCoordinateSystem enum |
| **XDE/XCAF Full Coverage** | 42 | shapeCount, shapeLabelId, freeShapeCount, freeShapeLabelId, isTopLevel, isComponent, isCompound, isSubShape, findShape, searchShape, subShapeCount, subShapeLabelId, addShape, newShapeLabel, removeShape, addComponent, removeComponent, componentCount, componentLabelId, componentReferredLabelId, shapeUserCount, updateAssemblies, expandShape, setShapeColor, shapeColor, isShapeColorSet, setLabelVisibility, getLabelVisibility, setArea, getArea, setVolume, getVolume, setCentroid, getCentroid, setLayer, isLayerSet, getLabelLayers, findLayer, setLayerVisibility, getLayerVisibility, editorExpand, rescaleGeometry |
| **Length Dimension** | 7 | fromPoints, fromEdge, fromFaces, value, isValid, geometry, setCustomValue |
| **Radius Dimension** | 4 | fromShape, value, geometry, setCustomValue |
| **Angle Dimension** | 7 | fromEdges, fromPoints, fromFaces, value, degrees, geometry, setCustomValue |
| **Diameter Dimension** | 4 | fromShape, value, geometry, setCustomValue |
| **Text Label** | 5 | create, text, position, setHeight, getInfo |
| **Point Cloud** | 6 | create, createColored, count, bounds, points, colors |
| **KD-Tree** | 5 | build, nearest, kNearest, rangeSearch, boxSearch |
| **Shape History** | 1 | History (create, addModified, addGenerated, remove, isRemoved, hasModified, hasGenerated, hasRemoved, modifiedCount, generatedCount) |
| **Contour Analysis** | 3 | contourSphereDir, contourCylinderDir, contourSphereEye |
| **IntCurvesFace** | 1 | intersectLine (line-face intersection) |
| **BOPAlgo Utilities** | 17 | split (splitter), CellsBuilder (create, addAll, removeAll, removeInternalBoundaries, result), analyzeBoolean, removeFeatures, section(instance), section(static), buildFaces, buildSolids, splitShell, edgesToWires, wiresToFaces, makeWire |
| **IntTools** | 6 | edgeEdgeIntersection, edgeFaceIntersection, faceFaceIntersection, classifyPoint2d, isHole, beanFaceIntersect |
| **BOPTools** | 4 | normalOnEdge, pointInFace, isEmpty, isOpenShell |
| **PCurve / BRepAdaptor** | 3 | pcurveParams, pcurveValue, approxCurveOnSurface |
| **Mesh Deflection** | 2 | computeAbsoluteDeflection, deflectionIsConsistent |
| **Shape from Mesh** | 1 | fromMesh (BRepBuilderAPI_MakeShapeOnMesh) |
| **Plate Surface** | 1 | plateSurface (GeomPlate_BuildPlateSurface + MakeApprox) |
| **BRepLib Topology** | 9 | edgeFromLine, edgeFromPoints, edgeFromCircle, faceFromPlane, faceFromCylinder, shellFromPlane, computeNormals, pointCloudByTriangulation, pointCloudByDensity |
| **2D Edges** | 3 | edge2d(points), edge2dFromCircle, edge2dFromLine |
| **BRepTools Modifier** | 1 | nurbsConvertViaModifier |
| **ShapeCustom** | 2 | directModification, trsfModificationScale |
| **LocOpe Extensions** | 5 | buildWires, splitByWireOnFace, curveShapeIntersect, locOpeSplit, locOpeSplitAuto |
| **CPnts Deflection** | 2 | uniformDeflection, uniformDeflection(range) |
| **IntCurvesFace** | 2 | rayIntersect, rayIntersectNearest |
| **GeomLProp** | 2 | curveLocalProps, surfaceLocalProps |
| **BRepOffset** | 1 | simpleOffsetShape |
| **Approx** | 1 | curvilinearParameter |
| **GeomInt** | 1 | surfaceSurfaceIntersection |
| **Contap** | 2 | contapContourDirection, contapContourEye |
| **BRepFeat** | 6 | featFuse, featCut, splitByEdge, splitByWire, splitWithSides, glue |
| **GeomFill Filling** | 3 | coonsFilling, curvedFilling, coonsAlgPatch |
| **GeomFill Sweep** | 1 | geomFillSweep |
| **GeomFill Section** | 1 | evolvedSectionInfo |
| **ProjLib** | 2 | projectOntoSurface, projectOntoPolarSurface |
| **BRepOffset** | 1 | offsetFace |
| **Adaptor3d IsoCurve** | 4 | uIsoCurvePoints, vIsoCurvePoints, uIsoCurveEdge, vIsoCurveEdge |
| **ShapeAnalysis Transfer** | 2 | transferParameterToFace, transferParameterFromFace |
| **ShapeBuild Edge** | 9 | copyEdge, copyEdgeReplacingVertices, setEdgeRange3d, buildEdgeCurve3d, removeEdgeCurve3d, copyEdgeRanges, copyEdgePCurves, removeEdgePCurve, reassignEdgePCurve |
| **ShapeBuild Vertex** | 2 | combineVertex, combineVertices(static) |
| **ShapeExtend Explorer** | 2 | sortedCompound, predominantShapeType |
| **ShapeUpgrade Divide** | 4 | divideFace, divideWire, analyzeEdgeDivide, canDivideClosedEdge |
| **ShapeUpgrade Fix** | 2 | fixSmallCurves, fixSmallBezierCurves |
| **ShapeUpgrade Convert** | 2 | convertCurves3dToBezier, convertSurfacesToBezier |
| **Point2D (Geom2d_CartesianPoint)** | 13 | create, x, y, setCoords, distance, squareDistance, translated, rotated, scaled, mirroredPoint, mirroredAxis, distanceToCurve, transformed |
| **Transform2D (Geom2d_Transformation)** | 14 | identity, translation, rotation, scale, mirrorPoint, mirrorAxis, inverted, composed, powered, apply, scaleFactor, isNegative, matrixValues, applyToCurve |
| **AxisPlacement2D (Geom2d_AxisPlacement)** | 5 | create, origin, direction, reversed, angle |
| **Vector2D Utilities** | 5 | angle, cross, dot, magnitude, normalize |
| **Direction2D Utilities** | 3 | normalize, angle, cross |
| **LProp AnalyticCurInf** | 1 | analyticCurvaturePoints (inflection/min/max curvature for analytic curves) |
| **Curve2D ↔ Point2D** | 3 | pointAt, segment(from:Point2D), project(Point2D) |
| **FairCurve** | 2 | fairCurveBatten, fairCurveMinimalVariation |
| **LocalAnalysis** | 4 | curveContinuity, curveContinuityFlags, surfaceContinuity, surfaceContinuityFlags |
| **TopTrans** | 4 | surfaceTransition, surfaceTransitionWithCurvature, curveTransition, curveTransitionWithCurvature |
| **GeomFill Trihedrons** | 7 | draftTrihedron, discreteTrihedron, correctedFrenet, frenetTrihedron, fixedTrihedron, constantBiNormalTrihedron, darbouxTrihedron |
| **GeomFill NSections** | 2 | nSections, nSectionsInfo |
| **Law Extensions** | 2 | composite, knotSplitting |
| **GccAna Circ2d3Tan** | 6 | circleThrough3Points, circleTangent3Lines, circleTangent3Circles, circleTangent2CirclesPoint, circleTangentCircle2Points, circleTangent2LinesPoint |
| **Polygon Interference** | 2 | polygonInterference, polygonSelfInterference |
| **ChFi2d Edge Operations** | 2 | chamfer2dEdges, fillet2dEdges |
| **FilletSurf** | 2 | filletSurfaces, filletSurfError |
| **HLR Extended** | 6 | hlrEdges (by category), hlrPolyEdges, hlrCompoundOfEdges, reflectLines, reflectLinesFiltered, edgeFaceTransition |
| **Interval Arithmetic** | 23 | Interval create/bounds/isProbablyEmpty/position/isBefore/isAfter/isInside/isEnclosing/isSimilar/setStart/setEnd/fuseAtStart/fuseAtEnd/cutAtStart/cutAtEnd, IntervalSet create/createEmpty/count/bounds/unite/subtract/intersect/xUnite |
| **Ray-Shape Intersection (BRepIntCurveSurface)** | 4 | lineIntersection, curveIntersection, allHits, hitFace |
| **ShapeConstruct Triangulation** | 2 | triangulationFromPoints, triangulationFromWire |
| **Surface Periodic Conversion** | 2 | convertToPeriodic, conversionGap |
| **Mesh Linear Properties** | 2 | meshPolygonPoints (edge), meshCinertCompute |
| **Mesh Surface/Volume Properties** | 2 | meshProps(surface), meshProps(volume) |
| **Mesh Shape Utilities** | 3 | maxMeshTolerance, meshMaxDimension, uvPoints |
| **Edge Validation** | 1 | validate(on:face:tolerance:) |
| **BiTgte Blend** | 1 | biTgteBlend (rolling-ball blend on edges) |
| **GeomConvert Approx** | 2 | approxWithDetails (curve), approxWithDetails (surface) |
| **GCPnts Sampling** | 2 | quasiUniformParameters (edge), tangentialDeflectionPoints (edge) |
| **BRepGProp Per-Face** | 5 | curveInertia, surfaceInertia, surfaceInertia(epsilon:), volumeInertia, volumeInertia(planeNormal:) |
| **Curve-Surface Projection** | 1 | projectOnSurface |
| **Preview Shapes** | 1 | previewBox (degenerate-safe box preview) |
| **GeomPoint3D (Geom_CartesianPoint)** | 8 | create, x, y, z, setCoordinates, distance, squareDistance, translate |
| **GeomDirection (Geom_Direction)** | 4 | create, coordinates, setCoordinates, crossed |
| **GeomVector3D (Geom_VectorWithMagnitude)** | 9 | create, fromPoints, coordinates, magnitude, dot, added, multiplied, normalized, crossed |
| **Axis1Placement (Geom_Axis1Placement)** | 7 | create, location, direction, reverse, reversed, setDirection, setLocation |
| **Axis2Placement (Geom_Axis2Placement)** | 7 | create, location, mainDirection, xDirection, yDirection, setDirection, setXDirection |
| **ShapeConstruct Curve** | 4 | convertSegmentToBSpline3D, convertSegmentToBSpline2D, adjustEndpoints3D, adjustEndpoints2D |
| **Bisector Intersection** | 2 | bisectorIntersections (point-point bisector intersection), BisectorPoint data |
| **GeomLib Tool** | 3 | parameterOf (3D curve), parametersOf (surface UV), parameterOf (2D curve) |
| **GeomLib IsPlanarSurface** | 2 | isPlanar, planarPlane (extract plane from surface) |
| **GeomLib CheckBSpline** | 4 | checkBSplineTangents (3D/2D), fixBSplineTangents (3D/2D) |
| **GeomLib Interpolate** | 1 | polynomialInterpolation (BSpline through points at parameters) |
| **GccAna Circ2d2TanRad** | 2 | circlesTangentToLines, circlesThroughPointsWithRadius |
| **GccAna Circ2dTanCen** | 2 | circleThroughPointCentered, circleTangentToLineCentered |
| **GccAna Lin2d2Tan** | 2 | lineThroughPoints, linesTangentToCircleThroughPoint |
| **Approx SameParameter** | 1 | checkSameParameter (3D vs 2D on surface) |
| **ShapeUpgrade CurveSplit** | 3 | splitByContinuity (3D/2D), convertToBezierSegments (2D) |
| **ShapeUpgrade SurfaceSplit** | 3 | splitSurfaceByContinuity, splitByAngle, splitByArea |
| **GeomConvert Recognition** | 5 | curveToAnalytical, arePointsLinear, surfToAnalyticalWithGap, surfToAnalyticalBounded, isCanonical |
| **Geom2dConvert** | 1 | approxArcsAndSegments (approximate 2D curves as arcs/lines) |
| **Poly_Polygon2D** | 5 | create, nodeCount, node, nodes, deflection |
| **Poly_Polygon3D** | 8 | create, createWithParams, nodeCount, node, nodes, hasParameters, parameter, deflection |
| **Poly_PolygonOnTriangulation** | 7 | create, createWithParams, nodeCount, nodeIndex, hasParameters, parameter, deflection |
| **Poly_MergeNodesTool** | 1 | mergedMeshNodes (merge duplicate vertices from shape triangulations) |
| **Poly_CoherentTriangulation** | 12 | create, createFromMesh, setNode, addTriangle, removeTriangle, triangleCount, computeLinks, linkCount, deflection, removeDegenerated, getResult, nodeCoords |
| **BRepFill_Evolved** | 1 | evolved (face spine + wire profile sweep) |
| **BRepFill_OffsetAncestors** | 3 | create, hasAncestor, ancestor (trace offset wire edge ancestry) |
| **BRepExtrema_DistanceSS** | 1 | distanceSS (sub-shape to sub-shape minimum distance) |
| **BRepGProp_VinertGK** | 1 | vinertGK (Gauss-Kronrod volume integration on face) |
| **GeomFill_Profiler** | 8 | create, addCurve, perform, degree, poleCount, knotCount, isPeriodic, poles, knotsAndMults |
| **GeomFill_Stretch** | 1 | stretchFill (4-boundary stretch surface) |
| **GeomFill_LocationDraft** | 4 | create, setCurve, evaluate, setAngle, direction |
| **GeomFill_GuideTrihedronAC** | 2 | create+setCurve, evaluate (arc-length corrected guide frame) |
| **GeomFill_GuideTrihedronPlan** | 2 | create+setCurve, evaluate (planar guide frame) |
| **GeomFill_SectionPlacement** | 1 | sectionPlacement (place section on sweep path) |
| **BRepFill_NSections** | 3 | create, lawCount, isConstant, isVertex |
| **GeomFill_AppSurf** | 1 | appSurf (approximate surface from section curves) |
| **ShapeFix_ComposeShell** | 1 | composeShell (split face into sub-faces) |
| **Extrema 3D/2D** | 10 | extremaCC, extremaCCPoint, extremaCS, extremaCSPoint, extremaPS, extremaPSPoint, extremaSS, extremaSSPoint, locateExtremaCC, locateExtremaCC2d |
| **GeomTools Persistence** | 6 | serializeCurves (3D), deserializeCurves (3D), serializeCurves (2D), deserializeCurves (2D), serializeSurfaces, deserializeSurfaces |
| **ProjLib Projection** | 1 | projectOnSurface (BSpline approximation) |
| **gce 3D Geometry Factories** | 11 | circleThrough3Points, circleFromCenterNormal, lineFrom2Points, directionFrom2Points, ellipseFromCenterNormal, hyperbolaFromCenterNormal, parabolaFromCenterNormal, coneFrom2PointsRadii, cylinderFrom3Points, planeFromEquation, planeFrom3Points |
| **gce 2D Geometry Factories** | 7 | circleFromCenterRadius, circleThrough3Points, lineFrom2Points, lineFromEquation, ellipseFromCenterDir, hyperbolaFromCenterDir, parabolaFromCenterDir |
| **Quantity_Color** | 17 | fromName, fromHex, fromHexRGBA, toHex, toHexRGBA, distance, squareDistance, deltaE2000, hls, fromHLS, withIntensityChanged, withContrastChanged, sRGB, linearRGB, lab, namedColorName, epsilon |
| **Graphic3d Material/PBR** | 7 | predefinedMaterialCount, predefinedMaterialName, predefinedMaterial(named:), predefinedMaterial(at:), minRoughness, roughnessFromSpecular, metallicFromSpecular |
| **Quantity_Period** | 9 | create, createFromSeconds, components, totalSeconds, add, subtract, compare, isValid, isValidSeconds |
| **Quantity_Date** | 9 | create, epoch, components, addPeriod, subtractPeriod, difference, compare, isValid, isLeap |
| **Font_FontMgr** | 6 | initDatabase, fontCount, fontName, fontPath, fontHasAspect, aspectToString |
| **Image_AlienPixMap** | 15 | create, release, initTrash, initCopy, clear, width, height, format, isEmpty, getPixel, setPixel, save, load, adjustGamma, sizePixelBytes, isTopDownDefault |
| **XCAFDoc_Location** | 3 | setLocation, getLocation, hasLocation |
| **XCAFDoc_GraphNode** | 10 | setGraphNode, setChild, setFather, unSetChild, unSetFather, nbChildren, nbFathers, getChild, getFather, isFather |
| **XCAFDoc_Color** | 7 | setColor (RGB/RGBA/NOC/components), getColor, getColorRGBA, getAlpha, getNOC |
| **XCAFDoc_Material** | 6 | setMaterial, getName, getDescription, getDensity, getDensName, getDensValType |
| **XCAFDoc Notes** | 14 | createComment, createBalloon, createBinData (array), nbNotes, nbAnnotatedItems, deleteNote, deleteAllNotes, nbOrphanNotes, deleteOrphanNotes, noteUserName, noteTimeStamp, noteCommentText, noteBinDataSize, noteBinDataTitle |
| **XCAFDoc_ClippingPlaneTool** | 7 | addClippingPlane, getClippingPlane, isClippingPlane, removeClippingPlane, getClippingPlaneCount, setCapping, getCapping |
| **XCAFDoc_ShapeMapTool** | 4 | setShapeMap, isSubShape, shapeMapExtent, hasShapeMap |
| **XCAFDoc_AssemblyGraph** | 8 | createFromDoc, release, nbNodes, nbLinks, nbRoots, getNodeType, hasChildren, isDirectLink |
| **XCAFDoc_AssemblyItemId** | 5 | createFromString, toString, isNull, isEqual, pathCount |
| **XCAFView_Object** | 15 | create, release, projectionType, projectionPoint, viewDirection, upDirection, zoomFactor, windowSize, frontPlane, backPlane, unsetFrontPlane, unsetBackPlane, hasVolumeSidesClipping, name, setName |
| **XCAFNoteObjects_NoteObject** | 9 | create, release, hasPlane, getPlane, setPlane, hasPoint, getPoint, setPoint, reset |
| **XCAFPrs_Style** | 7 | isEmpty, setColorSurf, getColorSurf, setColorCurv, setVisibility, isVisible, isEqual |
| **XCAFDoc_VisMaterialCommon** | 1 | create (struct with diffuse/ambient/specular/emissive, shininess, transparency) |
| **XCAFDoc_VisMaterialPBR** | 1 | create (struct with baseColor, metallic, roughness, IOR, emissiveFactor) |
| **VrmlAPI_Writer** | 2 | writeVRML (shape), writeVRML (document with scale) |
| **TDataStd_Directory** | 4 | createDirectory, hasDirectory, addSubDirectory, makeObjectLabel |
| **TDataStd_Variable** | 13 | setVariable, setVariableName, variableName, setVariableValue, variableValue, variableIsValued, setVariableUnit, variableUnit, setVariableConstant, variableIsConstant, assignExpression, desassignExpression, variableIsAssigned |
| **TDataStd_Expression** | 4 | setExpression, setExpressionString, expressionString, expressionName |
| **TDocStd_XLink** | 5 | setXLink, setXLinkDocumentEntry, xLinkDocumentEntry, setXLinkLabelEntry, xLinkLabelEntry |
| **XCAFDimTolObjects_Tool** | 2 | dimTolToolDimensionCount, dimTolToolToleranceCount |
| **TPrsStd_DriverTable** | 3 | initStandard, exists, clear |
| **TObj_Application** | 4 | shared, isVerbose, setVerbose, createDocument |
| **UnitsAPI** | 7 | convert, toSI, fromSI, toLocalSystem, fromLocalSystem, currentSystem, check |
| **BinTools** | 4 | toBinaryData, fromBinaryData, writeBinary, loadBinary |
| **Message_Messenger** | 6 | create, release, send, sendInfo, sendWarning, sendAlarm |
| **Message_Report** | 7 | create, release, addAlert, alertCount, clearAlerts, sendAlerts, isActive |
| **RWMesh_CoordinateSystemConverter** | 2 | convertPoint, convertNormal |
| **TDF_IDFilter** | 8 | create, release, keep, ignore, isKept, isIgnored, copy, setIgnoreAll |
| **TDataStd_BooleanArray** | 3 | setBooleanArray, booleanArray, hasBooleanArray |
| **TDataStd_BooleanList** | 5 | setBooleanList, booleanList, booleanListAppend, booleanListClear, hasBooleanList |
| **TDataStd_ByteArray** | 3 | setByteArray, byteArray, hasByteArray |
| **TDataStd_IntegerList** | 5 | setIntegerList, integerList, integerListAppend, integerListClear, hasIntegerList |
| **TDataStd_RealList** | 5 | setRealList, realList, realListAppend, realListClear, hasRealList |
| **TDataStd_ExtStringArray** | 4 | setExtStringArray, extStringArrayValue, extStringArrayLength, hasExtStringArray |
| **TDataStd_ExtStringList** | 6 | setExtStringList, extStringListCount, extStringListValue, extStringListAppend, extStringListClear, hasExtStringList |
| **TDataStd_ReferenceArray** | 3 | setReferenceArray, referenceArray, hasReferenceArray |
| **TDataStd_ReferenceList** | 5 | setReferenceList, referenceList, referenceListAppend, referenceListClear, hasReferenceList |
| **TDataStd_Relation** | 3 | setRelation, relation, hasRelation |
| **ShapeFix_Solid** | 2 | fixSolid, solidFromShellFixed |
| **ShapeFix_EdgeConnect** | 1 | fixEdgeConnect |
| **BRepOffsetAPI_FindContigousEdges** | 1 | findContigousEdges |
| **TDataStd_Tick** | 3 | setTick, hasTick, removeTick |
| **TDataStd_Current** | 3 | setCurrentLabel, currentLabel, hasCurrentLabel |
| **ShapeAnalysis_Shell** | 1 | analyzeShell (orientation, free/bad/connected edges) |
| **ShapeAnalysis_CanonicalRecognition** | 2 | recognizeCanonicalSurface, recognizeCanonicalCurve |
| **Geom_Transformation** | 14 | create, release, setTranslation, setRotation, setScale, setMirrorPoint, setMirrorAxis, scaleFactor, isNegative, apply, value, multiplied, inverted |
| **Geom_OffsetCurve** | 3 | offset, offsetValue, offsetDirection |
| **Geom_RectangularTrimmedSurface** | 3 | rectangularTrimmed, trimmedInU, trimmedInV |
| **TNaming Extensions** | 9 | namingIsEmpty, namingVersion, setNamingVersion, namingOriginalShape, namingHasLabel, namingFindLabel, namingValidUntil, sameShapeCount, sameShapeLabels |
| **TDataStd_IntPackedMap** | 9 | setIntPackedMap, intPackedMapAdd, intPackedMapRemove, intPackedMapContains, intPackedMapCount, intPackedMapClear, intPackedMapIsEmpty, intPackedMapValues, intPackedMapSetValues |
| **TDataStd_NoteBook** | 4 | setNoteBook, noteBookAppendReal, noteBookAppendInteger, noteBookExists |
| **TDataStd_UAttribute** | 3 | setUAttribute, hasUAttribute, uAttributeID |
| **TDataStd_ChildNodeIterator** | 1 | childNodeCount |
| **TDF_Transaction Named** | 3 | openNamedTransaction, commitWithDelta, transactionNumber |
| **TDF_Delta** | 7 | deltaIsEmpty, deltaBeginTime, deltaEndTime, deltaAttributeDeltaCount, deltaSetName, deltaGetName, deltaRelease |
| **TDF_ComparisonTool** | 1 | isSelfContained |
| **TDocStd_XLinkTool** | 2 | xlinkCopy, xlinkCopyWithLink |
| **TFunction_IFunction** | 4 | newFunction, deleteFunction, functionExecStatus, setFunctionExecStatus |
| **TFunction_Scope** | 7 | setFunctionScope, functionScopeAdd, functionScopeRemove, functionScopeHas, functionScopeRemoveAll, functionScopeCount, functionScopeFreeID |
| **TDF_AttributeIterator** | 1 | attributeCount |
| **TDF_DataSet** | 1 | dataSetIsEmpty |
| **TDF_ChildIDIterator** | 1 | childIDCount |
| **TDocStd_PathParser** | 3 | trek, name, fileExtension |
| **TFunction_DriverTable** | 2 | hasDriver, clear |
| **TNaming_Scope** | 6 | valid, validChildren, isValid, unvalid, clear, validCount |
| **TNaming_Translator** | 2 | translatorCopy, isSame |
| **TDataXtd_Placement** | 2 | setPlacement, hasPlacement |
| **TDataXtd_Presentation** | 13 | set, unset, has, setDisplayed, isDisplayed, setColor, getColor, setTransparency, getTransparency, setWidth, getWidth, setMode, getMode |
| **XCAFDoc_AssemblyIterator** | 1 | assemblyItemCount |
| **XCAFDoc_DimTol** | 5 | setDimTol, dimTolKind, dimTolName, dimTolDescription, dimTolValues |
| **IntTools_Tools** | 5 | computeVV, intermediatePoint, isDirsCoinside, isDirsCoinisdeWithTol, computeIntRange |
| **ElCLib** | 8 | valueOnLine, valueOnCircle, valueOnEllipse, d1OnLine, d1OnCircle, parameterOnLine, parameterOnCircle, inPeriod |
| **ElSLib** | 7 | valueOnPlane, valueOnCylinder, valueOnCone, valueOnSphere, valueOnTorus, parametersOnSphere, d1OnSphere |
| **gp_Quaternion** | 11 | create, fromAxisAngle, fromVectors, getComponents, setEulerAngles, getEulerAngles, getMatrix, rotate, multiplied, axisAngle, rotationAngle, normalize |
| **OSD_Timer** | 5 | start, stop, reset, elapsedTime, wallClockTime |
| **Bnd_OBB** | 8 | create, fromShape, isVoid, center, halfSizes, isOutPoint, isOutOBB, enlarge, squareExtent |
| **Bnd_Range** | 11 | create, isVoid, bounds, delta, contains, addValue, addRange, common, enlarge, trimFrom, trimTo |
| **BRepClass3d** | 1 | classifyPoint |
| **TDataXtd_Constraint** | 9 | set, setType, getType, nbGeometries, isPlanar, isDimension, setVerified, getVerified, clearGeometries |
| **OSD_MemInfo** | 4 | heapUsage, workingSet, heapUsageMiB, infoString |
| **ShapeFix_EdgeProjAux** | 1 | edgeProjAux |
| **Geom2dAPI_Interpolate** | 1 | interpolate2D |
| **Geom2dAPI_PointsToBSpline** | 1 | approximate2D |
| **TDataXtd_PatternStd** | 5 | setPattern, hasPattern, setSignature, getSignature, nbTrsfs |
| **BRepAlgo_FaceRestrictor** | 1 | faceRestrictAlgo |
| **math_Matrix** | 8 | create, rows, cols, getValue, setValue, determinant, invert, multiplyScalar, transpose |
| **math_Gauss** | 2 | solve, determinant |
| **math_SVD** | 1 | solve |
| **math_DirectPolynomialRoots** | 1 | solve |
| **math_Jacobi** | 1 | eigenvalues |
| **Convert_CircleToBSplineCurve** | 1 | fromCircleArc |
| **Convert_SphereToBSplineSurface** | 1 | fromSphere |
| **OSD_Environment** | 3 | get, set, remove |
| **Convert_EllipseToBSplineCurve** | 1 | fromEllipseArc |
| **Convert_HyperbolaToBSplineCurve** | 1 | fromHyperbolaArc |
| **Convert_ParabolaToBSplineCurve** | 1 | fromParabolaArc |
| **Convert_CylinderToBSplineSurface** | 1 | fromCylinder |
| **Convert_ConeToBSplineSurface** | 1 | fromCone |
| **Convert_TorusToBSplineSurface** | 1 | fromTorus |
| **math_Householder** | 1 | solve |
| **math_Crout** | 2 | solve, determinant |
| **ShapeFix_IntersectionTool** | 1 | fixIntersectingWires |
| **XCAFDoc_AssemblyItemRef** | 7 | setAssemblyItemRef, assemblyItemRefPath, setSubshape, getSubshape, hasExtra, clearExtra, isOrphan |
| **BRepAlgo_Image** | 5 | create, setRoot, bind, hasImage, isImage, clear |
| **OSD_Path** | 9 | name, fileExtension, trek, systemName, folderAndFile, isValid, isUnixPath, isRelative, isAbsolute |
| **BRepClass_FClassifier** | 1 | classifyPoint2D |
| **BRepAlgo_Loop** | 1 | buildLoops |
| **Bnd_BoundSortBox** | 2 | create, compare |
| **BRepGProp_Domain** | 1 | faceDomainEdgeCount |
| **TNaming_Naming** | 2 | insertNaming, namingIsDefined |
| **Precision** | 7 | confusion, angular, intersection, approximation, infinite, pConfusion, isInfinite |
| **IntAna_IntConicQuad** | 2 | linePlane, lineSphere |
| **IntAna_QuadQuadGeo** | 2 | planePlane, planeSphere |
| **IntAna_Int3Pln** | 1 | threePlanes |
| **IntAna_IntLinTorus** | 1 | lineTorus |
| **OSD_Chronometer** | 2 | processCPU, threadCPU |
| **OSD_Process** | 4 | processId, userName, executablePath, executableFolder |
| **Draft_Modification** | 1 | draftModification |
| **Convert_CompBezierCurvesToBSplineCurve** | 1 | toBSpline (composite 3D Bezier → BSpline) |
| **Convert_CompBezierCurves2dToBSplineCurve2d** | 1 | toBSpline2d (composite 2D Bezier → BSpline) |
| **Geom_OffsetSurface Extensions** | 3 | offsetValue, setOffsetValue, offsetBasis |
| **OSD_File** | 13 | create, createTemporary, open, openReadOnly, write, readLine, readAll, close, isOpen, fileSize, rewind, isAtEnd, release |
| **ShapeFix_Wireframe Extensions** | 2 | fixWireGaps, fixSmallEdges |
| **RWStl** | 3 | writeSTLBinary, writeSTLAscii, readSTL |
| **ShapeAnalysis_Curve Statics** | 2 | isClosedWithPrecision, isPeriodicSA |
| **BRepExtrema_SelfIntersection Pairs** | 1 | selfIntersectionPairs (face-pair overlap reporting) |
| **Geom_OffsetCurve Basis** | 1 | offsetBasisCurve |
| **APIHeaderSection_MakeHeader** | 15 | StepHeader create/release/isDone, get/set name/timeStamp/author/organization/preprocessorVersion/originatingSystem |
| **ShapeAnalysis_FreeBounds Simplified** | 3 | freeBoundsClosedCount, freeBoundsClosedWires, freeBoundsOpenWires |
| **Geom_TrimmedCurve** | 5 | trimmed, startPoint, endPoint, trimmedBasis, setTrim |
| **BRepLib_FindSurface** | 3 | findSurface, findSurfaceTolerance, findSurfaceExisted |
| **ShapeAnalysis_Surface Extensions** | 9 | projectPointUV, hasSingularitiesSA, singularityCountSA, isUClosedSA, isVClosedSA, uvFromIso, singularity(detail), projectDegenerated, projectPoint(uDomain:vDomain:) |
| **Resource_Manager** | 9 | create, release, setString, setInt, setReal, find, getString, getInt, getReal |
| **TopExp Adjacency** | 9 | edgeFirstVertex, edgeLastVertex, edgeVertices, wireVertices, commonVertex, edgeFaceAdjacency, vertexEdgeAdjacency, adjacentFaces(forEdge), adjacentEdges(forVertex) |
| **Poly_Connect Mesh Adjacency** | 3 | meshTriangleAdjacency, meshNodeTriangle, meshNodeTriangleCount |
| **BRepOffset_Analyse** | 5 | analyseEdgeConcavity, analyseExplode, analyseEdgesOnFace, analyseAncestorCount, analyseTangentEdgeCount |
| **BRepTools_WireExplorer Extensions** | 2 | wireEdgeOrientations, wireExplorerVertices |
| **gce Transform Factories 3D** | 7 | mirrorPoint, mirrorAxis, mirrorPlane, rotation, scale, translationVec, translationPoints |
| **gce Transform Factories 2D** | 8 | mirrorPoint2d, mirrorAxis2d, rotation2d, scale2d, translationVec2d, translationPoints2d, dir2d, dir2dFromPoints |
| **GProp Element Properties** | 5 | lineSegment, circularArc, pointSetCentroid, sphereSurface, sphereVolume |
| **Plate Constraint Extensions** | 3 | planeConstraint, lineConstraint, freeG1Constraint |
| **Law_Interpolate** | 1 | interpolated (BSpline from values/parameters) |
| **Bnd_Sphere** | 8 | create, release, radius, center, distance, isOut, isOutSphere, add |
| **BndLib Analytic Bounding** | 7 | line, circle, sphere, cylinder, torus, edge, face |
| **OSD_Host** | 3 | hostName, systemVersion, internetAddress |
| **OSD_PerfMeter** | 5 | create, release, start, stop, elapsed |
| **GProp Cylinder/Cone** | 4 | cylinderSurface, cylinderVolume, coneSurface, coneVolume |
| **IntAna_IntQuadQuad** | 2 | cylinderSphere, cylinderSphereIdentical |
| **XCAFPrs_DocumentExplorer** | 7 | nodeCount, shapeAtIndex, pathId, findShapeFromPathId, depth, isAssembly, location |
| **GC_MakeCircle** | 4 | circle from axis+radius, 3 points, center+normal, parallel |
| **GC_MakeEllipse** | 3 | ellipse from axis+radii, 3 points, full Ax2 |
| **GC_MakeHyperbola** | 2 | hyperbola from axis+radii, 3 points |
| **GCE2d_MakeCircle** | 5 | 2D circle: center+radius, 3 points, center+point, parallel, axis |
| **GCE2d_MakeEllipse** | 3 | 2D ellipse: axis+radii, 3 points, Ax22d |
| **GCE2d_MakeHyperbola** | 2 | 2D hyperbola: axis+radii, 3 points |
| **GCE2d_MakeParabola** | 2 | 2D parabola: axis+focal, directrix+focus |
| **GCPnts_UniformAbscissa** | 4 | uniform arc-length points by count/distance, full/subrange |
| **GeomConvert_CompCurveToBSpline** | 1 | concatenate bounded 3D curves into BSpline |
| **Geom2dConvert_CompCurveToBSpline** | 1 | concatenate bounded 2D curves into BSpline |
| **GeomConvert_BSplineSurfaceKnotSplitting** | 3 | surface knot splits U/V count and values |
| **Geom2dConvert_BSplineCurveKnotSplitting** | 2 | 2D curve knot split count and values |
| **BndLib Extras** | 6 | ellipse, cone, circleArc, ellipseArc, parabolaArc, hyperbolaArc bounds |
| **GProp Torus** | 2 | torus surface area, torus volume |
| **BRepTools_ReShape** | 8 | create, release, clear, remove, replace, isRecorded, apply, value |
| **BRepTools_Substitution** | 2 | substitute subshape, isCopied check |
| **BRepLib_MakeVertex** | 1 | vertex from 3D point |
| **BRepFill_PipeShell** | 15 | create, release, setFrenet, setDiscrete, setFixed, add, addAtVertex, setLaw, setTolerance, setTransition, build, shape, makeSolid, error, isReady |
| **OSD_Directory** | 4 | exists, create, buildTemporary, remove |
| **IntAna Extensions** | 4 | coneSphere intersection, curvePoints, isOpen, domain |
| **Resource_Unicode** | 4 | setFormat, getFormat, convertToUnicode, convertFromUnicode |
| **GProp Weighted** | 2 | weightedCentroid, barycentre |
| **Draft Info Types** | 6 | edgeInfoNewGeometry, faceInfoNewGeometry, vertexInfoGeometry, setTangent, faceFromSurface, vertexAddParameter |
| **GeomLib_LogSample** | 1 | logarithmic parameter sampling |
| **GC_MakeConicalSurface** | 3 | conical surface from axis/angle/radius, 2pts+radii, 4pts |
| **GC_MakeCylindricalSurface** | 5 | cylindrical surface from axis, 3pts, circle, parallel, axis1 |
| **GC_MakeTrimmedCone** | 2 | trimmed cone from 2pts+radii, 4pts |
| **GC_MakeTrimmedCylinder** | 3 | trimmed cylinder from circle+height, axis+radius+height, 3pts |
| **BRepLib_MakeEdge2d** | 5 | 2D edges from circle, ellipse, ellipseArc, Curve2D, Curve2D+range |
| **ShapeAnalysis_Wire** | 20 | wire quality: order, connected, small, degenerated, closed, selfIntersection, gaps, edgeCurves, lacking, distances, per-edge checks, outerBound |
| **ShapeAnalysis_Edge** | 15 | edge quality: hasCurve3d, isClosed, hasPCurve, isSeam, sameParameter, vertices, boundUV, tangent2d, overlap |
| **OSD_DirectoryIterator** | 3 | count, name, list directories |
| **OSD_FileIterator** | 3 | count, name, list files |
| **BRepFill_PipeShell Extensions** | 6 | maxDegree, maxSegments, forceC1, errorOnSurface, firstShape, lastShape |
| **Shape Topology Extensions** | 16 | orientation, reversed, complemented, composed, isFree, isModified, isChecked, isOrientable, isInfinite, isConvex, isEmpty, isPartner, isEqual, nbChildren, hashCode |
| **Curve/Surface Continuity** | 4 | Curve3D, Curve2D, Surface continuity, Surface nBounds |
| **BSplineCurve 3D Manipulation** | 16 | knotCount, poleCount, degree, isRational, getKnots, getMults, getPole, setPole, setWeight, getWeight, insertKnot, removeKnot, segment, increaseDegree, resolution, setPeriodic |
| **BSplineSurface Manipulation** | 16 | nbUKnots, nbVKnots, nbUPoles, nbVPoles, uDegree, vDegree, isURational, isVRational, getPole, setPole, setWeight, insertUKnot, insertVKnot, segment, increaseDegree, exchangeUV |
| **BSplineCurve 2D Manipulation** | 12 | knotCount, poleCount, degree, isRational, getPole, setPole, setWeight, insertKnot, removeKnot, segment, increaseDegree, resolution |
| **BezierCurve Manipulation** | 10 | getPole, setPole, setWeight, insertPoleAfter, removePole, segment, increaseDegree, isRational, degree, poleCount |
| **BRepTools/BRepLib Utilities** | 10 | clean, cleanGeometry, removeUnusedPCurves, update, checkSameRange, sameRange, buildCurve3d, updateTolerances, updateInnerTolerances, updateEdgeTolerance |
| **MakeFace Extras** | 7 | fromSphere, fromTorus, fromCone, fromSurfaceWire, fromSurfaceWireWithHoles, addHole, copy |
| **BRepBuilderAPI_Sewing Detailed** | 8 | create, release, add, perform, result, nbFreeEdges, nbContigousEdges, nbDegeneratedShapes |
| **Hatch_Hatcher** | 7 | create, release, addXLine, addYLine, trim, nbLines, nbIntervals |
| **Edge/Face Extraction** | 9 | extractCurve3D, extractPCurve, edgeTolerance, isDegenerated, extractSurface, faceTolerance, wireCount, vertexTolerance, vertexPoint |
| **Geom_Circle Properties** | 6 | radius, setRadius, eccentricity, xAxis, yAxis, center |
| **Geom_Ellipse Properties** | 10 | majorRadius, minorRadius, setMajor/Minor, eccentricity, focal, focus1/2, parameter, directrix |
| **Geom_Hyperbola Properties** | 8 | majorRadius, minorRadius, setMajor/Minor, eccentricity, focal, focus1, asymptote1 |
| **Geom_Parabola Properties** | 6 | focal, setFocal, focus, eccentricity, parameter, directrix |
| **Geom_Line Properties** | 6 | direction, location, setDirection, setLocation, position, lin |
| **Geom_Plane Properties** | 4 | coefficients, uIso, vIso, pln |
| **Geom_SphericalSurface Properties** | 8 | radius, setRadius, area, volume, center, uIso, vIso, sphere |
| **Geom_ToroidalSurface Properties** | 6 | majorRadius, minorRadius, setMajor/Minor, area, volume |
| **Geom_CylindricalSurface Properties** | 4 | radius, setRadius, axis, uIso |
| **Geom_ConicalSurface Properties** | 4 | semiAngle, refRadius, apex, axis |
| **Geom_SweptSurface Properties** | 2 | direction, basisCurve |
| **Geom2d_Circle Properties** | 5 | radius, setRadius, eccentricity, center, xAxis |
| **Geom2d_Ellipse Properties** | 7 | majorRadius, minorRadius, setMajor/Minor, eccentricity, focal, focus1 |
| **Geom2d_Hyperbola Properties** | 5 | majorRadius, minorRadius, eccentricity, focal, focus1 |
| **Geom2d_Parabola Properties** | 5 | focal, setFocal, focus, eccentricity, parameter |
| **Geom2d_Line Properties** | 6 | direction, location, setDirection, setLocation, distance, lin2d |
| **Geom2d_OffsetCurve Properties** | 3 | offset, setOffset, basisCurve |
| **Extrema_ExtElC** | 4 | lineToLine, lineToCircle, circleToCircle, lineToEllipse |
| **Extrema_ExtElCS** | 3 | lineToPlane, lineToSphere, lineToCylinder |
| **Extrema_ExtElSS** | 3 | planeToPlane, planeToSphere, sphereToSphere |
| **Extrema_ExtPElC** | 4 | pointToLine, pointToCircle, pointToEllipse, pointToParabola |
| **Extrema_ExtPElS** | 5 | pointToPlane, pointToSphere, pointToCylinder, pointToCone, pointToTorus |
| **math_TrigonometricFunctionRoots** | 2 | solve, hasInfiniteRoots |
| **IntAna2d_Conic** | 4 | fromCircle, fromLine, fromEllipse, lineCircleIntersection |
| **BRepAlgo_NormalProjection** | 5 | create, release, add, build, result |
| **OSD_Disk** | 4 | size, freeSpace, isValid, name |
| **OSD_SharedLibrary** | 5 | create, release, open, close, name |
| **Message_Msg** | 4 | message(forKey:), loadFile, loadDefault, hasMessage |
| **Plate Constraint Extensions (v2)** | 2 | globalTranslation, linearXYZ |
| **Shape Topology Counting** | 3 | faceCount, edgeCount, shapeTypeString |
| **Curve3D Extras** | 3 | reverse, copy, continuity |
| **Curve2D Extras** | 3 | reverse, copy, continuity |
| **Surface Extras** | 3 | parameterBounds, surfaceContinuityOrder, copy |
| **Math Solvers** | 7 | findRoot, findRootBounded, findRootBisection, solveSystem, minimize (BFGS), minimizePowell, minimizeBrent |
| **Curve3D Evaluation** | 6 | evalD0, evalD1, evalD2, evalD3, evalBatchD0, evalBatchD1 |
| **Curve2D Evaluation** | 5 | evalD0, evalD1, evalD2, evalBatchD0, evalBatchD1 |
| **Surface Evaluation** | 3 | evalD0, evalD1, evalD2 |
| **RWMesh_FaceIterator** | 10 | create, release, more, next, nbNodes, nbTriangles, node, hasNormals, normal, triangle |
| **RWMesh_VertexIterator** | 5 | create, release, more, next, point |
| **Intf_Tool** | 5 | create, release, linBox, beginParam, endParam |
| **BRepAlgo_AsDes** | 5 | create, release, add, hasDescendant, descendantCount |
| **BiTgte_CurveOnEdge** | 4 | create, release, domain, value |
| **Shape Location/Orientation** | 9 | child, isLocked, setLocked, located, getLocation, setLocation, oriented, compounded, empty |
| **Wire/Face Construction** | 8 | wireFromEdges, makeCompound, makeShell, isCompound, isSolid, isShell, isFace, isEdge |
| **BRepCheck Extended** | 8 | checkFaceStatus, checkEdgeStatus, checkVertexStatus, maxTolerance, minTolerance, avgTolerance, fixTolerance, limitMaxTolerance |
| **Curve3D/2D Type & Projection** | 5 | curveType (3D), parameterAtPoint (3D), curveType (2D), parameterAtPoint (2D), surfaceGetType |
| **Extrema Extras** | 4 | locateOnCurve, locateOnSurface, pointCurve, pointSurface |
| **MakeEdge Completions** | 12 | edgeFromEllipse, edgeFromEllipseArc, edgeFromHyperbolaArc, edgeFromParabolaArc, edgeFromCurve, edgeFromCurveParams, edgeFromCurvePoints, edgeOnSurface, edgeOnSurfaceParams, edgeVertex1, edgeVertex2, edgeError |
| **ProjectionOnCurve** | 8 | create, release, nbPoints, point, parameter, distance, lowerDistance, lowerParam |
| **ProjectionOnSurface** | 8 | create, release, nbPoints, point, parameters, distance, lowerDistance, lowerParams |
| **ShapeDistance (DistShapeShape)** | 12 | create, release, isDone, value, nbSolution, pointOnShape1, pointOnShape2, supportType1, supportType2, supportShape1, supportShape2 |
| **WireFixer** | 12 | create, release, fixReorder, fixConnected, fixSmall, fixDegenerated, fixSelfIntersection, fixLacking, fixClosed, fixGaps3d, fixEdgeCurves, wire |
| **FaceFixer** | 15 | create, release, perform, fixOrientation, fixAddNaturalBound, fixMissingSeam, fixSmallAreaWire, face, setMode, fixIntersectingWires, fixPeriodicDegenerated, fixWiresTwoCoincEdges, fixLoopWire, result, status |
| **BRepCheck_Face Diagnostics** | 3 | checkFaceIntersectingWires, checkFaceWireImbrication, checkFaceWireOrientation |
| **BRepGProp_Face Integration** | 2 | faceIntegrationOrders, faceIntegrationKnotsU |
| **MakeFace Completions** | 3 | fromSurfaceUV, fromGpPlane, fromGpCylinder |
| **IntCS Full Results** | 6 | create, release, nbPoints, point (with params), nbSegments |
| **BSplineCurve Mutations** | 8 | setKnot, getKnotSequence, getWeights, insertKnots, movePoint, localValue, maxDegree, locateU |
| **BSplineSurface Mutations** | 6 | setUKnot, setVKnot, getUKnots, getVKnots, getWeights, removeUKnot |
| **HelixGeom (rc4)** | 7 | helixBuild, helixCoilBuild, helixCurveEval, helixCurveD1, helixCurveD2, helixApproxToBSpline |
| **CoordinateSystem3D (gp_Ax3)** | 7 | create, createFromNormal, angle, isCoplanar, mirror, rotate, translate |
| **GeneralTransform2D (gp_GTrsf2d)** | 4 | affinity, multiply, invert, transformPoint |
| **Matrix2D (gp_Mat2d)** | 7 | identity, rotation, scale, determinant, invert, multiply, transpose |
| **Quaternion Interpolation** | 3 | slerp, nlerp, transformInterpolate |
| **Vector2D/3D Math (gp_XY/XYZ)** | 9 | modulus, cross, dot, normalize (2D), modulus, cross, dot, dotCross, normalize (3D) |
| **Math Solvers Part 2** | 13 | bracketedRoot, bracketMinimum, frpr, functionAllRoots, gaussLeastSquare, newtonFunctionRoot, uzawa, eigenvalues, eigenvaluesAndVectors, kronrodIntegrate, kronrodIntegrateAdaptive, gaussMultipleIntegration, gaussSetIntegration |
| **MathPoly rc4** | 4 | linearRoots, quadraticRoots, cubicRoots, quarticRoots |
| **MathInteg rc4** | 5 | integGauss, integGaussAdaptive, integKronrod, integKronrodAdaptive, integTanhSinh |
| **UnitsMethods** | 3 | lengthFactor, lengthUnitScale, dumpLengthUnit |
| **LProp3d Curve** | 4 | localCurvature, localTangent, localNormal, localCentreOfCurvature |
| **LProp3d Surface** | 2 | localCurvatures, localCurvatureDirections |
| **ProjLib Projectors** | 3 | projectLineOnPlane, projectLineOnCylinder, projectCircleOnPlane |
| **BRepBndLib** | 3 | boundingBox, boundingBoxOptimal, orientedBoundingBoxDetailed |
| **ShapeAnalysis Tolerance** | 3 | toleranceValue, toleranceOverCount, toleranceInRangeCount |
| **Boolean Validation** | 2 | isBooleanValid, isBooleanValidWith |
| **Defeaturing** | 1 | defeature(faces:) |
| **Polynomial Conversion** | 1 | polynomialToPoles |
| **Transform Extras** | 4 | transformed(byMatrix:), isTransformNegative, displacement, transformation |
| **TopExp Extras** | 1 | commonVertex |
| **BRep_Tool Extras** | 5 | edgeSameParameter, edgeSameRange, faceNaturalRestriction, edgeIsGeometric, faceIsGeometric |
| **Sewing Extras** | 2 | multipleEdgeCount, multipleEdge(at:) |
| **BREP Serialization** | 2 | toBREPString, fromBREPString |
| **Plane Geometry** | 3 | PlaneGeometry.distanceToPoint, distanceToLine, containsPoint |
| **Line Geometry** | 3 | LineGeometry.distanceToPoint, distanceToLine, containsPoint |
| **Bezier Surface** | 11 | bezierProperties (nbUPoles, nbVPoles, uDegree, vDegree, pole, setPole, setWeight, segment, isURational, isVRational, exchangeUV) |
| **Curve2D Bezier** | 7 | bezierProperties (degree, poleCount, isRational, pole, setPole, setWeight, resolution) |
| **Curve2D BSpline Extras** | 3 | bsplineSetPeriodic, bsplineWeight, bsplineWeights |
| **BSplineSurface Extras** | 4 | bsplineResolution, bsplineSetUPeriodic, bsplineSetVPeriodic, bsplineWeight |
| **Final Cleanup** | 25 | IsCN (curve3D/curve2D/surfaceU/V), ReversedParameter (curve3D/2D), ParametricTransformation, continuityOrder (curve3D/2D), surface UReversed/VReversed/UReversedParam/VReversedParam, RemoveVKnot, vecCrossMagnitude/CrossSquareMagnitude, dirIsOpposite/IsNormal, BezierResolution (curve3D/surface), MaxDegree (bezierCurve3D/2D/surface, bsplineSurface/curve2D) |
| **GLTF Import/Export** | 5 | importGLTF, exportGLTF (GLB/GLTF), documentLoadGLTF, documentWriteGLTF |
| **FilletBuilder** | 16 | create, addEdge, addEdgeEvolving, build, nbContours, nbEdges, hasResult, badShape, faultyContours, faultyVertices, getRadius, getLength, isConstant, removeEdge, reset |
| **ChamferBuilder** | 8 | create, addEdge, addEdgeTwoDists, addEdgeDistAngle, build, nbContours, isDistAngle |
| **BSpline Completions** | 25 | Surface: SetU/VNotPeriodic, SetU/VOrigin, IncreaseU/VMultiplicity, InsertU/VKnots, MovePoint, SetPoleCol/Row. Curve3D/2D: SetNotPeriodic, SetOrigin, IncreaseMultiplicity, IncrementMultiplicity, SetKnots, Reverse, MovePointAndTangent |
| **v0.122.0 Additions** | 44 | WireFixer: fixGaps2d, fixSeam, fixShifted, fixNotchedEdges, fixTails, setMaxTailAngle, setMaxTailWidth. ShapeFix_Edge: addCurve3d, addPCurve, removeCurve3d, removePCurve, fixReversed2d. BRepTools: cleanTriangulation, removeInternals, detectClosedness, evalAndUpdateTol, map3DEdgeCount, updateFaceUVPoints, compareVertices, compareEdges, isReallyClosed, updateTopology. BRepLib: ensureNormalConsistency, updateDeflection, continuityOfFaces, buildCurves3dAll, sameParameterAll. History: merge, replaceGenerated, replaceModified, getModifiedShapes, getGeneratedShapes. Sewing: nbDeletedFaces, deletedFace, isModified, modified, isDegenerated, isSectionBound, whichFace, load, setNonManifoldMode, setFaceMode, setFloatingEdgesMode, setMinTolerance, setMaxTolerance |
| **v0.123.0 Additions** | 37 | ThruSections: checkCompatibility, setParType, setCriteriumWeight, generatedFace. CellsBuilder: addToResult(selective), removeFromResult, allParts, makeContainers. PipeShell: getStatus, simulate. UnifySameDomainBuilder: create, allowInternalEdges, keepShape, setSafeInputMode, setLinearTolerance, setAngularTolerance, build, shape. Section: sectionWithOptions, ancestorFaceOn1, ancestorFaceOn2. Curve3D: period, firstParameter, lastParameter. Surface: uPeriod, vPeriod. Shape: nullified, typeName, isNotEqual, emptied, moved, orientationValue, nbEdges, nbFaces, nbVertices |
| **v0.124.0 Additions** | 54 | ChamferBuilder: nbEdges, getDist, getDists, getDistAngle, setDist, setDists, setDistAngle, length, removeEdge, reset, closed, closedAndTangent, isSymmetric, isTwoDists, edge, firstVertex, lastVertex, contour, abscissa, relativeAbscissa. FilletBuilder: setRadiusOnEdge, setRadiusAtVertex, setTwoRadii, contour, edge, firstVertex, lastVertex, abscissa, relativeAbscissa, closedAndTangent, closed, nbSurfaces, nbComputedSurfaces, stripeStatus, faultyContour, faultyVertex. WireAnalyzer: create, release, perform, checkOrder, checkConnected, checkSmall, checkDegenerated, checkGap3d, checkGap2d, checkSeam, checkLacking, checkSelfIntersection, checkClosed, minDistance3d, maxDistance3d, nbEdges, isLoaded, isReady |
| **v0.125.0 Additions** | 56 | BSplineSurface: LocalD0/D1/D2/D3/DN/Value, UIso, VIso, LocateU/V, UKnot/VKnot, UMultiplicity/VMultiplicity, UKnotDistribution/VKnotDistribution, GetPoles, Bounds, IsUClosed/IsVClosed. Curve2D BSpline: LocalD0/D1/D2/D3/DN/Value, LocateU, FirstUKnotIndex/LastUKnotIndex, Knot, KnotDistribution, Multiplicity, GetMultiplicities, StartPoint/EndPoint, GetPoles, IsClosed/IsPeriodic, Continuity, IsCN. BezierCurve3D: StartPoint/EndPoint, GetPoles, GetWeights, IsClosed/IsPeriodic, Continuity, IsCN. BezierSurface: UIso/VIso, IsUClosed/IsVClosed, IsUPeriodic/IsVPeriodic, Continuity, IsCNu/IsCNv, GetPoles, GetWeights, Bounds |
| **v0.126.0 Additions** | 62 | BRep_Tool: CurveOnSurface, HasContinuity, Continuity, HasAnyContinuity, MaxContinuity, Degenerated, NaturalRestriction, RangeOnFace, ParameterOnFace, ParametersOnFace, UVPoints, MaxTolerance. XCAFDoc_ColorTool: AddColor, RemoveColor, GetColorCount, UnSetColor, IsVisible, SetVisibility, IsColorByLayer, SetColorByLayer, FindColor, SetInstanceColor, GetInstanceColor. Geom2d_BezierCurve: InsertPoleAfter, RemovePole, Segment, IncreaseDegree, StartPoint, EndPoint, GetPoles, Reverse. BSplineSurface: GetUMultiplicities, GetVMultiplicities, UReverse, VReverse, PeriodicNormalization. BezierSurface: InsertPoleColAfter, InsertPoleRowAfter, RemovePoleCol, RemovePoleRow, IncreaseDegree, UReverse, VReverse, NbUPoles, NbVPoles, UDegree, VDegree. FilletBuilder: SetParams, SetContinuity, SetFilletShape, GetFilletShape, ResetContour, Simulate, NbSimulatedSurf. XCAFDoc_ShapeTool: IsFree, IsSimpleShape, IsComponent, IsCompound, IsSubShape, IsExternRef, GetUsers, ComputeShapes, NbComponents. Bezier3D: InsertPoleBefore, Reverse, SetPoleWithWeight |
| **v0.127.0 Additions** | 16 | BRepAlgoAPI_Section: sectionWithPlane, sectionWithSurface. BSplineCurve: PeriodicNormalization, IsG1. BRep_Tool: CurveOnPlane, Polygon3D, PolygonOnTriangulation. BezierSurface: SetPoleColWeights, SetPoleRowWeights. ColorTool: GetAllColors. FilletBuilder: GetBounds, GetLaw, SetLaw, Generated, Modified, IsDeleted |
| **v0.128.0 Additions** | 40 | ChamferBuilder: Generated, Modified, IsDeleted, SetMode, Simulate, NbSurf. SectionBuilder: full builder pattern (Create, Init1/Init2 shape/plane/surface, Approximation, ComputePCurveOn1/2, Build, AncestorFaceOn1/2). BRep_Tool: IsClosedOnFace, PolygonOnSurface, SetUVPoints. Curve3D Transform: translate, rotate, scale, mirrorPoint, mirrorAxis, mirrorPlane. Curve2D Transform: translate, rotate, scale, mirrorPoint, mirrorAxis. Surface Transform: translate, rotate, scale, mirrorPoint, mirrorAxis, mirrorPlane |
| **v0.129.0 Additions** | 20 | BSplineCurve3D: LocalD0/D1/D2/D3/DN on knot span. BSplineSurface: SetWeightCol/Row, IncrementUMultiplicity/IncrementVMultiplicity (range), FirstU/LastU/FirstV/LastVKnotIndex, CheckAndSegment. BezierSurface: InsertPoleColBefore/RowBefore, SetPoleCol/Row (no weights), SetWeightCol/Row |
| **v0.130.0 Additions** | 33 | GeomEval 3D curves: CircularHelix D0/D1/D2/Create, SineWave D0/D1/Create. GeomEval surfaces: Ellipsoid D0/Create, Hyperboloid D0/Create, Paraboloid D0/Create, CircularHelicoid D0/Create, HypParaboloid D0/Create. Geom2dEval: ArchimedeanSpiral D0/D1, LogSpiral D0/D1, CircleInvolute D0/D1, SineWave2D D0/D1. GeomFill_Gordon surface. PointSetLib: Props/Inertia/Barycentre/Equation. ExtremaPC: Curve/CurveBounded/MinDistance |
| **Approx_BSplineApproxInterp** | 13 | create, interpolatePoint, perform, performOptimal, isDone, curve, maxError, setAlpha, setMinPivot, setClosedTol, setKnotTol, setConvergenceTol, setProjectionTol |
| **GeomAdaptor_TransformedCurve** | 1 | translated (curve with translation) |
| **GeomEval TBezier/AHTBezier Curves** | 4 | tBezier (3D), tBezierRational (3D), ahtBezier (3D), ahtBezierRational (3D) |
| **GeomEval TBezier/AHTBezier Surfaces** | 2 | tBezier surface, ahtBezier surface |
| **Geom2dEval TBezier/AHTBezier** | 2 | tBezier (2D), ahtBezier (2D) |
| **Total** | **3425** | |

> **Note:** OCCTSwift wraps a curated subset of OCCT. To add new functions, see [docs/EXTENDING.md](docs/EXTENDING.md).


## API Reference

### Currently Wrapped OCCT Functions

OCCTSwift wraps a **subset** of OCCT's functionality. The bridge layer (`OCCTBridge`) exposes these specific operations:

#### Shape Creation (Primitives)
| Swift API | OCCT Class |
|-----------|------------|
| `Shape.box()` | `BRepPrimAPI_MakeBox` |
| `Shape.cylinder()` | `BRepPrimAPI_MakeCylinder` |
| `Shape.sphere()` | `BRepPrimAPI_MakeSphere` |
| `Shape.cone()` | `BRepPrimAPI_MakeCone` |
| `Shape.torus()` | `BRepPrimAPI_MakeTorus` |

#### Sweep Operations
| Swift API | OCCT Class |
|-----------|------------|
| `Shape.sweep(profile:along:)` | `BRepOffsetAPI_MakePipe` |
| `Shape.extrude(profile:direction:length:)` | `BRepPrimAPI_MakePrism` |
| `Shape.revolve(profile:axisOrigin:axisDirection:angle:)` | `BRepPrimAPI_MakeRevol` |
| `Shape.loft(profiles:solid:)` | `BRepOffsetAPI_ThruSections` |

#### Boolean Operations
| Swift API | OCCT Class |
|-----------|------------|
| `shape1 + shape2` / `shape1.union(with:)` | `BRepAlgoAPI_Fuse` |
| `shape1 - shape2` / `shape1.subtracting(_:)` | `BRepAlgoAPI_Cut` |
| `shape1 & shape2` / `shape1.intersection(with:)` | `BRepAlgoAPI_Common` |

#### Modifications
| Swift API | OCCT Class |
|-----------|------------|
| `shape.filleted(radius:)` | `BRepFilletAPI_MakeFillet` |
| `shape.chamfered(distance:)` | `BRepFilletAPI_MakeChamfer` |
| `shape.shelled(thickness:)` | `BRepOffsetAPI_MakeThickSolid` |
| `shape.offset(by:)` | `BRepOffsetAPI_MakeOffsetShape` |

#### Transformations
| Swift API | OCCT Class |
|-----------|------------|
| `shape.translated(by:)` | `BRepBuilderAPI_Transform` + `gp_Trsf` |
| `shape.rotated(axis:angle:)` | `BRepBuilderAPI_Transform` + `gp_Trsf` |
| `shape.scaled(by:)` | `BRepBuilderAPI_Transform` + `gp_Trsf` |
| `shape.mirrored(planeNormal:planeOrigin:)` | `BRepBuilderAPI_Transform` + `gp_Trsf` |

#### Wire/Curve Creation
| Swift API | OCCT Class |
|-----------|------------|
| `Wire.rectangle()` | `BRepBuilderAPI_MakeWire` + `GC_MakeSegment` |
| `Wire.circle()` | `BRepBuilderAPI_MakeEdge` + `gp_Circ` |
| `Wire.polygon(_:closed:)` | `BRepBuilderAPI_MakeWire` + edges |
| `Wire.line(from:to:)` | `BRepBuilderAPI_MakeEdge` + `GC_MakeSegment` |
| `Wire.arc(center:radius:...)` | `BRepBuilderAPI_MakeEdge` + `GC_MakeArcOfCircle` |
| `Wire.bspline(_:)` | `BRepBuilderAPI_MakeEdge` + `Geom_BSplineCurve` |
| `Wire.join(_:)` | `BRepBuilderAPI_MakeWire` |

#### 2D Parametric Curves
| Swift API | OCCT Class |
|-----------|------------|
| `Curve2D.segment(from:to:)` | `GCE2d_MakeSegment` |
| `Curve2D.circle(center:radius:)` | `Geom2d_Circle` |
| `Curve2D.ellipse(...)` | `GCE2d_MakeEllipse` |
| `Curve2D.bspline(...)` | `Geom2d_BSplineCurve` |
| `Curve2D.interpolate(through:)` | `Geom2dAPI_Interpolate` |
| `curve.curvature(at:)` | `Geom2dLProp_CLProps2d` |
| `curve.intersections(with:)` | `Geom2dAPI_InterCurveCurve` |
| `curve.drawAdaptive()` | `GCPnts_TangentialDeflection` |
| `Curve2DGcc.circlesTangentWithCenter(...)` | `Geom2dGcc_Circ2dTanCen` |
| `Curve2DGcc.hatch(boundaries:...)` | `Geom2dHatch_Hatcher` |

#### 3D Parametric Curves (v0.19.0)
| Swift API | OCCT Class |
|-----------|------------|
| `Curve3D.line(through:direction:)` | `Geom_Line` |
| `Curve3D.segment(from:to:)` | `GC_MakeSegment` |
| `Curve3D.circle(center:normal:radius:)` | `Geom_Circle` |
| `Curve3D.arcOfCircle(start:interior:end:)` | `GC_MakeArcOfCircle` |
| `Curve3D.ellipse(...)` | `Geom_Ellipse` |
| `Curve3D.bspline(...)` | `Geom_BSplineCurve` |
| `Curve3D.interpolate(points:...)` | `GeomAPI_Interpolate` |
| `curve.drawAdaptive()` | `GCPnts_TangentialDeflection` |
| `curve.curvature(at:)` | `GeomLProp_CLProps` |
| `Curve3D.join(_:)` | `GeomConvert::ConcatG1` |

#### Parametric Surfaces (v0.20.0)
| Swift API | OCCT Class |
|-----------|------------|
| `Surface.plane(origin:normal:)` | `Geom_Plane` |
| `Surface.cylinder(origin:axis:radius:)` | `Geom_CylindricalSurface` |
| `Surface.sphere(center:radius:)` | `Geom_SphericalSurface` |
| `Surface.bspline(...)` | `Geom_BSplineSurface` |
| `Surface.extrusion(profile:direction:)` | `Geom_SurfaceOfLinearExtrusion` |
| `Surface.revolution(...)` | `Geom_SurfaceOfRevolution` |
| `Surface.pipe(path:radius:)` | `GeomFill_Pipe` |
| `surface.uIso(at:)` / `surface.vIso(at:)` | `Geom_Surface::UIso/VIso` |
| `surface.drawGrid(...)` / `surface.drawMesh(...)` | Grid/mesh discretization |
| `surface.gaussianCurvature(atU:v:)` | `GeomLProp_SLProps` |

#### Face Surface Analysis (v0.18.0)
| Swift API | OCCT Class |
|-----------|------------|
| `face.uvBounds` | `BRepTools::UVBounds` |
| `face.point(atU:v:)` / `face.normal(atU:v:)` | `GeomLProp_SLProps` |
| `face.gaussianCurvature(atU:v:)` / `face.meanCurvature(atU:v:)` | `GeomLProp_SLProps` |
| `face.principalCurvatures(atU:v:)` | `GeomLProp_SLProps` |
| `face.surfaceType` / `face.area(tolerance:)` | `GeomAdaptor_Surface` / `BRepGProp` |
| `face.project(point:)` / `face.allProjections(of:)` | `GeomAPI_ProjectPointOnSurf` |
| `face.intersection(with:tolerance:)` | `BRepAlgoAPI_Section` |

#### Edge Curve Analysis (v0.18.0)
| Swift API | OCCT Class |
|-----------|------------|
| `edge.parameterBounds` / `edge.curveType` | `BRep_Tool` / `GeomAdaptor_Curve` |
| `edge.point(at:)` / `edge.tangent(at:)` / `edge.normal(at:)` | `GeomLProp_CLProps` |
| `edge.curvature(at:)` / `edge.centerOfCurvature(at:)` / `edge.torsion(at:)` | `GeomLProp_CLProps` |
| `edge.project(point:)` | `GeomAPI_ProjectPointOnCurve` |

#### Shape Proximity (v0.18.0)
| Swift API | OCCT Class |
|-----------|------------|
| `shape.proximityFaces(with:tolerance:)` | `BRepExtrema_ShapeProximity` |
| `shape.selfIntersects` | `BOPAlgo_CheckerSI` |

#### Law Functions (v0.21.0)
| Swift API | OCCT Class |
|-----------|------------|
| `LawFunction.constant(_:from:to:)` | `Law_Constant` |
| `LawFunction.linear(from:to:parameterRange:)` | `Law_Linear` |
| `LawFunction.sCurve(from:to:parameterRange:)` | `Law_S` |
| `LawFunction.interpolate(points:periodic:)` | `Law_Interpol` |
| `LawFunction.bspline(...)` | `Law_BSpline` |
| `Shape.pipeShellWithLaw(spine:profile:law:solid:)` | `BRepOffsetAPI_MakePipeShell` |

#### Curve Projection (v0.22.0)
| Swift API | OCCT Class |
|-----------|------------|
| `surface.projectCurve(_:tolerance:)` → `Curve2D?` | `GeomProjLib::Curve2d` |
| `surface.projectCurveSegments(_:tolerance:)` → `[Curve2D]` | `ProjLib_CompProjectedCurve` |
| `surface.projectCurve3D(_:)` → `Curve3D?` | `GeomProjLib::Project` |
| `surface.projectPoint(_:)` → `SurfaceProjection?` | `GeomAPI_ProjectPointOnSurf` |
| `curve.projectedOnPlane(origin:normal:direction:)` → `Curve3D?` | `GeomProjLib::ProjectOnPlane` |

#### XDE GD&T (v0.21.0)
| Swift API | OCCT Class |
|-----------|------------|
| `document.dimensionCount` / `document.dimension(at:)` | `XCAFDimTolObjects_DimensionObject` |
| `document.geomToleranceCount` / `document.geomTolerance(at:)` | `XCAFDimTolObjects_GeomToleranceObject` |
| `document.datumCount` / `document.datum(at:)` | `XCAFDimTolObjects_DatumObject` |

#### Topological Naming (v0.25.0)
| Swift API | OCCT Class |
|-----------|------------|
| `document.createLabel(parent:)` | `TDF_TagSource::NewTag` |
| `document.recordNaming(on:evolution:oldShape:newShape:)` | `TNaming_Builder` |
| `document.currentShape(on:)` | `TNaming_Tool::CurrentShape` |
| `document.storedShape(on:)` | `TNaming_Tool::GetShape` |
| `document.namingEvolution(on:)` | `TNaming_NamedShape::Evolution` |
| `document.namingHistory(on:)` | `TNaming_Iterator` |
| `document.tracedForward(from:scope:)` | `TNaming_NewShapeIterator` |
| `document.tracedBackward(from:scope:)` | `TNaming_OldShapeIterator` |
| `document.selectShape(_:context:on:)` | `TNaming_Selector::Select` |
| `document.resolveShape(on:)` | `TNaming_Selector::Solve` |

#### Annotations & Measurements (v0.26.0)
| Swift API | OCCT Class |
|-----------|------------|
| `LengthDimension(from:to:)` | `PrsDim_LengthDimension` |
| `LengthDimension(edge:)` | `PrsDim_LengthDimension` |
| `LengthDimension(face1:face2:)` | `PrsDim_LengthDimension` |
| `RadiusDimension(shape:)` | `PrsDim_RadiusDimension` |
| `AngleDimension(edge1:edge2:)` | `PrsDim_AngleDimension` |
| `AngleDimension(first:vertex:second:)` | `PrsDim_AngleDimension` |
| `AngleDimension(face1:face2:)` | `PrsDim_AngleDimension` |
| `DiameterDimension(shape:)` | `PrsDim_DiameterDimension` |
| `TextLabel(text:position:)` | `AIS_TextLabel` |
| `PointCloud(points:)` / `PointCloud(points:colors:)` | `AIS_PointCloud` |
| `dimension.geometry` → `DimensionGeometry` | Extracted line segments + text position for Metal |

#### Import
| Swift API | OCCT Class |
|-----------|------------|
| `Shape.load(from:)` | `STEPControl_Reader` |
| `Shape.loadRobust(from:)` | `STEPControl_Reader` + `ShapeFix_*` |
| `Shape.loadIGES(from:)` | `IGESControl_Reader` |
| `Shape.loadIGESRobust(from:)` | `IGESControl_Reader` + `ShapeFix_*` |
| `Shape.loadBREP(from:)` | `BRepTools::Read` |
| `Shape.loadSTL(from:)` | `StlAPI_Reader` |
| `Shape.loadSTLRobust(from:)` | `StlAPI_Reader` + `BRepBuilderAPI_Sewing` + `ShapeFix_Shape` |
| `Shape.loadOBJ(from:)` | `RWObj_CafReader` |

#### Geometry Construction
| Swift API | OCCT Class |
|-----------|------------|
| `Shape.face(from:)` | `BRepBuilderAPI_MakeFace` |
| `Shape.face(outer:holes:)` | `BRepBuilderAPI_MakeFace` |
| `Shape.face(from:outer:innerWires:)` | `BRepBuilderAPI_MakeFace(surface, outer)` + `.Add(hole)` + `ShapeFix_Face` |
| `Shape.solid(from:)` | `BRepBuilderAPI_MakeSolid` |
| `Shape.sew(shapes:tolerance:)` | `BRepBuilderAPI_Sewing` |
| `Wire.interpolate(through:)` | `GeomAPI_Interpolate` |

#### Bounds
| Swift API | OCCT Class |
|-----------|------------|
| `shape.bounds` | `Bnd_Box`, `BRepBndLib` |
| `shape.size` | (computed from bounds) |
| `shape.center` | (computed from bounds) |

#### Slicing & Contours
| Swift API | OCCT Class |
|-----------|------------|
| `shape.sliceAtZ(_:)` | `BRepAlgoAPI_Section`, `gp_Pln` |
| `shape.edgeCount` | `TopExp_Explorer` |
| `shape.edgePoints(at:maxPoints:)` | `BRep_Tool::Curve`, `Geom_Curve` |
| `shape.contourPoints(maxPoints:)` | `TopExp::Vertices`, `BRep_Tool::Pnt` |

#### CAM Operations
| Swift API | OCCT Class |
|-----------|------------|
| `Shape.cylinder(at:bottomZ:radius:height:)` | `BRepPrimAPI_MakeCylinder`, `gp_Ax2` |
| `Shape.toolSweep(radius:height:from:to:)` | `BRepPrimAPI_MakeCylinder`, `BRepAlgoAPI_Fuse`, `BRepPrimAPI_MakePrism` |

#### Meshing & Export
| Swift API | OCCT Class |
|-----------|------------|
| `shape.mesh(linearDeflection:angularDeflection:)` | `BRepMesh_IncrementalMesh` |
| `shape.writeSTL(to:deflection:)` | `StlAPI_Writer` |
| `shape.writeSTEP(to:)` | `STEPControl_Writer` |
| `shape.writeIGES(to:)` | `IGESControl_Writer` |
| `shape.writeBREP(to:)` | `BRepTools::Write` |
| `shape.writeOBJ(to:deflection:)` | `RWObj_CafWriter` |
| `shape.writePLY(to:deflection:)` | `RWPly_CafWriter` |
| `Exporter.optimizeSTEP(input:output:)` | `StepTidy_DuplicateCleaner` |

#### Helix Curves
| Swift API | OCCT Class |
|-----------|------------|
| `Wire.helix(radius:pitch:turns:)` | `HelixBRep_BuilderHelix` |
| `Wire.helixTapered(startRadius:endRadius:pitch:turns:)` | `HelixBRep_BuilderHelix` |

#### KD-Tree Spatial Queries
| Swift API | OCCT Class |
|-----------|------------|
| `KDTree(points:)` | `NCollection_KDTree<gp_Pnt, 3>` |
| `tree.nearest(to:)` | `NCollection_KDTree::NearestPoint` |
| `tree.kNearest(to:k:)` | `NCollection_KDTree::KNearestPoints` |
| `tree.rangeSearch(center:radius:)` | `NCollection_KDTree::RangeSearch` |
| `tree.boxSearch(min:max:)` | `NCollection_KDTree::BoxSearch` |

#### Batch Curve/Surface Evaluation
| Swift API | OCCT Class |
|-----------|------------|
| `curve2d.evaluateGrid(_:)` | `Geom2dGridEval_Curve::EvaluateGrid` |
| `curve2d.evaluateGridD1(_:)` | `Geom2dGridEval_Curve::EvaluateGridD1` |
| `curve3d.evaluateGrid(_:)` | `GeomGridEval_Curve::EvaluateGrid` |
| `curve3d.evaluateGridD1(_:)` | `GeomGridEval_Curve::EvaluateGridD1` |
| `surface.evaluateGrid(uParameters:vParameters:)` | `GeomGridEval_Surface::EvaluateGrid` |

#### Wedge & Half-Space Primitives (v0.29.0)
| Swift API | OCCT Class |
|-----------|------------|
| `Shape.wedge(dx:dy:dz:ltx:)` | `BRepPrimAPI_MakeWedge` |
| `Shape.wedge(dx:dy:dz:xmin:zmin:xmax:zmax:)` | `BRepPrimAPI_MakeWedge` |
| `Shape.halfSpace(face:referencePoint:)` | `BRepPrimAPI_MakeHalfSpace` |

#### Shape Conversion & Sewing (v0.29.0)
| Swift API | OCCT Class |
|-----------|------------|
| `shape.convertedToNURBS()` | `BRepBuilderAPI_NurbsConvert` |
| `shape.fastSewn(tolerance:)` | `BRepBuilderAPI_FastSewing` |
| `shape.normalProjection(of:)` | `BRepOffsetAPI_NormalProjection` |
| `shape.draft(direction:angle:length:)` | `BRepOffsetAPI_MakeDraft` |

#### Shape Editing (v0.29.0)
| Swift API | OCCT Class |
|-----------|------------|
| `shape.replacingSubShape(_:with:)` | `BRepTools_ReShape` |
| `shape.removingSubShape(_:)` | `BRepTools_ReShape` |
| `shape.makePeriodic(xPeriod:yPeriod:zPeriod:)` | `BOPAlgo_MakePeriodic` |
| `shape.repeated(...)` | `BOPAlgo_MakePeriodic` |

#### Wire Explorer (v0.29.0)
| Swift API | OCCT Class |
|-----------|------------|
| `wire.orderedEdgeCount` | `BRepTools_WireExplorer` |
| `wire.orderedEdgePoints(at:maxPoints:)` | `BRepTools_WireExplorer` + `BRepAdaptor_Curve` |

#### Curve Planarity (v0.29.0)
| Swift API | OCCT Class |
|-----------|------------|
| `curve3d.planeNormal(tolerance:)` | `ShapeAnalysis_Curve::IsPlanar` |

#### Polynomial Solver (v0.29.0)
| Swift API | OCCT Class |
|-----------|------------|
| `PolynomialSolver.quadratic(a:b:c:)` | `math_DirectPolynomialRoots` |
| `PolynomialSolver.cubic(a:b:c:d:)` | `math_DirectPolynomialRoots` |
| `PolynomialSolver.quartic(a:b:c:d:e:)` | `math_DirectPolynomialRoots` |

#### Hatch Pattern (v0.29.0)
| Swift API | OCCT Class |
|-----------|------------|
| `HatchPattern.generate(boundary:direction:spacing:)` | `Hatch_Hatcher` |

#### Non-Uniform Scale (v0.30.0)
| Swift API | OCCT Class |
|-----------|------------|
| `shape.nonUniformScaled(sx:sy:sz:)` | `BRepBuilderAPI_GTransform` |

#### Shell & Vertex Creation (v0.30.0)
| Swift API | OCCT Class |
|-----------|------------|
| `Shape.shell(from:)` | `BRepBuilderAPI_MakeShell` |
| `Shape.vertex(at:)` | `BRepBuilderAPI_MakeVertex` |

#### Simple Offset & Middle Path (v0.30.0)
| Swift API | OCCT Class |
|-----------|------------|
| `shape.simpleOffset(by:)` | `BRepOffset_MakeSimpleOffset` |
| `shape.middlePath(start:end:)` | `BRepOffsetAPI_MiddlePath` |

#### Edge Fusion & Volume (v0.30.0)
| Swift API | OCCT Class |
|-----------|------------|
| `shape.fusedEdges()` | `BRepLib_FuseEdges` |
| `Shape.makeVolume(from:)` | `BOPAlgo_MakerVolume` |
| `Shape.makeConnected(_:)` | `BOPAlgo_MakeConnected` |

#### Curve-Curve & Curve-Surface (v0.30.0)
| Swift API | OCCT Class |
|-----------|------------|
| `curve.minDistance(to: otherCurve)` | `GeomAPI_ExtremaCurveCurve` |
| `curve.extrema(with:)` | `GeomAPI_ExtremaCurveCurve` |
| `curve.intersections(with: surface)` | `GeomAPI_IntCS` |
| `curve.minDistance(to: surface)` | `GeomAPI_ExtremaCurveSurface` |
| `surface.intersections(with: otherSurface)` | `GeomAPI_IntSS` |

#### Analytical Recognition (v0.30.0)
| Swift API | OCCT Class |
|-----------|------------|
| `curve.toAnalytical(tolerance:)` | `GeomConvert_CurveToAnaCurve` |
| `surface.toAnalytical(tolerance:)` | `GeomConvert_SurfToAnaSurf` |
| `shape.recognizeCanonical(tolerance:)` | `ShapeAnalysis_CanonicalRecognition` |

#### Shape Census & Edge Analysis (v0.30.0)
| Swift API | OCCT Class |
|-----------|------------|
| `shape.contents` | `ShapeAnalysis_ShapeContents` |
| `edge.hasCurve3D` / `edge.isClosed3D` | `ShapeAnalysis_Edge` |
| `edge.isSeam(on:)` | `ShapeAnalysis_Edge` |
| `shape.findSurface(tolerance:)` | `BRepLib_FindSurface` |

#### Healing & Diagnostics (v0.30.0)
| Swift API | OCCT Class |
|-----------|------------|
| `shape.fixedWireframe(tolerance:)` | `ShapeFix_Wireframe` |
| `shape.removingInternalWires(minArea:)` | `ShapeUpgrade_RemoveInternalWires` |
| `shape.contiguousEdgeCount(tolerance:)` | `BRepOffsetAPI_FindContigousEdges` |

#### Document Units (v0.30.0)
| Swift API | OCCT Class |
|-----------|------------|
| `document.lengthUnit` | `XCAFDoc_LengthUnit` |

#### Quasi-Uniform Curve Sampling (v0.31.0)
| Swift API | OCCT Class |
|-----------|------------|
| `curve.quasiUniformParameters(count:)` | `GCPnts_QuasiUniformAbscissa` |
| `curve.quasiUniformDeflectionPoints(deflection:)` | `GCPnts_QuasiUniformDeflection` |

#### Bezier Surface Fill (v0.31.0)
| Swift API | OCCT Class |
|-----------|------------|
| `Surface.bezierFill(_:_:_:_:style:)` | `GeomFill_BezierCurves` |
| `Surface.bezierFill(_:_:style:)` | `GeomFill_BezierCurves` |

#### Shape Healing (v0.31.0)
| Swift API | OCCT Class |
|-----------|------------|
| `Shape.quilt(_:)` | `BRepTools_Quilt` |
| `shape.fixingSmallFaces(tolerance:)` | `ShapeFix_FixSmallFace` |
| `shape.removingLocations()` | `ShapeUpgrade_RemoveLocations` |

#### Revolution from Curve (v0.31.0)
| Swift API | OCCT Class |
|-----------|------------|
| `Shape.revolution(meridian:axisOrigin:axisDirection:angle:)` | `BRepPrimAPI_MakeRevolution` |

#### Document Layers & Materials (v0.31.0)
| Swift API | OCCT Class |
|-----------|------------|
| `document.layerCount` / `layerName(at:)` / `layerNames` | `XCAFDoc_LayerTool` |
| `document.materialCount` / `materialInfo(at:)` / `materials` | `XCAFDoc_MaterialTool` |

#### Linear Rib Feature (v0.31.0)
| Swift API | OCCT Class |
|-----------|------------|
| `shape.addingLinearRib(profile:direction:draftDirection:fuse:)` | `BRepFeat_MakeLinearForm` |

#### Oriented Bounding Box (v0.38.0)
| Swift API | OCCT Class |
|-----------|------------|
| `shape.orientedBoundingBox(optimal:)` → `OrientedBoundingBox` | `BRepBndLib::AddOBB` + `Bnd_OBB` |
| `shape.orientedBoundingBoxCorners(optimal:)` | `Bnd_OBB` corner computation |

#### Deep Shape Copy (v0.38.0)
| Swift API | OCCT Class |
|-----------|------------|
| `shape.copy(copyGeometry:copyMesh:)` | `BRepBuilderAPI_Copy` |

#### Sub-Shape Extraction (v0.38.0)
| Swift API | OCCT Class |
|-----------|------------|
| `shape.solids` / `shape.solidCount` | `TopExp_Explorer(TopAbs_SOLID)` |
| `shape.shells` / `shape.shellCount` | `TopExp_Explorer(TopAbs_SHELL)` |
| `shape.wires` / `shape.wireCount` | `TopExp_Explorer(TopAbs_WIRE)` |

#### Fuse and Blend (v0.38.0)
| Swift API | OCCT Class |
|-----------|------------|
| `shape.fusedAndBlended(with:radius:)` | `BRepAlgoAPI_Fuse` + `BRepFilletAPI_MakeFillet` |
| `shape.cutAndBlended(with:radius:)` | `BRepAlgoAPI_Cut` + `BRepFilletAPI_MakeFillet` |

#### Evolving Fillet (v0.38.0)
| Swift API | OCCT Class |
|-----------|------------|
| `shape.filletEvolving(_:)` | `BRepFilletAPI_MakeFillet.SetRadius(UandR)` |

#### Per-Face Variable Offset (v0.38.0)
| Swift API | OCCT Class |
|-----------|------------|
| `shape.offsetPerFace(defaultOffset:faceOffsets:...)` | `BRepOffset_MakeOffset.SetOffsetOnFace` |

#### Thick/Hollow Solid (v0.37.0)
| Swift API | OCCT Class |
|-----------|------------|
| `shape.hollowed(removingFaces:thickness:tolerance:joinType:)` | `BRepOffsetAPI_MakeThickSolid` |

#### Wire Topology Analysis (v0.37.0)
| Swift API | OCCT Class |
|-----------|------------|
| `wire.analyze(tolerance:)` → `WireAnalysis` | `ShapeAnalysis_Wire` |

#### Surface Singularity (v0.37.0)
| Swift API | OCCT Class |
|-----------|------------|
| `surface.singularityCount(tolerance:)` | `ShapeAnalysis_Surface.NbSingularities` |
| `surface.isDegenerated(at:tolerance:)` | `ShapeAnalysis_Surface.IsDegenerated` |
| `surface.hasSingularities(tolerance:)` | `ShapeAnalysis_Surface.NbSingularities` |

#### Shell from Surface (v0.37.0)
| Swift API | OCCT Class |
|-----------|------------|
| `Shape.shell(from:uRange:vRange:)` | `BRepBuilderAPI_MakeShell` |

#### Multi-Tool Common (v0.37.0)
| Swift API | OCCT Class |
|-----------|------------|
| `Shape.commonAll(_:)` | `BRepAlgoAPI_Common` (iterative) |

#### Conical Projection (v0.36.0)
| Swift API | OCCT Class |
|-----------|------------|
| `Shape.projectWireConical(_:onto:eye:)` | `BRepProj_Projection(Wire, Shape, gp_Pnt)` |

#### Shape Consistency (v0.36.0)
| Swift API | OCCT Class |
|-----------|------------|
| `shape.encodingRegularity(toleranceDegrees:)` | `BRepLib::EncodeRegularity` |
| `shape.updatingTolerances(verifyFaces:)` | `BRepLib::UpdateTolerances` |
| `shape.dividedByNumber(_:)` | `ShapeUpgrade_FaceDivideArea` |
| `surface.toBezierPatches()` | `GeomConvert_BSplineSurfaceToBezierSurface` |

#### Boolean with History (v0.36.0)
| Swift API | OCCT Class |
|-----------|------------|
| `shape.fuseWithHistory(_:)` → `BooleanResult` | `BRepAlgoAPI_Fuse.Modified()` |

#### Multi-Offset Wire (v0.35.0)
| Swift API | OCCT Class |
|-----------|------------|
| `face.multiOffsetWires(offsets:joinType:)` | `BRepOffsetAPI_MakeOffset.Perform` |

#### Surface-Surface Intersection (v0.35.0)
| Swift API | OCCT Class |
|-----------|------------|
| `surface.intersectionCurves(with:tolerance:)` | `GeomAPI_IntSS` |

#### Curve-Surface Intersection (v0.35.0)
| Swift API | OCCT Class |
|-----------|------------|
| `curve.intersections(with:)` | `GeomAPI_IntCS` |

#### Cylindrical Projection (v0.35.0)
| Swift API | OCCT Class |
|-----------|------------|
| `Shape.projectWire(_:onto:direction:)` | `BRepProj_Projection` |

#### Same Parameter (v0.35.0)
| Swift API | OCCT Class |
|-----------|------------|
| `shape.sameParameter(tolerance:)` | `BRepLib::SameParameter` |

#### Shape-to-Shape Section (v0.34.0)
| Swift API | OCCT Class |
|-----------|------------|
| `shape.section(with:)` | `BRepAlgoAPI_Section` |

#### Boolean Pre-Validation (v0.34.0)
| Swift API | OCCT Class |
|-----------|------------|
| `shape.isValidForBoolean` | `BRepAlgoAPI_Check` (self-check) |
| `shape.isValidForBoolean(with:)` | `BRepAlgoAPI_Check` (pair check) |

#### Wire Imprinting (v0.34.0)
| Swift API | OCCT Class |
|-----------|------------|
| `shape.splittingFace(with:faceIndex:)` | `BRepFeat_SplitShape` |

#### Split by Angle (v0.34.0)
| Swift API | OCCT Class |
|-----------|------------|
| `shape.splitByAngle(_:)` | `ShapeUpgrade_ShapeDivideAngle` |

#### Drop Small Edges (v0.34.0)
| Swift API | OCCT Class |
|-----------|------------|
| `shape.droppingSmallEdges(tolerance:)` | `ShapeFix_Wireframe.FixSmallEdges` (drop mode) |

#### Multi-Tool Boolean Fuse (v0.34.0)
| Swift API | OCCT Class |
|-----------|------------|
| `Shape.fuseAll(_:)` | `BRepAlgoAPI_BuilderAlgo` |

#### Evolved Shape Advanced (v0.33.0)
| Swift API | OCCT Class |
|-----------|------------|
| `Shape.evolvedAdvanced(spine:profile:joinType:axeProf:solid:volume:tolerance:)` | `BRepOffsetAPI_MakeEvolved` (full constructor) |

#### Pipe Shell Transition (v0.33.0)
| Swift API | OCCT Class |
|-----------|------------|
| `Shape.pipeShellWithTransition(spine:profile:mode:transition:solid:)` | `BRepOffsetAPI_MakePipeShell.SetTransitionMode` |

#### Face from Surface (v0.33.0)
| Swift API | OCCT Class |
|-----------|------------|
| `Shape.face(from:uRange:vRange:tolerance:)` | `BRepBuilderAPI_MakeFace(surface, u1, u2, v1, v2, tol)` |
| `surface.toFace()` / `surface.toFace(uRange:vRange:)` | Convenience wrappers |

#### Edges to Faces (v0.33.0)
| Swift API | OCCT Class |
|-----------|------------|
| `Shape.facesFromEdges(_:onlyPlanar:)` | `BRepBuilderAPI_MakeWire` + `BRepBuilderAPI_MakeFace` |

#### Asymmetric Chamfer (v0.32.0)
| Swift API | OCCT Class |
|-----------|------------|
| `shape.chamferedTwoDistances(_:)` | `BRepFilletAPI_MakeChamfer.Add(d1,d2,E,F)` |
| `shape.chamferedDistAngle(_:)` | `BRepFilletAPI_MakeChamfer.AddDA(d,a,E,F)` |

#### Loft Improvements (v0.32.0)
| Swift API | OCCT Class |
|-----------|------------|
| `Shape.loft(profiles:solid:ruled:firstVertex:lastVertex:)` | `BRepOffsetAPI_ThruSections(solid,ruled)` |

#### Offset by Join (v0.32.0)
| Swift API | OCCT Class |
|-----------|------------|
| `shape.offset(by:tolerance:joinType:removeInternalEdges:)` | `BRepOffsetAPI_MakeOffsetShape.PerformByJoin` |

#### Feature Operations (v0.32.0)
| Swift API | OCCT Class |
|-----------|------------|
| `shape.addingRevolutionForm(profile:...)` | `BRepFeat_MakeRevolutionForm` |
| `shape.addingDraftPrism(profile:sketchFaceIndex:draftAngle:height:fuse:)` | `BRepFeat_MakeDPrism` |
| `shape.addingDraftPrismThruAll(...)` | `BRepFeat_MakeDPrism.PerformThruAll` |
| `shape.addingRevolvedFeature(profile:sketchFaceIndex:...)` | `BRepFeat_MakeRevol` |
| `shape.addingRevolvedFeatureThruAll(...)` | `BRepFeat_MakeRevol.PerformThruAll` |

#### Validation
| Swift API | OCCT Class |
|-----------|------------|
| `shape.isValid` | `BRepCheck_Analyzer` |
| `shape.healed()` | `ShapeFix_Shape` |

### What's NOT Wrapped (and Why)

Some OCCT classes cannot be wrapped through a C bridge because they rely on **C++ inheritance patterns** that have no equivalent in C or Swift:

- **ChFi3d_FilBuilder / ChFi3d_ChBuilder** — These fillet/chamfer builder classes inherit from `ChFi3d_Builder`, which is a complex stateful base class with protected virtual methods. The public API is deeply coupled to internal OCCT data structures (`ChFiDS_SurfData`, `ChFiDS_Stripe`, etc.) that would require wrapping an entire tree of internal types. **You don't need these directly** — the higher-level `BRepFilletAPI_MakeFillet` (exposed as `Shape.filleted()`, `Shape.filletEvolving()`, etc.) uses `ChFi3d_FilBuilder` internally, so all the functionality is already available through the cleaner public API.

- **Approx_FitAndDivide / Approx_FitAndDivide2d** — Require implementing the abstract `AppCont_Function` interface in C++, which means providing callback functions for evaluation. Cannot be driven from Swift without a C++ subclass.

- **BRepBlend_AppSurface** — Requires implementing the abstract `Approx_SweepFunction` interface. Same pattern — needs a C++ subclass providing evaluation callbacks.

- **BRepBlend_\*, BlendFunc_\*, ChFiKPart_\*, ChFiDS_\*** — Internal implementation classes used by the fillet/chamfer algorithms. Not intended for direct use; their functionality is exposed through the `BRepFilletAPI_*` public APIs.

In general, OCCT classes that require **subclassing with virtual method overrides** or that serve as **internal implementation details** of higher-level algorithms are not wrappable through a C function bridge. The wrapped APIs always provide equivalent or better functionality through OCCT's public algorithm classes.

### What's NOT Wrapped (Yet)

OCCT has thousands of classes. Some notable ones not yet exposed:

- **Pockets with Islands**: Multi-contour pocket features

> **Note:** Many previously missing features have been added in recent versions:
> - v0.51.0: **2D curve completions** — `Curve2D.parameterAtLength` (GCPnts_AbscissaPoint arc-length parameter query), `Curve2D.interpolate(tangents:)` (interior tangent constraints via Geom2dAPI_Interpolate.Load), `Wire.fromCurve2D(on:)` (lift 2D parametric curve to 3D wire on a geometric plane via BRepBuilderAPI_MakeEdge + BRepLib::BuildCurves3d)
> - v0.46.0: **Edge concavity, curve approximation, local prism, volume/surface inertia** — BRepOffset_Analyse edge classification, Approx_Curve3d BSpline approximation, LocOpe_Prism with shape tracking, full inertia tensor with principal axes
> - v0.45.0: **N-side filling, self-intersection, face GProp, wire ordering** — BRepFill_Filling with edge/point constraints, BRepExtrema_SelfIntersection via BVH, BRepGProp_Face natural bounds + unnormalized normals, ShapeAnalysis_WireOrder edge chain analysis
> - v0.38.0: **OCCT test suite audit, round 7** — oriented bounding box, deep shape copy, sub-shape extraction (solids/shells/wires), fuse-and-blend, cut-and-blend, evolving fillet, per-face variable offset
> - v0.37.0: **OCCT test suite audit, round 6** — thick/hollow solids, wire topology analysis, surface singularity detection, shell from parametric surface, multi-tool common
> - v0.36.0: **OCCT test suite audit, round 5** — conical projection, encode regularity, update tolerances, face division, surface-to-Bezier, boolean history
> - v0.35.0: **OCCT test suite audit, round 4** — multi-offset wire, surface-surface intersection, curve-surface intersection, cylindrical projection, same-parameter enforcement
> - v0.34.0: **OCCT test suite audit, round 3** — shape-to-shape section, boolean pre-validation, wire imprinting, angle splitting, small edge removal, multi-tool fuse
> - v0.33.0: **OCCT test suite audit, round 2** — evolved shapes with full parameter control, pipe shell transition modes, face creation from parametric surfaces, edge-to-face reconstruction
> - v0.32.0: **OCCT test suite audit** — asymmetric chamfer (two-distance + distance-angle), ruled loft with vertex endpoints, offset by join with join type control, revolution form, draft prism, revolved feature
> - v0.31.0: **Medium/low priority audit wrap** — quasi-uniform curve sampling (arc-length & deflection), Bezier surface fill, quilt faces, fix small faces, remove locations, revolution from curve, document layers/materials, linear rib feature
> - v0.30.0: **Deep audit wrap** — non-uniform scale, shell/vertex creation, simple offset, middle path, edge fusion, make volume, make connected, curve-curve/curve-surface/surface-surface distance & intersection, analytical recognition, shape contents census, canonical form recognition, edge analysis, find surface, wireframe fixing, internal wire removal, document length unit
> - v0.29.0: **Comprehensive audit wrap** — wedge primitives, NURBS conversion, fast sewing, normal projection, half-space, shape editing, draft extrusion, wire explorer, batch 3D curve/surface evaluation, polynomial solver, hatch patterns, planarity analysis
> - v0.28.0: **New rc4 APIs** — helix curves, KD-tree spatial queries, STEP optimization, batch curve evaluation
> - v0.27.0: **OCCT 8.0.0-rc4 upgrade** — 111 internal improvements, performance gains, deprecation fixes
> - v0.26.0: Annotations & measurements — length/radius/angle/diameter dimensions, text labels, point clouds
> - v0.25.0: Topological naming — record/trace naming history, persistent named selections
> - v0.131.0: Final RC5 wrapping — Approx_BSplineApproxInterp (constrained least-squares BSpline fitting), GeomEval TBezier/AHTBezier curves (3D/2D) and surfaces, GeomAdaptor_TransformedCurve, upgrade documentation (3408 ops, 1553 tests)
> - v0.130.0: RC5 analytical geometry — GeomEval 3D curves (CircularHelix, SineWave), GeomEval surfaces (Ellipsoid, Hyperboloid, Paraboloid, CircularHelicoid, HypParaboloid), Geom2dEval 2D curves (ArchimedeanSpiral, LogarithmicSpiral, CircleInvolute, SineWave2D), GeomFill_Gordon transfinite interpolation surface, PointSetLib point cloud analysis (centroid/inertia/PCA), ExtremaPC point-curve distance (3386 ops, 1538 tests)
> - v0.129.0: BSplineCurve3D local derivatives (LocalD0/D1/D2/D3/DN on knot span), BSplineSurface completions (SetWeightCol/Row, IncrementU/VMultiplicity range, First/LastU/VKnotIndex, CheckAndSegment), BezierSurface completions (InsertPoleCol/RowBefore, SetPoleCol/Row, SetWeightCol/Row) (3353 ops, 2920 tests)
> - v0.128.0: ChamferBuilder history (Generated/Modified/IsDeleted/SetMode/Simulate/NbSurf), SectionBuilder full builder pattern, BRep_Tool extras (IsClosedOnFace/PolygonOnSurface/SetUVPoints), Curve3D/Curve2D/Surface in-place transforms (3333 ops, 2907 tests)
> - v0.127.0: Priority class gaps closure — BRepAlgoAPI_Section with plane/surface, BSplineCurve PeriodicNormalization/IsG1, BRep_Tool CurveOnPlane/Polygon3D/PolygonOnTriangulation, BezierSurface SetPoleCol/RowWeights, ColorTool GetAllColors, FilletBuilder history (GetBounds/GetLaw/SetLaw/Generated/Modified/IsDeleted) (3293 ops, 2878 tests)
> - v0.126.0: Final completeness release — BRep_Tool completions (CurveOnSurface, HasContinuity, Continuity, MaxContinuity, Degenerated, NaturalRestriction, RangeOnFace, ParameterOnFace, ParametersOnFace, UVPoints, MaxTolerance), XCAFDoc_ColorTool completions (AddColor, RemoveColor, GetColorCount, UnSetColor, IsVisible, SetVisibility, IsColorByLayer, SetColorByLayer, FindColor, SetInstanceColor, GetInstanceColor), Geom2d_BezierCurve completions (InsertPoleAfter, RemovePole, Segment, IncreaseDegree, StartPoint, EndPoint, GetPoles, Reverse), BSplineSurface completions (GetUMultiplicities, GetVMultiplicities, UReverse, VReverse, PeriodicNormalization), BezierSurface completions (InsertPoleCol/Row, RemovePoleCol/Row, IncreaseDegree, UReverse, VReverse), FilletBuilder completions (SetParams, SetContinuity, SetFilletShape, GetFilletShape, ResetContour, Simulate), XCAFDoc_ShapeTool completions (IsFree, IsSimpleShape, IsComponent, IsCompound, IsSubShape, IsExternRef, GetUsers, ComputeShapes, NbComponents), Bezier3D completions (InsertPoleBefore, Reverse, SetPoleWithWeight) (3277 ops, 3277 tests)
> - v0.125.0: BSpline/Bezier deep method completion — BSplineSurface local evaluation (LocalD0/D1/D2/D3/DN/Value), isoparametric curves (UIso/VIso), knot location (LocateU/V), individual knot/multiplicity queries, knot distribution, bulk poles, bounds, closure. Curve2D BSpline local evaluation (LocalD0/D1/D2/D3/DN/Value), knot span location, knot indices, distribution, multiplicities, start/end points, poles, closure/periodicity/continuity. BezierCurve3D start/end points, bulk poles/weights, closure/periodicity/continuity. BezierSurface iso curves, closure/periodicity/continuity, bulk poles/weights, bounds (3215 ops, 3250 tests)
> - v0.124.0: ChamferBuilder completions (distance get/set, contour navigation, vertex/edge queries, abscissa, closed/tangent, symmetric/two-dist/dist-angle mode queries), FilletBuilder completions (SetRadius on edge/vertex, two-radii evolving, contour navigation, surface counts, stripe status, faulty queries), WireAnalyzer (ShapeAnalysis_Wire: order, connected, small, degenerated, gap, seam, lacking, self-intersection, closed, distances) (3159 ops, 3203 tests)
> - v0.123.0: ThruSections extensions (CheckCompatibility, SetParType, SetCriteriumWeight, GeneratedFace), CellsBuilder extensions (AddToResult selective, RemoveFromResult, GetAllParts, MakeContainers), PipeShell extensions (GetStatus, Simulate), UnifySameDomain builder (AllowInternalEdges, KeepShape, SafeInputMode, linear/angular tolerance), BRepAlgoAPI_Section extended (approximation, pcurves, ancestor faces), Curve3D queries (period, firstParameter, lastParameter), Surface queries (uPeriod, vPeriod), Shape queries (typeName, isNotEqual, nullified, emptied, moved, orientationValue, nbEdges/nbFaces/nbVertices) (3105 ops, 3182 tests)
> - v0.122.0: WireFixer extended (FixGaps2d, FixSeam, FixShifted, FixNotchedEdges, FixTails, tail config), ShapeFix_Edge (AddCurve3d, AddPCurve, RemoveCurve3d, RemovePCurve, FixReversed2d), BRepTools statics (Clean, RemoveInternals, DetectClosedness, EvalAndUpdateTol, Map3DEdges, UpdateFaceUVPoints, CompareVertices/Edges, IsReallyClosed), BRepLib extended (EnsureNormalConsistency, UpdateDeflection, ContinuityOfFaces, BuildCurves3dAll, SameParameterAll), History extended (Merge, ReplaceGenerated/Modified, GetModified/GeneratedShapes), Sewing extended (DeletedFaces, IsModified/Modified, IsDegenerated, IsSectionBound, WhichFace, Load, modes) (3068 ops, 3151 tests)
> - v0.121.0: GLTF/GLB import+export (RWGltf_CafReader/CafWriter with RapidJSON), FilletBuilder (BRepFilletAPI_MakeFillet builder pattern with edge control, contour queries, error diagnosis), ChamferBuilder (BRepFilletAPI_MakeChamfer with symmetric/two-dist/dist-angle modes), BSpline completions (Surface: SetNotPeriodic, SetOrigin, IncreaseMultiplicity, InsertKnots batch, MovePoint, SetPoleCol/Row; Curve3D/2D: SetNotPeriodic, SetOrigin, IncreaseMultiplicity, IncrementMultiplicity, SetKnots, Reverse, MovePointAndTangent) (3024 ops, 3119 tests)
> - v0.120.0: Final cleanup — IsCN continuity checks (Curve3D/2D, Surface U/V), ReversedParameter (Curve3D/2D), ParametricTransformation, continuity order wrappers, Surface UReversed/VReversed copies and reversed parameters, BSpline RemoveVKnot, gp_Vec CrossMagnitude/CrossSquareMagnitude, gp_Dir IsOpposite/IsNormal, Bezier Resolution (Curve3D/Surface), MaxDegree statics (Bezier Curve3D/2D/Surface, BSpline Surface/Curve2D) (2970 ops, 3046 tests)
> - v0.119.0: BREP string serialization, gp_Pln/gp_Lin distance/contains, Geom_BezierSurface queries/mutations, Curve2D Bezier properties, Curve2D BSpline extras, BSplineSurface resolution/periodicity/weight (2945 ops, 3015 tests)
> - v0.118.0: BRepBndLib shape bounding boxes (AABB, optimal, OBB detailed), ShapeAnalysis_ShapeTolerance (min/max/avg/over/inRange), BRepAlgoAPI_Check boolean validation, BRepAlgoAPI_Defeaturing feature removal, Convert_CompPolynomialToPoles, gp_Trsf matrix transform/displacement/transformation, TopExp common vertex, BRep_Tool edge/face flags (SameParameter/SameRange/NaturalRestriction/IsGeometric), Sewing multiple edges (2912 ops, 2982 tests)
> - v0.117.0: MathPoly rc4 polynomial solvers (Linear/Quadratic/Cubic/Quartic), MathInteg rc4 numerical integration (Gauss/Kronrod/TanhSinh adaptive), UnitsMethods length unit conversion, LProp3d curve/surface local properties (curvature/tangent/normal/directions via adaptor), ProjLib surface projectors (line/circle on plane/cylinder) (2890 ops, 2943 tests)
> - v0.116.0: HelixGeom helix construction (rc4: BuilderHelix, BuilderHelixCoil, HelixCurve, Tools), gp_Ax3 coordinate system (create, angle, coplanar, mirror, rotate, translate), gp_GTrsf2d affinity/multiply/invert/transform, gp_Mat2d 2x2 matrix (identity, rotation, scale, determinant, invert, multiply, transpose), quaternion interpolation (SLERP, NLERP, transform lerp), gp_XY/gp_XYZ vector math (modulus, cross, dot, dotCross, normalize), math solvers (BracketedRoot, BracketMinimum, FRPR conjugate gradient, FunctionAllRoots, GaussLeastSquare, NewtonFunctionRoot, Uzawa constrained optimization, EigenValuesSearcher, KronrodSingleIntegration, GaussMultipleIntegration, GaussSetIntegration) (2869 ops, 2918 tests)
> - v0.115.0: GeomAPI_Interpolate expansion (endpoint/per-point tangents, parameters, periodic 3D/2D), PointsToBSpline configurable (3D/2D/surface grid), BRepBuilderAPI_Transform/GTransform (general affine + non-uniform scale), BRepAlgoAPI expansion (section tolerance, split multi, cut with history, defeature tolerance), ThruSections builder (9 ops), GeomConvert split/concatenate, ShapeFix_Shape builder (8 ops), Poly_Triangulation queries (9 ops), GCPnts arc length/parameter (4 ops), BRepAdaptor exposure (6 ops), shape queries (OBB volume, tolerances, free edges/wires/faces, bounding diagonal, centroid, total edge length), Curve3D/2D arc length + closest point, Surface normal/curvatures/fromPointGrid (2819 ops, 2861 tests)
> - v0.114.0: TopoDS_Builder low-level topology, ShapeContentsExtended analysis, FreeBoundsProperties handle-based, WireBuilder incremental, Boolean tolerance/glue modes, Offset wire/face, ThickSolid options, BRepLib utilities, mass properties (inertia/principal axes/radius of gyration), Curve/Surface DN arbitrary derivatives, BRep_Tool queries, unique sub-shape counts, type names (2748 ops, 2811 tests)
> - v0.113.0: MakeEdge completions (ellipse/hyperbola/parabola/curve), ProjectionOnCurve/Surface multi-result, DistShapeShape full results, WireFixer/FaceFixer individual fixes, MakeFace from surface/plane/cylinder, IntCS full results, BSplineCurve/Surface mutations (2682 ops, 2758 tests)
> - v0.112.0: RWMesh face/vertex iterators, Intf_Tool line-box clipping, BRepAlgo_AsDes tracker, BiTgte_CurveOnEdge, shape location/orientation/type, wire/shell construction, BRepCheck extended tolerance analysis, curve/surface type queries, Extrema point-on-curve/surface (2599 ops, 2244 tests)
> - v0.111.0: Advanced math solvers & local properties — PSO, GlobOptMin, FunctionRoots, GaussIntegration, NewtonFunctionSetRoot, GeomGridEval (3D/2D/Surface), BRepLProp (CLProps/SLProps), MathPoly_Laguerre polynomial solver
> - v0.110.0: Constraint solver infrastructure — C callback adapters for math solvers, EvalD0/D1/D2/D3 curve evaluation, batch evaluation, surface differential evaluation
> - v0.24.0: Medial axis transform — Voronoi skeleton, arc/node graph, bisector curves, wall thickness
> - v0.23.0: NLPlate — advanced plate surfaces, non-linear G0/G1 surface deformation
> - v0.22.0: Curve projection onto surfaces — 2D UV projection, composite segments, 3D-on-surface, plane projection
> - v0.21.0: Law functions, variable-section sweeps, XDE GD&T (dimensions, tolerances, datums)
> - v0.20.0: Full parametric surface wrapping — analytic, swept, freeform, pipe, draw methods, curvature
> - v0.19.0: Full 3D parametric curve wrapping — primitives, BSplines, operations, conversion, draw methods
> - v0.18.0: 3D geometry analysis — face surface properties, edge curve queries, point projection, proximity
> - v0.17.0: STL/OBJ import, OBJ/PLY export, advanced shape healing, point classification
> - v0.16.0: Full Geom2d wrapping — 2D parametric curves with evaluation, operations, analysis, Gcc solver, hatching, bisectors
> - v0.14.0: Variable radius fillets, multi-edge blends, 2D fillet/chamfer, surface filling, plate surfaces
> - v0.13.0: Shape analysis, fixing, unification, simplification
> - v0.12.0: Boss, pocket, drilling, shape splitting, gluing, evolved surfaces, pattern operations
> - v0.11.0: Face from wire, sewing operations, solid from shell, curve interpolation
> - v0.10.0: IGES import/export, BREP native format
> - v0.9.0: B-spline surfaces, ruled surfaces, curve analysis
> - v0.8.0: Draft angles, selective fillet, defeaturing, pipe shell modes
> - v0.7.0: Volume, surface area, distance measurement, center of mass

### Adding New OCCT Functions

To wrap additional OCCT functionality, you need to modify three files:

1. **`Sources/OCCTBridge/include/OCCTBridge.h`** - Add C function declaration
2. **`Sources/OCCTBridge/src/OCCTBridge.mm`** - Implement using OCCT C++ API
3. **`Sources/OCCTSwift/Shape.swift`** (or Wire.swift) - Add Swift wrapper

**See [docs/EXTENDING.md](docs/EXTENDING.md) for the complete guide** with:
- Step-by-step walkthrough with example
- Common OCCT patterns (primitives, booleans, topology iteration)
- Memory management details
- Internal struct documentation
- Debugging tips

