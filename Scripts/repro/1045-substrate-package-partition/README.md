# #1045: where the fifteen unowned "substrate" packages go

`partition_census.py` records the decision, not an audit: fifteen packages under #811's features
lane, 331 headers (the issue's own title says "337 headers"; the issue's own table sums to 331,
re-measured here directly against the pinned headers, so the title's figure was the wrong one to
trust), are named in no sub-issue of #807. Rather than open a thirteenth lane pass, all fifteen are
assigned to #820 (Phase 6), whose own charter already names exactly this class of finding, "a class
that sits at a boundary belongs to nobody's table." `GeomFill_` and `BRepFill_` are flagged HIGH
priority within that assignment, per #1045's own "Done when" #3.

```
python3 partition_census.py             # the table and the destination decision
python3 partition_census.py --verify    # header counts still match the pinned kernel; no other
                                         # #807 sub-issue has since claimed one of the fifteen
python3 partition_census.py --self-test # proves --verify catches a header-count drift
```

See #1045 (closed) and #820 (the lane that now owns these fifteen packages).
