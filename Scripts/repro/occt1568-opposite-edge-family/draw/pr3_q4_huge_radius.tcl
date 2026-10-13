puts "============"
puts "OCCT#1568 / PR3 Q4: a huge radius"
puts "============"
puts ""
##########################################################################
# 10 cube, r = 100 on one edge: a near flat cut through both far edges
# (523.605676 by the section).
##########################################################################

source [file join [file dirname [info script]] common.tcl]

pload MODELING
box b 10 10 10
set e1 [fam_edge_at b 0 5 10]

set ok [expr {![catch {blend result b 100 $e1} msg]}]
fam_verdict "pr3.q4.r100" $ok result 523.605676 valid
