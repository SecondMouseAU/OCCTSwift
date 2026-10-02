// Epic #766, Tests/OCCTModelingTests/LoftPolarMethodCrashTests.swift: kernel parity for
// mismatchedPolarProfilesDoNotCrash. OCCTShapeCreateLoft is BRepOffsetAPI_ThruSections(solid=true)
// with CheckCompatibility(true), one AddWire per profile, Build(), nullptr unless IsDone(). The
// profiles are the #176 set, each a closed BRepBuilderAPI_MakePolygon (OCCTWireCreateFastPolygon).
#include <BRepBuilderAPI_MakePolygon.hxx>
#include <BRepCheck_Analyzer.hxx>
#include <BRepOffsetAPI_ThruSections.hxx>
#include <Standard_Failure.hxx>
#include <cstdio>
#include <vector>

int main()
{
  struct Station
  {
    double                                 z;
    std::vector<std::pair<double, double>> pts;
  };
  std::vector<Station> st = {
    {-3.75, {{-0.0502, 2.1681}, {-0.0162, 0.2239}, {0.0463, 0.2250}, {0.0357, 0.8300}, {0.0123, 2.1692}}},
    {-2.9167, {{-0.0162, 0.2239}, {0.0007, -0.7416}, {0.0632, -0.7405}, {0.0556, -0.3053}, {0.0463, 0.2250}}},
    {-2.0833, {{-0.0451, -1.2651}, {0.0174, -1.2640}, {0.0689, -1.0639}, {0.0632, -0.7405}, {0.0007, -0.7416}}},
    {-1.25, {{-0.1048, -1.3334}, {-0.0423, -1.3323}, {0.0174, -1.2640}, {-0.0451, -1.2651}}},
    {1.25, {{-0.1048, -1.3334}, {-0.0423, -1.3323}, {0.0174, -1.2640}, {-0.0451, -1.2651}}},
    {2.0833, {{-0.0451, -1.2651}, {0.0174, -1.2640}, {0.0689, -1.0639}, {0.0632, -0.7405}, {0.0007, -0.7416}}},
    {2.9167, {{-0.0162, 0.2239}, {0.0007, -0.7416}, {0.0632, -0.7405}, {0.0556, -0.3053}, {0.0463, 0.2250}}},
    {3.75, {{-0.0502, 2.1681}, {-0.0162, 0.2239}, {0.0463, 0.2250}, {0.0357, 0.8300}, {0.0123, 2.1692}}},
  };
  for (int compat = 1; compat >= 0; compat--)
  {
  BRepOffsetAPI_ThruSections maker(Standard_True);
  maker.CheckCompatibility(compat ? Standard_True : Standard_False);
  printf("CheckCompatibility(%s):\n", compat ? "true, what the bridge sets" : "false, for comparison");
  int wires = 0;
  for (const Station& s : st)
  {
    BRepBuilderAPI_MakePolygon poly;
    for (auto& p : s.pts)
      poly.Add(gp_Pnt(p.first, p.second, s.z));
    poly.Close();
    if (poly.IsDone())
    {
      maker.AddWire(poly.Wire());
      wires++;
    }
  }
  printf("profiles built: %d of %zu\n", wires, st.size());
  try
  {
    maker.Build();
    printf("loft: returned from Build, done=%d", maker.IsDone());
    if (maker.IsDone())
      printf(" valid=%d", BRepCheck_Analyzer(maker.Shape()).IsValid());
    printf("\n");
  }
  catch (Standard_Failure& e)
  {
    printf("loft: Build threw %s (bridge catch returns nullptr)\n", e.what());
  }
  }
  return 0;
}
