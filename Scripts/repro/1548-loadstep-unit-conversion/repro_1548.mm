// #1548: STEPControl_Reader::SetSystemLengthUnit ordering + scale-convention repro.
//
// Writes a 100 x 50 x 25 box to STEP (declared unit: millimeter, OCCT's own default), then
// re-imports it four ways to isolate both defects the issue raised:
//
//   A: correct order (ReadFile, then SetSystemLengthUnit(1.0))     -> expect unscaled (mm)
//   B: correct order, SetSystemLengthUnit(1000.0)                  -> expect /1000 (meters)
//   C: correct order, SetSystemLengthUnit(0.001) (doc's old "mm")  -> expect *1000 (backwards)
//   D: BUGGY order: SetSystemLengthUnit(1000.0) called before ReadFile()
//                                                                   -> expect unscaled (dead call)
//
// Build (from the repo root, against the pinned xcframework):
//
//   clang++ -std=c++17 -ObjC++ -w \
//     -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
//     -L"Libraries/OCCT.xcframework/macos-arm64" \
//     -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
//     Scripts/repro/1548-loadstep-unit-conversion/repro_1548.mm -o /tmp/repro_1548
//   /tmp/repro_1548
//
// Measured output (2026-09-04, pinned v3.0.0 kernel):
//
//   A cascade=1.0:    dims = (100, 50, 25)                 -- confirms 1.0 == 1 mm
//   B cascade=1000.0: dims = (0.1, 0.0500002, 0.0250002)    -- confirms 1000.0 == 1 m
//   C cascade=0.001:  dims = (100000, 50000, 25000)         -- doc's old examples were 1000x wrong
//   D buggy order:    dims = (100, 50, 25)                  -- unscaled: SetSystemLengthUnit() was
//                                                               a dead no-op, whatever value it got

#include <STEPControl_Reader.hxx>
#include <STEPControl_Writer.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <TopoDS_Shape.hxx>
#include <Bnd_Box.hxx>
#include <BRepBndLib.hxx>
#include <IFSelect_ReturnStatus.hxx>
#include <iostream>

static void printBBox(const char* label, const TopoDS_Shape& s)
{
  Bnd_Box box;
  BRepBndLib::Add(s, box);
  double xmin, ymin, zmin, xmax, ymax, zmax;
  box.Get(xmin, ymin, zmin, xmax, ymax, zmax);
  std::cout << label << ": dims = (" << (xmax - xmin) << ", " << (ymax - ymin) << ", "
            << (zmax - zmin) << ")\n";
}

int main()
{
  TopoDS_Shape box = BRepPrimAPI_MakeBox(100.0, 50.0, 25.0).Shape();

  const char* path = "/tmp/occt_1548_test_box.step";
  {
    STEPControl_Writer writer;
    writer.Transfer(box, STEPControl_AsIs);
    writer.Write(path);
  }

  {
    STEPControl_Reader reader;
    reader.ReadFile(path);
    reader.SetSystemLengthUnit(1.0);
    reader.TransferRoots();
    printBBox("A cascade=1.0 (expect mm, ~100/50/25)", reader.OneShape());
  }
  {
    STEPControl_Reader reader;
    reader.ReadFile(path);
    reader.SetSystemLengthUnit(1000.0);
    reader.TransferRoots();
    printBBox("B cascade=1000.0 (expect meters, ~0.1/0.05/0.025)", reader.OneShape());
  }
  {
    STEPControl_Reader reader;
    reader.ReadFile(path);
    reader.SetSystemLengthUnit(0.001);
    reader.TransferRoots();
    printBBox("C cascade=0.001 (doc's old 'mm' example)", reader.OneShape());
  }
  {
    STEPControl_Reader reader;
    reader.SetSystemLengthUnit(1000.0); // no-op: StepModel() is still null here
    reader.ReadFile(path);
    reader.TransferRoots();
    printBBox("D buggy order, cascade=1000.0 (expect UNSCALED, proving the dead call)",
              reader.OneShape());
  }

  return 0;
}
