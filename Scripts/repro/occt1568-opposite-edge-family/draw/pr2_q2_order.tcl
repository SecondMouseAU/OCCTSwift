puts "============"
puts "OCCT#1568 / PR2 Q2: at once or one after the other"
puts "============"
puts ""
##########################################################################
# Box 4 x 10 x 6, r = 3 on both top edges: in one blend (202.502076) and one
# after the other (213.812565: the second fillet sees the shape with the
# first one in it, so its pivot is the first fillet's tangent edge).
##########################################################################

source [file join [file dirname [info script]] common.tcl]

pload MODELING
box b 4 10 6
set e1 [fam_edge_at b 0 5 6]
set e2 [fam_edge_at b 4 5 6]

set ok [expr {![catch {blend once b 3 $e1 3 $e2} msg]}]
fam_verdict "pr2.q2.at-once" $ok once 202.502076313 valid

set ok1 [expr {![catch {blend s1 b 3 $e1} msg]}]
if {$ok1} {
  set e2b [fam_edge_at s1 4 5 6]
  set ok [expr {![catch {blend s2 s1 3 $e2b} msg]}]
} else {
  set ok 0
}
fam_verdict "pr2.q2.sequence" $ok s2 213.812565331 valid
