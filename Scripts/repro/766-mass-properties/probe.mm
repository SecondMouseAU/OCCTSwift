// Kernel parity probe for Tests/OCCTAnalysisTests/MassPropertiesTests.swift (#1729-#1732).
// Same inputs as the tests: Wire.rectangle(10, 10) is four BRepBuilderAPI_MakeEdge segments around
// (+-5, +-5, 0) (OCCTWireCreateRectangle); Shape.box(10,10,10) is BRepPrimAPI_MakeBox from
// (-5,-5,-5). The bridge reads BRepGProp::LinearProperties for the wire and
// BRepGProp::VolumeProperties(OnlyClosed = true) for the box, as below.
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepBuilderAPI_MakeWire.hxx>
#include <BRepGProp.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <GProp_GProps.hxx>
#include <GProp_PrincipalProps.hxx>
#include <gp_Ax1.hxx>
#include <gp_Mat.hxx>
#include <cstdio>

int main()
{
  gp_Pnt                  p1(-5, -5, 0), p2(5, -5, 0), p3(5, 5, 0), p4(-5, 5, 0);
  BRepBuilderAPI_MakeWire mw;
  mw.Add(BRepBuilderAPI_MakeEdge(p1, p2));
  mw.Add(BRepBuilderAPI_MakeEdge(p2, p3));
  mw.Add(BRepBuilderAPI_MakeEdge(p3, p4));
  mw.Add(BRepBuilderAPI_MakeEdge(p4, p1));
  GProp_GProps lp;
  BRepGProp::LinearProperties(mw.Wire(), lp);
  gp_Pnt lc = lp.CentreOfMass();
  printf("linearProperties: length=%.12g centre=(%.12g, %.12g, %.12g)\n", lp.Mass(), lc.X(), lc.Y(),
         lc.Z());

  TopoDS_Shape box = BRepPrimAPI_MakeBox(gp_Pnt(-5, -5, -5), 10, 10, 10).Shape();
  GProp_GProps vp;
  BRepGProp::VolumeProperties(box, vp, Standard_True);
  printf("volume=%.12g\n", vp.Mass());
  gp_Mat m = vp.MatrixOfInertia();
  printf("momentOfInertia: ixx=%.12g iyy=%.12g izz=%.12g ixy=%.12g ixz=%.12g iyz=%.12g\n", m(1, 1),
         m(2, 2), m(3, 3), m(1, 2), m(1, 3), m(2, 3));

  GProp_PrincipalProps pp = vp.PrincipalProperties();
  const gp_Vec&        a1 = pp.FirstAxisOfInertia();
  const gp_Vec&        a2 = pp.SecondAxisOfInertia();
  const gp_Vec&        a3 = pp.ThirdAxisOfInertia();
  printf("principalAxes: axis1=(%.12g, %.12g, %.12g) axis2=(%.12g, %.12g, %.12g) "
         "axis3=(%.12g, %.12g, %.12g)\n",
         a1.X(), a1.Y(), a1.Z(), a2.X(), a2.Y(), a2.Z(), a3.X(), a3.Y(), a3.Z());

  // A cube's inertia is isotropic, so its principal axes are whatever math_Jacobi settles on (the
  // near-axis vectors above). The 10x20x30 box has three distinct moments and unique axes.
  TopoDS_Shape box2 = BRepPrimAPI_MakeBox(gp_Pnt(-5, -10, -15), 10, 20, 30).Shape();
  GProp_GProps vp2;
  BRepGProp::VolumeProperties(box2, vp2, Standard_True);
  GProp_PrincipalProps pp2 = vp2.PrincipalProperties();
  const gp_Vec&        b1  = pp2.FirstAxisOfInertia();
  const gp_Vec&        b2  = pp2.SecondAxisOfInertia();
  const gp_Vec&        b3  = pp2.ThirdAxisOfInertia();
  printf("principalAxes 10x20x30: axis1=(%.12g, %.12g, %.12g) axis2=(%.12g, %.12g, %.12g) "
         "axis3=(%.12g, %.12g, %.12g)\n",
         b1.X(), b1.Y(), b1.Z(), b2.X(), b2.Y(), b2.Z(), b3.X(), b3.Y(), b3.Z());
  double i1, i2, i3;
  pp2.Moments(i1, i2, i3);
  printf("principal moments 10x20x30: %.12g %.12g %.12g\n", i1, i2, i3);

  gp_Ax1 z(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1));
  printf("radiusOfGyration(origin, +Z)=%.12g\n", vp.RadiusOfGyration(z));
  return 0;
}
