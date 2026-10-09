import sys,os
SP=os.environ["SP"]
s=open(SP+"/../occt-3105/src/ModelingAlgorithms/TKOffset/BRepOffsetAPI/BRepOffsetAPI_MiddlePath.cxx").read()
def rep(t,a,b):
    assert t.count(a)==1,a
    return t.replace(a,b)
V={}
V["A1_pad_refuses_vertex"]=rep(s,"  TopoDS_Shape aVer = thePath.Last();\n  if (aVer.ShapeType() == TopAbs_EDGE)\n  {\n    aVer = TopExp::LastVertex(TopoDS::Edge(aVer), true);\n  }","  TopoDS_Shape aVer = thePath.Last();\n  if (aVer.ShapeType() != TopAbs_EDGE)\n  {\n    return false;\n  }\n  aVer = TopExp::LastVertex(TopoDS::Edge(aVer), true);")
V["A2_no_level_bound"]=rep(s,"    if (i > NbSolidEdges)\n    {\n      return;\n    }\n","")
V["A3_vertex_end_refuses"]=rep(s,"  if (theEdge.IsNull())\n  {\n    for (TopExp_Explorer anExp","  if (theEdge.IsNull())\n  {\n    return false;\n    for (TopExp_Explorer anExp")
V["A4_null_face_not_relaxed"]=rep(rep(s,"(theFace.IsNull() || EdgesOfTheFace.Contains(anEdge))","EdgesOfTheFace.Contains(anEdge)"),"        if (theFace.IsNull())\n        {\n          return;\n        }\n","")
V["A5_makeedge_unchecked"]=rep(s,"  if (!aMaker.IsDone())\n  {\n    return TopoDS_Edge();\n  }\n  TopoDS_Edge anEdge = aMaker.Edge();","  TopoDS_Edge anEdge = aMaker.Edge();")
V["A6_no_empty_tangent_flag"]=rep(s,"        if (PntSeq.IsEmpty()) // every path is a point here: no tangent to impose\n        {\n          theFlags->SetValue(k - i + 1, false);\n          continue;\n        }\n","")
V["A7_insert_refuses_vertex"]=rep(s,"              TopoDS_Shape VertexAsEdge = myPaths(k)(i);\n              if (VertexAsEdge.ShapeType() == TopAbs_EDGE)\n              {\n                VertexAsEdge = TopExp::FirstVertex(TopoDS::Edge(VertexAsEdge), true);\n              }","              TopoDS_Shape VertexAsEdge = myPaths(k)(i);\n              if (VertexAsEdge.ShapeType() != TopAbs_EDGE)\n              {\n                return;\n              }\n              VertexAsEdge = TopExp::FirstVertex(TopoDS::Edge(VertexAsEdge), true);")
V["A8_no_pcurve_null_check"]=rep(s,"          if (PCurve1.IsNull() || PCurve2.IsNull())\n          {\n            return;\n          }\n","")
for k,v in V.items(): open(f"{SP}/abl/{k}.cxx","w").write(v)
print(list(V))
