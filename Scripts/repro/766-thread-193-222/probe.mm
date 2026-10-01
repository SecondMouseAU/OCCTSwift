// Kernel parity probe for OCCTThreadTests #181-#222 (#1990).
//
// The thread builders under test (threadedShaft's direct cam-loft build, threadedHole's cut
// path, helicalSweep) are Swift compositions of many bridge calls, so the probe does not
// re-derive the construction. It checks the layer the tests actually assert on: every value a
// test reads (BRepCheck validity, closed-volume mass, face count, AddOptimal / Add boxes, poly
// HLR edge count, STEP file size) is recomputed here with the same OCCT calls and flags the
// bridge uses, on the SAME shapes, which the Swift side wrote to BREP (no triangulation) before
// measuring. Blanks are also rebuilt from BRepPrimAPI directly, as an independent input check.
//
//   probe brep <file.brep>...     valid / vol / faces / optimal box / box, per shape
//   probe hlr <file.brep> <defl>  HLRBRep_PolyAlgo VCompound edge count, as OCCTHLRPolyGetEdgesByCategory
//   probe step <out.step>         STEPControl_Writer AsIs AP214 of a 4x3x2 box, file size
//   probe prim                    BRepPrimAPI cylinders the tests use as blanks
//   probe meshcrest <file.brep> <defl>  max XY radius over BRepMesh nodes, as meshMaxRadialExtent
#include <BRepBndLib.hxx>
#include <BRepCheck_Analyzer.hxx>
#include <BRepGProp.hxx>
#include <BRepMesh_IncrementalMesh.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <BRepTools.hxx>
#include <BRep_Builder.hxx>
#include <BRep_Tool.hxx>
#include <Poly_Triangulation.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <cmath>
#include <Bnd_Box.hxx>
#include <GProp_GProps.hxx>
#include <HLRAlgo_Projector.hxx>
#include <HLRBRep_PolyAlgo.hxx>
#include <HLRBRep_PolyHLRToShape.hxx>
#include <Interface_Static.hxx>
#include <STEPControl_Writer.hxx>
#include <TopExp.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopoDS_Shape.hxx>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <string>
#include <sys/stat.h>

static void measure(const char* name, const TopoDS_Shape& s)
{
  GProp_GProps p;
  BRepGProp::VolumeProperties(s, p, true);
  TopTools_IndexedMapOfShape faces;
  TopExp::MapShapes(s, TopAbs_FACE, faces);
  Bnd_Box o, b;
  BRepBndLib::AddOptimal(s, o, true, false);
  BRepBndLib::Add(s, b, true);
  double a[6], c[6];
  o.Get(a[0], a[1], a[2], a[3], a[4], a[5]);
  b.Get(c[0], c[1], c[2], c[3], c[4], c[5]);
  printf("KERNEL %s valid=%s vol=%.9g faces=%d opt=%.9g,%.9g,%.9g,%.9g,%.9g,%.9g "
         "bounds=%.9g,%.9g,%.9g,%.9g,%.9g,%.9g\n",
         name,
         BRepCheck_Analyzer(s).IsValid() ? "true" : "false",
         p.Mass(),
         faces.Extent(),
         a[0], a[1], a[2], a[3], a[4], a[5],
         c[0], c[1], c[2], c[3], c[4], c[5]);
}

static TopoDS_Shape readBrep(const char* path)
{
  TopoDS_Shape s;
  BRep_Builder bb;
  BRepTools::Read(s, path, bb);
  return s;
}

int main(int argc, char** argv)
{
  if (argc < 2)
    return 2;
  if (!strcmp(argv[1], "brep"))
  {
    for (int i = 2; i < argc; i++)
    {
      std::string n = argv[i];
      n             = n.substr(n.find_last_of('/') + 1);
      n             = n.substr(0, n.size() - 5);
      TopoDS_Shape s = readBrep(argv[i]);
      if (s.IsNull())
        printf("KERNEL %s readfail\n", n.c_str());
      else
        measure(n.c_str(), s);
    }
  }
  else if (!strcmp(argv[1], "hlr"))
  {
    TopoDS_Shape             s    = readBrep(argv[2]);
    double                   defl = atof(argv[3]);
    BRepMesh_IncrementalMesh mesh(s, defl);
    HLRAlgo_Projector        proj(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(1, 0, 0)));
    Handle(HLRBRep_PolyAlgo) algo = new HLRBRep_PolyAlgo();
    algo->Load(s);
    algo->Projector(proj);
    algo->Update();
    HLRBRep_PolyHLRToShape toShape;
    toShape.Update(algo);
    TopTools_IndexedMapOfShape edges;
    TopExp::MapShapes(toShape.VCompound(), TopAbs_EDGE, edges);
    std::string n = argv[2];
    printf("KERNEL hlr %s defl=%g edges=%d\n",
           n.substr(n.find_last_of('/') + 1).c_str(), defl, edges.Extent());
  }
  else if (!strcmp(argv[1], "step"))
  {
    // Shape.box(width:height:depth:) is centred on the origin, so the same box here is placed
    // at (-2, -1.5, -1), not at BRepPrimAPI_MakeBox's default corner-at-origin.
    TopoDS_Shape       box = BRepPrimAPI_MakeBox(gp_Pnt(-2, -1.5, -1), 4, 3, 2).Shape();
    STEPControl_Writer w;
    Interface_Static::SetCVal("write.step.schema", "AP214");
    bool ok = w.Transfer(box, STEPControl_AsIs) == IFSelect_RetDone
              && w.Write(argv[2]) == IFSelect_RetDone;
    struct stat st;
    long        size = stat(argv[2], &st) == 0 ? (long)st.st_size : -1;
    printf("KERNEL step ok=%d size=%ld\n", ok, size);
  }
  else if (!strcmp(argv[1], "meshcrest"))
  {
    // OCCTShapeCreateMesh: BRepMesh_IncrementalMesh(shape, lin, relative=false, ang=0.5), then
    // every face triangulation's nodes through its location. The Swift mesh stores Float, so
    // the node is rounded to float before the radius is taken, as meshMaxRadialExtent sees it.
    TopoDS_Shape             s = readBrep(argv[2]);
    BRepMesh_IncrementalMesh mesh(s, atof(argv[3]), Standard_False, 0.5);
    mesh.Perform();
    double maxR = 0;
    for (TopExp_Explorer ex(s, TopAbs_FACE); ex.More(); ex.Next())
    {
      TopLoc_Location            loc;
      Handle(Poly_Triangulation) tri = BRep_Tool::Triangulation(TopoDS::Face(ex.Current()), loc);
      if (tri.IsNull())
        continue;
      for (int i = 1; i <= tri->NbNodes(); i++)
      {
        gp_Pnt p = tri->Node(i).Transformed(loc.Transformation());
        float  x = (float)p.X(), y = (float)p.Y();
        float  r = sqrtf(x * x + y * y);
        if (r > maxR)
          maxR = r;
      }
    }
    std::string n = argv[2];
    printf("KERNEL meshcrest %s defl=%g crest=%.9g\n",
           n.substr(n.find_last_of('/') + 1).c_str(), atof(argv[3]), maxR);
  }
  else if (!strcmp(argv[1], "prim"))
  {
    struct C
    {
      const char* n;
      double      r, h;
    } cyl[] = {{"181_blank", 6, 18},
               {"187_shank_6.0_1.0", 3, 22},
               {"187_shank_8.0_1.25", 4, 22},
               {"187_shank_10.0_1.5", 5, 22},
               {"187_shank_12.0_1.75", 6, 22},
               {"187_shank_12.0_3.14159", 6, 22},
               {"189_shank_6.0_1.0", 3, 25},
               {"189_shank_8.0_1.25", 4, 25},
               {"189_shank_10.0_1.5", 5, 25},
               {"189_shank_5.0_0.8", 2.5, 25},
               {"189_wshank", 6, 15},
               {"193_shank", 5, 50},
               {"213_shaft", 5, 20},
               {"222_rod", 6, 40}};
    for (auto& c : cyl)
      measure((std::string("prim_") + c.n).c_str(), BRepPrimAPI_MakeCylinder(c.r, c.h).Shape());
  }
  return 0;
}
