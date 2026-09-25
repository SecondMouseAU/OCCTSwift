// Kernel-parity probe for #766 (OCCTXCAFTests). Calls the OCCT API the bridge calls, with the
// test's inputs, and prints what the kernel returns. Build line: CLAUDE.md "Compile a Ground
// Truth C++ Test", headers/lib from the pinned OCCT.xcframework.
#include <BRepPrimAPI_MakeBox.hxx>
#include <TDocStd_Application.hxx>
#include <TDocStd_Document.hxx>
#include <TDF_Label.hxx>
#include <TDF_LabelSequence.hxx>
#include <TDF_Tool.hxx>
#include <TCollection_AsciiString.hxx>
#include <TCollection_ExtendedString.hxx>
#include <XCAFDoc_DocumentTool.hxx>
#include <XCAFDoc_ShapeTool.hxx>
#include <XCAFDoc_ColorTool.hxx>
#include <XCAFDoc_VisMaterialTool.hxx>
#include <TopoDS_Shape.hxx>
#include <cstdio>

// OCCTDocument(): a private TDocStd_Application (#371), NewDocument("MDTV-XCAF"), then the three
// XCAF tools occtDocumentInit fetches.
static Handle(TDocStd_Document) newDoc(Handle(TDocStd_Application)& app)
{
  app = new TDocStd_Application();
  Handle(TDocStd_Document) d;
  app->NewDocument("MDTV-XCAF", d);
  XCAFDoc_DocumentTool::ShapeTool(d->Main());
  XCAFDoc_DocumentTool::ColorTool(d->Main());
  XCAFDoc_DocumentTool::VisMaterialTool(d->Main());
  return d;
}

// getLabelForTag: tag 0 is Main, otherwise Main().FindChild(tag, create).
static TDF_Label tagLabel(const Handle(TDocStd_Document)& d, int tag)
{
  return tag == 0 ? d->Main() : d->Main().FindChild(tag, Standard_True);
}

// OCCTShapeCreateBox: centred on the origin.
static TopoDS_Shape centredBox(double w, double h, double dp)
{
  return BRepPrimAPI_MakeBox(gp_Pnt(-w / 2, -h / 2, -dp / 2), w, h, dp).Shape();
}

static const char* tf(bool b) { return b ? "true" : "false"; }

#include <AIS_TextLabel.hxx>
#include <Graphic3d_PBRMaterial.hxx>
#include <RWObj_CafReader.hxx>
#include <Message_ProgressRange.hxx>
#include <Standard_GUID.hxx>
#include <Standard_OutOfRange.hxx>
#include <TFunction_Function.hxx>
#include <TFunction_IFunction.hxx>
#include <TFunction_Scope.hxx>
#include <XCAFDoc_AssemblyItemId.hxx>
#include <XCAFDoc_AssemblyItemRef.hxx>
#include <XCAFDoc_DimTol.hxx>
#include <XCAFDoc_Location.hxx>
#include <XCAFDoc_Material.hxx>
#include <XCAFDoc_VisMaterial.hxx>
#include <XCAFDoc_VisMaterialCommon.hxx>
#include <XCAFDoc_VisMaterialPBR.hxx>
#include <XCAFDoc_VisMaterialTool.hxx>
#include <fstream>
#include <BRepPrimAPI_MakeBox.hxx>
#include <Interface_Static.hxx>
#include <STEPCAFControl_Reader.hxx>
#include <STEPControl_Writer.hxx>
#include <TColStd_HArray1OfReal.hxx>
#include <TCollection_HAsciiString.hxx>
#include <TDataStd_Name.hxx>
#include <XCAFDimTolObjects_DatumObject.hxx>
#include <XCAFDimTolObjects_DimensionObject.hxx>
#include <XCAFDimTolObjects_DimensionType.hxx>
#include <XCAFDimTolObjects_GeomToleranceObject.hxx>
#include <XCAFDimTolObjects_GeomToleranceType.hxx>
#include <XCAFDoc_Datum.hxx>
#include <XCAFDoc_DimTolTool.hxx>
#include <XCAFDoc_Dimension.hxx>
#include <XCAFDoc_GeomTolerance.hxx>
#include <algorithm>
#include <string>
#include <vector>
#include <Standard_ConstructionError.hxx>
#include <XCAFDimTolObjects_DatumModifWithValue.hxx>
#include <XCAFDimTolObjects_DatumTargetType.hxx>
#include <XCAFDimTolObjects_DimensionModif.hxx>
#include <XCAFDimTolObjects_DimensionQualifier.hxx>
#include <XCAFDimTolObjects_GeomToleranceModif.hxx>
#include <XCAFDimTolObjects_GeomToleranceTypeValue.hxx>
#include <XCAFDoc_LayerTool.hxx>
#include <gp_Ax2.hxx>
#include <XCAFDimTolObjects_DatumSingleModif.hxx>
#include <XCAFDimTolObjects_DimensionFormVariance.hxx>
#include <XCAFDimTolObjects_DimensionGrade.hxx>

// Kernel measurements for the #1982 evidence correction pass over OCCTXCAFTests. Each section prints lines
// tagged with the worklist index ([n]) of the parity record it backs, so a record's kernel value can be
// traced to a line of transcript.txt. Every section calls the OCCT API the bridge function calls.

static const char* ascii(const TCollection_ExtendedString& e)
{
  static TCollection_AsciiString s;
  s = TCollection_AsciiString(e);
  return s.ToCString();
}

// ---- NA_FALSE group ------------------------------------------------------------------------------
// [159]-[162] TextLabelAndPointCloudTests: OCCTTextLabelCreate / GetInfo / SetText / SetPosition wrap an
// AIS_TextLabel (SetText, SetPosition, Text, Position).
static void textLabel()
{
  Handle(AIS_TextLabel) a = new AIS_TextLabel();
  a->SetText(TCollection_ExtendedString("Hello", Standard_True));
  a->SetPosition(gp_Pnt(1, 2, 3));
  printf("[159] AIS_TextLabel SetText(\"Hello\") Text=\"%s\"\n", ascii(a->Text()));
  Handle(AIS_TextLabel) b = new AIS_TextLabel();
  b->SetText(TCollection_ExtendedString("Test", Standard_True));
  b->SetPosition(gp_Pnt(10, 20, 30));
  printf("[160] AIS_TextLabel SetPosition(10, 20, 30) Position=(%.17g, %.17g, %.17g)\n", b->Position().X(), b->Position().Y(),
         b->Position().Z());
  Handle(AIS_TextLabel) c = new AIS_TextLabel();
  c->SetText(TCollection_ExtendedString("Original", Standard_True));
  c->SetText(TCollection_ExtendedString("Updated", Standard_True));
  printf("[161] AIS_TextLabel SetText(\"Original\") then SetText(\"Updated\") Text=\"%s\"\n", ascii(c->Text()));
  Handle(AIS_TextLabel) d = new AIS_TextLabel();
  d->SetText(TCollection_ExtendedString("Test", Standard_True));
  d->SetPosition(gp_Pnt(0, 0, 0));
  d->SetPosition(gp_Pnt(5, 10, 15));
  printf("[162] AIS_TextLabel SetPosition(0, 0, 0) then SetPosition(5, 10, 15) Position=(%.17g, %.17g, %.17g)\n", d->Position().X(),
         d->Position().Y(), d->Position().Z());
}

// [137] VisMaterialPBRTests.equality: two PBR materials with the same fields, XCAFDoc_VisMaterialPBR::IsEqual.
static void pbrEquality()
{
  XCAFDoc_VisMaterialPBR pa, pb;
  pa.BaseColor = Quantity_ColorRGBA(Quantity_Color(0.8, 0.2, 0.1, Quantity_TOC_sRGB), 1.0f);
  pa.Metallic  = 0.0f;
  pa.Roughness = 0.5f;
  pb.BaseColor = Quantity_ColorRGBA(Quantity_Color(0.8, 0.2, 0.1, Quantity_TOC_sRGB), 1.0f);
  pb.Metallic  = 0.0f;
  pb.Roughness = 0.5f;
  printf("[137] XCAFDoc_VisMaterialPBR same fields (metallic 0, roughness 0.5, base colour 0.8/0.2/0.1): IsEqual=%s\n",
         tf(pa.IsEqual(pb)));
}

// [142] XCAFDocAssemblyItemRefTests.isOrphan: a ref set on a fresh label to a path that names no label.
static void itemRefOrphan()
{
  Handle(TDocStd_Application) app;
  Handle(TDocStd_Document)    d     = newDoc(app);
  TDF_Label                   label = d->Main().NewChild();
  XCAFDoc_AssemblyItemId      id(TCollection_AsciiString("/99:99:99"));
  Handle(XCAFDoc_AssemblyItemRef) ref = XCAFDoc_AssemblyItemRef::Set(label, id);
  printf("[142] XCAFDoc_AssemblyItemRef::Set(label, \"/99:99:99\") non-null=%s IsOrphan=%s\n", tf(!ref.IsNull()), tf(ref->IsOrphan()));
}

// [171]-[174] TFunctionIFunctionTests: TFunction_IFunction on a fresh child label of Main().
static void iFunction()
{
  Handle(TDocStd_Application) app;
  Handle(TDocStd_Document)    d = newDoc(app);
  TFunction_Scope::Set(d->GetData()->Root());
  TDF_Label                  l1 = d->Main().NewChild();
  Handle(TFunction_Function) f;
  bool created = TFunction_IFunction::NewFunction(l1, Standard_GUID("12345678-1234-1234-1234-123456789abc"));
  printf("[171] NewFunction on a fresh label: returned=%s TFunction_Function attribute present=%s\n", tf(created),
         tf(l1.FindAttribute(TFunction_Function::GetID(), f)));
  TDF_Label l2 = d->Main().NewChild();
  TFunction_IFunction::NewFunction(l2, Standard_GUID("aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"));
  printf("[172] NewFunction then DeleteFunction: DeleteFunction returned=%s\n", tf(TFunction_IFunction::DeleteFunction(l2)));
  TDF_Label l3 = d->Main().NewChild();
  TFunction_IFunction::NewFunction(l3, Standard_GUID("11111111-2222-3333-4444-555555555555"));
  TFunction_IFunction ifn(l3);
  printf("[173] fresh function GetStatus=%d (WrongDefinition=%d NotExecuted=%d Succeeded=%d)", (int)ifn.GetStatus(),
         (int)TFunction_ES_WrongDefinition, (int)TFunction_ES_NotExecuted, (int)TFunction_ES_Succeeded);
  ifn.SetStatus(TFunction_ES_Succeeded);
  printf(", after SetStatus(Succeeded) GetStatus=%d\n", (int)ifn.GetStatus());
  TDF_Label l4 = d->Main().NewChild();
  printf("[174] fresh label without NewFunction: TFunction_Function attribute present=%s\n", tf(l4.FindAttribute(TFunction_Function::GetID(), f)));
}

// [209] [211] [212] a fresh child label of Main() carries no DimTol / Location / Material attribute.
static void freshLabelAttrs()
{
  Handle(TDocStd_Application) app;
  Handle(TDocStd_Document)    d = newDoc(app);
  TDF_Label                   l = d->Main().NewChild();
  Handle(XCAFDoc_DimTol)      dt;
  Handle(XCAFDoc_Location)    lo;
  Handle(XCAFDoc_Material)    ma;
  printf("[209] fresh label: XCAFDoc_DimTol present=%s\n", tf(l.FindAttribute(XCAFDoc_DimTol::GetID(), dt)));
  printf("[211] fresh label: XCAFDoc_Location present=%s\n", tf(l.FindAttribute(XCAFDoc_Location::GetID(), lo)));
  printf("[212] fresh label: XCAFDoc_Material present=%s\n", tf(l.FindAttribute(XCAFDoc_Material::GetID(), ma)));
}

// [135] VisMaterialCommonTests.commonMaterialRoughnessFromShininess: OBJ/MTL import (Ks 0.8, Ns 300), then the
// bridge's fallback roughness, Graphic3d_PBRMaterial::RoughnessFromSpecular(specular, shininess).
static bool findCommon(const Handle(XCAFDoc_ShapeTool)& st, const Handle(XCAFDoc_VisMaterialTool)& vmt, const TDF_Label& l,
                       XCAFDoc_VisMaterialCommon& out, int depth)
{
  TopoDS_Shape s = XCAFDoc_ShapeTool::GetShape(l);
  if (!s.IsNull())
  {
    Handle(XCAFDoc_VisMaterial) m = vmt->GetShapeMaterial(s);
    if (!m.IsNull() && m->HasCommonMaterial() && !m->HasPbrMaterial())
    {
      out = m->CommonMaterial();
      return true;
    }
  }
  TDF_LabelSequence comps;
  XCAFDoc_ShapeTool::GetComponents(l, comps);
  for (int i = 1; i <= comps.Length(); i++)
    if (findCommon(st, vmt, comps.Value(i), out, depth + 1))
      return true;
  return false;
}

static void roughnessFallback()
{
  {
    std::ofstream m("/tmp/766-xcaf-evidence-fix-1508.mtl");
    m << "newmtl Issue1508Material\nKa 0.1 0.1 0.1\nKd 0.8 0.8 0.8\nKs 0.8 0.8 0.8\nNs 300.0\n";
    std::ofstream o("/tmp/766-xcaf-evidence-fix-1508.obj");
    o << "mtllib 766-xcaf-evidence-fix-1508.mtl\ng Issue1508Group\nusemtl Issue1508Material\nv 0 0 0\nv 1 0 0\nv 0 1 0\nf 1 2 3\n";
  }
  Handle(TDocStd_Application) app;
  Handle(TDocStd_Document)    d = newDoc(app);
  RWObj_CafReader             reader;
  reader.SetDocument(d);
  bool ok = reader.Perform(TCollection_AsciiString("/tmp/766-xcaf-evidence-fix-1508.obj"), Message_ProgressRange());
  Handle(XCAFDoc_ShapeTool)       st  = XCAFDoc_DocumentTool::ShapeTool(d->Main());
  Handle(XCAFDoc_VisMaterialTool) vmt = XCAFDoc_DocumentTool::VisMaterialTool(d->Main());
  TDF_LabelSequence               roots;
  st->GetFreeShapes(roots);
  XCAFDoc_VisMaterialCommon common;
  bool                      found = false;
  for (int i = 1; i <= roots.Length() && !found; i++)
    found = findCommon(st, vmt, roots.Value(i), common, 0);
  printf("[135] RWObj_CafReader::Perform=%s free shapes=%d common material found=%s", tf(ok), roots.Length(), tf(found));
  if (found)
  {
    float r = Graphic3d_PBRMaterial::RoughnessFromSpecular(common.SpecularColor, common.Shininess);
    printf(" Shininess=%.9g specular=(%.9g, %.9g, %.9g) RoughnessFromSpecular=%.9g |r-0.7|=%.9g", (double)common.Shininess,
           common.SpecularColor.Red(), common.SpecularColor.Green(), common.SpecularColor.Blue(), (double)r, std::fabs((double)r - 0.7));
  }
  printf("\n");
}

// ---- KEYS group 1 --------------------------------------------------------------------------------
// [16] AssemblyNodeIdentityTests.labelIdRoundTrip: box -> STEP -> STEPCAFControl_Reader (the modes OCCTDocumentLoadSTEP
// sets); the root label is fetched twice (Document.node(at:) re-fetches through GetFreeShapes) and its name read from both.
static std::string nameOf(const TDF_Label& l)
{
  Handle(TDataStd_Name) nm;
  return l.FindAttribute(TDataStd_Name::GetID(), nm) ? std::string(TCollection_AsciiString(nm->Get()).ToCString())
                                                     : std::string("<none>");
}

static void stepIdentity()
{
  const char* path = "/tmp/766-xcaf-evidence-fix-16.step";
  {
    STEPControl_Writer w;
    Interface_Static::SetCVal("write.step.schema", "AP214");
    w.Transfer(centredBox(10, 10, 10), STEPControl_AsIs);
    w.Write(path);
  }
  Handle(TDocStd_Application) app;
  Handle(TDocStd_Document)    d = newDoc(app);
  STEPCAFControl_Reader       r;
  r.SetColorMode(true);
  r.SetNameMode(true);
  r.SetLayerMode(true);
  r.SetPropsMode(true);
  r.SetMatMode(true);
  r.ReadFile(path);
  r.Transfer(d);
  TDF_LabelSequence first, second;
  XCAFDoc_DocumentTool::ShapeTool(d->Main())->GetFreeShapes(first);
  XCAFDoc_DocumentTool::ShapeTool(d->Main())->GetFreeShapes(second);
  std::string n1 = nameOf(first.Value(1)), n2 = nameOf(second.Value(1));
  printf("[16] free shapes=%d, re-fetched root IsEqual first=%s, name(first)=\"%s\" name(re-fetched)=\"%s\" equal=%s\n", first.Length(),
         tf(second.Value(1).IsEqual(first.Value(1))), n1.c_str(), n2.c_str(), tf(n1 == n2));
}

// [45] DocumentGDTTests.fullAuthoring: 3 dimensions + 2 tolerances + 2 datums on one box through the calls the bridge's
// OCCTDocumentCreateDimension / CreateGeomTolerance / CreateDatum make, then the counts and the types and names read back.
static void gdtAuthoring()
{
  Handle(TDocStd_Application) app;
  Handle(TDocStd_Document)    d = newDoc(app);
  Handle(XCAFDoc_DimTolTool)  t = XCAFDoc_DocumentTool::DimTolTool(d->Main());
  TDF_Label                   shape = XCAFDoc_DocumentTool::ShapeTool(d->Main())->AddShape(centredBox(100, 50, 25), false);
  const XCAFDimTolObjects_DimensionType dtypes[3] = {XCAFDimTolObjects_DimensionType_Size_Diameter,
                                                     XCAFDimTolObjects_DimensionType_Location_LinearDistance,
                                                     XCAFDimTolObjects_DimensionType_Size_Radius};
  const double                          dvals[3]  = {10.0, 50.0, 5.0};
  for (int i = 0; i < 3; i++)
  {
    TDF_Label dl = t->AddDimension();
    t->SetDimension(shape, dl);
    Handle(XCAFDoc_Dimension) da;
    dl.FindAttribute(XCAFDoc_Dimension::GetID(), da);
    Handle(XCAFDimTolObjects_DimensionObject) o = new XCAFDimTolObjects_DimensionObject();
    o->SetType(dtypes[i]);
    Handle(TColStd_HArray1OfReal) vals = new TColStd_HArray1OfReal(1, 1);
    vals->SetValue(1, dvals[i]);
    o->SetValues(vals);
    da->SetObject(o);
  }
  const XCAFDimTolObjects_GeomToleranceType ttypes[2] = {XCAFDimTolObjects_GeomToleranceType_Flatness,
                                                         XCAFDimTolObjects_GeomToleranceType_Perpendicularity};
  const double                              tvals[2]  = {0.01, 0.05};
  for (int i = 0; i < 2; i++)
  {
    TDF_Label         tl = t->AddGeomTolerance();
    TDF_LabelSequence shapes;
    shapes.Append(shape);
    t->SetGeomTolerance(shapes, tl);
    Handle(XCAFDoc_GeomTolerance) ta;
    tl.FindAttribute(XCAFDoc_GeomTolerance::GetID(), ta);
    Handle(XCAFDimTolObjects_GeomToleranceObject) o = new XCAFDimTolObjects_GeomToleranceObject();
    o->SetTypeOfValue(XCAFDimTolObjects_GeomToleranceTypeValue_None);
    o->SetMaterialRequirementModifier(XCAFDimTolObjects_GeomToleranceMatReqModif_None);
    o->SetZoneModifier(XCAFDimTolObjects_GeomToleranceZoneModif_None);
    o->SetValueOfZoneModifier(0.0);
    o->SetMaxValueModifier(0.0);
    o->SetType(ttypes[i]);
    o->SetValue(tvals[i]);
    ta->SetObject(o);
  }
  const char* dnames[2] = {"A", "B"};
  for (int i = 0; i < 2; i++)
  {
    TDF_Label             dat = t->AddDatum();
    Handle(XCAFDoc_Datum) da;
    dat.FindAttribute(XCAFDoc_Datum::GetID(), da);
    Handle(XCAFDimTolObjects_DatumObject) o = new XCAFDimTolObjects_DatumObject();
    o->SetPosition(0);
    o->SetModifierWithValue(XCAFDimTolObjects_DatumModifWithValue_None, 0.0);
    o->SetName(new TCollection_HAsciiString(dnames[i]));
    da->SetObject(o);
  }
  TDF_LabelSequence dl, tl, xl;
  t->GetDimensionLabels(dl);
  t->GetGeomToleranceLabels(tl);
  t->GetDatumLabels(xl);
  bool hasDiameter = false, hasPerp = false;
  for (int i = 1; i <= dl.Length(); i++)
  {
    Handle(XCAFDoc_Dimension) da;
    dl.Value(i).FindAttribute(XCAFDoc_Dimension::GetID(), da);
    hasDiameter = hasDiameter || da->GetObject()->GetType() == XCAFDimTolObjects_DimensionType_Size_Diameter;
  }
  for (int i = 1; i <= tl.Length(); i++)
  {
    Handle(XCAFDoc_GeomTolerance) ta;
    tl.Value(i).FindAttribute(XCAFDoc_GeomTolerance::GetID(), ta);
    hasPerp = hasPerp || ta->GetObject()->GetType() == XCAFDimTolObjects_GeomToleranceType_Perpendicularity;
  }
  std::vector<std::string> names;
  for (int i = 1; i <= xl.Length(); i++)
  {
    Handle(XCAFDoc_Datum) da;
    xl.Value(i).FindAttribute(XCAFDoc_Datum::GetID(), da);
    names.push_back(da->GetObject()->GetName()->ToCString());
  }
  std::sort(names.begin(), names.end());
  printf("[45] dimensions=%d tolerances=%d datums=%d, has Size_Diameter=%s, has Perpendicularity=%s, sorted datum names=[", dl.Length(),
         tl.Length(), xl.Length(), tf(hasDiameter), tf(hasPerp));
  for (size_t i = 0; i < names.size(); i++)
    printf("%s\"%s\"", i ? ", " : "", names[i].c_str());
  printf("]\n");
}

// [43] [44] DocumentGDTTests.createTolerance / createDatum: the index the bridge returns for a new tolerance or datum is the
// label count minus one (OCCTDocumentCreateGeomTolerance / OCCTDocumentCreateDatum), read back through the objects.
static void gdtSingles()
{
  Handle(TDocStd_Application) app;
  Handle(TDocStd_Document)    d = newDoc(app);
  Handle(XCAFDoc_DimTolTool)  t = XCAFDoc_DocumentTool::DimTolTool(d->Main());
  TDF_Label                   shape = XCAFDoc_DocumentTool::ShapeTool(d->Main())->AddShape(centredBox(10, 10, 10), false);
  TDF_Label                   tl    = t->AddGeomTolerance();
  TDF_LabelSequence           shapes;
  shapes.Append(shape);
  t->SetGeomTolerance(shapes, tl);
  Handle(XCAFDoc_GeomTolerance) ta;
  tl.FindAttribute(XCAFDoc_GeomTolerance::GetID(), ta);
  Handle(XCAFDimTolObjects_GeomToleranceObject) to = new XCAFDimTolObjects_GeomToleranceObject();
  to->SetTypeOfValue(XCAFDimTolObjects_GeomToleranceTypeValue_None);
  to->SetMaterialRequirementModifier(XCAFDimTolObjects_GeomToleranceMatReqModif_None);
  to->SetZoneModifier(XCAFDimTolObjects_GeomToleranceZoneModif_None);
  to->SetValueOfZoneModifier(0.0);
  to->SetMaxValueModifier(0.0);
  to->SetType(XCAFDimTolObjects_GeomToleranceType_Flatness);
  to->SetValue(0.01);
  ta->SetObject(to);
  TDF_LabelSequence tls;
  t->GetGeomToleranceLabels(tls);
  printf("[43] flatness 0.01: tolerance labels=%d (index of new = %d) GetType=%d (Flatness=%d) GetValue=%.17g\n", tls.Length(),
         tls.Length() - 1, (int)ta->GetObject()->GetType(), (int)XCAFDimTolObjects_GeomToleranceType_Flatness, ta->GetObject()->GetValue());
  TDF_Label             dat = t->AddDatum();
  Handle(XCAFDoc_Datum) da;
  dat.FindAttribute(XCAFDoc_Datum::GetID(), da);
  Handle(XCAFDimTolObjects_DatumObject) dobj = new XCAFDimTolObjects_DatumObject();
  dobj->SetPosition(0);
  dobj->SetModifierWithValue(XCAFDimTolObjects_DatumModifWithValue_None, 0.0);
  dobj->SetName(new TCollection_HAsciiString("A"));
  da->SetObject(dobj);
  TDF_LabelSequence dls;
  t->GetDatumLabels(dls);
  printf("[44] datum A: datum labels=%d (index of new = %d) GetName=\"%s\"\n", dls.Length(), dls.Length() - 1,
         da->GetObject()->GetName()->ToCString());
}

// ---- KEYS group 2: the GD&T accessor, setter and buffer tests -------------------------------------------------------
// Each helper mirrors what the bridge's OCCTDocumentCreateDimension / CreateGeomTolerance / CreateDatum do, then a section
// applies the calls one test makes to the objects and reads them back through a fresh GetObject().
struct GdtDoc
{
  Handle(TDocStd_Application) app;
  Handle(TDocStd_Document)    d;
  Handle(XCAFDoc_DimTolTool)  t;
  TDF_Label                   shape;
};

static void gdtInit(GdtDoc& g)
{
  g.d     = newDoc(g.app);
  g.t     = XCAFDoc_DocumentTool::DimTolTool(g.d->Main());
  g.shape = XCAFDoc_DocumentTool::ShapeTool(g.d->Main())->AddShape(centredBox(10, 10, 10), false);
}

static Handle(XCAFDoc_Dimension) gdtAddDim(GdtDoc& g, XCAFDimTolObjects_DimensionType ty, double v)
{
  TDF_Label dl = g.t->AddDimension();
  g.t->SetDimension(g.shape, dl);
  Handle(XCAFDoc_Dimension) da;
  dl.FindAttribute(XCAFDoc_Dimension::GetID(), da);
  Handle(XCAFDimTolObjects_DimensionObject) o = new XCAFDimTolObjects_DimensionObject();
  o->SetType(ty);
  Handle(TColStd_HArray1OfReal) vals = new TColStd_HArray1OfReal(1, 1);
  vals->SetValue(1, v);
  o->SetValues(vals);
  da->SetObject(o);
  return da;
}

static Handle(XCAFDoc_GeomTolerance) gdtAddTol(GdtDoc& g, XCAFDimTolObjects_GeomToleranceType ty, double v)
{
  TDF_Label         tl = g.t->AddGeomTolerance();
  TDF_LabelSequence shapes;
  shapes.Append(g.shape);
  g.t->SetGeomTolerance(shapes, tl);
  Handle(XCAFDoc_GeomTolerance) ta;
  tl.FindAttribute(XCAFDoc_GeomTolerance::GetID(), ta);
  Handle(XCAFDimTolObjects_GeomToleranceObject) o = new XCAFDimTolObjects_GeomToleranceObject();
  o->SetTypeOfValue(XCAFDimTolObjects_GeomToleranceTypeValue_None);
  o->SetMaterialRequirementModifier(XCAFDimTolObjects_GeomToleranceMatReqModif_None);
  o->SetZoneModifier(XCAFDimTolObjects_GeomToleranceZoneModif_None);
  o->SetValueOfZoneModifier(0.0);
  o->SetMaxValueModifier(0.0);
  o->SetType(ty);
  o->SetValue(v);
  ta->SetObject(o);
  return ta;
}

static Handle(XCAFDoc_Datum) gdtAddDatum(GdtDoc& g, const char* name)
{
  TDF_Label             dat = g.t->AddDatum();
  Handle(XCAFDoc_Datum) da;
  dat.FindAttribute(XCAFDoc_Datum::GetID(), da);
  Handle(XCAFDimTolObjects_DatumObject) o = new XCAFDimTolObjects_DatumObject();
  o->SetPosition(0);
  o->SetModifierWithValue(XCAFDimTolObjects_DatumModifWithValue_None, 0.0);
  o->SetName(new TCollection_HAsciiString(name));
  da->SetObject(o);
  return da;
}

static bool seqRaises(const TDF_LabelSequence& s, int oneBased)
{
  try
  {
    (void)s.Value(oneBased);
    return false;
  }
  catch (const Standard_OutOfRange&)
  {
    return true;
  }
}

static void gdtDimState(const char* tag, const Handle(XCAFDoc_Dimension)& a)
{
  Handle(XCAFDimTolObjects_DimensionObject) o = a->GetObject();
  int                                       l = -1, r = -1;
  o->GetNbOfDecimalPlaces(l, r);
  printf("%s: qualifier=%d modifiers=[", tag, (int)o->GetQualifier());
  for (int i = 1; i <= o->GetModifiers().Length(); i++)
    printf("%s%d", i > 1 ? ", " : "", (int)o->GetModifiers().Value(i));
  printf("] decimal places=(%d, %d) present=%s\n", l, r, tf(l > 0 || r > 0));
}

static void gdtDimAccessors()
{
  {
    GdtDoc g;
    gdtInit(g);
    Handle(XCAFDoc_Dimension) a = gdtAddDim(g, XCAFDimTolObjects_DimensionType_Size_Diameter, 20.0);
    Handle(XCAFDoc_Dimension) b = gdtAddDim(g, XCAFDimTolObjects_DimensionType_Size_Radius, 5.0);
    {
      Handle(XCAFDimTolObjects_DimensionObject) o = a->GetObject();
      o->SetQualifier(XCAFDimTolObjects_DimensionQualifier_Max);
      a->SetObject(o);
    }
    {
      Handle(XCAFDimTolObjects_DimensionObject)                o = a->GetObject();
      NCollection_Sequence<XCAFDimTolObjects_DimensionModif> m;
      m.Append(XCAFDimTolObjects_DimensionModif_Square);
      o->SetModifiers(m);
      a->SetObject(o);
    }
    {
      Handle(XCAFDimTolObjects_DimensionObject) o = b->GetObject();
      o->SetNbOfDecimalPlaces(1, 1);
      b->SetObject(o);
    }
    gdtDimState("[49] first dimension (qualifier Max, modifiers [Square])", a);
    gdtDimState("[49] second dimension (decimal places (1, 1))", b);
  }
  {
    GdtDoc g;
    gdtInit(g);
    Handle(XCAFDoc_Dimension) a = gdtAddDim(g, XCAFDimTolObjects_DimensionType_Size_Diameter, 20.0);
    TDF_LabelSequence         dls;
    g.t->GetDimensionLabels(dls);
    printf("[50] dimension labels=%d: Value(6) (index 5) raises Standard_OutOfRange=%s\n", dls.Length(), tf(seqRaises(dls, 6)));
    bool threw = false;
    try
    {
      Handle(XCAFDimTolObjects_DimensionObject) o = a->GetObject();
      o->SetNbOfDecimalPlaces(-1, 0);
      a->SetObject(o);
    }
    catch (const Standard_Failure&)
    {
      threw = true;
    }
    int l = 99, r = 99;
    a->GetObject()->GetNbOfDecimalPlaces(l, r);
    printf("[50] SetNbOfDecimalPlaces(-1, 0) without the bridge's guard: threw=%s, read back (%d, %d) (present=%s)\n", tf(threw), l, r,
           tf(l > 0 || r > 0));
  }
  {
    GdtDoc g;
    gdtInit(g);
    TDF_LabelSequence dls, tls, xls;
    g.t->GetDimensionLabels(dls);
    g.t->GetGeomToleranceLabels(tls);
    g.t->GetDatumLabels(xls);
    printf("[54] [55] [56] fresh document: dimension labels=%d tolerance labels=%d datum labels=%d\n", dls.Length(), tls.Length(),
           xls.Length());
    printf("[54] dimension index 0 (Value(1)) raises=%s, index -1 (Value(0)) raises=%s, index 999 (Value(1000)) raises=%s\n",
           tf(seqRaises(dls, 1)), tf(seqRaises(dls, 0)), tf(seqRaises(dls, 1000)));
    printf("[55] tolerance index 0 (Value(1)) raises=%s, index -1 (Value(0)) raises=%s\n", tf(seqRaises(tls, 1)), tf(seqRaises(tls, 0)));
    printf("[56] datum index 0 (Value(1)) raises=%s, index -1 (Value(0)) raises=%s\n", tf(seqRaises(xls, 1)), tf(seqRaises(xls, 0)));
  }
}

static void datumState(const char* tag, const Handle(XCAFDoc_Datum)& da)
{
  Handle(XCAFDimTolObjects_DatumObject) o = da->GetObject();
  printf("%s: IsDatumTarget=%s type=%d number=%d HasDatumTargetParams=%s length=%.17g width=%.17g\n", tag, tf(o->IsDatumTarget()),
         (int)o->GetDatumTargetType(), o->GetDatumTargetNumber(), tf(o->HasDatumTargetParams()), o->GetDatumTargetLength(),
         o->GetDatumTargetWidth());
}

static void datumSetTarget(const Handle(XCAFDoc_Datum)& da, XCAFDimTolObjects_DatumTargetType ty, int number)
{
  Handle(XCAFDimTolObjects_DatumObject) o = da->GetObject();
  o->IsDatumTarget(true);
  o->SetDatumTargetType(ty);
  o->SetDatumTargetNumber(number);
  da->SetObject(o);
}

// The placement calls of OCCTDocumentSetDatumTargetPlacement, WITHOUT its precondition test.
static bool datumPlace(const Handle(XCAFDoc_Datum)& da, double length, double width)
{
  try
  {
    Handle(XCAFDimTolObjects_DatumObject) o = da->GetObject();
    o->SetDatumTargetAxis(gp_Ax2(gp_Pnt(1, 2, 3), gp_Dir(0, 0, 1), gp_Dir(1, 0, 0)));
    o->SetDatumTargetLength(length);
    o->SetDatumTargetWidth(width);
    da->SetObject(o);
  }
  catch (const Standard_Failure&)
  {
    return true;  // threw
  }
  return false;
}

static void gdtTolDatumAccessors()
{
  {  // [57] the test's sequence: allAround (15), commonZone (1), freeState (3), then cleared
    GdtDoc g;
    gdtInit(g);
    Handle(XCAFDoc_GeomTolerance)                  t  = gdtAddTol(g, XCAFDimTolObjects_GeomToleranceType_Position, 0.1);
    Handle(XCAFDimTolObjects_GeomToleranceObject) o  = t->GetObject();
    printf("[57] fresh tolerance modifiers=%d", o->GetModifiers().Length());
    NCollection_Sequence<XCAFDimTolObjects_GeomToleranceModif> m;
    m.Append(XCAFDimTolObjects_GeomToleranceModif_All_Around);
    m.Append(XCAFDimTolObjects_GeomToleranceModif_Common_Zone);
    m.Append(XCAFDimTolObjects_GeomToleranceModif_Free_State);
    o->SetModifiers(m);
    t->SetObject(o);
    printf("; written [%d, %d, %d], read back [", (int)XCAFDimTolObjects_GeomToleranceModif_All_Around,
           (int)XCAFDimTolObjects_GeomToleranceModif_Common_Zone, (int)XCAFDimTolObjects_GeomToleranceModif_Free_State);
    Handle(XCAFDimTolObjects_GeomToleranceObject) o2 = t->GetObject();
    for (int i = 1; i <= o2->GetModifiers().Length(); i++)
      printf("%s%d", i > 1 ? ", " : "", (int)o2->GetModifiers().Value(i));
    o2->SetModifiers(NCollection_Sequence<XCAFDimTolObjects_GeomToleranceModif>());
    t->SetObject(o2);
    printf("]; after clearing modifiers=%d\n", t->GetObject()->GetModifiers().Length());
  }
  // [58] a datum target's persisted length and width, by target type (the read-back after SetObject, not the in-memory object)
  const struct
  {
    XCAFDimTolObjects_DatumTargetType ty;
    const char*                       name;
  } kinds[3] = {{XCAFDimTolObjects_DatumTargetType_Rectangle, "Rectangle"},
                {XCAFDimTolObjects_DatumTargetType_Line, "Line"},
                {XCAFDimTolObjects_DatumTargetType_Point, "Point"}};
  for (const auto& k : kinds)
  {
    GdtDoc g;
    gdtInit(g);
    Handle(XCAFDoc_Datum) da = gdtAddDatum(g, "B");
    datumSetTarget(da, k.ty, 4);
    datumPlace(da, 30.0, 18.0);
    char tag[64];
    snprintf(tag, sizeof tag, "[58] %s target after placement (30, 18), read back", k.name);
    datumState(tag, da);
  }
  {  // [59] a zero normal: gp_Dir throws before any setter runs
    GdtDoc g;
    gdtInit(g);
    Handle(XCAFDoc_Datum) da = gdtAddDatum(g, "C");
    datumSetTarget(da, XCAFDimTolObjects_DatumTargetType_Line, 1);
    bool threw = false;
    try
    {
      Handle(XCAFDimTolObjects_DatumObject) o = da->GetObject();
      o->SetDatumTargetAxis(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 0), gp_Dir(1, 0, 0)));
      o->SetDatumTargetLength(10);
      o->SetDatumTargetWidth(0);
      da->SetObject(o);
    }
    catch (const Standard_ConstructionError&)
    {
      threw = true;
    }
    printf("[59] gp_Dir(0, 0, 0) in the placement throws Standard_ConstructionError=%s; ", tf(threw));
    datumState("after the failed placement", da);
  }
  {  // [60] two tolerances and two datums, each written differently, read back separately
    GdtDoc g;
    gdtInit(g);
    Handle(XCAFDoc_GeomTolerance) ta = gdtAddTol(g, XCAFDimTolObjects_GeomToleranceType_Position, 0.1);
    Handle(XCAFDoc_GeomTolerance) tb = gdtAddTol(g, XCAFDimTolObjects_GeomToleranceType_Flatness, 0.05);
    Handle(XCAFDoc_Datum)         da = gdtAddDatum(g, "A");
    Handle(XCAFDoc_Datum)         db = gdtAddDatum(g, "B");
    {
      Handle(XCAFDimTolObjects_GeomToleranceObject) o = ta->GetObject();
      o->SetTypeOfValue(XCAFDimTolObjects_GeomToleranceTypeValue_Diameter);
      ta->SetObject(o);
    }
    {
      Handle(XCAFDimTolObjects_GeomToleranceObject)               o = tb->GetObject();
      NCollection_Sequence<XCAFDimTolObjects_GeomToleranceModif> m;
      m.Append(XCAFDimTolObjects_GeomToleranceModif_All_Over);
      o->SetModifiers(m);
      tb->SetObject(o);
    }
    {
      Handle(XCAFDimTolObjects_DatumObject) o = da->GetObject();
      o->SetPosition(1);
      da->SetObject(o);
    }
    datumSetTarget(db, XCAFDimTolObjects_DatumTargetType_Circle, 7);
    Handle(XCAFDimTolObjects_GeomToleranceObject) a = ta->GetObject(), b = tb->GetObject();
    Handle(XCAFDimTolObjects_DatumObject)          x = da->GetObject(), y = db->GetObject();
    printf("[60] tolerance A: typeOfValue=%d modifiers=%d; tolerance B: typeOfValue=%d modifiers=[%d]; datum A: name=%s position=%d "
           "isTarget=%s; datum B: name=%s position=%d isTarget=%s type=%d number=%d\n",
           (int)a->GetTypeOfValue(), a->GetModifiers().Length(), (int)b->GetTypeOfValue(), (int)b->GetModifiers().Value(1),
           x->GetName()->ToCString(), x->GetPosition(), tf(x->IsDatumTarget()), y->GetName()->ToCString(), y->GetPosition(),
           tf(y->IsDatumTarget()), (int)y->GetDatumTargetType(), y->GetDatumTargetNumber());
  }
  {  // [61] one tolerance, no datums
    GdtDoc g;
    gdtInit(g);
    gdtAddTol(g, XCAFDimTolObjects_GeomToleranceType_Position, 0.1);
    TDF_LabelSequence tls, xls;
    g.t->GetGeomToleranceLabels(tls);
    g.t->GetDatumLabels(xls);
    printf("[61] tolerance labels=%d: index 5 (Value(6)) raises=%s; datum labels=%d: index 0 (Value(1)) raises=%s\n", tls.Length(),
           tf(seqRaises(tls, 6)), xls.Length(), tf(seqRaises(xls, 1)));
  }
}

static void gdtPlacement()
{
  {  // [67] a datum that is not a target
    GdtDoc g;
    gdtInit(g);
    Handle(XCAFDoc_Datum) da = gdtAddDatum(g, "A");
    bool                  threw = datumPlace(da, 30.0, 18.0);
    printf("[67] placement threw=%s; ", tf(threw));
    datumState("fresh datum, placement (30, 18) applied without the precondition, read back", da);
  }
  {  // [68] an Area target
    GdtDoc g;
    gdtInit(g);
    Handle(XCAFDoc_Datum) da = gdtAddDatum(g, "A");
    datumSetTarget(da, XCAFDimTolObjects_DatumTargetType_Area, 1);
    bool threw = datumPlace(da, 30.0, 18.0);
    printf("[68] placement threw=%s; ", tf(threw));
    datumState("Area target (type 4), placement (30, 18) applied without the precondition, read back", da);
  }
  {  // [69] a rectangle target with a stored placement, the mark cleared, a second placement applied
    GdtDoc g;
    gdtInit(g);
    Handle(XCAFDoc_Datum) da = gdtAddDatum(g, "A");
    datumSetTarget(da, XCAFDimTolObjects_DatumTargetType_Rectangle, 1);
    datumPlace(da, 30.0, 18.0);
    datumState("[69] rectangle target with placement (30, 18), read back", da);
    {
      Handle(XCAFDimTolObjects_DatumObject) o = da->GetObject();
      o->IsDatumTarget(false);
      da->SetObject(o);
    }
    bool threw = datumPlace(da, 44.0, 22.0);
    printf("[69] second placement threw=%s; ", tf(threw));
    datumState("after IsDatumTarget(false) and a second placement (44, 22) applied without the precondition, read back", da);
  }
}

static void gdtNames()
{
  {  // [71] one datum, index 1 is past the end
    GdtDoc g;
    gdtInit(g);
    gdtAddDatum(g, "AAAA");
    TDF_LabelSequence xls;
    g.t->GetDatumLabels(xls);
    printf("[71] datum labels=%d: index 1 (Value(2)) raises=%s\n", xls.Length(), tf(seqRaises(xls, 2)));
  }
  {  // [73] [74] the layers the bridge reads: XCAFDoc_LayerTool::Set(Main)
    Handle(TDocStd_Application) app;
    Handle(TDocStd_Document)    d  = newDoc(app);
    Handle(XCAFDoc_LayerTool)   lt = XCAFDoc_LayerTool::Set(d->Main());
    TDF_LabelSequence           ls;
    lt->GetLayerLabels(ls);
    printf("[73] [74] XCAFDoc_LayerTool::Set(Main): %d layer labels, name lengths [", ls.Length());
    for (int i = 1; i <= ls.Length(); i++)
    {
      TCollection_ExtendedString nm;
      lt->GetLayer(ls.Value(i), nm);
      printf("%s%d", i > 1 ? ", " : "", TCollection_AsciiString(nm).Length());
    }
    printf("]; index %d (Value(%d)) raises=%s, index -1 (Value(0)) raises=%s\n", ls.Length(), ls.Length() + 1,
           tf(seqRaises(ls, ls.Length() + 1)), tf(seqRaises(ls, 0)));
  }
}

// ---- KEYS group 2b: what the raw kernel does with the values the bridge's #1037 guards refuse -----------------------------
// The bridge refuses an enum ordinal outside the enumerator range before any OCCT call. These sections make the same calls
// WITHOUT that guard, through the attribute (SetObject, then a fresh GetObject), on the same dimension / tolerance / datum in
// the same order the test uses, and print what the kernel read back.
template <class E>
static std::string ordinals(const NCollection_Sequence<E>& s)
{
  std::string out = "[";
  for (int i = 1; i <= s.Length(); i++)
    out += (i > 1 ? ", " : "") + std::to_string((int)s.Value(i));
  return out + "]";
}

static void gdtRawWrites()
{
  const int bad[3] = {24, 9999, -1};
  {  // [62] dimension modifiers: valid [2, 19], three bad singles, then a mixed array
    GdtDoc g;
    gdtInit(g);
    Handle(XCAFDoc_Dimension) a = gdtAddDim(g, XCAFDimTolObjects_DimensionType_Size_Diameter, 20.0);
    auto write = [&](std::initializer_list<int> v) {
      bool                                                   threw = false;
      try
      {
        Handle(XCAFDimTolObjects_DimensionObject)              o = a->GetObject();
        NCollection_Sequence<XCAFDimTolObjects_DimensionModif> m;
        for (int x : v)
          m.Append((XCAFDimTolObjects_DimensionModif)x);
        o->SetModifiers(m);
        a->SetObject(o);
      }
      catch (const Standard_Failure&)
      {
        threw = true;
      }
      return threw;
    };
    write({2, 19});
    printf("[62] valid [2, 19] read back %s (StatisticalTolerance=%d AnyCrossSection=%d)\n", ordinals(a->GetObject()->GetModifiers()).c_str(),
           (int)XCAFDimTolObjects_DimensionModif_StatisticalTolerance, (int)XCAFDimTolObjects_DimensionModif_AnyCrossSection);
    for (int b : bad)
    {
      bool threw = write({b});
      printf("[62] unguarded single %d: threw=%s, read back %s\n", b, tf(threw), ordinals(a->GetObject()->GetModifiers()).c_str());
    }
    bool threw = write({2, 9999, 19});
    printf("[62] unguarded mixed [2, 9999, 19]: threw=%s, read back %s\n", tf(threw), ordinals(a->GetObject()->GetModifiers()).c_str());
  }
  {  // [63] class of tolerance: five out-of-range pairs in the test's order, then the valid pair (11, 7)
    GdtDoc g;
    gdtInit(g);
    Handle(XCAFDoc_Dimension) a = gdtAddDim(g, XCAFDimTolObjects_DimensionType_Size_Diameter, 20.0);
    const int pairs[6][2] = {{29, 7}, {9999, 7}, {-1, 7}, {11, 20}, {11, -1}, {11, 7}};
    for (const auto& p : pairs)
    {
      bool threw = false;
      try
      {
        Handle(XCAFDimTolObjects_DimensionObject) o = a->GetObject();
        o->SetClassOfTolerance(true, (XCAFDimTolObjects_DimensionFormVariance)p[0], (XCAFDimTolObjects_DimensionGrade)p[1]);
        a->SetObject(o);
      }
      catch (const Standard_Failure&)
      {
        threw = true;
      }
      Handle(XCAFDimTolObjects_DimensionObject) o2 = a->GetObject();
      bool                                      hole = false;
      XCAFDimTolObjects_DimensionFormVariance   fv   = XCAFDimTolObjects_DimensionFormVariance_None;
      XCAFDimTolObjects_DimensionGrade          gr   = XCAFDimTolObjects_DimensionGrade_IT01;
      bool                                      got  = o2->GetClassOfTolerance(hole, fv, gr);
      printf("[63] unguarded SetClassOfTolerance(true, %d, %d): threw=%s, IsDimWithClassOfTolerance=%s GetClassOfTolerance=%s (%d, %d)\n",
             p[0], p[1], tf(threw), tf(o2->IsDimWithClassOfTolerance()), tf(got), (int)fv, (int)gr);
    }
  }
  {  // [64] geometric tolerance modifiers: valid [3, 15], then three bad singles
    GdtDoc g;
    gdtInit(g);
    Handle(XCAFDoc_GeomTolerance) t = gdtAddTol(g, XCAFDimTolObjects_GeomToleranceType_Position, 0.1);
    auto write = [&](std::initializer_list<int> v) {
      bool threw = false;
      try
      {
        Handle(XCAFDimTolObjects_GeomToleranceObject)               o = t->GetObject();
        NCollection_Sequence<XCAFDimTolObjects_GeomToleranceModif> m;
        for (int x : v)
          m.Append((XCAFDimTolObjects_GeomToleranceModif)x);
        o->SetModifiers(m);
        t->SetObject(o);
      }
      catch (const Standard_Failure&)
      {
        threw = true;
      }
      return threw;
    };
    write({3, 15});
    printf("[64] valid [3, 15] read back %s (%d modifiers)\n", ordinals(t->GetObject()->GetModifiers()).c_str(),
           t->GetObject()->GetModifiers().Length());
    const int bad64[3] = {17, 9999, -1};
    for (int b : bad64)
    {
      bool threw = write({b});
      printf("[64] unguarded single %d: threw=%s, read back %s (%d modifiers)\n", b, tf(threw),
             ordinals(t->GetObject()->GetModifiers()).c_str(), t->GetObject()->GetModifiers().Length());
    }
  }
  {  // [65] [66] datum modifiers: valid [2, 3], three bad singles; and the empty sequence
    GdtDoc g;
    gdtInit(g);
    Handle(XCAFDoc_Datum) d = gdtAddDatum(g, "A");
    auto write = [&](std::initializer_list<int> v) {
      bool threw = false;
      try
      {
        Handle(XCAFDimTolObjects_DatumObject)                    o = d->GetObject();
        NCollection_Sequence<XCAFDimTolObjects_DatumSingleModif> m;
        for (int x : v)
          m.Append((XCAFDimTolObjects_DatumSingleModif)x);
        o->SetModifiers(m);
        d->SetObject(o);
      }
      catch (const Standard_Failure&)
      {
        threw = true;
      }
      return threw;
    };
    write({2, 3});
    printf("[65] [66] valid [2, 3] read back %s (%d modifiers; Basic=%d ContactingFeature=%d)\n", ordinals(d->GetObject()->GetModifiers()).c_str(),
           d->GetObject()->GetModifiers().Length(), (int)XCAFDimTolObjects_DatumSingleModif_Basic,
           (int)XCAFDimTolObjects_DatumSingleModif_ContactingFeature);
    const int bad65[3] = {22, 9999, -1};
    for (int b : bad65)
    {
      bool threw = write({b});
      printf("[65] unguarded single %d: threw=%s, read back %s\n", b, tf(threw), ordinals(d->GetObject()->GetModifiers()).c_str());
    }
    write({2, 3});
    int  before = d->GetObject()->GetModifiers().Length();
    bool threw  = write({});
    printf("[66] [2, 3] written again (modifiers=%d), then an empty sequence: threw=%s, modifiers=%d\n", before, tf(threw),
           d->GetObject()->GetModifiers().Length());
  }
}

int main()
{
  textLabel();
  pbrEquality();
  itemRefOrphan();
  iFunction();
  freshLabelAttrs();
  roughnessFallback();
  stepIdentity();
  gdtAuthoring();
  gdtSingles();
  gdtDimAccessors();
  gdtTolDatumAccessors();
  gdtPlacement();
  gdtNames();
  gdtRawWrites();
  return 0;
}
