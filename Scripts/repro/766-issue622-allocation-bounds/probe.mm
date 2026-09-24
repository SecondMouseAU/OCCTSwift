// #766 / #1989: kernel-parity probe for Tests/OCCTMiscTests/Issue622AllocationBoundsTests.swift.
//
// Each #622 test clamps a caller's result-buffer capacity. The clamp itself is Swift-side
// (Sampling.capacity) and has no kernel counterpart, but the count the clamped call must return is
// the kernel's own, uncapped result count. This probe produces that count for every fixture with
// the OCCT call its bridge function makes, so a test's "clamped == baseline" can be read against
// the number the kernel actually finds.
//
// Build (from the repo root, against the SwiftPM-resolved pinned kernel):
//   X=.build/artifacts/<checkout>/OCCT/OCCT.xcframework/macos-arm64
//   clang++ -std=c++17 -ObjC++ -w -I"$X/Headers" -L"$X" -lOCCT-macos \
//     -framework Foundation -framework AppKit -lz -lc++ \
//     Scripts/repro/766-issue622-allocation-bounds/probe.mm -o /tmp/probe_766_622

#include <BRepExtrema_DistShapeShape.hxx>
#include <BRepExtrema_SelfIntersection.hxx>
#include <BRepMesh_IncrementalMesh.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeSphere.hxx>
#include <GC_MakeSegment.hxx>
#include <GCE2d_MakeSegment.hxx>
#include <Geom2dConvert.hxx>
#include <Geom2d_BSplineCurve.hxx>
#include <GeomAPI_ExtremaCurveCurve.hxx>
#include <GeomAPI_IntCS.hxx>
#include <GeomAPI_IntSS.hxx>
#include <GeomAPI_ProjectPointOnCurve.hxx>
#include <GeomAPI_ProjectPointOnSurf.hxx>
#include <GeomConvert.hxx>
#include <GeomLib_LogSample.hxx>
#include <Geom_BSplineCurve.hxx>
#include <Geom_Plane.hxx>
#include <IntCurvesFace_ShapeIntersector.hxx>
#include <NCollection_KDTree.hxx>
#include <OSD_FileIterator.hxx>
#include <OSD_DirectoryIterator.hxx>
#include <OSD_Path.hxx>
#include <Resource_Unicode.hxx>
#include <TCollection_ExtendedString.hxx>
#include <gp_Lin.hxx>
#include <cstdio>
#include <cstdlib>
#include <string>
#include <sys/stat.h>
#include <unistd.h>

int main()
{
  TopoDS_Shape box    = BRepPrimAPI_MakeBox(gp_Pnt(-5, -5, -5), 10, 10, 10).Shape();
  TopoDS_Shape sphere = BRepPrimAPI_MakeSphere(5).Shape();

  // raycastCapacity: OCCTShapeRaycast, a +Z-down ray at (0, 0, 20).
  {
    IntCurvesFace_ShapeIntersector it;
    it.Load(box, 1e-7);
    it.Perform(gp_Lin(gp_Pnt(0, 0, 20), gp_Dir(0, 0, -1)), -1e10, 1e10);
    std::printf("raycast box: NbPnt = %d\n", it.NbPnt());
  }
  // curve3DCapacities: OCCTCurve3DExtrema, OCCTCurve3DIntersectSurface, OCCTCurve3DSplitAtContinuity.
  Handle(Geom_Curve) a = GC_MakeSegment(gp_Pnt(0, 0, 0), gp_Pnt(10, 0, 0)).Value();
  {
    Handle(Geom_Curve)        b = GC_MakeSegment(gp_Pnt(5, -5, 1), gp_Pnt(5, 5, 1)).Value();
    GeomAPI_ExtremaCurveCurve e(a, b);
    std::printf("extrema skew segments: NbExtrema = %d\n", e.NbExtrema());
    Handle(Geom_Curve) through = GC_MakeSegment(gp_Pnt(0, 0, -20), gp_Pnt(0, 0, 20)).Value();
    GeomAPI_IntCS      ics(through, new Geom_Plane(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)));
    std::printf("segment x plane z=0: NbPoints = %d\n", ics.NbPoints());
    Handle(Geom_BSplineCurve) bsp = GeomConvert::CurveToBSplineCurve(a);
    std::printf("segment as BSpline: NbKnots = %d (one C0-free piece)\n", bsp->NbKnots());
  }
  // curve2DSplitCapacity
  {
    Handle(Geom2d_Curve)        c   = GCE2d_MakeSegment(gp_Pnt2d(0, 0), gp_Pnt2d(10, 0)).Value();
    Handle(Geom2d_BSplineCurve) bsp = Geom2dConvert::CurveToBSplineCurve(c);
    std::printf("2D segment as BSpline: NbKnots = %d\n", bsp->NbKnots());
  }
  // surfaceIntersectionCapacity: OCCTSurfaceIntersect, planes z = 0 and y = 0.
  {
    GeomAPI_IntSS iss(new Geom_Plane(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)),
                      new Geom_Plane(gp_Pnt(0, 0, 0), gp_Dir(0, 1, 0)),
                      1e-7);
    std::printf("plane z=0 x plane y=0: NbLines = %d\n", iss.NbLines());
  }
  // projectionCapacities: OCCTExtremaPointCurve, OCCTExtremaPointSurface.
  {
    GeomAPI_ProjectPointOnCurve pc(gp_Pnt(5, 5, 0), a);
    GeomAPI_ProjectPointOnSurf  ps(gp_Pnt(1, 1, 5), new Geom_Plane(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)));
    std::printf("project (5,5,0) on segment: NbPoints = %d\n", pc.NbPoints());
    std::printf("project (1,1,5) on plane: NbPoints = %d\n", ps.NbPoints());
  }
  // allDistanceSolutionsCapacity: OCCTShapeAllDistanceSolutions, box and sphere.
  {
    BRepExtrema_DistShapeShape d(box, sphere);
    std::printf("box to sphere: IsDone = %d, Value = %.12g, NbSolution = %d\n",
                d.IsDone() ? 1 : 0, d.Value(), d.NbSolution());
  }
  // selfIntersectionPairsCapacity: OCCTShapeSelfIntersectionPairs, box, deflection 0.1, tol 0.
  {
    BRepMesh_IncrementalMesh     mesh(box, 0.1);
    BRepExtrema_SelfIntersection si(box, 0.0);
    si.Perform();
    int pairs = 0;
    for (NCollection_DataMap<int, TColStd_PackedMapOfInteger>::Iterator it(si.OverlapElements());
         it.More(); it.Next())
      pairs += it.Value().Extent();
    std::printf("box self-intersection: overlap entries = %d\n", pairs);
  }
  // kdTreeCapacities: NCollection_KDTree over (0,0,0), (1,1,1), (2,2,2).
  {
    gp_Pnt                        pts[3] = {gp_Pnt(0, 0, 0), gp_Pnt(1, 1, 1), gp_Pnt(2, 2, 2)};
    NCollection_KDTree<gp_Pnt, 3> tree;
    tree.Build(pts, 3);
    NCollection_Array1<size_t> idx(1, 3);
    NCollection_Array1<double> dist(1, 3);
    std::printf("kd kNearest(k=3): %zu\n", tree.KNearestPoints(gp_Pnt(0, 0, 0), 3, idx, dist));
    std::printf("kd RangeSearch(r=10): %zu\n", (size_t)tree.RangeSearch(gp_Pnt(0, 0, 0), 10).Size());
    std::printf("kd BoxSearch(+-9): %zu\n",
                (size_t)tree.BoxSearch(gp_Pnt(-9, -9, -9), gp_Pnt(9, 9, 9)).Size());
  }
  // unicodeCapacity: OCCTUnicodeConvertFromUnicode("hello").
  {
    TCollection_ExtendedString s("hello", true);
    char                       buf[64] = {0};
    Standard_PCharacter        bufPtr  = buf;
    bool ok = Resource_Unicode::ConvertUnicodeToFormat(s, bufPtr, 64);
    std::printf("ConvertUnicodeToFormat(\"hello\") ok = %d, out = \"%s\"\n", ok ? 1 : 0, buf);
  }
  // listingCapacities: OCCTFileList / OCCTDirectoryList over a directory of seven files.
  {
    char tmpl[] = "/tmp/occt622-probe-XXXXXX";
    char* dir   = mkdtemp(tmpl);
    for (int i = 0; i < 7; i++)
    {
      std::string p = std::string(dir) + "/f" + std::to_string(i) + ".txt";
      FILE*       f = std::fopen(p.c_str(), "w");
      std::fputs("x", f);
      std::fclose(f);
    }
    int files = 0, dirs = 0;
    for (OSD_FileIterator it(OSD_Path(dir), "*"); it.More(); it.Next())
      files++;
    for (OSD_DirectoryIterator it(OSD_Path(dir), "*"); it.More(); it.Next())
      dirs++;
    std::printf("OSD_FileIterator: %d files, OSD_DirectoryIterator: %d directories\n", files, dirs);
    for (int i = 0; i < 7; i++)
      unlink((std::string(dir) + "/f" + std::to_string(i) + ".txt").c_str());
    rmdir(dir);
  }
  // logSampleIsARequest: OCCTLogSample, GeomLib_LogSample(1, 100, n).
  {
    GeomLib_LogSample s16(1, 100, 16), s1(1, 100, 1);
    std::printf("GeomLib_LogSample(1, 100, 16): NbPoints = %d, first = %.12g, last = %.12g\n",
                s16.NbPoints(), s16.GetParameter(1), s16.GetParameter(16));
    std::printf("GeomLib_LogSample(1, 100, 1): NbPoints = %d\n", s1.NbPoints());
  }
  return 0;
}
