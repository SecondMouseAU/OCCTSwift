import re,sys
inp,outp=sys.argv[1:3]
s=open(inp).read().split('\n')
out=[]
start=None;end=None
for i,l in enumerate(s):
    if l.startswith('bool ChFi3d_Builder::StartSol(') and start is None: start=i
for i,l in enumerate(s):
    if l.startswith('bool ChFi3d_Builder::SearchFace('): end=i; break
# the second StartSol is the one that starts with "bool ChFi3d_Builder::StartSol(" on its own line
for i,l in enumerate(s):
    if start<=i<end:
        m=re.match(r'^(\s*)return (true|false);$',l)
        if m: l=f'{m.group(1)}{{ fprintf(stderr,"[SS] return {m.group(2)} line %d\\n", {i+1}); return {m.group(2)}; }}'
    out.append(l)
t='\n'.join(out)
t=t.replace('#include <ChFi3d_Builder.hxx>','#include <ChFi3d_Builder.hxx>\n#include <cstdio>\n#include <BRepAdaptor_Curve.hxx>\n#include <BRepAdaptor_Surface.hxx>\n#include <TopExp.hxx>',1)
t=t.replace('''  const ChFiDS_CommonPoint& aCommonPoint = SD->Vertex(isfirst, ons);
  HSBis.Nullify();
''','''  const ChFiDS_CommonPoint& aCommonPoint = SD->Vertex(isfirst, ons);
  HSBis.Nullify();
  {
    static const char* ST[] = {"Plane","Cylinder","Cone","Sphere","Torus","BezierS","BSplineS","Revolution","Extrusion","Offset","Other"};
    static const char* CT[] = {"Line","Circle","Ellipse","Hyperbola","Parabola","BezierC","BSplineC","Offset","Other"};
    BRepAdaptor_Surface aF(F); gp_Pnt P = aCommonPoint.Point();
    fprintf(stderr,"[SS] entry ons=%d isfirst=%d decroch=%d HCnull=%d F=%s%s onArc=%d isVertex=%d hasVec=%d P=(%.6f %.6f %.6f) tol=%.3e Vref=%d\\n",(int)ons,(int)isfirst,(int)decroch,(int)HC.IsNull(),ST[(int)aF.GetType()],F.Orientation()==TopAbs_REVERSED?"(rev)":"",(int)aCommonPoint.IsOnArc(),(int)aCommonPoint.IsVertex(),(int)aCommonPoint.HasVector(),P.X(),P.Y(),P.Z(),aCommonPoint.Tolerance(),(int)!Vref.IsNull());
    if (aCommonPoint.IsOnArc()) { const TopoDS_Edge& ae=aCommonPoint.Arc(); BRepAdaptor_Curve c(ae); gp_Pnt a=c.Value(c.FirstParameter()), b=c.Value(c.LastParameter());
      fprintf(stderr,"[SS]   arc %s (%.4f %.4f %.4f)->(%.4f %.4f %.4f) param=%.9g [%.6f %.6f]\\n",CT[(int)c.GetType()],a.X(),a.Y(),a.Z(),b.X(),b.Y(),b.Z(),aCommonPoint.ParameterOnArc(),c.FirstParameter(),c.LastParameter());
      if (aCommonPoint.IsVertex()) { gp_Pnt v=BRep_Tool::Pnt(aCommonPoint.Vertex()); fprintf(stderr,"[SS]   vertex (%.6f %.6f %.6f) tolV=%.3e\\n",v.X(),v.Y(),v.Z(),BRep_Tool::Tolerance(aCommonPoint.Vertex())); } }
  }
''',1)
t=t.replace('''        Spine->SetErrorStatus(ChFiDS_WalkingFailure);
        throw Standard_Failure("CallPerformSurf : Path failed!");''','''        Spine->SetErrorStatus(ChFiDS_WalkingFailure);
        fprintf(stderr,"[PS] PATH FAILED Ok1=%d Ok2=%d obs1=%d obs2=%d w1=%.9g w2=%.9g forward=%d First=%.9g Last=%.9g wf=%.9g wl=%.9g intf=%d intl=%d\\n",(int)Ok1,(int)Ok2,(int)obstacleon1,(int)obstacleon2,w1,w2,(int)forward,First,Last,wf,wl,intf,intl);
        throw Standard_Failure("CallPerformSurf : Path failed!");''',1)
t=t.replace('''      else
      {
        throw Standard_Failure("PerformSetOfSurfOnElSpine : Chaining is impossible.");''','''      else
      {
        fprintf(stderr,"[PS] CHAINING IMPOSSIBLE Ok1=%d Ok2=%d HC1null=%d HC2null=%d intf=%d intl=%d forward=%d\\n",(int)Ok1,(int)Ok2,(int)HC1.IsNull(),(int)HC2.IsNull(),intf,intl,(int)forward);
        throw Standard_Failure("PerformSetOfSurfOnElSpine : Chaining is impossible.");''',1)
open(outp,'w').write(t)
