// Ground truth for #1004: what each unwrapped XCAFDimTolObjects accessor answers when nothing has
// set it, and which of them carry a presence predicate that can tell absence from a measured value.
//
// Build (from the repo root):
//   clang++ -std=c++17 -ObjC++ -w \
//     -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
//     -L"Libraries/OCCT.xcframework/macos-arm64" \
//     -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
//     Scripts/repro/1004-gdt-accessors/gdt_accessor_defaults.mm -o /tmp/gdt_accessor_defaults
//   /tmp/gdt_accessor_defaults
//
// Four parts.
//
// Part 1 poisons the heap and then default-constructs each of the three objects, because none of
// the three constructors initialises every member. Reading an accessor whose member the constructor
// skipped is indeterminate. Measured against this kernel and allocator the poison does NOT come
// through: every such member still reads 0. That is the useful result, not a failed experiment, and
// it is why the defect never shows up in ordinary use; the storage is still nobody's to rely on, so
// the bridge's create path assigns the neutral values rather than assuming this.
//
// Part 2 is the same three objects put on a real document through XCAFDoc_DimTolTool and read back,
// which is the path the bridge takes. SetObject/GetObject write a child label only for some fields,
// so a value that survives part 1 does not necessarily survive part 2.
//
// Part 3 sets every accessor under test and reads it back off the document, so each wrapped one has
// a measured round trip rather than a header comment behind it.
//
// Part 4 measures the three things that cannot be read off a header at all: the index base of the
// description arrays, whether GetDirection's bool ever reports absence, and what the "semantic
// name" of a dimension nobody named actually is.

#include <TDocStd_Application.hxx>
#include <TDocStd_Document.hxx>
#include <TDF_Label.hxx>
#include <TDF_LabelSequence.hxx>
#include <TColStd_HArray1OfReal.hxx>
#include <XCAFDoc_DimTolTool.hxx>
#include <XCAFDoc_Dimension.hxx>
#include <XCAFDoc_GeomTolerance.hxx>
#include <XCAFDoc_Datum.hxx>
#include <XCAFDoc_DocumentTool.hxx>
#include <XCAFDoc_ShapeTool.hxx>
#include <XCAFDimTolObjects_DimensionObject.hxx>
#include <XCAFDimTolObjects_GeomToleranceObject.hxx>
#include <XCAFDimTolObjects_DatumObject.hxx>
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <TCollection_HAsciiString.hxx>
#include <TopoDS_Edge.hxx>
#include <TopoDS_Shape.hxx>
#include <gp_Ax2.hxx>
#include <gp_Dir.hxx>
#include <gp_Pln.hxx>
#include <gp_Pnt.hxx>

#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <vector>

// Fill and free a run of blocks the size of the object about to be constructed, so the allocator has
// same-size storage on its free list with a non-zero pattern in it. Sized to the object rather than
// to a round number on purpose: malloc bins by size, so a 1024-byte poison never reaches the bin a
// ~400-byte object is served from, and the experiment would prove nothing while looking like it had.
static void poisonHeap(size_t objectSize)
{
  std::vector<void*> blocks;
  for (int i = 0; i < 4096; ++i)
  {
    void* p = malloc(objectSize);
    memset(p, 0xA5, objectSize);
    blocks.push_back(p);
  }
  for (void* p : blocks)
    free(p);
}

static const char* boolText(bool value)
{
  return value ? "true" : "false";
}

static void dumpDimension(const char* tag, const Handle(XCAFDimTolObjects_DimensionObject) & obj)
{
  int left = -1, right = -1;
  obj->GetNbOfDecimalPlaces(left, right);
  gp_Dir dir;
  bool   dirOk = obj->GetDirection(dir);
  printf("  %-14s qualifier=%d (Has=%s)  angularQualifier=%d (Has=%s)\n",
         tag,
         (int)obj->GetQualifier(),
         boolText(obj->HasQualifier()),
         (int)obj->GetAngularQualifier(),
         boolText(obj->HasAngularQualifier()));
  printf("  %-14s decimalPlaces=(%d,%d)  modifiers=%d  descriptions=%d (Has=%s)\n",
         "",
         left,
         right,
         obj->GetModifiers().Length(),
         obj->NbDescriptions(),
         boolText(obj->HasDescriptions()));
  printf("  %-14s path.IsNull=%s  direction=(%g,%g,%g) returned=%s\n",
         "",
         boolText(obj->GetPath().IsNull()),
         dir.X(),
         dir.Y(),
         dir.Z(),
         boolText(dirOk));
  printf("  %-14s HasPlane=%s HasTextPoint=%s HasPoint=%s HasPoint2=%s "
         "IsPointConnection=%s\n",
         "",
         boolText(obj->HasPlane()),
         boolText(obj->HasTextPoint()),
         boolText(obj->HasPoint()),
         boolText(obj->HasPoint2()),
         boolText(obj->IsPointConnection()));
  printf("  %-14s presentation.IsNull=%s  presentationName.IsNull=%s  semanticName=%s\n",
         "",
         boolText(obj->GetPresentation().IsNull()),
         boolText(obj->GetPresentationName().IsNull()),
         obj->GetSemanticName().IsNull() ? "(null)"
                                         : obj->GetSemanticName()->String().ToCString());
}

static void dumpTolerance(const char* tag, const Handle(XCAFDimTolObjects_GeomToleranceObject) & obj)
{
  printf("  %-14s typeOfValue=%d  matReq=%d  zoneModifier=%d  valueOfZoneModifier=%g\n",
         tag,
         (int)obj->GetTypeOfValue(),
         (int)obj->GetMaterialRequirementModifier(),
         (int)obj->GetZoneModifier(),
         obj->GetValueOfZoneModifier());
  printf("  %-14s maxValueModifier=%g  modifiers=%d\n",
         "",
         obj->GetMaxValueModifier(),
         obj->GetModifiers().Length());
  printf("  %-14s HasAxis=%s HasPlane=%s HasPoint=%s HasPointText=%s HasAffectedPlane=%s "
         "affectedPlaneType=%d\n",
         "",
         boolText(obj->HasAxis()),
         boolText(obj->HasPlane()),
         boolText(obj->HasPoint()),
         boolText(obj->HasPointText()),
         boolText(obj->HasAffectedPlane()),
         (int)obj->GetAffectedPlaneType());
  printf("  %-14s presentation.IsNull=%s  semanticName=%s\n",
         "",
         boolText(obj->GetPresentation().IsNull()),
         obj->GetSemanticName().IsNull() ? "(null)"
                                         : obj->GetSemanticName()->String().ToCString());
}

static void dumpDatum(const char* tag, const Handle(XCAFDimTolObjects_DatumObject) & obj)
{
  XCAFDimTolObjects_DatumModifWithValue modifier = XCAFDimTolObjects_DatumModifWithValue_None;
  double                                modifierValue = 0.0;
  obj->GetModifierWithValue(modifier, modifierValue);
  printf("  %-14s position=%d  modifiers=%d  modifierWithValue=%d/%g\n",
         tag,
         obj->GetPosition(),
         obj->GetModifiers().Length(),
         (int)modifier,
         modifierValue);
  printf("  %-14s IsDatumTarget=%s HasDatumTargetParams=%s targetType=%d targetNumber=%d\n",
         "",
         boolText(obj->IsDatumTarget()),
         boolText(obj->HasDatumTargetParams()),
         (int)obj->GetDatumTargetType(),
         obj->GetDatumTargetNumber());
  printf("  %-14s targetLength=%g targetWidth=%g target.IsNull=%s\n",
         "",
         obj->GetDatumTargetLength(),
         obj->GetDatumTargetWidth(),
         boolText(obj->GetDatumTarget().IsNull()));
  printf("  %-14s HasPlane=%s HasPoint=%s HasPointText=%s  presentation.IsNull=%s "
         "semanticName=%s\n",
         "",
         boolText(obj->HasPlane()),
         boolText(obj->HasPoint()),
         boolText(obj->HasPointText()),
         boolText(obj->GetPresentation().IsNull()),
         obj->GetSemanticName().IsNull() ? "(null)"
                                         : obj->GetSemanticName()->String().ToCString());
}

int main()
{
  printf("== part 1: default-constructed objects, on deliberately poisoned heap storage ==\n\n");
  printf("The three constructors set only these members:\n"
         "  DimensionObject:     myHasPlane, myHasPntText, myHasConnection1, myHasConnection2\n"
         "  GeomToleranceObject: myHasAxis, myHasPlane, myHasPnt, myHasPntText, "
         "myAffectedPlaneType\n"
         "  DatumObject:         myIsDTarget, myIsValidDT, myHasPlane, myHasPnt, myHasPntText\n"
         "Everything else below reads storage nobody wrote. Against this kernel and this allocator\n"
         "every such member happens to read back as 0, which is why the defect is invisible in\n"
         "ordinary use; it is still storage no constructor assigned, so the bridge's create path\n"
         "sets the neutral values explicitly rather than relying on it.\n\n");

  poisonHeap(sizeof(XCAFDimTolObjects_DimensionObject));
  Handle(XCAFDimTolObjects_DimensionObject) freshDim = new XCAFDimTolObjects_DimensionObject();
  dumpDimension("fresh dim", freshDim);
  printf("\n");

  poisonHeap(sizeof(XCAFDimTolObjects_GeomToleranceObject));
  Handle(XCAFDimTolObjects_GeomToleranceObject) freshTol =
    new XCAFDimTolObjects_GeomToleranceObject();
  dumpTolerance("fresh tol", freshTol);
  printf("\n");

  poisonHeap(sizeof(XCAFDimTolObjects_DatumObject));
  Handle(XCAFDimTolObjects_DatumObject) freshDatum = new XCAFDimTolObjects_DatumObject();
  dumpDatum("fresh datum", freshDatum);

  printf("\n== part 2: the bridge's own create path, read back off the document ==\n\n");
  printf("OCCTDocumentCreateDimension / CreateGeomTolerance / CreateDatum construct the object,\n"
         "set only type and value (or name), and call SetObject. Whatever part 1 reports is what\n"
         "SetObject reads out of those objects and stores.\n\n");

  Handle(TDocStd_Application) app = new TDocStd_Application();
  Handle(TDocStd_Document)    doc;
  app->NewDocument("BinXCAF", doc);
  Handle(XCAFDoc_ShapeTool)  shapeTool = XCAFDoc_DocumentTool::ShapeTool(doc->Main());
  Handle(XCAFDoc_DimTolTool) dimTol    = XCAFDoc_DimTolTool::Set(doc->Main());

  TopoDS_Shape box      = BRepPrimAPI_MakeBox(100.0, 50.0, 25.0).Shape();
  TDF_Label    boxLabel = shapeTool->AddShape(box);

  TDF_Label         dimLabel = dimTol->AddDimension();
  TDF_LabelSequence shapeSeq;
  shapeSeq.Append(boxLabel);
  dimTol->SetDimension(shapeSeq, shapeSeq, dimLabel);
  Handle(XCAFDoc_Dimension) dimAttr;
  dimLabel.FindAttribute(XCAFDoc_Dimension::GetID(), dimAttr);
  {
    poisonHeap(sizeof(XCAFDimTolObjects_DimensionObject));
    Handle(XCAFDimTolObjects_DimensionObject) obj = new XCAFDimTolObjects_DimensionObject();
    obj->SetType(XCAFDimTolObjects_DimensionType_Size_Diameter);
    Handle(TColStd_HArray1OfReal) vals = new TColStd_HArray1OfReal(1, 1);
    vals->SetValue(1, 20.0);
    obj->SetValues(vals);
    dimAttr->SetObject(obj);
  }
  dumpDimension("readback dim", dimAttr->GetObject());
  printf("\n");

  TDF_Label tolLabel = dimTol->AddGeomTolerance();
  dimTol->SetGeomTolerance(shapeSeq, tolLabel);
  Handle(XCAFDoc_GeomTolerance) tolAttr;
  tolLabel.FindAttribute(XCAFDoc_GeomTolerance::GetID(), tolAttr);
  {
    poisonHeap(sizeof(XCAFDimTolObjects_GeomToleranceObject));
    Handle(XCAFDimTolObjects_GeomToleranceObject) obj =
      new XCAFDimTolObjects_GeomToleranceObject();
    obj->SetType(XCAFDimTolObjects_GeomToleranceType_Flatness);
    obj->SetValue(0.05);
    tolAttr->SetObject(obj);
  }
  dumpTolerance("readback tol", tolAttr->GetObject());
  printf("\n");

  TDF_Label             datumLabel = dimTol->AddDatum();
  Handle(XCAFDoc_Datum) datumAttr;
  datumLabel.FindAttribute(XCAFDoc_Datum::GetID(), datumAttr);
  {
    poisonHeap(sizeof(XCAFDimTolObjects_DatumObject));
    Handle(XCAFDimTolObjects_DatumObject) obj = new XCAFDimTolObjects_DatumObject();
    obj->SetName(new TCollection_HAsciiString("A"));
    datumAttr->SetObject(obj);
  }
  dumpDatum("readback datum", datumAttr->GetObject());

  printf("\n== part 3: every accessor set, then read back off the document ==\n\n");

  TDF_Label                 fullDimLabel = dimTol->AddDimension();
  Handle(XCAFDoc_Dimension) fullDimAttr;
  dimTol->SetDimension(shapeSeq, shapeSeq, fullDimLabel);
  fullDimLabel.FindAttribute(XCAFDoc_Dimension::GetID(), fullDimAttr);
  TopoDS_Edge pathEdge = BRepBuilderAPI_MakeEdge(gp_Pnt(0, 0, 0), gp_Pnt(10, 0, 0)).Edge();
  {
    Handle(XCAFDimTolObjects_DimensionObject) obj = new XCAFDimTolObjects_DimensionObject();
    // Location_Oriented, because SetObject only stores the direction for that one type.
    obj->SetType(XCAFDimTolObjects_DimensionType_Location_Oriented);
    obj->SetValue(20.0);
    obj->SetQualifier(XCAFDimTolObjects_DimensionQualifier_Max);
    obj->SetAngularQualifier(XCAFDimTolObjects_AngularQualifier_Large);
    obj->SetNbOfDecimalPlaces(2, 3);
    obj->AddModifier(XCAFDimTolObjects_DimensionModif_Square);
    obj->AddModifier(XCAFDimTolObjects_DimensionModif_AnyCrossSection);
    obj->SetPath(pathEdge);
    obj->SetDirection(gp_Dir(0, 1, 0));
    obj->SetPlane(gp_Ax2(gp_Pnt(1, 2, 3), gp_Dir(0, 0, 1), gp_Dir(1, 0, 0)));
    obj->SetPointTextAttach(gp_Pnt(4, 5, 6));
    obj->SetPoint(gp_Pnt(7, 8, 9));
    obj->SetConnectionName(new TCollection_HAsciiString("start"));
    obj->SetConnectionAxis2(gp_Ax2(gp_Pnt(10, 11, 12), gp_Dir(1, 0, 0), gp_Dir(0, 1, 0)));
    obj->SetConnectionName2(new TCollection_HAsciiString("end"));
    obj->SetSemanticName(new TCollection_HAsciiString("dim-semantic"));
    obj->SetPresentation(box, new TCollection_HAsciiString("dim-presentation"));
    obj->AddDescription(new TCollection_HAsciiString("d0"), new TCollection_HAsciiString("n0"));
    obj->AddDescription(new TCollection_HAsciiString("d1"), new TCollection_HAsciiString("n1"));
    fullDimAttr->SetObject(obj);
  }
  {
    Handle(XCAFDimTolObjects_DimensionObject) obj = fullDimAttr->GetObject();
    dumpDimension("full dim", obj);
    gp_Dir dir;
    obj->GetDirection(dir);
    printf("  %-14s direction=(%g,%g,%g)  plane loc=(%g,%g,%g)  textPoint=(%g,%g,%g)\n",
           "",
           dir.X(),
           dir.Y(),
           dir.Z(),
           obj->GetPlane().Location().X(),
           obj->GetPlane().Location().Y(),
           obj->GetPlane().Location().Z(),
           obj->GetPointTextAttach().X(),
           obj->GetPointTextAttach().Y(),
           obj->GetPointTextAttach().Z());
    printf("  %-14s point=(%g,%g,%g) connectionName=%s  point2=(%g,%g,%g) "
           "isPointConnection2=%s connectionName2=%s\n",
           "",
           obj->GetPoint().X(),
           obj->GetPoint().Y(),
           obj->GetPoint().Z(),
           obj->GetConnectionName().IsNull() ? "(null)"
                                             : obj->GetConnectionName()->String().ToCString(),
           obj->GetPoint2().X(),
           obj->GetPoint2().Y(),
           obj->GetPoint2().Z(),
           boolText(obj->IsPointConnection2()),
           obj->GetConnectionName2().IsNull() ? "(null)"
                                              : obj->GetConnectionName2()->String().ToCString());
    printf("  %-14s semanticName=%s presentationName=%s\n",
           "",
           obj->GetSemanticName().IsNull() ? "(null)"
                                           : obj->GetSemanticName()->String().ToCString(),
           obj->GetPresentationName().IsNull()
             ? "(null)"
             : obj->GetPresentationName()->String().ToCString());
    for (int i = 0; i < obj->NbDescriptions(); ++i)
    {
      printf("  %-14s description[%d]=%s name=%s\n",
             "",
             i,
             obj->GetDescription(i)->String().ToCString(),
             obj->GetDescriptionName(i)->String().ToCString());
    }
    NCollection_Sequence<XCAFDimTolObjects_DimensionModif> modifiers = obj->GetModifiers();
    for (int i = 1; i <= modifiers.Length(); ++i)
      printf("  %-14s modifier[%d]=%d\n", "", i, (int)modifiers.Value(i));
  }
  printf("\n");

  TDF_Label                     fullTolLabel = dimTol->AddGeomTolerance();
  Handle(XCAFDoc_GeomTolerance) fullTolAttr;
  dimTol->SetGeomTolerance(shapeSeq, fullTolLabel);
  fullTolLabel.FindAttribute(XCAFDoc_GeomTolerance::GetID(), fullTolAttr);
  {
    Handle(XCAFDimTolObjects_GeomToleranceObject) obj =
      new XCAFDimTolObjects_GeomToleranceObject();
    obj->SetType(XCAFDimTolObjects_GeomToleranceType_Position);
    obj->SetValue(0.1);
    obj->SetTypeOfValue(XCAFDimTolObjects_GeomToleranceTypeValue_Diameter);
    obj->SetMaterialRequirementModifier(XCAFDimTolObjects_GeomToleranceMatReqModif_M);
    obj->SetZoneModifier(XCAFDimTolObjects_GeomToleranceZoneModif_Projected);
    obj->SetValueOfZoneModifier(15.0);
    obj->SetMaxValueModifier(0.25);
    obj->AddModifier(XCAFDimTolObjects_GeomToleranceModif_Free_State);
    obj->AddModifier(XCAFDimTolObjects_GeomToleranceModif_All_Around);
    obj->SetAxis(gp_Ax2(gp_Pnt(1, 1, 1), gp_Dir(0, 0, 1), gp_Dir(1, 0, 0)));
    obj->SetPlane(gp_Ax2(gp_Pnt(2, 2, 2), gp_Dir(0, 0, 1), gp_Dir(1, 0, 0)));
    obj->SetPoint(gp_Pnt(3, 3, 3));
    obj->SetPointTextAttach(gp_Pnt(4, 4, 4));
    obj->SetAffectedPlane(gp_Pln(gp_Pnt(5, 5, 5), gp_Dir(0, 1, 0)),
                          XCAFDimTolObjects_ToleranceZoneAffectedPlane_Orientation);
    obj->SetSemanticName(new TCollection_HAsciiString("tol-semantic"));
    obj->SetPresentation(box, new TCollection_HAsciiString("tol-presentation"));
    fullTolAttr->SetObject(obj);
  }
  {
    Handle(XCAFDimTolObjects_GeomToleranceObject) obj = fullTolAttr->GetObject();
    dumpTolerance("full tol", obj);
    printf("  %-14s axis loc=(%g,%g,%g) plane loc=(%g,%g,%g) point=(%g,%g,%g) "
           "textPoint=(%g,%g,%g)\n",
           "",
           obj->GetAxis().Location().X(),
           obj->GetAxis().Location().Y(),
           obj->GetAxis().Location().Z(),
           obj->GetPlane().Location().X(),
           obj->GetPlane().Location().Y(),
           obj->GetPlane().Location().Z(),
           obj->GetPoint().X(),
           obj->GetPoint().Y(),
           obj->GetPoint().Z(),
           obj->GetPointTextAttach().X(),
           obj->GetPointTextAttach().Y(),
           obj->GetPointTextAttach().Z());
    printf("  %-14s affectedPlane loc=(%g,%g,%g) axis=(%g,%g,%g)\n",
           "",
           obj->GetAffectedPlane().Location().X(),
           obj->GetAffectedPlane().Location().Y(),
           obj->GetAffectedPlane().Location().Z(),
           obj->GetAffectedPlane().Axis().Direction().X(),
           obj->GetAffectedPlane().Axis().Direction().Y(),
           obj->GetAffectedPlane().Axis().Direction().Z());
    printf("  %-14s semanticName=%s presentationName=%s\n",
           "",
           obj->GetSemanticName().IsNull() ? "(null)"
                                           : obj->GetSemanticName()->String().ToCString(),
           obj->GetPresentationName().IsNull()
             ? "(null)"
             : obj->GetPresentationName()->String().ToCString());
    NCollection_Sequence<XCAFDimTolObjects_GeomToleranceModif> modifiers = obj->GetModifiers();
    for (int i = 1; i <= modifiers.Length(); ++i)
      printf("  %-14s modifier[%d]=%d\n", "", i, (int)modifiers.Value(i));
  }
  printf("\n");

  TDF_Label             fullDatumLabel = dimTol->AddDatum();
  Handle(XCAFDoc_Datum) fullDatumAttr;
  fullDatumLabel.FindAttribute(XCAFDoc_Datum::GetID(), fullDatumAttr);
  {
    Handle(XCAFDimTolObjects_DatumObject) obj = new XCAFDimTolObjects_DatumObject();
    obj->SetName(new TCollection_HAsciiString("B"));
    obj->SetPosition(2);
    obj->AddModifier(XCAFDimTolObjects_DatumSingleModif_Basic);
    obj->AddModifier(XCAFDimTolObjects_DatumSingleModif_Translation);
    obj->SetModifierWithValue(XCAFDimTolObjects_DatumModifWithValue_Projected, 12.5);
    obj->IsDatumTarget(true);
    obj->SetDatumTargetType(XCAFDimTolObjects_DatumTargetType_Rectangle);
    obj->SetDatumTargetAxis(gp_Ax2(gp_Pnt(1, 2, 3), gp_Dir(0, 0, 1), gp_Dir(1, 0, 0)));
    obj->SetDatumTargetLength(30.0);
    obj->SetDatumTargetWidth(18.0);
    obj->SetDatumTargetNumber(4);
    obj->SetPlane(gp_Ax2(gp_Pnt(6, 6, 6), gp_Dir(0, 0, 1), gp_Dir(1, 0, 0)));
    obj->SetPoint(gp_Pnt(7, 7, 7));
    obj->SetPointTextAttach(gp_Pnt(8, 8, 8));
    obj->SetSemanticName(new TCollection_HAsciiString("datum-semantic"));
    obj->SetPresentation(box, new TCollection_HAsciiString("datum-presentation"));
    fullDatumAttr->SetObject(obj);
  }
  {
    Handle(XCAFDimTolObjects_DatumObject) obj = fullDatumAttr->GetObject();
    dumpDatum("full datum", obj);
    printf("  %-14s name=%s  targetAxis loc=(%g,%g,%g)\n",
           "",
           obj->GetName().IsNull() ? "(null)" : obj->GetName()->String().ToCString(),
           obj->GetDatumTargetAxis().Location().X(),
           obj->GetDatumTargetAxis().Location().Y(),
           obj->GetDatumTargetAxis().Location().Z());
    printf("  %-14s plane loc=(%g,%g,%g) point=(%g,%g,%g) textPoint=(%g,%g,%g)\n",
           "",
           obj->GetPlane().Location().X(),
           obj->GetPlane().Location().Y(),
           obj->GetPlane().Location().Z(),
           obj->GetPoint().X(),
           obj->GetPoint().Y(),
           obj->GetPoint().Z(),
           obj->GetPointTextAttach().X(),
           obj->GetPointTextAttach().Y(),
           obj->GetPointTextAttach().Z());
    printf("  %-14s semanticName=%s presentationName=%s\n",
           "",
           obj->GetSemanticName().IsNull() ? "(null)"
                                           : obj->GetSemanticName()->String().ToCString(),
           obj->GetPresentationName().IsNull()
             ? "(null)"
             : obj->GetPresentationName()->String().ToCString());
    NCollection_Sequence<XCAFDimTolObjects_DatumSingleModif> modifiers = obj->GetModifiers();
    for (int i = 1; i <= modifiers.Length(); ++i)
      printf("  %-14s modifier[%d]=%d\n", "", i, (int)modifiers.Value(i));
  }

  printf("\n== part 4: the three shapes no header states ==\n\n");
  {
    Handle(XCAFDimTolObjects_DimensionObject) obj = new XCAFDimTolObjects_DimensionObject();
    obj->AddDescription(new TCollection_HAsciiString("first"),
                        new TCollection_HAsciiString("firstName"));
    printf("  NbDescriptions=%d  GetDescription(0)=%s  GetDescription(1)=%s\n",
           obj->NbDescriptions(),
           obj->GetDescription(0)->String().ToCString(),
           obj->GetDescription(1)->String().ToCString());
    printf("  index base is 0: GetDescription(0) is the first entry and GetDescription(1) falls\n"
           "  outside the array, where the accessor answers an empty string rather than throwing.\n");
  }
  {
    Handle(XCAFDimTolObjects_DimensionObject) obj = new XCAFDimTolObjects_DimensionObject();
    gp_Dir dir(0, 0, 1);
    bool   returned = obj->GetDirection(dir);
    printf("\n  GetDirection on an object that never had one: returned=%s dir=(%g,%g,%g)\n",
           boolText(returned),
           dir.X(),
           dir.Y(),
           dir.Z());
    printf("  The bool is a constant true (XCAFDimTolObjects_DimensionObject.cxx:419-423 returns\n"
           "  true unconditionally), so it cannot report absence and the vector it writes is the\n"
           "  default-constructed gp_Dir rather than a stored one.\n");
  }
  printf("\n  Part 2's readback rows print the semantic name of a dimension, tolerance and datum\n"
         "  nobody ever named. Each reports the GD&T table's own marker string, because\n"
         "  XCAFDoc_DimTolTool::AddDimension/AddGeomTolerance/AddDatum set the label's TDataStd_Name\n"
         "  to \"DGT:Dimension\" / \"DGT:Tolerance\" / \"DGT:Datum\", and that is the same attribute\n"
         "  GetSemanticName reads. XCAFDoc_Dimension.cxx's setString helper also returns early on a\n"
         "  null handle, so the name cannot be cleared once set.\n");

  return 0;
}
