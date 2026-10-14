# A fillet of r = 100 on an edge of a 10 cube.
# Box: the 10 cube; b_2 is the top edge at x = 0.
# Candidate for tests/blend or tests/bugs/modalg_7 (OCCT#1568, OCCT#1177). Label pr3.q4.r100, expect valid.

# the common helpers of the runner, absent under testgrid
catch { source [file join [file dirname [info script]] .. common.tcl] }

pload MODELING
box b 10 10 10
explode b e

set ok [expr {![catch { blend result b 100 b_2 } msg]}]
if { !$ok } {
    puts "Error : the blend is refused: $msg"
} else {
    checkshape result
    checkprops result -v 523.605676 -eps 1e-9 -deps 1e-5
    checknbshapes result -vertex 6 -edge 9 -wire 5 -face 5 -shell 1 -solid 1
}

# FAMILY line for draw/run-all.py, not part of an upstream test
if { [llength [info procs fam_verdict]] } {
    fam_verdict "pr3.q4.r100" $ok result 523.605676 valid
}

puts "TEST COMPLETED"
