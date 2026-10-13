puts "============"
puts "OCCT#1568 / PR2 Q1: radii past the face between two opposite edges"
puts "============"
puts ""
##########################################################################
# Box 4 x 10 x 6, two top edges, r1 + r2 > 4. Chosen rule: the intersection of
# the rounded profiles. Analytic volumes are the section extruded.
##########################################################################

source [file join [file dirname [info script]] common.tcl]

pload MODELING
box b 4 10 6
set e1 [fam_edge_at b 0 5 6]
set e2 [fam_edge_at b 4 5 6]

foreach {r1 r2 vol tag} {
  3   3   202.502076313 3_3
  2.5 3   207.791557091 2.5_3
  1   3.5 211.590596594 1_3.5
  0.5 3.9 206.837421274 0.5_3.9
  2.2 2.2 219.238678500 2.2_2.2
} {
  set ok [expr {![catch {blend r_$tag b $r1 $e1 $r2 $e2} msg]}]
  fam_verdict "pr2.q1.$tag" $ok r_$tag $vol valid
}
