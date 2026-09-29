// #2801 sweep: two out-of-line index guards the pinned kernel compiles out, both reached from a
// documented public Swift API that takes a 1-based index and bound-checks it nowhere.
//
// 1. Intf_Tool::BeginParam / EndParam (Intf_Tool.cxx:1641,1649)
//      Standard_OutOfRange_Raise_if(SegmentNum < 1 || SegmentNum > nbSeg, ...)
//      return beginOnCurve[SegmentNum - 1];        // beginOnCurve is a raw double[6]
//    No container sits under it, so nothing checks the index at any depth.
//    Swift: IntfTool.beginParam(segment:) / .endParam(segment:), which do not expose
//    Intf_Tool::NbSegments() at all, so a caller has no way to learn the valid range.
//
// 2. BRepBuilderAPI_Sewing::DeletedFace (BRepBuilderAPI_Sewing.cxx:2441)
//      Standard_OutOfRange_Raise_if(index < 0 || index > NbDeletedFaces(), ...)
//      return TopoDS::Face(myLittleFace(index));   // NCollection_IndexedMap, 1-based
//    myLittleFace(index) -> FindKey(size_t) whose own inline Standard_OutOfRange_Raise_if is
//    expanded inside BRepBuilderAPI_Sewing.cxx, an OCCT TU compiled -DNo_Exception, so it is
//    compiled out at that depth too.  Note the kernel guard permits index 0, which FindKey
//    explicitly rejects, so index 0 is a defect even with the checks ON.
//    Swift: SewingBuilder.deletedFace(at:).  The sibling multipleEdge(at:) DOES bound-check.
//
// Build/run: see run.sh.  Each mode must run in its own process; a fault is the result.

#include <Intf_Tool.hxx>
#include <gp_Lin.hxx>
#include <gp_Pnt.hxx>
#include <gp_Dir.hxx>
#include <Bnd_Box.hxx>
#include <BRepBuilderAPI_Sewing.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Face.hxx>
#include <TopExp_Explorer.hxx>

#include <cstdio>
#include <cstdlib>

static void reportIntf(Intf_Tool& t, int idx, const char* what)
{
  printf("  %s(%d) ... ", what, idx);
  fflush(stdout);
  double v = (what[0] == 'B') ? t.BeginParam(idx) : t.EndParam(idx);
  printf("returned %g\n", v);
  fflush(stdout);
}

int main(int argc, char** argv)
{
  int mode = (argc > 1) ? atoi(argv[1]) : 0;
  printf("mode %d\n", mode);
  fflush(stdout);

  if (mode >= 0 && mode <= 7)
  {
    Intf_Tool t;
    // A real clip, so nbSeg is whatever OCCT computed rather than the ctor's 0.
    gp_Lin  line(gp_Pnt(-10, 0.5, 0.5), gp_Dir(1, 0, 0));
    Bnd_Box box;
    box.Update(0, 0, 0, 1, 1, 1);
    Bnd_Box outBox;
    t.LinBox(line, box, outBox);
    printf("  NbSegments()=%d  (beginOnCurve is double[6])\n", t.NbSegments());
    fflush(stdout);

    switch (mode)
    {
      case 0:  // baseline: the one valid index
        reportIntf(t, 1, "BeginParam");
        reportIntf(t, 1, "EndParam");
        break;
      case 1:  // one past nbSeg but still inside the double[6]: adjacent member read
        reportIntf(t, 6, "BeginParam");
        break;
      case 2:  // past the end of the array: reads endOnCurve / bord
        reportIntf(t, 7, "BeginParam");
        break;
      case 3:  // index 0 -> beginOnCurve[-1]
        reportIntf(t, 0, "BeginParam");
        break;
      case 4:  // far out of range -> raw OOB read well past the object
        reportIntf(t, 100000000, "BeginParam");
        break;
      case 5:  // further still
        reportIntf(t, 1000000000, "BeginParam");
        break;
      case 6:  // large negative: reads far BELOW the object
        reportIntf(t, -1000000000, "BeginParam");
        break;
      case 7:  // INT_MIN + 1: SegmentNum - 1 is itself a signed overflow
        reportIntf(t, -2147483647, "BeginParam");
        break;
    }
    printf("mode %d survived\n", mode);
    fflush(stdout);
    return 0;
  }

  if (mode >= 10 && mode <= 13)
  {
    // A sewing that deletes no face at all, so NbDeletedFaces() == 0 and every index is invalid.
    BRepBuilderAPI_Sewing sew(1.0e-6);
    TopoDS_Shape          box = BRepPrimAPI_MakeBox(1.0, 1.0, 1.0).Shape();
    for (TopExp_Explorer ex(box, TopAbs_FACE); ex.More(); ex.Next())
      sew.Add(ex.Current());
    sew.Perform();
    printf("  NbDeletedFaces()=%d\n", sew.NbDeletedFaces());
    fflush(stdout);

    int idx = 0;
    switch (mode)
    {
      case 10: idx = 0; break;          // the value the kernel guard would have PERMITTED
      case 11: idx = 1; break;          // 1-based first element of an empty map
      case 12: idx = 1000; break;
      case 13: idx = -1; break;         // int -1 -> size_t 0xFFFF... inside FindKey
    }
    printf("  DeletedFace(%d) ... ", idx);
    fflush(stdout);
    const TopoDS_Face& f = sew.DeletedFace(idx);
    printf("returned, IsNull=%d\n", (int)f.IsNull());
    fflush(stdout);
    printf("mode %d survived\n", mode);
    fflush(stdout);
    return 0;
  }

  printf("unknown mode\n");
  return 2;
}
