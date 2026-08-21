#!/bin/bash
# Committed transcript for the guide's four deprecation figures, the libstdc++ claim, and the
# consumer-.m-reaches-the-C-bridge measurement (#967 f1, f5).
set -u
SDK=$(xcrun --show-sdk-path)
R="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
H="$R/Libraries/OCCT.xcframework/macos-arm64/Headers"
W=$(mktemp -d)
OUT="$R/Scripts/repro/967-consumer-compile/warnings-and-stdlib.txt"

{
echo "Figures the guide quotes that run.sh's rows do not cover. Regenerate with"
echo "  bash Scripts/repro/967-consumer-compile/measure-warnings.sh"
echo "Paths are normalised to <repo>; nothing else is altered."
echo
echo "########## -Wdeprecated-declarations: warnings follow what YOU write ##########"
cat > "$W/include_only.mm" <<'EOF'
#import <Foundation/Foundation.h>
#include <STEPControl_Reader.hxx>
int probe(void) { return 0; }
EOF
cat > "$W/uses_legacy.mm" <<'EOF'
#import <Foundation/Foundation.h>
#include <STEPControl_Reader.hxx>
#include <TopTools_ListOfShape.hxx>
int probe(void) {
  Standard_Boolean b = Standard_True;
  Standard_Real r = 1.0;
  TopTools_ListOfShape l;
  return (b && r > 0.0 && l.IsEmpty()) ? 0 : 1;
}
EOF
for f in include_only uses_legacy; do
  n=$(clang++ -std=c++17 -ObjC++ -fsyntax-only -Wdeprecated-declarations -isysroot "$SDK" -I "$H" "$W/$f.mm" 2>&1 | grep -c 'warning:.*deprecated')
  echo "$f.mm: $n"
done
n=$(clang++ -std=c++17 -ObjC++ -fsyntax-only -Wdeprecated-declarations -DOCCT_NO_DEPRECATED -isysroot "$SDK" -I "$H" "$W/uses_legacy.mm" 2>&1 | grep -c 'warning:.*deprecated')
echo "uses_legacy.mm -DOCCT_NO_DEPRECATED: $n"

echo
echo "########## -W#pragma-messages: some OCCT headers warn on the include alone ##########"
for h in STEPControl_Reader TopTools_ListOfShape TColStd_Array1OfReal; do
  cat > "$W/$h.mm" <<EOF
#import <Foundation/Foundation.h>
#include <$h.hxx>
int probe(void) { return 0; }
EOF
  out=$(clang++ -std=c++17 -ObjC++ -fsyntax-only -isysroot "$SDK" -I "$H" "$W/$h.mm" 2>&1)
  echo "include <$h.hxx> and nothing else: $(echo "$out" | grep -c 'warning:') warning(s)"
  echo "$out" | grep 'warning:' | head -1 | sed "s|$H/||"
  nn=$(clang++ -std=c++17 -ObjC++ -fsyntax-only -DOCCT_NO_DEPRECATED -isysroot "$SDK" -I "$H" "$W/$h.mm" 2>&1 | grep -c 'warning:')
  echo "  with -DOCCT_NO_DEPRECATED: $nn"
done

echo
echo "########## -stdlib=libstdc++ cannot reach the bridge: it fails <type_traits> outright ##########"
cat > "$W/stdlib.mm" <<'EOF'
#import <Foundation/Foundation.h>
#include <STEPControl_Reader.hxx>
int probe(void) { return 0; }
EOF
out=$(clang++ -std=c++17 -ObjC++ -fsyntax-only -stdlib=libstdc++ -isysroot "$SDK" -I "$H" "$W/stdlib.mm" 2>&1)
rc=$?
echo "$out" | sed "s|$H/||" | grep -E "error:|warning: include path" | head -3
echo "clang exit: $rc"
} > "$OUT"

/usr/bin/sed -i '' "s|$R|<repo>|g" "$OUT"
cat "$OUT"
