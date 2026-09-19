// Ground truth for #1638: can ShapeFix_ComposeShell split a face when the
// ShapeExtend_CompositeSurface it is handed is a real n x m grid rather than the 1 x 1 grid the
// bridge builds today?
//
// Build: see CLAUDE.md, "Compile a Ground Truth C++ Test".

#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <BRep_Tool.hxx>
#include <BRepTools.hxx>
#include <Geom_RectangularTrimmedSurface.hxx>
#include <Geom_Surface.hxx>
#include <NCollection_HArray2.hxx>
#include <ShapeBuild_ReShape.hxx>
#include <ShapeExtend_CompositeSurface.hxx>
#include <ShapeFix_ComposeShell.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Face.hxx>
#include <gp_Pln.hxx>

#include <cstdio>

static int faceCount(const TopoDS_Shape& s)
{
  int n = 0;
  for (TopExp_Explorer e(s, TopAbs_FACE); e.More(); e.Next())
    n++;
  return n;
}

// Tile the face's own surface into nbU x nbV rectangular-trimmed patches over the face's UV box.
static Handle(ShapeExtend_CompositeSurface) tile(const TopoDS_Face& face, int nbU, int nbV,
                                                 ShapeExtend_Parametrisation param)
{
  Handle(Geom_Surface) surf = BRep_Tool::Surface(face);
  double u0, u1, v0, v1;
  BRepTools::UVBounds(face, u0, u1, v0, v1);
  printf("   face UV box            : u [%g, %g]  v [%g, %g]\n", u0, u1, v0, v1);

  Handle(NCollection_HArray2<Handle(Geom_Surface)>) grid =
    new NCollection_HArray2<Handle(Geom_Surface)>(1, nbU, 1, nbV);
  for (int i = 1; i <= nbU; i++)
  {
    double ua = u0 + (u1 - u0) * (i - 1) / nbU;
    double ub = u0 + (u1 - u0) * i / nbU;
    for (int j = 1; j <= nbV; j++)
    {
      double vb0 = v0 + (v1 - v0) * (j - 1) / nbV;
      double vb1 = v0 + (v1 - v0) * j / nbV;
      grid->SetValue(i, j, new Geom_RectangularTrimmedSurface(surf, ua, ub, vb0, vb1));
    }
  }
  Handle(ShapeExtend_CompositeSurface) cs = new ShapeExtend_CompositeSurface();
  bool connected = cs->Init(grid, param);
  printf("   Init() connectivity ok : %s\n", connected ? "true" : "false");
  return cs;
}

static void run(const char* label, const TopoDS_Face& face, int nbU, int nbV,
                ShapeExtend_Parametrisation param)
{
  printf("=== %s, %d x %d grid\n", label, nbU, nbV);
  Handle(ShapeExtend_CompositeSurface) cs = tile(face, nbU, nbV, param);
  Handle(ShapeFix_ComposeShell) shell = new ShapeFix_ComposeShell();
  shell->SetContext(new ShapeBuild_ReShape());
  shell->Init(cs, TopLoc_Location(), face, 1e-6);
  bool ok = shell->Perform();
  printf("   Perform()              : %s\n", ok ? "true" : "false");
  printf("   faces in: 1, faces out : %d\n", faceCount(shell->Result()));
  printf("   status DONE2 (split)   : %s\n", shell->Status(ShapeExtend_DONE2) ? "true" : "false");
}

int main()
{
  // A planar face.
  TopoDS_Face plane = BRepBuilderAPI_MakeFace(gp_Pln(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)),
                                              0.0, 10.0, 0.0, 10.0);
  run("planar face, natural", plane, 1, 1, ShapeExtend_Natural);
  run("planar face, natural", plane, 2, 1, ShapeExtend_Natural);
  run("planar face, natural", plane, 3, 2, ShapeExtend_Natural);
  run("planar face, uniform", plane, 3, 2, ShapeExtend_Uniform);

  // A cylinder's lateral face (periodic in U).
  TopoDS_Shape cyl = BRepPrimAPI_MakeCylinder(5.0, 10.0).Shape();
  TopoDS_Face  lateral;
  for (TopExp_Explorer e(cyl, TopAbs_FACE); e.More(); e.Next())
  {
    TopoDS_Face f = TopoDS::Face(e.Current());
    Handle(Geom_Surface) s = BRep_Tool::Surface(f);
    if (s->DynamicType()->Name() == std::string("Geom_CylindricalSurface"))
    {
      lateral = f;
      break;
    }
  }
  if (!lateral.IsNull())
  {
    run("cylinder lateral face, natural", lateral, 2, 1, ShapeExtend_Natural);
    run("cylinder lateral face, natural", lateral, 1, 2, ShapeExtend_Natural);
  }
  return 0;
}
