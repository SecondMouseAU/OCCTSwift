// #484 equivalence probe: structural fingerprint of ShapeUpgrade_WireDivide and
// ShapeFix_ComposeShell results, so stock-vs-patched output can be compared for
// the WITH-context path (which the patch must not change), and so the
// NO-context path can be checked to now produce the same result.
#include <sstream>
#include <stdio.h>
#include <string>

#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepBuilderAPI_MakePolygon.hxx>
#include <BRepTools.hxx>
#include <BRep_Tool.hxx>
#include <Geom_CylindricalSurface.hxx>
#include <Geom_Plane.hxx>
#include <NCollection_HArray2.hxx>
#include <ShapeBuild_ReShape.hxx>
#include <ShapeExtend_CompositeSurface.hxx>
#include <ShapeFix_ComposeShell.hxx>
#include <ShapeUpgrade_WireDivide.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <gp_Ax3.hxx>
#include <gp_Pln.hxx>

static std::string fingerprint(const TopoDS_Shape& s)
{
  if (s.IsNull())
    return "NULL";
  std::ostringstream os;
  os << "type=" << (int)s.ShapeType();
  static const TopAbs_ShapeEnum kinds[] = {TopAbs_FACE, TopAbs_WIRE, TopAbs_EDGE, TopAbs_VERTEX};
  for (TopAbs_ShapeEnum k : kinds)
  {
    int n = 0;
    for (TopExp_Explorer ex(s, k); ex.More(); ex.Next())
      n++;
    os << " n" << (int)k << "=" << n;
  }
  std::ostringstream dump;
  BRepTools::Write(s, dump);
  // hash the BREP dump so any geometric difference shows up
  std::hash<std::string> h;
  os << " brep=" << std::hex << h(dump.str()) << " len=" << std::dec << dump.str().size();
  return os.str();
}

static TopoDS_Face planarFace()
{
  BRepBuilderAPI_MakePolygon p;
  p.Add(gp_Pnt(0, 0, 0));
  p.Add(gp_Pnt(10, 0, 0));
  p.Add(gp_Pnt(10, 10, 0));
  p.Add(gp_Pnt(0, 10, 0));
  p.Close();
  Handle(Geom_Plane)      pln = new Geom_Plane(gp_Pln(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)));
  BRepBuilderAPI_MakeFace mf(pln, p.Wire(), Standard_True);
  return mf.Face();
}

static TopoDS_Face cylindricalFace()
{
  gp_Ax3                          ax(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1));
  Handle(Geom_CylindricalSurface) cyl = new Geom_CylindricalSurface(ax, 3.0);
  BRepBuilderAPI_MakeFace         mf(cyl, 0.0, 2.0 * M_PI, 0.0, 5.0, 1e-7);
  return mf.Face();
}

static void wireDivide(const char* tag, const TopoDS_Face& f, bool withContext)
{
  TopoDS_Wire w;
  for (TopExp_Explorer ex(f, TopAbs_WIRE); ex.More(); ex.Next())
  {
    w = TopoDS::Wire(ex.Current());
    break;
  }
  Handle(ShapeUpgrade_WireDivide) wd = new ShapeUpgrade_WireDivide();
  if (withContext)
    wd->SetContext(new ShapeBuild_ReShape);
  wd->Init(w, f);
  wd->Perform();
  printf("WireDivide   %-12s ctx=%-3s : %s\n", tag, withContext ? "yes" : "NO",
         fingerprint(wd->Wire()).c_str());
}

static void composeShell(const char* tag, const TopoDS_Face& f, bool withContext)
{
  Handle(Geom_Surface)                              surf = BRep_Tool::Surface(f);
  Handle(NCollection_HArray2<Handle(Geom_Surface)>) grid =
    new NCollection_HArray2<Handle(Geom_Surface)>(1, 1, 1, 1);
  grid->SetValue(1, 1, surf);
  Handle(ShapeExtend_CompositeSurface) cs = new ShapeExtend_CompositeSurface(grid);

  Handle(ShapeFix_ComposeShell) shell = new ShapeFix_ComposeShell();
  if (withContext)
    shell->SetContext(new ShapeBuild_ReShape);
  shell->Init(cs, TopLoc_Location(), f, 1e-7);
  bool ok = shell->Perform();
  printf("ComposeShell %-12s ctx=%-3s : ok=%d %s\n", tag, withContext ? "yes" : "NO", (int)ok,
         fingerprint(shell->Result()).c_str());
}

int main()
{
  setvbuf(stdout, nullptr, _IONBF, 0); // unbuffered: keep output when a case SIGSEGVs
  TopoDS_Face planar = planarFace();
  TopoDS_Face cyl    = cylindricalFace();
  wireDivide("planar", planar, true);
  wireDivide("cylindrical", cyl, true);
  composeShell("planar", planar, true);
  composeShell("cylindrical", cyl, true);
  printf("---- no-context (crashes on stock) ----\n");
  wireDivide("planar", planar, false);
  wireDivide("cylindrical", cyl, false);
  composeShell("planar", planar, false);
  composeShell("cylindrical", cyl, false);
  return 0;
}
