// Epic #766, OCCTFoundationTests.swift "FontManager Tests" (5), "PixMap Tests" (10) and
// "UnitsAPI Tests" (8): kernel parity. Same inputs as the Swift tests, straight to Font_FontMgr
// (OCCTFontMgr*), Image_AlienPixMap / Image_PixMap (OCCTImage*) and UnitsAPI (OCCTUnits*).
#include <Font_FontMgr.hxx>
#include <Font_SystemFont.hxx>
#include <Image_AlienPixMap.hxx>
#include <Quantity_ColorRGBA.hxx>
#include <UnitsAPI.hxx>
#include <cstdio>

int main()
{
  // ---- FontManager Tests
  Handle(Font_FontMgr) mgr = Font_FontMgr::GetInstance();
  mgr->InitFontDataBase();
  NCollection_List<Handle(Font_SystemFont)> fonts = mgr->GetAvailableFonts();
  printf("GetAvailableFonts().Size()=%d\n", fonts.Size());
  int i = 0;
  for (auto it = fonts.cbegin(); it != fonts.cend() && i < 3; ++it, ++i)
    printf("  font[%d]=[%s]\n", i, (*it)->FontName().ToCString());
  for (int a = 0; a <= 3; a++)
    printf("FontAspectToString(%d)=[%s]\n", a, Font_FontMgr::FontAspectToString((Font_FontAspect)a));

  // ---- PixMap Tests
  Handle(Image_AlienPixMap) img = new Image_AlienPixMap();
  printf("new Image_AlienPixMap: IsEmpty=%d\n", (int)img->IsEmpty());
  bool ok = img->InitTrash(Image_Format_RGBA, 64, 64);
  printf("InitTrash(RGBA,64,64)=%d IsEmpty=%d SizeX=%zu SizeY=%zu Format=%d\n", ok, (int)img->IsEmpty(),
         img->SizeX(), img->SizeY(), (int)img->Format());
  Handle(Image_AlienPixMap) rgb = new Image_AlienPixMap();
  ok = rgb->InitTrash(Image_Format_RGB, 100, 50);
  printf("InitTrash(RGB,100,50)=%d SizeX=%zu SizeY=%zu Format=%d\n", ok, rgb->SizeX(), rgb->SizeY(), (int)rgb->Format());
  Handle(Image_AlienPixMap) px = new Image_AlienPixMap();
  px->InitTrash(Image_Format_RGBA, 4, 4);
  px->SetPixelColor(2, 2, Quantity_ColorRGBA(0.8f, 0.2f, 0.5f, 1.0f));
  Quantity_ColorRGBA got = px->PixelColor(2, 2);
  printf("RGBA 4x4 set(2,2)=(0.8,0.2,0.5,1) -> get r=%.9g g=%.9g b=%.9g a=%.9g\n", got.GetRGB().Red(),
         got.GetRGB().Green(), got.GetRGB().Blue(), (double)got.Alpha());
  Handle(Image_AlienPixMap) ppm = new Image_AlienPixMap();
  ppm->InitTrash(Image_Format_RGB, 16, 16);
  for (int y = 0; y < 16; y++)
    for (int x = 0; x < 16; x++)
      ppm->SetPixelColor(x, y, Quantity_ColorRGBA(float(x) / 16.0f, float(y) / 16.0f, 0.5f, 1.0f));
  printf("Save(/tmp/occt_pixmap_probe.ppm)=%d\n", (int)ppm->Save(TCollection_AsciiString("/tmp/occt_pixmap_probe.ppm")));
  Handle(Image_AlienPixMap) cl = new Image_AlienPixMap();
  cl->InitTrash(Image_Format_RGB, 32, 32);
  int before = cl->IsEmpty();
  cl->Clear();
  printf("RGB 32x32 IsEmpty before Clear=%d after=%d\n", before, (int)cl->IsEmpty());
  Handle(Image_AlienPixMap) src = new Image_AlienPixMap(), dst = new Image_AlienPixMap();
  src->InitTrash(Image_Format_RGB, 8, 8);
  src->SetPixelColor(0, 0, Quantity_ColorRGBA(1, 0, 0, 1));
  ok = dst->InitCopy(*src);
  printf("InitCopy(8x8 RGB)=%d SizeX=%zu SizeY=%zu\n", ok, dst->SizeX(), dst->SizeY());
  printf("SizePixelBytes RGBA=%zu RGB=%zu Gray=%zu\n", Image_PixMap::SizePixelBytes(Image_Format_RGBA),
         Image_PixMap::SizePixelBytes(Image_Format_RGB), Image_PixMap::SizePixelBytes(Image_Format_Gray));
  printf("Image_AlienPixMap::IsTopDownDefault()=%d\n", (int)Image_AlienPixMap::IsTopDownDefault());
  Handle(Image_AlienPixMap) gray = new Image_AlienPixMap();
  gray->InitTrash(Image_Format_Gray, 10, 10);
  printf("InitTrash(Gray,10,10): Format=%d IsEmpty=%d\n", (int)gray->Format(), (int)gray->IsEmpty());

  // ---- UnitsAPI Tests
  printf("AnyToAny(1000, mm, m)=%.17g\n", UnitsAPI::AnyToAny(1000, "mm", "m"));
  printf("AnyToAny(1, m, mm)=%.17g\n", UnitsAPI::AnyToAny(1, "m", "mm"));
  printf("AnyToAny(1, in, mm)=%.17g\n", UnitsAPI::AnyToAny(1, "in", "mm"));
  printf("AnyToAny(180, deg, rad)=%.17g\n", UnitsAPI::AnyToAny(180, "deg", "rad"));
  printf("AnyToSI(1000, mm)=%.17g\n", UnitsAPI::AnyToSI(1000, "mm"));
  printf("AnyFromSI(1, mm)=%.17g\n", UnitsAPI::AnyFromSI(1, "mm"));
  printf("AnyToAny(1, kg, g)=%.17g\n", UnitsAPI::AnyToAny(1, "kg", "g"));
  printf("LocalSystem() before=%d\n", (int)UnitsAPI::LocalSystem());
  UnitsAPI::SetLocalSystem(UnitsAPI_SI);
  printf("SetLocalSystem(UnitsAPI_SI=%d) -> LocalSystem()=%d\n", (int)UnitsAPI_SI, (int)UnitsAPI::LocalSystem());
  UnitsAPI::SetLocalSystem(UnitsAPI_MDTV);
  printf("SetLocalSystem(UnitsAPI_MDTV=%d) -> LocalSystem()=%d\n", (int)UnitsAPI_MDTV, (int)UnitsAPI::LocalSystem());
  return 0;
}
