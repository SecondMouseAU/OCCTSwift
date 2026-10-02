import math

A1, A2 = 0.0, 2 * math.pi
R, Z1, Z2 = 5.0, 0.0, 10.0
a = math.pi / 6
c, s = math.cos(a), math.sin(a)

# --- AREA ---
area_true = (A2 - A1) * (Z2 - Z1) * (R + (Z2 + Z1) * s / 2)
auxi1 = R + (Z2 + Z1) * s / 2
kernel_area = (A2 - A1) * c * (Z2 - Z1) * auxi1
patched_area = (A2 - A1) * (Z2 - Z1) * auxi1
print("area true      ", repr(area_true))
print("area kernel    ", repr(kernel_area), "ratio", repr(kernel_area / area_true), "cos a", repr(c))
print("area patched   ", repr(patched_area), "== true:", patched_area == area_true)

# --- VOLUME ---
H = (Z2 - Z1) * c
R1, R2 = R + Z1 * s, R + Z2 * s
vol_true = math.pi * H / 3 * (R1 * R1 + R1 * R2 + R2 * R2)
ZZ = (Z2 - Z1) * (Z2 - Z1) * c * s
vauxi1 = 2 * R + (Z2 + Z1) * s
kernel_vol = ZZ * (A2 - A1) * vauxi1 / 2
patched_vol = (A2 - A1) * c * (Z2 - Z1) * (R * R + R * (Z2 + Z1) * s + (Z2 * Z2 + Z2 * Z1 + Z1 * Z1) * s * s / 3.0) / 2.0
issue_vol = (A2 - A1) * c / 2 * (R * R * (Z2 - Z1) + R * s * (Z2 ** 2 - Z1 ** 2) + s * s * (Z2 ** 3 - Z1 ** 3) / 3)
coef0_vol = (A2 - A1) * c * (Z2 - Z1) * (R1 * R1 + R1 * R2 + R2 * R2) / 6.0
print("vol true(frustum) ", repr(vol_true))
print("vol kernel        ", repr(kernel_vol))
print("vol patched inline", repr(patched_vol), "rel", abs(patched_vol - vol_true) / vol_true)
print("vol issue form    ", repr(issue_vol), "rel", abs(issue_vol - vol_true) / vol_true)
print("vol Coef0 form    ", repr(coef0_vol), "rel", abs(coef0_vol - vol_true) / vol_true)
print("dim_Vel / dim_Sel ", repr(kernel_vol / kernel_area), "(Z2-Z1)*sin a =", repr((Z2 - Z1) * s))

# --- cylinder limit ---
for aa in (1e-3, 1e-6, 1e-9):
    cc, ss = math.cos(aa), math.sin(aa)
    k = (Z2 - Z1) ** 2 * cc * ss * (A2 - A1) * (2 * R + (Z2 + Z1) * ss) / 2
    p = (A2 - A1) * cc * (Z2 - Z1) * (R * R + R * (Z2 + Z1) * ss + (Z2 * Z2 + Z2 * Z1 + Z1 * Z1) * ss * ss / 3.0) / 2.0
    ka = (A2 - A1) * cc * (Z2 - Z1) * (R + (Z2 + Z1) * ss / 2)
    pa = (A2 - A1) * (Z2 - Z1) * (R + (Z2 + Z1) * ss / 2)
    print("a=%g  vol kernel=%.9f patched=%.9f   area kernel=%.9f patched=%.9f" % (aa, k, p, ka, pa))
print("cylinder vol", repr((A2 - A1) * R * R * (Z2 - Z1) / 2), " area", repr(R * (Z2 - Z1) * (A2 - A1)))

# --- inertia cross-check (out of scope, reported only) ---
# Sel Dm(3,3) should be  (A2-A1)(Z2-Z1)(R1^3+R1^2R2+R1R2^2+R2^3)/4
sel_dm33_true = (A2 - A1) * (Z2 - Z1) * (R1 ** 3 + R1 ** 2 * R2 + R1 * R2 ** 2 + R2 ** 3) / 4
sel_ZZ = (Z2 - Z1) * c
sel_IR2 = sel_ZZ * s * (R1 ** 3 + R1 ** 2 * R2 + R1 * R2 ** 2 + R2 ** 3) / 4
print("Sel Dm(3,3) true", repr(sel_dm33_true), "kernel", repr(sel_IR2 * (A2 - A1)),
      "ratio", repr(sel_IR2 * (A2 - A1) / sel_dm33_true), "cos a sin a", repr(c * s))
