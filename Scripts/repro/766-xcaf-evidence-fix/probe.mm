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

int main()
{
  textLabel();
  pbrEquality();
  itemRefOrphan();
  iFunction();
  freshLabelAttrs();
  roughnessFallback();
  return 0;
}
