puts "============"
puts "OCCT#1568 / PR1: StartSol leaves an empty adaptor, the model of the report"
puts "============"
puts ""
##########################################################################
# Fillet r = 1.5 on the inner rim (edges 12 to 19 of explode) and on all
# twelve edges of the model. Before the fix BRepFilletAPI_MakeFillet::Build
# dereferences an empty adaptor (SIGSEGV). NOTE: DRAWEXE installs OSD's signal
# handler (OCC_CONVERT_SIGNALS), which turns the SIGSEGV into an exception that
# Build catches, so in DRAW blend returns an error with and without the fix;
# only a process that does not call OSD::SetSignal (an application, the
# GTest, brepfillet.cxx) dies. This script is the text repro and a regression
# check that nothing is built; the crash itself is shown by the C++ probe.
##########################################################################

source [file join [file dirname [info script]] common.tcl]

pload MODELING
restore [file join [file dirname [info script]] model-1568.brep] model
explode model e

set rim {}
foreach i {12 13 14 15 16 17 18 19} { lappend rim 1.5 model_$i }
set ok [expr {![catch {blend rim_result model {*}$rim} msg]}]
fam_verdict "pr1.rim-1.5" $ok rim_result 0 refused

set all {}
foreach i {3 6 9 11 12 13 14 15 16 17 18 19} { lappend all 1.5 model_$i }
set ok [expr {![catch {blend all_result model {*}$all} msg]}]
fam_verdict "pr1.all12-1.5" $ok all_result 0 refused
