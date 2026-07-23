// Verification harness for OCCTSwift#363 / Open-Cascade-SAS/OCCT#1388: redesigning
// XCAFDoc_ShapeTool's auto-naming override from a shared process-wide flag (theAutoNaming,
// guarded by a recursive_mutex in the old AutoNamingScope) to a field on each ShapeTool
// instance (OwnAutoNamingScope). Pure C++, no Swift/bridge layer -- isolates OCCT itself,
// same convention as Scripts/repro/341-meshcaf/.
//
// Two properties matter here, and they're independently checkable:
//
//  1. Race-free (the original #341 bar). obj_roundtrip_unique is the same repro #341 used
//     to find the theAutoNaming race in the first place -- concurrent OBJ round-trips,
//     which internally exercise OwnAutoNamingScope via RWObj_CafReader ->
//     RWMesh_CafReader::fillDocument(). Expect zero TSan reports, same as after #341's
//     original fix.
//
//  2. Isolation -- the property the OLD mutex+atomic fix did NOT provide. Upstream
//     reviewer gkv311's critique of OCCT#1388 ("a mutex is not the right tool here...
//     usage remains unprotected within XCAFDoc_ShapeTool.cpp itself"): the old fix
//     serialized the three known save/modify/restore call sites against each other, but
//     every OTHER read of theAutoNaming in the file (AddShape, MakeReference, SetSHUO)
//     stayed outside any scope -- an unrelated, unscoped caller on another thread could
//     still observe a temporary override meant only for the scoped caller's own document.
//     Scenario "isolation" checks this directly: half the threads force auto-naming OFF on
//     their own document (OwnAutoNamingScope, simulating fillDocument()'s internal usage),
//     the other half do plain unscoped AddShape() on independent documents relying on the
//     global default (true) -- assert the unscoped threads' shapes are named on EVERY
//     iteration, throughout sustained concurrent pressure from the overriding threads. Any
//     miss is the exact leak the old design couldn't rule out.
//
// Usage: occt_363_isolation <scenario> <threads> <iterations> [tmpDir]
//   scenarios: obj_roundtrip_unique | isolation

#include <atomic>
#include <chrono>
#include <cstdarg>
#include <cstdio>
#include <cstdlib>
#include <sstream>
#include <string>
#include <thread>
#include <vector>

#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepMesh_IncrementalMesh.hxx>
#include <RWObj_CafReader.hxx>
#include <RWObj_CafWriter.hxx>
#include <TDocStd_Document.hxx>
#include <XCAFDoc_DocumentTool.hxx>
#include <XCAFDoc_ShapeTool.hxx>
#include <TDataStd_Name.hxx>
#include <NCollection_IndexedDataMap.hxx>
#include <Message_ProgressRange.hxx>

std::atomic<long> gOps{0};
std::atomic<long> gErrors{0};
std::atomic<long> gDefaultThreadNamed{0};
std::atomic<long> gDefaultThreadUnnamed{0}; // should stay 0 -- any >0 is the leak

static void note(const char* fmt, ...) {
    va_list args;
    va_start(args, fmt);
    vfprintf(stderr, fmt, args);
    va_end(args);
    fprintf(stderr, "\n");
}

// ---------------------------------------------------------------------------
// Scenario: obj_roundtrip_unique -- same repro #341 used, now exercising
// OwnAutoNamingScope's per-instance path instead of the old global mutex.
// ---------------------------------------------------------------------------
void runObjRoundtripUnique(int id, int iterations, const std::string& tmpDir) {
    for (int it = 0; it < iterations; ++it) {
        TopoDS_Shape box = BRepPrimAPI_MakeBox(10, 20, 30).Shape();
        BRepMesh_IncrementalMesh mesher(box, 0.5);
        mesher.Perform();

        std::ostringstream pathStream;
        pathStream << tmpDir << "/occt363_obj_" << id << "_" << it << ".obj";
        std::string path = pathStream.str();

        Handle(TDocStd_Document) writeDoc = new TDocStd_Document("BinXCAF");
        Handle(XCAFDoc_ShapeTool) shapeTool = XCAFDoc_DocumentTool::ShapeTool(writeDoc->Main());
        shapeTool->AddShape(box);

        NCollection_IndexedDataMap<TCollection_AsciiString, TCollection_AsciiString> fileInfo;
        RWObj_CafWriter writer(path.c_str());
        Message_ProgressRange range;
        bool wroteOk = writer.Perform(writeDoc, fileInfo, range);
        if (!wroteOk) { gErrors++; note("[thread %d] OBJ write failed: %s", id, path.c_str()); continue; }

        Handle(TDocStd_Document) readDoc = new TDocStd_Document("BinXCAF");
        RWObj_CafReader reader;
        reader.SetDocument(readDoc);
        bool readOk = reader.Perform(path.c_str(), range);
        if (!readOk) { gErrors++; note("[thread %d] OBJ read failed: %s", id, path.c_str()); continue; }

        std::remove(path.c_str());
        gOps++;
    }
}

// ---------------------------------------------------------------------------
// Scenario: isolation. See file header for the property under test.
// ---------------------------------------------------------------------------
void runOverrideOff(int id, int iterations) {
    for (int it = 0; it < iterations; ++it) {
        Handle(TDocStd_Document) doc = new TDocStd_Document("BinXCAF");
        Handle(XCAFDoc_ShapeTool) shapeTool = XCAFDoc_DocumentTool::ShapeTool(doc->Main());
        TopoDS_Shape box = BRepPrimAPI_MakeBox(10, 20, 30).Shape();
        {
            XCAFDoc_ShapeTool::OwnAutoNamingScope scope(shapeTool, false);
            TDF_Label label = shapeTool->AddShape(box);
            // Sanity: the override must actually take effect on THIS instance too.
            if (label.IsAttribute(TDataStd_Name::GetID())) {
                gErrors++;
                note("[override thread %d] shape got a name despite OwnAutoNamingScope(false)", id);
            }
        }
        gOps++;
    }
}

void runDefaultOn(int id, int iterations) {
    for (int it = 0; it < iterations; ++it) {
        Handle(TDocStd_Document) doc = new TDocStd_Document("BinXCAF");
        Handle(XCAFDoc_ShapeTool) shapeTool = XCAFDoc_DocumentTool::ShapeTool(doc->Main());
        TopoDS_Shape box = BRepPrimAPI_MakeBox(10, 20, 30).Shape();
        // No override -- inherits XCAFDoc_ShapeTool::AutoNaming(), which defaults true and
        // is never changed by anyone in this harness (only OwnAutoNamingScope is used,
        // which never touches the process-wide default).
        TDF_Label label = shapeTool->AddShape(box);
        if (label.IsAttribute(TDataStd_Name::GetID())) {
            gDefaultThreadNamed++;
        } else {
            gDefaultThreadUnnamed++;
            gErrors++;
            note("[default thread %d] shape got NO name despite global AutoNaming()==true -- "
                 "leaked another thread's local override",
                 id);
        }
        gOps++;
    }
}

int main(int argc, char** argv) {
    std::string scenario = argc > 1 ? argv[1] : "isolation";
    int threads = argc > 2 ? atoi(argv[2]) : 8;
    int iterations = argc > 3 ? atoi(argv[3]) : 50;
    std::string tmpDir = argc > 4 ? argv[4] : "/tmp";

    note("scenario=%s threads=%d iterations=%d", scenario.c_str(), threads, iterations);

    std::vector<std::thread> pool;
    auto t0 = std::chrono::steady_clock::now();

    if (scenario == "obj_roundtrip_unique") {
        for (int i = 0; i < threads; ++i) pool.emplace_back(runObjRoundtripUnique, i, iterations, tmpDir);
    } else if (scenario == "isolation") {
        for (int i = 0; i < threads; ++i) {
            if (i % 2 == 0) pool.emplace_back(runOverrideOff, i, iterations);
            else pool.emplace_back(runDefaultOn, i, iterations);
        }
    } else {
        note("unknown scenario: %s", scenario.c_str());
        return 2;
    }

    for (auto& t : pool) t.join();

    auto t1 = std::chrono::steady_clock::now();
    double secs = std::chrono::duration<double>(t1 - t0).count();
    note("done: ops=%ld errors=%ld defaultNamed=%ld defaultUnnamed=%ld elapsed=%.2fs",
         gOps.load(), gErrors.load(), gDefaultThreadNamed.load(), gDefaultThreadUnnamed.load(), secs);
    return gErrors.load() > 0 ? 1 : 0;
}
