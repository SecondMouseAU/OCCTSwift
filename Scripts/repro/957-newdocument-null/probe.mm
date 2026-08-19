/*
 * Probe: Can TDocStd_Application::NewDocument return null for "MDTV-XCAF"?
 *
 * Compile against the pinned xcframework:
 *   clang++ -std=c++17 -ObjC++ -w \
 *     -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
 *     -L"Libraries/OCCT.xcframework/macos-arm64" \
 *     -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
 *     probe.mm -o probe
 *
 * Run: ./probe
 */

#include <TDocStd_Application.hxx>
#include <TDocStd_Document.hxx>
#include <XCAFDoc_DocumentTool.hxx>
#include <XCAFDoc_ShapeTool.hxx>
#include <XCAFDoc_ColorTool.hxx>
#include <XCAFDoc_VisMaterialTool.hxx>
#include <iostream>

int main()
{
    Handle(TDocStd_Application) app = new TDocStd_Application();
    Handle(TDocStd_Document) doc;

    std::cout << "Testing NewDocument(\"MDTV-XCAF\", doc)..." << std::endl;
    app->NewDocument("MDTV-XCAF", doc);

    if (doc.IsNull())
    {
        std::cout << "RESULT: doc IS NULL (NewDocument failed)" << std::endl;
        return 1;
    }
    else
    {
        std::cout << "RESULT: doc is NOT null (NewDocument succeeded)" << std::endl;

        // Also test the tool fetches
        Handle(XCAFDoc_ShapeTool) shapeTool = XCAFDoc_DocumentTool::ShapeTool(doc->Main());
        Handle(XCAFDoc_ColorTool) colorTool = XCAFDoc_DocumentTool::ColorTool(doc->Main());
        Handle(XCAFDoc_VisMaterialTool) materialTool = XCAFDoc_DocumentTool::VisMaterialTool(doc->Main());

        std::cout << "  shapeTool.IsNull()   = " << shapeTool.IsNull() << std::endl;
        std::cout << "  colorTool.IsNull()   = " << colorTool.IsNull() << std::endl;
        std::cout << "  materialTool.IsNull() = " << materialTool.IsNull() << std::endl;

        return 0;
    }
}