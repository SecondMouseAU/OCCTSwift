puts "============"
puts "OCCT#1568 / PR3 Q5: both radii past their wall"
puts "============"
puts ""
##########################################################################
# Box 10 x 4 x 6, r = 7.5 on both edges of the 10 wide top face (7.5 > the 6
# high wall, 7.5 + 7.5 > 10): each pivot is the bottom edge of its wall and
# the two pivot arcs intersect. Analytic 153.644087.
##########################################################################

source [file join [file dirname [info script]] common.tcl]

pload MODELING
box b 10 4 6
set e1 [fam_edge_at b 0 2 6]
set e2 [fam_edge_at b 10 2 6]

set ok [expr {![catch {blend result b 7.5 $e1 7.5 $e2} msg]}]
fam_verdict "pr3.q5.7_5" $ok result 153.644087465 valid
