puts "============"
puts "OCCT#1568 / PR2 Q6: exact ties"
puts "============"
puts ""
##########################################################################
# Box 4 x 10 x 6. r1 + r2 = w exactly (2 and 2), r = w on one edge (4 on 4),
# and a hair under the tie. All tangent arcs, no special case.
##########################################################################

source [file join [file dirname [info script]] common.tcl]

pload MODELING
box b 4 10 6
set e1 [fam_edge_at b 0 5 6]
set e2 [fam_edge_at b 4 5 6]

set ok [expr {![catch {blend t22 b 2 $e1 2 $e2} msg]}]
fam_verdict "pr2.q6.2_2" $ok t22 222.831853072 valid

set ok [expr {![catch {blend t_lo b 1.99999999 $e1 1.99999999 $e2} msg]}]
fam_verdict "pr2.q6.2-1e-8" $ok t_lo 222.831853072 valid

set ok [expr {![catch {blend t4 b 4 $e1} msg]}]
fam_verdict "pr2.q6.single-4" $ok t4 205.663706144 valid
