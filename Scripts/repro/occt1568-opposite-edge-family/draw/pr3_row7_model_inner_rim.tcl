puts "============"
puts "OCCT#1568 / PR3 row 7: the model, inner rim at 1.5000001"
puts "============"
puts ""
##########################################################################
# The inner rim (edges 12 to 19) at r = 1.5000001. IR before the series, and
# 8.0.1: IsDone true with an invalid solid (volume 74243 for a model of about
# 100000). With it: declined, never invalid.
##########################################################################

source [file join [file dirname [info script]] common.tcl]

pload MODELING
restore [file join [file dirname [info script]] model-1568.brep] model
explode model e

set rim {}
foreach i {12 13 14 15 16 17 18 19} { lappend rim 1.5000001 model_$i }
set ok [expr {![catch {blend result model {*}$rim} msg]}]
fam_verdict "pr3.row7" $ok result 0 refused
