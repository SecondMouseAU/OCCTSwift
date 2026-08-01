// Ground truth for OCCTSwift #605: what does OCCT itself do for a shape that has no volume?
// No bridge, no Swift. Pinned OCCT 8.0.0p1 kernel only.

#import <Foundation/Foundation.h>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepBuilderAPI_Transform.hxx>
#include <BRepBuilderAPI_Sewing.hxx>
#include <BRepBuilderAPI_MakeSolid.hxx>
#include <BRepGProp.hxx>
#include <GProp_GProps.hxx>
#include <BRep_Tool.hxx>
#include <BRep_Builder.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Shape.hxx>
#include <TopoDS_Shell.hxx>
#include <TopoDS_Compound.hxx>
#include <gp_Trsf.hxx>
#include <gp_Pnt.hxx>
#include <stdio.h>

static const char* typeName(const TopoDS_Shape& s) {
    switch (s.ShapeType()) {
        case TopAbs_COMPOUND: return "COMPOUND";
        case TopAbs_COMPSOLID: return "COMPSOLID";
        case TopAbs_SOLID: return "SOLID";
        case TopAbs_SHELL: return "SHELL";
        case TopAbs_FACE: return "FACE";
        case TopAbs_WIRE: return "WIRE";
        case TopAbs_EDGE: return "EDGE";
        case TopAbs_VERTEX: return "VERTEX";
        default: return "SHAPE";
    }
}

static void report(const char* label, const TopoDS_Shape& s) {
    printf("\n--- %s  (type=%s, location %s identity) ---\n",
           label, typeName(s), s.Location().IsIdentity() ? "IS" : "is NOT");

    // Does OCCT consider this closed? (BRep_Tool::IsClosed computes it for shells; it does not
    // read a cached flag.)
    int nShells = 0, nClosedShells = 0;
    for (TopExp_Explorer ex(s, TopAbs_SHELL); ex.More(); ex.Next()) {
        nShells++;
        if (BRep_Tool::IsClosed(ex.Current())) nClosedShells++;
    }
    printf("  shells: %d total, %d closed\n", nShells, nClosedShells);

    GProp_GProps vOpen, vClosed, sProps, lProps;
    BRepGProp::VolumeProperties(s, vOpen,   /*OnlyClosed*/ false);
    BRepGProp::VolumeProperties(s, vClosed, /*OnlyClosed*/ true);
    BRepGProp::SurfaceProperties(s, sProps);
    BRepGProp::LinearProperties(s, lProps);

    gp_Pnt a = vOpen.CentreOfMass(), b = vClosed.CentreOfMass();
    gp_Pnt c = sProps.CentreOfMass(), d = lProps.CentreOfMass();
    printf("  VolumeProperties (OnlyClosed=false, OUR CURRENT CALL): mass=%12.4f  COM=(%.4f, %.4f, %.4f)\n",
           vOpen.Mass(), a.X(), a.Y(), a.Z());
    printf("  VolumeProperties (OnlyClosed=true,  OCCT XDE'S CALL ): mass=%12.4f  COM=(%.4f, %.4f, %.4f)\n",
           vClosed.Mass(), b.X(), b.Y(), b.Z());
    printf("  SurfaceProperties                                    : mass=%12.4f  COM=(%.4f, %.4f, %.4f)\n",
           sProps.Mass(), c.X(), c.Y(), c.Z());
    printf("  LinearProperties                                     : mass=%12.4f  COM=(%.4f, %.4f, %.4f)\n",
           lProps.Mass(), d.X(), d.Y(), d.Z());
}

int main() {
    printf("========== #605 GROUND TRUTH: OCCT ONLY, NO BRIDGE ==========\n");

    // Box 10 x 20 x 30 with its min corner at the origin, then moved to (100, 200, 300)
    // so a wrong answer of "the origin" is unmistakable.
    TopoDS_Shape rawBox = BRepPrimAPI_MakeBox(10.0, 20.0, 30.0).Shape();
    gp_Trsf move; move.SetTranslation(gp_Vec(100.0, 200.0, 300.0));
    TopoDS_Shape solid = BRepBuilderAPI_Transform(rawBox, move, /*Copy*/ false).Shape();
    printf("\nbox 10x20x30 moved to (100,200,300); true volume centroid = (105, 210, 315)\n");

    report("CLOSED SOLID", solid);

    // Peel off the solid's shell and check it on its own.
    TopoDS_Shape closedShell;
    for (TopExp_Explorer ex(solid, TopAbs_SHELL); ex.More(); ex.Next()) { closedShell = ex.Current(); break; }
    report("CLOSED SHELL (not wrapped in a solid)", closedShell);

    // Sew 5 of the 6 faces into an OPEN shell. This is the case the fix has to decide.
    BRepBuilderAPI_Sewing sewer(1e-6);
    int fi = 0;
    for (TopExp_Explorer ex(solid, TopAbs_FACE); ex.More(); ex.Next(), fi++) {
        if (fi == 5) continue;              // drop one face
        sewer.Add(ex.Current());
    }
    sewer.Perform();
    TopoDS_Shape openShell = sewer.SewedShape();
    report("OPEN SHELL (5 of 6 faces)", openShell);

    // Lower-dimension sub-shapes.
    TopoDS_Shape face, wire, edge, vertex;
    for (TopExp_Explorer ex(solid, TopAbs_FACE);   ex.More(); ex.Next()) { face   = ex.Current(); break; }
    for (TopExp_Explorer ex(solid, TopAbs_WIRE);   ex.More(); ex.Next()) { wire   = ex.Current(); break; }
    for (TopExp_Explorer ex(solid, TopAbs_EDGE);   ex.More(); ex.Next()) { edge   = ex.Current(); break; }
    for (TopExp_Explorer ex(solid, TopAbs_VERTEX); ex.More(); ex.Next()) { vertex = ex.Current(); break; }
    report("FACE",   face);
    report("WIRE",   wire);
    report("EDGE",   edge);
    report("VERTEX", vertex);

    // A compound mixing dimensions: a solid at the origin plus a loose edge far away.
    TopoDS_Shape smallRaw = BRepPrimAPI_MakeBox(2.0, 2.0, 2.0).Shape();
    gp_Trsf far; far.SetTranslation(gp_Vec(1000.0, 0.0, 0.0));
    TopoDS_Shape smallMoved = BRepBuilderAPI_Transform(smallRaw, far, false).Shape();
    TopoDS_Shape looseEdge;
    for (TopExp_Explorer ex(smallMoved, TopAbs_EDGE); ex.More(); ex.Next()) { looseEdge = ex.Current(); break; }
    TopoDS_Compound comp; BRep_Builder bb; bb.MakeCompound(comp);
    bb.Add(comp, rawBox);          // solid with min corner at origin
    bb.Add(comp, looseEdge);       // edge out at x = 1000
    report("MIXED COMPOUND (solid at origin + loose edge at x=1000)", comp);

    // Is the zero-mass answer literally (0,0,0), or the shape's own location origin?
    // BRepGProp::VolumeProperties seeds the framework with gp_Pnt(0,0,0).Transform(S.Location()).
    TopoDS_Shape movedFace = face.Moved(TopLoc_Location(move));
    printf("\n--- ZERO-MASS SENTINEL: is it always (0,0,0)? ---\n");
    printf("  original face location IS identity      : %s\n", face.Location().IsIdentity() ? "yes" : "no");
    printf("  moved face location IS identity         : %s\n", movedFace.Location().IsIdentity() ? "yes" : "no");
    {
        GProp_GProps g1, g2;
        BRepGProp::VolumeProperties(face, g1, false);
        BRepGProp::VolumeProperties(movedFace, g2, false);
        gp_Pnt p1 = g1.CentreOfMass(), p2 = g2.CentreOfMass();
        printf("  face      : mass=%.6f  COM=(%.4f, %.4f, %.4f)\n", g1.Mass(), p1.X(), p1.Y(), p1.Z());
        printf("  moved face: mass=%.6f  COM=(%.4f, %.4f, %.4f)\n", g2.Mass(), p2.X(), p2.Y(), p2.Z());
        printf("  => a zero-mass COM is the shape's LOCATION origin, not necessarily (0,0,0)\n");
    }

    printf("\n========== END ==========\n");
    return 0;
}
