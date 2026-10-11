"""Shapr3D construction steps for a #3233 case, generated from the same removal items the reference is built from."""
import math, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import cases3233 as C


def v(s): return tuple(float(x) for x in s.split(","))
def add(a, b, k=1.0): return tuple(a[i] + k * b[i] for i in range(3))
def fm(p): return "(%.4f, %.4f, %.4f)" % p


def plane_of(e):
    ax = max(range(3), key=lambda i: abs(e[i]))
    return ["YZ", "XZ", "XY"][ax], "XYZ"[ax]


def item_steps(it, n):
    f = it.split(":")
    out = []
    if f[0] == "P":
        p0, e, d1, d2 = v(f[1]), v(f[2]), v(f[3]), v(f[4])
        t0, t1, q1, q2, cu, cv, r = (float(x) for x in f[5:12])
        for extra in f[12:]:
            if extra.startswith("len="):                     # the reference runs past a convex end for the Boolean; in a CAD the cut is flush with the end face
                t0, t1 = max(t0, 0.0), min(t1, float(extra[4:]))
        O = add(p0, e, t0)
        A, B = add(O, d1, q1), add(O, d2, q2)
        Cc = add(add(O, d1, cu), d2, cv)
        pl, ax = plane_of(e)
        out.append(f"{n}. Cut by a swept profile. Sketch on the {pl} plane at {ax} = {O['XYZ'.index(ax)]:.4f} (the plane through the corner point perpendicular to the edge), one closed profile:")
        out.append(f"   - corner point O = {fm(O)}")
        out.append(f"   - line from O to A = {fm(A)}")
        out.append(f"   - arc centre {fm(Cc)}, radius {r:g}, from A to B = {fm(B)}, the short way round (it bulges towards O)")
        out.append(f"   - line from B back to O")
        out.append(f"   Extrude the profile {abs(t1 - t0):.4f} along ({e[0]:g}, {e[1]:g}, {e[2]:g}) as a Subtract (Combine, Cut) from the body.")
    elif f[0] == "V":
        O, sd, r, deg = v(f[1]), v(f[2]), float(f[3]), float(f[4])
        A, B = add(O, sd, r), add(O, (0.0, 0.0, 1.0), -r)
        Cc = add(add(O, sd, r), (0.0, 0.0, 1.0), -r)
        out.append(f"{n}. Cut the revolved corner piece. Sketch on the vertical plane through O = {fm(O)} that contains the direction ({sd[0]:g}, {sd[1]:g}, {sd[2]:g}), one closed profile:")
        out.append(f"   - line from O to A = {fm(A)}")
        out.append(f"   - arc centre {fm(Cc)}, radius {r:g}, from A to B = {fm(B)}, the short way round (it bulges towards O)")
        out.append(f"   - line from B back to O")
        out.append(f"   Revolve the profile {deg:g} degrees about the vertical axis through O, counter-clockwise seen from above starting from that direction, as a Subtract from the body.")
    else:
        b = [float(x) for x in f[1].split(",")]
        c = v(f[2])
        out.append(f"{n}. Cut the corner piece: make a box with opposite corners ({b[0]:g}, {b[1]:g}, {b[2]:g}) and ({b[3]:g}, {b[4]:g}, {b[5]:g}) as a separate body, make a sphere centre {fm(c)} radius {float(f[3]):g} as a second body, Subtract the sphere from the box (what is left is the corner cube minus the ball), then Subtract that piece from the main body.")
    return out


def base_steps(case):
    poly = case.poly
    if len(poly) == 4 and case.shape.startswith("box"):
        return [f"1. Base solid: sketch on the XY plane a rectangle with corners (0, 0) and ({poly[2][0]:g}, {poly[2][1]:g}); extrude {case.H:g} along +Z."]
    pts = ", ".join("(%g, %g)" % p for p in poly)
    return [f"1. Base solid: sketch on the XY plane the closed polyline {pts}; extrude {case.H:g} along +Z."]


def profile_steps(g, length, label):
    out = [label]
    cur, step = None, 0
    for seg in g.path:
        if seg[0] == "S":
            cur = seg[1]; step = 1
            out.append(f"   {step}. Start at ({cur[0]:.4f}, {cur[1]:.4f}).")
            continue
        step += 1
        if seg[0] == "L":
            out.append(f"   {step}. Line to ({seg[1][0]:.4f}, {seg[1][1]:.4f}).")
            cur = seg[1]
        else:
            c, r = g.arcs[(round(cur[0], 6), round(cur[1], 6), round(seg[2][0], 6), round(seg[2][1], 6))]
            out.append(f"   {step}. Arc, centre ({c[0]:.4f}, {c[1]:.4f}), radius {r:g}, from ({cur[0]:.4f}, {cur[1]:.4f}) to ({seg[2][0]:.4f}, {seg[2][1]:.4f}), the short way round.")
            cur = seg[2]
    out.append(f"   {step + 1}. Close the profile with a line, then extrude {length:g}.")
    return out


def steps(case, R):
    out = base_steps(case)
    for i, it in enumerate(case.items):
        out += item_steps(it, i + 2)
    if case.kind == "frame":
        W, D = case.poly[2]
        r = case.edges[0][0]
        gx = R.build_add(W, case.H, r, r)
        gy = R.build_add(D, case.H, r, r)
        out.append("")
        out.append("Shorter equivalent for a frame: build the two rounded profiles and Intersect them.")
        out += profile_steps(gx, D, f"   Body 1, sketch on the XZ plane (origin at the box's lower-left corner), the profile across the {W:g} mm width, extruded {D:g} along +Y:")
        out += profile_steps(gy, W, f"   Body 2, sketch on the YZ plane, the profile across the {D:g} mm length, extruded {W:g} along +X:")
        out.append("   Intersect (Combine, Common) Body 1 with Body 2.")
    return out
