// Ground truth for the presence predicates the tolerance and datum accessors need (#1004, second
// PR). `gdt_accessor_defaults.mm` establishes what an unset accessor answers; this one establishes
// which condition separates that from a real value, by writing each boundary case and reading it
// back off a real document rather than reasoning from XCAFDoc_*::SetObject's source.
//
// Build (from the repo root):
//   clang++ -std=c++17 -ObjC++ -w \
//     -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
//     -L"Libraries/OCCT.xcframework/macos-arm64" \
//     -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
//     Scripts/repro/1004-gdt-accessors/gdt_tolerance_datum_gates.mm -o /tmp/gdt_gates
//   /tmp/gdt_gates
//
// Four questions:
//
//   1. Is a datum's position 1-based, so that 0 is "no position in the frame"?
//   2. Does a zone modifier's value survive when it is 0, or is `> 0` the store condition?
//   3. Same for the maximum value modifier.
//   4. Which datum target types keep a length and a width?

#include <TDocStd_Application.hxx>
#include <TDocStd_Document.hxx>
#include <TDF_Label.hxx>
#include <XCAFDoc_DimTolTool.hxx>
#include <XCAFDoc_GeomTolerance.hxx>
#include <XCAFDoc_Datum.hxx>
#include <XCAFDoc_DocumentTool.hxx>
#include <XCAFDimTolObjects_GeomToleranceObject.hxx>
#include <XCAFDimTolObjects_DatumObject.hxx>
#include <TCollection_HAsciiString.hxx>
#include <gp_Ax2.hxx>
#include <gp_Dir.hxx>
#include <gp_Pnt.hxx>

#include <cstdio>

static Handle(XCAFDoc_DimTolTool) gTool;

// Write a tolerance with the given zone modifier / zone value / max value, read it back, print.
static void toleranceRoundTrip(const char*                                    tag,
                               XCAFDimTolObjects_GeomToleranceZoneModif       zoneModifier,
                               double                                         zoneValue,
                               double                                         maxValue)
{
  TDF_Label                     label = gTool->AddGeomTolerance();
  Handle(XCAFDoc_GeomTolerance) attr;
  label.FindAttribute(XCAFDoc_GeomTolerance::GetID(), attr);

  Handle(XCAFDimTolObjects_GeomToleranceObject) obj = new XCAFDimTolObjects_GeomToleranceObject();
  obj->SetType(XCAFDimTolObjects_GeomToleranceType_Position);
  obj->SetValue(0.1);
  obj->SetTypeOfValue(XCAFDimTolObjects_GeomToleranceTypeValue_None);
  obj->SetMaterialRequirementModifier(XCAFDimTolObjects_GeomToleranceMatReqModif_None);
  obj->SetZoneModifier(zoneModifier);
  obj->SetValueOfZoneModifier(zoneValue);
  obj->SetMaxValueModifier(maxValue);
  attr->SetObject(obj);

  Handle(XCAFDimTolObjects_GeomToleranceObject) back = attr->GetObject();
  printf("  %-34s wrote zoneModifier=%d zoneValue=%g maxValue=%g\n"
         "  %-34s read  zoneModifier=%d zoneValue=%g maxValue=%g\n",
         tag,
         (int)zoneModifier,
         zoneValue,
         maxValue,
         "",
         (int)back->GetZoneModifier(),
         back->GetValueOfZoneModifier(),
         back->GetMaxValueModifier());
}

static void datumPositionRoundTrip(int position)
{
  TDF_Label             label = gTool->AddDatum();
  Handle(XCAFDoc_Datum) attr;
  label.FindAttribute(XCAFDoc_Datum::GetID(), attr);

  Handle(XCAFDimTolObjects_DatumObject) obj = new XCAFDimTolObjects_DatumObject();
  obj->SetName(new TCollection_HAsciiString("A"));
  obj->SetModifierWithValue(XCAFDimTolObjects_DatumModifWithValue_None, 0.0);
  obj->SetPosition(position);
  attr->SetObject(obj);

  printf("  wrote position=%-3d  read position=%d\n", position, attr->GetObject()->GetPosition());
}

static const char* targetTypeName(XCAFDimTolObjects_DatumTargetType type)
{
  switch (type)
  {
    case XCAFDimTolObjects_DatumTargetType_Point:
      return "Point";
    case XCAFDimTolObjects_DatumTargetType_Line:
      return "Line";
    case XCAFDimTolObjects_DatumTargetType_Rectangle:
      return "Rectangle";
    case XCAFDimTolObjects_DatumTargetType_Circle:
      return "Circle";
    case XCAFDimTolObjects_DatumTargetType_Area:
      return "Area";
  }
  return "?";
}

static void datumTargetRoundTrip(XCAFDimTolObjects_DatumTargetType type)
{
  TDF_Label             label = gTool->AddDatum();
  Handle(XCAFDoc_Datum) attr;
  label.FindAttribute(XCAFDoc_Datum::GetID(), attr);

  Handle(XCAFDimTolObjects_DatumObject) obj = new XCAFDimTolObjects_DatumObject();
  obj->SetName(new TCollection_HAsciiString("B"));
  obj->SetPosition(1);
  obj->SetModifierWithValue(XCAFDimTolObjects_DatumModifWithValue_None, 0.0);
  obj->IsDatumTarget(true);
  obj->SetDatumTargetType(type);
  obj->SetDatumTargetNumber(4);
  obj->SetDatumTargetAxis(gp_Ax2(gp_Pnt(1, 2, 3), gp_Dir(0, 0, 1), gp_Dir(1, 0, 0)));
  // Asymmetric on purpose, so a length reported as a width is visible.
  obj->SetDatumTargetLength(30.0);
  obj->SetDatumTargetWidth(18.0);
  attr->SetObject(obj);

  Handle(XCAFDimTolObjects_DatumObject) back = attr->GetObject();
  printf("  %-10s wrote length=30 width=18  ->  read isTarget=%d hasParams=%d "
         "type=%s number=%d length=%g width=%g\n",
         targetTypeName(type),
         (int)back->IsDatumTarget(),
         (int)back->HasDatumTargetParams(),
         targetTypeName(back->GetDatumTargetType()),
         back->GetDatumTargetNumber(),
         back->GetDatumTargetLength(),
         back->GetDatumTargetWidth());
}

int main()
{
  Handle(TDocStd_Application) app = new TDocStd_Application();
  Handle(TDocStd_Document)    doc;
  app->NewDocument("BinXCAF", doc);
  XCAFDoc_DocumentTool::ShapeTool(doc->Main());
  gTool = XCAFDoc_DimTolTool::Set(doc->Main());

  printf("== 1: is a datum position 1-based, so 0 means no position? ==\n\n");
  datumPositionRoundTrip(0);
  datumPositionRoundTrip(1);
  datumPositionRoundTrip(3);
  printf("\n  STEPCAFControl_Reader.cxx:3676 declares its frame counter as `int aPositionCounter = 0`\n"
         "  and :3763 increments it BEFORE passing it at :3774, so the first datum of a reference\n"
         "  frame is written as position 1 and 0 is never assigned by an import. The round trip is\n"
         "  faithful in both directions, so 0 is a usable \"no position\" reading rather than a\n"
         "  value OCCT could have meant.\n");

  printf("\n== 2 and 3: do a zero zone value and a zero max value survive? ==\n\n");
  toleranceRoundTrip("zone=Projected value=15 max=0.25",
                     XCAFDimTolObjects_GeomToleranceZoneModif_Projected,
                     15.0,
                     0.25);
  toleranceRoundTrip("zone=Projected value=0  max=0",
                     XCAFDimTolObjects_GeomToleranceZoneModif_Projected,
                     0.0,
                     0.0);
  toleranceRoundTrip("zone=None      value=15 max=0.25",
                     XCAFDimTolObjects_GeomToleranceZoneModif_None,
                     15.0,
                     0.25);
  printf("\n  Read the second row carefully: the zeroes come back as zeroes, and that is NOT evidence\n"
         "  they were stored. XCAFDoc_GeomTolerance::SetObject writes the zone value only under\n"
         "  `> 0` and the max value only under `> 0`, so neither child label exists for that row;\n"
         "  GetObject then leaves both at the fresh object's own unassigned member, which reads 0.\n"
         "  A stored 0 and an unstored one are the same reading, which is exactly why `> 0` is the\n"
         "  presence test rather than an approximation of one, and why the Swift side reports nil\n"
         "  rather than 0. The zone MODIFIER is gated separately on `!= _None`: the third row keeps\n"
         "  its zone value with no modifier at all, which is what shows the two are independent.\n");

  printf("\n== 4: which datum target types keep a length and a width? ==\n\n");
  datumTargetRoundTrip(XCAFDimTolObjects_DatumTargetType_Point);
  datumTargetRoundTrip(XCAFDimTolObjects_DatumTargetType_Line);
  datumTargetRoundTrip(XCAFDimTolObjects_DatumTargetType_Rectangle);
  datumTargetRoundTrip(XCAFDimTolObjects_DatumTargetType_Circle);
  datumTargetRoundTrip(XCAFDimTolObjects_DatumTargetType_Area);
  printf("\n  One rule each, and both fall out of SetObject's own nesting. LENGTH is present when\n"
         "  HasDatumTargetParams() holds and the type is not Point. WIDTH is present when\n"
         "  HasDatumTargetParams() holds and the type is Rectangle. Area needs no separate clause:\n"
         "  SetObject takes the shape branch for it and never writes the axis, so GetObject never\n"
         "  calls SetDatumTargetAxis and HasDatumTargetParams() is false, as the row shows. Point\n"
         "  does have params (the axis is written) and simply has no length, which is why the type\n"
         "  test is needed on top of the predicate. A length or width read outside those two\n"
         "  combinations is the fresh object's unassigned member, not a measurement.\n");
  return 0;
}
