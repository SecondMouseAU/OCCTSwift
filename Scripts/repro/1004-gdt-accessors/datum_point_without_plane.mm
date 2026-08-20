// XCAFDoc_Datum::GetObject reads the datum point's X coordinate out of the ANNOTATION PLANE's
// location array, found while wrapping the datum accessors for #1004.
//
// Build (from the repo root):
//   clang++ -std=c++17 -ObjC++ -w \
//     -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
//     -L"Libraries/OCCT.xcframework/macos-arm64" \
//     -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
//     Scripts/repro/1004-gdt-accessors/datum_point_without_plane.mm \
//     -o /tmp/datum_point_without_plane
//   /tmp/datum_point_without_plane
//
// XCAFDoc_Datum.cxx's GetObject, the ChildLab_Pnt block:
//
//     gp_Pnt aP(aLoc->Value(aPnt->Lower()),        // aLoc, not aPnt
//               aPnt->Value(aPnt->Lower() + 1),
//               aPnt->Value(aPnt->Lower() + 2));
//
// `aLoc` is the handle the ChildLab_PlaneLoc block above filled. Two consequences, and the second
// is the one that matters:
//
//   1. A datum with both a plane and a point reads its point's X from the plane's location, so
//      SetPoint(7,7,7) with SetPlane at (6,6,6) reads back as (6,7,7).
//   2. A datum with a point and NO plane leaves `aLoc` null, and `aLoc->Value(...)` dereferences
//      it. That is an OS signal, not a Standard_Failure, so the bridge's catch(...) cannot absorb
//      it, and it is reachable from Document.datums on any imported document whose datum carries a
//      point without an annotation plane.
//
// Part 2 is guarded behind argv[1] so the wrong-answer half can be run on its own.

#include <TDocStd_Application.hxx>
#include <TDocStd_Document.hxx>
#include <TDF_Label.hxx>
#include <XCAFDoc_DimTolTool.hxx>
#include <XCAFDoc_Datum.hxx>
#include <XCAFDoc_DocumentTool.hxx>
#include <XCAFDimTolObjects_DatumObject.hxx>
#include <TCollection_HAsciiString.hxx>
#include <gp_Ax2.hxx>
#include <gp_Dir.hxx>
#include <gp_Pnt.hxx>

#include <cstdio>
#include <cstring>

int main(int argc, const char** argv)
{
  Handle(TDocStd_Application) app = new TDocStd_Application();
  Handle(TDocStd_Document)    doc;
  app->NewDocument("BinXCAF", doc);
  Handle(XCAFDoc_DimTolTool) dimTol = XCAFDoc_DimTolTool::Set(doc->Main());

  printf("== part 1: a datum with BOTH a plane and a point ==\n");
  {
    TDF_Label             label = dimTol->AddDatum();
    Handle(XCAFDoc_Datum) attr;
    label.FindAttribute(XCAFDoc_Datum::GetID(), attr);

    Handle(XCAFDimTolObjects_DatumObject) obj = new XCAFDimTolObjects_DatumObject();
    obj->SetName(new TCollection_HAsciiString("A"));
    obj->SetPlane(gp_Ax2(gp_Pnt(6, 6, 6), gp_Dir(0, 0, 1), gp_Dir(1, 0, 0)));
    obj->SetPoint(gp_Pnt(7, 7, 7));
    attr->SetObject(obj);

    Handle(XCAFDimTolObjects_DatumObject) back = attr->GetObject();
    printf("  wrote plane loc (6,6,6) and point (7,7,7)\n");
    printf("  read  plane loc (%g,%g,%g) and point (%g,%g,%g)\n",
           back->GetPlane().Location().X(),
           back->GetPlane().Location().Y(),
           back->GetPlane().Location().Z(),
           back->GetPoint().X(),
           back->GetPoint().Y(),
           back->GetPoint().Z());
    printf("  the point's X is the plane's X, so a datum's stored point is not recoverable\n");
  }

  if (argc < 2 || strcmp(argv[1], "--crash") != 0)
  {
    printf("\n== part 2 skipped: re-run with --crash to take the null dereference ==\n");
    return 0;
  }

  printf("\n== part 2: a datum with a point and NO plane ==\n");
  {
    TDF_Label             label = dimTol->AddDatum();
    Handle(XCAFDoc_Datum) attr;
    label.FindAttribute(XCAFDoc_Datum::GetID(), attr);

    Handle(XCAFDimTolObjects_DatumObject) obj = new XCAFDimTolObjects_DatumObject();
    obj->SetName(new TCollection_HAsciiString("B"));
    obj->SetPoint(gp_Pnt(7, 7, 7));
    attr->SetObject(obj);

    printf("  about to call GetObject on a datum with a point and no plane\n");
    fflush(stdout);
    Handle(XCAFDimTolObjects_DatumObject) back = attr->GetObject();
    printf("  survived, point read back as (%g,%g,%g)\n",
           back->GetPoint().X(),
           back->GetPoint().Y(),
           back->GetPoint().Z());
  }
  return 0;
}
