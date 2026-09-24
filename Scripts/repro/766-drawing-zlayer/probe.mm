// Epic #766, OCCTDrawingTests/ZLayerSettingsTests.swift: kernel parity for all thirteen tests.
// A default Graphic3d_ZLayerSettings, as OCCTZLayerSettingsCreate builds it, driven with the
// tests' setter values; and the Graphic3d_ZLayerId constants the Swift layer ids restate.
#include <Graphic3d_ZLayerId.hxx>
#include <Graphic3d_ZLayerSettings.hxx>
#include <cstdio>

int main()
{
  {
    Graphic3d_ZLayerSettings s;
    printf("defaults: depthTest=%d depthWrite=%d clearDepth=%d immediate=%d raytracable=%d "
           "environmentTexture=%d renderInDepthPrepass=%d\n",
           s.ToEnableDepthTest(), s.ToEnableDepthWrite(), s.ToClearDepth(), s.IsImmediate(),
           s.IsRaytracable(), s.UseEnvironmentTexture(), s.ToRenderInDepthPrepass());
  }
  Graphic3d_ZLayerSettings s;
  s.SetEnableDepthTest(false);
  int dt0 = s.ToEnableDepthTest();
  s.SetEnableDepthTest(true);
  printf("depthTest: false->%d true->%d\n", dt0, s.ToEnableDepthTest());
  s.SetEnableDepthWrite(false);
  printf("depthWrite: %d\n", s.ToEnableDepthWrite());
  s.SetClearDepth(false);
  printf("clearDepth: %d\n", s.ToClearDepth());
  Graphic3d_PolygonOffset o;
  o.Mode   = Aspect_POM_Fill;
  o.Factor = 1.5f;
  o.Units  = 2.0f;
  s.SetPolygonOffset(o);
  printf("polygonOffset: mode=%d (Aspect_POM_Fill=%d) factor=%g units=%g\n", (int)s.PolygonOffset().Mode,
         (int)Aspect_POM_Fill, s.PolygonOffset().Factor, s.PolygonOffset().Units);
  {
    Graphic3d_ZLayerSettings p;
    p.SetDepthOffsetPositive();
    printf("depthOffsetPositive: mode=%d factor=%g units=%g\n", (int)p.PolygonOffset().Mode,
           p.PolygonOffset().Factor, p.PolygonOffset().Units);
    Graphic3d_ZLayerSettings n;
    n.SetDepthOffsetNegative();
    printf("depthOffsetNegative: mode=%d factor=%g units=%g\n", (int)n.PolygonOffset().Mode,
           n.PolygonOffset().Factor, n.PolygonOffset().Units);
  }
  s.SetImmediate(true);
  printf("immediate: %d\n", s.IsImmediate());
  s.SetRaytracable(false);
  printf("raytracable: %d\n", s.IsRaytracable());
  s.SetCullingDistance(1000.0);
  printf("cullingDistance: %.17g\n", s.CullingDistance());
  s.SetCullingSize(5.0);
  printf("cullingSize: %.17g\n", s.CullingSize());
  s.SetOrigin(gp_XYZ(100, 200, 300));
  printf("origin: (%.17g, %.17g, %.17g)\n", s.Origin().X(), s.Origin().Y(), s.Origin().Z());
  printf("layer ids: BotOSD=%d Default=%d Top=%d Topmost=%d TopOSD=%d\n", Graphic3d_ZLayerId_BotOSD,
         Graphic3d_ZLayerId_Default, Graphic3d_ZLayerId_Top, Graphic3d_ZLayerId_Topmost,
         Graphic3d_ZLayerId_TopOSD);
  return 0;
}
