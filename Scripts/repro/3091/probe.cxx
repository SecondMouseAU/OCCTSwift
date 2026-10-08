// Probe for #3091: the mass, centre of mass and matrix of inertia of GProp_SelGProps and
// GProp_VelGProps on gp_Cylinder, gp_Sphere and gp_Torus, against an independent Gauss-Legendre
// integral. (The gp_Cone overloads are 0055's and are not probed here; Scripts/repro/3010-cone-inertia.)
//
// The integral is written here, over each surface's own parameter space, and uses none of the
// kernel's closed forms. For a surface it integrates (|p|^2 I - p p^T) dA about the origin; for a
// volume it integrates the same over the solid swept between the axis (or the centre) and the
// patch, which is the convention 0051 documents for VelGProps. Both are then moved to the centre
// of mass so they compare with GProp_GProps::MatrixOfInertia(), which is the kernel's inertia
// about the centre of mass. Placements are tilted and translated, so the frame transform is
// exercised as well as the polynomials.
#include <GProp_SelGProps.hxx>
#include <GProp_VelGProps.hxx>
#include <gp_Ax3.hxx>
#include <gp_Cone.hxx>
#include <gp_Cylinder.hxx>
#include <gp_Dir.hxx>
#include <gp_Mat.hxx>
#include <gp_Pnt.hxx>
#include <gp_Sphere.hxx>
#include <gp_Torus.hxx>

#include <array>
#include <cmath>
#include <cstdio>
#include <cstring>
#include <functional>
#include <vector>

namespace
{
using V3 = std::array<double, 3>;
using M3 = std::array<std::array<double, 3>, 3>;

struct Rule
{
  std::vector<double> x, w;
};

// n-point Gauss-Legendre on [-1, 1] by Newton iteration on P_n, then mapped by the caller.
Rule gaussLegendre(int n)
{
  Rule r;
  r.x.resize(n);
  r.w.resize(n);
  for (int i = 0; i < n; ++i)
  {
    double z = std::cos(M_PI * (i + 0.75) / (n + 0.5));
    double pp = 0;
    for (int it = 0; it < 100; ++it)
    {
      double p1 = 1, p2 = 0;
      for (int j = 1; j <= n; ++j)
      {
        double p3 = p2;
        p2        = p1;
        p1        = ((2.0 * j - 1.0) * z * p2 - (j - 1.0) * p3) / j;
      }
      pp           = n * (z * p1 - p2) / (z * z - 1.0);
      double znext = z - p1 / pp;
      if (std::abs(znext - z) < 1e-16)
      {
        z = znext;
        break;
      }
      z = znext;
    }
    r.x[i] = z;
    r.w[i] = 2.0 / ((1.0 - z * z) * pp * pp);
  }
  return r;
}

struct Moments
{
  double mass = 0;
  V3     first{};  // integral of p
  M3     second{}; // integral of p p^T
};

// samples(u, v, t) returns the global point and the weight (area or volume element).
using Sample = std::function<std::pair<V3, double>(double, double, double)>;

Moments integrate(const Sample& f, double u1, double u2, double v1, double v2, bool threeD)
{
  static const Rule g = gaussLegendre(24);
  Moments m;
  const int nt = threeD ? (int)g.x.size() : 1;
  for (size_t i = 0; i < g.x.size(); ++i)
    for (size_t j = 0; j < g.x.size(); ++j)
      for (int k = 0; k < nt; ++k)
      {
        double u  = 0.5 * (u2 - u1) * g.x[i] + 0.5 * (u2 + u1);
        double v  = 0.5 * (v2 - v1) * g.x[j] + 0.5 * (v2 + v1);
        double t  = threeD ? 0.5 * g.x[k] + 0.5 : 1.0;
        double wt = 0.5 * (u2 - u1) * g.w[i] * 0.5 * (v2 - v1) * g.w[j] * (threeD ? 0.5 * g.w[k] : 1.0);
        auto [p, w] = f(u, v, t);
        w *= wt;
        m.mass += w;
        for (int a = 0; a < 3; ++a)
        {
          m.first[a] += w * p[a];
          for (int b = 0; b < 3; ++b)
            m.second[a][b] += w * p[a] * p[b];
        }
      }
  return m;
}

// Matrix of inertia about the centre of mass: trace(S) I - S, with S the second moment about G.
M3 inertiaAboutG(const Moments& m, V3& G)
{
  for (int a = 0; a < 3; ++a)
    G[a] = m.first[a] / m.mass;
  M3 s{};
  for (int a = 0; a < 3; ++a)
    for (int b = 0; b < 3; ++b)
      s[a][b] = m.second[a][b] - m.mass * G[a] * G[b];
  double tr = s[0][0] + s[1][1] + s[2][2];
  M3     r{};
  for (int a = 0; a < 3; ++a)
    for (int b = 0; b < 3; ++b)
      r[a][b] = (a == b ? tr : 0.0) - s[a][b];
  return r;
}

V3 toGlobal(const gp_Ax3& ax, double x, double y, double z)
{
  const gp_Dir X = ax.XDirection(), Y = ax.YDirection(), Z = ax.Direction();
  const gp_Pnt O = ax.Location();
  return {O.X() + x * X.X() + y * Y.X() + z * Z.X(),
          O.Y() + x * X.Y() + y * Y.Y() + z * Z.Y(),
          O.Z() + x * X.Z() + y * Y.Z() + z * Z.Z()};
}

struct Report
{
  double maxRel = 0; // max |kernel - exact| over the matrix, over max |exact|
  double massRel = 0;
  double gDist = 0;
};

bool g_verbose = false;
// A case passes when mass, centre of mass and the matrix of inertia agree with the integral.
// Gauss-Legendre at 24 nodes on these polynomial integrands is exact to rounding, so the bound is
// loose on purpose: it separates 1e-14 from the O(1) errors, and nothing in between occurs.
const double kTol    = 1e-9;
int          g_bad = 0, g_all = 0;

Report compare(const char* label, const GProp_GProps& k, const Moments& m)
{
  V3 G;
  M3 ex = inertiaAboutG(m, G);
  gp_Mat km = k.MatrixOfInertia();
  double scale = 0, dev = 0;
  for (int a = 0; a < 3; ++a)
    for (int b = 0; b < 3; ++b)
    {
      scale = std::fmax(scale, std::abs(ex[a][b]));
      dev   = std::fmax(dev, std::abs(km.Value(a + 1, b + 1) - ex[a][b]));
    }
  Report r;
  r.maxRel  = dev / scale;
  r.massRel = std::abs(k.Mass() - m.mass) / std::abs(m.mass);
  gp_Pnt kg = k.CentreOfMass();
  r.gDist   = std::sqrt((kg.X() - G[0]) * (kg.X() - G[0]) + (kg.Y() - G[1]) * (kg.Y() - G[1])
                        + (kg.Z() - G[2]) * (kg.Z() - G[2]));
  const bool bad = r.maxRel > kTol || r.massRel > kTol || r.gDist > kTol * (1.0 + std::abs(G[0]) + std::abs(G[1]) + std::abs(G[2]));
  g_all++;
  if (bad)
    g_bad++;
  std::printf("  %-34s mass %.12g (exact %.12g)  |G err| %.2g  inertia max rel err %.3e%s\n",
              label, k.Mass(), m.mass, r.gDist, r.maxRel, bad ? "  FAIL" : "");
  if (g_verbose)
  {
    std::printf("    centre of mass: kernel (%.12g, %.12g, %.12g)  integral (%.12g, %.12g, %.12g)\n",
                kg.X(), kg.Y(), kg.Z(), G[0], G[1], G[2]);
    std::printf("    kernel (about G)                                   exact (about G)\n");
    for (int a = 0; a < 3; ++a)
      std::printf("    %16.9g %16.9g %16.9g   %16.9g %16.9g %16.9g\n",
                  km.Value(a + 1, 1), km.Value(a + 1, 2), km.Value(a + 1, 3),
                  ex[a][0], ex[a][1], ex[a][2]);
  }
  return r;
}

// Exact moment of inertia about the axis through q along unit d: integral of |(p - q) x d|^2.
double axisMoment(const Moments& m, const V3& q, const V3& d)
{
  double trS = m.second[0][0] + m.second[1][1] + m.second[2][2];
  double qF = 0, dF = 0, qd = 0, qq = 0, dSd = 0;
  for (int a = 0; a < 3; ++a)
  {
    qF += q[a] * m.first[a];
    dF += d[a] * m.first[a];
    qd += q[a] * d[a];
    qq += q[a] * q[a];
    for (int b = 0; b < 3; ++b)
      dSd += d[a] * m.second[a][b] * d[b];
  }
  double yy  = trS - 2 * qF + m.mass * qq;
  double ydd = dSd - 2 * qd * dF + m.mass * qd * qd;
  return yy - ydd;
}

// The same through GProp_GProps::MomentOfInertia, with the kernel's reference point at q.
void checkAxis(const char* label, const GProp_GProps& k, const Moments& m, const V3& q, const V3& d)
{
  double ex = axisMoment(m, q, d);
  double kv = k.MomentOfInertia(gp_Ax1(gp_Pnt(q[0], q[1], q[2]), gp_Dir(d[0], d[1], d[2])));
  double rel = std::abs(kv - ex) / std::abs(ex);
  const bool bad = rel > kTol;
  g_all++;
  if (bad)
    g_bad++;
  std::printf("  %-34s I = %.12g (exact %.12g)  rel err %.3e%s\n", label, kv, ex, rel, bad ? "  FAIL" : "");
}

// Frames: untilted at the origin, and tilted and translated.
const gp_Ax3 kFrames[2] = {gp_Ax3(gp::XOY()),
                           gp_Ax3(gp_Pnt(1.5, -2.0, 3.0), gp_Dir(1.0, 2.0, 3.0), gp_Dir(2.0, -1.0, 0.0))};
const char* kFrameName[2] = {"XOY", "tilted"};
const gp_Pnt kRef(2.0, -1.0, 3.0);
const V3     kAxisPt{2.0, -1.0, 3.0}, kAxisDir{1.0 / 3.0, 2.0 / 3.0, 2.0 / 3.0};

// Runs one (surface, volume) pair through compare and a moment about an oblique axis with the
// reference point away from the origin.
template <class Shape, class SelF, class VelF>
void both(const gp_Ax3& ax, const Shape& shape, const SelF& selMoments, const VelF& velMoments,
          const std::function<void(GProp_SelGProps&)>& performSel,
          const std::function<void(GProp_VelGProps&)>& performVel,
          const std::function<GProp_SelGProps(const gp_Pnt&)>& selAt,
          const std::function<GProp_VelGProps(const gp_Pnt&)>& velAt)
{
  (void)ax; (void)shape;
  GProp_SelGProps sel;
  performSel(sel);
  Moments ms = selMoments();
  compare("GProp_SelGProps (surface)", sel, ms);
  GProp_SelGProps selq = selAt(kRef);
  checkAxis("  Sel, loc (2,-1,3), axis (1,2,2)/3", selq, ms, kAxisPt, kAxisDir);
  GProp_VelGProps vel;
  performVel(vel);
  Moments mv = velMoments();
  compare("GProp_VelGProps (volume)", vel, mv);
  GProp_VelGProps velq = velAt(kRef);
  checkAxis("  Vel, loc (2,-1,3), axis (1,2,2)/3", velq, mv, kAxisPt, kAxisDir);
}
} // namespace

int main(int argc, char** argv)
{
  for (int i = 1; i < argc; ++i)
    if (!std::strcmp(argv[i], "-v"))
      g_verbose = true;
  const double P = M_PI;

  std::printf("== the issue's number: Dm(3, 3) of the full cylinder surface, R = 5, height 10 ==\n");
  {
    // With loc at the cylinder's location, the moment about its axis reads Dm(3, 3) directly.
    const double R = 5;
    gp_Cylinder cyl(gp_Ax3(gp::XOY()), R);
    GProp_SelGProps sel;
    sel.Perform(cyl, 0, 2 * P, 0, 10);
    double kv = sel.MomentOfInertia(gp_Ax1(gp::Origin(), gp::DZ()));
    std::printf("  GProp_SelGProps  Izz = %.17g   closed form 2 pi R^3 H = %.17g\n", kv, 2 * P * R * R * R * 10);
  }

  std::printf("== gp_Cylinder ==\n");
  struct CylCase { const char* name; double R, z1, z2, u1, u2; };
  const CylCase cyls[] = {{"R=5 z 0..10 full", 5, 0, 10, 0, 2 * P},
                          {"R=5 z 1..9 u 0.3..2.2", 5, 1, 9, 0.3, 2.2},
                          {"R=2.5 z -3..4 u 1..5.5", 2.5, -3, 4, 1.0, 5.5},
                          {"R=7 z 0.5..2 u -1..0.6", 7, 0.5, 2, -1.0, 0.6}};
  for (int f = 0; f < 2; ++f)
    for (const auto& c : cyls)
    {
      const gp_Ax3& ax = kFrames[f];
      std::printf("[%s] %s\n", kFrameName[f], c.name);
      gp_Cylinder cyl(ax, c.R);
      both(ax, cyl,
           [&] { return integrate([&](double u, double v, double) {
                   return std::make_pair(toGlobal(ax, c.R * std::cos(u), c.R * std::sin(u), v), c.R);
                 }, c.u1, c.u2, c.z1, c.z2, false); },
           [&] { return integrate([&](double u, double v, double t) {
                   return std::make_pair(toGlobal(ax, t * c.R * std::cos(u), t * c.R * std::sin(u), v),
                                         t * c.R * c.R);
                 }, c.u1, c.u2, c.z1, c.z2, true); },
           [&](GProp_SelGProps& s) { s.Perform(cyl, c.u1, c.u2, c.z1, c.z2); },
           [&](GProp_VelGProps& v) { v.Perform(cyl, c.u1, c.u2, c.z1, c.z2); },
           [&](const gp_Pnt& q) { return GProp_SelGProps(cyl, c.u1, c.u2, c.z1, c.z2, q); },
           [&](const gp_Pnt& q) { return GProp_VelGProps(cyl, c.u1, c.u2, c.z1, c.z2, q); });
    }

  std::printf("== gp_Sphere ==\n");
  struct SphCase { const char* name; double R, t1, t2, a1, a2; };
  const SphCase sphs[] = {{"R=5 full", 5, 0, 2 * P, -P / 2, P / 2},
                          {"R=5 teta 0.3..2.2 alpha -0.4..1.1", 5, 0.3, 2.2, -0.4, 1.1},
                          {"R=3 teta 1..5.5 alpha 0.2..1.3", 3, 1.0, 5.5, 0.2, 1.3},
                          {"R=4 teta -0.8..0.9 alpha -1.2..-0.1", 4, -0.8, 0.9, -1.2, -0.1}};
  for (int f = 0; f < 2; ++f)
    for (const auto& c : sphs)
    {
      const gp_Ax3& ax = kFrames[f];
      std::printf("[%s] %s\n", kFrameName[f], c.name);
      gp_Sphere sph(ax, c.R);
      both(ax, sph,
           [&] { return integrate([&](double u, double v, double) {
                   return std::make_pair(toGlobal(ax, c.R * std::cos(v) * std::cos(u),
                                                  c.R * std::cos(v) * std::sin(u), c.R * std::sin(v)),
                                         c.R * c.R * std::cos(v));
                 }, c.t1, c.t2, c.a1, c.a2, false); },
           [&] { return integrate([&](double u, double v, double t) {
                   return std::make_pair(toGlobal(ax, t * c.R * std::cos(v) * std::cos(u),
                                                  t * c.R * std::cos(v) * std::sin(u), t * c.R * std::sin(v)),
                                         t * t * c.R * c.R * c.R * std::cos(v));
                 }, c.t1, c.t2, c.a1, c.a2, true); },
           [&](GProp_SelGProps& s) { s.Perform(sph, c.t1, c.t2, c.a1, c.a2); },
           [&](GProp_VelGProps& v) { v.Perform(sph, c.t1, c.t2, c.a1, c.a2); },
           [&](const gp_Pnt& q) { return GProp_SelGProps(sph, c.t1, c.t2, c.a1, c.a2, q); },
           [&](const gp_Pnt& q) { return GProp_VelGProps(sph, c.t1, c.t2, c.a1, c.a2, q); });
    }

  // The torus volume is the solid swept by the segment from the circle through the centres of the
  // tube to the patch: p = ((R + t r cos v) cos u, (R + t r cos v) sin u, t r sin v), t in [0, 1], and
  // dV = (R + t r cos v) t r^2 dt dv du. A full turn in v reads 2 pi^2 R r^2 either way; a partial
  // one is where the convention shows.
  std::printf("== gp_Torus ==\n");
  struct TorCase { const char* name; double R, r, t1, t2, a1, a2; };
  const TorCase tors[] = {{"R=8 r=2 full", 8, 2, 0, 2 * P, 0, 2 * P},
                          {"R=8 r=2 teta 0.3..2.2 alpha 0.4..2.5", 8, 2, 0.3, 2.2, 0.4, 2.5},
                          {"R=6 r=1.5 teta 1..5.5 alpha -1..1.6", 6, 1.5, 1.0, 5.5, -1.0, 1.6},
                          {"R=5 r=4 teta 0..P alpha 2..5.2", 5, 4, 0, P, 2.0, 5.2}};
  for (int f = 0; f < 2; ++f)
    for (const auto& c : tors)
    {
      const gp_Ax3& ax = kFrames[f];
      std::printf("[%s] %s\n", kFrameName[f], c.name);
      gp_Torus tor(ax, c.R, c.r);
      both(ax, tor,
           [&] { return integrate([&](double u, double v, double) {
                   double rho = c.R + c.r * std::cos(v);
                   return std::make_pair(toGlobal(ax, rho * std::cos(u), rho * std::sin(u), c.r * std::sin(v)),
                                         rho * c.r);
                 }, c.t1, c.t2, c.a1, c.a2, false); },
           [&] { return integrate([&](double u, double v, double t) {
                   double rho = c.R + t * c.r * std::cos(v);
                   return std::make_pair(toGlobal(ax, rho * std::cos(u), rho * std::sin(u), t * c.r * std::sin(v)),
                                         rho * t * c.r * c.r);
                 }, c.t1, c.t2, c.a1, c.a2, true); },
           [&](GProp_SelGProps& s) { s.Perform(tor, c.t1, c.t2, c.a1, c.a2); },
           [&](GProp_VelGProps& v) { v.Perform(tor, c.t1, c.t2, c.a1, c.a2); },
           [&](const gp_Pnt& q) { return GProp_SelGProps(tor, c.t1, c.t2, c.a1, c.a2, q); },
           [&](const gp_Pnt& q) { return GProp_VelGProps(tor, c.t1, c.t2, c.a1, c.a2, q); });
    }

  std::printf("== summary ==\n");
  std::printf("checks failing: %d of %d\n", g_bad, g_all);
  return g_bad == 0 ? 0 : 1;
}
