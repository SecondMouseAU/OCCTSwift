# OCCTSwift#3428: four fillets of r = w / 2 leave a face that is a point. Without the BRepTools_WireExplorer fix and the validity check the result is returned and checkshape on it never returns.
# Box: the 4 x 4 x 4 cube; b_2, b_6, b_10, b_12 are the four edges of the top face (x = 0, x = 4, y = 0, y = 4).
# Candidate for tests/blend or tests/bugs/modalg_7 (OCCT#1568, OCCT#1177). Label pr2.i3428.r2, expect valid_or_refused.

# the common helpers of the runner, absent under testgrid
catch { source [file join [file dirname [info script]] .. common.tcl] }

pload MODELING
box b 4 4 4
explode b e

set ok [expr {![catch { blend result b 2 b_10 2 b_12 2 b_2 2 b_6 } msg]}]
# a refusal is acceptable; a result must be a valid solid
if { $ok } {
    checkshape result
    checkprops result -v 53.3333333333 -eps 1e-9 -deps 1e-4
}

# FAMILY line for draw/run-all.py, not part of an upstream test
if { [llength [info procs fam_verdict]] } {
    fam_verdict "pr2.i3428.r2" $ok result 53.3333333333 valid_or_refused
}

puts "TEST COMPLETED"
