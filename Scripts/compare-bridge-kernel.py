#!/usr/bin/env python3
"""
compare-bridge-kernel.py - Compare bridge function output with OCCT kernel ground truth.

Usage:
  python3 compare-bridge-kernel.py --spec '{"bridge_function": "OCCTShapeFillet", "inputs": [...]}'
  python3 compare-bridge-kernel.py --spec-file tests.json --output results.json
"""

import json
import subprocess
import sys
import os
import math
from typing import Any, Dict, List, Union

def compare_doubles(d1: float, d2: float, tol: float = 1e-12) -> bool:
    """Compare two doubles with relative tolerance."""
    if math.isnan(d1) and math.isnan(d2):
        return True
    if math.isinf(d1) and math.isinf(d2) and (d1 > 0) == (d2 > 0):
        return True
    if d1 == 0 and d2 == 0:
        return True
    rel_diff = abs(d1 - d2) / max(abs(d1), abs(d2))
    return rel_diff <= tol

def compare_vectors(v1: List[float], v2: List[float], tol: float = 1e-12) -> bool:
    """Compare two vectors element-wise."""
    if len(v1) != len(v2):
        return False
    return all(compare_doubles(a, b) for a, b in zip(v1, v2))

def compare_shapes(shape1: Dict, shape2: Dict) -> Dict:
    """Compare two shape representations."""
    differences = []
    
    # Compare topology counts
    for key in ['faces', 'edges', 'vertices', 'wires', 'shells', 'solids']:
        c1 = shape1.get(key, 0)
        c2 = shape2.get(key, 0)
        if c1 != c2:
            differences.append(f"{key}: bridge={c1}, kernel={c2}")
    
    # Compare geometry if present
    for key in ['face_areas', 'edge_lengths', 'vertex_positions']:
        v1 = shape1.get(key, [])
        v2 = shape2.get(key, [])
        if v1 or v2:
            if len(v1) != len(v2):
                differences.append(f"{key}: length mismatch ({len(v1)} vs {len(v2)})")
            else:
                for i, (a, b) in enumerate(zip(v1, v2)):
                    if isinstance(a, (int, float)) and isinstance(b, (int, float)):
                        if not compare_doubles(a, b):
                            differences.append(f"{key}[{i}]: {a} vs {b}")
                    elif isinstance(a, list) and isinstance(b, list):
                        if not compare_vectors(a, b):
                            differences.append(f"{key}[{i}]: vector mismatch")
    
    return {"equal": len(differences) == 0, "differences": differences}

def compare_curves(curve1: Dict, curve2: Dict) -> Dict:
    """Compare two curve representations."""
    differences = []
    
    for key in ['degree', 'periodic', 'rational', 'num_poles', 'num_knots']:
        c1 = curve1.get(key)
        c2 = curve2.get(key)
        if c1 != c2:
            differences.append(f"{key}: {c1} vs {c2}")
    
    # Compare poles
    poles1 = curve1.get('poles', [])
    poles2 = curve2.get('poles', [])
    if len(poles1) != len(poles2):
        differences.append(f"num_poles: {len(poles1)} vs {len(poles2)}")
    else:
        for i, (p1, p2) in enumerate(zip(poles1, poles2)):
            if not compare_vectors(p1, p2):
                differences.append(f"pole[{i}]: {p1} vs {p2}")
    
    return {"equal": len(differences) == 0, "differences": differences}

def compare_surfaces(surf1: Dict, surf2: Dict) -> Dict:
    """Compare two surface representations."""
    differences = []
    
    for key in ['u_degree', 'v_degree', 'u_periodic', 'v_periodic', 'u_rational', 'v_rational',
                'u_num_poles', 'v_num_poles', 'u_num_knots', 'v_num_knots']:
        c1 = surf1.get(key)
        c2 = surf2.get(key)
        if c1 != c2:
            differences.append(f"{key}: {c1} vs {c2}")
    
    # Compare pole grid
    poles1 = surf1.get('poles', [])
    poles2 = surf2.get('poles', [])
    if len(poles1) != len(poles2):
        differences.append(f"u_poles: {len(poles1)} vs {len(poles2)}")
    else:
        for i, (row1, row2) in enumerate(zip(poles1, poles2)):
            if len(row1) != len(row2):
                differences.append(f"v_poles[{i}]: {len(row1)} vs {len(row2)}")
            else:
                for j, (p1, p2) in enumerate(zip(row1, row2)):
                    if not compare_vectors(p1, p2):
                        differences.append(f"pole[{i}][{j}]: {p1} vs {p2}")
    
    return {"equal": len(differences) == 0, "differences": differences}

def run_bridge_test(bridge_function: str, inputs: List[Any]) -> Dict:
    """Run bridge function via Swift test (placeholder - would need Swift integration)."""
    # This would need to be implemented with actual Swift bridge call
    # For now, return placeholder
    return {"status": "not_implemented", "error": "Bridge execution not yet integrated"}

def run_ground_truth(bridge_function: str, inputs: List[Any]) -> Dict:
    """Run ground truth via ground-truth-runner.py."""
    spec = json.dumps({"bridge_function": bridge_function, "inputs": inputs, "test_name": "comparison"})
    result = subprocess.run(
        [sys.executable, "ground-truth-runner.py", "--spec", spec],
        capture_output=True, text=True, cwd=os.path.dirname(__file__)
    )
    if result.returncode != 0:
        return {"status": "error", "error": result.stderr}
    return json.loads(result.stdout)

def compare_outputs(bridge_output: Dict, kernel_output: Dict) -> Dict:
    """Compare bridge output with kernel output."""
    all_differences = []
    
    # Compare based on output type
    out_type = bridge_output.get("type", "")
    kernel_type = kernel_output.get("type", "")
    
    if out_type != kernel_type:
        return {"equal": False, "differences": [f"Output type mismatch: {out_type} vs {kernel_type}"]}
    
    if out_type == "shape":
        return compare_shapes(bridge_output.get("data", {}), kernel_output.get("data", {}))
    elif out_type == "curve":
        return compare_curves(bridge_output.get("data", {}), kernel_output.get("data", {}))
    elif out_type == "surface":
        return compare_surfaces(bridge_output.get("data", {}), kernel_output.get("data", {}))
    elif out_type in ("double", "float"):
        d1 = bridge_output.get("data", 0)
        d2 = kernel_output.get("data", 0)
        if not compare_doubles(d1, d2):
            return {"equal": False, "differences": [f"Value mismatch: {d1} vs {d2}"]}
        return {"equal": True, "differences": []}
    elif out_type == "int":
        d1 = bridge_output.get("data", 0)
        d2 = kernel_output.get("data", 0)
        if d1 != d2:
            return {"equal": False, "differences": [f"Integer mismatch: {d1} vs {d2}"]}
        return {"equal": True, "differences": []}
    elif out_type == "bool":
        d1 = bridge_output.get("data", False)
        d2 = kernel_output.get("data", False)
        if d1 != d2:
            return {"equal": False, "differences": [f"Bool mismatch: {d1} vs {d2}"]}
        return {"equal": True, "differences": []}
    elif out_type == "null":
        return {"equal": True, "differences": []}
    else:
        return {"equal": False, "differences": [f"Unknown output type: {out_type}"]}

def main():
    if len(sys.argv) < 2:
        print("Usage: compare-bridge-kernel.py --spec '...' | --spec-file file.json [--output file.json]")
        sys.exit(1)
    
    spec = None
    output_file = None
    
    i = 1
    while i < len(sys.argv):
        if sys.argv[i] == "--spec":
            spec = json.loads(sys.argv[i + 1])
            i += 2
        elif sys.argv[i] == "--spec-file":
            with open(sys.argv[i + 1]) as f:
                spec = json.load(f)
            i += 2
        elif sys.argv[i] == "--output":
            output_file = sys.argv[i + 1]
            i += 2
        else:
            i += 1
    
    if not spec:
        print("Error: --spec or --spec-file required")
        sys.exit(1)
    
    # Handle both single spec and array of specs
    specs = spec if isinstance(spec, list) else [spec]
    results = []
    
    for s in specs:
        bridge_fn = s.get("bridge_function")
        inputs = s.get("inputs", [])
        test_name = s.get("test_name", "unknown")
        
        print(f"Comparing {bridge_fn} ({test_name})...")
        
        # Run bridge (placeholder)
        bridge_result = run_bridge_test(bridge_fn, inputs)
        
        # Run kernel ground truth
        kernel_result = run_ground_truth(bridge_fn, inputs)
        
        if bridge_result.get("status") == "not_implemented":
            comparison = {"equal": False, "differences": ["Bridge execution not implemented"]}
        elif kernel_result.get("status") != "success":
            comparison = {"equal": False, "differences": [f"Kernel execution failed: {kernel_result.get('error', 'unknown')}"]}
        else:
            comparison = compare_outputs(bridge_result, kernel_result)
        
        result = {
            "test_name": test_name,
            "bridge_function": bridge_fn,
            "bridge_output": bridge_result,
            "kernel_output": kernel_result,
            "comparison": comparison,
            "status": "PASS" if comparison.get("equal") else "FAIL"
        }
        results.append(result)
        
        status = "PASS" if comparison.get("equal") else "FAIL"
        print(f"  {status}: {test_name}")
        if not comparison.get("equal"):
            for diff in comparison.get("differences", []):
                print(f"  - {diff}")
    
    if output_file:
        with open(output_file, 'w') as f:
            json.dump(results, f, indent=2)
    
    # Summary
    passed = sum(1 for r in results if r["status"] == "PASS")
    failed = len(results) - passed
    print(f"\nSummary: {passed} PASS, {failed} FAIL")
    
    if failed > 0:
        sys.exit(1)

if __name__ == "__main__":
    main()