puts "============"
puts "OCCT#1568 / PR3 row 3: one fillet wider than its face"
puts "============"
puts ""
##########################################################################
# Box 4 x 10 x 6, r = 5 on one top edge of the 4 wide face. Declined by 8.0.1
# and by IR before the series; with it the far edge is the pivot, volume
# 190.725724.
##########################################################################

source [file join [file dirname [info script]] common.tcl]

pload MODELING
box b 4 10 6
set e1 [fam_edge_at b 0 5 6]

set ok [expr {![catch {blend result b 5 $e1} msg]}]
fam_verdict "pr3.row3" $ok result 190.725723900 valid
