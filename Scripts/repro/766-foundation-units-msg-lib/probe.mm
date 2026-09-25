// #766 / #1987 kernel parity for the Foundation suites "Message_Msg", "OSD_SharedLibrary",
// "v0.114.0 - Named Color Count", "UnitsConversion" and "v0.127.0, ColorTool GetAllColors".
// Each section calls the OCCT API the bridge function named in its header calls, with the
// inputs the Swift test passes.
#include <Message_Msg.hxx>
#include <Message_MsgFile.hxx>
#include <ShapeExtend.hxx>
#include <OSD_SharedLibrary.hxx>
#include <Quantity_NameOfColor.hxx>
#include <UnitsMethods.hxx>
#include <UnitsMethods_LengthUnit.hxx>
#include <XCAFApp_Application.hxx>
#include <XCAFDoc_DocumentTool.hxx>
#include <XCAFDoc_ColorTool.hxx>
#include <TDocStd_Document.hxx>
#include <TDF_LabelSequence.hxx>
#include <TCollection_AsciiString.hxx>
#include <Quantity_Color.hxx>
#include <cstdio>

static void printMsg(const char* key)
{
  Message_Msg             msg(key);
  TCollection_AsciiString s(msg.Get());
  printf("Message_Msg(\"%s\").Get() = \"%s\"\n", key, s.ToCString());
}

int main()
{
  printf("== Message_Msg (OCCTMessageMsgGet / HasMsg / FileLoad / FileLoadDefault) ==\n");
  printMsg("test.key");
  printf("HasMsg(\"nonexistent.key.12345\") = %d\n",
         (int)Message_MsgFile::HasMsg(TCollection_AsciiString("nonexistent.key.12345")));
  printf("HasMsg(\"ShapeFix.FixSmallSolid.MSG0\") before ShapeExtend::Init = %d\n",
         (int)Message_MsgFile::HasMsg(TCollection_AsciiString("ShapeFix.FixSmallSolid.MSG0")));
  ShapeExtend::Init();
  printf("HasMsg(\"ShapeFix.FixSmallSolid.MSG0\") after ShapeExtend::Init = %d\n",
         (int)Message_MsgFile::HasMsg(TCollection_AsciiString("ShapeFix.FixSmallSolid.MSG0")));
  printMsg("ShapeFix.FixSmallSolid.MSG0");
  printf("LoadFile(\"/tmp/nonexistent_msg_file_12345.txt\") = %d\n",
         (int)Message_MsgFile::LoadFile("/tmp/nonexistent_msg_file_12345.txt"));

  printf("== OSD_SharedLibrary (OCCTSharedLibCreate / Name / Open / Close) ==\n");
  {
    OSD_SharedLibrary lib("libc.dylib");
    printf("Name() = \"%s\"\n", lib.Name());
    bool ok = lib.DlOpen(OSD_RTLD_LAZY);
    printf("DlOpen(OSD_RTLD_LAZY) libc.dylib = %d\n", (int)ok);
    lib.DlClose();
  }
  {
    OSD_SharedLibrary lib("nonexistent_lib_12345.dylib");
    printf("DlOpen(OSD_RTLD_LAZY) nonexistent_lib_12345.dylib = %d\n", (int)lib.DlOpen(OSD_RTLD_LAZY));
  }

  printf("== Named colour count (OCCTNamedColorCount) ==\n");
  printf("Quantity_NOC_WHITE + 1 = %d\n", (int)Quantity_NOC_WHITE + 1);
  printf("Quantity_Color::StringName(Quantity_NOC_WHITE) = %s\n",
         Quantity_Color::StringName(Quantity_NOC_WHITE));

  printf("== UnitsMethods (OCCTUnitsGetLengthFactor / GetLengthUnitScale / DumpLengthUnit) ==\n");
  printf("GetLengthFactorValue(6) = %.12g\n", UnitsMethods::GetLengthFactorValue(6));
  printf("GetLengthUnitScale(Meter, Millimeter) = %.12g\n",
         UnitsMethods::GetLengthUnitScale(UnitsMethods_LengthUnit_Meter,
                                          UnitsMethods_LengthUnit_Millimeter));
  printf("GetLengthUnitScale(Millimeter, Meter) = %.12g\n",
         UnitsMethods::GetLengthUnitScale(UnitsMethods_LengthUnit_Millimeter,
                                          UnitsMethods_LengthUnit_Meter));
  printf("DumpLengthUnit(Millimeter) = \"%s\"\n",
         UnitsMethods::DumpLengthUnit(UnitsMethods_LengthUnit_Millimeter));

  printf("== XCAFDoc_ColorTool (OCCTDocumentColorToolAddColor / GetAllColors) ==\n");
  Handle(XCAFApp_Application) app = XCAFApp_Application::GetApplication();
  {
    Handle(TDocStd_Document) doc;
    app->NewDocument("MDTV-XCAF", doc);
    Handle(XCAFDoc_ColorTool) tool = XCAFDoc_DocumentTool::ColorTool(doc->Main());
    TDF_LabelSequence         empty;
    tool->GetColors(empty);
    printf("new document GetColors count = %d\n", empty.Length());
    TDF_Label red   = tool->AddColor(Quantity_Color(1, 0, 0, Quantity_TOC_RGB));
    TDF_Label green = tool->AddColor(Quantity_Color(0, 1, 0, Quantity_TOC_RGB));
    TDF_LabelSequence all;
    tool->GetColors(all);
    printf("after AddColor red, green: GetColors count = %d, [1]==red %d, [2]==green %d\n",
           all.Length(),
           (int)all.Value(1).IsEqual(red),
           (int)all.Value(2).IsEqual(green));
    app->Close(doc);
  }
  return 0;
}
