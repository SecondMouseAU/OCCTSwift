// Epic #766, Issue1440Polygon3DParameterGuardTests.swift: kernel parity for both tests.
// Same inputs as the Swift tests, straight to OCCT: Poly_Polygon3D built from three nodes with and
// without a parameter array (OCCTPolyPolygon3DCreate / OCCTPolyPolygon3DCreateWithParams), then
// HasParameters() and Parameters()(i). The no-params polygon's Parameters() is NOT called: it
// dereferences a null Handle (SIGSEGV), which is the defect the bridge's HasParameters() guard
// exists to avoid, so the kernel side of that test is "HasParameters() == false".
#include <Poly_Polygon3D.hxx>
#include <TColStd_Array1OfReal.hxx>
#include <TColgp_Array1OfPnt.hxx>
#include <cstdio>

int main()
{
  TColgp_Array1OfPnt nodes(1, 3);
  nodes(1) = gp_Pnt(0, 0, 0);
  nodes(2) = gp_Pnt(1, 0, 0);
  nodes(3) = gp_Pnt(1, 1, 0);

  Handle(Poly_Polygon3D) noParams = new Poly_Polygon3D(nodes);
  printf("noParametersPolygonParameterIsSafe: hasParameters=%d nbNodes=%d\n",
         noParams->HasParameters(), noParams->NbNodes());

  TColStd_Array1OfReal params(1, 3);
  params(1)                        = 0.0;
  params(2)                        = 0.5;
  params(3)                        = 1.0;
  Handle(Poly_Polygon3D) withParams = new Poly_Polygon3D(nodes, params);
  printf("withParametersPolygonReturnsStoredValue: hasParameters=%d parameters=[%.17g, %.17g, %.17g]\n",
         withParams->HasParameters(), withParams->Parameters()(1), withParams->Parameters()(2),
         withParams->Parameters()(3));
  return 0;
}
