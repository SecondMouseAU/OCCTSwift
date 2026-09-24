// Epic #766, Issue1078UnicodeConvertLengthTests.swift: kernel parity for all six tests.
// Same inputs as the Swift tests, straight to OCCT: Resource_Unicode::SetFormat(ANSI), then
// Resource_Unicode::ConvertUnicodeToFormat on TCollection_ExtendedString(utf8, true), the
// conversion OCCTUnicodeConvertFromUnicode (OCCTBridge_IO_OSDUtilities.mm) wraps.
#include <Resource_Unicode.hxx>
#include <TCollection_ExtendedString.hxx>
#include <cstdio>
#include <cstring>
#include <string>
#include <vector>

static int convertedLength(const std::string& utf8, std::string* out)
{
  TCollection_ExtendedString eStr(utf8.c_str(), true);
  std::vector<char>          buf(utf8.size() * 4 + 1);
  Standard_PCharacter        p  = buf.data();
  bool                       ok = Resource_Unicode::ConvertUnicodeToFormat(eStr, p, (int)buf.size());
  if (!ok)
    return -1;
  if (out)
    *out = buf.data();
  return (int)strlen(buf.data());
}

int main()
{
  Resource_Unicode::SetFormat(Resource_FormatType_ANSI);
  std::string longStr;
  for (int i = 0; i < 5000; i++)
    longStr += "\xE6\xBC\xA2"; // U+6F22, the Swift test's "漢"
  std::string conv;
  int         lenLong = convertedLength(longStr, &conv);
  printf("ANSI long (5000 x U+6F22): utf8Bytes=%zu extLength=%d convertedLength=%d\n",
         longStr.size(),
         TCollection_ExtendedString(longStr.c_str(), true).Length(),
         lenLong);
  printf("  first 8 converted bytes:");
  for (int i = 0; i < 8 && i < (int)conv.size(); i++)
    printf(" %02X", (unsigned char)conv[i]);
  printf("\n");
  std::string hello;
  printf("ANSI \"hello\": convertedLength=%d\n", convertedLength("hello", &hello));
  printf("  converted=[%s]\n", hello.c_str());
  return 0;
}
