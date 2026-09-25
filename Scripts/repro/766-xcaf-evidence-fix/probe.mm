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
#include <TDF_Reference.hxx>
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
#include <BRepBndLib.hxx>
#include <BRepMesh_IncrementalMesh.hxx>
#include <BRepPrimAPI_MakeSphere.hxx>
#include <BRepBuilderAPI_Transform.hxx>
#include <BRep_Tool.hxx>
#include <Bnd_Box.hxx>
#include <Poly_Triangulation.hxx>
#include <RWGltf_CafReader.hxx>
#include <RWGltf_CafWriter.hxx>
#include <TDF_AttributeIterator.hxx>
#include <TDF_ChildIterator.hxx>
#include <TDF_CopyLabel.hxx>
#include <TDF_DataSet.hxx>
#include <TDF_Delta.hxx>
#include <TDataStd_Integer.hxx>
#include <TDataStd_Real.hxx>
#include <TDataStd_RealArray.hxx>
#include <TDataXtd_Shape.hxx>
#include <TDataXtd_Triangulation.hxx>
#include <TNaming_Builder.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <NCollection_IndexedDataMap.hxx>
#include <XCAFDoc_Editor.hxx>
#include <cmath>
#include <Prs3d_Drawer.hxx>
#include <Prs3d_TextAspect.hxx>
#include <TDataStd_Variable.hxx>
#include <TDataXtd_Axis.hxx>
#include <TDataXtd_Constraint.hxx>
#include <TDataXtd_Geometry.hxx>
#include <TDataXtd_Plane.hxx>
#include <TDataXtd_Point.hxx>
#include <TDocStd_XLink.hxx>
#include <TFunction_GraphNode.hxx>
#include <TObj_Application.hxx>
#include <XCAFDoc_AssemblyGraph.hxx>
#include <XCAFNoteObjects_NoteObject.hxx>
#include <XCAFPrs_Style.hxx>
#include <XCAFView_Object.hxx>
#include <gp_Lin.hxx>
#include <gp_Pln.hxx>
#include <BRepCheck_Analyzer.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <TNaming_CopyShape.hxx>
#include <TNaming_Iterator.hxx>
#include <TNaming_NamedShape.hxx>
#include <TNaming_NewShapeIterator.hxx>
#include <TNaming_OldShapeIterator.hxx>
#include <TNaming_SameShapeIterator.hxx>
#include <TNaming_Tool.hxx>
#include <TNaming_Translator.hxx>
#include <TColStd_IndexedDataMapOfTransientTransient.hxx>
#include <XCAFDoc_AssemblyIterator.hxx>
#include <XCAFDoc_Color.hxx>
#include <XCAFDoc_GraphNode.hxx>
#include <XCAFDoc_ShapeMapTool.hxx>
#include <climits>

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
  // One document per test, as each test has: Document.createLabel() is Main().NewChild(), which on an XCAF document is 0:1:1.
  Handle(TFunction_Function) f;
  {
    Handle(TDocStd_Application) app;
    Handle(TDocStd_Document)    d = newDoc(app);
    TFunction_Scope::Set(d->GetData()->Root());
    TDF_Label l1      = d->Main().NewChild();
    bool      created = TFunction_IFunction::NewFunction(l1, Standard_GUID("12345678-1234-1234-1234-123456789abc"));
    printf("[171] NewFunction on the created label: returned=%s TFunction_Function attribute present=%s\n", tf(created),
           tf(l1.FindAttribute(TFunction_Function::GetID(), f)));
  }
  {
    Handle(TDocStd_Application) app;
    Handle(TDocStd_Document)    d = newDoc(app);
    TFunction_Scope::Set(d->GetData()->Root());
    TDF_Label l2 = d->Main().NewChild();
    TFunction_IFunction::NewFunction(l2, Standard_GUID("aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"));
    printf("[172] NewFunction then DeleteFunction: DeleteFunction returned=%s\n", tf(TFunction_IFunction::DeleteFunction(l2)));
  }
  {
    Handle(TDocStd_Application) app;
    Handle(TDocStd_Document)    d = newDoc(app);
    TFunction_Scope::Set(d->GetData()->Root());
    TDF_Label l3 = d->Main().NewChild();
    TFunction_IFunction::NewFunction(l3, Standard_GUID("11111111-2222-3333-4444-555555555555"));
    TFunction_IFunction ifn(l3);
    printf("[173] fresh function GetStatus=%d (WrongDefinition=%d NotExecuted=%d Succeeded=%d)", (int)ifn.GetStatus(),
           (int)TFunction_ES_WrongDefinition, (int)TFunction_ES_NotExecuted, (int)TFunction_ES_Succeeded);
    ifn.SetStatus(TFunction_ES_Succeeded);
    printf(", after SetStatus(Succeeded) GetStatus=%d\n", (int)ifn.GetStatus());
  }
  {
    Handle(TDocStd_Application) app;
    Handle(TDocStd_Document)    d  = newDoc(app);
    TDF_Label                   l4 = d->Main().NewChild();
    printf("[174] created label without NewFunction: TFunction_Function attribute present=%s\n", tf(l4.FindAttribute(TFunction_Function::GetID(), f)));
  }
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
  TCollection_AsciiString entry;
  TDF_Tool::Entry(l, entry);
  Handle(TDF_Reference) ref;
  printf("[117] the label Document.createLabel() makes (Main().NewChild(), entry %s): TDF_Reference present=%s\n", entry.ToCString(),
         tf(l.FindAttribute(TDF_Reference::GetID(), ref)));
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

// ---- KEYS group 3 -----------------------------------------------------------------------------------------------------

// [80] [81] [82] [83] [84] [85] [87] Issue1030DatumLookupGuardTests: the datum shapes the tests author, read through
// XCAFDoc_Datum::GetObject (patch 0029 is in the pinned kernel), and the five write paths on the point-without-plane datum.
static TDF_Label d1030Make(const Handle(TDocStd_Document)& d, GdtDoc& g)
{
  g.d     = d;
  g.t     = XCAFDoc_DocumentTool::DimTolTool(d->Main());
  g.shape = XCAFDoc_DocumentTool::ShapeTool(d->Main())->AddShape(centredBox(10, 10, 10), false);
  Handle(XCAFDoc_Datum) a = gdtAddDatum(g, "Datum1030");
  return a->Label();
}

static void d1030Triple(const TDF_Label& l, int tag, double v, int lower = 1, int upper = 3)
{
  Handle(TDataStd_RealArray) arr = TDataStd_RealArray::Set(l.FindChild(tag, true), lower, upper);
  for (int i = lower; i <= upper; i++)
    arr->SetValue(i, v);
}

static void d1030Read(const char* tag, const TDF_Label& l, GdtDoc& g)
{
  Handle(XCAFDoc_Datum) a;
  l.FindAttribute(XCAFDoc_Datum::GetID(), a);
  Handle(XCAFDimTolObjects_DatumObject) o = a->GetObject();
  TDF_LabelSequence                     ls;
  g.t->GetDatumLabels(ls);
  int readable = 0;
  for (int i = 1; i <= ls.Length(); i++)
  {
    Handle(XCAFDoc_Datum) x;
    ls.Value(i).FindAttribute(XCAFDoc_Datum::GetID(), x);
    if (!x->GetObject().IsNull())
      readable++;
  }
  printf("%s: GetObject null=%s name=%s, datum labels=%d readable=%d\n", tag, tf(o.IsNull()),
         (o.IsNull() || o->GetName().IsNull()) ? "-" : o->GetName()->ToCString(), ls.Length(), readable);
}

static void datum1030()
{
  {  // [80]
    Handle(TDocStd_Application) app;
    GdtDoc                      g;
    g.app = app;
    TDF_Label l = d1030Make(newDoc(app), g);
    TDF_LabelSequence ls;
    g.t->GetDatumLabels(ls);
    printf("[80] fresh datum: datum labels=%d (index of new = %d), child 17 exists=%s child 14 exists=%s, point array present=%s, "
           "plane array present=%s",
           ls.Length(), ls.Length() - 1, tf(!l.FindChild(17, false).IsNull()), tf(!l.FindChild(14, false).IsNull()),
           tf(l.FindChild(17, false).IsAttribute(TDataStd_RealArray::GetID())), tf(l.FindChild(14, false).IsAttribute(TDataStd_RealArray::GetID())));
    d1030Triple(l, 17, 7);
    Handle(TDataStd_RealArray) p;
    l.FindChild(17, false).FindAttribute(TDataStd_RealArray::GetID(), p);
    printf("; after writing the point triple 7: bounds %d..%d value(1)=%g value(3)=%g, plane array present=%s\n", p->Lower(), p->Upper(),
           p->Value(1), p->Value(3), tf(l.FindChild(14, false).IsAttribute(TDataStd_RealArray::GetID())));
  }
  {  // [81]
    Handle(TDocStd_Application) app;
    GdtDoc                      g;
    g.app = app;
    TDF_Label l = d1030Make(newDoc(app), g);
    d1030Triple(l, 17, 7);
    d1030Read("[81] point, no plane location", l, g);
  }
  {  // [83]
    Handle(TDocStd_Application) app;
    GdtDoc                      g;
    g.app = app;
    TDF_Label l = d1030Make(newDoc(app), g);
    d1030Triple(l, 14, 6);
    d1030Triple(l, 17, 0, 1000000, 1000002);
    d1030Read("[83] plane location 1..3, point at 1000000", l, g);
  }
  {  // [84]
    Handle(TDocStd_Application) app;
    GdtDoc                      g;
    g.app = app;
    TDF_Label l = d1030Make(newDoc(app), g);
    d1030Triple(l, 14, 6);
    d1030Triple(l, 17, 7);
    d1030Read("[84] point and plane location", l, g);
  }
  {  // [85]
    Handle(TDocStd_Application) app;
    GdtDoc                      g;
    g.app = app;
    TDF_Label l = d1030Make(newDoc(app), g);
    d1030Triple(l, 17, 0, 1, 2);
    d1030Read("[85] point array of length 2", l, g);
  }
  {  // [82] the five write paths of the test, on the point-without-plane datum
    Handle(TDocStd_Application) app;
    GdtDoc                      g;
    g.app = app;
    TDF_Label l = d1030Make(newDoc(app), g);
    d1030Triple(l, 17, 7);
    Handle(XCAFDoc_Datum) a;
    l.FindAttribute(XCAFDoc_Datum::GetID(), a);
    bool threw = false, readable = true;
    try
    {
      auto get = [&]() {
        Handle(XCAFDimTolObjects_DatumObject) o = a->GetObject();
        if (o.IsNull())
          readable = false;
        return o;
      };
      Handle(XCAFDimTolObjects_DatumObject) o = get();
      o->SetPosition(2);
      a->SetObject(o);
      o = get();
      NCollection_Sequence<XCAFDimTolObjects_DatumSingleModif> m;
      m.Append(XCAFDimTolObjects_DatumSingleModif_Basic);
      o->SetModifiers(m);
      a->SetObject(o);
      o = get();
      o->SetModifierWithValue(XCAFDimTolObjects_DatumModifWithValue_CircularOrCylindrical, 1.5);
      a->SetObject(o);
      o = get();
      o->IsDatumTarget(true);
      o->SetDatumTargetType(XCAFDimTolObjects_DatumTargetType_Point);
      o->SetDatumTargetNumber(1);
      a->SetObject(o);
      o = get();
      o->IsDatumTarget(false);
      a->SetObject(o);
    }
    catch (const Standard_Failure&)
    {
      threw = true;
    }
    printf("[82] five write paths on the point-without-plane datum (position 2, modifiers [Basic], modifier with value, point target, "
           "target cleared): threw=%s, GetObject readable throughout=%s, final position=%d\n",
           tf(threw), tf(readable), a->GetObject()->GetPosition());
  }
  {  // [86] RescaleGeometry with one readable datum
    Handle(TDocStd_Application) app;
    GdtDoc                      g;
    g.app = app;
    d1030Make(newDoc(app), g);
    printf("[86] RescaleGeometry(Main, 2.0, force) with one readable datum=%s\n", tf(XCAFDoc_Editor::RescaleGeometry(g.d->Main(), 2.0, true)));
  }
  {  // [87] a plain datum
    Handle(TDocStd_Application) app;
    GdtDoc                      g;
    g.app = app;
    TDF_Label             l = d1030Make(newDoc(app), g);
    Handle(XCAFDoc_Datum) a;
    l.FindAttribute(XCAFDoc_Datum::GetID(), a);
    Handle(XCAFDimTolObjects_DatumObject) o = a->GetObject();
    printf("[87] plain datum: name=%s", o->GetName()->ToCString());
    o->SetPosition(2);
    a->SetObject(o);
    printf(", after SetPosition(2) and SetObject: position=%d\n", a->GetObject()->GetPosition());
  }
}

// [99] [100] [101] [102] Issue1056: what the raw kernel does with the tolerance pairs the bridge checks by reading back, and
// with the modifier values it clears itself ([103] [104] [105]).
static void dim1056()
{
  const double nan_ = std::nan("");
  const double pairs[3][2] = {{nan_, 0.5}, {-0.3, nan_}, {nan_, nan_}};
  for (const auto& p : pairs)
  {
    GdtDoc g;
    gdtInit(g);
    TDF_Label dl = g.t->AddDimension();
    g.t->SetDimension(g.shape, dl);
    Handle(XCAFDoc_Dimension) da;
    dl.FindAttribute(XCAFDoc_Dimension::GetID(), da);
    Handle(XCAFDimTolObjects_DimensionObject) o = new XCAFDimTolObjects_DimensionObject();
    o->SetType(XCAFDimTolObjects_DimensionType_Size_Diameter);
    Handle(TColStd_HArray1OfReal) vals = new TColStd_HArray1OfReal(1, 1);
    vals->SetValue(1, 20.0);
    o->SetValues(vals);
    bool lo = o->SetLowerTolValue(p[0]);
    bool up = o->SetUpperTolValue(p[1]);
    da->SetObject(o);
    TDF_LabelSequence dls;
    g.t->GetDimensionLabels(dls);
    Handle(XCAFDimTolObjects_DimensionObject) r = da->GetObject();
    printf("[99] raw tolerance (%g, %g) without the bridge's readback refusal: SetLower=%s SetUpper=%s, dimension labels=%d, plusMinus=%s "
           "read back (%g, %g)\n",
           p[0], p[1], tf(lo), tf(up), dls.Length(), tf(r->IsDimWithPlusMinusTolerance()), r->GetLowerTolValue(), r->GetUpperTolValue());
  }
  {  // [100]
    GdtDoc g;
    gdtInit(g);
    Handle(XCAFDoc_Dimension) da = gdtAddDim(g, XCAFDimTolObjects_DimensionType_Size_Diameter, 20.0);
    Handle(XCAFDimTolObjects_DimensionObject) o = da->GetObject();
    bool                                      lo = o->SetLowerTolValue(-0.3);
    bool                                      up = o->SetUpperTolValue(0.7);
    da->SetObject(o);
    TDF_LabelSequence dls;
    g.t->GetDimensionLabels(dls);
    Handle(XCAFDimTolObjects_DimensionObject) r = da->GetObject();
    printf("[100] tolerance (-0.3, 0.7): SetLower=%s SetUpper=%s, dimension labels=%d, plusMinus=%s value=%.17g lowerTol=%.17g upperTol=%.17g\n",
           tf(lo), tf(up), dls.Length(), tf(r->IsDimWithPlusMinusTolerance()), r->GetValue(), r->GetLowerTolValue(), r->GetUpperTolValue());
  }
  {  // [101]
    GdtDoc g;
    gdtInit(g);
    Handle(XCAFDoc_Dimension) da = gdtAddDim(g, XCAFDimTolObjects_DimensionType_Size_Diameter, 20.0);
    TDF_LabelSequence         dls;
    g.t->GetDimensionLabels(dls);
    Handle(XCAFDimTolObjects_DimensionObject) r = da->GetObject();
    printf("[101] no tolerance: dimension labels=%d, IsDimWithRange=%s IsDimWithPlusMinusTolerance=%s (so simple)\n", dls.Length(),
           tf(r->IsDimWithRange()), tf(r->IsDimWithPlusMinusTolerance()));
  }
  {  // [102] the standalone setter, raw, on a simple dimension
    GdtDoc g;
    gdtInit(g);
    Handle(XCAFDoc_Dimension) da = gdtAddDim(g, XCAFDimTolObjects_DimensionType_Size_Diameter, 20.0);
    Handle(XCAFDimTolObjects_DimensionObject) o = da->GetObject();
    bool                                      lo = o->SetLowerTolValue(nan_);
    bool                                      up = o->SetUpperTolValue(0.5);
    da->SetObject(o);
    Handle(XCAFDimTolObjects_DimensionObject) r = da->GetObject();
    printf("[102] raw SetLowerTolValue(nan) SetUpperTolValue(0.5) on a simple dimension without the readback refusal: SetLower=%s "
           "SetUpper=%s, then plusMinus=%s range=%s lowerTol=%g upperTol=%g\n",
           tf(lo), tf(up), tf(r->IsDimWithPlusMinusTolerance()), tf(r->IsDimWithRange()), r->GetLowerTolValue(), r->GetUpperTolValue());
  }
  {  // [103]
    GdtDoc g;
    gdtInit(g);
    Handle(XCAFDoc_GeomTolerance) t = gdtAddTol(g, XCAFDimTolObjects_GeomToleranceType_Position, 0.1);
    Handle(XCAFDimTolObjects_GeomToleranceObject) o = t->GetObject();
    o->SetZoneModifier(XCAFDimTolObjects_GeomToleranceZoneModif_None);
    o->SetValueOfZoneModifier(15.0);
    t->SetObject(o);
    Handle(XCAFDimTolObjects_GeomToleranceObject) r = t->GetObject();
    printf("[103] raw zone None with value 15 (the bridge writes 0 under None): read back zone=%d value=%g\n", (int)r->GetZoneModifier(),
           r->GetValueOfZoneModifier());
  }
  {  // [104]
    GdtDoc g;
    gdtInit(g);
    Handle(XCAFDoc_GeomTolerance) t = gdtAddTol(g, XCAFDimTolObjects_GeomToleranceType_Position, 0.1);
    auto write = [&](XCAFDimTolObjects_GeomToleranceZoneModif z, bool withValue, double v) {
      Handle(XCAFDimTolObjects_GeomToleranceObject) o = t->GetObject();
      o->SetZoneModifier(z);
      if (withValue)
        o->SetValueOfZoneModifier(v);
      t->SetObject(o);
    };
    auto read = [&]() {
      Handle(XCAFDimTolObjects_GeomToleranceObject) r = t->GetObject();
      static char buf[64];
      snprintf(buf, sizeof buf, "zone=%d value=%g", (int)r->GetZoneModifier(), r->GetValueOfZoneModifier());
      return std::string(buf);
    };
    write(XCAFDimTolObjects_GeomToleranceZoneModif_Projected, true, 15.0);
    std::string s1 = read();
    write(XCAFDimTolObjects_GeomToleranceZoneModif_None, true, 7.5);
    std::string s2 = read();
    write(XCAFDimTolObjects_GeomToleranceZoneModif_Projected, true, 15.0);
    write(XCAFDimTolObjects_GeomToleranceZoneModif_None, false, 0.0);
    std::string s3 = read();
    printf("[104] raw writes without the bridge's clearing: Projected 15 -> %s; None with 7.5 -> %s; Projected 15 then None with no value -> %s\n",
           s1.c_str(), s2.c_str(), s3.c_str());
  }
  {  // [105]
    GdtDoc g;
    gdtInit(g);
    Handle(XCAFDoc_Datum) d = gdtAddDatum(g, "A");
    Handle(XCAFDimTolObjects_DatumObject) o = d->GetObject();
    o->SetModifierWithValue(XCAFDimTolObjects_DatumModifWithValue_None, 15.0);
    d->SetObject(o);
    XCAFDimTolObjects_DatumModifWithValue m = XCAFDimTolObjects_DatumModifWithValue_Spherical;
    double                                v = -1;
    d->GetObject()->GetModifierWithValue(m, v);
    printf("[105] raw datum modifier None with value 15 (the bridge writes 0 under None): read back modifier=%d value=%g\n", (int)m, v);
  }
}

// [106] [107] Issue1435: datums created through the DimTolTool of XCAFDoc_DocumentTool land under Main().FindChild(4).
static void datum1435()
{
  for (int n : {1, 3})
  {
    GdtDoc g;
    gdtInit(g);
    for (int i = 0; i < n; i++)
      gdtAddDatum(g, i == 0 ? "A" : (i == 1 ? "B" : "C"));
    TDF_Label         table = g.d->Main().FindChild(4, false);
    TDF_LabelSequence xls;
    g.t->GetDatumLabels(xls);
    TCollection_AsciiString e;
    if (!table.IsNull())
      TDF_Tool::Entry(table, e);
    printf("[106] [107] after %d datum(s): Main().FindChild(4, false) null=%s entry=%s children=%d, GetDatumLabels=%d (index of the last = %d)\n",
           n, tf(table.IsNull()), e.ToCString(), table.IsNull() ? -1 : table.NbChildren(), xls.Length(), xls.Length() - 1);
  }
}

// [108] [109] [110] [111] [113] [114] [116] TDataXtd shape, triangulation and TDF label attribute tests.
static void tdfMisc()
{
  {  // [108] [109] the bridge's shape attribute: a new TDataXtd_Shape plus a TNaming_Builder Generated
    Handle(TDocStd_Application) app;
    Handle(TDocStd_Document)    d = newDoc(app);
    TDF_Label                   fresh = d->Main().NewChild();
    Handle(TDataXtd_Shape)      fa;
    printf("[109] fresh label: TDataXtd_Shape present=%s Get null=%s\n", tf(fresh.FindAttribute(TDataXtd_Shape::GetID(), fa)),
           tf(TDataXtd_Shape::Get(fresh).IsNull()));
    TDF_Label l = d->Main().NewChild();
    Handle(TDataXtd_Shape) attr = new TDataXtd_Shape();
    l.AddAttribute(attr);
    TNaming_Builder builder(l);
    builder.Generated(centredBox(10, 20, 30));
    Handle(TDataXtd_Shape) found;
    printf("[108] after the bridge's set: TDataXtd_Shape present=%s Get null=%s\n", tf(l.FindAttribute(TDataXtd_Shape::GetID(), found)),
           tf(TDataXtd_Shape::Get(l).IsNull()));
  }
  {  // [110] [111] a sphere at 1.0 and a box at 0.5, merged the way the bridge merges
    TopoDS_Shape sphere = BRepPrimAPI_MakeSphere(10).Shape();
    BRepMesh_IncrementalMesh(sphere, 1.0);
    int    nodes = 0, tris = 0;
    for (TopExp_Explorer e(sphere, TopAbs_FACE); e.More(); e.Next())
    {
      TopLoc_Location            l;
      Handle(Poly_Triangulation) t = BRep_Tool::Triangulation(TopoDS::Face(e.Current()), l);
      if (!t.IsNull())
      {
        nodes += t->NbNodes();
        tris += t->NbTriangles();
      }
    }
    printf("[110] sphere r10 at deflection 1.0: merged nodes=%d triangles=%d\n", nodes, tris);
    TopoDS_Shape box = centredBox(10, 20, 30);
    BRepMesh_IncrementalMesh(box, 0.5);
    double worst = 0;
    for (TopExp_Explorer e(box, TopAbs_FACE); e.More(); e.Next())
    {
      TopLoc_Location            l;
      Handle(Poly_Triangulation) t = BRep_Tool::Triangulation(TopoDS::Face(e.Current()), l);
      if (!t.IsNull())
        worst = std::max(worst, t->Deflection());
    }
    printf("[111] box 10x20x30 at deflection 0.5: worst face deflection=%.17g positive=%s\n", worst, tf(worst > 0));
  }
  {  // [113] [114] [116]
    Handle(TDocStd_Application) app;
    Handle(TDocStd_Document)    d = newDoc(app);
    TDF_Label                   e = d->Main().NewChild();
    int                         n = 0;
    for (TDF_AttributeIterator it(e); it.More(); it.Next())
      n++;
    TCollection_AsciiString entry;
    TDF_Tool::Entry(e, entry);
    printf("[113] the label Document.createLabel() makes (Main().NewChild(), entry %s, NbAttributes=%d): TDF_AttributeIterator count=%d\n",
           entry.ToCString(), e.NbAttributes(), n);
    Handle(TDF_DataSet) ds = new TDF_DataSet();
    ds->AddLabel(e);
    printf("[114] TDF_DataSet with a fresh label added: IsEmpty=%s\n", tf(ds->IsEmpty()));
    TDF_Label src = d->Main().NewChild();
    TDataStd_Name::Set(src, "Parent");
    TDF_Label child = src.NewChild();
    TDataStd_Name::Set(child, "Child");
    TDF_Label dst = d->Main().NewChild();
    TDF_CopyLabel cp(src, dst);
    cp.Perform();
    printf("[116] TDF_CopyLabel of a label with a child: IsDone=%s, destination HasChild=%s\n", tf(cp.IsDone()), tf(dst.HasChild()));
  }
}

// [118] [119] [120] [121] [90] [91] [92] [93] [94] [95] [96] [97] [98] transactions: TDocStd_Document command numbering and TDF_Delta.
static void txn970()
{
  auto fresh = [](Handle(TDocStd_Application)& app, int limit) {
    Handle(TDocStd_Document) d = newDoc(app);
    if (limit > 0)
      d->SetUndoLimit(limit);
    return d;
  };
  auto touch = [](const Handle(TDocStd_Document)& d, int v) { TDataStd_Integer::Set(d->Main().NewChild(), v); };
  auto open2 = [](const Handle(TDocStd_Document)& d) {
    bool threw = false;
    try
    {
      d->OpenCommand();
    }
    catch (const Standard_Failure&)
    {
      threw = true;
    }
    return threw;
  };
  {  // [91] a second transaction, never named
    Handle(TDocStd_Application) app;
    Handle(TDocStd_Document)    d = fresh(app, 10);
    d->OpenCommand();
    touch(d, 1);
    d->CommitCommand();
    d->OpenCommand();
    touch(d, 2);
    d->CommitCommand();
    printf("[91] second transaction committed: delta name=\"%s\" undos=%d\n", TCollection_AsciiString(d->GetUndos().Last()->Name()).ToCString(),
           d->GetAvailableUndos());
  }
  {  // [92] [93] a second open while one runs
    Handle(TDocStd_Application) app;
    Handle(TDocStd_Document)    d = fresh(app, 10);
    d->OpenCommand();
    int  first  = d->GetData()->Transaction();
    bool threw  = open2(d);
    int  second = d->GetData()->Transaction();
    touch(d, 1);
    d->CommitCommand();
    Handle(TDF_Delta) delta = d->GetUndos().Last();
    printf("[92] [93] first open number=%d, second open throws=%s (number still %d); committed delta name=\"%s\"", first, tf(threw), second,
           TCollection_AsciiString(delta->Name()).ToCString());
    delta->SetName(TCollection_ExtendedString("first"));
    printf("; after SetName(\"first\") name=\"%s\"\n", TCollection_AsciiString(delta->Name()).ToCString());
  }
  {  // [94] an aborted transaction, then a second one
    Handle(TDocStd_Application) app;
    Handle(TDocStd_Document)    d = fresh(app, 10);
    d->OpenCommand();
    touch(d, 1);
    d->AbortCommand();
    d->OpenCommand();
    touch(d, 2);
    d->CommitCommand();
    printf("[94] abort then a second transaction committed: delta name=\"%s\" undos=%d\n",
           TCollection_AsciiString(d->GetUndos().Last()->Name()).ToCString(), d->GetAvailableUndos());
  }
  {  // [95] [120] [121]
    Handle(TDocStd_Application) app;
    Handle(TDocStd_Document)    d = fresh(app, 10);
    d->OpenCommand();
    touch(d, 3);
    d->CommitCommand();
    Handle(TDF_Delta) delta = d->GetUndos().Last();
    printf("[95] [120] committed delta non-null=%s IsEmpty=%s attribute deltas=%d begin=%d end=%d; undo limit=%d undos=%d\n", tf(!delta.IsNull()),
           tf(delta->IsEmpty()), delta->AttributeDeltas().Extent(), delta->BeginTime(), delta->EndTime(), d->GetUndoLimit(),
           d->GetAvailableUndos());
    delta->SetName(TCollection_ExtendedString("MyDelta"));
    printf("[121] after SetName(\"MyDelta\") name=\"%s\"\n", TCollection_AsciiString(delta->Name()).ToCString());
  }
  {  // [96] [97] [98] [118] [119]
    Handle(TDocStd_Application) app;
    Handle(TDocStd_Document)    d0 = fresh(app, 0);
    int                         lim0 = d0->GetUndoLimit();
    d0->OpenCommand();
    printf("[97] [98] undo limit %d: OpenCommand -> Transaction=%d HasOpenCommand=%s\n", lim0, d0->GetData()->Transaction(),
           tf(d0->HasOpenCommand()));
    Handle(TDocStd_Application) app2;
    Handle(TDocStd_Document)    d = fresh(app2, 10);
    printf("[119] before=%d", d->GetData()->Transaction());
    d->OpenCommand();
    printf(" during=%d", d->GetData()->Transaction());
    d->CommitCommand();
    printf(" after commit=%d\n", d->GetData()->Transaction());
    d->OpenCommand();
    printf("[98] [118] undo limit 10: OpenCommand -> Transaction=%d", d->GetData()->Transaction());
    d->AbortCommand();
    printf(", after AbortCommand Transaction=%d\n", d->GetData()->Transaction());
    Handle(TDocStd_Application) app3;
    Handle(TDocStd_Document)    e = fresh(app3, 10);
    e->OpenCommand();
    open2(e);
    printf("[96] two opens: Transaction=%d", e->GetData()->Transaction());
    e->CommitCommand();
    printf(", after commit=%d\n", e->GetData()->Transaction());
  }
}

// [124]-[131] Issue443: the per-face triangulations the kernel leaves, and the frame the nodes are in.
static void tri443()
{
  auto boundsOK = [](const TopoDS_Shape& s, double defl, const char* tag) {
    BRepMesh_IncrementalMesh m(s, defl);
    Bnd_Box shapeBox;
    BRepBndLib::Add(s, shapeBox);
    double x0, y0, z0, x1, y1, z1;
    shapeBox.Get(x0, y0, z0, x1, y1, z1);
    int  nodes = 0, tris = 0, outside = 0, outsideX = 0;
    const double slack = 1e-6;
    for (TopExp_Explorer e(s, TopAbs_FACE); e.More(); e.Next())
    {
      TopLoc_Location            loc;
      Handle(Poly_Triangulation) t = BRep_Tool::Triangulation(TopoDS::Face(e.Current()), loc);
      if (t.IsNull())
        continue;
      nodes += t->NbNodes();
      tris += t->NbTriangles();
      for (int i = 1; i <= t->NbNodes(); i++)
      {
        gp_Pnt p = t->Node(i).Transformed(loc.Transformation());
        if (p.X() < x0 - slack || p.X() > x1 + slack)
          outsideX++;
        if (p.X() < x0 - slack || p.X() > x1 + slack || p.Y() < y0 - slack || p.Y() > y1 + slack || p.Z() < z0 - slack || p.Z() > z1 + slack)
          outside++;
      }
    }
    printf("%s: nodes=%d triangles=%d, shape bounds x[%g, %g] y[%g, %g] z[%g, %g], nodes outside the bounds (x, y, z)=%d, outside in x=%d\n", tag,
           nodes, tris, x0, x1, y0, y1, z0, z1, outside, outsideX);
  };
  gp_Trsf mv;
  mv.SetTranslation(gp_Vec(100, 200, 300));
  boundsOK(centredBox(10, 10, 10).Moved(TopLoc_Location(mv)), 1.0, "[128] centred box located at (100, 200, 300)");
  gp_Trsf mir;
  mir.SetMirror(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(1, 0, 0)));
  TopoDS_Shape mb = BRepBuilderAPI_Transform(BRepPrimAPI_MakeBox(gp_Pnt(10, 0, 0), 10, 10, 10).Shape(), mir, true).Shape();
  boundsOK(mb, 1.0, "[129] box at x 10..20 mirrored in x");
  {  // [130] the merged triangulation the bridge stores, indexed the way OCCTDocumentTriangulationNode indexes it
    TopoDS_Shape box = centredBox(10, 10, 10);
    BRepMesh_IncrementalMesh m(box, 1.0);
    int nodes = 0, tris = 0;
    for (TopExp_Explorer e(box, TopAbs_FACE); e.More(); e.Next())
    {
      TopLoc_Location            loc;
      Handle(Poly_Triangulation) t = BRep_Tool::Triangulation(TopoDS::Face(e.Current()), loc);
      nodes += t->NbNodes();
      tris += t->NbTriangles();
    }
    Handle(Poly_Triangulation) merged = new Poly_Triangulation(nodes, tris, Standard_False, Standard_False);
    auto raises = [&](int i) {
      try
      {
        (void)merged->Node(i);
        return false;
      }
      catch (const Standard_OutOfRange&)
      {
        return true;
      }
    };
    Handle(TDocStd_Application) app;
    Handle(TDocStd_Document)    d = newDoc(app);
    TDF_Label                   attrLess = d->Main().NewChild(), withAttr = d->Main().NewChild();
    TDataXtd_Triangulation::Set(withAttr, merged);
    Handle(TDataXtd_Triangulation) a;
    printf("[130] merged triangulation of %d nodes: Node(0) raises=%s, Node(1) raises=%s, Node(%d) raises=%s, Node(%d) raises=%s; label without the "
           "attribute has TDataXtd_Triangulation=%s, label with it=%s\n",
           merged->NbNodes(), tf(raises(0)), tf(raises(1)), nodes, tf(raises(nodes)), nodes + 1, tf(raises(nodes + 1)),
           tf(attrLess.FindAttribute(TDataXtd_Triangulation::GetID(), a)), tf(withAttr.FindAttribute(TDataXtd_Triangulation::GetID(), a)));
  }
  {  // [131] a sphere exported to GLB and read back by RWGltf_CafReader (what Shape.loadGLTF does)
    TopoDS_Shape sphere = BRepPrimAPI_MakeSphere(10).Shape();
    const char*  path   = "/tmp/766-xcaf-evidence-fix-443.glb";
    {
      BRepMesh_IncrementalMesh    mesher(sphere, 0.5);
      Handle(TDocStd_Application) app;
      Handle(TDocStd_Document)    d = newDoc(app);
      XCAFDoc_DocumentTool::ShapeTool(d->Main())->AddShape(sphere);
      RWGltf_CafWriter writer(TCollection_AsciiString(path), true);
      NCollection_IndexedDataMap<TCollection_AsciiString, TCollection_AsciiString> info;
      writer.Perform(d, info, Message_ProgressRange());
    }
    Handle(TDocStd_Application) app;
    Handle(TDocStd_Document)    d = newDoc(app);
    RWGltf_CafReader            reader;
    reader.SetDocument(d);
    bool         ok   = reader.Perform(TCollection_AsciiString(path), Message_ProgressRange());
    TopoDS_Shape imp  = XCAFDoc_DocumentTool::ShapeTool(d->Main())->GetOneShape();
    int          hasN = 0, faces = 0, checked = 0, outward = 0;
    double       firstLen = -1;
    for (TopExp_Explorer e(imp, TopAbs_FACE); e.More(); e.Next())
    {
      TopoDS_Face                face = TopoDS::Face(e.Current());
      TopLoc_Location            loc;
      Handle(Poly_Triangulation) t = BRep_Tool::Triangulation(face, loc);
      if (t.IsNull())
        continue;
      faces++;
      if (!t->HasNormals())
        continue;
      hasN++;
      for (int i = 1; i <= t->NbNodes() && checked < 200; i++)
      {
        gp_Dir n = t->Normal(i);
        if (firstLen < 0)
          firstLen = std::sqrt(n.X() * n.X() + n.Y() * n.Y() + n.Z() * n.Z());
        if (face.Orientation() == TopAbs_REVERSED)
          n.Reverse();
        n.Transform(loc.Transformation());
        gp_Pnt p = t->Node(i).Transformed(loc.Transformation());
        double r = std::sqrt(p.X() * p.X() + p.Y() * p.Y() + p.Z() * p.Z());
        if (r > 1e-6)
        {
          checked++;
          if (n.X() * p.X() / r + n.Y() * p.Y() / r + n.Z() * p.Z() / r > 0.5)
            outward++;
        }
      }
    }
    printf("[131] glTF import: Perform=%s, faces with a triangulation=%d, of which with normals=%d, first normal length=%.17g, nodes checked=%d of which "
           "the normal points outward (dot > 0.5)=%d; the BRepMesh sphere carries normals=false (see the #443 transcript)\n",
           tf(ok), faces, hasN, firstLen, checked, outward);
  }
}

// ---- KEYS group 4: style and material equality, matrices, note and view objects, ShapeTool queries, TDataXtd, TFunction, TObj --------------
// One document per test, as each test has; Document.createLabel() is Main().NewChild(), which on an XCAF document is 0:1:1.
static void vis134()
{
  {  // [133] the test's style: surface colour red, invisible, against a visible copy
    XCAFPrs_Style a, b;
    a.SetColorSurf(Quantity_ColorRGBA(Quantity_Color(1, 0, 0, Quantity_TOC_sRGB), 1.0f));
    a.SetVisibility(false);
    b = a;
    b.SetVisibility(true);
    printf("[133] invisible red-surface style vs its visible copy: IsEqual=%s (control, the style against itself: %s)\n", tf(a.IsEqual(b)),
           tf(a.IsEqual(a)));
  }
  {  // [134] the test's common material: diffuse red, shininess 0.5, transparency 0.3, against shininess 0.6
    XCAFDoc_VisMaterialCommon ma;
    ma.DiffuseColor = Quantity_Color(1, 0, 0, Quantity_TOC_sRGB);
    ma.Shininess    = 0.5f;
    ma.Transparency = 0.3f;
    ma.IsDefined    = true;
    XCAFDoc_VisMaterialCommon mb = ma;
    mb.Shininess                 = 0.6f;
    printf("[134] common material shininess 0.5 vs 0.6: IsEqual=%s (control, the material against itself: %s)\n", tf(ma.IsEqual(mb)),
           tf(ma.IsEqual(ma)));
  }
  {  // [136] the test's PBR material: metallic 0, roughness 0.5, base colour (0.8, 0.2, 0.1), against roughness 0.6
    XCAFDoc_VisMaterialPBR pa;
    pa.BaseColor = Quantity_ColorRGBA(Quantity_Color(0.8, 0.2, 0.1, Quantity_TOC_sRGB), 1.0f);
    pa.Metallic  = 0.0f;
    pa.Roughness = 0.5f;
    pa.IsDefined = true;
    XCAFDoc_VisMaterialPBR pb = pa;
    pb.Roughness              = 0.6f;
    printf("[136] PBR material roughness 0.5 vs 0.6: IsEqual=%s (control, the material against itself: %s)\n", tf(pa.IsEqual(pb)),
           tf(pa.IsEqual(pa)));
  }
}

// [138] XCAFComponentMatrixTests: a 4x2x1 part, an assembly made with AddShape(box, true), a rigid and a reflection component placed with the
// bridge's grouped matrix layout (nine rotation values, then three translations).
static TopLoc_Location grouped(const double* m)
{
  gp_Trsf t;
  t.SetValues(m[0], m[1], m[2], m[9], m[3], m[4], m[5], m[10], m[6], m[7], m[8], m[11]);
  return TopLoc_Location(t);
}

static void matrix138()
{
  Handle(TDocStd_Application) app;
  Handle(TDocStd_Document)    d  = newDoc(app);
  Handle(XCAFDoc_ShapeTool)   st = XCAFDoc_DocumentTool::ShapeTool(d->Main());
  TDF_Label                   part = st->AddShape(centredBox(4, 2, 1), false);
  TDF_Label                   asmL = st->AddShape(centredBox(1, 1, 1), true);
  const double                rigid[12]   = {0, -1, 0, 1, 0, 0, 0, 0, 1, 10, 20, 30};
  const double                reflect[12] = {-1, 0, 0, 0, 1, 0, 0, 0, 1, 5, 0, 0};
  TDF_Label                   c1          = st->AddComponent(asmL, part, grouped(rigid));
  TDF_Label                   c2          = st->AddComponent(asmL, part, grouped(reflect));
  printf("[138] rigid component null=%s, reflection component null=%s, NbComponents=%d\n", tf(c1.IsNull()), tf(c2.IsNull()),
         XCAFDoc_ShapeTool::NbComponents(asmL));
}

// [139] XCAFDocAssemblyGraphTests.createFromDocument: a graph over a document that holds only the label createLabel makes.
static void graph139()
{
  Handle(TDocStd_Application) app;
  Handle(TDocStd_Document)    d = newDoc(app);
  d->Main().NewChild();
  Handle(XCAFDoc_AssemblyGraph) g = new XCAFDoc_AssemblyGraph(d);
  printf("[139] XCAFDoc_AssemblyGraph over a document with no shape: non-null=%s nodes=%d links=%d roots=%d\n", tf(!g.IsNull()), g->NbNodes(),
         g->NbLinks(), g->GetRoots().Extent());
}

// [140] [141] XCAFDocAssemblyItemIdTests, built from a string as OCCTAssemblyItemIdIsValid / PathCount do.
static void itemId()
{
  XCAFDoc_AssemblyItemId a(TCollection_AsciiString("0:1:1:1/0:1:1:2"));
  XCAFDoc_AssemblyItemId e(TCollection_AsciiString(""));
  printf("[140] AssemblyItemId(\"0:1:1:1/0:1:1:2\"): IsNull=%s path size=%d\n", tf(a.IsNull()), (int)a.GetPath().Size());
  printf("[141] AssemblyItemId(\"\"): IsNull=%s\n", tf(e.IsNull()));
}

// [143]-[148] XCAFNoteObjects_NoteObject and XCAFView_Object, through the calls the bridge makes.
static void noteView()
{
  Handle(XCAFNoteObjects_NoteObject) n = new XCAFNoteObjects_NoteObject();
  printf("[143] NoteObject created non-null=%s\n", tf(!n.IsNull()));
  Handle(XCAFNoteObjects_NoteObject) p = new XCAFNoteObjects_NoteObject();
  p->SetPlane(gp_Ax2(gp_Pnt(1, 2, 3), gp_Dir(0, 0, 1)));
  printf("[144] SetPlane(origin (1, 2, 3), normal (0, 0, 1)): HasPlane=%s origin.x=%.17g\n", tf(p->HasPlane()), p->GetPlane().Location().X());
  Handle(XCAFNoteObjects_NoteObject) q = new XCAFNoteObjects_NoteObject();
  q->SetPoint(gp_Pnt(10, 20, 30));
  printf("[145] SetPoint(10, 20, 30): HasPoint=%s point.x=%.17g\n", tf(q->HasPoint()), q->GetPoint().X());
  Handle(XCAFView_Object) v = new XCAFView_Object();
  printf("[146] ViewObject created non-null=%s\n", tf(!v.IsNull()));
  printf("[147] SetType(Central) -> %d", (v->SetType(XCAFView_ProjectionType_Central), (int)v->Type()));
  v->SetType(XCAFView_ProjectionType_Parallel);
  printf(", SetType(Parallel) -> %d", (int)v->Type());
  v->SetType(XCAFView_ProjectionType_NoCamera);
  printf(", SetType(NoCamera) -> %d\n", (int)v->Type());
  printf("[148] raw values written with a bare cast and read back:");
  for (int raw : {0, 1, 2})
  {
    v->SetType((XCAFView_ProjectionType)raw);
    printf(" %d -> %d", raw, (int)v->Type());
  }
  printf(" (XCAFView_ProjectionType NoCamera=%d Parallel=%d Central=%d)\n", (int)XCAFView_ProjectionType_NoCamera,
         (int)XCAFView_ProjectionType_Parallel, (int)XCAFView_ProjectionType_Central);
}

// [149] [150] [151] XDEShapeToolQueryTests: a document holding one box added with AddShape(box, true).
static void shapeQueries()
{
  Handle(TDocStd_Application) app;
  Handle(TDocStd_Document)    d  = newDoc(app);
  Handle(XCAFDoc_ShapeTool)   st = XCAFDoc_DocumentTool::ShapeTool(d->Main());
  TopoDS_Shape                box = centredBox(10, 20, 30);
  st->AddShape(box, true);
  TDF_LabelSequence all, freeS;
  st->GetShapes(all);
  st->GetFreeShapes(freeS);
  TDF_Label f1, f2;
  bool      found = st->FindShape(box, f1), searched = st->Search(box, f2);
  printf("[149] [150] [151] one box added: GetShapes=%d GetFreeShapes=%d FindShape=%s (label non-null=%s) Search=%s (label non-null=%s)\n",
         all.Length(), freeS.Length(), tf(found), tf(!f1.IsNull()), tf(searched), tf(!f2.IsNull()));
}

// [152] [153] [154] [155] [156] [157] [158] [178] TDataXtd and TDocStd attributes on the label the test makes.
static void xtdAttrs()
{
  {  // [152] [178] setXLink(at: 1) and setVariable(at: 1): getLabelForTag(1) is Main().FindChild(1, true)
    Handle(TDocStd_Application) app;
    Handle(TDocStd_Document)    d = newDoc(app);
    printf("[152] TDocStd_XLink::Set on the tag-1 label: non-null=%s\n", tf(!TDocStd_XLink::Set(tagLabel(d, 1)).IsNull()));
    Handle(TDocStd_Application) app2;
    Handle(TDocStd_Document)    d2 = newDoc(app2);
    printf("[178] TDataStd_Variable::Set on the tag-1 label: non-null=%s\n", tf(!TDataStd_Variable::Set(tagLabel(d2, 1)).IsNull()));
  }
  {  // [153]
    Handle(TDocStd_Application) app;
    Handle(TDocStd_Document)    d = newDoc(app);
    TDF_Label                   l = d->Main().NewChild();
    Handle(TDataXtd_Constraint) c;
    printf("[153] created label: TDataXtd_Constraint present=%s\n", tf(l.FindAttribute(TDataXtd_Constraint::GetID(), c)));
  }
  {  // [154] [155] [156]
    Handle(TDocStd_Application) app;
    Handle(TDocStd_Document)    d = newDoc(app);
    printf("[154] TDataXtd_Point::Set((5, 10, 15)) non-null=%s\n", tf(!TDataXtd_Point::Set(d->Main().NewChild(), gp_Pnt(5, 10, 15)).IsNull()));
    Handle(TDocStd_Application) app2;
    Handle(TDocStd_Document)    d2 = newDoc(app2);
    printf("[155] TDataXtd_Axis::Set(origin (0, 0, 0), direction (0, 0, 1)) non-null=%s\n",
           tf(!TDataXtd_Axis::Set(d2->Main().NewChild(), gp_Lin(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1))).IsNull()));
    Handle(TDocStd_Application) app3;
    Handle(TDocStd_Document)    d3 = newDoc(app3);
    printf("[156] TDataXtd_Plane::Set(origin (0, 0, 0), normal (0, 0, 1)) non-null=%s\n",
           tf(!TDataXtd_Plane::Set(d3->Main().NewChild(), gp_Pln(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1))).IsNull()));
  }
  {  // [157]
    Handle(TDocStd_Application) app;
    Handle(TDocStd_Document)    d = newDoc(app);
    TDF_Label                   l = d->Main().NewChild();
    Handle(TDataXtd_Geometry)   g = TDataXtd_Geometry::Set(l);
    Handle(TDataXtd_Geometry)   r;
    printf("[157] TDataXtd_Geometry attribute present=%s; SetType then GetType:", tf(l.FindAttribute(TDataXtd_Geometry::GetID(), r)));
    for (TDataXtd_GeometryEnum e : {TDataXtd_POINT, TDataXtd_PLANE, TDataXtd_CYLINDER})
    {
      g->SetType(e);
      l.FindAttribute(TDataXtd_Geometry::GetID(), r);
      printf(" %d -> %d", (int)e, (int)r->GetType());
    }
    printf("\n");
  }
  {  // [158] all eight types, each on its own created label of one document
    Handle(TDocStd_Application) app;
    Handle(TDocStd_Document)    d = newDoc(app);
    printf("[158] TDataXtd_Geometry SetType then GetType for ordinals 0..7:");
    for (int i = 0; i <= 7; i++)
    {
      TDF_Label                 l = d->Main().NewChild();
      Handle(TDataXtd_Geometry) g = TDataXtd_Geometry::Set(l);
      g->SetType((TDataXtd_GeometryEnum)i);
      Handle(TDataXtd_Geometry) r;
      l.FindAttribute(TDataXtd_Geometry::GetID(), r);
      printf(" %d -> %d", i, (int)r->GetType());
    }
    printf("\n");
  }
}

// [163] [164] TextLabelAndPointCloudTests: the height AIS_TextLabel reports, as OCCTTextLabelGetInfo reads it.
static void textHeight()
{
  Handle(AIS_TextLabel) t = new AIS_TextLabel();
  t->SetText(TCollection_ExtendedString("Test", Standard_True));
  printf("[163] AIS_TextLabel default Attributes()->TextAspect()->Height()=%.17g\n", t->Attributes()->TextAspect()->Height());
  t->SetHeight(30.0);
  printf("[164] after SetHeight(30): Attributes()->TextAspect()->Height()=%.17g\n", t->Attributes()->TextAspect()->Height());
}

// [169] [170] TFunctionGraphNodeTests: TFunction_GraphNode::Set on the created label, SetStatus, GetStatus.
static void graphNode()
{
  {
    Handle(TDocStd_Application) app;
    Handle(TDocStd_Document)    d = newDoc(app);
    TDF_Label                   l = d->Main().NewChild();
    Handle(TFunction_GraphNode) g = TFunction_GraphNode::Set(l);
    g->SetStatus(TFunction_ES_NotExecuted);
    int first = (int)g->GetStatus();
    g->SetStatus(TFunction_ES_Succeeded);
    printf("[169] SetStatus(NotExecuted) -> GetStatus=%d, SetStatus(Succeeded) -> GetStatus=%d\n", first, (int)g->GetStatus());
  }
  {
    Handle(TDocStd_Application) app;
    Handle(TDocStd_Document)    d = newDoc(app);
    printf("[170] TFunction_GraphNode SetStatus then GetStatus for the five statuses:");
    for (TFunction_ExecutionStatus s : {TFunction_ES_WrongDefinition, TFunction_ES_NotExecuted, TFunction_ES_Executing, TFunction_ES_Succeeded,
                                        TFunction_ES_Failed})
    {
      TDF_Label                   l = d->Main().NewChild();
      Handle(TFunction_GraphNode) g = TFunction_GraphNode::Set(l);
      g->SetStatus(s);
      printf(" %d -> %d", (int)s, (int)g->GetStatus());
    }
    printf("\n");
  }
}

// [177] TObjApplicationTests.createDocument: OCCTTObjApplicationCreateDocument calls CreateNewDocument(doc, "BinOcaf").
static void tobjDoc()
{
  Handle(TObj_Application) a = TObj_Application::GetInstance();
  Handle(TDocStd_Document) doc;
  bool ok = a->CreateNewDocument(doc, TCollection_ExtendedString("BinOcaf"));
  printf("[177] TObj_Application::CreateNewDocument(doc, \"BinOcaf\")=%s, document non-null=%s\n", tf(ok), tf(!doc.IsNull()));
}

// ---- KEYS group 4b: TNaming, one document per test, records made the way OCCTDocumentNamingRecord makes them (no command open) ------------
static void nRec(const TDF_Label& l, int evo, const TopoDS_Shape& oldS, const TopoDS_Shape& newS)
{
  TNaming_Builder b(l);
  if (evo == 0)
    b.Generated(newS);
  else if (evo == 1)
    b.Generated(oldS, newS);
  else
    b.Modify(oldS, newS);
}

static const char* evoName(TNaming_Evolution e)
{
  switch (e)
  {
    case TNaming_PRIMITIVE: return "PRIMITIVE";
    case TNaming_GENERATED: return "GENERATED";
    case TNaming_MODIFY: return "MODIFY";
    case TNaming_DELETE: return "DELETE";
    case TNaming_SELECTED: return "SELECTED";
    case TNaming_REPLACE: return "REPLACE";
  }
  return "?";
}

static TopoDS_Shape nSphere(double r) { return BRepPrimAPI_MakeSphere(r).Shape(); }

static void naming179()
{
  {  // [179] [180]
    Handle(TDocStd_Application) app;
    Handle(TDocStd_Document)    d = newDoc(app);
    TDF_Label                   l = d->Main().NewChild();
    printf("[179] Main().NewChild() null=%s\n", tf(l.IsNull()));
    Handle(TDocStd_Application) app2;
    Handle(TDocStd_Document)    d2 = newDoc(app2);
    TDF_Label                   p  = d2->Main().NewChild();
    TDF_Label                   c  = p.NewChild();
    printf("[180] child of a created label: NewChild() null=%s\n", tf(c.IsNull()));
  }
  TopoDS_Shape box = centredBox(10, 10, 10);
  {  // [181] [182] [183] [185] the primitive record
    Handle(TDocStd_Application) app;
    Handle(TDocStd_Document)    d = newDoc(app);
    TDF_Label                   l = d->Main().NewChild();
    nRec(l, 0, TopoDS_Shape(), box);
    Handle(TNaming_NamedShape) ns;
    bool                       has = l.FindAttribute(TNaming_NamedShape::GetID(), ns);
    printf("[181] primitive record: TNaming_NamedShape present=%s evolution=%s\n", tf(has), has ? evoName(ns->Evolution()) : "-");
    TopoDS_Shape cur = TNaming_Tool::CurrentShape(ns);
    printf("[182] CurrentShape non-null=%s IsSame(box)=%s\n", tf(!cur.IsNull()), tf(cur.IsSame(box)));
    TopoDS_Shape st = TNaming_Tool::GetShape(ns);
    printf("[183] GetShape non-null=%s IsSame(box)=%s\n", tf(!st.IsNull()), tf(st.IsSame(box)));
    int  h = 0;
    bool hasOld = false, hasNew = false;
    for (TNaming_Iterator it(ns); it.More(); it.Next(), h++)
    {
      hasOld = !it.OldShape().IsNull();
      hasNew = !it.NewShape().IsNull();
    }
    printf("[185] TNaming_Iterator: entries=%d hasOld=%s hasNew=%s\n", h, tf(hasOld), tf(hasNew));
  }
  {  // [184]
    Handle(TDocStd_Application) app;
    Handle(TDocStd_Document)    d = newDoc(app);
    TDF_Label                   l = d->Main().NewChild();
    Handle(TNaming_NamedShape)  ns;
    printf("[184] created label: TNaming_NamedShape present=%s\n", tf(l.FindAttribute(TNaming_NamedShape::GetID(), ns)));
  }
  {  // [186] [188] primitive then modify on one label
    Handle(TDocStd_Application) app;
    Handle(TDocStd_Document)    d = newDoc(app);
    TDF_Label                   l = d->Main().NewChild();
    nRec(l, 0, TopoDS_Shape(), box);
    nRec(l, 2, box, nSphere(5));
    Handle(TNaming_NamedShape) ns;
    l.FindAttribute(TNaming_NamedShape::GetID(), ns);
    TopoDS_Shape cur = TNaming_Tool::CurrentShape(ns);
    int          h   = 0;
    for (TNaming_Iterator it(ns); it.More(); it.Next())
      h++;
    printf("[186] [188] primitive(box) then modify(box -> sphere): evolution=%s CurrentShape non-null=%s history entries=%d\n",
           evoName(ns->Evolution()), tf(!cur.IsNull()), h);
  }
  {  // [187] generated with an old and a new shape
    Handle(TDocStd_Application) app;
    Handle(TDocStd_Document)    d = newDoc(app);
    TDF_Label                   l = d->Main().NewChild();
    nRec(l, 1, centredBox(1, 1, 1), centredBox(5, 5, 1));
    Handle(TNaming_NamedShape) ns;
    l.FindAttribute(TNaming_NamedShape::GetID(), ns);
    int  h = 0;
    bool hasOld = false, hasNew = false;
    for (TNaming_Iterator it(ns); it.More(); it.Next(), h++)
    {
      hasOld = !it.OldShape().IsNull();
      hasNew = !it.NewShape().IsNull();
    }
    printf("[187] generated(old, new): evolution=%s entries=%d hasOld=%s hasNew=%s\n", evoName(ns->Evolution()), h, tf(hasOld), tf(hasNew));
  }
}

static void naming189()
{
  for (int i = 0; i < 2; i++)
  {
    TopoDS_Shape s = i == 0 ? centredBox(10, 20, 30) : nSphere(5);
    TColStd_IndexedDataMapOfTransientTransient map;
    TopoDS_Shape                               copy;
    TNaming_CopyShape::CopyTool(s, map, copy);
    printf("[%d] TNaming_CopyShape of a %s: non-null=%s BRepCheck_Analyzer valid=%s IsSame(source)=%s\n", 189 + i, i == 0 ? "box" : "sphere",
           tf(!copy.IsNull()), tf(!copy.IsNull() && BRepCheck_Analyzer(copy).IsValid()), tf(!copy.IsNull() && copy.IsSame(s)));
  }
  {  // [205]
    TopoDS_Shape       box = centredBox(10, 20, 30);
    TNaming_Translator tr;
    tr.Add(box);
    tr.Perform();
    TopoDS_Shape copy = tr.Copied(box);
    printf("[205] TNaming_Translator: IsDone=%s copy non-null=%s BRepCheck_Analyzer valid=%s IsSame(source)=%s\n", tf(tr.IsDone()),
           tf(!copy.IsNull()), tf(!copy.IsNull() && BRepCheck_Analyzer(copy).IsValid()), tf(!copy.IsNull() && copy.IsSame(box)));
  }
}

static void naming191()
{
  TopoDS_Shape box = centredBox(10, 20, 30);
  {  // [191]
    Handle(TDocStd_Application) app;
    Handle(TDocStd_Document)    d = newDoc(app);
    TDF_Label                   l = d->Main().NewChild();
    Handle(TNaming_NamedShape)  ns;
    printf("[191] created label: TNaming_NamedShape present=%s\n", tf(l.FindAttribute(TNaming_NamedShape::GetID(), ns)));
  }
  {  // [192]
    Handle(TDocStd_Application) app;
    Handle(TDocStd_Document)    d = newDoc(app);
    TDF_Label                   l = d->Main().NewChild();
    nRec(l, 0, TopoDS_Shape(), box);
    Handle(TNaming_NamedShape) ns;
    l.FindAttribute(TNaming_NamedShape::GetID(), ns);
    printf("[192] primitive: TNaming_Tool::OriginalShape null=%s\n", tf(TNaming_Tool::OriginalShape(ns).IsNull()));
  }
  {  // [193]
    Handle(TDocStd_Application) app;
    Handle(TDocStd_Document)    d  = newDoc(app);
    TDF_Label                   l1 = d->Main().NewChild(), l2 = d->Main().NewChild();
    TopoDS_Shape                sp = nSphere(5);
    nRec(l1, 0, TopoDS_Shape(), box);
    nRec(l2, 2, box, sp);
    Handle(TNaming_NamedShape) ns;
    l2.FindAttribute(TNaming_NamedShape::GetID(), ns);
    TopoDS_Shape orig = TNaming_Tool::OriginalShape(ns);
    printf("[193] modify(box -> sphere) on the second label: OriginalShape non-null=%s IsSame(box)=%s\n", tf(!orig.IsNull()),
           tf(!orig.IsNull() && orig.IsSame(box)));
  }
  {  // [194] [195] [196] [197]
    Handle(TDocStd_Application) app;
    Handle(TDocStd_Document)    d  = newDoc(app);
    TDF_Label                   l1 = d->Main().NewChild(), l2 = d->Main().NewChild();
    nRec(l1, 0, TopoDS_Shape(), box);
    int  order = 0;
    TDF_Label found = TNaming_Tool::Label(d->Main(), box, order);
    printf("[194] one primitive record: TNaming_Tool::Label null=%s IsEqual(record label)=%s\n", tf(found.IsNull()),
           tf(!found.IsNull() && found.IsEqual(l1)));
    printf("[195] TNaming_Tool::ValidUntil=%d\n", TNaming_Tool::ValidUntil(d->Main(), box));
    nRec(l2, 0, TopoDS_Shape(), box);
    int same = 0;
    for (TNaming_SameShapeIterator it(box, d->Main()); it.More(); it.Next())
      same++;
    printf("[196] [197] two primitive records of the box: TNaming_SameShapeIterator labels=%d\n", same);
  }
}

static void tracing198()
{
  auto count = [](const char* tag, const TopoDS_Shape& from, const TDF_Label& scope, const TopoDS_Shape& other, bool fwd) {
    int  n = 0;
    bool includesOther = false, threw = false;
    try
    {
      if (fwd)
        for (TNaming_NewShapeIterator it(from, scope); it.More(); it.Next(), n++)
          includesOther = includesOther || it.Shape().IsSame(other);
      else
        for (TNaming_OldShapeIterator it(from, scope); it.More(); it.Next(), n++)
          includesOther = includesOther || it.Shape().IsSame(other);
    }
    catch (const Standard_Failure&)
    {
      threw = true;
    }
    printf("%s: %s trace count=%d includes %s=%s threw=%s\n", tag, fwd ? "forward" : "backward", n, fwd ? "the source" : "itself",
           tf(includesOther), tf(threw));
  };
  TopoDS_Shape box = centredBox(10, 10, 10);
  {  // [198] [203]
    Handle(TDocStd_Application) app;
    Handle(TDocStd_Document)    d  = newDoc(app);
    TDF_Label                   l1 = d->Main().NewChild(), l2 = d->Main().NewChild();
    TopoDS_Shape                sp = nSphere(5);
    nRec(l1, 0, TopoDS_Shape(), box);
    nRec(l2, 1, box, sp);
    count("[198] [203] primitive(box) + generated(box -> sphere)", box, l1, box, true);
    count("[199] [204] same document, from the sphere", sp, l2, sp, false);
  }
  {  // [200]
    Handle(TDocStd_Application) app;
    Handle(TDocStd_Document)    d  = newDoc(app);
    TDF_Label                   l1 = d->Main().NewChild(), l2 = d->Main().NewChild(), l3 = d->Main().NewChild();
    nRec(l1, 0, TopoDS_Shape(), box);
    nRec(l2, 1, box, nSphere(5));
    nRec(l3, 1, box, BRepPrimAPI_MakeCylinder(3, 8).Shape());
    count("[200] box generating a sphere and a cylinder", box, l1, box, true);
  }
  {  // [201]
    Handle(TDocStd_Application) app;
    Handle(TDocStd_Document)    d = newDoc(app);
    TDF_Label                   l1 = d->Main().NewChild();
    nRec(l1, 0, TopoDS_Shape(), box);
    TopoDS_Shape unrelated = nSphere(7);
    printf("[201] unrelated sphere: TNaming_Tool::HasLabel=%s; ", tf(TNaming_Tool::HasLabel(d->Main(), unrelated)));
    count("forward from it", unrelated, l1, box, true);
  }
  {  // [202]
    Handle(TDocStd_Application) app;
    Handle(TDocStd_Document)    d = newDoc(app);
    TDF_Label                   l = d->Main().NewChild();
    nRec(l, 0, TopoDS_Shape(), box);
    nRec(l, 2, box, nSphere(5));
    count("[202] primitive(box) then modify(box -> sphere) on one label", box, l, box, true);
  }
}

// ---- KEYS group 4c: assembly iterator, colour NOC, graph node, shape map tool -----------------------------------------------------
// [206] [207] OCCTDocumentAssemblyItemCount: XCAFDoc_AssemblyIterator over the document, bounded at 100000 items.
static int assemblyItems(int boxes)
{
  Handle(TDocStd_Application) app;
  Handle(TDocStd_Document)    d  = newDoc(app);
  Handle(XCAFDoc_ShapeTool)   st = XCAFDoc_DocumentTool::ShapeTool(d->Main());
  for (int i = 1; i <= boxes; i++)
    st->AddShape(centredBox(boxes == 1 ? 10 : i, 1, 1), true);
  int count = 0;
  for (XCAFDoc_AssemblyIterator it(d, INT_MAX); it.More(); it.Next())
    count++;
  return count;
}

static void lastRecords()
{
  printf("[206] one box added with AddShape(box, true): XCAFDoc_AssemblyIterator items=%d (limit 100000 not reached=%s)\n", assemblyItems(1),
         tf(assemblyItems(1) < 100000));
  printf("[207] three boxes added: XCAFDoc_AssemblyIterator items=%d (limit 100000 not reached=%s)\n", assemblyItems(3),
         tf(assemblyItems(3) < 100000));
  {  // [208]
    Handle(TDocStd_Application) app;
    Handle(TDocStd_Document)    d = newDoc(app);
    TDF_Label                   l = d->Main().NewChild();
    Handle(XCAFDoc_Color)       c = XCAFDoc_Color::Set(l, Quantity_Color(1.0, 0.0, 0.0, Quantity_TOC_RGB));
    printf("[208] XCAFDoc_Color::Set(red) non-null=%s GetNOC=%d\n", tf(!c.IsNull()), (int)c->GetNOC());
  }
  {  // [210] the test's calls: l1 SetChild(l2), l2 SetFather(l1), then IsFather(l1 -> l2), IsChild(l2 -> l1) and l1's child count
    Handle(TDocStd_Application) app;
    Handle(TDocStd_Document)    d  = newDoc(app);
    TDF_Label                   l1 = d->Main().NewChild(), l2 = d->Main().NewChild();
    Handle(XCAFDoc_GraphNode)   n1 = XCAFDoc_GraphNode::Set(l1), n2 = XCAFDoc_GraphNode::Set(l2);
    n1->SetChild(n2);
    n2->SetFather(n1);
    printf("[210] n1 IsFather(n2)=%s, n2 IsChild(n1)=%s, n1 NbChildren=%d\n", tf(n1->IsFather(n2)), tf(n2->IsChild(n1)), n1->NbChildren());
  }
  {  // [213] the test's calls: XCAFDoc_ShapeMapTool::Set on the created label, SetShape(box), IsSubShape(first face), extent
    Handle(TDocStd_Application) app;
    Handle(TDocStd_Document)    d   = newDoc(app);
    TDF_Label                   l   = d->Main().NewChild();
    Handle(XCAFDoc_ShapeMapTool) smt = XCAFDoc_ShapeMapTool::Set(l);
    TopoDS_Shape                box = centredBox(10, 20, 30);
    smt->SetShape(box);
    TopExp_Explorer fe(box, TopAbs_FACE);
    printf("[213] ShapeMapTool::Set non-null=%s, IsSubShape(first face)=%s, extent=%d\n", tf(!smt.IsNull()), tf(smt->IsSubShape(fe.Current())),
           smt->GetMap().Extent());
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
  datum1030();
  dim1056();
  datum1435();
  tdfMisc();
  txn970();
  tri443();
  vis134();
  matrix138();
  graph139();
  itemId();
  noteView();
  shapeQueries();
  xtdAttrs();
  textHeight();
  graphNode();
  tobjDoc();
  naming179();
  naming189();
  naming191();
  tracing198();
  lastRecords();
  return 0;
}
