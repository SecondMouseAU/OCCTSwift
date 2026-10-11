import sys,subprocess
def sub(p,old,new):
    s=open(p).read()
    assert s.count(old)==1,(p,old,s.count(old))
    open(p,'w').write(s.replace(old,new))
open('Sources/OCCTSwift/SweepSwitch.swift','w').write('''import Foundation
func sweepOn(_ n: String) -> Bool { ProcessInfo.processInfo.environment["SW"] == n }
''')
A='Sources/OCCTSwift/Shape+Analysis.swift'
sub(A,'''        CanonicalRecognitionResult(
            type: CanonicalGeometryType(rawValue: Int(r.type.rawValue)) ?? .none,
            gap: r.gap,
            origin: (r.originX, r.originY, r.originZ),
            direction: (r.dirX, r.dirY, r.dirZ),
            param1: r.param1,
            param2: r.param2
        )''','''        CanonicalRecognitionResult(
            type: sweepOn("CAN_TYPE_NONE") ? .none : (CanonicalGeometryType(rawValue: Int(r.type.rawValue)) ?? .none),
            gap: r.gap,
            origin: sweepOn("CAN_ORIGIN0") ? (0, 0, 0) : (r.originX, r.originY, r.originZ),
            direction: sweepOn("CAN_DIRX") ? (1, 0, 0) : (r.dirX, r.dirY, r.dirZ),
            param1: (sweepOn("CAN_NONE_P1") && r.type.rawValue == 0) ? 1 : r.param1,
            param2: sweepOn("CAN_P2_0") ? 0 : r.param2
        )''')
sub(A,'''        guard OCCTShapeGetVolume(handle, &v), v >= 0 else { return nil }
        return v''','''        guard OCCTShapeGetVolume(handle, &v), v >= 0 else { return nil }
        if sweepOn("VOLUME_NIL") { return nil }
        return v''')
H='Sources/OCCTSwift/HatchBuilder.swift'
sub(H,'public var nbLines: Int { Int(OCCTHatcherNbLines(ref)) }','public var nbLines: Int { Int(OCCTHatcherNbLines(ref)) + (sweepOn("HATCH_NB1") ? 1 : 0) }')
sub(H,'        OCCTHatcherAddXLine(ref, x)','        if sweepOn("HATCH_ADD_NOOP") { return }\n        OCCTHatcherAddXLine(ref, x)')
X='Sources/OCCTSwift/AxisPlacement2D.swift'
sub(X,'''        OCCTAxisPlacement2DGetDirection(handle, &x, &y)
        return SIMD2(x, y)''','''        OCCTAxisPlacement2DGetDirection(handle, &x, &y)
        if sweepOn("AX_RAWDIR") { return SIMD2(x, y) * 5 }
        return SIMD2(x, y)''')
sub(X,'''        OCCTAxisPlacement2DGetOrigin(handle, &x, &y)
        return SIMD2(x, y)''','''        OCCTAxisPlacement2DGetOrigin(handle, &x, &y)
        if sweepOn("AX_ORIGIN_X") { return SIMD2(x + 1, y) }
        return SIMD2(x, y)''')
G='Sources/OCCTSwift/BRepGraph.swift'
sub(G,'''        guard ok, outKind >= 0, let kind = NodeKind(rawValue: outKind) else { return nil }
        return NodeRef(kind: kind, index: Int(outIndex))''','''        guard ok, outKind >= 0, let kind = NodeKind(rawValue: outKind) else { return nil }
        if sweepOn("ADD_WRONG_ROOT") { return NodeRef(kind: kind, index: Int(outIndex) + 1) }
        return NodeRef(kind: kind, index: Int(outIndex))''')
sub(G,'''                        namePtr,
                        &outKind, &outIndex)''','''                        sweepOn("ADD_NAME") ? "x" : namePtr,
                        &outKind, &outIndex)''')
M='Sources/OCCTBridge/src/OCCTBridge_BRepGraph.mm'
sub(M,'''    *outSequenceNumber = (int32_t)rec.SequenceNumber;
    // Allow length-only query''','''    if (!(getenv("SW") && !strcmp(getenv("SW"), "H_SEQ_NOWRITE")))
      *outSequenceNumber = (int32_t)rec.SequenceNumber;
    // Allow length-only query''')
sub(M,'''    int copyLen = std::min(srcLen, outOpNameMax - 1);
    memcpy(outOpName, src, copyLen);
    outOpName[copyLen] = '\\0'; // #1434: was the ASCII digit '0' (0x30), not NUL (0x00)
    return srcLen;''','''    int copyLen = std::min(srcLen, outOpNameMax - 1);
    if (getenv("SW") && !strcmp(getenv("SW"), "H_COPY_SHORT") && copyLen > 1)
      copyLen -= 1;
    memcpy(outOpName, src, copyLen);
    if (getenv("SW") && !strcmp(getenv("SW"), "H_COPY_FIRSTCHAR_X") && copyLen > 0)
      outOpName[0] = 'X';
    outOpName[copyLen] = '\\0'; // #1434: was the ASCII digit '0' (0x30), not NUL (0x00)
    if (getenv("SW") && !strcmp(getenv("SW"), "H_LEN_TRUNC"))
      return std::min(srcLen, 127);
    return srcLen;''')
