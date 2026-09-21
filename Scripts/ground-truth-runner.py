#!/usr/bin/env python3
"""
ground-truth-runner.py — Compile/run C++ against OCCT kernel directly.

Reads test spec (bridge function, inputs), generates C++ test calling OCCT kernel,
compiles with xcframework headers/libs, runs and captures output.
"""

import json
import sys
import os
import argparse
import subprocess
import tempfile
import shutil
import time
import shlex
from pathlib import Path
from typing import Dict, List, Any, Optional
from dataclasses import dataclass, asdict


@dataclass
class TestInput:
    name: str
    type: str
    value: Any


@dataclass
class TestSpec:
    bridge_function: str
    inputs: List[TestInput]
    test_name: str
    occt_class: str = ""
    occt_method: str = ""
    occt_headers: Optional[List[str]] = None
    setup_code: str = ""
    cleanup_code: str = ""

    def __post_init__(self):
        if self.occt_headers is None:
            self.occt_headers = []


def find_xcframework() -> Path:
    """Find the OCCT.xcframework in the build artifacts"""
    possible_paths = [
        Path(__file__).parent.parent / ".build" / "artifacts" / "epic_766" / "OCCT" / "OCCT.xcframework",
        Path(__file__).parent.parent / ".build" / "index-build" / "artifacts" / "epic_766" / "OCCT" / "OCCT.xcframework",
        Path(__file__).parent.parent / "Libraries" / "OCCT.xcframework",
    ]

    for path in possible_paths:
        if path.exists():
            return path

    raise FileNotFoundError("OCCT.xcframework not found in expected locations")


def get_xcframework_paths(xcframework: Path) -> Dict[str, Path]:
    """Get headers and library paths for macOS arm64"""
    macos_path = xcframework / "macos-arm64"
    if not macos_path.exists():
        raise FileNotFoundError(f"macos-arm64 slice not found in {xcframework}")

    headers = macos_path / "Headers"
    lib = macos_path / "libOCCT-macos.a"

    if not headers.exists():
        raise FileNotFoundError(f"Headers not found at {headers}")
    if not lib.exists():
        raise FileNotFoundError(f"Library not found at {lib}")

    return {
        "headers": headers,
        "library": lib,
        "framework_dir": macos_path
    }


# Mapping from bridge function to OCCT kernel call
BRIDGE_TO_OCCT = {
    "OCCTShapeFillet": {
        "class": "BRepFilletAPI_MakeFillet",
        "method": "",
        "headers": ["BRepFilletAPI_MakeFillet.hxx", "TopoDS_Shape.hxx", "TopoDS_Edge.hxx", "TopExp_Explorer.hxx", "BRepPrimAPI_MakeBox.hxx"],
        "call_template": "static",
        "requires_base_shape": True
    },
    "OCCTShapeChamfer": {
        "class": "BRepFilletAPI_MakeChamfer",
        "method": "",
        "headers": ["BRepFilletAPI_MakeChamfer.hxx", "TopoDS_Shape.hxx", "TopoDS_Edge.hxx", "TopExp_Explorer.hxx", "BRepPrimAPI_MakeBox.hxx"],
        "call_template": "static",
        "requires_base_shape": True
    },
    "OCCTShapeBooleanFuse": {
        "class": "BRepAlgoAPI_Fuse",
        "method": "",
        "headers": ["BRepAlgoAPI_Fuse.hxx", "TopoDS_Shape.hxx", "BRepPrimAPI_MakeBox.hxx"],
        "call_template": "static",
        "requires_base_shape": True
    },
    "OCCTShapeBooleanCut": {
        "class": "BRepAlgoAPI_Cut",
        "method": "",
        "headers": ["BRepAlgoAPI_Cut.hxx", "TopoDS_Shape.hxx", "BRepPrimAPI_MakeBox.hxx"],
        "call_template": "static",
        "requires_base_shape": True
    },
    "OCCTShapeBooleanCommon": {
        "class": "BRepAlgoAPI_Common",
        "method": "",
        "headers": ["BRepAlgoAPI_Common.hxx", "TopoDS_Shape.hxx", "BRepPrimAPI_MakeBox.hxx"],
        "call_template": "static",
        "requires_base_shape": True
    },
    "OCCTShapeOffset": {
        "class": "BRepOffsetAPI_MakeOffset",
        "method": "",
        "headers": ["BRepOffsetAPI_MakeOffset.hxx", "TopoDS_Shape.hxx", "TopoDS_Face.hxx", "TopExp_Explorer.hxx", "BRepPrimAPI_MakeBox.hxx"],
        "call_template": "static",
        "requires_base_shape": True
    },
    "OCCTShapeThicken": {
        "class": "BRepOffsetAPI_MakeThickSolid",
        "method": "",
        "headers": ["BRepOffsetAPI_MakeThickSolid.hxx", "TopoDS_Shape.hxx", "TopoDS_Face.hxx", "TopExp_Explorer.hxx", "BRepPrimAPI_MakeBox.hxx"],
        "call_template": "static",
        "requires_base_shape": True
    },
    "OCCTShapeDraft": {
        "class": "BRepOffsetAPI_DraftAngle",
        "method": "",
        "headers": ["BRepOffsetAPI_DraftAngle.hxx", "TopoDS_Shape.hxx", "TopoDS_Face.hxx", "gp_Dir.hxx", "TopExp_Explorer.hxx", "BRepPrimAPI_MakeBox.hxx"],
        "call_template": "static",
        "requires_base_shape": True
    },
    "OCCTShapeHollow": {
        "class": "BRepOffsetAPI_MakeThickSolid",
        "method": "",
        "headers": ["BRepOffsetAPI_MakeThickSolid.hxx", "TopoDS_Shape.hxx", "TopoDS_Face.hxx", "TopExp_Explorer.hxx", "BRepPrimAPI_MakeBox.hxx"],
        "call_template": "static",
        "requires_base_shape": True
    },
    "OCCTShapeRevolution": {
        "class": "BRepPrimAPI_MakeRevol",
        "method": "",
        "headers": ["BRepPrimAPI_MakeRevol.hxx", "TopoDS_Shape.hxx", "gp_Ax1.hxx"],
        "call_template": "static"
    },
    "OCCTShapeExtrusion": {
        "class": "BRepPrimAPI_MakePrism",
        "method": "",
        "headers": ["BRepPrimAPI_MakePrism.hxx", "TopoDS_Shape.hxx", "gp_Vec.hxx"],
        "call_template": "static"
    },
    "OCCTShapeLoft": {
        "class": "BRepOffsetAPI_ThruSections",
        "method": "",
        "headers": ["BRepOffsetAPI_ThruSections.hxx", "TopoDS_Wire.hxx", "TopoDS_Vertex.hxx", "TopExp_Explorer.hxx"],
        "call_template": "static"
    },
    "OCCTShapeSewing": {
        "class": "BRepBuilderAPI_Sewing",
        "method": "Perform",
        "headers": ["BRepBuilderAPI_Sewing.hxx", "TopoDS_Shape.hxx", "TopoDS_Face.hxx", "TopExp_Explorer.hxx"],
        "call_template": "instance"
    },
    "OCCTShapeCheck": {
        "class": "BRepCheck_Analyzer",
        "method": "",
        "headers": ["BRepCheck_Analyzer.hxx", "TopoDS_Shape.hxx"],
        "call_template": "static"
    },
    "OCCTShapeClean": {
        "class": "ShapeFix_Shape",
        "method": "Perform",
        "headers": ["ShapeFix_Shape.hxx", "TopoDS_Shape.hxx"],
        "call_template": "instance"
    },
    "OCCTShapeFixFace": {
        "class": "ShapeFix_Face",
        "method": "Perform",
        "headers": ["ShapeFix_Face.hxx", "TopoDS_Face.hxx"],
        "call_template": "instance"
    },
    "OCCTShapeFixWire": {
        "class": "ShapeFix_Wire",
        "method": "Perform",
        "headers": ["ShapeFix_Wire.hxx", "TopoDS_Wire.hxx"],
        "call_template": "instance"
    },
    "OCCTShapeHeal": {
        "class": "ShapeHealing_ShapeTolerance",
        "method": "",
        "headers": ["ShapeHealing_ShapeTolerance.hxx", "TopoDS_Shape.hxx"],
        "call_template": "static"
    },
    "OCCTCurve3DInterpolate": {
        "class": "GeomAPI_Interpolate",
        "method": "Perform",
        "headers": ["GeomAPI_Interpolate.hxx", "TColgp_Array1OfPnt.hxx", "TColgp_HArray1OfPnt.hxx", "Geom_BSplineCurve.hxx"],
        "call_template": "instance"
    },
    "OCCTCurve3DApprox": {
        "class": "GeomConvert_ApproxCurve",
        "method": "",
        "headers": ["GeomConvert_ApproxCurve.hxx", "Geom_Curve.hxx", "Geom_BSplineCurve.hxx"],
        "call_template": "static"
    },
    "OCCTSurfaceFill": {
        "class": "GeomFill_ConstrainedFilling",
        "method": "",
        "headers": ["GeomFill_ConstrainedFilling.hxx", "Geom_Surface.hxx", "Geom_BSplineSurface.hxx"],
        "call_template": "static"
    },
    "OCCTSurfaceApprox": {
        "class": "GeomConvert_ApproxSurface",
        "method": "",
        "headers": ["GeomConvert_ApproxSurface.hxx", "Geom_Surface.hxx", "Geom_BSplineSurface.hxx"],
        "call_template": "static"
    },
}


def generate_cpp_test(spec: TestSpec, xcframework_paths: Dict[str, Path]) -> str:
    """Generate C++ test code that calls OCCT kernel directly"""

    # Get OCCT mapping for this bridge function
    mapping = BRIDGE_TO_OCCT.get(spec.bridge_function, {})
    occt_class = spec.occt_class or mapping.get("class", "")
    occt_method = spec.occt_method or mapping.get("method", "")
    occt_headers = spec.occt_headers or mapping.get("headers", [])
    call_template = mapping.get("call_template", "static")
    requires_base_shape = mapping.get("requires_base_shape", False)

    includes = [
        "#include <iostream>",
        "#include <iomanip>",
        "#include <cmath>",
        "#include <vector>",
        "#include <string>",
        "#include <typeinfo>",
        "",
        "// OCCT headers",
        "#include <Standard.hxx>",
        "#include <Standard_Handle.hxx>",
        "#include <Standard_Failure.hxx>",
        "#include <TopoDS.hxx>",
        "#include <TopoDS_Shape.hxx>",
        "#include <TopoDS_Face.hxx>",
        "#include <TopoDS_Edge.hxx>",
        "#include <TopoDS_Wire.hxx>",
        "#include <TopoDS_Vertex.hxx>",
        "#include <TopExp_Explorer.hxx>",
    ]

    # Add OCCT-specific headers
    for inc in occt_headers:
        includes.append(f"#include <{inc}>")

    # Add any additional headers from spec
    # (spec.occt_headers already included above)

    # Generate input setup code
    input_setup = []
    input_decls = []
    for inp in spec.inputs:
        name = inp.name
        type_ = inp.type
        value = inp.value

        if type_ == "int":
            input_decls.append(f"    Standard_Integer {name};")
            input_setup.append(f"    {name} = {value};")
        elif type_ == "double":
            input_decls.append(f"    Standard_Real {name};")
            input_setup.append(f"    {name} = {value};")
        elif type_ == "bool":
            input_decls.append(f"    Standard_Boolean {name};")
            input_setup.append(f"    {name} = {str(value).lower()};")
        elif type_ == "string":
            input_decls.append(f"    TCollection_AsciiString {name};")
            input_setup.append(f'    {name} = TCollection_AsciiString("{value}");')
        elif type_ == "gp_Pnt":
            input_decls.append(f"    gp_Pnt {name};")
            if isinstance(value, list) and len(value) == 3:
                input_setup.append(f"    {name} = gp_Pnt({value[0]}, {value[1]}, {value[2]});")
        elif type_ == "gp_Pnt2d":
            input_decls.append(f"    gp_Pnt2d {name};")
            if isinstance(value, list) and len(value) == 2:
                input_setup.append(f"    {name} = gp_Pnt2d({value[0]}, {value[1]});")
        elif type_ == "gp_Dir":
            input_decls.append(f"    gp_Dir {name};")
            if isinstance(value, list) and len(value) == 3:
                input_setup.append(f"    {name} = gp_Dir({value[0]}, {value[1]}, {value[2]});")
        elif type_ == "gp_Dir2d":
            input_decls.append(f"    gp_Dir2d {name};")
            if isinstance(value, list) and len(value) == 2:
                input_setup.append(f"    {name} = gp_Dir2d({value[0]}, {value[1]});")
        elif type_ == "gp_Vec":
            input_decls.append(f"    gp_Vec {name};")
            if isinstance(value, list) and len(value) == 3:
                input_setup.append(f"    {name} = gp_Vec({value[0]}, {value[1]}, {value[2]});")
        elif type_ == "gp_Ax1":
            input_decls.append(f"    gp_Ax1 {name};")
            if isinstance(value, dict):
                loc = value.get("location", [0, 0, 0])
                dir_ = value.get("direction", [0, 0, 1])
                input_setup.append(f"    {name} = gp_Ax1(gp_Pnt({loc[0]}, {loc[1]}, {loc[2]}), gp_Dir({dir_[0]}, {dir_[1]}, {dir_[2]}));")
        elif type_ == "gp_Ax2":
            input_decls.append(f"    gp_Ax2 {name};")
            if isinstance(value, dict):
                loc = value.get("location", [0, 0, 0])
                dir_ = value.get("direction", [0, 0, 1])
                xdir = value.get("x_direction", [1, 0, 0])
                input_setup.append(f"    {name} = gp_Ax2(gp_Pnt({loc[0]}, {loc[1]}, {loc[2]}), gp_Dir({dir_[0]}, {dir_[1]}, {dir_[2]}), gp_Dir({xdir[0]}, {xdir[1]}, {xdir[2]}));")
        elif type_ == "gp_Ax3":
            input_decls.append(f"    gp_Ax3 {name};")
            if isinstance(value, dict):
                loc = value.get("location", [0, 0, 0])
                dir_ = value.get("direction", [0, 0, 1])
                xdir = value.get("x_direction", [1, 0, 0])
                input_setup.append(f"    {name} = gp_Ax3(gp_Pnt({loc[0]}, {loc[1]}, {loc[2]}), gp_Dir({dir_[0]}, {dir_[1]}, {dir_[2]}), gp_Dir({xdir[0]}, {xdir[1]}, {xdir[2]}));")
        elif type_ == "gp_Trsf":
            input_decls.append(f"    gp_Trsf {name};")
            input_setup.append(f"    {name}.SetIdentity();")
        elif type_ == "TopoDS_Shape":
            input_decls.append(f"    TopoDS_Shape {name};")
            input_setup.append(f"    // {name}: placeholder - shape construction not implemented")
        elif type_ == "TopoDS_Face":
            input_decls.append(f"    TopoDS_Face {name};")
            input_setup.append(f"    // {name}: placeholder - face construction not implemented")
        elif type_ == "TopoDS_Edge":
            input_decls.append(f"    TopoDS_Edge {name};")
            input_setup.append(f"    // {name}: placeholder - edge construction not implemented")
        elif type_ == "TopoDS_Wire":
            input_decls.append(f"    TopoDS_Wire {name};")
            input_setup.append(f"    // {name}: placeholder - wire construction not implemented")
        elif type_ == "TopoDS_Vertex":
            input_decls.append(f"    TopoDS_Vertex {name};")
            input_setup.append(f"    // {name}: placeholder - vertex construction not implemented")
        else:
            input_decls.append(f"    // TODO: Input type {type_} not fully supported")
            input_setup.append(f"    // {name} = ?;")

    # Generate the OCCT call
    call_code = []

    # Create base shape if required (e.g., for fillet, chamfer, boolean ops)
    if requires_base_shape:
        call_code.append(f"    // Create a base shape (unit box) for the operation")
        call_code.append(f"    TopoDS_Shape baseShape = BRepPrimAPI_MakeBox(10.0, 10.0, 10.0).Shape();")

    if call_template == "static":
        # Static/factory method call
        if occt_class == "BRepFilletAPI_MakeFillet":
            if requires_base_shape:
                call_code.append(f"    {occt_class} fillet(baseShape);")
            else:
                call_code.append(f"    {occt_class} fillet;")
            call_code.append(f"    // Add edges to fillet (placeholder)")
            call_code.append(f"    // fillet.Add(edge, radius);")
            call_code.append(f"    fillet.Build();")
            call_code.append(f"    TopoDS_Shape result = fillet.Shape();")
        elif occt_class == "BRepFilletAPI_MakeChamfer":
            if requires_base_shape:
                call_code.append(f"    {occt_class} chamfer(baseShape);")
            else:
                call_code.append(f"    {occt_class} chamfer;")
            call_code.append(f"    // Add edges to chamfer (placeholder)")
            call_code.append(f"    chamfer.Build();")
            call_code.append(f"    TopoDS_Shape result = chamfer.Shape();")
        elif occt_class in ["BRepAlgoAPI_Fuse", "BRepAlgoAPI_Cut", "BRepAlgoAPI_Common"]:
            if requires_base_shape:
                call_code.append(f"    TopoDS_Shape toolShape = BRepPrimAPI_MakeBox(5.0, 5.0, 5.0).Shape();")
                call_code.append(f"    {occt_class} boolOp(baseShape, toolShape);")
            else:
                call_code.append(f"    {occt_class} boolOp;")
            call_code.append(f"    // Set arguments (placeholder)")
            call_code.append(f"    boolOp.Build();")
            call_code.append(f"    TopoDS_Shape result = boolOp.Shape();")
        elif occt_class == "BRepOffsetAPI_MakeOffset":
            if requires_base_shape:
                call_code.append(f"    {occt_class} offset(baseShape);")
            else:
                call_code.append(f"    {occt_class} offset;")
            call_code.append(f"    // Add faces and set parameters (placeholder)")
            call_code.append(f"    offset.Build();")
            call_code.append(f"    TopoDS_Shape result = offset.Shape();")
        elif occt_class == "BRepOffsetAPI_MakeThickSolid":
            if requires_base_shape:
                call_code.append(f"    {occt_class} thicken(baseShape);")
            else:
                call_code.append(f"    {occt_class} thicken;")
            call_code.append(f"    // Add faces and set parameters (placeholder)")
            call_code.append(f"    thicken.Build();")
            call_code.append(f"    TopoDS_Shape result = thicken.Shape();")
        elif occt_class == "BRepOffsetAPI_DraftAngle":
            if requires_base_shape:
                call_code.append(f"    {occt_class} draft(baseShape);")
            else:
                call_code.append(f"    {occt_class} draft;")
            call_code.append(f"    // Add faces and set parameters (placeholder)")
            call_code.append(f"    draft.Build();")
            call_code.append(f"    TopoDS_Shape result = draft.Shape();")
        elif occt_class == "BRepPrimAPI_MakeRevol":
            call_code.append(f"    {occt_class} revol;")
            call_code.append(f"    // Set parameters (placeholder)")
            call_code.append(f"    revol.Build();")
            call_code.append(f"    TopoDS_Shape result = revol.Shape();")
        elif occt_class == "BRepPrimAPI_MakePrism":
            call_code.append(f"    {occt_class} prism;")
            call_code.append(f"    // Set parameters (placeholder)")
            call_code.append(f"    prism.Build();")
            call_code.append(f"    TopoDS_Shape result = prism.Shape();")
        elif occt_class == "BRepOffsetAPI_ThruSections":
            call_code.append(f"    {occt_class} thruSections;")
            call_code.append(f"    // Add wires/vertices (placeholder)")
            call_code.append(f"    thruSections.Build();")
            call_code.append(f"    TopoDS_Shape result = thruSections.Shape();")
        elif occt_class == "BRepCheck_Analyzer":
            if requires_base_shape:
                call_code.append(f"    {occt_class} analyzer(baseShape);")
            else:
                call_code.append(f"    {occt_class} analyzer(baseShape);")
            call_code.append(f"    Standard_Boolean result = analyzer.IsValid();")
        elif occt_class == "ShapeHealing_ShapeTolerance":
            if requires_base_shape:
                call_code.append(f"    {occt_class} healer(baseShape);")
            else:
                call_code.append(f"    {occt_class} healer(baseShape);")
            call_code.append(f"    healer.Perform();")
            call_code.append(f"    TopoDS_Shape result = healer.Shape();")
        elif occt_class == "GeomAPI_Interpolate":
            call_code.append(f"    // Interpolation requires point array setup")
            call_code.append(f"    {occt_class} interp;")
            call_code.append(f"    interp.Perform();")
            call_code.append(f"    Handle(Geom_BSplineCurve) result = interp.Curve();")
        elif occt_class in ["GeomConvert_ApproxCurve", "GeomConvert_ApproxSurface"]:
            call_code.append(f"    {occt_class} approx;")
            call_code.append(f"    approx.Perform();")
            call_code.append(f"    Standard_Boolean result = approx.IsDone();")
        elif occt_class == "GeomFill_ConstrainedFilling":
            call_code.append(f"    {occt_class} filling;")
            call_code.append(f"    filling.Perform();")
            call_code.append(f"    Handle(Geom_BSplineSurface) result = filling.Surface();")
        else:
            call_code.append(f"    // Unknown OCCT class: {occt_class}")
            call_code.append(f"    Standard_Boolean result = Standard_False;")
    else:
        # Instance method call
        call_code.append(f"    {occt_class} obj;")
        call_code.append(f"    // Setup object (placeholder)")
        if occt_method:
            call_code.append(f"    obj.{occt_method}();")
        call_code.append(f"    Standard_Boolean result = Standard_True;")

    # Output capture - print result info
    output_code = [
        "    std::cout << \"status=success\" << std::endl;",
        "    std::cout << \"result_type=\" << typeid(result).name() << std::endl;",
    ]

    # Add shape-specific output if result is a shape
    if "result" in " ".join(call_code):
        output_code.extend([
            "    std::cout << \"result_null=\" << (result.IsNull() ? \"true\" : \"false\") << std::endl;",
            "    if (!result.IsNull()) {",
            "        std::cout << \"result_shape_type=\" << result.ShapeType() << std::endl;",
            "    }",
        ])

    cpp_code = f"""
{chr(10).join(includes)}

{spec.setup_code}

int main() {{
    try {{
{chr(10).join(input_decls)}

{chr(10).join(input_setup)}

{chr(10).join(call_code)}

{chr(10).join(output_code)}

        {spec.cleanup_code}
        return 0;
    }} catch (Standard_Failure& e) {{
        std::cerr << "OCCT Exception: " << e.GetMessageString() << std::endl;
        std::cout << "status=exception" << std::endl;
        return 1;
    }} catch (std::exception& e) {{
        std::cerr << "std::exception: " << e.what() << std::endl;
        std::cout << "status=exception" << std::endl;
        return 2;
    }} catch (...) {{
        std::cerr << "Unknown exception" << std::endl;
        std::cout << "status=crash" << std::endl;
        return 3;
    }}
}}
"""
    return cpp_code


def compile_and_run(cpp_code: str, xcframework_paths: Dict[str, Path], work_dir: Path) -> Dict[str, Any]:
    """Compile and run the C++ test"""

    cpp_file = work_dir / "ground_truth_test.mm"
    cpp_file.write_text(cpp_code)

    exe_file = work_dir / "ground_truth_test"

    headers = xcframework_paths["headers"]
    library = xcframework_paths["library"]

    framework_flags = "-framework Foundation -framework AppKit"

    compile_cmd = [
        "clang++",
        "-std=c++17",
        "-ObjC++",
        "-w",
        f"-I{shlex.quote(str(headers))}",
        f"-L{shlex.quote(str(library.parent))}",
        "-lOCCT-macos",
        "-framework", "Foundation",
        "-framework", "AppKit",
        "-lz",
        "-lc++",
        str(cpp_file),
        "-o",
        str(exe_file)
    ]

    start_time = time.time()

    try:
        result = subprocess.run(compile_cmd, capture_output=True, text=True, timeout=60)
        if result.returncode != 0:
            return {
                "status": "fail",
                "output": result.stderr,
                "return_code": result.returncode,
                "duration_ms": int((time.time() - start_time) * 1000)
            }
    except subprocess.TimeoutExpired:
        return {
            "status": "fail",
            "output": "Compilation timeout",
            "return_code": -1,
            "duration_ms": int((time.time() - start_time) * 1000)
        }
    except Exception as e:
        return {
            "status": "fail",
            "output": f"Compilation error: {e}",
            "return_code": -1,
            "duration_ms": int((time.time() - start_time) * 1000)
        }

    try:
        result = subprocess.run([str(exe_file)], capture_output=True, text=True, timeout=30)
        duration_ms = int((time.time() - start_time) * 1000)

        # Determine status from output
        status = "success" if result.returncode == 0 else "fail"
        if "status=crash" in result.stdout:
            status = "crash"
        elif "status=exception" in result.stdout:
            status = "fail"

        return {
            "status": status,
            "output": result.stdout,
            "return_code": result.returncode,
            "duration_ms": duration_ms
        }
    except subprocess.TimeoutExpired:
        return {
            "status": "fail",
            "output": "Execution timeout",
            "return_code": -1,
            "duration_ms": int((time.time() - start_time) * 1000)
        }
    except Exception as e:
        return {
            "status": "fail",
            "output": f"Execution error: {e}",
            "return_code": -1,
            "duration_ms": int((time.time() - start_time) * 1000)
        }


def load_spec_from_file(spec_file: Path) -> List[TestSpec]:
    with open(spec_file) as f:
        data = json.load(f)

    specs = []
    for item in data:
        inputs = [TestInput(**i) for i in item.get("inputs", [])]
        item["inputs"] = inputs
        specs.append(TestSpec(**item))
    return specs


def main():
    parser = argparse.ArgumentParser(description="Run ground truth C++ tests against OCCT kernel")
    parser.add_argument("--spec", help="Single test spec as JSON string")
    parser.add_argument("--spec-file", help="JSON file with array of test specs")
    parser.add_argument("--output", help="Output JSON file for results")
    parser.add_argument("--verbose", action="store_true", help="Verbose output")
    parser.add_argument("--work-dir", help="Working directory (default: temp)")

    args = parser.parse_args()

    try:
        xcframework = find_xcframework()
        if args.verbose:
            print(f"Found OCCT.xcframework at: {xcframework}")
    except FileNotFoundError as e:
        print(f"ERROR: {e}", file=sys.stderr)
        sys.exit(1)

    xcframework_paths = get_xcframework_paths(xcframework)

    if args.verbose:
        print(f"Headers: {xcframework_paths['headers']}")
        print(f"Library: {xcframework_paths['library']}")

    specs = []
    if args.spec:
        spec_data = json.loads(args.spec)
        inputs = [TestInput(**i) for i in spec_data.get("inputs", [])]
        spec_data["inputs"] = inputs
        specs.append(TestSpec(**spec_data))
    elif args.spec_file:
        specs = load_spec_from_file(Path(args.spec_file))
    else:
        print("ERROR: Either --spec or --spec-file required", file=sys.stderr)
        sys.exit(1)

    # Work directory
    if args.work_dir:
        work_dir = Path(args.work_dir)
        work_dir.mkdir(parents=True, exist_ok=True)
        cleanup_workdir = False
    else:
        work_dir = Path(tempfile.mkdtemp(prefix="occt_ground_truth_"))
        cleanup_workdir = True

    if args.verbose:
        print(f"Work directory: {work_dir}")

    results = []
    for spec in specs:
        if args.verbose:
            print(f"\nRunning: {spec.test_name}")
            print(f"  Bridge function: {spec.bridge_function}")

        cpp_code = generate_cpp_test(spec, xcframework_paths)

        if args.verbose:
            print(f"  Generated C++ ({len(cpp_code)} chars)")

        result = compile_and_run(cpp_code, xcframework_paths, work_dir)
        result["test_name"] = spec.test_name
        result["bridge_function"] = spec.bridge_function

        if args.verbose:
            print(f"  Result: {result['status']} (code={result['return_code']}, {result['duration_ms']}ms)")
            if result['output']:
                print(f"  Output: {result['output'][:200]}...")

        results.append(result)

    # Output results
    if args.output:
        with open(args.output, "w") as f:
            json.dump(results, f, indent=2)
        print(f"Results written to {args.output}")

    # Print JSON to stdout if no output file specified
    if not args.output:
        print(json.dumps(results, indent=2))

    # Cleanup
    if cleanup_workdir:
        shutil.rmtree(work_dir, ignore_errors=True)

    # Exit with error if any test failed
    any_failed = any(r["status"] != "success" for r in results)
    sys.exit(1 if any_failed else 0)


if __name__ == "__main__":
    main()