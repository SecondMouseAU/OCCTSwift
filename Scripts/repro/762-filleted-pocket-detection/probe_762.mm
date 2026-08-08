// #762 ground truth: what ChFi3d::DefineConnectType reports at every floor/wall-adjacent
// junction of a filleted, chamfered, partially-filleted, filleted-open, and filleted-boss
// fixture, plus (for any cylindrical/spherical junction face) whether its own outward normal
// points radially inward (toward its axis/center) or outward.
//
// This mirrors OCCTEdgeGetConvexity's own call exactly: same smoothThreshold (0.01), same
// CorrectPoint=true, same ChFi3d::DefineConnectType signature (OCCTBridge_BRepGraph.mm). No
// bridge and no Swift: this is OCCT's own classifier, called the same way the bridge calls it,
// against fixtures built with plain OCCT primitives (not centered like Shape.box, corner-based
// like BRepPrimAPI_MakeBox always is; noted per fixture, not assumed).
//
// Build and run:
//   clang++ -std=c++17 -ObjC++ -w \
//     -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
//     -L"Libraries/OCCT.xcframework/macos-arm64" \
//     -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
//     Scripts/repro/762-filleted-pocket-detection/probe_762.mm -o /tmp/probe_762
//   /tmp/probe_762

#include <iostream>
#include <sstream>
#include <string>
#include <vector>
#include <cmath>

#include <gp_Pnt.hxx>
#include <gp_Dir.hxx>
#include <gp_Ax1.hxx>
#include <gp_Vec.hxx>
#include <gp_Cylinder.hxx>
#include <gp_Sphere.hxx>
#include <gp_Cone.hxx>
#include <gp_Pln.hxx>

#include <TopoDS.hxx>
#include <TopoDS_Shape.hxx>
#include <TopoDS_Face.hxx>
#include <TopoDS_Edge.hxx>
#include <TopExp.hxx>
#include <TopExp_Explorer.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopTools_IndexedDataMapOfShapeListOfShape.hxx>
#include <TopTools_ListOfShape.hxx>

#include <BRep_Tool.hxx>
#include <BRepAdaptor_Surface.hxx>
#include <GeomAbs_SurfaceType.hxx>
#include <BRepGProp.hxx>
#include <GProp_GProps.hxx>
#include <Bnd_Box.hxx>
#include <BRepBndLib.hxx>

#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <BRepAlgoAPI_Cut.hxx>
#include <BRepAlgoAPI_Fuse.hxx>
#include <BRepFilletAPI_MakeFillet.hxx>
#include <BRepFilletAPI_MakeChamfer.hxx>

#include <ChFi3d.hxx>
#include <ChFiDS_TypeOfConcavity.hxx>

using namespace std;

// ---------------------------------------------------------------------------------------
// Small helpers
// ---------------------------------------------------------------------------------------

static string typeName(ChFiDS_TypeOfConcavity t) {
    switch (t) {
        case ChFiDS_Concave: return "CONCAVE";
        case ChFiDS_Convex: return "CONVEX";
        case ChFiDS_Tangential: return "TANGENT(smooth)";
        case ChFiDS_FreeBound: return "FreeBound";
        case ChFiDS_Other: return "Other";
        case ChFiDS_Mixed: return "Mixed";
    }
    return "?";
}

static string surfaceTypeName(GeomAbs_SurfaceType t) {
    switch (t) {
        case GeomAbs_Plane: return "Plane";
        case GeomAbs_Cylinder: return "Cylinder";
        case GeomAbs_Cone: return "Cone";
        case GeomAbs_Sphere: return "Sphere";
        case GeomAbs_Torus: return "Torus";
        case GeomAbs_BezierSurface: return "Bezier";
        case GeomAbs_BSplineSurface: return "BSpline";
        case GeomAbs_SurfaceOfRevolution: return "Revolution";
        case GeomAbs_SurfaceOfExtrusion: return "Extrusion";
        case GeomAbs_OffsetSurface: return "Offset";
        default: return "Other";
    }
}

struct FaceDescription {
    GeomAbs_SurfaceType type;
    string typeStr;
    gp_Pnt centroid;
    double area;
    gp_Dir normalAtCentroidish; // approximate outward normal near the face's own mid-parameter
    // For cylinder/sphere/cone: radial test result, "N/A" otherwise.
    string radialTest;
};

// Outward-corrected normal at a face's mid-parameter point (accounts for face orientation).
static bool midNormal(const TopoDS_Face& face, gp_Pnt& outPoint, gp_Dir& outNormal) {
    BRepAdaptor_Surface surf(face, true);
    double uMid = (surf.FirstUParameter() + surf.LastUParameter()) / 2.0;
    double vMid = (surf.FirstVParameter() + surf.LastVParameter()) / 2.0;
    gp_Pnt p;
    gp_Vec du, dv;
    surf.D1(uMid, vMid, p, du, dv);
    gp_Vec n = du.Crossed(dv);
    if (n.Magnitude() < 1e-12) return false;
    n.Normalize();
    if (face.Orientation() == TopAbs_REVERSED) n.Reverse();
    outPoint = p;
    outNormal = gp_Dir(n);
    return true;
}

static FaceDescription describe(const TopoDS_Face& face) {
    FaceDescription d;
    BRepAdaptor_Surface surf(face);
    d.type = surf.GetType();
    d.typeStr = surfaceTypeName(d.type);
    d.radialTest = "N/A";

    GProp_GProps props;
    BRepGProp::SurfaceProperties(face, props);
    d.centroid = props.CentreOfMass();
    d.area = props.Mass();

    gp_Pnt p;
    gp_Dir n;
    if (midNormal(face, p, n)) {
        d.normalAtCentroidish = n;

        if (d.type == GeomAbs_Cylinder) {
            gp_Cylinder cyl = surf.Cylinder();
            gp_Ax1 axis = cyl.Axis();
            gp_Vec toPoint(axis.Location(), p);
            gp_Vec axisDir(axis.Direction());
            gp_Vec radial = toPoint - axisDir * (toPoint.Dot(axisDir));
            if (radial.Magnitude() > 1e-9) {
                radial.Normalize();
                double dot = gp_Vec(n).Dot(radial);
                d.radialTest = dot < 0 ? "INWARD (dot=" + to_string(dot) + ")"
                                       : "OUTWARD (dot=" + to_string(dot) + ")";
            }
        } else if (d.type == GeomAbs_Sphere) {
            gp_Sphere sph = surf.Sphere();
            gp_Vec radial(sph.Location(), p);
            if (radial.Magnitude() > 1e-9) {
                radial.Normalize();
                double dot = gp_Vec(n).Dot(radial);
                d.radialTest = dot < 0 ? "INWARD (dot=" + to_string(dot) + ")"
                                       : "OUTWARD (dot=" + to_string(dot) + ")";
            }
        } else if (d.type == GeomAbs_Cone) {
            gp_Cone cone = surf.Cone();
            gp_Ax1 axis = cone.Axis();
            gp_Vec toPoint(axis.Location(), p);
            gp_Vec axisDir(axis.Direction());
            gp_Vec radial = toPoint - axisDir * (toPoint.Dot(axisDir));
            if (radial.Magnitude() > 1e-9) {
                radial.Normalize();
                double dot = gp_Vec(n).Dot(radial);
                d.radialTest = dot < 0 ? "INWARD (dot=" + to_string(dot) + ")"
                                       : "OUTWARD (dot=" + to_string(dot) + ")";
            }
        }
    }
    return d;
}

static string fmt(const FaceDescription& d) {
    ostringstream ss;
    ss << d.typeStr
       << " area=" << d.area
       << " centroid=(" << d.centroid.X() << "," << d.centroid.Y() << "," << d.centroid.Z() << ")"
       << " radial=" << d.radialTest;
    return ss.str();
}

static void reportJunctions(const TopoDS_Shape& shape, const string& label) {
    cout << "\n=== " << label << " ===\n";

    TopTools_IndexedMapOfShape edgeMap;
    TopExp::MapShapes(shape, TopAbs_EDGE, edgeMap);
    TopTools_IndexedDataMapOfShapeListOfShape edgeFaceMap;
    TopExp::MapShapesAndAncestors(shape, TopAbs_EDGE, TopAbs_FACE, edgeFaceMap);

    const double smoothThreshold = 0.01; // matches OCCTEdgeGetConvexity exactly

    int edgeCount = 0;
    for (int i = 1; i <= edgeMap.Extent(); i++) {
        TopoDS_Edge edge = TopoDS::Edge(edgeMap(i));
        if (BRep_Tool::Degenerated(edge)) continue;
        if (!edgeFaceMap.Contains(edge)) continue;
        const TopTools_ListOfShape& faces = edgeFaceMap.FindFromKey(edge);
        if (faces.Extent() != 2) continue; // skip free/non-manifold edges

        TopTools_ListIteratorOfListOfShape it(faces);
        TopoDS_Face f1 = TopoDS::Face(it.Value());
        it.Next();
        TopoDS_Face f2 = TopoDS::Face(it.Value());

        FaceDescription d1 = describe(f1);
        FaceDescription d2 = describe(f2);

        ChFiDS_TypeOfConcavity type =
            ChFi3d::DefineConnectType(edge, f1, f2, smoothThreshold, true);

        edgeCount++;
        cout << "  edge #" << edgeCount << ": " << typeName(type) << "\n";
        cout << "      F1: " << fmt(d1) << "\n";
        cout << "      F2: " << fmt(d2) << "\n";
    }
    cout << "  (" << edgeCount << " manifold edges total)\n";
}

// ---------------------------------------------------------------------------------------
// Fixtures. All shapes are built with plain BRepPrimAPI (corner-based, NOT centered like
// Shape.box) unless noted: purely local coordinates, chosen to match
// Issue753FilletedJunctionDetectedTests's own numbers (10x10x15 pocket in a 20mm cube)
// wherever this probe's fixture corresponds to an existing Swift fixture, so the two are
// directly comparable.
// ---------------------------------------------------------------------------------------

// A 20x20x20 box centered at the origin (spans -10..10), matching Shape.box(width:height:depth:).
static TopoDS_Shape centeredBox(double size) {
    double h = size / 2.0;
    return BRepPrimAPI_MakeBox(gp_Pnt(-h, -h, -h), size, size, size).Shape();
}

// The floor/wall junction edges of a square pocket cut into centeredBox(20) at
// origin (-5,-5,0) 10x10x15: the four edges at z=0 bounding the 10x10 footprint.
static vector<TopoDS_Edge> pocketJunctionEdges(const TopoDS_Shape& shape) {
    vector<TopoDS_Edge> result;
    TopExp_Explorer exp(shape, TopAbs_EDGE);
    for (; exp.More(); exp.Next()) {
        TopoDS_Edge edge = TopoDS::Edge(exp.Current());
        Bnd_Box box;
        BRepBndLib::Add(edge, box);
        double xmin, ymin, zmin, xmax, ymax, zmax;
        box.Get(xmin, ymin, zmin, xmax, ymax, zmax);
        // At z=0, within the pocket footprint (-5<=x<=5, -5<=y<=5), and a straight edge
        // (zero z-extent): excludes the box's own outer top-face edges, which sit at z=10.
        if (abs(zmin) < 1e-6 && abs(zmax) < 1e-6 &&
            xmin > -5.5 && xmax < 5.5 && ymin > -5.5 && ymax < 5.5) {
            result.push_back(edge);
        }
    }
    return result;
}

static TopoDS_Shape sharpPocket() {
    TopoDS_Shape box = centeredBox(20);
    TopoDS_Shape tool = BRepPrimAPI_MakeBox(gp_Pnt(-5, -5, 0), 10, 10, 15).Shape();
    return BRepAlgoAPI_Cut(box, tool).Shape();
}

static TopoDS_Shape filletedPocket(double radius, int edgeCountToFillet = 4) {
    TopoDS_Shape cut = sharpPocket();
    vector<TopoDS_Edge> junctions = pocketJunctionEdges(cut);
    BRepFilletAPI_MakeFillet mkFillet(cut);
    int n = min((int)junctions.size(), edgeCountToFillet);
    for (int i = 0; i < n; i++) {
        mkFillet.Add(radius, junctions[i]);
    }
    mkFillet.Build();
    if (!mkFillet.IsDone()) {
        cerr << "  !! fillet build FAILED for radius " << radius << "\n";
        return cut;
    }
    return mkFillet.Shape();
}

static TopoDS_Shape chamferedPocket(double distance) {
    TopoDS_Shape cut = sharpPocket();
    vector<TopoDS_Edge> junctions = pocketJunctionEdges(cut);

    // BRepFilletAPI_MakeChamfer needs each edge's own adjacent face for a symmetric chamfer.
    TopTools_IndexedDataMapOfShapeListOfShape edgeFaceMap;
    TopExp::MapShapesAndAncestors(cut, TopAbs_EDGE, TopAbs_FACE, edgeFaceMap);

    BRepFilletAPI_MakeChamfer mkChamfer(cut);
    for (auto& edge : junctions) {
        const TopTools_ListOfShape& faces = edgeFaceMap.FindFromKey(edge);
        TopoDS_Face f1 = TopoDS::Face(faces.First());
        mkChamfer.Add(distance, distance, edge, f1);
    }
    mkChamfer.Build();
    if (!mkChamfer.IsDone()) {
        cerr << "  !! chamfer build FAILED\n";
        return cut;
    }
    return mkChamfer.Shape();
}

// Through-slot spanning the box's full width (x), open at both ends, with the two long
// floor/wall junction edges (at y=-3 and y=3) filleted. Mirrors
// Issue735PocketEnclosureTests.twoWalledThroughSlotIsNotEnclosed's own tool geometry.
static TopoDS_Shape filletedThroughSlot(double radius) {
    TopoDS_Shape box = centeredBox(20);
    TopoDS_Shape tool = BRepPrimAPI_MakeBox(gp_Pnt(-15, -3, 0), 25, 6, 10).Shape();
    TopoDS_Shape cut = BRepAlgoAPI_Cut(box, tool).Shape();

    vector<TopoDS_Edge> junctions;
    TopExp_Explorer exp(cut, TopAbs_EDGE);
    for (; exp.More(); exp.Next()) {
        TopoDS_Edge edge = TopoDS::Edge(exp.Current());
        Bnd_Box bbox;
        BRepBndLib::Add(edge, bbox);
        double xmin, ymin, zmin, xmax, ymax, zmax;
        bbox.Get(xmin, ymin, zmin, xmax, ymax, zmax);
        // At z=0, spanning the full slot length in x (long edges only, not the (nonexistent,
        // since the slot is open) end edges).
        if (abs(zmin) < 1e-6 && abs(zmax) < 1e-6 && (xmax - xmin) > 15.0) {
            junctions.push_back(edge);
        }
    }

    BRepFilletAPI_MakeFillet mkFillet(cut);
    for (auto& edge : junctions) mkFillet.Add(radius, edge);
    mkFillet.Build();
    if (!mkFillet.IsDone()) {
        cerr << "  !! through-slot fillet build FAILED\n";
        return cut;
    }
    return mkFillet.Shape();
}

// A boss (square pillar) standing on a base plate, with its base (convex) junction filleted.
// The base plate's top face is a legitimate AAG "floor" candidate (upward, horizontal,
// planar); the boss's own side walls must NOT be reported as that floor's pocket walls.
static TopoDS_Shape filletedBoss(double radius) {
    TopoDS_Shape plate = BRepPrimAPI_MakeBox(gp_Pnt(-10, -10, -5), 20, 20, 5).Shape();
    TopoDS_Shape boss = BRepPrimAPI_MakeBox(gp_Pnt(-3, -3, 0), 6, 6, 8).Shape();
    TopoDS_Shape fused = BRepAlgoAPI_Fuse(plate, boss).Shape();

    vector<TopoDS_Edge> junctions;
    TopExp_Explorer exp(fused, TopAbs_EDGE);
    for (; exp.More(); exp.Next()) {
        TopoDS_Edge edge = TopoDS::Edge(exp.Current());
        Bnd_Box bbox;
        BRepBndLib::Add(edge, bbox);
        double xmin, ymin, zmin, xmax, ymax, zmax;
        bbox.Get(xmin, ymin, zmin, xmax, ymax, zmax);
        if (abs(zmin) < 1e-6 && abs(zmax) < 1e-6 &&
            xmin > -3.5 && xmax < 3.5 && ymin > -3.5 && ymax < 3.5) {
            junctions.push_back(edge);
        }
    }

    BRepFilletAPI_MakeFillet mkFillet(fused);
    for (auto& edge : junctions) mkFillet.Add(radius, edge);
    mkFillet.Build();
    if (!mkFillet.IsDone()) {
        cerr << "  !! boss fillet build FAILED\n";
        return fused;
    }
    return mkFillet.Shape();
}

// An L-shaped pocket: two rectangular tools fused into an L, cut into a box's top. The
// cavity's own floor boundary has a REFLEX vertex at the inner corner of the L (0,0), where a
// small block of remaining material sticks into the cavity, the mirror image of a boss
// standing in the corner of a room. At an ORDINARY (convex-from-the-cavity) corner, the two
// walls meeting there share a CONCAVE vertical edge (measured on the plain rectangular pocket
// above: fixture 1's edges #17-24). At THIS reflex vertex, the hypothesis under test was that
// the two walls instead share a CONVEX vertical edge, by the same duality that makes a boss's
// own corner convex (fixture 6's edges #9/#11/#13/#15: a boss's BASE junction is
// reentrant/concave, just like a pocket's, but its own CORNER, where two base fillets meet
// going around the boss, is convex).
//
// Filleting ONLY one of the two walls at the reflex corner (WallY0, at y=0, x in [0,6]) and
// leaving the other (WallX0, at x=0, y in [0,6]) sharp was built to test the specific path a PR
// #778 removal-matrix review named: floor, to a confirmed-radially-inward fillet (a junction,
// absorbed), to a face reached by a CONVEX edge from that junction, with the floor having NO
// other, direct route to that same face (so an earlier BFS visit could not mask the result the
// way the through-slot fixture's own floor-to-exterior-wall direct edge did).
//
// Measured, that second condition does not hold here. The fillet does meet WallX0 via a
// CONVEX edge (confirming the reflex-corner hypothesis itself), but BRepFilletAPI_MakeFillet's
// own corner-blending, needed to keep the result watertight where the fillet ends at an
// unfilleted reflex corner, reshapes WallX0's own face so that the FLOOR also borders it
// directly (a CONCAVE edge, confirmed via exact bounding boxes on the Swift side, not
// inferred from face areas alone). So this fixture is masked too, the same way the
// through-slot fixture was, for a related but distinct reason: there, the floor's own polygon
// vertex gave it a direct route; here, the fillet operation's own reshaping does. See the PR
// body for the fuller discussion, including why every construction tried reduces to the same
// masking, and the geometric argument for why that appears to be structural rather than a
// series of fixture-building failures. Kept as a permanent regression test regardless, since
// it is still a real correctness check on reflex-corner and partial-fillet geometry together.
static TopoDS_Shape lShapedPocketPartiallyFilleted(double radius) {
    TopoDS_Shape box = centeredBox(20);
    TopoDS_Shape toolA = BRepPrimAPI_MakeBox(gp_Pnt(-6, -6, 0), 12, 6, 10).Shape();  // x[-6,6] y[-6,0]
    TopoDS_Shape toolB = BRepPrimAPI_MakeBox(gp_Pnt(-6, 0, 0), 6, 6, 10).Shape();     // x[-6,0] y[0,6]
    TopoDS_Shape toolL = BRepAlgoAPI_Fuse(toolA, toolB).Shape();
    TopoDS_Shape cut = BRepAlgoAPI_Cut(box, toolL).Shape();

    // WallY0: the floor/wall junction edge at y=0, z=0, x in [0,6] (bounds the remaining
    // material block from below). Distinguished from every other z=0 junction edge in this
    // fixture by its own bounding box (min.y == max.y == 0, and it does not run along x=-6,
    // x=6, or y=-6).
    TopoDS_Edge wallY0Edge;
    bool found = false;
    TopExp_Explorer exp(cut, TopAbs_EDGE);
    for (; exp.More(); exp.Next()) {
        TopoDS_Edge edge = TopoDS::Edge(exp.Current());
        Bnd_Box bbox;
        BRepBndLib::Add(edge, bbox);
        double xmin, ymin, zmin, xmax, ymax, zmax;
        bbox.Get(xmin, ymin, zmin, xmax, ymax, zmax);
        if (abs(zmin) < 1e-6 && abs(zmax) < 1e-6 &&
            abs(ymin) < 1e-6 && abs(ymax) < 1e-6 &&
            xmin > -1e-6 && xmax > 5.9 && xmax < 6.1) {
            wallY0Edge = edge;
            found = true;
            break;
        }
    }
    if (!found) {
        cerr << "  !! lShapedPocketPartiallyFilleted: WallY0 edge not found\n";
        return cut;
    }

    BRepFilletAPI_MakeFillet mkFillet(cut);
    mkFillet.Add(radius, wallY0Edge);
    mkFillet.Build();
    if (!mkFillet.IsDone()) {
        cerr << "  !! lShapedPocketPartiallyFilleted: fillet build FAILED\n";
        return cut;
    }
    return mkFillet.Shape();
}

// The south floor/wall junction filleted (radius floorRadius), and, separately, the vertical
// corner edge between the west and south walls also filleted (radius cornerRadius), with the
// WEST floor/wall junction left SHARP (unfilleted). Ground-truths the OR-fusion bug (#762
// review round 4): the ORIGINAL crossable test for a `.smooth` edge leaving an already
// confirmed fillet was `isRadiallyInwardFillet(edge.face1Index) ||
// isRadiallyInwardFillet(edge.face2Index)`, which tests EITHER end of the edge. Once the
// south fillet is confirmed, that OR is trivially satisfied by the south fillet's own half
// regardless of what is on the far side, so it wrongly crossed into this corner-blend
// cylinder and, since the cylinder is vertical and radially inward too, wrongly accepted it
// as a WALL. The corner-blend cylinder is reached only through the south fillet's own further
// (non-floor-bordering) torus junction, never directly from the floor.
static TopoDS_Shape southFilletPlusVerticalCornerFillet(double floorRadius, double cornerRadius) {
    TopoDS_Shape box = centeredBox(20);
    TopoDS_Shape tool = BRepPrimAPI_MakeBox(gp_Pnt(-5, -5, 0), 10, 10, 15).Shape();
    TopoDS_Shape cut = BRepAlgoAPI_Cut(box, tool).Shape();

    // South floor/wall junction: z=0, y=-5, x spanning [-5,5].
    TopoDS_Edge southEdge;
    bool foundSouth = false;
    {
        TopExp_Explorer exp(cut, TopAbs_EDGE);
        for (; exp.More(); exp.Next()) {
            TopoDS_Edge edge = TopoDS::Edge(exp.Current());
            Bnd_Box bbox;
            BRepBndLib::Add(edge, bbox);
            double xmin, ymin, zmin, xmax, ymax, zmax;
            bbox.Get(xmin, ymin, zmin, xmax, ymax, zmax);
            if (abs(zmin) < 1e-6 && abs(zmax) < 1e-6 &&
                abs(ymin - (-5)) < 1e-6 && abs(ymax - (-5)) < 1e-6) {
                southEdge = edge;
                foundSouth = true;
                break;
            }
        }
    }
    if (!foundSouth) {
        cerr << "  !! southFilletPlusVerticalCornerFillet: south edge not found\n";
        return cut;
    }

    BRepFilletAPI_MakeFillet mkFillet1(cut);
    mkFillet1.Add(floorRadius, southEdge);
    mkFillet1.Build();
    if (!mkFillet1.IsDone()) {
        cerr << "  !! southFilletPlusVerticalCornerFillet: south fillet build FAILED\n";
        return cut;
    }
    TopoDS_Shape filletedSouth = mkFillet1.Shape();

    // Vertical corner edge between west (x=-5) and south (y=-5) walls: x=-5, y=-5, spanning z.
    TopoDS_Edge cornerEdge;
    bool foundCorner = false;
    {
        TopExp_Explorer exp(filletedSouth, TopAbs_EDGE);
        for (; exp.More(); exp.Next()) {
            TopoDS_Edge edge = TopoDS::Edge(exp.Current());
            Bnd_Box bbox;
            BRepBndLib::Add(edge, bbox);
            double xmin, ymin, zmin, xmax, ymax, zmax;
            bbox.Get(xmin, ymin, zmin, xmax, ymax, zmax);
            if (abs(xmin - (-5)) < 1e-3 && abs(xmax - (-5)) < 1e-3 &&
                abs(ymin - (-5)) < 1e-3 && abs(ymax - (-5)) < 1e-3 &&
                (zmax - zmin) > 1.0) {
                cornerEdge = edge;
                foundCorner = true;
                break;
            }
        }
    }
    if (!foundCorner) {
        cerr << "  !! southFilletPlusVerticalCornerFillet: corner edge not found\n";
        return filletedSouth;
    }

    BRepFilletAPI_MakeFillet mkFillet2(filletedSouth);
    mkFillet2.Add(cornerRadius, cornerEdge);
    mkFillet2.Build();
    if (!mkFillet2.IsDone()) {
        cerr << "  !! southFilletPlusVerticalCornerFillet: corner fillet build FAILED\n";
        return filletedSouth;
    }
    return mkFillet2.Shape();
}

// All four floor/wall junctions filleted (radius floorRadius) AND all four vertical corners
// separately filleted (radius cornerRadius): a torus/corner-fillet ring all the way around
// the pocket. Stresses whether junction-to-junction chaining, now confined by the #762 review
// round 4 fix to producing only further junctions past the first floor-bordering hop, still
// finds exactly the four genuine flat walls without wandering into any of the eight curved
// junction faces (four floor fillets, four corner fillets) or the four BSpline surfaces OCCT
// inserts to reconcile the mismatched-radius corners.
static TopoDS_Shape fullyRoundedPocket(double floorRadius, double cornerRadius) {
    TopoDS_Shape cut = sharpPocket();
    vector<TopoDS_Edge> floorEdges = pocketJunctionEdges(cut);
    BRepFilletAPI_MakeFillet mkFillet1(cut);
    for (auto& edge : floorEdges) mkFillet1.Add(floorRadius, edge);
    mkFillet1.Build();
    if (!mkFillet1.IsDone()) {
        cerr << "  !! fullyRoundedPocket: floor fillet build FAILED\n";
        return cut;
    }
    TopoDS_Shape filletedFloor = mkFillet1.Shape();

    // TopTools_IndexedMapOfShape, not a plain TopExp_Explorer: a bare explorer over a solid
    // visits each edge once per face-wire occurrence (twice for an edge shared by two faces),
    // so counting matches directly against it would double-count every corner edge found.
    vector<TopoDS_Edge> cornerEdges;
    TopTools_IndexedMapOfShape edgeMap;
    TopExp::MapShapes(filletedFloor, TopAbs_EDGE, edgeMap);
    for (int i = 1; i <= edgeMap.Extent(); i++) {
        TopoDS_Edge edge = TopoDS::Edge(edgeMap(i));
        Bnd_Box bbox;
        BRepBndLib::Add(edge, bbox);
        double xmin, ymin, zmin, xmax, ymax, zmax;
        bbox.Get(xmin, ymin, zmin, xmax, ymax, zmax);
        // A true vertical corner edge is a single (x,y) point swept in z: tight x/y extent of
        // its own, at one of the pocket's four (+-5,+-5) corners. Distinguishes it from a
        // diagonal boundary edge of the corner-reconciliation patch the floor fillet itself
        // inserts, which can loosely satisfy a min-only x/y check but spans a wide x/y range.
        if ((zmax - zmin) > 1.0 && (xmax - xmin) < 0.5 && (ymax - ymin) < 0.5 &&
            abs(abs(xmin) - 5) < 1e-2 && abs(abs(ymin) - 5) < 1e-2) {
            cornerEdges.push_back(edge);
        }
    }
    if (cornerEdges.size() != 4) {
        cerr << "  !! fullyRoundedPocket: expected 4 corner edges, found " << cornerEdges.size() << "\n";
    }

    BRepFilletAPI_MakeFillet mkFillet2(filletedFloor);
    for (auto& edge : cornerEdges) mkFillet2.Add(cornerRadius, edge);
    mkFillet2.Build();
    if (!mkFillet2.IsDone()) {
        cerr << "  !! fullyRoundedPocket: corner fillet build FAILED\n";
        return filletedFloor;
    }
    return mkFillet2.Shape();
}

int main() {
    cout << "#762 ground truth: ChFi3d::DefineConnectType at floor/wall junctions\n";
    cout << "smoothThreshold = 0.01, CorrectPoint = true (matches OCCTEdgeGetConvexity exactly)\n";

    reportJunctions(sharpPocket(), "1. Sharp pocket (control), 10x10x15 pocket in a 20mm cube");

    for (double r : {0.5, 1.0, 2.0, 4.0}) {
        ostringstream label;
        label << "2. Filleted pocket, radius=" << r;
        reportJunctions(filletedPocket(r), label.str());
    }

    reportJunctions(chamferedPocket(1.0), "3. Chamfered pocket, distance=1.0 (symmetric)");

    reportJunctions(filletedPocket(1.0, 2), "4. Partially filleted pocket (2 of 4 edges, radius=1.0)");

    reportJunctions(filletedThroughSlot(1.0), "5. Filleted through-slot (open both ends), radius=1.0");

    reportJunctions(filletedBoss(1.0), "6. Filleted boss (convex feature, must NOT be a pocket), radius=1.0");

    reportJunctions(lShapedPocketPartiallyFilleted(1.0),
                     "8. L-shaped pocket, reflex corner, one of its two walls filleted, radius=1.0");

    reportJunctions(southFilletPlusVerticalCornerFillet(3.0, 2.0),
                     "9. South floor fillet (r=3) + separate vertical corner fillet (r=2), west junction left sharp");

    reportJunctions(fullyRoundedPocket(3.0, 2.0),
                     "10. Fully rounded pocket: floor fillet (r=3) all four sides + vertical corner fillet (r=2) all four corners");

    return 0;
}
