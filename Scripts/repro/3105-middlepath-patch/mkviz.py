# Builds an instrumented copy of the PATCHED BRepOffsetAPI_MiddlePath.cxx for the review images only:
# it prints the paths Build() traced from each start vertex (exact coordinates) and which guard fired.
import os
SP=os.environ["SP"]
s=open(SP+"/MiddlePath_guard.cxx").read()
helper=r'''
#include <BRep_Tool.hxx>
static void TR_Dump(const NCollection_Sequence<NCollection_Sequence<TopoDS_Shape>>& P)
{
  for (int a = 1; a <= P.Length(); a++) {
    fprintf(stderr, "PATH %d", a);
    for (int b = 1; b <= P(a).Length(); b++) {
      const TopoDS_Shape& s = P(a)(b);
      if (s.ShapeType()==TopAbs_EDGE) { TopoDS_Vertex v1,v2; TopExp::Vertices(TopoDS::Edge(s),v1,v2,true); gp_Pnt p1=BRep_Tool::Pnt(v1),p2=BRep_Tool::Pnt(v2); fprintf(stderr," E %.5f %.5f %.5f %.5f %.5f %.5f",p1.X(),p1.Y(),p1.Z(),p2.X(),p2.Y(),p2.Z()); }
      else { gp_Pnt p=BRep_Tool::Pnt(TopoDS::Vertex(s)); fprintf(stderr," V %.5f %.5f %.5f",p.X(),p.Y(),p.Z()); }
    }
    fprintf(stderr,"\n");
  }
}
'''
out=[]
for l in s.split("\n"):
    if l.startswith("static bool IsLinear"): out.append(helper)
    if l.strip()=="// Building of set of sections":
        out.append("  TR_Dump(myPaths);")
    out.append(l)
open(SP+"/MiddlePath_viz.cxx","w").write("\n".join(out))
