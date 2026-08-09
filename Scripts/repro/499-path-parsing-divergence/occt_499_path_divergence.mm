// Ground-truth probe for OCCTSwift #499: measure how TDocStd_PathParser and OSD_Path
// actually disagree, across a full input matrix. No assumptions: print everything.
#include <TDocStd_PathParser.hxx>
#include <TCollection_ExtendedString.hxx>
#include <TCollection_AsciiString.hxx>
#include <OSD_Path.hxx>
#include <Standard_Failure.hxx>
#include <cstdio>
#include <string>
#include <vector>

static std::string q(const TCollection_AsciiString& s) {
    return std::string("\"") + s.ToCString() + "\"";
}

// Mirror the bridge: ExtendedString in, AsciiString out.
static void pathParser(const char* p, std::string& trek, std::string& name, std::string& ext, std::string& err) {
    try {
        TCollection_ExtendedString e(p);
        TDocStd_PathParser parser(e);
        trek = q(TCollection_AsciiString(parser.Trek()));
        name = q(TCollection_AsciiString(parser.Name()));
        ext  = q(TCollection_AsciiString(parser.Extension()));
        err  = "";
    } catch (Standard_Failure const& f) {
        trek = name = ext = "-"; err = std::string("THROW:") + f.GetMessageString();
    } catch (...) { trek = name = ext = "-"; err = "THROW:unknown"; }
}

static void osdPath(const char* p, std::string& trek, std::string& name, std::string& ext,
                    std::string& sys, std::string& err) {
    try {
        TCollection_AsciiString a(p);
        OSD_Path o(a);
        trek = q(o.Trek());
        name = q(o.Name());
        ext  = q(o.Extension());
        TCollection_AsciiString s; o.SystemName(s);
        sys  = q(s);
        err  = "";
    } catch (Standard_Failure const& f) {
        trek = name = ext = sys = "-"; err = std::string("THROW:") + f.GetMessageString();
    } catch (...) { trek = name = ext = sys = "-"; err = "THROW:unknown"; }
}

static void statics(const char* p) {
    std::string valid = "?", unixp = "?", rel = "?", abs = "?", folder = "?", file = "?";
    try { valid = OSD_Path::IsValid(TCollection_AsciiString(p)) ? "Y" : "n"; } catch (...) { valid = "T"; }
    try { unixp = OSD_Path::IsUnixPath(p) ? "Y" : "n"; } catch (...) { unixp = "T"; }
    try { rel   = OSD_Path::IsRelativePath(p) ? "Y" : "n"; } catch (...) { rel = "T"; }
    try { abs   = OSD_Path::IsAbsolutePath(p) ? "Y" : "n"; } catch (...) { abs = "T"; }
    try {
        TCollection_AsciiString f, g;
        OSD_Path::FolderAndFileFromPath(TCollection_AsciiString(p), f, g);
        folder = q(f); file = q(g);
    } catch (...) { folder = file = "THROW"; }
    printf("    statics : IsValid=%s IsUnix=%s IsRel=%s IsAbs=%s  FolderAndFile=%s / %s\n",
           valid.c_str(), unixp.c_str(), rel.c_str(), abs.c_str(), folder.c_str(), file.c_str());
}

int main() {
    std::vector<std::pair<const char*, const char*>> cases = {
        {"absolute + ext",          "/home/user/model.step"},
        {"bare filename + ext",     "model.step"},
        {"absolute, NO ext",        "/home/user/model"},
        {"bare filename, NO ext",   "model"},
        {"explicit relative",       "./sub/f.txt"},
        {"parent relative",         "../up/f.txt"},
        {"multi-dot",               "/home/user/archive.tar.gz"},
        {"dotfile bare",            ".gitignore"},
        {"dotfile in dir",          "/home/user/.config"},
        {"empty string",            ""},
        {"trailing slash (dir)",    "/home/user/"},
        {"dot in DIR, none on file","/home/a.b/model"},
        {"spaces",                  "/home/my docs/a file.step"},
        {"windows-style",           "C:\\Users\\me\\model.step"},
        {"non-ASCII (accented)",    "/home/\xc3\xbcser/m" "\xc3\xb8" "del.step"},
        {"non-ASCII (CJK)",         "/home/user/" "\xe6\xa8\xa1" "\xe5\x9e\x8b" ".step"},
        {"root only",               "/"},
        {"just a dot",              "."},
        {"tilde",                   "~/model.step"},
    };

    printf("OCCT path-parsing divergence probe (#499)\n");
    printf("=========================================\n\n");
    for (auto& c : cases) {
        printf("[%s]  input=\"%s\"\n", c.first, c.second);
        std::string pt, pn, pe, perr;
        pathParser(c.second, pt, pn, pe, perr);
        printf("    PathParser: trek=%-16s name=%-14s ext=%-10s %s\n",
               pt.c_str(), pn.c_str(), pe.c_str(), perr.c_str());
        std::string ot, on, oe, os, oerr;
        osdPath(c.second, ot, on, oe, os, oerr);
        printf("    OSDPath   : trek=%-16s name=%-14s ext=%-10s sys=%s %s\n",
               ot.c_str(), on.c_str(), oe.c_str(), os.c_str(), oerr.c_str());
        statics(c.second);
        printf("\n");
    }
    return 0;
}
