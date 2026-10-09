# instrumented copy of the patched file: every `return;` in Build() prints GUARD <source line of the return>
# plus the traced paths (for the review images). usage: mkret.py <in.cxx> <out.cxx>
import re,sys
s=open(sys.argv[1]).read().split("\n")
out=[];inb=False
helper=r'''
#include <cstdio>
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
first=True
for n,l in enumerate(s,1):
    if l.startswith("static gp_Vec TangentOfEdge") : out.append(helper)
    if l.startswith("void BRepOffsetAPI_MiddlePath::Build"): inb=True
    if inb and l.strip()=="return;" :
        if first: first=False   # the original "no edge outside the start wire" return
        else: l=l.replace("return;",'{ fprintf(stderr,"GUARD line=%d\\n",__LINE__); return; }')
    if l.strip()=="// Building of set of sections": out.append("  TR_Dump(myPaths);")
    if l.strip()=="// final phase: building of middle path": out.append('  fprintf(stderr,"LEVELS i=%d solidEdges=%d\\n",i,NbSolidEdges);')
    out.append(l)
open(sys.argv[2],"w").write("\n".join(out))
