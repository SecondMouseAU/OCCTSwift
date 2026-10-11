// Hand-written shadows for the two entry points generate-shadow.py cannot map (an out-pointer-to-
// pointer result and an array-of-handles parameter). Appended to the generated InjectionShadow.swift
// for a sweep and deleted with it. The switch names are listed in manual-switches.txt.

func OCCTGeomToolsCurveSetWrite(
    _ curveRefs: UnsafePointer<OCCTCurve3DRef>, _ count: Int32
) -> UnsafePointer<CChar>? {
    if GD.on("OCCTGeomToolsCurveSetWrite_RET_NIL") { return nil }
    return OCCTBridge.OCCTGeomToolsCurveSetWrite(curveRefs, count)
}

func OCCTGeomToolsCurveSetRead(
    _ data: UnsafePointer<CChar>, _ outCount: UnsafeMutablePointer<Int32>
) -> UnsafeMutablePointer<OCCTCurve3DRef?>? {
    let arr = OCCTBridge.OCCTGeomToolsCurveSetRead(data, outCount)
    if GD.on("OCCTGeomToolsCurveSetRead_COUNT_MINUS1") { outCount.pointee -= 1 }
    if GD.on("OCCTGeomToolsCurveSetRead_REVERSED"), let arr = arr {
        let n = Int(outCount.pointee)
        for i in 0..<(n / 2) {
            let tmp = arr[i]
            arr[i] = arr[n - 1 - i]
            arr[n - 1 - i] = tmp
        }
    }
    return arr
}
