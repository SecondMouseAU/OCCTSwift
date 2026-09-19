#include <Graphic3d_MaterialAspect.hxx>
#include <Graphic3d_PBRMaterial.hxx>
#include <cstdio>

int main() {
  int n = Graphic3d_MaterialAspect::NumberOfMaterials();
  printf("count=%d minRoughness=%f\n", n, Graphic3d_PBRMaterial::MinRoughness());
  for (int i = 1; i <= n; i++) {
    Graphic3d_NameOfMaterial nom = (Graphic3d_NameOfMaterial)(i - 1);
    Graphic3d_MaterialAspect mat(nom);
    const char* name = Graphic3d_MaterialAspect::MaterialName(i);
    Graphic3d_PBRMaterial pbr = mat.PBRMaterial();
    printf("%2d %-20s normalized=%.6f remapped=%.6f metallic=%.6f\n",
           i, name ? name : "?", pbr.NormalizedRoughness(), pbr.Roughness(), pbr.Metallic());
  }
  return 0;
}
