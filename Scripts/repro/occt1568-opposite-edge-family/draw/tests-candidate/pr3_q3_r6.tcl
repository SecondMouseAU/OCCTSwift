# A single fillet of r = 6 on an edge of a 4 wide face (wider than the face): the fillet runs out on the far wall.
# Box: the 4 x 10 x 6 box; b_2 and b_6 are the edges of the top face at x = 0 and x = 4 (the 4 wide face).
# Candidate for tests/blend or tests/bugs/modalg_7 (OCCT#1568, OCCT#1177). Label pr3.q3.r6, expect valid.

# the common helpers of the runner, absent under testgrid
catch { source [file join [file dirname [info script]] .. common.tcl] }

pload MODELING
box b 4 10 6
explode b e

set ok [expr {![catch { blend result b 6 b_2 } msg]}]
if { !$ok } {
    puts "Error : the blend is refused: $msg"
} else {
    checkshape result
    checkprops result -v 178.729982647 -eps 1e-9 -deps 1e-5
    checknbshapes result -vertex 8 -edge 12 -wire 6 -face 6 -shell 1 -solid 1
}

# FAMILY line for draw/run-all.py, not part of an upstream test
if { [llength [info procs fam_verdict]] } {
    fam_verdict "pr3.q3.r6" $ok result 178.729982647 valid
}

puts "TEST COMPLETED"
