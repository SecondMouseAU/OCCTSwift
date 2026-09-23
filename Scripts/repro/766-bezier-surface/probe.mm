// #766 kernel parity for Tests/OCCTAnalysisTests/BezierSurfaceTests.swift: Geom_BezierSurface
// accessors on the suite's 3 x 3 fixture (OCCTSurfaceBezierNbUPoles/NbVPoles/UDegree/VDegree,
// GetPole/SetPole, IsURational/IsVRational, ExchangeUV). Surface.bezier(poles:) builds row i of
// the Swift array as U index i + 1.
#include <Geom_BezierSurface.hxx>
#include <NCollection_Array2.hxx>
#include <TColgp_Array2OfPnt.hxx>
#include <cstdio>

static occ::handle<Geom_BezierSurface> fixture()
{
  const double       p[3][3][3] = {{{0, 0, 0}, {0, 5, 1}, {0, 10, 0}},
                                   {{5, 0, 1}, {5, 5, 2}, {5, 10, 1}},
                                   {{10, 0, 0}, {10, 5, 1}, {10, 10, 0}}};
  TColgp_Array2OfPnt poles(1, 3, 1, 3);
  for (int i = 0; i < 3; ++i)
    for (int j = 0; j < 3; ++j)
      poles(i + 1, j + 1) = gp_Pnt(p[i][j][0], p[i][j][1], p[i][j][2]);
  return new Geom_BezierSurface(poles);
}

static void pole(const char* label, const occ::handle<Geom_BezierSurface>& s, int u, int v)
{
  gp_Pnt q = s->Pole(u, v);
  printf("%s Pole(%d,%d)=(%g, %g, %g)\n", label, u, v, q.X(), q.Y(), q.Z());
}

int main()
{
  occ::handle<Geom_BezierSurface> s = fixture();
  printf("nbPoles: NbUPoles=%d NbVPoles=%d\n", s->NbUPoles(), s->NbVPoles());
  printf("degree: UDegree=%d VDegree=%d\n", s->UDegree(), s->VDegree());
  printf("rationalFlags: IsURational=%d IsVRational=%d\n", (int)s->IsURational(),
         (int)s->IsVRational());
  pole("getPoleAndSet before", s, 1, 1);
  s->SetPole(1, 1, gp_Pnt(1, 2, 3));
  pole("getPoleAndSet after SetPole(1,1,(1,2,3))", s, 1, 1);

  occ::handle<Geom_BezierSurface> e = fixture();
  pole("exchangeUV before", e, 1, 2);
  pole("exchangeUV before", e, 2, 1);
  e->ExchangeUV();
  printf("exchangeUV after: UDegree=%d VDegree=%d\n", e->UDegree(), e->VDegree());
  pole("exchangeUV after", e, 1, 2);
  pole("exchangeUV after", e, 2, 1);
  return 0;
}
