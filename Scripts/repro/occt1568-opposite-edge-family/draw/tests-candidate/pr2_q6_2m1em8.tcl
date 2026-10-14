# Radii a hair under the width: valid, same volume.
# Box: the 4 x 10 x 6 box; b_2 and b_6 are the edges of the top face at x = 0 and x = 4 (the 4 wide face).
# Candidate for tests/blend or tests/bugs/modalg_7 (OCCT#1568, OCCT#1177). Label pr2.q6.2-1e-8, expect valid.

# the common helpers of the runner, absent under testgrid
catch { source [file join [file dirname [info script]] .. common.tcl] }

pload MODELING
box b 4 10 6
explode b e

set ok [expr {![catch { blend result b 1.99999999 b_2 1.99999999 b_6 } msg]}]
if { !$ok } {
    puts "Error : the blend is refused: $msg"
} else {
    checkshape result
    checkprops result -v 222.831853072 -eps 1e-9 -deps 1e-5
    checknbshapes result -vertex 12 -edge 18 -wire 8 -face 8 -shell 1 -solid 1
}

# FAMILY line for draw/run-all.py, not part of an upstream test
if { [llength [info procs fam_verdict]] } {
    fam_verdict "pr2.q6.2-1e-8" $ok result 222.831853072 valid
}

puts "TEST COMPLETED"
