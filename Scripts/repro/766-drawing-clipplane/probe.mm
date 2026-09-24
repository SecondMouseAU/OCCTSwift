// Epic #766, OCCTDrawingTests/ClipPlaneTests.swift: kernel parity for all fifteen tests.
// Graphic3d_ClipPlane driven the way OCCTBridge_Visualization_Appearance.mm drives it, with the
// same inputs as the Swift tests. Probe states print as Graphic3d_ClipState: 0 Out, 1 In, 2 On.
#include <Graphic3d_BndBox3d.hxx>
#include <Graphic3d_ClipPlane.hxx>
#include <Graphic3d_Vec3.hxx>
#include <Graphic3d_Vec4.hxx>
#include <cstdio>

static void eq(const char* tag, const Graphic3d_Vec4d& e)
{
  printf("%s: (%.17g, %.17g, %.17g, %.17g)\n", tag, e.x(), e.y(), e.z(), e.w());
}

// The bridge walks the chain and reports Out on the first Out, else On if any plane is On.
static int chainPoint(const Handle(Graphic3d_ClipPlane)& head, double x, double y, double z)
{
  int worst = Graphic3d_ClipState_In;
  for (Handle(Graphic3d_ClipPlane) p = head; !p.IsNull(); p = p->ChainNextPlane())
  {
    Graphic3d_ClipState s = p->ProbePointHalfspace(Graphic3d_Vec4d(x, y, z, 1.0));
    if (s == Graphic3d_ClipState_Out)
      return s;
    if (s == Graphic3d_ClipState_On)
      worst = s;
  }
  return worst;
}

static int box(const Handle(Graphic3d_ClipPlane)& p, double x0, double y0, double z0, double x1,
               double y1, double z1)
{
  Graphic3d_BndBox3d b;
  b.Add(Graphic3d_Vec3d(x0, y0, z0));
  b.Add(Graphic3d_Vec3d(x1, y1, z1));
  return p->ProbeBoxHalfspace(b);
}

int main()
{
  Handle(Graphic3d_ClipPlane) z5 = new Graphic3d_ClipPlane(Graphic3d_Vec4d(0, 0, 1, -5));
  eq("equationRoundtrip", z5->GetEquation());
  eq("createFromNormal", Handle(Graphic3d_ClipPlane)(new Graphic3d_ClipPlane(Graphic3d_Vec4d(1, 0, 0, -3)))->GetEquation());
  Handle(Graphic3d_ClipPlane) s = new Graphic3d_ClipPlane(Graphic3d_Vec4d(1, 0, 0, 0));
  s->SetEquation(Graphic3d_Vec4d(0, 1, 0, -2));
  eq("setEquation", s->GetEquation());
  eq("reversedEquation", z5->ReversedEquation());

  Handle(Graphic3d_ClipPlane) p = new Graphic3d_ClipPlane(Graphic3d_Vec4d(0, 0, 1, 0));
  int                         on0 = p->IsOn();
  p->SetOn(false);
  int on1 = p->IsOn();
  p->SetOn(true);
  printf("enableDisable: default=%d off=%d on=%d\n", on0, on1, p->IsOn());
  int cap0 = p->IsCapping();
  p->SetCapping(true);
  printf("capping: default=%d set=%d\n", cap0, p->IsCapping());
  p->SetCappingColor(Quantity_Color(1.0, 0.0, 0.5, Quantity_TOC_RGB));
  Quantity_Color c = p->CappingAspect()->InteriorColor();
  printf("cappingColor: (%.17g, %.17g, %.17g)\n", c.Red(), c.Green(), c.Blue());
  // HatchStyle.diagonal45 is Aspect_HS_DIAGONAL_45 in the Swift enum's raw values.
  p->SetCappingHatch(Aspect_HS_DIAGONAL_45);
  int h = p->CappingHatch();
  p->SetCappingHatchOn();
  int hon = p->IsHatchOn();
  p->SetCappingHatchOff();
  printf("hatchStyle: style=%d (Aspect_HS_DIAGONAL_45=%d) on=%d off=%d\n", h,
         (int)Aspect_HS_DIAGONAL_45, hon, p->IsHatchOn());

  Handle(Graphic3d_ClipPlane) z0 = new Graphic3d_ClipPlane(Graphic3d_Vec4d(0, 0, 1, 0));
  printf("probePointInside: %d\n", chainPoint(z0, 0, 0, 5));
  printf("probePointOutside: %d\n", chainPoint(z0, 0, 0, -5));
  printf("probeBoxInside: %d\n", box(z0, 0, 0, 1, 5, 5, 10));
  printf("probeBoxPartial: %d\n", box(z0, -5, -5, -5, 5, 5, 5));
  printf("probeBoxOutside: %d\n", box(z0, 0, 0, -10, 5, 5, -1));

  Handle(Graphic3d_ClipPlane) a  = new Graphic3d_ClipPlane(Graphic3d_Vec4d(0, 0, 1, 0));
  Handle(Graphic3d_ClipPlane) b  = new Graphic3d_ClipPlane(Graphic3d_Vec4d(1, 0, 0, 0));
  int                         n0 = a->NbChainNextPlanes();
  a->SetChainNextPlane(b);
  printf("chainPlanes: length %d -> %d, (5,0,5)=%d, (-5,0,5)=%d\n", n0, a->NbChainNextPlanes(),
         chainPoint(a, 5, 0, 5), chainPoint(a, -5, 0, 5));
  a->SetChainNextPlane(Handle(Graphic3d_ClipPlane)());
  printf("clearChain: length after clear %d\n", a->NbChainNextPlanes());
  return 0;
}
