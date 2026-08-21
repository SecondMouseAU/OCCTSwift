// #726 sub-kind 4 adjudication probe. Every candidate the new detector reports on this tree reads
// a value off a DEFAULT-CONSTRUCTED local. The detector cannot tell a subject whose default
// constructor populates itself (the process, the host, OCCT's own documented defaults) from one
// that stays empty forever (Draft_EdgeInfo, the #1000 defect), because both are spelled `T v;`.
// This is the measurement that separates them, per okf/policies/measure-dont-assume.md.
//
// Build (from the repo root, with Libraries/ present):
//
//   clang++ -std=c++17 -ObjC++ -w \
//     -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
//     -L"Libraries/OCCT.xcframework/macos-arm64" \
//     -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
//     Scripts/repro/726-unfed-subjects/probe_default_subjects.mm -o /tmp/probe_726
//   /tmp/probe_726
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <unistd.h>

#include <Draft_EdgeInfo.hxx>
#include <Draft_FaceInfo.hxx>
#include <Draft_VertexInfo.hxx>
#include <OSD_Directory.hxx>
#include <OSD_Host.hxx>
#include <OSD_MemInfo.hxx>
#include <OSD_Path.hxx>
#include <OSD_Process.hxx>
#include <Quantity_ColorRGBA.hxx>
#include <gp_Mat2d.hxx>
#include <XCAFDoc_VisMaterialCommon.hxx>
#include <XCAFDoc_VisMaterialPBR.hxx>
#include <XCAFPrs_Style.hxx>

int main()
{
  printf("=== subjects the detector flags, and what a default-constructed one reports ===\n\n");

  // OSD_MemInfo: does a fresh instance track THIS process, or answer a constant?
  {
    OSD_MemInfo before;
    Standard_Size b = before.Value(OSD_MemInfo::MemHeapUsage);
    const size_t  n = 64u * 1024u * 1024u;
    char*         block = (char*)malloc(n);
    memset(block, 7, n);
    OSD_MemInfo  after;
    Standard_Size a = after.Value(OSD_MemInfo::MemHeapUsage);
    printf("OSD_MemInfo heap usage   : before=%lu after 64MiB malloc=%lu  delta=%ld\n",
           (unsigned long)b, (unsigned long)a, (long)a - (long)b);
    printf("OSD_MemInfo MiB (precise): %f\n", after.ValuePreciseMiB(OSD_MemInfo::MemHeapUsage));
    printf("OSD_MemInfo working set  : %lu\n",
           (unsigned long)after.Value(OSD_MemInfo::MemWorkingSet));
    free(block);
  }

  // OSD_Process / OSD_Host: does a fresh instance know the real process and host?
  {
    OSD_Process p;
    printf("OSD_Process ProcessId    : %d   (getpid() = %d)\n", p.ProcessId(), (int)getpid());
    TCollection_AsciiString user = p.UserName();
    printf("OSD_Process UserName     : \"%s\"  (getenv USER = \"%s\")\n",
           user.ToCString(), getenv("USER") ? getenv("USER") : "");
    OSD_Path exe = p.CurrentDirectory();
    TCollection_AsciiString cwd;
    exe.SystemName(cwd);
    printf("OSD_Process CurrentDir   : \"%s\"\n", cwd.ToCString());

    OSD_Host h;
    printf("OSD_Host HostName        : \"%s\"\n", h.HostName().ToCString());
    printf("OSD_Host SystemVersion   : \"%s\"\n", h.SystemVersion().ToCString());
  }

  // OSD_Directory::BuildTemporary + Path + SystemName, OCCTDirectoryBuildTemporary's own chain.
  {
    OSD_Directory           tmpDir = OSD_Directory::BuildTemporary();
    OSD_Path                tmpPath;
    tmpDir.Path(tmpPath);
    TCollection_AsciiString sysName;
    tmpPath.SystemName(sysName);
    printf("OSD_Directory temporary  : \"%s\"\n", sysName.ToCString());
  }

  // OCCT's own documented defaults: the value IS the answer the API's own name promises.
  {
    XCAFDoc_VisMaterialCommon mat;
    printf("XCAFDoc_VisMaterialCommon default diffuse : %f %f %f  (header says 0.8 0.8 0.8)\n",
           mat.DiffuseColor.Red(), mat.DiffuseColor.Green(), mat.DiffuseColor.Blue());
    XCAFDoc_VisMaterialPBR pbr;
    printf("XCAFDoc_VisMaterialPBR default base color : %f %f %f\n",
           pbr.BaseColor.GetRGB().Red(), pbr.BaseColor.GetRGB().Green(),
           pbr.BaseColor.GetRGB().Blue());
    XCAFPrs_Style style;
    printf("XCAFPrs_Style default     : IsVisible=%d IsEmpty=%d\n",
           (int)style.IsVisible(), (int)style.IsEmpty());
    style.SetColorSurf(Quantity_ColorRGBA(Quantity_Color(1.0, 0.0, 0.0, Quantity_TOC_sRGB), 1.0f));
    printf("XCAFPrs_Style + surf color: IsVisible=%d IsEmpty=%d  (the flag moves)\n",
           (int)style.IsVisible(), (int)style.IsEmpty());

    // OCCTMat2dIdentity's subject: default-constructed, then SetIdentity(), which is the operation
    // the function is named for. Its sibling OCCTMat2dRotation(angle, mat) passes the caller's
    // angle into the same subject and is therefore never a candidate.
    gp_Mat2d m;
    m.SetIdentity();
    printf("gp_Mat2d after SetIdentity : %g %g %g %g\n",
           m.Value(1, 1), m.Value(1, 2), m.Value(2, 1), m.Value(2, 2));
  }

  printf("\n=== the #1000 subjects, for contrast ===\n\n");
  {
    for (int i = 0; i < 3; i++)
    {
      Draft_EdgeInfo ei;
      Draft_FaceInfo fi;
      Draft_VertexInfo vi;
      gp_Pnt           g = vi.Geometry();
      printf("run %d: Draft_EdgeInfo.NewGeometry=%d  Draft_FaceInfo.NewGeometry=%d  "
             "Draft_VertexInfo.Geometry=(%g, %g, %g)\n",
             i, (int)ei.NewGeometry(), (int)fi.NewGeometry(), g.X(), g.Y(), g.Z());
    }
    Draft_EdgeInfo ei;
    ei.SetNewGeometry(true);
    printf("Draft_EdgeInfo after SetNewGeometry(true): NewGeometry=%d  (the setter the deleted "
           "OCCTDraftEdgeInfoSetTangent called, with its three direction arguments unread)\n",
           (int)ei.NewGeometry());
  }
  return 0;
}
