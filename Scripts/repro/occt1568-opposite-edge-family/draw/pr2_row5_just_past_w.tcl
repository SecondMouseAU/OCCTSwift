puts "============"
puts "OCCT#1568 / PR2 row 5: r1 + r2 = w + 1e-9 .. 1e-5"
puts "============"
puts ""
##########################################################################
# Box 4 x 10 x 6, radii 2 + d/2 on both top edges (r1 + r2 = 4 + d). IR before
# the series: IsDone true with an invalid solid at d = 1e-9 and 1e-5. With it:
# valid (the intersection), or declined; an invalid solid is the defect.
##########################################################################

source [file join [file dirname [info script]] common.tcl]

pload MODELING
box b 4 10 6
set e1 [fam_edge_at b 0 5 6]
set e2 [fam_edge_at b 4 5 6]

foreach {d name} {1e-9 d1e-9 2e-8 d2e-8 1e-7 d1e-7 1e-5 d1e-5 2e-4 d2e-4} {
  set r [expr {2.0 + $d / 2.0}]
  set ok [expr {![catch {blend result_$name b $r $e1 $r $e2} msg]}]
  fam_verdict "pr2.row5.$name" $ok result_$name 222.831853072 valid_or_refused
}
