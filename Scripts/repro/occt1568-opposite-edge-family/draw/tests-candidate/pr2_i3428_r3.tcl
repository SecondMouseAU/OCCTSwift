# Four fillets wider than half the face: refused.
# Box: the 4 x 4 x 4 cube; b_2, b_6, b_10, b_12 are the four edges of the top face (x = 0, x = 4, y = 0, y = 4).
# Candidate for tests/blend or tests/bugs/modalg_7 (OCCT#1568, OCCT#1177). Label pr2.i3428.r3, expect refused.

# the common helpers of the runner, absent under testgrid
catch { source [file join [file dirname [info script]] .. common.tcl] }

pload MODELING
box b 4 4 4
explode b e

set ok [expr {![catch { blend result b 3 b_10 3 b_12 3 b_2 3 b_6 } msg]}]
if { $ok } {
    puts "Error : the blend was built, it must be refused"
}

# FAMILY line for draw/run-all.py, not part of an upstream test
if { [llength [info procs fam_verdict]] } {
    fam_verdict "pr2.i3428.r3" $ok result 0 refused
}

puts "TEST COMPLETED"
