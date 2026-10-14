puts "============"
puts "OCCT#1568 / PR3 Q3: one fillet wider than its face"
puts "============"
puts ""
##########################################################################
# Box 4 x 10 x 6, one top edge, r = 4.5, 5 and 6 (> w = 4). The far edge of
# the face is the pivot. Analytic: the section extruded.
##########################################################################

source [file join [file dirname [info script]] common.tcl]

pload MODELING
box b 4 10 6
set e1 [fam_edge_at b 0 5 6]

foreach {r vol} {4.5 197.704072298 5 190.725723900 6 178.729982647} {
  set ok [expr {![catch {blend r_$r b $r $e1} msg]}]
  fam_verdict "pr3.q3.r$r" $ok r_$r $vol valid
}
