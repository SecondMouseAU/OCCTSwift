// #3074 ground truth: error of BRepGProp_Cinert's centroid and inertia on an elliptical arc,
// against an independent Simpson integral, and the same figures with the arc cut into N sub-edges.
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepAdaptor_Curve.hxx>
#include <BRepGProp.hxx>
#include <GProp_GProps.hxx>
#include <Geom_Ellipse.hxx>
#include <gp_Ax2.hxx>
#include <cstdio>
#include <cmath>

static const double A = 10, B = 1;

static void simpson(double t0, double t1, double r[7])
{
  const int n = 400000;
  double h = (t1 - t0) / n;
  for (int k = 0; k < 7; ++k) r[k] = 0;
  for (int i = 0; i <= n; ++i)
  {
    double t = t0 + i * h, w = (i == 0 || i == n) ? 1 : (i % 2 ? 4 : 2);
    double x = A * cos(t), y = B * sin(t), ds = sqrt(A*A*sin(t)*sin(t) + B*B*cos(t)*cos(t));
    w *= h / 3 * ds;
    r[0] += w; r[1] += w * x; r[2] += w * y; r[3] += w * (y*y); r[4] += w * (x*x); r[5] += w * (x*x + y*y); r[6] += w * x * y;
  }
}

static void viaGProps(double t0, double t1, int pieces, double r[7])
{
  Handle(Geom_Ellipse) e = new Geom_Ellipse(gp_Ax2(gp::Origin(), gp::DZ(), gp::DX()), A, B);
  GProp_GProps total(gp::Origin());
  for (int i = 0; i < pieces; ++i)
  {
    double a = t0 + (t1 - t0) * i / pieces, b = t0 + (t1 - t0) * (i + 1) / pieces;
    TopoDS_Edge ed = BRepBuilderAPI_MakeEdge(e, a, b);
    GProp_GProps p(gp::Origin());
    BRepGProp::LinearProperties(ed, p);
    total.Add(p);
  }
  gp_Pnt c = total.CentreOfMass();
  gp_Mat m = total.MatrixOfInertia();
  r[0] = total.Mass(); r[1] = c.X() * r[0]; r[2] = c.Y() * r[0];
  r[3] = m(1,1); r[4] = m(2,2); r[5] = m(3,3); r[6] = -m(1,2);
}

int main()
{
  double spans[4][2] = {{0, 2*M_PI}, {0, M_PI}, {0, M_PI / 2}, {0.3, 2.0}};
  for (auto& s : spans)
  {
    double ref[7];
    simpson(s[0], s[1], ref);
    // GProp_GProps reports the inertia matrix about the centre of mass; move the reference there.
    { double L = ref[0], cx = ref[1]/L, cy = ref[2]/L;
      double Ixx = ref[3] - L*cy*cy, Iyy = ref[4] - L*cx*cx, Izz = ref[5] - L*(cx*cx+cy*cy);
      ref[3] = Ixx; ref[4] = Iyy; ref[5] = Izz; }
    printf("arc [%.3f, %.3f] ref: len %.12f cx %.12f cy %.12f Ixx %.9f Iyy %.9f Izz %.9f\n", s[0], s[1], ref[0], ref[1]/ref[0], ref[2]/ref[0], ref[3], ref[4], ref[5]);
    for (int pieces : {1, 2, 4, 8, 16, 64})
    {
      double r[7];
      viaGProps(s[0], s[1], pieces, r);
      printf("  N=%-3d len %+.2e cx %+.2e cy %+.2e Ixx %+.2e Iyy %+.2e Izz %+.2e (relative to ref; centroid absolute)\n", pieces,
             r[0]/ref[0]-1, r[1]/r[0]-ref[1]/ref[0], r[2]/r[0]-ref[2]/ref[0], r[3]/ref[3]-1, r[4]/ref[4]-1, r[5]/ref[5]-1);
    }
  }
}
