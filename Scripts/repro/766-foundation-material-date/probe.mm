// Epic #766, OCCTFoundationTests.swift "Material OCCT Operations Tests" (14 tests) and
// "OCCTDate Tests" (12 tests): kernel parity. Same inputs as the Swift tests, straight to
// Graphic3d_MaterialAspect / Graphic3d_PBRMaterial (the OCCTMaterial* bridge functions) and
// Quantity_Date / Quantity_Period (the OCCTDate* / OCCTPeriod* bridge functions), with the
// bridge's own epoch-offset encoding reproduced where the bridge adds one.
#include <Graphic3d_MaterialAspect.hxx>
#include <Graphic3d_PBRMaterial.hxx>
#include <Quantity_Color.hxx>
#include <Quantity_Date.hxx>
#include <Quantity_Period.hxx>
#include <cstdio>

static void mat(const char* label, const Graphic3d_MaterialAspect& m)
{
  const Graphic3d_PBRMaterial& p = m.PBRMaterial();
  printf("%s: name=[%s] isPhysic=%d shininess=%.9g transparency=%.9g ambient.r=%.9g diffuse.r=%.9g "
         "specular.r=%.9g pbrMetallic=%.9g pbrNormalizedRoughness=%.9g pbrRoughness(remapped)=%.9g pbrIOR=%.9g\n",
         label, m.StringName().ToCString(), (int)(m.MaterialType() == Graphic3d_MATERIAL_PHYSIC), m.Shininess(),
         m.Transparency(), m.AmbientColor().Red(), m.DiffuseColor().Red(), m.SpecularColor().Red(),
         p.Metallic(), p.NormalizedRoughness(), p.Roughness(), p.IOR());
}

static void date(const char* label, const Quantity_Date& d)
{
  int mm, dd, yy, hh, mn, ss, mis, mics;
  d.Values(mm, dd, yy, hh, mn, ss, mis, mics);
  printf("%s: %04d-%02d-%02d %02d:%02d:%02d ms=%d us=%d\n", label, yy, mm, dd, hh, mn, ss, mis, mics);
}

int main()
{
  // ---- Material OCCT Operations Tests
  int n = Graphic3d_MaterialAspect::NumberOfMaterials();
  printf("NumberOfMaterials=%d\n", n);
  printf("MaterialName(1)=[%s]\n", Graphic3d_MaterialAspect::MaterialName(1));
  Graphic3d_NameOfMaterial nom;
  for (const char* name : {"Brass", "Gold", "Copper", "Water"})
  {
    bool ok = Graphic3d_MaterialAspect::MaterialFromName(name, nom);
    printf("MaterialFromName(%s): ok=%d enum=%d\n", name, ok, (int)nom);
    if (ok)
      mat(name, Graphic3d_MaterialAspect(nom));
  }
  printf("MaterialFromName(NOT_A_MATERIAL_XYZ): ok=%d\n",
         Graphic3d_MaterialAspect::MaterialFromName("NOT_A_MATERIAL_XYZ", nom));
  // OCCTMaterialFromIndex(1) constructs Graphic3d_NameOfMaterial(index - 1)
  mat("index 1 (enum 0)", Graphic3d_MaterialAspect((Graphic3d_NameOfMaterial)0));
  printf("MinRoughness=%.9g\n", Graphic3d_PBRMaterial::MinRoughness());
  Quantity_Color white(1, 1, 1, Quantity_TOC_RGB);
  printf("RoughnessFromSpecular(white, 0.8)=%.9g\n", Graphic3d_PBRMaterial::RoughnessFromSpecular(white, 0.8));
  printf("MetallicFromSpecular(white)=%.9g\n", Graphic3d_PBRMaterial::MetallicFromSpecular(white));

  // ---- OCCTDate Tests
  Quantity_Date epoch;
  date("default Quantity_Date (epoch)", epoch);
  Quantity_Date d1(6, 15, 2000, 14, 30, 0, 0, 0);
  date("Date(6,15,2000,14,30)", d1);
  Quantity_Date jan1(1, 1, 2000, 0, 0, 0, 0, 0);
  Quantity_Period oneDay(1, 0, 0, 0, 0, 0);
  date("Date(1,1,2000) + Period(days:1)", jan1 + oneDay);
  Quantity_Date   jan15(1, 15, 2000, 12, 0, 0, 0, 0);
  Quantity_Period sixH(0, 6, 0, 0, 0, 0);
  date("Date(1,15,2000,12) - Period(hours:6)", jan15 - sixH);
  Quantity_Date   jan2(1, 2, 2000, 0, 0, 0, 0, 0);
  Quantity_Period diff = jan1.Difference(jan2);
  int             s, us;
  diff.Values(s, us);
  printf("Date(1,1,2000).Difference(Date(1,2,2000)): sec=%d usec=%d\n", s, us);
  printf("Date(1,1,2000) < Date(1,2,2000): %d, > : %d, IsEqual(self): %d\n",
         (int)jan1.IsEarlier(jan2), (int)jan2.IsLater(jan1), (int)jan1.IsEqual(Quantity_Date(1, 1, 2000, 0, 0, 0, 0, 0)));
  Quantity_Period h24(0, 24, 0, 0, 0, 0);
  date("Date(1,1,2000) + Period(hours:24)", jan1 + h24);
  printf("IsValid(6,15,2000)=%d IsValid(13,1,2000)=%d IsValid(2,30,2000)=%d\n",
         (int)Quantity_Date::IsValid(6, 15, 2000, 0, 0, 0, 0, 0),
         (int)Quantity_Date::IsValid(13, 1, 2000, 0, 0, 0, 0, 0),
         (int)Quantity_Date::IsValid(2, 30, 2000, 0, 0, 0, 0, 0));
  printf("IsLeap(2000)=%d IsLeap(1900)=%d IsLeap(2024)=%d\n",
         (int)Quantity_Date::IsLeap(2000), (int)Quantity_Date::IsLeap(1900), (int)Quantity_Date::IsLeap(2024));
  date("Date(1,1,2000, ms=123, us=456)", Quantity_Date(1, 1, 2000, 0, 0, 0, 123, 456));
  printf("IsValid(0,0,1900)=%d\n", (int)Quantity_Date::IsValid(0, 0, 1900, 0, 0, 0, 0, 0));
  return 0;
}
