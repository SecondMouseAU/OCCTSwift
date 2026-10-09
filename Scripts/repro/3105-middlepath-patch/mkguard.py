import os,re
SP=os.environ["SP"]
s=open(SP+"/../occt-3105/src/ModelingAlgorithms/TKOffset/BRepOffsetAPI/BRepOffsetAPI_MiddlePath.cxx").read()
n=[0]
def lab(m):
    n[0]+=1
    return m.group(0).replace("return;", 'fprintf(stderr,"GUARD G%d i=%%d j=%%d\\n",i,j); return;'%n[0])
# the five new returns
pats=[r"return; // the path ended before the end section",]
out=s
tags=["pad-start-path(j-1)","pad-end-path","E1-previous-level","E2-previous-level","no-common-face"]
idx=0
def sub(m):
    global idx
    t=tags[idx]; idx+=1
    return m.group(0).replace("return;", 'fprintf(stderr,"GUARD %s i=%%d j=%%d\\n",i,j); return;'%t,1)
# order of appearance
out=re.sub(r"return; // the path ended before the end section|return;\n            \}\n            E[12] = TopoDS::Edge|return;\n      \}\n\n      TopoDS_Vertex PrevVertex", lambda m: sub(m), out) if False else out
# simpler: sequentially replace the new returns by position
marks=[("if (!IsEdgeAt(myPaths(j - 1), i - 1))\n        {\n          return;",0),
 ("if (!IsEdgeAt(myPaths((j <= NbPaths) ? j : 1), i - 1))\n        {\n          return;",1),
 ("if (!IsEdgeAt(myPaths(j - 1), i - 1))\n            {\n              return;",2),
 ("if (!IsEdgeAt(myPaths((j <= NbPaths) ? j : 1), i - 1))\n            {\n              return;",3),
 ("if (theFace.IsNull()) // no face holds both the path edge and the section edge\n      {\n        return;",4)]
for m,t in marks:
    assert out.count(m)==1,m
    out=out.replace(m,m.replace("return;",'fprintf(stderr,"GUARD %s i=%%d j=%%d\\n",i,j); return;'%tags[t]))
out=out.replace("#include <BRepOffsetAPI_MiddlePath.hxx>","#include <BRepOffsetAPI_MiddlePath.hxx>\n#include <cstdio>",1)
open(SP+"/MiddlePath_guard.cxx","w").write(out)
