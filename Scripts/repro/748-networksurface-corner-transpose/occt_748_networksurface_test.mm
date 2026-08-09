// Ground-truth reproducer for #748: GeomFill_NetworkSurface reports .done with two of
// four corners transposed.
//
// Replicates OCCTGeomFillNetworkSurface (Sources/OCCTBridge/src/OCCTBridge_Surface.mm,
// PR #741 head c311a7b) verbatim in `buggyNetworkSurface`, then a corrected version in
// `fixedNetworkSurface` that only transposes the ipts/iwts array so its axes match what
// GeomFill_NetworkSurface::Init's own isReadyToBuild() dimension check requires
// (ColLength() == guideCount, RowLength() == profileCount). Everything else is identical.

#include <GeomAPI_Interpolate.hxx>
#include <GeomAPI_ExtremaCurveCurve.hxx>
#include <GeomFill_NetworkSurface.hxx>
#include <GeomConvert.hxx>
#include <Geom_BSplineCurve.hxx>
#include <Geom_BSplineSurface.hxx>
#include <TColgp_HArray1OfPnt.hxx>
#include <NCollection_Array1.hxx>
#include <NCollection_Array2.hxx>
#include <gp_Pnt.hxx>

#include <cstdio>
#include <cmath>

static occ::handle<Geom_BSplineCurve> interp(std::initializer_list<gp_Pnt> pts) {
    Handle(TColgp_HArray1OfPnt) arr = new TColgp_HArray1OfPnt(1, (int)pts.size());
    int i = 1;
    for (auto& p : pts) arr->SetValue(i++, p);
    GeomAPI_Interpolate gi(arr, Standard_False, 1e-6);
    gi.Perform();
    occ::handle<Geom_Curve> c = gi.Curve();
    return GeomConvert::CurveToBSplineCurve(c);
}

// Verbatim port of OCCTGeomFillNetworkSurface's body (PR #741, c311a7b), minus the C ABI
// wrapper. `transpose` selects the ipts/iwts axis convention.
static occ::handle<Geom_BSplineSurface> networkSurface(
    NCollection_Array1<occ::handle<Geom_BSplineCurve>>& profs,
    NCollection_Array1<occ::handle<Geom_BSplineCurve>>& gds,
    double tolerance, GeomFill_NetworkSurface::ResultStatus& outStatus, bool transpose) {
    int profileCount = profs.Length();
    int guideCount = gds.Length();

    NCollection_Array2<gp_Pnt> ipts(1, transpose ? guideCount : profileCount, 1, transpose ? profileCount : guideCount);
    NCollection_Array2<double> iwts(1, transpose ? guideCount : profileCount, 1, transpose ? profileCount : guideCount);
    NCollection_Array2<double> profParam(1, profileCount, 1, guideCount);
    NCollection_Array2<double> guideParam(1, profileCount, 1, guideCount);
    for (int i = 0; i < profileCount; i++) {
        const Handle(Geom_BSplineCurve)& pc = profs.Value(i + 1);
        for (int j = 0; j < guideCount; j++) {
            const Handle(Geom_BSplineCurve)& gc = gds.Value(j + 1);
            GeomAPI_ExtremaCurveCurve ex(pc, gc);
            if (ex.IsParallel() || ex.NbExtrema() < 1) {
                outStatus = GeomFill_NetworkSurface::ResultStatus::InvalidInput;
                return nullptr;
            }
            gp_Pnt pp, gp;
            ex.NearestPoints(pp, gp);
            double pparam, gparam;
            ex.LowerDistanceParameters(pparam, gparam);
            if (transpose) {
                ipts.SetValue(j + 1, i + 1, pp);
                iwts.SetValue(j + 1, i + 1, 1.0);
            } else {
                ipts.SetValue(i + 1, j + 1, pp);
                iwts.SetValue(i + 1, j + 1, 1.0);
            }
            profParam.SetValue(i + 1, j + 1, pparam);
            guideParam.SetValue(i + 1, j + 1, gparam);
        }
    }

    NCollection_Array1<double> profileParams(1, profileCount);
    for (int i = 0; i < profileCount; i++) {
        double sum = 0.0;
        for (int j = 0; j < guideCount; j++) sum += guideParam.Value(i + 1, j + 1);
        profileParams.SetValue(i + 1, sum / guideCount);
    }
    NCollection_Array1<double> guideParams(1, guideCount);
    for (int j = 0; j < guideCount; j++) {
        double sum = 0.0;
        for (int i = 0; i < profileCount; i++) sum += profParam.Value(i + 1, j + 1);
        guideParams.SetValue(j + 1, sum / profileCount);
    }

    GeomFill_NetworkSurface net;
    net.Init(profs, gds, profileParams, guideParams, ipts, iwts, tolerance, false, false);
    net.Perform();
    outStatus = net.Status();
    if (!net.IsDone()) return nullptr;
    return net.Surface();
}

static void printCorner(const char* label, const occ::handle<Geom_BSplineSurface>& surf, double u, double v, double ex, double ey, double ez) {
    gp_Pnt p = surf->Value(u, v);
    double d = p.Distance(gp_Pnt(ex, ey, ez));
    printf("  %-6s u=%.2f v=%.2f -> (%.4f, %.4f, %.4f)  expected (%.2f, %.2f, %.2f)  err=%.6f  %s\n",
           label, u, v, p.X(), p.Y(), p.Z(), ex, ey, ez, d, d > 1e-6 ? "WRONG" : "ok");
}

int main() {
    // Plain bilinear rectangle, exactly issue #748's fixture.
    auto p1 = interp({gp_Pnt(0, 0, 0), gp_Pnt(10, 0, 0)});   // profile at y=0
    auto p2 = interp({gp_Pnt(0, 10, 0), gp_Pnt(10, 10, 0)}); // profile at y=10
    auto g1 = interp({gp_Pnt(0, 0, 0), gp_Pnt(0, 10, 0)});   // guide at x=0
    auto g2 = interp({gp_Pnt(10, 0, 0), gp_Pnt(10, 10, 0)}); // guide at x=10

    for (bool transpose : {false, true}) {
        NCollection_Array1<occ::handle<Geom_BSplineCurve>> profs(1, 2);
        profs.SetValue(1, p1);
        profs.SetValue(2, p2);
        NCollection_Array1<occ::handle<Geom_BSplineCurve>> gds(1, 2);
        gds.SetValue(1, g1);
        gds.SetValue(2, g2);

        GeomFill_NetworkSurface::ResultStatus status;
        auto surf = networkSurface(profs, gds, 1e-6, status, transpose);
        printf("%s: status=%d done=%s\n", transpose ? "FIXED  (ipts transposed)" : "BUGGY  (as in PR #741 head)",
               (int)status, surf.IsNull() ? "false" : "true");
        if (surf.IsNull()) continue;
        double u0 = surf->UKnots().First(), u1 = surf->UKnots().Last();
        double v0 = surf->VKnots().First(), v1 = surf->VKnots().Last();
        printCorner("(u0,v0)", surf, u0, v0, 0, 0, 0);
        printCorner("(u1,v0)", surf, u1, v0, 10, 0, 0);
        printCorner("(u0,v1)", surf, u0, v1, 0, 10, 0);
        printCorner("(u1,v1)", surf, u1, v1, 10, 10, 0);
        printf("\n");
    }

    // Non-square 2 profiles x 3 guides, to force the dimension check the issue's own
    // hypothesis wanted: with profileCount != guideCount the buggy (untransposed) build
    // should now fail outright (a real dimension mismatch), not silently transpose.
    printf("--- asymmetric 2 profiles x 3 guides ---\n");
    auto p3 = interp({gp_Pnt(0, 5, 0), gp_Pnt(10, 5, 0)}); // extra guide crossing at y=5
    NCollection_Array1<occ::handle<Geom_BSplineCurve>> profs2(1, 2);
    profs2.SetValue(1, p1);
    profs2.SetValue(2, p2);
    NCollection_Array1<occ::handle<Geom_BSplineCurve>> gds3(1, 3);
    gds3.SetValue(1, g1);
    auto gmid = interp({gp_Pnt(5, 0, 0), gp_Pnt(5, 10, 0)});
    gds3.SetValue(2, gmid);
    gds3.SetValue(3, g2);
    for (bool transpose : {false, true}) {
        GeomFill_NetworkSurface::ResultStatus status;
        auto surf = networkSurface(profs2, gds3, 1e-6, status, transpose);
        printf("%s: status=%d done=%s\n", transpose ? "FIXED  (ipts transposed)" : "BUGGY  (as in PR #741 head)",
               (int)status, surf.IsNull() ? "false" : "true");
        if (surf.IsNull()) continue;
        double u0 = surf->UKnots().First(), u1 = surf->UKnots().Last();
        double v0 = surf->VKnots().First(), v1 = surf->VKnots().Last();
        printCorner("(u0,v0)", surf, u0, v0, 0, 0, 0);
        printCorner("(u1,v0)", surf, u1, v0, 10, 0, 0);
        printCorner("(u0,v1)", surf, u0, v1, 0, 10, 0);
        printCorner("(u1,v1)", surf, u1, v1, 10, 10, 0);
        printCorner("(mid)", surf, (u0+u1)/2, (v0+v1)/2, 5, 5, 0);
        printf("\n");
    }
    return 0;
}
