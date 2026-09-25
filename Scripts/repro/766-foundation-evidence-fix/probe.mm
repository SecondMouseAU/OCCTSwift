// Epic #766, #1987 evidence-fix pass for OCCTFoundationTests. Kernel side of the 45 parity
// records whose bridge and kernel outputs were not like for like (three more, the out-of-range
// refusals and the maxSize clamp, have no kernel value and are N/A). Each line is
//   {"id": "<record id>", "data": {<same keys the Swift side observes>}}
// and calls the OCCT class the bridge function calls, with the flagged test's inputs. The Swift
// side is bridge-replay.swift.txt, which prints the same ids and keys to
// bridge-replay-transcript.jsonl; each record is built from the two by id.
#include <BRepBuilderAPI_MakePolygon.hxx>
#include <BRepMesh_IncrementalMesh.hxx>
#include <BRepOffsetAPI_ThruSections.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRep_Tool.hxx>
#include <Font_FontMgr.hxx>
#include <Font_SystemFont.hxx>
#include <Graphic3d_MaterialAspect.hxx>
#include <Graphic3d_PBRMaterial.hxx>
#include <Image_AlienPixMap.hxx>
#include <Message_Report.hxx>
#include <OSD_Chronometer.hxx>
#include <OSD_Disk.hxx>
#include <OSD_Environment.hxx>
#include <OSD_MemInfo.hxx>
#include <OSD_Timer.hxx>
#include <Poly_Triangulation.hxx>
#include <Quantity_Color.hxx>
#include <Quantity_ColorRGBA.hxx>
#include <Quantity_Date.hxx>
#include <Quantity_Period.hxx>
#include <Resource_Unicode.hxx>
#include <TCollection_AsciiString.hxx>
#include <TCollection_ExtendedString.hxx>
#include <TDF_LabelSequence.hxx>
#include <TDocStd_Document.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <UnitsAPI.hxx>
#include <XCAFApp_Application.hxx>
#include <XCAFDoc_ColorTool.hxx>
#include <XCAFDoc_DocumentTool.hxx>
#include <cmath>
#include <cstdio>
#include <cstring>
#include <sstream>
#include <string>
#include <sys/resource.h>
#include <sys/statvfs.h>
#include <unistd.h>
#include <vector>

static const char* B(bool v)
{
  return v ? "true" : "false";
}

static std::string dateString(const Quantity_Date& d)
{
  int  mm, dd, yy, hh, mn, ss, mis, mics;
  char buf[64];
  d.Values(mm, dd, yy, hh, mn, ss, mis, mics);
  snprintf(buf, sizeof buf, "%04d-%02d-%02d %02d:%02d:%02d", yy, mm, dd, hh, mn, ss);
  return buf;
}

static void materialFields(const Graphic3d_MaterialAspect& m, std::vector<double>& out)
{
  // The fields Material.PredefinedMaterial's == compares, read as fillMaterialProps reads them.
  const Graphic3d_PBRMaterial& p = m.PBRMaterial();
  for (const Quantity_Color& c : {m.AmbientColor(), m.DiffuseColor(), m.SpecularColor(), m.EmissiveColor()})
  {
    out.push_back(c.Red());
    out.push_back(c.Green());
    out.push_back(c.Blue());
  }
  out.push_back(m.Transparency());
  out.push_back(m.Shininess());
  out.push_back(m.RefractionIndex());
  out.push_back(m.MaterialType() == Graphic3d_MATERIAL_PHYSIC ? 1 : 0);
  out.push_back(p.Metallic());
  out.push_back(p.NormalizedRoughness());
  out.push_back(p.IOR());
  out.push_back(p.Alpha());
  NCollection_Vec3<float> em = p.Emission();
  out.push_back(em.x());
  out.push_back(em.y());
  out.push_back(em.z());
}

int main()
{
  // ---- #1078: Resource_Unicode under ANSI, 5000 x U+6F22
  {
    Resource_Unicode::SetFormat(Resource_FormatType_ANSI);
    std::string longStr;
    for (int i = 0; i < 5000; i++)
      longStr += "\xE6\xBC\xA2";
    TCollection_ExtendedString eStr(longStr.c_str(), true);
    std::vector<char>          buf(longStr.size() * 4 + 1);
    Standard_PCharacter        p = buf.data();
    bool                       ok = Resource_Unicode::ConvertUnicodeToFormat(eStr, p, (int)buf.size());
    int                        len = ok ? (int)strlen(buf.data()) : -1;
    printf("{\"id\":\"1078-short\",\"data\":{\"converted_length\":%d}}\n", len);
    printf("{\"id\":\"1078-swiftfull\",\"data\":{\"converted_length\":%d}}\n", len);
  }

  // ---- #1442: OSD_Disk(const char*) against statvfs
  {
    struct statvfs vfs;
    statvfs("/", &vfs);
    long long totalKB = (long long)((unsigned long long)vfs.f_blocks * (vfs.f_frsize / 512) / 2);
    long long freeKB  = (long long)((unsigned long long)vfs.f_bavail * (vfs.f_frsize / 512) / 2);
    OSD_Disk  root("/");
    long long size = (long long)root.DiskSize() / 2;
    long long fre  = (long long)root.DiskFree() / 2;
    bool      rootFailed = root.Failed();
    long long tol        = std::max(freeKB / 10, 1024LL);
    printf("{\"id\":\"1442-size\",\"data\":{\"size_kb\":%lld,\"statvfs_size_kb\":%lld}}\n", size, totalKB);
    printf("{\"id\":\"1442-free\",\"data\":{\"free_kb_within_tolerance_of_statvfs\":%s,\"free_kb\":%lld,"
           "\"statvfs_free_kb\":%lld}}\n",
           B(std::llabs(fre - freeKB) <= tol), fre, freeKB);
    printf("{\"id\":\"1442-valid-real\",\"data\":{\"valid\":%s}}\n", B(!rootFailed));
    OSD_Disk bogus("/this/path/does/not/exist/xyz123_555555");
    bogus.DiskSize();
    printf("{\"id\":\"1442-valid-bogus\",\"data\":{\"valid\":%s}}\n", B(!bogus.Failed()));
  }

  // ---- OCCT signal handling (#175): ThruSections over a square and a collinear polygon
  {
    BRepBuilderAPI_MakePolygon sq;
    sq.Add(gp_Pnt(0, 0, 0));
    sq.Add(gp_Pnt(10, 0, 0));
    sq.Add(gp_Pnt(10, 10, 0));
    sq.Add(gp_Pnt(0, 10, 0));
    sq.Close();
    BRepBuilderAPI_MakePolygon col;
    col.Add(gp_Pnt(0, 0, 5));
    col.Add(gp_Pnt(1, 0, 5));
    col.Add(gp_Pnt(2, 0, 5));
    col.Close();
    bool done = false;
    try
    {
      BRepOffsetAPI_ThruSections maker(Standard_True);
      maker.CheckCompatibility(Standard_True);
      maker.AddWire(sq.Wire());
      maker.AddWire(col.Wire());
      maker.Build();
      done = maker.IsDone();
    }
    catch (Standard_Failure&)
    {
      done = false;
    }
    TopoDS_Shape box = BRepPrimAPI_MakeBox(1, 1, 1).Shape();
    BRepMesh_IncrementalMesh(box, 0.01, Standard_False, 0.5);
    int tris = 0;
    for (TopExp_Explorer ex(box, TopAbs_FACE); ex.More(); ex.Next())
    {
      TopLoc_Location            loc;
      Handle(Poly_Triangulation) t = BRep_Tool::Triangulation(TopoDS::Face(ex.Current()), loc);
      if (!t.IsNull())
        tris += t->NbTriangles();
    }
    printf("{\"id\":\"signal-loft\",\"data\":{\"loft_is_nil\":%s,\"box_mesh_triangles\":%d}}\n", B(!done), tris);
  }

  // ---- Color OCCT Operations Tests: Quantity_Color / Quantity_ColorRGBA
  {
    Quantity_Color c;
    printf("{\"id\":\"color-fromNameInvalid\",\"data\":{\"found\":%s}}\n",
           B(Quantity_Color::ColorFromName("NOTACOLOR_XYZ", c)));
    printf("{\"id\":\"color-fromHexInvalid\",\"data\":{\"found\":%s}}\n", B(Quantity_Color::ColorFromHex("NOT_HEX", c)));
    Quantity_Color red(1, 0, 0, Quantity_TOC_RGB);
    printf("{\"id\":\"color-hls\",\"data\":{\"hue\":%.17g,\"lightness\":%.17g,\"saturation\":%.17g}}\n", red.Hue(),
           red.Light(), red.Saturation());
    Quantity_Color orig(0.4, 0.6, 0.2, Quantity_TOC_RGB);
    Quantity_Color rest(orig.Hue(), orig.Light(), orig.Saturation(), Quantity_TOC_HLS);
    printf("{\"id\":\"color-fromHLSRoundtrip\",\"data\":{\"restored_red\":%.17g,\"restored_green\":%.17g,"
           "\"restored_blue\":%.17g}}\n",
           rest.Red(), rest.Green(), rest.Blue());
    Quantity_Color gray(0.5, 0.5, 0.5, Quantity_TOC_RGB);
    Quantity_Color gi = gray;
    gi.ChangeIntensity(0.1);
    printf("{\"id\":\"color-changeIntensity\",\"data\":{\"red\":%.17g,\"green\":%.17g,\"blue\":%.17g}}\n", gi.Red(),
           gi.Green(), gi.Blue());
    NCollection_Vec3<float> half(0.5f, 0.5f, 0.5f);
    NCollection_Vec3<float> s = Quantity_Color::Convert_LinearRGB_To_sRGB(half);
    printf("{\"id\":\"color-linearToSRGB\",\"data\":{\"red\":%.9g,\"green\":%.9g,\"blue\":%.9g}}\n", s.r(), s.g(), s.b());
    NCollection_Vec3<float> l = Quantity_Color::Convert_sRGB_To_LinearRGB(half);
    printf("{\"id\":\"color-sRGBToLinear\",\"data\":{\"red\":%.9g,\"green\":%.9g,\"blue\":%.9g}}\n", l.r(), l.g(), l.b());
    NCollection_Vec3<float> o(0.3f, 0.6f, 0.9f);
    NCollection_Vec3<float> rt = Quantity_Color::Convert_sRGB_To_LinearRGB(Quantity_Color::Convert_LinearRGB_To_sRGB(o));
    printf("{\"id\":\"color-sRGBRoundtrip\",\"data\":{\"red\":%.9g,\"green\":%.9g,\"blue\":%.9g}}\n", rt.r(), rt.g(), rt.b());
    NCollection_Vec3<float> lab = Quantity_Color::Convert_LinearRGB_To_Lab(half);
    printf("{\"id\":\"color-toLab\",\"data\":{\"l\":%.9g,\"a\":%.9g,\"b\":%.9g}}\n", lab.x(), lab.y(), lab.z());
    printf("{\"id\":\"color-epsilon\",\"data\":{\"epsilon\":%.17g}}\n", Quantity_Color::Epsilon());
  }

  // ---- XCAFDoc_ColorTool::GetColors after two AddColor calls
  {
    Handle(XCAFApp_Application) app = XCAFApp_Application::GetApplication();
    Handle(TDocStd_Document)    doc;
    app->NewDocument("MDTV-XCAF", doc);
    Handle(XCAFDoc_ColorTool) tool  = XCAFDoc_DocumentTool::ColorTool(doc->Main());
    TDF_Label                 red   = tool->AddColor(Quantity_Color(1, 0, 0, Quantity_TOC_RGB));
    TDF_Label                 green = tool->AddColor(Quantity_Color(0, 1, 0, Quantity_TOC_RGB));
    TDF_LabelSequence         all;
    tool->GetColors(all);
    printf("{\"id\":\"colortool-getAllColors\",\"data\":{\"count\":%d,\"first_is_red\":%s,\"second_is_green\":%s}}\n",
           all.Length(), B(all.Length() > 0 && all.Value(1).IsEqual(red)),
           B(all.Length() > 1 && all.Value(2).IsEqual(green)));
    app->Close(doc);
  }

  // ---- Material OCCT Operations Tests: Graphic3d_MaterialAspect / Graphic3d_PBRMaterial
  {
    Graphic3d_NameOfMaterial nom;
    printf("{\"id\":\"material-byNameInvalid\",\"data\":{\"found\":%s}}\n",
           B(Graphic3d_MaterialAspect::MaterialFromName("NOT_A_MATERIAL_XYZ", nom)));
    Graphic3d_NameOfMaterial brassEnum;
    Graphic3d_MaterialAspect::MaterialFromName("Brass", brassEnum);
    // OCCTMaterialFromIndex(1) builds Graphic3d_NameOfMaterial(index - 1)
    Graphic3d_MaterialAspect byIndex((Graphic3d_NameOfMaterial)0);
    Graphic3d_MaterialAspect byName(brassEnum);
    std::vector<double>      fi, fn;
    materialFields(byIndex, fi);
    materialFields(byName, fn);
    printf("{\"id\":\"material-byIndex\",\"data\":{\"same_as_brass_by_name\":%s,\"shininess\":%.9g,"
           "\"pbr_normalized_roughness\":%.9g}}\n",
           B(fi == fn), byIndex.Shininess(), byIndex.PBRMaterial().NormalizedRoughness());
    Graphic3d_NameOfMaterial copperEnum;
    Graphic3d_MaterialAspect::MaterialFromName("Copper", copperEnum);
    Graphic3d_MaterialAspect copper(copperEnum);
    printf("{\"id\":\"material-pbr\",\"data\":{\"pbr_metallic\":%.9g,\"pbr_normalized_roughness\":%.9g,"
           "\"pbr_ior\":%.9g}}\n",
           copper.PBRMaterial().Metallic(), copper.PBRMaterial().NormalizedRoughness(), copper.PBRMaterial().IOR());
    printf("{\"id\":\"material-minRoughness\",\"data\":{\"min_roughness\":%.9g}}\n", Graphic3d_PBRMaterial::MinRoughness());
    Graphic3d_NameOfMaterial waterEnum;
    Graphic3d_MaterialAspect::MaterialFromName("Water", waterEnum);
    Graphic3d_MaterialAspect water(waterEnum);
    printf("{\"id\":\"material-water\",\"data\":{\"pbr_normalized_roughness\":%.9g,\"min_roughness\":%.9g}}\n",
           water.PBRMaterial().NormalizedRoughness(), Graphic3d_PBRMaterial::MinRoughness());
    printf("{\"id\":\"material-brass\",\"data\":{\"pbr_normalized_roughness\":%.9g}}\n",
           byName.PBRMaterial().NormalizedRoughness());
  }

  // ---- OCCTDate Tests: Quantity_Date / Quantity_Period
  {
    Quantity_Date   jan1(1, 1, 2000, 0, 0, 0, 0, 0);
    Quantity_Date   jan2(1, 2, 2000, 0, 0, 0, 0, 0);
    Quantity_Date   jan15(1, 15, 2000, 12, 0, 0, 0, 0);
    Quantity_Period oneDay(1, 0, 0, 0, 0, 0);
    Quantity_Period sixH(0, 6, 0, 0, 0, 0);
    Quantity_Period h24(0, 24, 0, 0, 0, 0);
    printf("{\"id\":\"date-addPeriod\",\"data\":{\"date\":\"%s\"}}\n", dateString(jan1 + oneDay).c_str());
    printf("{\"id\":\"date-subtractPeriod\",\"data\":{\"date\":\"%s\"}}\n", dateString(jan15 - sixH).c_str());
    printf("{\"id\":\"date-comparison\",\"data\":{\"d1_earlier_than_d2\":%s,\"d2_later_than_d1\":%s}}\n",
           B(jan1.IsEarlier(jan2)), B(jan2.IsLater(jan1)));
    printf("{\"id\":\"date-operatorPlus\",\"data\":{\"date\":\"%s\"}}\n", dateString(jan1 + h24).c_str());
    printf("{\"id\":\"date-invalid\",\"data\":{\"created\":%s}}\n", B(Quantity_Date::IsValid(0, 0, 1900, 0, 0, 0, 0, 0)));
  }

  // ---- FontManager Tests: Font_FontMgr
  {
    Handle(Font_FontMgr) mgr = Font_FontMgr::GetInstance();
    mgr->InitFontDataBase();
    NCollection_List<Handle(Font_SystemFont)> fonts = mgr->GetAvailableFonts();
    std::string                               names;
    std::string                               at0 = "null";
    std::string                               at999999 = "null";
    int                                       i = 0;
    for (auto it = fonts.cbegin(); it != fonts.cend(); ++it, ++i)
    {
      std::string q = std::string("\"") + (*it)->FontName().ToCString() + "\"";
      names += (i ? "," : "") + q;
      if (i == 0)
        at0 = q;
      if (i == 999999)
        at999999 = q;
    }
    printf("{\"id\":\"font-initDatabase\",\"data\":{\"font_count\":%d,\"font_names\":[%s]}}\n", fonts.Size(), names.c_str());
    printf("{\"id\":\"font-fontCount\",\"data\":{\"font_count\":%d,\"font_name_at_0\":%s}}\n", fonts.Size(), at0.c_str());
    printf("{\"id\":\"font-outOfRange\",\"data\":{\"found\":%s}}\n", B(at999999 != "null"));
  }

  // ---- PixMap Tests: Image_AlienPixMap
  {
    Handle(Image_AlienPixMap) px = new Image_AlienPixMap();
    px->InitTrash(Image_Format_RGBA, 4, 4);
    px->SetPixelColor(2, 2, Quantity_ColorRGBA(0.8f, 0.2f, 0.5f, 1.0f));
    Quantity_ColorRGBA got = px->PixelColor(2, 2);
    printf("{\"id\":\"pixmap-setAndGet\",\"data\":{\"red\":%.9g,\"green\":%.9g,\"blue\":%.9g,\"alpha\":%.9g}}\n",
           got.GetRGB().Red(), got.GetRGB().Green(), got.GetRGB().Blue(), (double)got.Alpha());
  }

  // ---- extras found by re-running the criteria over the whole file
  {
    Quantity_Color white(1, 1, 1, Quantity_TOC_RGB);
    printf("{\"id\":\"material-roughnessFromSpecular\",\"data\":{\"roughness\":%.9g}}\n",
           Graphic3d_PBRMaterial::RoughnessFromSpecular(white, 0.8));
    Quantity_Date epoch;
    printf("{\"id\":\"date-epoch\",\"data\":{\"date\":\"%s\"}}\n", dateString(epoch).c_str());
    Quantity_Date created(6, 15, 2000, 14, 30, 0, 0, 0);
    printf("{\"id\":\"date-createDate\",\"data\":{\"date\":\"%s\"}}\n", dateString(created).c_str());
    UnitsAPI::SetLocalSystem(UnitsAPI_MDTV);
    int afterMdtv = (int)UnitsAPI::LocalSystem();
    UnitsAPI::SetLocalSystem(UnitsAPI_SI);
    int afterSi = (int)UnitsAPI::LocalSystem();
    printf("{\"id\":\"units-localSystem\",\"data\":{\"after_set_mdtv\":%d,\"after_set_si\":%d}}\n", afterMdtv, afterSi);
  }

  // ---- UnitsAPI Tests
  printf("{\"id\":\"units-inchToMM\",\"data\":{\"value\":%.17g}}\n", UnitsAPI::AnyToAny(1.0, "in", "mm"));
  printf("{\"id\":\"units-degToRad\",\"data\":{\"value\":%.17g}}\n", UnitsAPI::AnyToAny(180.0, "deg", "rad"));

  // ---- OSD_Environment: Build / Value / Remove as OCCTEnvironmentSet / Get / Remove do
  {
    TCollection_AsciiString name("OCCT_SWIFT_TEST"), val("hello");
    OSD_Environment         setter(name, val);
    setter.Build();
    OSD_Environment         reader(name);
    TCollection_AsciiString after = reader.Value();
    OSD_Environment         remover(name);
    remover.Remove();
    OSD_Environment         reader2(name);
    printf("{\"id\":\"env-setGetRemove\",\"data\":{\"after_set\":\"%s\",\"after_remove_is_empty\":%s}}\n",
           after.ToCString(), B(reader2.Value().Length() == 0));
  }

  // ---- OSD_Chronometer::GetProcessCPU against getrusage
  {
    // The test burns CPU first; OSD_Chronometer reports 1/100 s steps, so burn until the process
    // has used at least 0.05 s of user time (a fresh probe process starts near 0.009 s).
    double sum = 0;
    for (;;)
    {
      for (int i = 0; i < 1000000; i++)
        sum += (double)i;
      struct rusage r;
      getrusage(RUSAGE_SELF, &r);
      if (r.ru_utime.tv_sec + r.ru_utime.tv_usec * 1e-6 >= 0.05)
        break;
    }
    struct rusage before, after;
    getrusage(RUSAGE_SELF, &before);
    double user = 0, sys = 0;
    OSD_Chronometer::GetProcessCPU(user, sys);
    getrusage(RUSAGE_SELF, &after);
    double lo = before.ru_utime.tv_sec + before.ru_utime.tv_usec * 1e-6;
    double hi = after.ru_utime.tv_sec + after.ru_utime.tv_usec * 1e-6;
    printf("{\"id\":\"cpu-processCPU\",\"data\":{\"user_cpu_positive\":%s,\"user_cpu_within_0_02_s_of_getrusage\":%s,"
           "\"user_cpu_s\":%.17g,\"getrusage_user_s_before\":%.17g,\"getrusage_user_s_after\":%.17g,\"sum\":%.17g}}\n",
           B(user > 0), B(user >= lo - 0.02 && user <= hi + 0.02), user, lo, hi, sum);
  }

  // ---- Message_Report::Dump of an empty report
  {
    Message_Report     rep;
    std::ostringstream oss;
    rep.Dump(oss);
    printf("{\"id\":\"report-dump\",\"data\":{\"dump_byte_count\":%zu}}\n", oss.str().size());
  }

  // ---- OSD_Timer over a 50 ms sleep, and GetWallClockTime
  {
    OSD_Timer timer;
    timer.Start();
    usleep(50000);
    timer.Stop();
    double el = timer.ElapsedTime();
    printf("{\"id\":\"timer-basicTiming\",\"data\":{\"elapsed_at_least_0_04_s\":%s,\"elapsed_under_5_s\":%s,"
           "\"elapsed_s\":%.17g}}\n",
           B(el >= 0.04), B(el < 5), el);
    double t0 = OSD_Timer::GetWallClockTime();
    usleep(50000);
    double t1 = OSD_Timer::GetWallClockTime();
    printf("{\"id\":\"timer-wallClockTime\",\"data\":{\"wall_clock_positive\":%s,\"advance_at_least_0_04_s\":%s,"
           "\"advance_under_5_s\":%s,\"t0\":%.17g,\"advance_s\":%.17g}}\n",
           B(t0 > 0), B(t1 - t0 >= 0.04), B(t1 - t0 < 5), t0, t1 - t0);
  }

  // ---- OSD_MemInfo: Value(MemHeapUsage) bytes against ValuePreciseMiB
  {
    OSD_MemInfo a(true);
    double      before = (double)a.Value(OSD_MemInfo::MemHeapUsage) / 1048576.0;
    OSD_MemInfo m(true);
    double      mib = m.ValuePreciseMiB(OSD_MemInfo::MemHeapUsage);
    OSD_MemInfo c(true);
    double      afterMem = (double)c.Value(OSD_MemInfo::MemHeapUsage) / 1048576.0;
    printf("{\"id\":\"meminfo-heapUsageMiB\",\"data\":{\"mib_positive\":%s,"
           "\"mib_within_25_percent_of_bytes_over_2_20\":%s,\"mib\":%.17g,\"bytes_over_2_20_before\":%.17g,"
           "\"bytes_over_2_20_after\":%.17g}}\n",
           B(mib > 0), B(mib >= std::min(before, afterMem) * 0.75 && mib <= std::max(before, afterMem) * 1.25), mib,
           before, afterMem);
  }
  return 0;
}
