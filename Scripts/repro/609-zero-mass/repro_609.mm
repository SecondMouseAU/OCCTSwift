// Ground truth for #609: what a zero-mass GProp_GProps framework actually reports, and what
// OnlyClosed=true changes, across every shape class the bridge can be handed.
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <BRepPrimAPI_MakeSphere.hxx>
#include <BRepBuilderAPI_MakeVertex.hxx>
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepBuilderAPI_MakePolygon.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepBuilderAPI_MakeShell.hxx>
#include <BRepBuilderAPI_MakeSolid.hxx>
#include <BRepBuilderAPI_Sewing.hxx>
#include <BRepBuilderAPI_Transform.hxx>
#include <BRepGProp.hxx>
#include <BRepGProp_Face.hxx>
#include <BRepGProp_Vinert.hxx>
#include <BRepGProp_Sinert.hxx>
#include <BRepGProp_Cinert.hxx>
#include <BRepAdaptor_Curve.hxx>
#include <BRep_Builder.hxx>
#include <BRep_Tool.hxx>
#include <GProp_GProps.hxx>
#include <GProp_PGProps.hxx>
#include <GProp_CelGProps.hxx>
#include <GProp_PrincipalProps.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Compound.hxx>
#include <TopoDS_Shell.hxx>
#include <TopoDS_Solid.hxx>
#include <gp_Trsf.hxx>
#include <gp_Lin.hxx>
#include <TopLoc_Location.hxx>
#include <Standard_Failure.hxx>
#include <cstdio>
#include <cmath>

static const char* yn(bool b) { return b ? "yes" : "no"; }

static void row(const char* name, const TopoDS_Shape& s) {
  GProp_GProps vOpen, vClosed, surf, lin;
  BRepGProp::VolumeProperties(s, vOpen, /*OnlyClosed*/ false);
  BRepGProp::VolumeProperties(s, vClosed, /*OnlyClosed*/ true);
  BRepGProp::SurfaceProperties(s, surf);
  BRepGProp::LinearProperties(s, lin);
  gp_Pnt a = vOpen.CentreOfMass(), b = vClosed.CentreOfMass(), c = surf.CentreOfMass(), d = lin.CentreOfMass();
  printf("%-28s vol(open)=%12.4f @(%8.3f,%8.3f,%8.3f)  vol(closed)=%12.4f @(%8.3f,%8.3f,%8.3f)  area=%10.4f @(%8.3f,%8.3f,%8.3f)  len=%9.4f @(%8.3f,%8.3f,%8.3f)\n",
         name, vOpen.Mass(), a.X(), a.Y(), a.Z(), vClosed.Mass(), b.X(), b.Y(), b.Z(),
         surf.Mass(), c.X(), c.Y(), c.Z(), lin.Mass(), d.X(), d.Y(), d.Z());
}

int main() {
  gp_Trsf move; move.SetTranslation(gp_Vec(100, 200, 300));

  TopoDS_Shape solid = BRepBuilderAPI_Transform(BRepPrimAPI_MakeBox(10., 20., 30.).Shape(), move, true).Shape();
  TopoDS_Shape reversedSolid = solid.Reversed();

  TopoDS_Shell closedShell;
  for (TopExp_Explorer e(solid, TopAbs_SHELL); e.More(); e.Next()) { closedShell = TopoDS::Shell(e.Current()); break; }

  // open shell: 5 of the 6 faces, rebuilt so the sharing is preserved
  BRep_Builder bb;
  TopoDS_Shell openShell; bb.MakeShell(openShell);
  int fi = 0; TopoDS_Face oneFace;
  for (TopExp_Explorer e(solid, TopAbs_FACE); e.More(); e.Next(), fi++) {
    if (fi == 0) oneFace = TopoDS::Face(e.Current());
    if (fi < 5) bb.Add(openShell, e.Current());
  }

  TopoDS_Edge oneEdge;
  for (TopExp_Explorer e(solid, TopAbs_EDGE); e.More(); e.Next()) { oneEdge = TopoDS::Edge(e.Current()); break; }
  TopoDS_Shape oneWire;
  for (TopExp_Explorer e(solid, TopAbs_WIRE); e.More(); e.Next()) { oneWire = e.Current(); break; }
  TopoDS_Shape oneVertex = BRepBuilderAPI_MakeVertex(gp_Pnt(100, 200, 300)).Shape();

  TopoDS_Compound cSolidFace, cSolidEdge, cTwoSolids, cSolidPlusReversed;
  bb.MakeCompound(cSolidFace);  bb.Add(cSolidFace, solid);  bb.Add(cSolidFace, oneFace);
  bb.MakeCompound(cSolidEdge);  bb.Add(cSolidEdge, solid);  bb.Add(cSolidEdge, BRepBuilderAPI_MakeEdge(gp_Pnt(1000,0,0), gp_Pnt(1010,0,0)).Shape());
  TopoDS_Shape solid2 = BRepBuilderAPI_Transform(solid, [] { gp_Trsf t; t.SetTranslation(gp_Vec(500,0,0)); return t; }(), true).Shape();
  bb.MakeCompound(cTwoSolids);  bb.Add(cTwoSolids, solid);  bb.Add(cTwoSolids, solid2);
  bb.MakeCompound(cSolidPlusReversed); bb.Add(cSolidPlusReversed, solid); bb.Add(cSolidPlusReversed, solid.Reversed());

  TopoDS_Shape cyl = BRepPrimAPI_MakeCylinder(5., 20.).Shape();
  TopoDS_Shape sph = BRepPrimAPI_MakeSphere(7.).Shape();

  // Unsewn: six independently-built faces, no shared edges, assembled into a shell and a "solid".
  auto quad = [&](gp_Pnt a, gp_Pnt b, gp_Pnt c, gp_Pnt d) {
    BRepBuilderAPI_MakePolygon p(a, b, c, d, true);
    return BRepBuilderAPI_MakeFace(p.Wire()).Face();
  };
  gp_Pnt p000(0,0,0), p100(10,0,0), p110(10,20,0), p010(0,20,0);
  gp_Pnt q000(0,0,30), q100(10,0,30), q110(10,20,30), q010(0,20,30);
  TopoDS_Shell unsewnShell; bb.MakeShell(unsewnShell);
  bb.Add(unsewnShell, quad(p000,p010,p110,p100));
  bb.Add(unsewnShell, quad(q000,q100,q110,q010));
  bb.Add(unsewnShell, quad(p000,p100,q100,q000));
  bb.Add(unsewnShell, quad(p100,p110,q110,q100));
  bb.Add(unsewnShell, quad(p110,p010,q010,q110));
  bb.Add(unsewnShell, quad(p010,p000,q000,q010));
  TopoDS_Solid unsewnSolid = BRepBuilderAPI_MakeSolid(unsewnShell).Solid();

  // and the same six faces after sewing, which is what an STL/mesh import path does
  BRepBuilderAPI_Sewing sew(1e-6);
  for (TopExp_Explorer e(unsewnShell, TopAbs_FACE); e.More(); e.Next()) sew.Add(e.Current());
  sew.Perform();
  TopoDS_Shape sewn = sew.SewedShape();
  TopoDS_Solid sewnSolid;
  for (TopExp_Explorer e(sewn, TopAbs_SHELL); e.More(); e.Next()) { sewnSolid = BRepBuilderAPI_MakeSolid(TopoDS::Shell(e.Current())).Solid(); break; }

  printf("=== A. mass + centre of mass, per measure ===\n");
  row("solid",                 solid);
  row("solid (reversed)",      reversedSolid);
  row("closed shell",          closedShell);
  row("open shell (5/6)",      openShell);
  row("face",                  oneFace);
  row("wire",                  oneWire);
  row("edge",                  oneEdge);
  row("vertex",                oneVertex);
  row("compound solid+face",   cSolidFace);
  row("compound solid+edge",   cSolidEdge);
  row("compound 2 solids",     cTwoSolids);
  row("compound solid+rev",    cSolidPlusReversed);
  row("cylinder (seam)",       cyl);
  row("sphere (degen poles)",  sph);
  row("unsewn shell",          unsewnShell);
  row("unsewn 'solid'",        unsewnSolid);
  row("sewn solid",            sewnSolid);

  printf("\n=== B. IsClosed per shell ===\n");
  auto shellClosed = [&](const char* n, const TopoDS_Shape& s) {
    int i = 0;
    for (TopExp_Explorer e(s, TopAbs_SHELL); e.More(); e.Next(), i++)
      printf("%-24s shell[%d] IsClosed=%s  Closed() flag=%s\n", n, i,
             yn(BRep_Tool::IsClosed(e.Current())), yn(e.Current().Closed()));
    if (i == 0) printf("%-24s (no shells)\n", n);
  };
  shellClosed("solid", solid);
  shellClosed("open shell", openShell);
  shellClosed("unsewn 'solid'", unsewnSolid);
  shellClosed("sewn solid", sewnSolid);
  shellClosed("cylinder", cyl);
  shellClosed("sphere", sph);
  shellClosed("face", oneFace);

  printf("\n=== C. what a ZERO-MASS framework reports (face, volume measure) ===\n");
  {
    GProp_GProps z;
    BRepGProp::VolumeProperties(oneFace, z);
    gp_Pnt com = z.CentreOfMass();
    gp_Mat m = z.MatrixOfInertia();
    GProp_PrincipalProps pp = z.PrincipalProperties();
    double i1, i2, i3, r1, r2, r3;
    pp.Moments(i1, i2, i3); pp.RadiusOfGyration(r1, r2, r3);
    gp_Vec a1 = pp.FirstAxisOfInertia(), a2 = pp.SecondAxisOfInertia(), a3 = pp.ThirdAxisOfInertia();
    double sx, sy, sz; z.StaticMoments(sx, sy, sz);
    printf("Mass            = %.6f\n", z.Mass());
    printf("CentreOfMass    = (%.4f, %.4f, %.4f)   <- the shape's LOCATION, not (0,0,0)\n", com.X(), com.Y(), com.Z());
    printf("MatrixOfInertia = [%g %g %g; %g %g %g; %g %g %g]\n",
           m(1,1), m(1,2), m(1,3), m(2,1), m(2,2), m(2,3), m(3,1), m(3,2), m(3,3));
    printf("StaticMoments   = (%g, %g, %g)\n", sx, sy, sz);
    printf("PrincipalMoments= (%g, %g, %g)\n", i1, i2, i3);
    printf("GyrationRadii   = (%g, %g, %g)\n", r1, r2, r3);
    printf("PrincipalAxes   = (%.3f,%.3f,%.3f) (%.3f,%.3f,%.3f) (%.3f,%.3f,%.3f)  <- pure artefact\n",
           a1.X(), a1.Y(), a1.Z(), a2.X(), a2.Y(), a2.Z(), a3.X(), a3.Y(), a3.Z());
    printf("HasSymmetryAxis = %s     HasSymmetryPoint = %s   <- reports SPHERICAL symmetry\n",
           yn(pp.HasSymmetryAxis()), yn(pp.HasSymmetryPoint()));
    double rg = z.RadiusOfGyration(gp_Ax1(gp_Pnt(0,0,0), gp_Dir(0,0,1)));
    printf("RadiusOfGyration(OZ) = %f   isnan=%s   <- sqrt(0/0)\n", rg, yn(std::isnan(rg)));
  }

  printf("\n=== D. same, for an OPEN SHELL (mass is non-zero but fabricated) ===\n");
  {
    GProp_GProps z;
    BRepGProp::VolumeProperties(openShell, z);
    GProp_PrincipalProps pp = z.PrincipalProperties();
    double i1, i2, i3; pp.Moments(i1, i2, i3);
    printf("Mass=%.4f  HasSymmetryAxis=%s HasSymmetryPoint=%s  moments=(%g,%g,%g)\n",
           z.Mass(), yn(pp.HasSymmetryAxis()), yn(pp.HasSymmetryPoint()), i1, i2, i3);
    double rg = z.RadiusOfGyration(gp_Ax1(gp_Pnt(0,0,0), gp_Dir(0,0,1)));
    printf("RadiusOfGyration(OZ) = %f  (a real number derived from a fabricated mass)\n", rg);
  }

  printf("\n=== E2. the sentinel under a real TopLoc_Location ===\n");
  {
    // BRepBuilderAPI_Transform(copy=true) bakes the transform into the geometry, leaving the
    // location identity. TopoDS_Shape::Move() sets a real location, which is what an assembly
    // instance or a moved import carries, and what seeds GProp_GProps.
    TopoDS_Shape movedFace = oneFace;
    gp_Trsf t2; t2.SetTranslation(gp_Vec(100, 200, 300));
    movedFace.Move(TopLoc_Location(t2));
    GProp_GProps z1, z2;
    BRepGProp::VolumeProperties(oneFace, z1);
    BRepGProp::VolumeProperties(movedFace, z2);
    gp_Pnt c1 = z1.CentreOfMass(), c2 = z2.CentreOfMass();
    printf("face (identity loc) : mass=%.4f com=(%.4f,%.4f,%.4f)\n", z1.Mass(), c1.X(), c1.Y(), c1.Z());
    printf("face (moved by loc) : mass=%.4f com=(%.4f,%.4f,%.4f)  <- looks like a real point\n", z2.Mass(), c2.X(), c2.Y(), c2.Z());
    TopoDS_Shape twice = movedFace; twice.Move(TopLoc_Location(t2));
    GProp_GProps z3; BRepGProp::VolumeProperties(twice, z3);
    gp_Pnt c3 = z3.CentreOfMass();
    printf("face (moved twice)  : mass=%.4f com=(%.4f,%.4f,%.4f)  <- and it TRACKS the shape\n", z3.Mass(), c3.X(), c3.Y(), c3.Z());
  }

  printf("\n=== E. GProp_PGProps / CelGProps degenerate inputs ===\n");
  {
    GProp_PGProps empty;
    gp_Pnt c = empty.CentreOfMass();
    printf("PGProps, no points        : mass=%.4f com=(%.4f,%.4f,%.4f)\n", empty.Mass(), c.X(), c.Y(), c.Z());
    try {
      GProp_PGProps cancel;
      cancel.AddPoint(gp_Pnt(0,0,0), 1.0);
      cancel.AddPoint(gp_Pnt(10,0,0), -1.0);
      gp_Pnt c2 = cancel.CentreOfMass();
      printf("PGProps, weights sum to 0 : mass=%.4f com=(%.4f,%.4f,%.4f)\n", cancel.Mass(), c2.X(), c2.Y(), c2.Z());
    } catch (Standard_Failure& e) { printf("PGProps, weights sum to 0 : THROWS %s\n", e.GetMessageString()); }
    try {
      GProp_PGProps zeroW; zeroW.AddPoint(gp_Pnt(10,0,0), 0.0);
      printf("PGProps, zero weight      : mass=%.4f\n", zeroW.Mass());
    } catch (Standard_Failure& e) { printf("PGProps, zero weight      : THROWS %s\n", e.GetMessageString()); }
    gp_Lin line(gp_Pnt(100,200,300), gp_Dir(1,0,0));
    GProp_CelGProps zeroLen(line, 5.0, 5.0, gp_Pnt(0,0,0));
    gp_Pnt c4 = zeroLen.CentreOfMass();
    printf("CelGProps, u1==u2         : mass=%.4f com=(%.4f,%.4f,%.4f)\n", zeroLen.Mass(), c4.X(), c4.Y(), c4.Z());
  }

  printf("\n=== F. BRepGProp_Vinert on a face through the location point ===\n");
  {
    // Vinert integrates the volume between the face and the location point; a planar face whose
    // plane contains that point contributes nothing.
    TopoDS_Face flat = quad(gp_Pnt(-5,-5,0), gp_Pnt(5,-5,0), gp_Pnt(5,5,0), gp_Pnt(-5,5,0));
    BRepGProp_Face gf(flat);
    BRepGProp_Vinert v; v.SetLocation(gp_Pnt(0,0,0)); v.Perform(gf);
    gp_Pnt c = v.CentreOfMass();
    printf("Vinert(coplanar face) : mass=%.6f com=(%.4f,%.4f,%.4f)\n", v.Mass(), c.X(), c.Y(), c.Z());
    BRepGProp_Sinert s; s.SetLocation(gp_Pnt(0,0,0)); s.Perform(gf);
    gp_Pnt cs = s.CentreOfMass();
    printf("Sinert(same face)     : mass=%.6f com=(%.4f,%.4f,%.4f)\n", s.Mass(), cs.X(), cs.Y(), cs.Z());
    try {
      TopoDS_Edge degen = BRepBuilderAPI_MakeEdge(gp_Pnt(1,2,3), gp_Pnt(1,2,3)).Edge();
      BRepAdaptor_Curve ac(degen);
      BRepGProp_Cinert ci(ac, gp_Pnt(0,0,0));
      gp_Pnt cc = ci.CentreOfMass();
      printf("Cinert(zero-len edge) : mass=%.6f com=(%.4f,%.4f,%.4f)\n", ci.Mass(), cc.X(), cc.Y(), cc.Z());
    } catch (Standard_Failure& e) { printf("Cinert(zero-len edge) : THROWS %s\n", e.GetMessageString()); }
  }
  printf("\n=== H. the flux integral's SIGN is a valid orientation signal ===\n");
  {
    // OnlyClosed=false is worthless as a measurement over an open surface, but reversing a surface
    // negates the flux whether it is closed or not, so the sign is sound either way. Shape.sweep
    // relies on this to normalise an inward-facing pipe (#170), and a pipe sweep is an open shell.
    auto flux = [](const TopoDS_Shape& s) {
      GProp_GProps p; BRepGProp::VolumeProperties(s, p, false); return p.Mass();
    };
    TopoDS_Shell oneFaceShell; bb.MakeShell(oneFaceShell); bb.Add(oneFaceShell, oneFace);
    printf("%-22s forward=%12.4f  reversed=%12.4f\n", "solid", flux(solid), flux(solid.Reversed()));
    printf("%-22s forward=%12.4f  reversed=%12.4f\n", "open shell (5/6)", flux(openShell), flux(openShell.Reversed()));
    printf("%-22s forward=%12.4f  reversed=%12.4f  <- coplanar with the origin\n",
           "lone face", flux(oneFace), flux(oneFace.Reversed()));
  }

  printf("\n=== G. what OCCTShapeSymmetryAxes sees for a zero-mass / open-shell shape ===\n");
  {
    auto sym = [&](const char* n, const TopoDS_Shape& s) {
      GProp_GProps p; BRepGProp::VolumeProperties(s, p);
      GProp_PrincipalProps pp = p.PrincipalProperties();
      gp_Pnt cm = p.CentreOfMass();
      double i1,i2,i3; pp.Moments(i1,i2,i3);
      printf("%-20s mass=%10.3f com=(%7.3f,%7.3f,%7.3f) hasSymPoint=%-4s hasSymAxis=%-4s moments=(%g,%g,%g)\n",
             n, p.Mass(), cm.X(), cm.Y(), cm.Z(), yn(pp.HasSymmetryPoint()), yn(pp.HasSymmetryAxis()), i1, i2, i3);
    };
    sym("solid", solid);
    sym("face", oneFace);
    sym("edge", oneEdge);
    sym("wire", oneWire);
    sym("vertex", oneVertex);
    sym("open shell", openShell);
    sym("unsewn 'solid'", unsewnSolid);
  }
  return 0;
}
