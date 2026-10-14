# Radii that add up to w + 1e-7: never an invalid solid; either refused or valid with the touching volume.
# Box: the 4 x 10 x 6 box; b_2 and b_6 are the edges of the top face at x = 0 and x = 4 (the 4 wide face).
# Candidate for tests/blend or tests/bugs/modalg_7 (OCCT#1568, OCCT#1177). Label pr2.row5.d1e-7, expect valid_or_refused.

# the common helpers of the runner, absent under testgrid
catch { source [file join [file dirname [info script]] .. common.tcl] }

pload MODELING
box b 4 10 6
explode b e

set ok [expr {![catch { blend result b 2.00000005 b_2 2.00000005 b_6 } msg]}]
# a refusal is acceptable; a result must be a valid solid
if { $ok } {
    checkshape result
    checkprops result -v 222.831853072 -eps 1e-9 -deps 1e-4
}

# FAMILY line for draw/run-all.py, not part of an upstream test
if { [llength [info procs fam_verdict]] } {
    fam_verdict "pr2.row5.d1e-7" $ok result 222.831853072 valid_or_refused
}

puts "TEST COMPLETED"
