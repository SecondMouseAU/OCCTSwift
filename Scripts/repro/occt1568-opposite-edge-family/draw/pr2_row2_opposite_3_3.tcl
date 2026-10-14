puts "============"
puts "OCCT#1568 / PR2 row 2: opposite fillets, r1 + r2 > w"
puts "============"
puts ""
##########################################################################
# Box 4 x 10 x 6, radius 3 on both top edges along Y (the top face is 4 wide,
# 3 + 3 > 4). IR before the series: IsDone true and an invalid solid, volume
# 315.7 for a box of 240. With it: the intersection of the two rounded
# profiles, volume 202.502076 (the section extruded).
##########################################################################

source [file join [file dirname [info script]] common.tcl]

pload MODELING
box b 4 10 6
set e1 [fam_edge_at b 0 5 6]
set e2 [fam_edge_at b 4 5 6]

set ok [expr {![catch {blend result b 3 $e1 3 $e2} msg]}]
fam_verdict "pr2.row2" $ok result 202.502076313 valid
