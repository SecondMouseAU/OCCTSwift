puts "============"
puts "OCCT#1568 / PR2 row 6: a second fillet that meets a finished one"
puts "============"
puts ""
##########################################################################
# Box 4 x 10 x 6, r = 5 on the top edge at y = 0, then r = 5 on the top edge
# at y = 10 of that result (the 10 wide face is consumed exactly). IR before
# the series: the second blend is done and an invalid solid (volume 100.36
# for 240). With it: valid, volume 197.079633 (a semicircular top, 4 long).
##########################################################################

source [file join [file dirname [info script]] common.tcl]

pload MODELING
box b 4 10 6
set e1 [fam_edge_at b 2 0 6]
set ok1 [expr {![catch {blend first b 5 $e1} msg]}]
fam_verdict "pr2.row6.first" $ok1 first 218.539816340 valid
if {$ok1} {
  set e2 [fam_edge_at first 2 10 6]
  set ok [expr {![catch {blend result first 5 $e2} msg]}]
  fam_verdict "pr2.row6.second" $ok result 197.079633 valid
}
