// Single-threaded ASan check: does D0/D1/D2/D3 on the exact reproducer curve overflow
// BSplCLib_Cache's internal buffer now that a mutex sits right after it in the layout?
#include <cstdio>
#include <GeomAPI_Interpolate.hxx>
#include <TColgp_HArray1OfPnt.hxx>
#include <Geom_BSplineCurve.hxx>
#include <GeomAdaptor_Curve.hxx>

int main()
{
  Handle(TColgp_HArray1OfPnt) pts = new TColgp_HArray1OfPnt(1, 6);
  pts->SetValue(1, gp_Pnt(0, 0, 0));
  pts->SetValue(2, gp_Pnt(1, 2, 0));
  pts->SetValue(3, gp_Pnt(2, -1, 1));
  pts->SetValue(4, gp_Pnt(3, 3, -1));
  pts->SetValue(5, gp_Pnt(4, 0, 2));
  pts->SetValue(6, gp_Pnt(5, 1, 0));
  GeomAPI_Interpolate interp(pts, false, 1e-6);
  interp.Perform();
  Handle(Geom_BSplineCurve) curve = interp.Curve();
  fprintf(stderr, "degree=%d rational=%d\n", curve->Degree(), curve->IsRational());

  GeomAdaptor_Curve adaptor(curve);
  double uFirst = curve->FirstParameter();
  double uLast  = curve->LastParameter();
  for (int it = 0; it < 5000; ++it)
  {
    double u = uFirst + (uLast - uFirst) * (it % 101) / 100.0;
    gp_Pnt p;
    gp_Vec d1, d2, d3;
    adaptor.D0(u, p);
    adaptor.D1(u, p, d1);
    adaptor.D2(u, p, d1, d2);
    adaptor.D3(u, p, d1, d2, d3);
  }
  fprintf(stderr, "done, no overflow detected by ASan\n");
  return 0;
}
