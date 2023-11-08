--
-- Copyright (C) 2009-2016 John MacFarlane, Hans Hagen
--
-- Permission is hereby granted, free of charge, to any person obtaining
-- a copy of this software and associated documentation files (the
-- "Software"), to deal in the Software without restriction, including
-- without limitation the rights to use, copy, modify, merge, publish,
-- distribute, sublicense, and/or sell copies of the Software, and to
-- permit persons to whom the Software is furnished to do so, subject to
-- the following conditions:
--
-- The above copyright notice and this permission notice shall be included
-- in all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
-- EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
-- MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
-- IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
-- CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
-- TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
-- SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
--
-- Copyright (C) 2016-2023 Vít Novotný
--
-- This work may be distributed and/or modified under the
-- conditions of the LaTeX Project Public License, either version 1.3
-- of this license or (at your option) any later version.
-- The latest version of this license is in
--
--     http://www.latex-project.org/lppl.txt
--
-- and version 1.3 or later is part of all distributions of LaTeX
-- version 2005/12/01 or later.
--
-- This work has the LPPL maintenance status `maintained'.
-- The Current Maintainer of this work is Vít Novotný.
--
-- Send bug reports, requests for additions and questions
-- either to the GitHub issue tracker at
--
--     https://github.com/witiko/markdown/issues
--
-- or to the e-mail address <witiko@mail.muni.cz>.
--
-- MODIFICATION ADVICE:
--
-- If you want to customize this file, it is best to make a copy of
-- the source file(s) from which it was produced. Use a different
-- name for your copy(ies) and modify the copy(ies); this will ensure
-- that your modifications do not get overwritten when you install a
-- new release of the standard system. You should also ensure that
-- your modified source file does not generate any modified file with
-- the same name as a standard file.
--
-- You will also need to produce your own, suitably named, .ins file to
-- control the generation of files from your source file; this file
-- should contain your own preambles for the files it generates, not
-- those in the standard .ins files.
--
local metadata = {
    version   = "2.23.0-0-g0b22f91",
    comment   = "A module for the conversion from markdown to plain TeX",
    author    = "John MacFarlane, Hans Hagen, Vít Novotný",
    copyright = {"2009-2016 John MacFarlane, Hans Hagen",
                 "2016-2023 Vít Novotný"},
    license   = "LPPL 1.3c"
}

if not modules then modules = { } end
modules['markdown'] = metadata
local lpeg = require("lpeg")
local unicode
(function()
  local ran_ok
  ran_ok, unicode = pcall(require, "unicode")
  if not ran_ok then
    unicode = {utf8 = {char=utf8.char}}
  end
end)()
local md5 = require("md5");
(function()
  local should_initialize = package.loaded.kpse == nil
                       or tex.initialize ~= nil
  local ran_ok
  ran_ok, kpse = pcall(require, "kpse")
  if ran_ok and should_initialize then
    kpse.set_program_name("luatex")
  end
  if not ran_ok then
    kpse = {lookup = function(f, _) return f end}
  end
end)()
local uni_case
(function()
  local ran_ok
  ran_ok, uni_case = pcall(require, "lua-uni-case")
  if not ran_ok then
    if unicode.utf8.lower then
      uni_case = {casefold = unicode.utf8.lower}
    else
      uni_case = {casefold = string.lower}
    end
  end
end)()
local M = {metadata = metadata}
local walkable_syntax = {
  Block = {
    "Blockquote",
    "Verbatim",
    "ThematicBreak",
    "BulletList",
    "OrderedList",
    "Heading",
    "DisplayHtml",
    "Paragraph",
    "Plain",
  },
  Inline = {
    "Str",
    "Space",
    "Endline",
    "UlOrStarLine",
    "Strong",
    "Emph",
    "Link",
    "Image",
    "Code",
    "AutoLinkUrl",
    "AutoLinkEmail",
    "AutoLinkRelativeReference",
    "InlineHtml",
    "HtmlEntity",
    "EscapedChar",
    "Smart",
    "Symbol",
  },
}
local defaultOptions = {}
defaultOptions.cacheDir = "."
defaultOptions.contentBlocksLanguageMap = "markdown-languages.json"
defaultOptions.debugExtensionsFileName = "debug-extensions.json"
defaultOptions.frozenCacheFileName = "frozenCache.tex"
defaultOptions.blankBeforeBlockquote = false
defaultOptions.blankBeforeCodeFence = false
defaultOptions.blankBeforeDivFence = false
defaultOptions.blankBeforeHeading = false
defaultOptions.bracketedSpans = false
defaultOptions.breakableBlockquotes = false
defaultOptions.citationNbsps = true
defaultOptions.citations = false
defaultOptions.codeSpans = true
defaultOptions.contentBlocks = false
defaultOptions.debugExtensions = false
defaultOptions.definitionLists = false
defaultOptions.eagerCache = true
defaultOptions.expectJekyllData = false
metadata.user_extension_api_version = 2
metadata.grammar_version = 2
defaultOptions.extensions = {}
defaultOptions.fancyLists = false
defaultOptions.fencedCode = false
defaultOptions.fencedCodeAttributes = false
defaultOptions.fencedDivs = false
defaultOptions.finalizeCache = false
defaultOptions.frozenCacheCounter = 0
defaultOptions.hardLineBreaks = false
defaultOptions.hashEnumerators = false
defaultOptions.headerAttributes = false
defaultOptions.html = false
defaultOptions.hybrid = false
defaultOptions.inlineCodeAttributes = false
defaultOptions.inlineFootnotes = false
defaultOptions.inlineNotes = false
defaultOptions.jekyllData = false
defaultOptions.linkAttributes = false
defaultOptions.lineBlocks = false
defaultOptions.footnotes = false
defaultOptions.notes = false
defaultOptions.pipeTables = false
defaultOptions.preserveTabs = false
defaultOptions.rawAttribute = true
defaultOptions.relativeReferences = false
defaultOptions.shiftHeadings = 0
defaultOptions.slice = "^ $"
defaultOptions.smartEllipses = false
defaultOptions.startNumber = true
defaultOptions.strikeThrough = false
defaultOptions.stripIndent = false
defaultOptions.subscripts = false
defaultOptions.superscripts = false
defaultOptions.tableCaptions = false
defaultOptions.taskLists = false
defaultOptions.texComments = false
defaultOptions.texMathDollars = false
defaultOptions.texMathDoubleBackslash = false
defaultOptions.texMathSingleBackslash = false
defaultOptions.tightLists = true
defaultOptions.underscores = true
local upper, format, length =
  string.upper, string.format, string.len
local P, R, S, V, C, Cg, Cb, Cmt, Cc, Ct, B, Cs, any =
  lpeg.P, lpeg.R, lpeg.S, lpeg.V, lpeg.C, lpeg.Cg, lpeg.Cb,
  lpeg.Cmt, lpeg.Cc, lpeg.Ct, lpeg.B, lpeg.Cs, lpeg.P(1)
local util = {}
function util.err(msg, exit_code)
  io.stderr:write("markdown.lua: " .. msg .. "\n")
  os.exit(exit_code or 1)
end
function util.cache(dir, string, salt, transform, suffix)
  local digest = md5.sumhexa(string .. (salt or ""))
  local name = util.pathname(dir, digest .. suffix)
  local file = io.open(name, "r")
  if file == nil then -- If no cache entry exists, then create a new one.
    file = assert(io.open(name, "w"),
      [[Could not open file "]] .. name .. [[" for writing]])
    local result = string
    if transform ~= nil then
      result = transform(result)
    end
    assert(file:write(result))
    assert(file:close())
  end
  return name
end
function util.cache_verbatim(dir, string)
  local name = util.cache(dir, string, nil, nil, ".verbatim")
  return name
end
function util.table_copy(t)
  local u = { }
  for k, v in pairs(t) do u[k] = v end
  return setmetatable(u, getmetatable(t))
end
function util.encode_json_string(s)
  s = s:gsub([[\]], [[\\]])
  s = s:gsub([["]], [[\"]])
  return [["]] .. s .. [["]]
end
function util.lookup_files(f, options)
  return kpse.lookup(f, options)
end
function util.expand_tabs_in_line(s, tabstop)
  local tab = tabstop or 4
  local corr = 0
  return (s:gsub("()\t", function(p)
            local sp = tab - (p - 1 + corr) % tab
            corr = corr - 1 + sp
            return string.rep(" ", sp)
          end))
end
function util.walk(t, f)
  local typ = type(t)
  if typ == "string" then
    f(t)
  elseif typ == "table" then
    local i = 1
    local n
    n = t[i]
    while n do
      util.walk(n, f)
      i = i + 1
      n = t[i]
    end
  elseif typ == "function" then
    local ok, val = pcall(t)
    if ok then
      util.walk(val,f)
    end
  else
    f(tostring(t))
  end
end
function util.flatten(ary)
  local new = {}
  for _,v in ipairs(ary) do
    if type(v) == "table" then
      for _,w in ipairs(util.flatten(v)) do
        new[#new + 1] = w
      end
    else
      new[#new + 1] = v
    end
  end
  return new
end
function util.rope_to_string(rope)
  local buffer = {}
  util.walk(rope, function(x) buffer[#buffer + 1] = x end)
  return table.concat(buffer)
end
function util.rope_last(rope)
  if #rope == 0 then
    return nil
  else
    local l = rope[#rope]
    if type(l) == "table" then
      return util.rope_last(l)
    else
      return l
    end
  end
end
function util.intersperse(ary, x)
  local new = {}
  local l = #ary
  for i,v in ipairs(ary) do
    local n = #new
    new[n + 1] = v
    if i ~= l then
      new[n + 2] = x
    end
  end
  return new
end
function util.map(ary, f)
  local new = {}
  for i,v in ipairs(ary) do
    new[i] = f(v)
  end
  return new
end
function util.escaper(char_escapes, string_escapes)
  local char_escapes_list = ""
  for i,_ in pairs(char_escapes) do
    char_escapes_list = char_escapes_list .. i
  end
  local escapable = S(char_escapes_list) / char_escapes
  if string_escapes then
    for k,v in pairs(string_escapes) do
      escapable = P(k) / v + escapable
    end
  end
  local escape_string = Cs((escapable + any)^0)
  return function(s)
    return lpeg.match(escape_string, s)
  end
end
function util.pathname(dir, file)
  if #dir == 0 then
    return file
  else
    return dir .. "/" .. file
  end
end
local entities = {}

local character_entities = {
  ["Tab"] = 9,
  ["NewLine"] = 10,
  ["excl"] = 33,
  ["quot"] = 34,
  ["QUOT"] = 34,
  ["num"] = 35,
  ["dollar"] = 36,
  ["percnt"] = 37,
  ["amp"] = 38,
  ["AMP"] = 38,
  ["apos"] = 39,
  ["lpar"] = 40,
  ["rpar"] = 41,
  ["ast"] = 42,
  ["midast"] = 42,
  ["plus"] = 43,
  ["comma"] = 44,
  ["period"] = 46,
  ["sol"] = 47,
  ["colon"] = 58,
  ["semi"] = 59,
  ["lt"] = 60,
  ["LT"] = 60,
  ["equals"] = 61,
  ["gt"] = 62,
  ["GT"] = 62,
  ["quest"] = 63,
  ["commat"] = 64,
  ["lsqb"] = 91,
  ["lbrack"] = 91,
  ["bsol"] = 92,
  ["rsqb"] = 93,
  ["rbrack"] = 93,
  ["Hat"] = 94,
  ["lowbar"] = 95,
  ["grave"] = 96,
  ["DiacriticalGrave"] = 96,
  ["lcub"] = 123,
  ["lbrace"] = 123,
  ["verbar"] = 124,
  ["vert"] = 124,
  ["VerticalLine"] = 124,
  ["rcub"] = 125,
  ["rbrace"] = 125,
  ["nbsp"] = 160,
  ["NonBreakingSpace"] = 160,
  ["iexcl"] = 161,
  ["cent"] = 162,
  ["pound"] = 163,
  ["curren"] = 164,
  ["yen"] = 165,
  ["brvbar"] = 166,
  ["sect"] = 167,
  ["Dot"] = 168,
  ["die"] = 168,
  ["DoubleDot"] = 168,
  ["uml"] = 168,
  ["copy"] = 169,
  ["COPY"] = 169,
  ["ordf"] = 170,
  ["laquo"] = 171,
  ["not"] = 172,
  ["shy"] = 173,
  ["reg"] = 174,
  ["circledR"] = 174,
  ["REG"] = 174,
  ["macr"] = 175,
  ["OverBar"] = 175,
  ["strns"] = 175,
  ["deg"] = 176,
  ["plusmn"] = 177,
  ["pm"] = 177,
  ["PlusMinus"] = 177,
  ["sup2"] = 178,
  ["sup3"] = 179,
  ["acute"] = 180,
  ["DiacriticalAcute"] = 180,
  ["micro"] = 181,
  ["para"] = 182,
  ["middot"] = 183,
  ["centerdot"] = 183,
  ["CenterDot"] = 183,
  ["cedil"] = 184,
  ["Cedilla"] = 184,
  ["sup1"] = 185,
  ["ordm"] = 186,
  ["raquo"] = 187,
  ["frac14"] = 188,
  ["frac12"] = 189,
  ["half"] = 189,
  ["frac34"] = 190,
  ["iquest"] = 191,
  ["Agrave"] = 192,
  ["Aacute"] = 193,
  ["Acirc"] = 194,
  ["Atilde"] = 195,
  ["Auml"] = 196,
  ["Aring"] = 197,
  ["AElig"] = 198,
  ["Ccedil"] = 199,
  ["Egrave"] = 200,
  ["Eacute"] = 201,
  ["Ecirc"] = 202,
  ["Euml"] = 203,
  ["Igrave"] = 204,
  ["Iacute"] = 205,
  ["Icirc"] = 206,
  ["Iuml"] = 207,
  ["ETH"] = 208,
  ["Ntilde"] = 209,
  ["Ograve"] = 210,
  ["Oacute"] = 211,
  ["Ocirc"] = 212,
  ["Otilde"] = 213,
  ["Ouml"] = 214,
  ["times"] = 215,
  ["Oslash"] = 216,
  ["Ugrave"] = 217,
  ["Uacute"] = 218,
  ["Ucirc"] = 219,
  ["Uuml"] = 220,
  ["Yacute"] = 221,
  ["THORN"] = 222,
  ["szlig"] = 223,
  ["agrave"] = 224,
  ["aacute"] = 225,
  ["acirc"] = 226,
  ["atilde"] = 227,
  ["auml"] = 228,
  ["aring"] = 229,
  ["aelig"] = 230,
  ["ccedil"] = 231,
  ["egrave"] = 232,
  ["eacute"] = 233,
  ["ecirc"] = 234,
  ["euml"] = 235,
  ["igrave"] = 236,
  ["iacute"] = 237,
  ["icirc"] = 238,
  ["iuml"] = 239,
  ["eth"] = 240,
  ["ntilde"] = 241,
  ["ograve"] = 242,
  ["oacute"] = 243,
  ["ocirc"] = 244,
  ["otilde"] = 245,
  ["ouml"] = 246,
  ["divide"] = 247,
  ["div"] = 247,
  ["oslash"] = 248,
  ["ugrave"] = 249,
  ["uacute"] = 250,
  ["ucirc"] = 251,
  ["uuml"] = 252,
  ["yacute"] = 253,
  ["thorn"] = 254,
  ["yuml"] = 255,
  ["Amacr"] = 256,
  ["amacr"] = 257,
  ["Abreve"] = 258,
  ["abreve"] = 259,
  ["Aogon"] = 260,
  ["aogon"] = 261,
  ["Cacute"] = 262,
  ["cacute"] = 263,
  ["Ccirc"] = 264,
  ["ccirc"] = 265,
  ["Cdot"] = 266,
  ["cdot"] = 267,
  ["Ccaron"] = 268,
  ["ccaron"] = 269,
  ["Dcaron"] = 270,
  ["dcaron"] = 271,
  ["Dstrok"] = 272,
  ["dstrok"] = 273,
  ["Emacr"] = 274,
  ["emacr"] = 275,
  ["Edot"] = 278,
  ["edot"] = 279,
  ["Eogon"] = 280,
  ["eogon"] = 281,
  ["Ecaron"] = 282,
  ["ecaron"] = 283,
  ["Gcirc"] = 284,
  ["gcirc"] = 285,
  ["Gbreve"] = 286,
  ["gbreve"] = 287,
  ["Gdot"] = 288,
  ["gdot"] = 289,
  ["Gcedil"] = 290,
  ["Hcirc"] = 292,
  ["hcirc"] = 293,
  ["Hstrok"] = 294,
  ["hstrok"] = 295,
  ["Itilde"] = 296,
  ["itilde"] = 297,
  ["Imacr"] = 298,
  ["imacr"] = 299,
  ["Iogon"] = 302,
  ["iogon"] = 303,
  ["Idot"] = 304,
  ["imath"] = 305,
  ["inodot"] = 305,
  ["IJlig"] = 306,
  ["ijlig"] = 307,
  ["Jcirc"] = 308,
  ["jcirc"] = 309,
  ["Kcedil"] = 310,
  ["kcedil"] = 311,
  ["kgreen"] = 312,
  ["Lacute"] = 313,
  ["lacute"] = 314,
  ["Lcedil"] = 315,
  ["lcedil"] = 316,
  ["Lcaron"] = 317,
  ["lcaron"] = 318,
  ["Lmidot"] = 319,
  ["lmidot"] = 320,
  ["Lstrok"] = 321,
  ["lstrok"] = 322,
  ["Nacute"] = 323,
  ["nacute"] = 324,
  ["Ncedil"] = 325,
  ["ncedil"] = 326,
  ["Ncaron"] = 327,
  ["ncaron"] = 328,
  ["napos"] = 329,
  ["ENG"] = 330,
  ["eng"] = 331,
  ["Omacr"] = 332,
  ["omacr"] = 333,
  ["Odblac"] = 336,
  ["odblac"] = 337,
  ["OElig"] = 338,
  ["oelig"] = 339,
  ["Racute"] = 340,
  ["racute"] = 341,
  ["Rcedil"] = 342,
  ["rcedil"] = 343,
  ["Rcaron"] = 344,
  ["rcaron"] = 345,
  ["Sacute"] = 346,
  ["sacute"] = 347,
  ["Scirc"] = 348,
  ["scirc"] = 349,
  ["Scedil"] = 350,
  ["scedil"] = 351,
  ["Scaron"] = 352,
  ["scaron"] = 353,
  ["Tcedil"] = 354,
  ["tcedil"] = 355,
  ["Tcaron"] = 356,
  ["tcaron"] = 357,
  ["Tstrok"] = 358,
  ["tstrok"] = 359,
  ["Utilde"] = 360,
  ["utilde"] = 361,
  ["Umacr"] = 362,
  ["umacr"] = 363,
  ["Ubreve"] = 364,
  ["ubreve"] = 365,
  ["Uring"] = 366,
  ["uring"] = 367,
  ["Udblac"] = 368,
  ["udblac"] = 369,
  ["Uogon"] = 370,
  ["uogon"] = 371,
  ["Wcirc"] = 372,
  ["wcirc"] = 373,
  ["Ycirc"] = 374,
  ["ycirc"] = 375,
  ["Yuml"] = 376,
  ["Zacute"] = 377,
  ["zacute"] = 378,
  ["Zdot"] = 379,
  ["zdot"] = 380,
  ["Zcaron"] = 381,
  ["zcaron"] = 382,
  ["fnof"] = 402,
  ["imped"] = 437,
  ["gacute"] = 501,
  ["jmath"] = 567,
  ["circ"] = 710,
  ["caron"] = 711,
  ["Hacek"] = 711,
  ["breve"] = 728,
  ["Breve"] = 728,
  ["dot"] = 729,
  ["DiacriticalDot"] = 729,
  ["ring"] = 730,
  ["ogon"] = 731,
  ["tilde"] = 732,
  ["DiacriticalTilde"] = 732,
  ["dblac"] = 733,
  ["DiacriticalDoubleAcute"] = 733,
  ["DownBreve"] = 785,
  ["UnderBar"] = 818,
  ["Alpha"] = 913,
  ["Beta"] = 914,
  ["Gamma"] = 915,
  ["Delta"] = 916,
  ["Epsilon"] = 917,
  ["Zeta"] = 918,
  ["Eta"] = 919,
  ["Theta"] = 920,
  ["Iota"] = 921,
  ["Kappa"] = 922,
  ["Lambda"] = 923,
  ["Mu"] = 924,
  ["Nu"] = 925,
  ["Xi"] = 926,
  ["Omicron"] = 927,
  ["Pi"] = 928,
  ["Rho"] = 929,
  ["Sigma"] = 931,
  ["Tau"] = 932,
  ["Upsilon"] = 933,
  ["Phi"] = 934,
  ["Chi"] = 935,
  ["Psi"] = 936,
  ["Omega"] = 937,
  ["alpha"] = 945,
  ["beta"] = 946,
  ["gamma"] = 947,
  ["delta"] = 948,
  ["epsiv"] = 949,
  ["varepsilon"] = 949,
  ["epsilon"] = 949,
  ["zeta"] = 950,
  ["eta"] = 951,
  ["theta"] = 952,
  ["iota"] = 953,
  ["kappa"] = 954,
  ["lambda"] = 955,
  ["mu"] = 956,
  ["nu"] = 957,
  ["xi"] = 958,
  ["omicron"] = 959,
  ["pi"] = 960,
  ["rho"] = 961,
  ["sigmav"] = 962,
  ["varsigma"] = 962,
  ["sigmaf"] = 962,
  ["sigma"] = 963,
  ["tau"] = 964,
  ["upsi"] = 965,
  ["upsilon"] = 965,
  ["phi"] = 966,
  ["phiv"] = 966,
  ["varphi"] = 966,
  ["chi"] = 967,
  ["psi"] = 968,
  ["omega"] = 969,
  ["thetav"] = 977,
  ["vartheta"] = 977,
  ["thetasym"] = 977,
  ["Upsi"] = 978,
  ["upsih"] = 978,
  ["straightphi"] = 981,
  ["piv"] = 982,
  ["varpi"] = 982,
  ["Gammad"] = 988,
  ["gammad"] = 989,
  ["digamma"] = 989,
  ["kappav"] = 1008,
  ["varkappa"] = 1008,
  ["rhov"] = 1009,
  ["varrho"] = 1009,
  ["epsi"] = 1013,
  ["straightepsilon"] = 1013,
  ["bepsi"] = 1014,
  ["backepsilon"] = 1014,
  ["IOcy"] = 1025,
  ["DJcy"] = 1026,
  ["GJcy"] = 1027,
  ["Jukcy"] = 1028,
  ["DScy"] = 1029,
  ["Iukcy"] = 1030,
  ["YIcy"] = 1031,
  ["Jsercy"] = 1032,
  ["LJcy"] = 1033,
  ["NJcy"] = 1034,
  ["TSHcy"] = 1035,
  ["KJcy"] = 1036,
  ["Ubrcy"] = 1038,
  ["DZcy"] = 1039,
  ["Acy"] = 1040,
  ["Bcy"] = 1041,
  ["Vcy"] = 1042,
  ["Gcy"] = 1043,
  ["Dcy"] = 1044,
  ["IEcy"] = 1045,
  ["ZHcy"] = 1046,
  ["Zcy"] = 1047,
  ["Icy"] = 1048,
  ["Jcy"] = 1049,
  ["Kcy"] = 1050,
  ["Lcy"] = 1051,
  ["Mcy"] = 1052,
  ["Ncy"] = 1053,
  ["Ocy"] = 1054,
  ["Pcy"] = 1055,
  ["Rcy"] = 1056,
  ["Scy"] = 1057,
  ["Tcy"] = 1058,
  ["Ucy"] = 1059,
  ["Fcy"] = 1060,
  ["KHcy"] = 1061,
  ["TScy"] = 1062,
  ["CHcy"] = 1063,
  ["SHcy"] = 1064,
  ["SHCHcy"] = 1065,
  ["HARDcy"] = 1066,
  ["Ycy"] = 1067,
  ["SOFTcy"] = 1068,
  ["Ecy"] = 1069,
  ["YUcy"] = 1070,
  ["YAcy"] = 1071,
  ["acy"] = 1072,
  ["bcy"] = 1073,
  ["vcy"] = 1074,
  ["gcy"] = 1075,
  ["dcy"] = 1076,
  ["iecy"] = 1077,
  ["zhcy"] = 1078,
  ["zcy"] = 1079,
  ["icy"] = 1080,
  ["jcy"] = 1081,
  ["kcy"] = 1082,
  ["lcy"] = 1083,
  ["mcy"] = 1084,
  ["ncy"] = 1085,
  ["ocy"] = 1086,
  ["pcy"] = 1087,
  ["rcy"] = 1088,
  ["scy"] = 1089,
  ["tcy"] = 1090,
  ["ucy"] = 1091,
  ["fcy"] = 1092,
  ["khcy"] = 1093,
  ["tscy"] = 1094,
  ["chcy"] = 1095,
  ["shcy"] = 1096,
  ["shchcy"] = 1097,
  ["hardcy"] = 1098,
  ["ycy"] = 1099,
  ["softcy"] = 1100,
  ["ecy"] = 1101,
  ["yucy"] = 1102,
  ["yacy"] = 1103,
  ["iocy"] = 1105,
  ["djcy"] = 1106,
  ["gjcy"] = 1107,
  ["jukcy"] = 1108,
  ["dscy"] = 1109,
  ["iukcy"] = 1110,
  ["yicy"] = 1111,
  ["jsercy"] = 1112,
  ["ljcy"] = 1113,
  ["njcy"] = 1114,
  ["tshcy"] = 1115,
  ["kjcy"] = 1116,
  ["ubrcy"] = 1118,
  ["dzcy"] = 1119,
  ["ensp"] = 8194,
  ["emsp"] = 8195,
  ["emsp13"] = 8196,
  ["emsp14"] = 8197,
  ["numsp"] = 8199,
  ["puncsp"] = 8200,
  ["thinsp"] = 8201,
  ["ThinSpace"] = 8201,
  ["hairsp"] = 8202,
  ["VeryThinSpace"] = 8202,
  ["ZeroWidthSpace"] = 8203,
  ["NegativeVeryThinSpace"] = 8203,
  ["NegativeThinSpace"] = 8203,
  ["NegativeMediumSpace"] = 8203,
  ["NegativeThickSpace"] = 8203,
  ["zwnj"] = 8204,
  ["zwj"] = 8205,
  ["lrm"] = 8206,
  ["rlm"] = 8207,
  ["hyphen"] = 8208,
  ["dash"] = 8208,
  ["ndash"] = 8211,
  ["mdash"] = 8212,
  ["horbar"] = 8213,
  ["Verbar"] = 8214,
  ["Vert"] = 8214,
  ["lsquo"] = 8216,
  ["OpenCurlyQuote"] = 8216,
  ["rsquo"] = 8217,
  ["rsquor"] = 8217,
  ["CloseCurlyQuote"] = 8217,
  ["lsquor"] = 8218,
  ["sbquo"] = 8218,
  ["ldquo"] = 8220,
  ["OpenCurlyDoubleQuote"] = 8220,
  ["rdquo"] = 8221,
  ["rdquor"] = 8221,
  ["CloseCurlyDoubleQuote"] = 8221,
  ["ldquor"] = 8222,
  ["bdquo"] = 8222,
  ["dagger"] = 8224,
  ["Dagger"] = 8225,
  ["ddagger"] = 8225,
  ["bull"] = 8226,
  ["bullet"] = 8226,
  ["nldr"] = 8229,
  ["hellip"] = 8230,
  ["mldr"] = 8230,
  ["permil"] = 8240,
  ["pertenk"] = 8241,
  ["prime"] = 8242,
  ["Prime"] = 8243,
  ["tprime"] = 8244,
  ["bprime"] = 8245,
  ["backprime"] = 8245,
  ["lsaquo"] = 8249,
  ["rsaquo"] = 8250,
  ["oline"] = 8254,
  ["caret"] = 8257,
  ["hybull"] = 8259,
  ["frasl"] = 8260,
  ["bsemi"] = 8271,
  ["qprime"] = 8279,
  ["MediumSpace"] = 8287,
  ["NoBreak"] = 8288,
  ["ApplyFunction"] = 8289,
  ["af"] = 8289,
  ["InvisibleTimes"] = 8290,
  ["it"] = 8290,
  ["InvisibleComma"] = 8291,
  ["ic"] = 8291,
  ["euro"] = 8364,
  ["tdot"] = 8411,
  ["TripleDot"] = 8411,
  ["DotDot"] = 8412,
  ["Copf"] = 8450,
  ["complexes"] = 8450,
  ["incare"] = 8453,
  ["gscr"] = 8458,
  ["hamilt"] = 8459,
  ["HilbertSpace"] = 8459,
  ["Hscr"] = 8459,
  ["Hfr"] = 8460,
  ["Poincareplane"] = 8460,
  ["quaternions"] = 8461,
  ["Hopf"] = 8461,
  ["planckh"] = 8462,
  ["planck"] = 8463,
  ["hbar"] = 8463,
  ["plankv"] = 8463,
  ["hslash"] = 8463,
  ["Iscr"] = 8464,
  ["imagline"] = 8464,
  ["image"] = 8465,
  ["Im"] = 8465,
  ["imagpart"] = 8465,
  ["Ifr"] = 8465,
  ["Lscr"] = 8466,
  ["lagran"] = 8466,
  ["Laplacetrf"] = 8466,
  ["ell"] = 8467,
  ["Nopf"] = 8469,
  ["naturals"] = 8469,
  ["numero"] = 8470,
  ["copysr"] = 8471,
  ["weierp"] = 8472,
  ["wp"] = 8472,
  ["Popf"] = 8473,
  ["primes"] = 8473,
  ["rationals"] = 8474,
  ["Qopf"] = 8474,
  ["Rscr"] = 8475,
  ["realine"] = 8475,
  ["real"] = 8476,
  ["Re"] = 8476,
  ["realpart"] = 8476,
  ["Rfr"] = 8476,
  ["reals"] = 8477,
  ["Ropf"] = 8477,
  ["rx"] = 8478,
  ["trade"] = 8482,
  ["TRADE"] = 8482,
  ["integers"] = 8484,
  ["Zopf"] = 8484,
  ["ohm"] = 8486,
  ["mho"] = 8487,
  ["Zfr"] = 8488,
  ["zeetrf"] = 8488,
  ["iiota"] = 8489,
  ["angst"] = 8491,
  ["bernou"] = 8492,
  ["Bernoullis"] = 8492,
  ["Bscr"] = 8492,
  ["Cfr"] = 8493,
  ["Cayleys"] = 8493,
  ["escr"] = 8495,
  ["Escr"] = 8496,
  ["expectation"] = 8496,
  ["Fscr"] = 8497,
  ["Fouriertrf"] = 8497,
  ["phmmat"] = 8499,
  ["Mellintrf"] = 8499,
  ["Mscr"] = 8499,
  ["order"] = 8500,
  ["orderof"] = 8500,
  ["oscr"] = 8500,
  ["alefsym"] = 8501,
  ["aleph"] = 8501,
  ["beth"] = 8502,
  ["gimel"] = 8503,
  ["daleth"] = 8504,
  ["CapitalDifferentialD"] = 8517,
  ["DD"] = 8517,
  ["DifferentialD"] = 8518,
  ["dd"] = 8518,
  ["ExponentialE"] = 8519,
  ["exponentiale"] = 8519,
  ["ee"] = 8519,
  ["ImaginaryI"] = 8520,
  ["ii"] = 8520,
  ["frac13"] = 8531,
  ["frac23"] = 8532,
  ["frac15"] = 8533,
  ["frac25"] = 8534,
  ["frac35"] = 8535,
  ["frac45"] = 8536,
  ["frac16"] = 8537,
  ["frac56"] = 8538,
  ["frac18"] = 8539,
  ["frac38"] = 8540,
  ["frac58"] = 8541,
  ["frac78"] = 8542,
  ["larr"] = 8592,
  ["leftarrow"] = 8592,
  ["LeftArrow"] = 8592,
  ["slarr"] = 8592,
  ["ShortLeftArrow"] = 8592,
  ["uarr"] = 8593,
  ["uparrow"] = 8593,
  ["UpArrow"] = 8593,
  ["ShortUpArrow"] = 8593,
  ["rarr"] = 8594,
  ["rightarrow"] = 8594,
  ["RightArrow"] = 8594,
  ["srarr"] = 8594,
  ["ShortRightArrow"] = 8594,
  ["darr"] = 8595,
  ["downarrow"] = 8595,
  ["DownArrow"] = 8595,
  ["ShortDownArrow"] = 8595,
  ["harr"] = 8596,
  ["leftrightarrow"] = 8596,
  ["LeftRightArrow"] = 8596,
  ["varr"] = 8597,
  ["updownarrow"] = 8597,
  ["UpDownArrow"] = 8597,
  ["nwarr"] = 8598,
  ["UpperLeftArrow"] = 8598,
  ["nwarrow"] = 8598,
  ["nearr"] = 8599,
  ["UpperRightArrow"] = 8599,
  ["nearrow"] = 8599,
  ["searr"] = 8600,
  ["searrow"] = 8600,
  ["LowerRightArrow"] = 8600,
  ["swarr"] = 8601,
  ["swarrow"] = 8601,
  ["LowerLeftArrow"] = 8601,
  ["nlarr"] = 8602,
  ["nleftarrow"] = 8602,
  ["nrarr"] = 8603,
  ["nrightarrow"] = 8603,
  ["rarrw"] = 8605,
  ["rightsquigarrow"] = 8605,
  ["Larr"] = 8606,
  ["twoheadleftarrow"] = 8606,
  ["Uarr"] = 8607,
  ["Rarr"] = 8608,
  ["twoheadrightarrow"] = 8608,
  ["Darr"] = 8609,
  ["larrtl"] = 8610,
  ["leftarrowtail"] = 8610,
  ["rarrtl"] = 8611,
  ["rightarrowtail"] = 8611,
  ["LeftTeeArrow"] = 8612,
  ["mapstoleft"] = 8612,
  ["UpTeeArrow"] = 8613,
  ["mapstoup"] = 8613,
  ["map"] = 8614,
  ["RightTeeArrow"] = 8614,
  ["mapsto"] = 8614,
  ["DownTeeArrow"] = 8615,
  ["mapstodown"] = 8615,
  ["larrhk"] = 8617,
  ["hookleftarrow"] = 8617,
  ["rarrhk"] = 8618,
  ["hookrightarrow"] = 8618,
  ["larrlp"] = 8619,
  ["looparrowleft"] = 8619,
  ["rarrlp"] = 8620,
  ["looparrowright"] = 8620,
  ["harrw"] = 8621,
  ["leftrightsquigarrow"] = 8621,
  ["nharr"] = 8622,
  ["nleftrightarrow"] = 8622,
  ["lsh"] = 8624,
  ["Lsh"] = 8624,
  ["rsh"] = 8625,
  ["Rsh"] = 8625,
  ["ldsh"] = 8626,
  ["rdsh"] = 8627,
  ["crarr"] = 8629,
  ["cularr"] = 8630,
  ["curvearrowleft"] = 8630,
  ["curarr"] = 8631,
  ["curvearrowright"] = 8631,
  ["olarr"] = 8634,
  ["circlearrowleft"] = 8634,
  ["orarr"] = 8635,
  ["circlearrowright"] = 8635,
  ["lharu"] = 8636,
  ["LeftVector"] = 8636,
  ["leftharpoonup"] = 8636,
  ["lhard"] = 8637,
  ["leftharpoondown"] = 8637,
  ["DownLeftVector"] = 8637,
  ["uharr"] = 8638,
  ["upharpoonright"] = 8638,
  ["RightUpVector"] = 8638,
  ["uharl"] = 8639,
  ["upharpoonleft"] = 8639,
  ["LeftUpVector"] = 8639,
  ["rharu"] = 8640,
  ["RightVector"] = 8640,
  ["rightharpoonup"] = 8640,
  ["rhard"] = 8641,
  ["rightharpoondown"] = 8641,
  ["DownRightVector"] = 8641,
  ["dharr"] = 8642,
  ["RightDownVector"] = 8642,
  ["downharpoonright"] = 8642,
  ["dharl"] = 8643,
  ["LeftDownVector"] = 8643,
  ["downharpoonleft"] = 8643,
  ["rlarr"] = 8644,
  ["rightleftarrows"] = 8644,
  ["RightArrowLeftArrow"] = 8644,
  ["udarr"] = 8645,
  ["UpArrowDownArrow"] = 8645,
  ["lrarr"] = 8646,
  ["leftrightarrows"] = 8646,
  ["LeftArrowRightArrow"] = 8646,
  ["llarr"] = 8647,
  ["leftleftarrows"] = 8647,
  ["uuarr"] = 8648,
  ["upuparrows"] = 8648,
  ["rrarr"] = 8649,
  ["rightrightarrows"] = 8649,
  ["ddarr"] = 8650,
  ["downdownarrows"] = 8650,
  ["lrhar"] = 8651,
  ["ReverseEquilibrium"] = 8651,
  ["leftrightharpoons"] = 8651,
  ["rlhar"] = 8652,
  ["rightleftharpoons"] = 8652,
  ["Equilibrium"] = 8652,
  ["nlArr"] = 8653,
  ["nLeftarrow"] = 8653,
  ["nhArr"] = 8654,
  ["nLeftrightarrow"] = 8654,
  ["nrArr"] = 8655,
  ["nRightarrow"] = 8655,
  ["lArr"] = 8656,
  ["Leftarrow"] = 8656,
  ["DoubleLeftArrow"] = 8656,
  ["uArr"] = 8657,
  ["Uparrow"] = 8657,
  ["DoubleUpArrow"] = 8657,
  ["rArr"] = 8658,
  ["Rightarrow"] = 8658,
  ["Implies"] = 8658,
  ["DoubleRightArrow"] = 8658,
  ["dArr"] = 8659,
  ["Downarrow"] = 8659,
  ["DoubleDownArrow"] = 8659,
  ["hArr"] = 8660,
  ["Leftrightarrow"] = 8660,
  ["DoubleLeftRightArrow"] = 8660,
  ["iff"] = 8660,
  ["vArr"] = 8661,
  ["Updownarrow"] = 8661,
  ["DoubleUpDownArrow"] = 8661,
  ["nwArr"] = 8662,
  ["neArr"] = 8663,
  ["seArr"] = 8664,
  ["swArr"] = 8665,
  ["lAarr"] = 8666,
  ["Lleftarrow"] = 8666,
  ["rAarr"] = 8667,
  ["Rrightarrow"] = 8667,
  ["zigrarr"] = 8669,
  ["larrb"] = 8676,
  ["LeftArrowBar"] = 8676,
  ["rarrb"] = 8677,
  ["RightArrowBar"] = 8677,
  ["duarr"] = 8693,
  ["DownArrowUpArrow"] = 8693,
  ["loarr"] = 8701,
  ["roarr"] = 8702,
  ["hoarr"] = 8703,
  ["forall"] = 8704,
  ["ForAll"] = 8704,
  ["comp"] = 8705,
  ["complement"] = 8705,
  ["part"] = 8706,
  ["PartialD"] = 8706,
  ["exist"] = 8707,
  ["Exists"] = 8707,
  ["nexist"] = 8708,
  ["NotExists"] = 8708,
  ["nexists"] = 8708,
  ["empty"] = 8709,
  ["emptyset"] = 8709,
  ["emptyv"] = 8709,
  ["varnothing"] = 8709,
  ["nabla"] = 8711,
  ["Del"] = 8711,
  ["isin"] = 8712,
  ["isinv"] = 8712,
  ["Element"] = 8712,
  ["in"] = 8712,
  ["notin"] = 8713,
  ["NotElement"] = 8713,
  ["notinva"] = 8713,
  ["niv"] = 8715,
  ["ReverseElement"] = 8715,
  ["ni"] = 8715,
  ["SuchThat"] = 8715,
  ["notni"] = 8716,
  ["notniva"] = 8716,
  ["NotReverseElement"] = 8716,
  ["prod"] = 8719,
  ["Product"] = 8719,
  ["coprod"] = 8720,
  ["Coproduct"] = 8720,
  ["sum"] = 8721,
  ["Sum"] = 8721,
  ["minus"] = 8722,
  ["mnplus"] = 8723,
  ["mp"] = 8723,
  ["MinusPlus"] = 8723,
  ["plusdo"] = 8724,
  ["dotplus"] = 8724,
  ["setmn"] = 8726,
  ["setminus"] = 8726,
  ["Backslash"] = 8726,
  ["ssetmn"] = 8726,
  ["smallsetminus"] = 8726,
  ["lowast"] = 8727,
  ["compfn"] = 8728,
  ["SmallCircle"] = 8728,
  ["radic"] = 8730,
  ["Sqrt"] = 8730,
  ["prop"] = 8733,
  ["propto"] = 8733,
  ["Proportional"] = 8733,
  ["vprop"] = 8733,
  ["varpropto"] = 8733,
  ["infin"] = 8734,
  ["angrt"] = 8735,
  ["ang"] = 8736,
  ["angle"] = 8736,
  ["angmsd"] = 8737,
  ["measuredangle"] = 8737,
  ["angsph"] = 8738,
  ["mid"] = 8739,
  ["VerticalBar"] = 8739,
  ["smid"] = 8739,
  ["shortmid"] = 8739,
  ["nmid"] = 8740,
  ["NotVerticalBar"] = 8740,
  ["nsmid"] = 8740,
  ["nshortmid"] = 8740,
  ["par"] = 8741,
  ["parallel"] = 8741,
  ["DoubleVerticalBar"] = 8741,
  ["spar"] = 8741,
  ["shortparallel"] = 8741,
  ["npar"] = 8742,
  ["nparallel"] = 8742,
  ["NotDoubleVerticalBar"] = 8742,
  ["nspar"] = 8742,
  ["nshortparallel"] = 8742,
  ["and"] = 8743,
  ["wedge"] = 8743,
  ["or"] = 8744,
  ["vee"] = 8744,
  ["cap"] = 8745,
  ["cup"] = 8746,
  ["int"] = 8747,
  ["Integral"] = 8747,
  ["Int"] = 8748,
  ["tint"] = 8749,
  ["iiint"] = 8749,
  ["conint"] = 8750,
  ["oint"] = 8750,
  ["ContourIntegral"] = 8750,
  ["Conint"] = 8751,
  ["DoubleContourIntegral"] = 8751,
  ["Cconint"] = 8752,
  ["cwint"] = 8753,
  ["cwconint"] = 8754,
  ["ClockwiseContourIntegral"] = 8754,
  ["awconint"] = 8755,
  ["CounterClockwiseContourIntegral"] = 8755,
  ["there4"] = 8756,
  ["therefore"] = 8756,
  ["Therefore"] = 8756,
  ["becaus"] = 8757,
  ["because"] = 8757,
  ["Because"] = 8757,
  ["ratio"] = 8758,
  ["Colon"] = 8759,
  ["Proportion"] = 8759,
  ["minusd"] = 8760,
  ["dotminus"] = 8760,
  ["mDDot"] = 8762,
  ["homtht"] = 8763,
  ["sim"] = 8764,
  ["Tilde"] = 8764,
  ["thksim"] = 8764,
  ["thicksim"] = 8764,
  ["bsim"] = 8765,
  ["backsim"] = 8765,
  ["ac"] = 8766,
  ["mstpos"] = 8766,
  ["acd"] = 8767,
  ["wreath"] = 8768,
  ["VerticalTilde"] = 8768,
  ["wr"] = 8768,
  ["nsim"] = 8769,
  ["NotTilde"] = 8769,
  ["esim"] = 8770,
  ["EqualTilde"] = 8770,
  ["eqsim"] = 8770,
  ["sime"] = 8771,
  ["TildeEqual"] = 8771,
  ["simeq"] = 8771,
  ["nsime"] = 8772,
  ["nsimeq"] = 8772,
  ["NotTildeEqual"] = 8772,
  ["cong"] = 8773,
  ["TildeFullEqual"] = 8773,
  ["simne"] = 8774,
  ["ncong"] = 8775,
  ["NotTildeFullEqual"] = 8775,
  ["asymp"] = 8776,
  ["ap"] = 8776,
  ["TildeTilde"] = 8776,
  ["approx"] = 8776,
  ["thkap"] = 8776,
  ["thickapprox"] = 8776,
  ["nap"] = 8777,
  ["NotTildeTilde"] = 8777,
  ["napprox"] = 8777,
  ["ape"] = 8778,
  ["approxeq"] = 8778,
  ["apid"] = 8779,
  ["bcong"] = 8780,
  ["backcong"] = 8780,
  ["asympeq"] = 8781,
  ["CupCap"] = 8781,
  ["bump"] = 8782,
  ["HumpDownHump"] = 8782,
  ["Bumpeq"] = 8782,
  ["bumpe"] = 8783,
  ["HumpEqual"] = 8783,
  ["bumpeq"] = 8783,
  ["esdot"] = 8784,
  ["DotEqual"] = 8784,
  ["doteq"] = 8784,
  ["eDot"] = 8785,
  ["doteqdot"] = 8785,
  ["efDot"] = 8786,
  ["fallingdotseq"] = 8786,
  ["erDot"] = 8787,
  ["risingdotseq"] = 8787,
  ["colone"] = 8788,
  ["coloneq"] = 8788,
  ["Assign"] = 8788,
  ["ecolon"] = 8789,
  ["eqcolon"] = 8789,
  ["ecir"] = 8790,
  ["eqcirc"] = 8790,
  ["cire"] = 8791,
  ["circeq"] = 8791,
  ["wedgeq"] = 8793,
  ["veeeq"] = 8794,
  ["trie"] = 8796,
  ["triangleq"] = 8796,
  ["equest"] = 8799,
  ["questeq"] = 8799,
  ["ne"] = 8800,
  ["NotEqual"] = 8800,
  ["equiv"] = 8801,
  ["Congruent"] = 8801,
  ["nequiv"] = 8802,
  ["NotCongruent"] = 8802,
  ["le"] = 8804,
  ["leq"] = 8804,
  ["ge"] = 8805,
  ["GreaterEqual"] = 8805,
  ["geq"] = 8805,
  ["lE"] = 8806,
  ["LessFullEqual"] = 8806,
  ["leqq"] = 8806,
  ["gE"] = 8807,
  ["GreaterFullEqual"] = 8807,
  ["geqq"] = 8807,
  ["lnE"] = 8808,
  ["lneqq"] = 8808,
  ["gnE"] = 8809,
  ["gneqq"] = 8809,
  ["Lt"] = 8810,
  ["NestedLessLess"] = 8810,
  ["ll"] = 8810,
  ["Gt"] = 8811,
  ["NestedGreaterGreater"] = 8811,
  ["gg"] = 8811,
  ["twixt"] = 8812,
  ["between"] = 8812,
  ["NotCupCap"] = 8813,
  ["nlt"] = 8814,
  ["NotLess"] = 8814,
  ["nless"] = 8814,
  ["ngt"] = 8815,
  ["NotGreater"] = 8815,
  ["ngtr"] = 8815,
  ["nle"] = 8816,
  ["NotLessEqual"] = 8816,
  ["nleq"] = 8816,
  ["nge"] = 8817,
  ["NotGreaterEqual"] = 8817,
  ["ngeq"] = 8817,
  ["lsim"] = 8818,
  ["LessTilde"] = 8818,
  ["lesssim"] = 8818,
  ["gsim"] = 8819,
  ["gtrsim"] = 8819,
  ["GreaterTilde"] = 8819,
  ["nlsim"] = 8820,
  ["NotLessTilde"] = 8820,
  ["ngsim"] = 8821,
  ["NotGreaterTilde"] = 8821,
  ["lg"] = 8822,
  ["lessgtr"] = 8822,
  ["LessGreater"] = 8822,
  ["gl"] = 8823,
  ["gtrless"] = 8823,
  ["GreaterLess"] = 8823,
  ["ntlg"] = 8824,
  ["NotLessGreater"] = 8824,
  ["ntgl"] = 8825,
  ["NotGreaterLess"] = 8825,
  ["pr"] = 8826,
  ["Precedes"] = 8826,
  ["prec"] = 8826,
  ["sc"] = 8827,
  ["Succeeds"] = 8827,
  ["succ"] = 8827,
  ["prcue"] = 8828,
  ["PrecedesSlantEqual"] = 8828,
  ["preccurlyeq"] = 8828,
  ["sccue"] = 8829,
  ["SucceedsSlantEqual"] = 8829,
  ["succcurlyeq"] = 8829,
  ["prsim"] = 8830,
  ["precsim"] = 8830,
  ["PrecedesTilde"] = 8830,
  ["scsim"] = 8831,
  ["succsim"] = 8831,
  ["SucceedsTilde"] = 8831,
  ["npr"] = 8832,
  ["nprec"] = 8832,
  ["NotPrecedes"] = 8832,
  ["nsc"] = 8833,
  ["nsucc"] = 8833,
  ["NotSucceeds"] = 8833,
  ["sub"] = 8834,
  ["subset"] = 8834,
  ["sup"] = 8835,
  ["supset"] = 8835,
  ["Superset"] = 8835,
  ["nsub"] = 8836,
  ["nsup"] = 8837,
  ["sube"] = 8838,
  ["SubsetEqual"] = 8838,
  ["subseteq"] = 8838,
  ["supe"] = 8839,
  ["supseteq"] = 8839,
  ["SupersetEqual"] = 8839,
  ["nsube"] = 8840,
  ["nsubseteq"] = 8840,
  ["NotSubsetEqual"] = 8840,
  ["nsupe"] = 8841,
  ["nsupseteq"] = 8841,
  ["NotSupersetEqual"] = 8841,
  ["subne"] = 8842,
  ["subsetneq"] = 8842,
  ["supne"] = 8843,
  ["supsetneq"] = 8843,
  ["cupdot"] = 8845,
  ["uplus"] = 8846,
  ["UnionPlus"] = 8846,
  ["sqsub"] = 8847,
  ["SquareSubset"] = 8847,
  ["sqsubset"] = 8847,
  ["sqsup"] = 8848,
  ["SquareSuperset"] = 8848,
  ["sqsupset"] = 8848,
  ["sqsube"] = 8849,
  ["SquareSubsetEqual"] = 8849,
  ["sqsubseteq"] = 8849,
  ["sqsupe"] = 8850,
  ["SquareSupersetEqual"] = 8850,
  ["sqsupseteq"] = 8850,
  ["sqcap"] = 8851,
  ["SquareIntersection"] = 8851,
  ["sqcup"] = 8852,
  ["SquareUnion"] = 8852,
  ["oplus"] = 8853,
  ["CirclePlus"] = 8853,
  ["ominus"] = 8854,
  ["CircleMinus"] = 8854,
  ["otimes"] = 8855,
  ["CircleTimes"] = 8855,
  ["osol"] = 8856,
  ["odot"] = 8857,
  ["CircleDot"] = 8857,
  ["ocir"] = 8858,
  ["circledcirc"] = 8858,
  ["oast"] = 8859,
  ["circledast"] = 8859,
  ["odash"] = 8861,
  ["circleddash"] = 8861,
  ["plusb"] = 8862,
  ["boxplus"] = 8862,
  ["minusb"] = 8863,
  ["boxminus"] = 8863,
  ["timesb"] = 8864,
  ["boxtimes"] = 8864,
  ["sdotb"] = 8865,
  ["dotsquare"] = 8865,
  ["vdash"] = 8866,
  ["RightTee"] = 8866,
  ["dashv"] = 8867,
  ["LeftTee"] = 8867,
  ["top"] = 8868,
  ["DownTee"] = 8868,
  ["bottom"] = 8869,
  ["bot"] = 8869,
  ["perp"] = 8869,
  ["UpTee"] = 8869,
  ["models"] = 8871,
  ["vDash"] = 8872,
  ["DoubleRightTee"] = 8872,
  ["Vdash"] = 8873,
  ["Vvdash"] = 8874,
  ["VDash"] = 8875,
  ["nvdash"] = 8876,
  ["nvDash"] = 8877,
  ["nVdash"] = 8878,
  ["nVDash"] = 8879,
  ["prurel"] = 8880,
  ["vltri"] = 8882,
  ["vartriangleleft"] = 8882,
  ["LeftTriangle"] = 8882,
  ["vrtri"] = 8883,
  ["vartriangleright"] = 8883,
  ["RightTriangle"] = 8883,
  ["ltrie"] = 8884,
  ["trianglelefteq"] = 8884,
  ["LeftTriangleEqual"] = 8884,
  ["rtrie"] = 8885,
  ["trianglerighteq"] = 8885,
  ["RightTriangleEqual"] = 8885,
  ["origof"] = 8886,
  ["imof"] = 8887,
  ["mumap"] = 8888,
  ["multimap"] = 8888,
  ["hercon"] = 8889,
  ["intcal"] = 8890,
  ["intercal"] = 8890,
  ["veebar"] = 8891,
  ["barvee"] = 8893,
  ["angrtvb"] = 8894,
  ["lrtri"] = 8895,
  ["xwedge"] = 8896,
  ["Wedge"] = 8896,
  ["bigwedge"] = 8896,
  ["xvee"] = 8897,
  ["Vee"] = 8897,
  ["bigvee"] = 8897,
  ["xcap"] = 8898,
  ["Intersection"] = 8898,
  ["bigcap"] = 8898,
  ["xcup"] = 8899,
  ["Union"] = 8899,
  ["bigcup"] = 8899,
  ["diam"] = 8900,
  ["diamond"] = 8900,
  ["Diamond"] = 8900,
  ["sdot"] = 8901,
  ["sstarf"] = 8902,
  ["Star"] = 8902,
  ["divonx"] = 8903,
  ["divideontimes"] = 8903,
  ["bowtie"] = 8904,
  ["ltimes"] = 8905,
  ["rtimes"] = 8906,
  ["lthree"] = 8907,
  ["leftthreetimes"] = 8907,
  ["rthree"] = 8908,
  ["rightthreetimes"] = 8908,
  ["bsime"] = 8909,
  ["backsimeq"] = 8909,
  ["cuvee"] = 8910,
  ["curlyvee"] = 8910,
  ["cuwed"] = 8911,
  ["curlywedge"] = 8911,
  ["Sub"] = 8912,
  ["Subset"] = 8912,
  ["Sup"] = 8913,
  ["Supset"] = 8913,
  ["Cap"] = 8914,
  ["Cup"] = 8915,
  ["fork"] = 8916,
  ["pitchfork"] = 8916,
  ["epar"] = 8917,
  ["ltdot"] = 8918,
  ["lessdot"] = 8918,
  ["gtdot"] = 8919,
  ["gtrdot"] = 8919,
  ["Ll"] = 8920,
  ["Gg"] = 8921,
  ["ggg"] = 8921,
  ["leg"] = 8922,
  ["LessEqualGreater"] = 8922,
  ["lesseqgtr"] = 8922,
  ["gel"] = 8923,
  ["gtreqless"] = 8923,
  ["GreaterEqualLess"] = 8923,
  ["cuepr"] = 8926,
  ["curlyeqprec"] = 8926,
  ["cuesc"] = 8927,
  ["curlyeqsucc"] = 8927,
  ["nprcue"] = 8928,
  ["NotPrecedesSlantEqual"] = 8928,
  ["nsccue"] = 8929,
  ["NotSucceedsSlantEqual"] = 8929,
  ["nsqsube"] = 8930,
  ["NotSquareSubsetEqual"] = 8930,
  ["nsqsupe"] = 8931,
  ["NotSquareSupersetEqual"] = 8931,
  ["lnsim"] = 8934,
  ["gnsim"] = 8935,
  ["prnsim"] = 8936,
  ["precnsim"] = 8936,
  ["scnsim"] = 8937,
  ["succnsim"] = 8937,
  ["nltri"] = 8938,
  ["ntriangleleft"] = 8938,
  ["NotLeftTriangle"] = 8938,
  ["nrtri"] = 8939,
  ["ntriangleright"] = 8939,
  ["NotRightTriangle"] = 8939,
  ["nltrie"] = 8940,
  ["ntrianglelefteq"] = 8940,
  ["NotLeftTriangleEqual"] = 8940,
  ["nrtrie"] = 8941,
  ["ntrianglerighteq"] = 8941,
  ["NotRightTriangleEqual"] = 8941,
  ["vellip"] = 8942,
  ["ctdot"] = 8943,
  ["utdot"] = 8944,
  ["dtdot"] = 8945,
  ["disin"] = 8946,
  ["isinsv"] = 8947,
  ["isins"] = 8948,
  ["isindot"] = 8949,
  ["notinvc"] = 8950,
  ["notinvb"] = 8951,
  ["isinE"] = 8953,
  ["nisd"] = 8954,
  ["xnis"] = 8955,
  ["nis"] = 8956,
  ["notnivc"] = 8957,
  ["notnivb"] = 8958,
  ["barwed"] = 8965,
  ["barwedge"] = 8965,
  ["Barwed"] = 8966,
  ["doublebarwedge"] = 8966,
  ["lceil"] = 8968,
  ["LeftCeiling"] = 8968,
  ["rceil"] = 8969,
  ["RightCeiling"] = 8969,
  ["lfloor"] = 8970,
  ["LeftFloor"] = 8970,
  ["rfloor"] = 8971,
  ["RightFloor"] = 8971,
  ["drcrop"] = 8972,
  ["dlcrop"] = 8973,
  ["urcrop"] = 8974,
  ["ulcrop"] = 8975,
  ["bnot"] = 8976,
  ["profline"] = 8978,
  ["profsurf"] = 8979,
  ["telrec"] = 8981,
  ["target"] = 8982,
  ["ulcorn"] = 8988,
  ["ulcorner"] = 8988,
  ["urcorn"] = 8989,
  ["urcorner"] = 8989,
  ["dlcorn"] = 8990,
  ["llcorner"] = 8990,
  ["drcorn"] = 8991,
  ["lrcorner"] = 8991,
  ["frown"] = 8994,
  ["sfrown"] = 8994,
  ["smile"] = 8995,
  ["ssmile"] = 8995,
  ["cylcty"] = 9005,
  ["profalar"] = 9006,
  ["topbot"] = 9014,
  ["ovbar"] = 9021,
  ["solbar"] = 9023,
  ["angzarr"] = 9084,
  ["lmoust"] = 9136,
  ["lmoustache"] = 9136,
  ["rmoust"] = 9137,
  ["rmoustache"] = 9137,
  ["tbrk"] = 9140,
  ["OverBracket"] = 9140,
  ["bbrk"] = 9141,
  ["UnderBracket"] = 9141,
  ["bbrktbrk"] = 9142,
  ["OverParenthesis"] = 9180,
  ["UnderParenthesis"] = 9181,
  ["OverBrace"] = 9182,
  ["UnderBrace"] = 9183,
  ["trpezium"] = 9186,
  ["elinters"] = 9191,
  ["blank"] = 9251,
  ["oS"] = 9416,
  ["circledS"] = 9416,
  ["boxh"] = 9472,
  ["HorizontalLine"] = 9472,
  ["boxv"] = 9474,
  ["boxdr"] = 9484,
  ["boxdl"] = 9488,
  ["boxur"] = 9492,
  ["boxul"] = 9496,
  ["boxvr"] = 9500,
  ["boxvl"] = 9508,
  ["boxhd"] = 9516,
  ["boxhu"] = 9524,
  ["boxvh"] = 9532,
  ["boxH"] = 9552,
  ["boxV"] = 9553,
  ["boxdR"] = 9554,
  ["boxDr"] = 9555,
  ["boxDR"] = 9556,
  ["boxdL"] = 9557,
  ["boxDl"] = 9558,
  ["boxDL"] = 9559,
  ["boxuR"] = 9560,
  ["boxUr"] = 9561,
  ["boxUR"] = 9562,
  ["boxuL"] = 9563,
  ["boxUl"] = 9564,
  ["boxUL"] = 9565,
  ["boxvR"] = 9566,
  ["boxVr"] = 9567,
  ["boxVR"] = 9568,
  ["boxvL"] = 9569,
  ["boxVl"] = 9570,
  ["boxVL"] = 9571,
  ["boxHd"] = 9572,
  ["boxhD"] = 9573,
  ["boxHD"] = 9574,
  ["boxHu"] = 9575,
  ["boxhU"] = 9576,
  ["boxHU"] = 9577,
  ["boxvH"] = 9578,
  ["boxVh"] = 9579,
  ["boxVH"] = 9580,
  ["uhblk"] = 9600,
  ["lhblk"] = 9604,
  ["block"] = 9608,
  ["blk14"] = 9617,
  ["blk12"] = 9618,
  ["blk34"] = 9619,
  ["squ"] = 9633,
  ["square"] = 9633,
  ["Square"] = 9633,
  ["squf"] = 9642,
  ["squarf"] = 9642,
  ["blacksquare"] = 9642,
  ["FilledVerySmallSquare"] = 9642,
  ["EmptyVerySmallSquare"] = 9643,
  ["rect"] = 9645,
  ["marker"] = 9646,
  ["fltns"] = 9649,
  ["xutri"] = 9651,
  ["bigtriangleup"] = 9651,
  ["utrif"] = 9652,
  ["blacktriangle"] = 9652,
  ["utri"] = 9653,
  ["triangle"] = 9653,
  ["rtrif"] = 9656,
  ["blacktriangleright"] = 9656,
  ["rtri"] = 9657,
  ["triangleright"] = 9657,
  ["xdtri"] = 9661,
  ["bigtriangledown"] = 9661,
  ["dtrif"] = 9662,
  ["blacktriangledown"] = 9662,
  ["dtri"] = 9663,
  ["triangledown"] = 9663,
  ["ltrif"] = 9666,
  ["blacktriangleleft"] = 9666,
  ["ltri"] = 9667,
  ["triangleleft"] = 9667,
  ["loz"] = 9674,
  ["lozenge"] = 9674,
  ["cir"] = 9675,
  ["tridot"] = 9708,
  ["xcirc"] = 9711,
  ["bigcirc"] = 9711,
  ["ultri"] = 9720,
  ["urtri"] = 9721,
  ["lltri"] = 9722,
  ["EmptySmallSquare"] = 9723,
  ["FilledSmallSquare"] = 9724,
  ["starf"] = 9733,
  ["bigstar"] = 9733,
  ["star"] = 9734,
  ["phone"] = 9742,
  ["female"] = 9792,
  ["male"] = 9794,
  ["spades"] = 9824,
  ["spadesuit"] = 9824,
  ["clubs"] = 9827,
  ["clubsuit"] = 9827,
  ["hearts"] = 9829,
  ["heartsuit"] = 9829,
  ["diams"] = 9830,
  ["diamondsuit"] = 9830,
  ["sung"] = 9834,
  ["flat"] = 9837,
  ["natur"] = 9838,
  ["natural"] = 9838,
  ["sharp"] = 9839,
  ["check"] = 10003,
  ["checkmark"] = 10003,
  ["cross"] = 10007,
  ["malt"] = 10016,
  ["maltese"] = 10016,
  ["sext"] = 10038,
  ["VerticalSeparator"] = 10072,
  ["lbbrk"] = 10098,
  ["rbbrk"] = 10099,
  ["lobrk"] = 10214,
  ["LeftDoubleBracket"] = 10214,
  ["robrk"] = 10215,
  ["RightDoubleBracket"] = 10215,
  ["lang"] = 10216,
  ["LeftAngleBracket"] = 10216,
  ["langle"] = 10216,
  ["rang"] = 10217,
  ["RightAngleBracket"] = 10217,
  ["rangle"] = 10217,
  ["Lang"] = 10218,
  ["Rang"] = 10219,
  ["loang"] = 10220,
  ["roang"] = 10221,
  ["xlarr"] = 10229,
  ["longleftarrow"] = 10229,
  ["LongLeftArrow"] = 10229,
  ["xrarr"] = 10230,
  ["longrightarrow"] = 10230,
  ["LongRightArrow"] = 10230,
  ["xharr"] = 10231,
  ["longleftrightarrow"] = 10231,
  ["LongLeftRightArrow"] = 10231,
  ["xlArr"] = 10232,
  ["Longleftarrow"] = 10232,
  ["DoubleLongLeftArrow"] = 10232,
  ["xrArr"] = 10233,
  ["Longrightarrow"] = 10233,
  ["DoubleLongRightArrow"] = 10233,
  ["xhArr"] = 10234,
  ["Longleftrightarrow"] = 10234,
  ["DoubleLongLeftRightArrow"] = 10234,
  ["xmap"] = 10236,
  ["longmapsto"] = 10236,
  ["dzigrarr"] = 10239,
  ["nvlArr"] = 10498,
  ["nvrArr"] = 10499,
  ["nvHarr"] = 10500,
  ["Map"] = 10501,
  ["lbarr"] = 10508,
  ["rbarr"] = 10509,
  ["bkarow"] = 10509,
  ["lBarr"] = 10510,
  ["rBarr"] = 10511,
  ["dbkarow"] = 10511,
  ["RBarr"] = 10512,
  ["drbkarow"] = 10512,
  ["DDotrahd"] = 10513,
  ["UpArrowBar"] = 10514,
  ["DownArrowBar"] = 10515,
  ["Rarrtl"] = 10518,
  ["latail"] = 10521,
  ["ratail"] = 10522,
  ["lAtail"] = 10523,
  ["rAtail"] = 10524,
  ["larrfs"] = 10525,
  ["rarrfs"] = 10526,
  ["larrbfs"] = 10527,
  ["rarrbfs"] = 10528,
  ["nwarhk"] = 10531,
  ["nearhk"] = 10532,
  ["searhk"] = 10533,
  ["hksearow"] = 10533,
  ["swarhk"] = 10534,
  ["hkswarow"] = 10534,
  ["nwnear"] = 10535,
  ["nesear"] = 10536,
  ["toea"] = 10536,
  ["seswar"] = 10537,
  ["tosa"] = 10537,
  ["swnwar"] = 10538,
  ["rarrc"] = 10547,
  ["cudarrr"] = 10549,
  ["ldca"] = 10550,
  ["rdca"] = 10551,
  ["cudarrl"] = 10552,
  ["larrpl"] = 10553,
  ["curarrm"] = 10556,
  ["cularrp"] = 10557,
  ["rarrpl"] = 10565,
  ["harrcir"] = 10568,
  ["Uarrocir"] = 10569,
  ["lurdshar"] = 10570,
  ["ldrushar"] = 10571,
  ["LeftRightVector"] = 10574,
  ["RightUpDownVector"] = 10575,
  ["DownLeftRightVector"] = 10576,
  ["LeftUpDownVector"] = 10577,
  ["LeftVectorBar"] = 10578,
  ["RightVectorBar"] = 10579,
  ["RightUpVectorBar"] = 10580,
  ["RightDownVectorBar"] = 10581,
  ["DownLeftVectorBar"] = 10582,
  ["DownRightVectorBar"] = 10583,
  ["LeftUpVectorBar"] = 10584,
  ["LeftDownVectorBar"] = 10585,
  ["LeftTeeVector"] = 10586,
  ["RightTeeVector"] = 10587,
  ["RightUpTeeVector"] = 10588,
  ["RightDownTeeVector"] = 10589,
  ["DownLeftTeeVector"] = 10590,
  ["DownRightTeeVector"] = 10591,
  ["LeftUpTeeVector"] = 10592,
  ["LeftDownTeeVector"] = 10593,
  ["lHar"] = 10594,
  ["uHar"] = 10595,
  ["rHar"] = 10596,
  ["dHar"] = 10597,
  ["luruhar"] = 10598,
  ["ldrdhar"] = 10599,
  ["ruluhar"] = 10600,
  ["rdldhar"] = 10601,
  ["lharul"] = 10602,
  ["llhard"] = 10603,
  ["rharul"] = 10604,
  ["lrhard"] = 10605,
  ["udhar"] = 10606,
  ["UpEquilibrium"] = 10606,
  ["duhar"] = 10607,
  ["ReverseUpEquilibrium"] = 10607,
  ["RoundImplies"] = 10608,
  ["erarr"] = 10609,
  ["simrarr"] = 10610,
  ["larrsim"] = 10611,
  ["rarrsim"] = 10612,
  ["rarrap"] = 10613,
  ["ltlarr"] = 10614,
  ["gtrarr"] = 10616,
  ["subrarr"] = 10617,
  ["suplarr"] = 10619,
  ["lfisht"] = 10620,
  ["rfisht"] = 10621,
  ["ufisht"] = 10622,
  ["dfisht"] = 10623,
  ["lopar"] = 10629,
  ["ropar"] = 10630,
  ["lbrke"] = 10635,
  ["rbrke"] = 10636,
  ["lbrkslu"] = 10637,
  ["rbrksld"] = 10638,
  ["lbrksld"] = 10639,
  ["rbrkslu"] = 10640,
  ["langd"] = 10641,
  ["rangd"] = 10642,
  ["lparlt"] = 10643,
  ["rpargt"] = 10644,
  ["gtlPar"] = 10645,
  ["ltrPar"] = 10646,
  ["vzigzag"] = 10650,
  ["vangrt"] = 10652,
  ["angrtvbd"] = 10653,
  ["ange"] = 10660,
  ["range"] = 10661,
  ["dwangle"] = 10662,
  ["uwangle"] = 10663,
  ["angmsdaa"] = 10664,
  ["angmsdab"] = 10665,
  ["angmsdac"] = 10666,
  ["angmsdad"] = 10667,
  ["angmsdae"] = 10668,
  ["angmsdaf"] = 10669,
  ["angmsdag"] = 10670,
  ["angmsdah"] = 10671,
  ["bemptyv"] = 10672,
  ["demptyv"] = 10673,
  ["cemptyv"] = 10674,
  ["raemptyv"] = 10675,
  ["laemptyv"] = 10676,
  ["ohbar"] = 10677,
  ["omid"] = 10678,
  ["opar"] = 10679,
  ["operp"] = 10681,
  ["olcross"] = 10683,
  ["odsold"] = 10684,
  ["olcir"] = 10686,
  ["ofcir"] = 10687,
  ["olt"] = 10688,
  ["ogt"] = 10689,
  ["cirscir"] = 10690,
  ["cirE"] = 10691,
  ["solb"] = 10692,
  ["bsolb"] = 10693,
  ["boxbox"] = 10697,
  ["trisb"] = 10701,
  ["rtriltri"] = 10702,
  ["LeftTriangleBar"] = 10703,
  ["RightTriangleBar"] = 10704,
  ["race"] = 10714,
  ["iinfin"] = 10716,
  ["infintie"] = 10717,
  ["nvinfin"] = 10718,
  ["eparsl"] = 10723,
  ["smeparsl"] = 10724,
  ["eqvparsl"] = 10725,
  ["lozf"] = 10731,
  ["blacklozenge"] = 10731,
  ["RuleDelayed"] = 10740,
  ["dsol"] = 10742,
  ["xodot"] = 10752,
  ["bigodot"] = 10752,
  ["xoplus"] = 10753,
  ["bigoplus"] = 10753,
  ["xotime"] = 10754,
  ["bigotimes"] = 10754,
  ["xuplus"] = 10756,
  ["biguplus"] = 10756,
  ["xsqcup"] = 10758,
  ["bigsqcup"] = 10758,
  ["qint"] = 10764,
  ["iiiint"] = 10764,
  ["fpartint"] = 10765,
  ["cirfnint"] = 10768,
  ["awint"] = 10769,
  ["rppolint"] = 10770,
  ["scpolint"] = 10771,
  ["npolint"] = 10772,
  ["pointint"] = 10773,
  ["quatint"] = 10774,
  ["intlarhk"] = 10775,
  ["pluscir"] = 10786,
  ["plusacir"] = 10787,
  ["simplus"] = 10788,
  ["plusdu"] = 10789,
  ["plussim"] = 10790,
  ["plustwo"] = 10791,
  ["mcomma"] = 10793,
  ["minusdu"] = 10794,
  ["loplus"] = 10797,
  ["roplus"] = 10798,
  ["Cross"] = 10799,
  ["timesd"] = 10800,
  ["timesbar"] = 10801,
  ["smashp"] = 10803,
  ["lotimes"] = 10804,
  ["rotimes"] = 10805,
  ["otimesas"] = 10806,
  ["Otimes"] = 10807,
  ["odiv"] = 10808,
  ["triplus"] = 10809,
  ["triminus"] = 10810,
  ["tritime"] = 10811,
  ["iprod"] = 10812,
  ["intprod"] = 10812,
  ["amalg"] = 10815,
  ["capdot"] = 10816,
  ["ncup"] = 10818,
  ["ncap"] = 10819,
  ["capand"] = 10820,
  ["cupor"] = 10821,
  ["cupcap"] = 10822,
  ["capcup"] = 10823,
  ["cupbrcap"] = 10824,
  ["capbrcup"] = 10825,
  ["cupcup"] = 10826,
  ["capcap"] = 10827,
  ["ccups"] = 10828,
  ["ccaps"] = 10829,
  ["ccupssm"] = 10832,
  ["And"] = 10835,
  ["Or"] = 10836,
  ["andand"] = 10837,
  ["oror"] = 10838,
  ["orslope"] = 10839,
  ["andslope"] = 10840,
  ["andv"] = 10842,
  ["orv"] = 10843,
  ["andd"] = 10844,
  ["ord"] = 10845,
  ["wedbar"] = 10847,
  ["sdote"] = 10854,
  ["simdot"] = 10858,
  ["congdot"] = 10861,
  ["easter"] = 10862,
  ["apacir"] = 10863,
  ["apE"] = 10864,
  ["eplus"] = 10865,
  ["pluse"] = 10866,
  ["Esim"] = 10867,
  ["Colone"] = 10868,
  ["Equal"] = 10869,
  ["eDDot"] = 10871,
  ["ddotseq"] = 10871,
  ["equivDD"] = 10872,
  ["ltcir"] = 10873,
  ["gtcir"] = 10874,
  ["ltquest"] = 10875,
  ["gtquest"] = 10876,
  ["les"] = 10877,
  ["LessSlantEqual"] = 10877,
  ["leqslant"] = 10877,
  ["ges"] = 10878,
  ["GreaterSlantEqual"] = 10878,
  ["geqslant"] = 10878,
  ["lesdot"] = 10879,
  ["gesdot"] = 10880,
  ["lesdoto"] = 10881,
  ["gesdoto"] = 10882,
  ["lesdotor"] = 10883,
  ["gesdotol"] = 10884,
  ["lap"] = 10885,
  ["lessapprox"] = 10885,
  ["gap"] = 10886,
  ["gtrapprox"] = 10886,
  ["lne"] = 10887,
  ["lneq"] = 10887,
  ["gne"] = 10888,
  ["gneq"] = 10888,
  ["lnap"] = 10889,
  ["lnapprox"] = 10889,
  ["gnap"] = 10890,
  ["gnapprox"] = 10890,
  ["lEg"] = 10891,
  ["lesseqqgtr"] = 10891,
  ["gEl"] = 10892,
  ["gtreqqless"] = 10892,
  ["lsime"] = 10893,
  ["gsime"] = 10894,
  ["lsimg"] = 10895,
  ["gsiml"] = 10896,
  ["lgE"] = 10897,
  ["glE"] = 10898,
  ["lesges"] = 10899,
  ["gesles"] = 10900,
  ["els"] = 10901,
  ["eqslantless"] = 10901,
  ["egs"] = 10902,
  ["eqslantgtr"] = 10902,
  ["elsdot"] = 10903,
  ["egsdot"] = 10904,
  ["el"] = 10905,
  ["eg"] = 10906,
  ["siml"] = 10909,
  ["simg"] = 10910,
  ["simlE"] = 10911,
  ["simgE"] = 10912,
  ["LessLess"] = 10913,
  ["GreaterGreater"] = 10914,
  ["glj"] = 10916,
  ["gla"] = 10917,
  ["ltcc"] = 10918,
  ["gtcc"] = 10919,
  ["lescc"] = 10920,
  ["gescc"] = 10921,
  ["smt"] = 10922,
  ["lat"] = 10923,
  ["smte"] = 10924,
  ["late"] = 10925,
  ["bumpE"] = 10926,
  ["pre"] = 10927,
  ["preceq"] = 10927,
  ["PrecedesEqual"] = 10927,
  ["sce"] = 10928,
  ["succeq"] = 10928,
  ["SucceedsEqual"] = 10928,
  ["prE"] = 10931,
  ["scE"] = 10932,
  ["prnE"] = 10933,
  ["precneqq"] = 10933,
  ["scnE"] = 10934,
  ["succneqq"] = 10934,
  ["prap"] = 10935,
  ["precapprox"] = 10935,
  ["scap"] = 10936,
  ["succapprox"] = 10936,
  ["prnap"] = 10937,
  ["precnapprox"] = 10937,
  ["scnap"] = 10938,
  ["succnapprox"] = 10938,
  ["Pr"] = 10939,
  ["Sc"] = 10940,
  ["subdot"] = 10941,
  ["supdot"] = 10942,
  ["subplus"] = 10943,
  ["supplus"] = 10944,
  ["submult"] = 10945,
  ["supmult"] = 10946,
  ["subedot"] = 10947,
  ["supedot"] = 10948,
  ["subE"] = 10949,
  ["subseteqq"] = 10949,
  ["supE"] = 10950,
  ["supseteqq"] = 10950,
  ["subsim"] = 10951,
  ["supsim"] = 10952,
  ["subnE"] = 10955,
  ["subsetneqq"] = 10955,
  ["supnE"] = 10956,
  ["supsetneqq"] = 10956,
  ["csub"] = 10959,
  ["csup"] = 10960,
  ["csube"] = 10961,
  ["csupe"] = 10962,
  ["subsup"] = 10963,
  ["supsub"] = 10964,
  ["subsub"] = 10965,
  ["supsup"] = 10966,
  ["suphsub"] = 10967,
  ["supdsub"] = 10968,
  ["forkv"] = 10969,
  ["topfork"] = 10970,
  ["mlcp"] = 10971,
  ["Dashv"] = 10980,
  ["DoubleLeftTee"] = 10980,
  ["Vdashl"] = 10982,
  ["Barv"] = 10983,
  ["vBar"] = 10984,
  ["vBarv"] = 10985,
  ["Vbar"] = 10987,
  ["Not"] = 10988,
  ["bNot"] = 10989,
  ["rnmid"] = 10990,
  ["cirmid"] = 10991,
  ["midcir"] = 10992,
  ["topcir"] = 10993,
  ["nhpar"] = 10994,
  ["parsim"] = 10995,
  ["parsl"] = 11005,
  ["fflig"] = 64256,
  ["filig"] = 64257,
  ["fllig"] = 64258,
  ["ffilig"] = 64259,
  ["ffllig"] = 64260,
  ["Ascr"] = 119964,
  ["Cscr"] = 119966,
  ["Dscr"] = 119967,
  ["Gscr"] = 119970,
  ["Jscr"] = 119973,
  ["Kscr"] = 119974,
  ["Nscr"] = 119977,
  ["Oscr"] = 119978,
  ["Pscr"] = 119979,
  ["Qscr"] = 119980,
  ["Sscr"] = 119982,
  ["Tscr"] = 119983,
  ["Uscr"] = 119984,
  ["Vscr"] = 119985,
  ["Wscr"] = 119986,
  ["Xscr"] = 119987,
  ["Yscr"] = 119988,
  ["Zscr"] = 119989,
  ["ascr"] = 119990,
  ["bscr"] = 119991,
  ["cscr"] = 119992,
  ["dscr"] = 119993,
  ["fscr"] = 119995,
  ["hscr"] = 119997,
  ["iscr"] = 119998,
  ["jscr"] = 119999,
  ["kscr"] = 120000,
  ["lscr"] = 120001,
  ["mscr"] = 120002,
  ["nscr"] = 120003,
  ["pscr"] = 120005,
  ["qscr"] = 120006,
  ["rscr"] = 120007,
  ["sscr"] = 120008,
  ["tscr"] = 120009,
  ["uscr"] = 120010,
  ["vscr"] = 120011,
  ["wscr"] = 120012,
  ["xscr"] = 120013,
  ["yscr"] = 120014,
  ["zscr"] = 120015,
  ["Afr"] = 120068,
  ["Bfr"] = 120069,
  ["Dfr"] = 120071,
  ["Efr"] = 120072,
  ["Ffr"] = 120073,
  ["Gfr"] = 120074,
  ["Jfr"] = 120077,
  ["Kfr"] = 120078,
  ["Lfr"] = 120079,
  ["Mfr"] = 120080,
  ["Nfr"] = 120081,
  ["Ofr"] = 120082,
  ["Pfr"] = 120083,
  ["Qfr"] = 120084,
  ["Sfr"] = 120086,
  ["Tfr"] = 120087,
  ["Ufr"] = 120088,
  ["Vfr"] = 120089,
  ["Wfr"] = 120090,
  ["Xfr"] = 120091,
  ["Yfr"] = 120092,
  ["afr"] = 120094,
  ["bfr"] = 120095,
  ["cfr"] = 120096,
  ["dfr"] = 120097,
  ["efr"] = 120098,
  ["ffr"] = 120099,
  ["gfr"] = 120100,
  ["hfr"] = 120101,
  ["ifr"] = 120102,
  ["jfr"] = 120103,
  ["kfr"] = 120104,
  ["lfr"] = 120105,
  ["mfr"] = 120106,
  ["nfr"] = 120107,
  ["ofr"] = 120108,
  ["pfr"] = 120109,
  ["qfr"] = 120110,
  ["rfr"] = 120111,
  ["sfr"] = 120112,
  ["tfr"] = 120113,
  ["ufr"] = 120114,
  ["vfr"] = 120115,
  ["wfr"] = 120116,
  ["xfr"] = 120117,
  ["yfr"] = 120118,
  ["zfr"] = 120119,
  ["Aopf"] = 120120,
  ["Bopf"] = 120121,
  ["Dopf"] = 120123,
  ["Eopf"] = 120124,
  ["Fopf"] = 120125,
  ["Gopf"] = 120126,
  ["Iopf"] = 120128,
  ["Jopf"] = 120129,
  ["Kopf"] = 120130,
  ["Lopf"] = 120131,
  ["Mopf"] = 120132,
  ["Oopf"] = 120134,
  ["Sopf"] = 120138,
  ["Topf"] = 120139,
  ["Uopf"] = 120140,
  ["Vopf"] = 120141,
  ["Wopf"] = 120142,
  ["Xopf"] = 120143,
  ["Yopf"] = 120144,
  ["aopf"] = 120146,
  ["bopf"] = 120147,
  ["copf"] = 120148,
  ["dopf"] = 120149,
  ["eopf"] = 120150,
  ["fopf"] = 120151,
  ["gopf"] = 120152,
  ["hopf"] = 120153,
  ["iopf"] = 120154,
  ["jopf"] = 120155,
  ["kopf"] = 120156,
  ["lopf"] = 120157,
  ["mopf"] = 120158,
  ["nopf"] = 120159,
  ["oopf"] = 120160,
  ["popf"] = 120161,
  ["qopf"] = 120162,
  ["ropf"] = 120163,
  ["sopf"] = 120164,
  ["topf"] = 120165,
  ["uopf"] = 120166,
  ["vopf"] = 120167,
  ["wopf"] = 120168,
  ["xopf"] = 120169,
  ["yopf"] = 120170,
  ["zopf"] = 120171,
}
function entities.dec_entity(s)
  return unicode.utf8.char(tonumber(s))
end
function entities.hex_entity(s)
  return unicode.utf8.char(tonumber("0x"..s))
end
function entities.char_entity(s)
  local n = character_entities[s]
  if n == nil then
    return "&" .. s .. ";"
  end
  return unicode.utf8.char(n)
end
M.writer = {}
function M.writer.new(options)
  local self = {}
  self.options = options
  local slice_specifiers = {}
  for specifier in options.slice:gmatch("[^%s]+") do
    table.insert(slice_specifiers, specifier)
  end

  if #slice_specifiers == 2 then
    self.slice_begin, self.slice_end = table.unpack(slice_specifiers)
    local slice_begin_type = self.slice_begin:sub(1, 1)
    if slice_begin_type ~= "^" and slice_begin_type ~= "$" then
      self.slice_begin = "^" .. self.slice_begin
    end
    local slice_end_type = self.slice_end:sub(1, 1)
    if slice_end_type ~= "^" and slice_end_type ~= "$" then
      self.slice_end = "$" .. self.slice_end
    end
  elseif #slice_specifiers == 1 then
    self.slice_begin = "^" .. slice_specifiers[1]
    self.slice_end = "$" .. slice_specifiers[1]
  end

  self.slice_begin_type = self.slice_begin:sub(1, 1)
  self.slice_begin_identifier = self.slice_begin:sub(2) or ""
  self.slice_end_type = self.slice_end:sub(1, 1)
  self.slice_end_identifier = self.slice_end:sub(2) or ""

  if self.slice_begin == "^" and self.slice_end ~= "^" then
    self.is_writing = true
  else
    self.is_writing = false
  end
  self.suffix = ".tex"
  self.space = " "
  self.nbsp = "\\markdownRendererNbsp{}"
  function self.plain(s)
    return s
  end
  function self.paragraph(s)
    if not self.is_writing then return "" end
    return s
  end
  function self.pack(name)
    return [[\input{]] .. name .. [[}\relax]]
  end
  function self.interblocksep()
    if not self.is_writing then return "" end
    return "\\markdownRendererInterblockSeparator\n{}"
  end
  self.hard_line_break = "\\markdownRendererHardLineBreak\n{}"
  self.ellipsis = "\\markdownRendererEllipsis{}"
  function self.thematic_break()
    if not self.is_writing then return "" end
    return "\\markdownRendererThematicBreak{}"
  end
  self.escaped_uri_chars = {
    ["{"] = "\\markdownRendererLeftBrace{}",
    ["}"] = "\\markdownRendererRightBrace{}",
    ["\\"] = "\\markdownRendererBackslash{}",
  }
  self.escaped_minimal_strings = {
    ["^^"] = "\\markdownRendererCircumflex\\markdownRendererCircumflex ",
    ["☒"] = "\\markdownRendererTickedBox{}",
    ["⌛"] = "\\markdownRendererHalfTickedBox{}",
    ["☐"] = "\\markdownRendererUntickedBox{}",
    [entities.hex_entity('FFFD')] = "\\markdownRendererReplacementCharacter{}",
  }
  self.escaped_strings = util.table_copy(self.escaped_minimal_strings)
  self.escaped_strings[entities.hex_entity('00A0')] = self.nbsp
  self.escaped_chars = {
    ["{"] = "\\markdownRendererLeftBrace{}",
    ["}"] = "\\markdownRendererRightBrace{}",
    ["%"] = "\\markdownRendererPercentSign{}",
    ["\\"] = "\\markdownRendererBackslash{}",
    ["#"] = "\\markdownRendererHash{}",
    ["$"] = "\\markdownRendererDollarSign{}",
    ["&"] = "\\markdownRendererAmpersand{}",
    ["_"] = "\\markdownRendererUnderscore{}",
    ["^"] = "\\markdownRendererCircumflex{}",
    ["~"] = "\\markdownRendererTilde{}",
    ["|"] = "\\markdownRendererPipe{}",
    [entities.hex_entity('0000')] = "\\markdownRendererReplacementCharacter{}",
  }
  local escape_typographic_text = util.escaper(
    self.escaped_chars, self.escaped_strings)
  local escape_programmatic_text = util.escaper(
    self.escaped_uri_chars, self.escaped_minimal_strings)
  local escape_minimal = util.escaper(
    {}, self.escaped_minimal_strings)
  self.escape = escape_typographic_text
  self.math = escape_minimal
  if options.hybrid then
    self.identifier = escape_minimal
    self.string = escape_minimal
    self.uri = escape_minimal
  else
    self.identifier = escape_programmatic_text
    self.string = escape_typographic_text
    self.uri = escape_programmatic_text
  end
  function self.code(s, attributes)
    local buf = {}
    if attributes ~= nil then
      table.insert(buf,
                   "\\markdownRendererCodeSpanAttributeContextBegin\n")
      table.insert(buf, self.attributes(attributes))
    end
    table.insert(buf,
                 {"\\markdownRendererCodeSpan{", self.escape(s), "}"})
    if attributes ~= nil then
      table.insert(buf,
                   "\\markdownRendererCodeSpanAttributeContextEnd{}")
    end
    return buf
  end
  function self.link(lab, src, tit, attributes)
    local buf = {}
    if attributes ~= nil then
      table.insert(buf,
                   "\\markdownRendererLinkAttributeContextBegin\n")
      table.insert(buf, self.attributes(attributes))
    end
    table.insert(buf, {"\\markdownRendererLink{",lab,"}",
                       "{",self.escape(src),"}",
                       "{",self.uri(src),"}",
                       "{",self.string(tit or ""),"}"})
    if attributes ~= nil then
      table.insert(buf,
                   "\\markdownRendererLinkAttributeContextEnd{}")
    end
    return buf
  end
  function self.image(lab, src, tit, attributes)
    local buf = {}
    if attributes ~= nil then
      table.insert(buf,
                   "\\markdownRendererImageAttributeContextBegin\n")
      table.insert(buf, self.attributes(attributes))
    end
    table.insert(buf, {"\\markdownRendererImage{",lab,"}",
                       "{",self.string(src),"}",
                       "{",self.uri(src),"}",
                       "{",self.string(tit or ""),"}"})
    if attributes ~= nil then
      table.insert(buf,
                   "\\markdownRendererImageAttributeContextEnd{}")
    end
    return buf
  end
  function self.bulletlist(items,tight)
    if not self.is_writing then return "" end
    local buffer = {}
    for _,item in ipairs(items) do
      buffer[#buffer + 1] = self.bulletitem(item)
    end
    local contents = util.intersperse(buffer,"\n")
    if tight and options.tightLists then
      return {"\\markdownRendererUlBeginTight\n",contents,
        "\n\\markdownRendererUlEndTight "}
    else
      return {"\\markdownRendererUlBegin\n",contents,
        "\n\\markdownRendererUlEnd "}
    end
  end
  function self.bulletitem(s)
    return {"\\markdownRendererUlItem ",s,
            "\\markdownRendererUlItemEnd "}
  end
  function self.orderedlist(items,tight,startnum)
    if not self.is_writing then return "" end
    local buffer = {}
    local num = startnum
    for _,item in ipairs(items) do
      buffer[#buffer + 1] = self.ordereditem(item,num)
      if num ~= nil then
        num = num + 1
      end
    end
    local contents = util.intersperse(buffer,"\n")
    if tight and options.tightLists then
      return {"\\markdownRendererOlBeginTight\n",contents,
              "\n\\markdownRendererOlEndTight "}
    else
      return {"\\markdownRendererOlBegin\n",contents,
              "\n\\markdownRendererOlEnd "}
    end
  end
  function self.ordereditem(s,num)
    if num ~= nil then
      return {"\\markdownRendererOlItemWithNumber{",num,"}",s,
              "\\markdownRendererOlItemEnd "}
    else
      return {"\\markdownRendererOlItem ",s,
              "\\markdownRendererOlItemEnd "}
    end
  end
  function self.inline_html_comment(contents)
    return {"\\markdownRendererInlineHtmlComment{",contents,"}"}
  end
  function self.block_html_comment(contents)
    if not self.is_writing then return "" end
    return {"\\markdownRendererBlockHtmlCommentBegin\n",contents,
            "\n\\markdownRendererBlockHtmlCommentEnd "}
  end
  function self.inline_html_tag(contents)
    return {"\\markdownRendererInlineHtmlTag{",self.string(contents),"}"}
  end
  function self.block_html_element(s)
    if not self.is_writing then return "" end
    local name = util.cache(options.cacheDir, s, nil, nil, ".verbatim")
    return {"\\markdownRendererInputBlockHtmlElement{",name,"}"}
  end
  function self.emphasis(s)
    return {"\\markdownRendererEmphasis{",s,"}"}
  end
  function self.tickbox(f)
    if f == 1.0 then
      return "☒ "
    elseif f == 0.0 then
      return "☐ "
    else
      return "⌛ "
    end
  end
  function self.strong(s)
    return {"\\markdownRendererStrongEmphasis{",s,"}"}
  end
  function self.blockquote(s)
    if #util.rope_to_string(s) == 0 then return "" end
    return {"\\markdownRendererBlockQuoteBegin\n",s,
      "\n\\markdownRendererBlockQuoteEnd "}
  end
  function self.verbatim(s)
    if not self.is_writing then return "" end
    s = s:gsub("\n$", "")
    local name = util.cache_verbatim(options.cacheDir, s)
    return {"\\markdownRendererInputVerbatim{",name,"}"}
  end
  function self.document(d)
    local buf = {"\\markdownRendererDocumentBegin\n", d}

    -- pop all attributes
    table.insert(buf, self.pop_attributes())

    table.insert(buf, "\\markdownRendererDocumentEnd")

    return buf
  end
  function self.attributes(attributes)
    local expanded_attributes = {}
    local key_value_regex = "([^= ]+)%s*=%s*(.*)"
    local key, value
    for _, attribute in ipairs(attributes) do
      if attribute:sub(1, 1) == "#" or attribute:sub(1, 1) == "." then
        table.insert(expanded_attributes, attribute)
      else
        key, value = attribute:match(key_value_regex)
        if key:lower() == "id" then
          table.insert(expanded_attributes, "#" .. value)
        elseif key:lower() == "class" then
          local classes = {}
          for class in value:gmatch("%S+") do
            table.insert(classes, class)
          end
          table.sort(classes)
          for _, class in ipairs(classes) do
            table.insert(expanded_attributes, "." .. class)
          end
        else
          table.insert(expanded_attributes, attribute)
        end
      end
    end
    table.sort(expanded_attributes)

    local buf = {}
    local seen = {}
    for _, attribute in ipairs(expanded_attributes) do
      if seen[attribute] ~= nil then
        goto continue  -- prevent duplicate attributes
      else
        seen[attribute] = true
      end
      if attribute:sub(1, 1) == "#" then
        table.insert(buf, {"\\markdownRendererAttributeIdentifier{",
                           attribute:sub(2), "}"})
      elseif attribute:sub(1, 1) == "." then
        table.insert(buf, {"\\markdownRendererAttributeClassName{",
                           attribute:sub(2), "}"})
      else
        key, value = attribute:match(key_value_regex)
        table.insert(buf, {"\\markdownRendererAttributeKeyValue{",
                           key, "}{", value, "}"})
      end
      ::continue::
    end

    return buf
  end
  self.active_attributes = {}
  local function apply_attributes()
    local buf = {}
    for i = 1, #self.active_attributes do
      local start_output = self.active_attributes[i][3]
      if start_output ~= nil then
        table.insert(buf, start_output)
      end
    end
    return buf
  end

  local function tear_down_attributes()
    local buf = {}
    for i = #self.active_attributes, 1, -1 do
      local end_output = self.active_attributes[i][4]
      if end_output ~= nil then
        table.insert(buf, end_output)
      end
    end
    return buf
  end
  function self.push_attributes(attribute_type, attributes,
                                start_output, end_output)
    -- index attributes in a hash table for easy lookup
    attributes = attributes or {}
    for i = 1, #attributes do
      attributes[attributes[i]] = true
    end

    local buf = {}
    -- handle slicing
    if attributes["#" .. self.slice_end_identifier] ~= nil and
       self.slice_end_type == "^" then
      if self.is_writing then
        table.insert(buf, tear_down_attributes())
      end
      self.is_writing = false
    end
    if attributes["#" .. self.slice_begin_identifier] ~= nil and
       self.slice_begin_type == "^" then
      self.is_writing = true
      table.insert(buf, apply_attributes())
      self.is_writing = true
    end
    if self.is_writing and start_output ~= nil then
      table.insert(buf, start_output)
    end
    table.insert(self.active_attributes,
                 {attribute_type, attributes,
                  start_output, end_output})
    return buf
  end

  function self.pop_attributes(attribute_type)
    local buf = {}
    -- pop attributes until we find attributes of correct type
    -- or until no attributes remain
    local current_attribute_type = false
    while current_attribute_type ~= attribute_type and
          #self.active_attributes > 0 do
      local attributes, _, end_output
      current_attribute_type, attributes, _, end_output = table.unpack(
        self.active_attributes[#self.active_attributes])
      if self.is_writing and end_output ~= nil then
        table.insert(buf, end_output)
      end
      table.remove(self.active_attributes, #self.active_attributes)
      -- handle slicing
      if attributes["#" .. self.slice_end_identifier] ~= nil
         and self.slice_end_type == "$" then
        if self.is_writing then
          table.insert(buf, tear_down_attributes())
        end
        self.is_writing = false
      end
      if attributes["#" .. self.slice_begin_identifier] ~= nil and
         self.slice_begin_type == "$" then
        self.is_writing = true
        table.insert(buf, apply_attributes())
      end
    end
    return buf
  end
  local current_heading_level = 0
  function self.heading(s, level, attributes)
    local buf = {}

    -- push empty attributes for implied sections
    while current_heading_level < level - 1 do
      table.insert(buf,
                   self.push_attributes("heading",
                                        nil,
                                        "\\markdownRendererSectionBegin\n",
                                        "\n\\markdownRendererSectionEnd "))
      current_heading_level = current_heading_level + 1
    end

    -- pop attributes for sections that have ended
    while current_heading_level >= level do
      table.insert(buf, self.pop_attributes("heading"))
      current_heading_level = current_heading_level - 1
    end

    -- push attributes for the new section
    local start_output = {}
    local end_output = {}
    table.insert(start_output, "\\markdownRendererSectionBegin\n")
    if options.headerAttributes and attributes ~= nil and #attributes > 0 then
      table.insert(start_output,
                   "\\markdownRendererHeaderAttributeContextBegin\n")
      table.insert(start_output, self.attributes(attributes))
      table.insert(end_output,
                   "\n\\markdownRendererHeaderAttributeContextEnd ")
    end
    table.insert(end_output, "\n\\markdownRendererSectionEnd ")

    table.insert(buf, self.push_attributes("heading",
                                           attributes,
                                           start_output,
                                           end_output))
    current_heading_level = current_heading_level + 1
    assert(current_heading_level == level)

    -- produce the renderer
    local cmd
    level = level + options.shiftHeadings
    if level <= 1 then
      cmd = "\\markdownRendererHeadingOne"
    elseif level == 2 then
      cmd = "\\markdownRendererHeadingTwo"
    elseif level == 3 then
      cmd = "\\markdownRendererHeadingThree"
    elseif level == 4 then
      cmd = "\\markdownRendererHeadingFour"
    elseif level == 5 then
      cmd = "\\markdownRendererHeadingFive"
    elseif level >= 6 then
      cmd = "\\markdownRendererHeadingSix"
    else
      cmd = ""
    end
    if self.is_writing then
      table.insert(buf, {cmd, "{", s, "}"})
    end

    return buf
  end
  function self.get_state()
    return {
      is_writing=self.is_writing,
      active_attributes={table.unpack(self.active_attributes)},
    }
  end
  function self.set_state(s)
    local previous_state = self.get_state()
    for key, value in pairs(s) do
      self[key] = value
    end
    return previous_state
  end
  function self.defer_call(f)
    local previous_state = self.get_state()
    return function(...)
      local state = self.set_state(previous_state)
      local return_value = f(...)
      self.set_state(state)
      return return_value
    end
  end

  return self
end
local parsers                  = {}
parsers.percent                = P("%")
parsers.at                     = P("@")
parsers.comma                  = P(",")
parsers.asterisk               = P("*")
parsers.dash                   = P("-")
parsers.plus                   = P("+")
parsers.underscore             = P("_")
parsers.period                 = P(".")
parsers.hash                   = P("#")
parsers.dollar                 = P("$")
parsers.ampersand              = P("&")
parsers.backtick               = P("`")
parsers.less                   = P("<")
parsers.more                   = P(">")
parsers.space                  = P(" ")
parsers.squote                 = P("'")
parsers.dquote                 = P('"')
parsers.lparent                = P("(")
parsers.rparent                = P(")")
parsers.lbracket               = P("[")
parsers.rbracket               = P("]")
parsers.lbrace                 = P("{")
parsers.rbrace                 = P("}")
parsers.circumflex             = P("^")
parsers.slash                  = P("/")
parsers.equal                  = P("=")
parsers.colon                  = P(":")
parsers.semicolon              = P(";")
parsers.exclamation            = P("!")
parsers.pipe                   = P("|")
parsers.tilde                  = P("~")
parsers.backslash              = P("\\")
parsers.tab                    = P("\t")
parsers.newline                = P("\n")
parsers.tightblocksep          = P("\001")

parsers.digit                  = R("09")
parsers.hexdigit               = R("09","af","AF")
parsers.letter                 = R("AZ","az")
parsers.alphanumeric           = R("AZ","az","09")
parsers.keyword                = parsers.letter
                               * parsers.alphanumeric^0
parsers.internal_punctuation   = S(":;,.?")

parsers.doubleasterisks        = P("**")
parsers.doubleunderscores      = P("__")
parsers.doubletildes           = P("~~")
parsers.fourspaces             = P("    ")

parsers.any                    = P(1)
parsers.succeed                = P(true)
parsers.fail                   = P(false)

parsers.escapable              = S("!\"#$%&'()*+,-./:;<=>?@[\\]^_`{|}~")
parsers.anyescaped             = parsers.backslash / "" * parsers.escapable
                               + parsers.any

parsers.spacechar              = S("\t ")
parsers.spacing                = S(" \n\r\t")
parsers.nonspacechar           = parsers.any - parsers.spacing
parsers.optionalspace          = parsers.spacechar^0

parsers.normalchar             = parsers.any - (V("SpecialChar")
                                                + parsers.spacing
                                                + parsers.tightblocksep)
parsers.eof                    = -parsers.any
parsers.nonindentspace         = parsers.space^-3 * - parsers.spacechar
parsers.indent                 = parsers.space^-3 * parsers.tab
                               + parsers.fourspaces / ""
parsers.linechar               = P(1 - parsers.newline)

parsers.blankline              = parsers.optionalspace
                               * parsers.newline / "\n"
parsers.blanklines             = parsers.blankline^0
parsers.skipblanklines         = (parsers.optionalspace * parsers.newline)^0
parsers.indentedline           = parsers.indent    /""
                               * C(parsers.linechar^1 * parsers.newline^-1)
parsers.optionallyindentedline = parsers.indent^-1 /""
                               * C(parsers.linechar^1 * parsers.newline^-1)
parsers.sp                     = parsers.spacing^0
parsers.spnl                   = parsers.optionalspace
                               * (parsers.newline * parsers.optionalspace)^-1
parsers.line                   = parsers.linechar^0 * parsers.newline
parsers.nonemptyline           = parsers.line - parsers.blankline
parsers.commented_line_letter  = parsers.linechar
                               + parsers.newline
                               - parsers.backslash
                               - parsers.percent
parsers.commented_line         = Cg(Cc(""), "backslashes")
                               * ((#(parsers.commented_line_letter
                                    - parsers.newline)
                                  * Cb("backslashes")
                                  * Cs(parsers.commented_line_letter
                                    - parsers.newline)^1  -- initial
                                  * Cg(Cc(""), "backslashes"))
                                 + #(parsers.backslash * parsers.backslash)
                                 * Cg((parsers.backslash  -- even backslash
                                      * parsers.backslash)^1, "backslashes")
                                 + (parsers.backslash
                                   * (#parsers.percent
                                     * Cb("backslashes")
                                     / function(backslashes)
                                       return string.rep("\\", #backslashes / 2)
                                     end
                                     * C(parsers.percent)
                                     + #parsers.commented_line_letter
                                     * Cb("backslashes")
                                     * Cc("\\")
                                     * C(parsers.commented_line_letter))
                                   * Cg(Cc(""), "backslashes")))^0
                               * (#parsers.percent
                                 * Cb("backslashes")
                                 / function(backslashes)
                                   return string.rep("\\", #backslashes / 2)
                                 end
                                 * ((parsers.percent  -- comment
                                    * parsers.line
                                    * #parsers.blankline) -- blank line
                                   / "\n"
                                   + parsers.percent  -- comment
                                   * parsers.line
                                   * parsers.optionalspace)  -- leading tabs and spaces
                                 + #(parsers.newline)
                                 * Cb("backslashes")
                                 * C(parsers.newline))

parsers.chunk                  = parsers.line * (parsers.optionallyindentedline
                                                - parsers.blankline)^0

parsers.attribute_key_char     = parsers.alphanumeric + S("-_:.")
parsers.attribute_key          = (parsers.attribute_key_char
                                 - parsers.dash - parsers.digit)
                               * parsers.attribute_key_char^0
parsers.attribute_value        = ( (parsers.dquote / "")
                                 * (parsers.anyescaped - parsers.dquote)^0
                                 * (parsers.dquote / ""))
                               + ( (parsers.squote / "")
                                 * (parsers.anyescaped - parsers.squote)^0
                                 * (parsers.squote / ""))
                               + ( parsers.anyescaped - parsers.dquote - parsers.rbrace
                                 - parsers.space)^0

parsers.attribute = (parsers.dash * Cc(".unnumbered"))
                  + C((parsers.hash + parsers.period)
                     * parsers.attribute_key)
                  + Cs( parsers.attribute_key
                      * parsers.optionalspace * parsers.equal * parsers.optionalspace
                      * parsers.attribute_value)
parsers.attributes = parsers.lbrace
                   * parsers.optionalspace
                   * parsers.attribute
                   * (parsers.spacechar^1
                     * parsers.attribute)^0
                   * parsers.optionalspace
                   * parsers.rbrace

parsers.raw_attribute = parsers.lbrace
                      * parsers.optionalspace
                      * parsers.equal
                      * C(parsers.attribute_key)
                      * parsers.optionalspace
                      * parsers.rbrace

-- block followed by 0 or more optionally
-- indented blocks with first line indented.
parsers.indented_blocks = function(bl)
  return Cs( bl
         * (parsers.blankline^1 * parsers.indent * -parsers.blankline * bl)^0
         * (parsers.blankline^1 + parsers.eof) )
end
parsers.bulletchar = C(parsers.plus + parsers.asterisk + parsers.dash)

parsers.bullet = ( parsers.bulletchar * #parsers.spacing
                                      * (parsers.tab + parsers.space^-3)
                 + parsers.space * parsers.bulletchar * #parsers.spacing
                                 * (parsers.tab + parsers.space^-2)
                 + parsers.space * parsers.space * parsers.bulletchar
                                 * #parsers.spacing
                                 * (parsers.tab + parsers.space^-1)
                 + parsers.space * parsers.space * parsers.space
                                 * parsers.bulletchar * #parsers.spacing
                 )

local function tickbox(interior)
  return parsers.optionalspace * parsers.lbracket
       * interior * parsers.rbracket * parsers.spacechar^1
end

parsers.ticked_box = tickbox(S("xX")) * Cc(1.0)
parsers.halfticked_box = tickbox(S("./")) * Cc(0.5)
parsers.unticked_box = tickbox(parsers.spacechar^1) * Cc(0.0)

parsers.openticks   = Cg(parsers.backtick^1, "ticks")

local function captures_equal_length(_,i,a,b)
  return #a == #b and i
end

parsers.closeticks  = parsers.space^-1
                    * Cmt(C(parsers.backtick^1)
                         * Cb("ticks"), captures_equal_length)

parsers.intickschar = (parsers.any - S(" \n\r`"))
                    + (parsers.newline * -parsers.blankline)
                    + (parsers.space - parsers.closeticks)
                    + (parsers.backtick^1 - parsers.closeticks)

parsers.inticks     = parsers.openticks * parsers.space^-1
                    * C(parsers.intickschar^0) * parsers.closeticks
parsers.leader      = parsers.space^-3

-- content in balanced brackets, parentheses, or quotes:
parsers.bracketed   = P{ parsers.lbracket
                       * (( parsers.backslash / "" * parsers.rbracket
                          + parsers.any - (parsers.lbracket
                                          + parsers.rbracket
                                          + parsers.blankline^2)
                          ) + V(1))^0
                       * parsers.rbracket }

parsers.inparens    = P{ parsers.lparent
                       * ((parsers.anyescaped - (parsers.lparent
                                                + parsers.rparent
                                                + parsers.blankline^2)
                          ) + V(1))^0
                       * parsers.rparent }

parsers.squoted     = P{ parsers.squote * parsers.alphanumeric
                       * ((parsers.anyescaped - (parsers.squote
                                                + parsers.blankline^2)
                          ) + V(1))^0
                       * parsers.squote }

parsers.dquoted     = P{ parsers.dquote * parsers.alphanumeric
                       * ((parsers.anyescaped - (parsers.dquote
                                                + parsers.blankline^2)
                          ) + V(1))^0
                       * parsers.dquote }

-- bracketed tag for markdown links, allowing nested brackets:
parsers.tag         = parsers.lbracket
                    * Cs((parsers.alphanumeric^1
                         + parsers.bracketed
                         + parsers.inticks
                         + ( parsers.backslash / "" * parsers.rbracket
                           + parsers.any
                           - (parsers.rbracket + parsers.blankline^2)))^0)
                    * parsers.rbracket

-- url for markdown links, allowing nested brackets:
parsers.url         = parsers.less * Cs((parsers.anyescaped
                                        - parsers.more)^0)
                                   * parsers.more
                    + Cs((parsers.inparens + (parsers.anyescaped
                                             - parsers.spacing
                                             - parsers.rparent))^1)

-- quoted text, possibly with nested quotes:
parsers.title_s     = parsers.squote * Cs(((parsers.anyescaped-parsers.squote)
                                           + parsers.squoted)^0)
                                     * parsers.squote

parsers.title_d     = parsers.dquote * Cs(((parsers.anyescaped-parsers.dquote)
                                           + parsers.dquoted)^0)
                                     * parsers.dquote

parsers.title_p     = parsers.lparent
                    * Cs((parsers.inparens + (parsers.anyescaped-parsers.rparent))^0)
                    * parsers.rparent

parsers.title       = parsers.title_d + parsers.title_s + parsers.title_p

parsers.optionaltitle
                    = parsers.spnl * parsers.title * parsers.spacechar^0
                    + Cc("")

parsers.indirect_link
                    = parsers.tag
                    * ( C(parsers.spnl) * parsers.tag
                      + Cc(nil) * Cc(nil)  -- always produce exactly two captures
                      )

parsers.indirect_image
                    = parsers.exclamation * parsers.indirect_link
-- case-insensitive match (we assume s is lowercase). must be single byte encoding
parsers.keyword_exact = function(s)
  local parser = P(0)
  for i=1,#s do
    local c = s:sub(i,i)
    local m = c .. upper(c)
    parser = parser * S(m)
  end
  return parser
end

parsers.block_keyword =
    parsers.keyword_exact("address") + parsers.keyword_exact("blockquote") +
    parsers.keyword_exact("center") + parsers.keyword_exact("del") +
    parsers.keyword_exact("dir") + parsers.keyword_exact("div") +
    parsers.keyword_exact("p") + parsers.keyword_exact("pre") +
    parsers.keyword_exact("li") + parsers.keyword_exact("ol") +
    parsers.keyword_exact("ul") + parsers.keyword_exact("dl") +
    parsers.keyword_exact("dd") + parsers.keyword_exact("form") +
    parsers.keyword_exact("fieldset") + parsers.keyword_exact("isindex") +
    parsers.keyword_exact("ins") + parsers.keyword_exact("menu") +
    parsers.keyword_exact("noframes") + parsers.keyword_exact("frameset") +
    parsers.keyword_exact("h1") + parsers.keyword_exact("h2") +
    parsers.keyword_exact("h3") + parsers.keyword_exact("h4") +
    parsers.keyword_exact("h5") + parsers.keyword_exact("h6") +
    parsers.keyword_exact("hr") + parsers.keyword_exact("script") +
    parsers.keyword_exact("noscript") + parsers.keyword_exact("table") +
    parsers.keyword_exact("tbody") + parsers.keyword_exact("tfoot") +
    parsers.keyword_exact("thead") + parsers.keyword_exact("th") +
    parsers.keyword_exact("td") + parsers.keyword_exact("tr")

-- There is no reason to support bad html, so we expect quoted attributes
parsers.htmlattributevalue
                          = parsers.squote * (parsers.any - (parsers.blankline
                                                            + parsers.squote))^0
                                           * parsers.squote
                          + parsers.dquote * (parsers.any - (parsers.blankline
                                                            + parsers.dquote))^0
                                           * parsers.dquote

parsers.htmlattribute     = parsers.spacing^1
                          * (parsers.alphanumeric + S("_-"))^1
                          * parsers.sp * parsers.equal * parsers.sp
                          * parsers.htmlattributevalue

parsers.htmlcomment       = P("<!--")
                          * parsers.optionalspace
                          * Cs((parsers.any - parsers.optionalspace * P("-->"))^0)
                          * parsers.optionalspace
                          * P("-->")

parsers.htmlinstruction   = P("<?") * (parsers.any - P("?>"))^0 * P("?>")

parsers.openelt_any = parsers.less * parsers.keyword * parsers.htmlattribute^0
                    * parsers.sp * parsers.more

parsers.openelt_exact = function(s)
  return parsers.less * parsers.sp * parsers.keyword_exact(s)
       * parsers.htmlattribute^0 * parsers.sp * parsers.more
end

parsers.openelt_block = parsers.sp * parsers.block_keyword
                      * parsers.htmlattribute^0 * parsers.sp * parsers.more

parsers.closeelt_any = parsers.less * parsers.sp * parsers.slash
                     * parsers.keyword * parsers.sp * parsers.more

parsers.closeelt_exact = function(s)
  return parsers.less * parsers.sp * parsers.slash * parsers.keyword_exact(s)
       * parsers.sp * parsers.more
end

parsers.emptyelt_any = parsers.less * parsers.sp * parsers.keyword
                     * parsers.htmlattribute^0 * parsers.sp * parsers.slash
                     * parsers.more

parsers.emptyelt_block = parsers.less * parsers.sp * parsers.block_keyword
                       * parsers.htmlattribute^0 * parsers.sp * parsers.slash
                       * parsers.more

parsers.displaytext = (parsers.any - parsers.less)^1

-- return content between two matched HTML tags
parsers.in_matched = function(s)
  return { parsers.openelt_exact(s)
         * (V(1) + parsers.displaytext
           + (parsers.less - parsers.closeelt_exact(s)))^0
         * parsers.closeelt_exact(s) }
end

local function parse_matched_tags(s,pos)
  local t = string.lower(lpeg.match(C(parsers.keyword),s,pos))
  return lpeg.match(parsers.in_matched(t),s,pos-1)
end

parsers.in_matched_block_tags = parsers.less
                              * Cmt(#parsers.openelt_block, parse_matched_tags)

parsers.hexentity = parsers.ampersand * parsers.hash * S("Xx")
                  * C(parsers.hexdigit^1) * parsers.semicolon
parsers.decentity = parsers.ampersand * parsers.hash
                  * C(parsers.digit^1) * parsers.semicolon
parsers.tagentity = parsers.ampersand * C(parsers.alphanumeric^1)
                  * parsers.semicolon
-- parse a reference definition:  [foo]: /bar "title"
parsers.define_reference_parser = parsers.leader * parsers.tag * parsers.colon
                                * parsers.spacechar^0 * parsers.url
                                * parsers.optionaltitle
parsers.Inline         = V("Inline")
parsers.IndentedInline = V("IndentedInline")

-- parse many p between starter and ender
parsers.between = function(p, starter, ender)
  local ender2 = B(parsers.nonspacechar) * ender
  return (starter * #parsers.nonspacechar * Ct(p * (p - ender2)^0) * ender2)
end

parsers.urlchar       = parsers.anyescaped
                      - parsers.newline
                      - parsers.more

parsers.auto_link_url = parsers.less
                      * C( parsers.alphanumeric^1 * P("://")
                         * parsers.urlchar^1)
                      * parsers.more

parsers.auto_link_email
                      = parsers.less
                      * C((parsers.alphanumeric + S("-._+"))^1
                      * P("@") * parsers.urlchar^1)
                      * parsers.more

parsers.auto_link_relative_reference
                      = parsers.less
                      * C(parsers.urlchar^1)
                      * parsers.more

parsers.lineof = function(c)
    return (parsers.leader * (P(c) * parsers.optionalspace)^3
           * (parsers.newline * parsers.blankline^1
             + parsers.newline^-1 * parsers.eof))
end
-- parse Atx heading start and return level
parsers.heading_start = #parsers.hash * C(parsers.hash^-6)
                      * -parsers.hash / length

-- parse setext header ending and return level
parsers.heading_level = parsers.equal^1 * Cc(1) + parsers.dash^1 * Cc(2)

local function strip_atx_end(s)
  return s:gsub("[#%s]*\n$","")
end
M.reader = {}
function M.reader.new(writer, options)
  local self = {}
  self.writer = writer
  self.options = options
  self.parsers = {}
  (function(parsers)
    setmetatable(self.parsers, {
      __index = function (_, key)
        return parsers[key]
      end
    })
  end)(parsers)
  local parsers = self.parsers
  function self.normalize_tag(tag)
    tag = util.rope_to_string(tag)
    tag = tag:gsub("[ \n\r\t]+", " ")
    tag = tag:gsub("^ ", ""):gsub(" $", "")
    tag = uni_case.casefold(tag, true, false)
    return tag
  end
  local function iterlines(s, f)
    local rope = lpeg.match(Ct((parsers.line / f)^1), s)
    return util.rope_to_string(rope)
  end
  if options.preserveTabs then
    self.expandtabs = function(s) return s end
  else
    self.expandtabs = function(s)
                        if s:find("\t") then
                          return iterlines(s, util.expand_tabs_in_line)
                        else
                          return s
                        end
                      end
  end
  self.parser_functions = {}
  self.create_parser = function(name, grammar, toplevel)
    self.parser_functions[name] = function(str)
      if toplevel and options.stripIndent then
          local min_prefix_length, min_prefix = nil, ''
          str = iterlines(str, function(line)
              if lpeg.match(parsers.nonemptyline, line) == nil then
                  return line
              end
              line = util.expand_tabs_in_line(line)
              local prefix = lpeg.match(C(parsers.optionalspace), line)
              local prefix_length = #prefix
              local is_shorter = min_prefix_length == nil
              is_shorter = is_shorter or prefix_length < min_prefix_length
              if is_shorter then
                  min_prefix_length, min_prefix = prefix_length, prefix
              end
              return line
          end)
          str = str:gsub('^' .. min_prefix, '')
      end
      if toplevel and (options.texComments or options.hybrid) then
        str = lpeg.match(Ct(parsers.commented_line^1), str)
        str = util.rope_to_string(str)
      end
      local res = lpeg.match(grammar(), str)
      if res == nil then
        error(format("%s failed on:\n%s", name, str:sub(1,20)))
      else
        return res
      end
    end
  end

  self.create_parser("parse_blocks",
                     function()
                       return parsers.blocks
                     end, true)

  self.create_parser("parse_blocks_nested",
                     function()
                       return parsers.blocks_nested
                     end, false)

  self.create_parser("parse_inlines",
                     function()
                       return parsers.inlines
                     end, false)

  self.create_parser("parse_inlines_no_link",
                     function()
                       return parsers.inlines_no_link
                     end, false)

  self.create_parser("parse_inlines_no_inline_note",
                     function()
                       return parsers.inlines_no_inline_note
                     end, false)

  self.create_parser("parse_inlines_no_html",
                     function()
                       return parsers.inlines_no_html
                     end, false)

  self.create_parser("parse_inlines_nbsp",
                     function()
                       return parsers.inlines_nbsp
                     end, false)
  if options.hashEnumerators then
    parsers.dig = parsers.digit + parsers.hash
  else
    parsers.dig = parsers.digit
  end

  parsers.enumerator = C(parsers.dig^3 * parsers.period) * #parsers.spacing
                     + C(parsers.dig^2 * parsers.period) * #parsers.spacing
                                       * (parsers.tab + parsers.space^1)
                     + C(parsers.dig * parsers.period) * #parsers.spacing
                                     * (parsers.tab + parsers.space^-2)
                     + parsers.space * C(parsers.dig^2 * parsers.period)
                                     * #parsers.spacing
                     + parsers.space * C(parsers.dig * parsers.period)
                                     * #parsers.spacing
                                     * (parsers.tab + parsers.space^-1)
                     + parsers.space * parsers.space * C(parsers.dig^1
                                     * parsers.period) * #parsers.spacing
  -- strip off leading > and indents, and run through blocks
  parsers.blockquote_body = ((parsers.leader * parsers.more * parsers.space^-1)/""
                             * parsers.linechar^0 * parsers.newline)^1
                            * (-V("BlockquoteExceptions") * parsers.linechar^1
                              * parsers.newline)^0

  if not options.breakableBlockquotes then
    parsers.blockquote_body = parsers.blockquote_body
                            * (parsers.blankline^0 / "")
  end
  -- List of references defined in the document
  local references

  function self.register_link(tag, url, title,
                              attributes)
    tag = self.normalize_tag(tag)
    references[tag] = {
      url = url,
      title = title,
      attributes = attributes,
    }
    return ""
  end

  function self.lookup_reference(label, sps, tag,
                                 attributes)
    local tagpart
    if not tag then
      tag = label
      tagpart = ""
    elseif tag == "" then
      tag = label
      tagpart = "[]"
    else
      tagpart = {
        "[",
        self.parser_functions.parse_inlines(tag),
        "]"
      }
    end
    if sps then
      tagpart = {sps, tagpart}
    end
    tag = self.normalize_tag(tag)
    local r = references[tag]
    if r then
      local merged_attributes = {}
      for _, attribute in ipairs(r.attributes or {}) do
        table.insert(merged_attributes, attribute)
      end
      for _, attribute in ipairs(attributes or {}) do
        table.insert(merged_attributes, attribute)
      end
      if #merged_attributes == 0 then
        merged_attributes = nil
      end
      return {
        url = r.url,
        title = r.title,
        attributes = merged_attributes,
      }
    else
      return nil, {
        "[",
        self.parser_functions.parse_inlines(label),
        "]",
        tagpart
      }
    end
  end

  -- lookup link reference and return a link, if the reference is found,
  -- or a bracketed label otherwise.
  local function indirect_link(label, sps, tag)
    return writer.defer_call(function()
      local r,fallback = self.lookup_reference(label, sps, tag)
      if r then
        return writer.link(
          self.parser_functions.parse_inlines_no_link(label),
          r.url, r.title)
      else
        return fallback
      end
    end)
  end

  -- lookup image reference and return an image, if the reference is found,
  -- or a bracketed label otherwise.
  local function indirect_image(label, sps, tag)
    return writer.defer_call(function()
      local r,fallback = self.lookup_reference(label, sps, tag)
      if r then
        return writer.image(writer.string(label), r.url, r.title)
      else
        return {"!", fallback}
      end
    end)
  end

  parsers.direct_link_tail = parsers.spnl
                           * parsers.lparent
                           * (parsers.url + Cc(""))  -- link can be empty [foo]()
                           * parsers.optionaltitle
                           * parsers.rparent

  parsers.direct_link = (parsers.tag / self.parser_functions.parse_inlines_no_link)
                      * parsers.direct_link_tail

  parsers.direct_image = parsers.exclamation
                       * (parsers.tag / self.parser_functions.parse_inlines)
                       * parsers.direct_link_tail
  parsers.Str      = (parsers.normalchar * (parsers.normalchar + parsers.at)^0)
                   / writer.string

  parsers.Symbol   = (V("SpecialChar") - parsers.tightblocksep)
                   / writer.string

  parsers.Ellipsis = P("...") / writer.ellipsis

  parsers.Smart    = parsers.Ellipsis

  parsers.Code     = parsers.inticks / writer.code

  if options.blankBeforeBlockquote then
    parsers.bqstart = parsers.fail
  else
    parsers.bqstart = parsers.more
  end

  if options.blankBeforeHeading then
    parsers.headerstart = parsers.fail
  else
    parsers.headerstart = parsers.hash
                        + (parsers.line * (parsers.equal^1 + parsers.dash^1)
                        * parsers.optionalspace * parsers.newline)
  end

  parsers.EndlineExceptions
                     = parsers.blankline -- paragraph break
                     + parsers.tightblocksep  -- nested list
                     + parsers.eof       -- end of document
                     + parsers.bqstart
                     + parsers.headerstart

  parsers.Endline   = parsers.newline
                    * -V("EndlineExceptions")
                    * parsers.spacechar^0
                    / (options.hardLineBreaks and writer.hard_line_break
                                               or writer.space)

  parsers.OptionalIndent
                     = parsers.spacechar^1 / writer.space

  parsers.Space      = parsers.spacechar^2 * parsers.Endline / writer.hard_line_break
                     + parsers.spacechar^1 * parsers.Endline^-1 * parsers.eof / ""
                     + parsers.spacechar^1 * parsers.Endline
                                           * parsers.optionalspace
                                           / (options.hardLineBreaks
                                              and writer.hard_line_break
                                               or writer.space)
                     + parsers.spacechar^1 * parsers.optionalspace
                                           / writer.space

  parsers.NonbreakingEndline
                    = parsers.newline
                    * -V("EndlineExceptions")
                    * parsers.spacechar^0
                    / (options.hardLineBreaks and writer.hard_line_break
                                               or writer.nbsp)

  parsers.NonbreakingSpace
                  = parsers.spacechar^2 * parsers.Endline / writer.hard_line_break
                  + parsers.spacechar^1 * parsers.Endline^-1 * parsers.eof / ""
                  + parsers.spacechar^1 * parsers.Endline
                                        * parsers.optionalspace
                                        / (options.hardLineBreaks
                                           and writer.hard_line_break
                                            or writer.nbsp)
                  + parsers.spacechar^1 * parsers.optionalspace
                                        / writer.nbsp

  if options.underscores then
    parsers.Strong = ( parsers.between(parsers.Inline, parsers.doubleasterisks,
                                       parsers.doubleasterisks)
                     + parsers.between(parsers.Inline, parsers.doubleunderscores,
                                       parsers.doubleunderscores)
                     ) / writer.strong

    parsers.Emph   = ( parsers.between(parsers.Inline, parsers.asterisk,
                                       parsers.asterisk)
                     + parsers.between(parsers.Inline, parsers.underscore,
                                       parsers.underscore)
                     ) / writer.emphasis
  else
    parsers.Strong = ( parsers.between(parsers.Inline, parsers.doubleasterisks,
                                       parsers.doubleasterisks)
                     ) / writer.strong

    parsers.Emph   = ( parsers.between(parsers.Inline, parsers.asterisk,
                                       parsers.asterisk)
                     ) / writer.emphasis
  end

function self.auto_link_url(url, attributes)
  return writer.link(writer.escape(url),
                     url, nil, attributes)
end

function self.auto_link_email(email, attributes)
  return writer.link(writer.escape(email),
                     "mailto:"..email,
                     nil, attributes)
end

  parsers.AutoLinkUrl = parsers.auto_link_url
                      / self.auto_link_url

  parsers.AutoLinkEmail
                      = parsers.auto_link_email
                      / self.auto_link_email

  parsers.AutoLinkRelativeReference
                      = parsers.auto_link_relative_reference
                      / self.auto_link_url

  parsers.DirectLink    = parsers.direct_link
                        / writer.link

  parsers.IndirectLink  = parsers.indirect_link
                        / indirect_link

  -- parse a link or image (direct or indirect)
  parsers.Link          = parsers.DirectLink + parsers.IndirectLink

  parsers.DirectImage   = parsers.direct_image
                        / writer.image

  parsers.IndirectImage = parsers.indirect_image
                        / indirect_image

  parsers.Image         = parsers.DirectImage + parsers.IndirectImage

  -- avoid parsing long strings of * or _ as emph/strong
  parsers.UlOrStarLine  = parsers.asterisk^4 + parsers.underscore^4
                        / writer.string

  parsers.EscapedChar   = parsers.backslash * C(parsers.escapable) / writer.string

  parsers.InlineHtml    = parsers.emptyelt_any / writer.inline_html_tag
                        + (parsers.htmlcomment / self.parser_functions.parse_inlines_no_html)
                        / writer.inline_html_comment
                        + parsers.htmlinstruction
                        + parsers.openelt_any / writer.inline_html_tag
                        + parsers.closeelt_any / writer.inline_html_tag

  parsers.HtmlEntity    = parsers.hexentity / entities.hex_entity  / writer.string
                        + parsers.decentity / entities.dec_entity  / writer.string
                        + parsers.tagentity / entities.char_entity / writer.string
  parsers.DisplayHtml  = (parsers.htmlcomment / self.parser_functions.parse_blocks_nested)
                       / writer.block_html_comment
                       + parsers.emptyelt_block / writer.block_html_element
                       + parsers.openelt_exact("hr") / writer.block_html_element
                       + parsers.in_matched_block_tags / writer.block_html_element
                       + parsers.htmlinstruction

  parsers.Verbatim     = Cs( (parsers.blanklines
                           * ((parsers.indentedline - parsers.blankline))^1)^1
                           ) / self.expandtabs / writer.verbatim

  parsers.BlockquoteExceptions = parsers.leader * parsers.more
                               + parsers.blankline

  parsers.Blockquote   = Cs(parsers.blockquote_body^1)
                       / self.parser_functions.parse_blocks_nested
                       / writer.blockquote

  parsers.ThematicBreak = ( parsers.lineof(parsers.asterisk)
                          + parsers.lineof(parsers.dash)
                          + parsers.lineof(parsers.underscore)
                          ) / writer.thematic_break

  parsers.Reference    = parsers.define_reference_parser
                       * parsers.blankline^1
                       / self.register_link

  parsers.Paragraph    = parsers.nonindentspace * Ct(parsers.Inline^1)
                       * ( parsers.newline
                         * ( parsers.blankline^1
                           + #V("EndlineExceptions")
                         )
                         + parsers.eof)
                       / writer.paragraph

  parsers.Plain        = parsers.nonindentspace * Ct(parsers.Inline^1)
                       / writer.plain
  parsers.starter = parsers.bullet + parsers.enumerator

  if options.taskLists then
    parsers.tickbox = ( parsers.ticked_box
                      + parsers.halfticked_box
                      + parsers.unticked_box
                      ) / writer.tickbox
  else
     parsers.tickbox = parsers.fail
  end

  -- we use \001 as a separator between a tight list item and a
  -- nested list under it.
  parsers.NestedList            = Cs((parsers.optionallyindentedline
                                     - parsers.starter)^1)
                                / function(a) return "\001"..a end

  parsers.ListBlockLine         = parsers.optionallyindentedline
                                - parsers.blankline - (parsers.indent^-1
                                                      * parsers.starter)

  parsers.ListBlock             = parsers.line * parsers.ListBlockLine^0

  parsers.ListContinuationBlock = parsers.blanklines * (parsers.indent / "")
                                * parsers.ListBlock

  parsers.TightListItem = function(starter)
      return -parsers.ThematicBreak
             * (Cs(starter / "" * parsers.tickbox^-1 * parsers.ListBlock * parsers.NestedList^-1)
               / self.parser_functions.parse_blocks_nested)
             * -(parsers.blanklines * parsers.indent)
  end

  parsers.LooseListItem = function(starter)
      return -parsers.ThematicBreak
             * Cs( starter / "" * parsers.tickbox^-1 * parsers.ListBlock * Cc("\n")
               * (parsers.NestedList + parsers.ListContinuationBlock^0)
               * (parsers.blanklines / "\n\n")
               ) / self.parser_functions.parse_blocks_nested
  end

  parsers.BulletList = ( Ct(parsers.TightListItem(parsers.bullet)^1) * Cc(true)
                       * parsers.skipblanklines * -parsers.bullet
                       + Ct(parsers.LooseListItem(parsers.bullet)^1) * Cc(false)
                       * parsers.skipblanklines )
                     / writer.bulletlist

  local function ordered_list(items,tight,startnum)
    if options.startNumber then
      startnum = tonumber(startnum) or 1  -- fallback for '#'
      if startnum ~= nil then
        startnum = math.floor(startnum)
      end
    else
      startnum = nil
    end
    return writer.orderedlist(items,tight,startnum)
  end

  parsers.OrderedList = Cg(parsers.enumerator, "listtype") *
                      ( Ct(parsers.TightListItem(Cb("listtype"))
                          * parsers.TightListItem(parsers.enumerator)^0)
                      * Cc(true) * parsers.skipblanklines * -parsers.enumerator
                      + Ct(parsers.LooseListItem(Cb("listtype"))
                          * parsers.LooseListItem(parsers.enumerator)^0)
                      * Cc(false) * parsers.skipblanklines
                      ) * Cb("listtype") / ordered_list
  parsers.Blank        = parsers.blankline / ""
                       + V("Reference")
                       + (parsers.tightblocksep / "\n")
  -- parse atx header
  parsers.AtxHeading = Cg(parsers.heading_start, "level")
                     * parsers.optionalspace
                     * (C(parsers.line)
                       / strip_atx_end
                       / self.parser_functions.parse_inlines)
                     * Cb("level")
                     / writer.heading

  parsers.SetextHeading = #(parsers.line * S("=-"))
                        * Ct(parsers.linechar^1
                            / self.parser_functions.parse_inlines)
                        * parsers.newline
                        * parsers.heading_level
                        * parsers.optionalspace
                        * parsers.newline
                        / writer.heading

  parsers.Heading = parsers.AtxHeading + parsers.SetextHeading
  function self.finalize_grammar(extensions)
    local walkable_syntax = (function(global_walkable_syntax)
      local local_walkable_syntax = {}
      for lhs, rule in pairs(global_walkable_syntax) do
        local_walkable_syntax[lhs] = util.table_copy(rule)
      end
      return local_walkable_syntax
    end)(walkable_syntax)
    local current_extension_name = nil
    self.insert_pattern = function(selector, pattern, pattern_name)
      assert(pattern_name == nil or type(pattern_name) == "string")
      local _, _, lhs, pos, rhs = selector:find("^(%a+)%s+([%a%s]+%a+)%s+(%a+)$")
      assert(lhs ~= nil,
        [[Expected selector in form "LHS (before|after|instead of) RHS", not "]]
        .. selector .. [["]])
      assert(walkable_syntax[lhs] ~= nil,
        [[Rule ]] .. lhs .. [[ -> ... does not exist in markdown grammar]])
      assert(pos == "before" or pos == "after" or pos == "instead of",
        [[Expected positional specifier "before", "after", or "instead of", not "]]
        .. pos .. [["]])
      local rule = walkable_syntax[lhs]
      local index = nil
      for current_index, current_rhs in ipairs(rule) do
        if type(current_rhs) == "string" and current_rhs == rhs then
          index = current_index
          if pos == "after" then
            index = index + 1
          end
          break
        end
      end
      assert(index ~= nil,
        [[Rule ]] .. lhs .. [[ -> ]] .. rhs
          .. [[ does not exist in markdown grammar]])
      local accountable_pattern
      if current_extension_name then
        accountable_pattern = { pattern, current_extension_name, pattern_name }
      else
        assert(type(pattern) == "string",
          [[reader->insert_pattern() was called outside an extension with ]]
          .. [[a PEG pattern instead of a rule name]])
        accountable_pattern = pattern
      end
      if pos == "instead of" then
        rule[index] = accountable_pattern
      else
        table.insert(rule, index, accountable_pattern)
      end
    end
    local syntax =
      { "Blocks",

        Blocks                = V("InitializeState")
                              * ( V("ExpectedJekyllData")
                                * (V("Blank")^0 / writer.interblocksep))^-1
                              * V("Blank")^0
                              * V("Block")^-1
                              * ( V("Blank")^0 / writer.interblocksep
                                * V("Block"))^0
                              * V("Blank")^0 * parsers.eof,

        ExpectedJekyllData    = parsers.fail,

        Blank                 = parsers.Blank,
        Reference             = parsers.Reference,

        Blockquote            = parsers.Blockquote,
        Verbatim              = parsers.Verbatim,
        ThematicBreak         = parsers.ThematicBreak,
        BulletList            = parsers.BulletList,
        OrderedList           = parsers.OrderedList,
        Heading               = parsers.Heading,
        DisplayHtml           = parsers.DisplayHtml,
        Paragraph             = parsers.Paragraph,
        Plain                 = parsers.Plain,

        EndlineExceptions     = parsers.EndlineExceptions,
        BlockquoteExceptions  = parsers.BlockquoteExceptions,

        Str                   = parsers.Str,
        Space                 = parsers.Space,
        OptionalIndent        = parsers.OptionalIndent,
        Endline               = parsers.Endline,
        UlOrStarLine          = parsers.UlOrStarLine,
        Strong                = parsers.Strong,
        Emph                  = parsers.Emph,
        Link                  = parsers.Link,
        Image                 = parsers.Image,
        Code                  = parsers.Code,
        AutoLinkUrl           = parsers.AutoLinkUrl,
        AutoLinkEmail         = parsers.AutoLinkEmail,
        AutoLinkRelativeReference
                              = parsers.AutoLinkRelativeReference,
        InlineHtml            = parsers.InlineHtml,
        HtmlEntity            = parsers.HtmlEntity,
        EscapedChar           = parsers.EscapedChar,
        Smart                 = parsers.Smart,
        Symbol                = parsers.Symbol,
        SpecialChar           = parsers.fail,
        InitializeState       = parsers.succeed,
      }
    self.update_rule = function(rule_name, get_pattern)
      assert(current_extension_name ~= nil)
      assert(syntax[rule_name] ~= nil,
        [[Rule ]] .. rule_name .. [[ -> ... does not exist in markdown grammar]])
      local previous_pattern
      local extension_name
      if walkable_syntax[rule_name] then
        local previous_accountable_pattern = walkable_syntax[rule_name][1]
        previous_pattern = previous_accountable_pattern[1]
        extension_name = previous_accountable_pattern[2] .. ", " .. current_extension_name
      else
        previous_pattern = nil
        extension_name = current_extension_name
      end
      local pattern
      if type(get_pattern) == "function" then
        pattern = get_pattern(previous_pattern)
      else
        assert(previous_pattern == nil,
               [[Rule ]] .. rule_name ..
               [[ has already been updated by ]] .. extension_name)
        pattern = get_pattern
      end
      local accountable_pattern = { pattern, extension_name, rule_name }
      walkable_syntax[rule_name] = { accountable_pattern }
    end
    local special_characters = {}
    self.add_special_character = function(c)
      table.insert(special_characters, c)
      syntax.SpecialChar = S(table.concat(special_characters, ""))
    end

    self.add_special_character("*")
    self.add_special_character("[")
    self.add_special_character("]")
    self.add_special_character("<")
    self.add_special_character("!")
    self.add_special_character("\\")
    self.initialize_named_group = function(name, value)
      syntax.InitializeState = syntax.InitializeState
                             * Cg(Ct("") / value, name)
    end
    for _, extension in ipairs(extensions) do
      current_extension_name = extension.name
      extension.extend_writer(writer)
      extension.extend_reader(self)
    end
    current_extension_name = nil
    if options.debugExtensions then
      local sorted_lhs = {}
      for lhs, _ in pairs(walkable_syntax) do
        table.insert(sorted_lhs, lhs)
      end
      table.sort(sorted_lhs)

      local output_lines = {"{"}
      for lhs_index, lhs in ipairs(sorted_lhs) do
        local encoded_lhs = util.encode_json_string(lhs)
        table.insert(output_lines, [[    ]] ..encoded_lhs .. [[: []])
        local rule = walkable_syntax[lhs]
        for rhs_index, rhs in ipairs(rule) do
          local human_readable_rhs
          if type(rhs) == "string" then
            human_readable_rhs = rhs
          else
            local pattern_name
            if rhs[3] then
              pattern_name = rhs[3]
            else
              pattern_name = "Anonymous Pattern"
            end
            local extension_name = rhs[2]
            human_readable_rhs = pattern_name .. [[ (]] .. extension_name .. [[)]]
          end
          local encoded_rhs = util.encode_json_string(human_readable_rhs)
          local output_line = [[        ]] .. encoded_rhs
          if rhs_index < #rule then
            output_line = output_line .. ","
          end
          table.insert(output_lines, output_line)
        end
        local output_line = "    ]"
        if lhs_index < #sorted_lhs then
          output_line = output_line .. ","
        end
        table.insert(output_lines, output_line)
      end
      table.insert(output_lines, "}")

      local output = table.concat(output_lines, "\n")
      local output_filename = options.debugExtensionsFileName
      local output_file = assert(io.open(output_filename, "w"),
        [[Could not open file "]] .. output_filename .. [[" for writing]])
      assert(output_file:write(output))
      assert(output_file:close())
    end
    walkable_syntax["IndentedInline"] = util.table_copy(
      walkable_syntax["Inline"])
    self.insert_pattern(
      "IndentedInline instead of Space",
      "OptionalIndent")
    for lhs, rule in pairs(walkable_syntax) do
      syntax[lhs] = parsers.fail
      for _, rhs in ipairs(rule) do
        local pattern
        if type(rhs) == "string" then
          pattern = V(rhs)
        else
          pattern = rhs[1]
          if type(pattern) == "string" then
            pattern = V(pattern)
          end
        end
        syntax[lhs] = syntax[lhs] + pattern
      end
    end
    if options.underscores then
      self.add_special_character("_")
    end

    if not options.codeSpans then
      syntax.Code = parsers.fail
    else
      self.add_special_character("`")
    end

    if not options.html then
      syntax.DisplayHtml = parsers.fail
      syntax.InlineHtml = parsers.fail
      syntax.HtmlEntity  = parsers.fail
    else
      self.add_special_character("&")
    end

    if options.preserveTabs then
      options.stripIndent = false
    end

    if not options.smartEllipses then
      syntax.Smart = parsers.fail
    else
      self.add_special_character(".")
    end

    if not options.relativeReferences then
      syntax.AutoLinkRelativeReference = parsers.fail
    end

    local blocks_nested_t = util.table_copy(syntax)
    blocks_nested_t.ExpectedJekyllData = parsers.fail
    parsers.blocks_nested = Ct(blocks_nested_t)

    parsers.blocks = Ct(syntax)

    local inlines_t = util.table_copy(syntax)
    inlines_t[1] = "Inlines"
    inlines_t.Inlines = V("InitializeState")
                      * parsers.Inline^0
                      * ( parsers.spacing^0
                        * parsers.eof / "")
    parsers.inlines = Ct(inlines_t)

    local inlines_no_link_t = util.table_copy(inlines_t)
    inlines_no_link_t.Link = parsers.fail
    parsers.inlines_no_link = Ct(inlines_no_link_t)

    local inlines_no_inline_note_t = util.table_copy(inlines_t)
    inlines_no_inline_note_t.InlineNote = parsers.fail
    parsers.inlines_no_inline_note = Ct(inlines_no_inline_note_t)

    local inlines_no_html_t = util.table_copy(inlines_t)
    inlines_no_html_t.DisplayHtml = parsers.fail
    inlines_no_html_t.InlineHtml = parsers.fail
    inlines_no_html_t.HtmlEntity = parsers.fail
    parsers.inlines_no_html = Ct(inlines_no_html_t)

    local inlines_nbsp_t = util.table_copy(inlines_t)
    inlines_nbsp_t.Endline = parsers.NonbreakingEndline
    inlines_nbsp_t.Space = parsers.NonbreakingSpace
    parsers.inlines_nbsp = Ct(inlines_nbsp_t)
    return function(input)
      input = input:gsub("\r\n?", "\n")
      if input:sub(-1) ~= "\n" then
        input = input .. "\n"
      end
      references = {}
      local opt_string = {}
      for k, _ in pairs(defaultOptions) do
        local v = options[k]
        if type(v) == "table" then
          for _, i in ipairs(v) do
            opt_string[#opt_string+1] = k .. "=" .. tostring(i)
          end
        elseif k ~= "cacheDir" then
          opt_string[#opt_string+1] = k .. "=" .. tostring(v)
        end
      end
      table.sort(opt_string)
      local salt = table.concat(opt_string, ",") .. "," .. metadata.version
      local output
      local function convert(input)
        local document = self.parser_functions.parse_blocks(input)
        return util.rope_to_string(writer.document(document))
      end
      if options.eagerCache or options.finalizeCache then
        local name = util.cache(options.cacheDir, input, salt, convert,
                                ".md" .. writer.suffix)
        output = writer.pack(name)
      else
        output = convert(input)
      end
      if options.finalizeCache then
        local file, mode
        if options.frozenCacheCounter > 0 then
          mode = "a"
        else
          mode = "w"
        end
        file = assert(io.open(options.frozenCacheFileName, mode),
          [[Could not open file "]] .. options.frozenCacheFileName
          .. [[" for writing]])
        assert(file:write([[\expandafter\global\expandafter\def\csname ]]
          .. [[markdownFrozenCache]] .. options.frozenCacheCounter
          .. [[\endcsname{]] .. output .. [[}]] .. "\n"))
        assert(file:close())
      end
      return output
    end
  end
  return self
end
M.extensions = {}
M.extensions.bracketed_spans = function()
  return {
    name = "built-in bracketed_spans syntax extension",
    extend_writer = function(self)
      function self.span(s, attr)
        return {"\\markdownRendererBracketedSpanAttributeContextBegin",
                self.attributes(attr),
                s,
                "\\markdownRendererBracketedSpanAttributeContextEnd{}"}
      end
    end, extend_reader = function(self)
      local parsers = self.parsers
      local writer = self.writer

      local Span = parsers.between(parsers.Inline,
                                   parsers.lbracket,
                                   parsers.rbracket)
                 * Ct(parsers.attributes)
                 / writer.span

      self.insert_pattern("Inline after Emph",
                          Span, "Span")
    end
  }
end
M.extensions.citations = function(citation_nbsps)
  return {
    name = "built-in citations syntax extension",
    extend_writer = function(self)
      function self.citations(text_cites, cites)
        local buffer = {"\\markdownRenderer", text_cites and "TextCite" or "Cite",
          "{", #cites, "}"}
        for _,cite in ipairs(cites) do
          buffer[#buffer+1] = {cite.suppress_author and "-" or "+", "{",
            cite.prenote or "", "}{", cite.postnote or "", "}{", cite.name, "}"}
        end
        return buffer
      end
    end, extend_reader = function(self)
      local parsers = self.parsers
      local writer = self.writer

      local citation_chars
                    = parsers.alphanumeric
                    + S("#$%&-+<>~/_")

      local citation_name
                    = Cs(parsers.dash^-1) * parsers.at
                    * Cs(citation_chars
                        * (((citation_chars + parsers.internal_punctuation
                            - parsers.comma - parsers.semicolon)
                           * -#((parsers.internal_punctuation - parsers.comma
                                - parsers.semicolon)^0
                               * -(citation_chars + parsers.internal_punctuation
                                  - parsers.comma - parsers.semicolon)))^0
                          * citation_chars)^-1)

      local citation_body_prenote
                    = Cs((parsers.alphanumeric^1
                         + parsers.bracketed
                         + parsers.inticks
                         + (parsers.anyescaped
                           - (parsers.rbracket + parsers.blankline^2))
                         - (parsers.spnl * parsers.dash^-1 * parsers.at))^0)

      local citation_body_postnote
                    = Cs((parsers.alphanumeric^1
                         + parsers.bracketed
                         + parsers.inticks
                         + (parsers.anyescaped
                           - (parsers.rbracket + parsers.semicolon
                             + parsers.blankline^2))
                         - (parsers.spnl * parsers.rbracket))^0)

      local citation_body_chunk
                    = citation_body_prenote
                    * parsers.spnl * citation_name
                    * (parsers.internal_punctuation - parsers.semicolon)^-1
                    * parsers.spnl * citation_body_postnote

      local citation_body
                    = citation_body_chunk
                    * (parsers.semicolon * parsers.spnl
                      * citation_body_chunk)^0

      local citation_headless_body_postnote
                    = Cs((parsers.alphanumeric^1
                         + parsers.bracketed
                         + parsers.inticks
                         + (parsers.anyescaped
                           - (parsers.rbracket + parsers.at
                             + parsers.semicolon + parsers.blankline^2))
                         - (parsers.spnl * parsers.rbracket))^0)

      local citation_headless_body
                    = citation_headless_body_postnote
                    * (parsers.sp * parsers.semicolon * parsers.spnl
                      * citation_body_chunk)^0

      local citations
                    = function(text_cites, raw_cites)
          local function normalize(str)
              if str == "" then
                  str = nil
              else
                  str = (citation_nbsps and
                    self.parser_functions.parse_inlines_nbsp or
                    self.parser_functions.parse_inlines)(str)
              end
              return str
          end

          local cites = {}
          for i = 1,#raw_cites,4 do
              cites[#cites+1] = {
                  prenote = normalize(raw_cites[i]),
                  suppress_author = raw_cites[i+1] == "-",
                  name = writer.identifier(raw_cites[i+2]),
                  postnote = normalize(raw_cites[i+3]),
              }
          end
          return writer.citations(text_cites, cites)
      end

      local TextCitations
                    = Ct((parsers.spnl
                    * Cc("")
                    * citation_name
                    * ((parsers.spnl
                        * parsers.lbracket
                        * citation_headless_body
                        * parsers.rbracket) + Cc("")))^1)
                    / function(raw_cites)
                        return citations(true, raw_cites)
                      end

      local ParenthesizedCitations
                    = Ct((parsers.spnl
                    * parsers.lbracket
                    * citation_body
                    * parsers.rbracket)^1)
                    / function(raw_cites)
                        return citations(false, raw_cites)
                      end

      local Citations = TextCitations + ParenthesizedCitations

      self.insert_pattern("Inline after Emph",
                          Citations, "Citations")

      self.add_special_character("@")
      self.add_special_character("-")
    end
  }
end
M.extensions.content_blocks = function(language_map)
  local languages_json = (function()
    local base, prev, curr
    for _, pathname in ipairs{util.lookup_files(language_map, { all=true })} do
      local file = io.open(pathname, "r")
      if not file then goto continue end
      local input = assert(file:read("*a"))
      assert(file:close())
      local json = input:gsub('("[^\n]-"):','[%1]=')
      curr = load("_ENV = {}; return "..json)()
      if type(curr) == "table" then
        if base == nil then
          base = curr
        else
          setmetatable(prev, { __index = curr })
        end
        prev = curr
      end
      ::continue::
    end
    return base or {}
  end)()

  return {
    name = "built-in content_blocks syntax extension",
    extend_writer = function(self)
      function self.contentblock(src,suf,type,tit)
        if not self.is_writing then return "" end
        src = src.."."..suf
        suf = suf:lower()
        if type == "onlineimage" then
          return {"\\markdownRendererContentBlockOnlineImage{",suf,"}",
                                 "{",self.string(src),"}",
                                 "{",self.uri(src),"}",
                                 "{",self.string(tit or ""),"}"}
        elseif languages_json[suf] then
          return {"\\markdownRendererContentBlockCode{",suf,"}",
                                 "{",self.string(languages_json[suf]),"}",
                                 "{",self.string(src),"}",
                                 "{",self.uri(src),"}",
                                 "{",self.string(tit or ""),"}"}
        else
          return {"\\markdownRendererContentBlock{",suf,"}",
                                 "{",self.string(src),"}",
                                 "{",self.uri(src),"}",
                                 "{",self.string(tit or ""),"}"}
        end
      end
    end, extend_reader = function(self)
      local parsers = self.parsers
      local writer = self.writer

      local contentblock_tail
                    = parsers.optionaltitle
                    * (parsers.newline + parsers.eof)

      -- case insensitive online image suffix:
      local onlineimagesuffix
                    = (function(...)
                        local parser = nil
                        for _, suffix in ipairs({...}) do
                          local pattern=nil
                          for i=1,#suffix do
                            local char=suffix:sub(i,i)
                            char = S(char:lower()..char:upper())
                            if pattern == nil then
                              pattern = char
                            else
                              pattern = pattern * char
                            end
                          end
                          if parser == nil then
                            parser = pattern
                          else
                            parser = parser + pattern
                          end
                        end
                        return parser
                      end)("png", "jpg", "jpeg", "gif", "tif", "tiff")

      -- online image url for iA Writer content blocks with mandatory suffix,
      -- allowing nested brackets:
      local onlineimageurl
                    = (parsers.less
                      * Cs((parsers.anyescaped
                           - parsers.more
                           - #(parsers.period
                              * onlineimagesuffix
                              * parsers.more
                              * contentblock_tail))^0)
                      * parsers.period
                      * Cs(onlineimagesuffix)
                      * parsers.more
                      + (Cs((parsers.inparens
                            + (parsers.anyescaped
                              - parsers.spacing
                              - parsers.rparent
                              - #(parsers.period
                                 * onlineimagesuffix
                                 * contentblock_tail)))^0)
                        * parsers.period
                        * Cs(onlineimagesuffix))
                      ) * Cc("onlineimage")

      -- filename for iA Writer content blocks with mandatory suffix:
      local localfilepath
                    = parsers.slash
                    * Cs((parsers.anyescaped
                         - parsers.tab
                         - parsers.newline
                         - #(parsers.period
                            * parsers.alphanumeric^1
                            * contentblock_tail))^1)
                    * parsers.period
                    * Cs(parsers.alphanumeric^1)
                    * Cc("localfile")

      local ContentBlock
                    = parsers.leader
                    * (localfilepath + onlineimageurl)
                    * contentblock_tail
                    / writer.contentblock

      self.insert_pattern("Block before Blockquote",
                          ContentBlock, "ContentBlock")
    end
  }
end
M.extensions.definition_lists = function(tight_lists)
  return {
    name = "built-in definition_lists syntax extension",
    extend_writer = function(self)
      local function dlitem(term, defs)
        local retVal = {"\\markdownRendererDlItem{",term,"}"}
        for _, def in ipairs(defs) do
          retVal[#retVal+1] = {"\\markdownRendererDlDefinitionBegin ",def,
                               "\\markdownRendererDlDefinitionEnd "}
        end
        retVal[#retVal+1] = "\\markdownRendererDlItemEnd "
        return retVal
      end

      function self.definitionlist(items,tight)
        if not self.is_writing then return "" end
        local buffer = {}
        for _,item in ipairs(items) do
          buffer[#buffer + 1] = dlitem(item.term, item.definitions)
        end
        if tight and tight_lists then
          return {"\\markdownRendererDlBeginTight\n", buffer,
            "\n\\markdownRendererDlEndTight"}
        else
          return {"\\markdownRendererDlBegin\n", buffer,
            "\n\\markdownRendererDlEnd"}
        end
      end
    end, extend_reader = function(self)
      local parsers = self.parsers
      local writer = self.writer

      local defstartchar = S("~:")

      local defstart = ( defstartchar * #parsers.spacing
                                      * (parsers.tab + parsers.space^-3)
                       + parsers.space * defstartchar * #parsers.spacing
                                       * (parsers.tab + parsers.space^-2)
                       + parsers.space * parsers.space * defstartchar
                                       * #parsers.spacing
                                       * (parsers.tab + parsers.space^-1)
                       + parsers.space * parsers.space * parsers.space
                                       * defstartchar * #parsers.spacing
                       )

      local dlchunk = Cs(parsers.line * (parsers.indentedline - parsers.blankline)^0)

      local function definition_list_item(term, defs, _)
        return { term = self.parser_functions.parse_inlines(term),
                 definitions = defs }
      end

      local DefinitionListItemLoose
                    = C(parsers.line) * parsers.skipblanklines
                    * Ct((defstart
                         * parsers.indented_blocks(dlchunk)
                         / self.parser_functions.parse_blocks_nested)^1)
                    * Cc(false) / definition_list_item

      local DefinitionListItemTight
                    = C(parsers.line)
                    * Ct((defstart * dlchunk
                         / self.parser_functions.parse_blocks_nested)^1)
                    * Cc(true) / definition_list_item

      local DefinitionList
                    = ( Ct(DefinitionListItemLoose^1) * Cc(false)
                      + Ct(DefinitionListItemTight^1)
                      * (parsers.skipblanklines
                        * -DefinitionListItemLoose * Cc(true))
                      ) / writer.definitionlist

      self.insert_pattern("Block after Heading",
                          DefinitionList, "DefinitionList")
    end
  }
end
M.extensions.fancy_lists = function()
  return {
    name = "built-in fancy_lists syntax extension",
    extend_writer = function(self)
      local options = self.options

      function self.fancylist(items,tight,startnum,numstyle,numdelim)
        if not self.is_writing then return "" end
        local buffer = {}
        local num = startnum
        for _,item in ipairs(items) do
          buffer[#buffer + 1] = self.fancyitem(item,num)
          if num ~= nil then
            num = num + 1
          end
        end
        local contents = util.intersperse(buffer,"\n")
        if tight and options.tightLists then
          return {"\\markdownRendererFancyOlBeginTight{",
                  numstyle,"}{",numdelim,"}",contents,
                  "\n\\markdownRendererFancyOlEndTight "}
        else
          return {"\\markdownRendererFancyOlBegin{",
                  numstyle,"}{",numdelim,"}",contents,
                  "\n\\markdownRendererFancyOlEnd "}
        end
      end
      function self.fancyitem(s,num)
        if num ~= nil then
          return {"\\markdownRendererFancyOlItemWithNumber{",num,"}",s,
                  "\\markdownRendererFancyOlItemEnd "}
        else
          return {"\\markdownRendererFancyOlItem ",s,"\\markdownRendererFancyOlItemEnd "}
        end
      end
    end, extend_reader = function(self)
      local parsers = self.parsers
      local options = self.options
      local writer = self.writer

      local label = parsers.dig + parsers.letter
      local numdelim = parsers.period + parsers.rparent
      local enumerator = C(label^3 * numdelim) * #parsers.spacing
                       + C(label^2 * numdelim) * #parsers.spacing
                                         * (parsers.tab + parsers.space^1)
                       + C(label * numdelim) * #parsers.spacing
                                       * (parsers.tab + parsers.space^-2)
                       + parsers.space * C(label^2 * numdelim)
                                       * #parsers.spacing
                       + parsers.space * C(label * numdelim)
                                       * #parsers.spacing
                                       * (parsers.tab + parsers.space^-1)
                       + parsers.space * parsers.space * C(label^1
                                       * numdelim) * #parsers.spacing
      local starter = parsers.bullet + enumerator

      local NestedList = Cs((parsers.optionallyindentedline
                            - starter)^1)
                       / function(a) return "\001"..a end

      local ListBlockLine  = parsers.optionallyindentedline
                           - parsers.blankline - (parsers.indent^-1
                                                 * starter)

      local ListBlock = parsers.line * ListBlockLine^0

      local ListContinuationBlock = parsers.blanklines * (parsers.indent / "")
                                  * ListBlock

      local TightListItem = function(starter)
          return -parsers.ThematicBreak
                 * (Cs(starter / "" * parsers.tickbox^-1 * ListBlock * NestedList^-1)
                   / self.parser_functions.parse_blocks_nested)
                 * -(parsers.blanklines * parsers.indent)
      end

      local LooseListItem = function(starter)
          return -parsers.ThematicBreak
                 * Cs( starter / "" * parsers.tickbox^-1 * ListBlock * Cc("\n")
                   * (NestedList + ListContinuationBlock^0)
                   * (parsers.blanklines / "\n\n")
                   ) / self.parser_functions.parse_blocks_nested
      end

      local function roman2number(roman)
        local romans = { ["L"] = 50, ["X"] = 10, ["V"] = 5, ["I"] = 1 }
        local numeral = 0

        local i = 1
        local len = string.len(roman)
        while i < len do
          local z1, z2 = romans[ string.sub(roman, i, i) ], romans[ string.sub(roman, i+1, i+1) ]
          if z1 < z2 then
              numeral = numeral + (z2 - z1)
              i = i + 2
          else
              numeral = numeral + z1
              i = i + 1
          end
        end
        if i <= len then numeral = numeral + romans[ string.sub(roman,i,i) ] end
        return numeral
      end

      local function sniffstyle(itemprefix)
        local numstr, delimend = itemprefix:match("^([A-Za-z0-9]*)([.)]*)")
        local numdelim
        if delimend == ")" then
          numdelim = "OneParen"
        elseif delimend == "." then
          numdelim = "Period"
        else
          numdelim = "Default"
        end
        numstr = numstr or itemprefix

        local num
        num = numstr:match("^([IVXL]+)")
        if num then
          return roman2number(num), "UpperRoman", numdelim
        end
        num = numstr:match("^([ivxl]+)")
        if num then
          return roman2number(string.upper(num)), "LowerRoman", numdelim
        end
        num = numstr:match("^([A-Z])")
        if num then
          return string.byte(num) - string.byte("A") + 1, "UpperAlpha", numdelim
        end
        num = numstr:match("^([a-z])")
        if num then
          return string.byte(num) - string.byte("a") + 1, "LowerAlpha", numdelim
        end
        return math.floor(tonumber(numstr) or 1), "Decimal", numdelim
      end

      local function fancylist(items,tight,start)
        local startnum, numstyle, numdelim = sniffstyle(start)
        return writer.fancylist(items,tight,
                                options.startNumber and startnum,
                                numstyle or "Decimal",
                                numdelim or "Default")
      end

      local FancyList = Cg(enumerator, "listtype") *
                      ( Ct(TightListItem(Cb("listtype"))
                          * TightListItem(enumerator)^0)
                      * Cc(true) * parsers.skipblanklines * -enumerator
                      + Ct(LooseListItem(Cb("listtype"))
                          * LooseListItem(enumerator)^0)
                      * Cc(false) * parsers.skipblanklines
                      ) * Cb("listtype") / fancylist

      self.update_rule("OrderedList", FancyList)
    end
  }
end
M.extensions.fenced_code = function(blank_before_code_fence,
                                    allow_attributes,
                                    allow_raw_blocks)
  return {
    name = "built-in fenced_code syntax extension",
    extend_writer = function(self)
      local options = self.options

      function self.fencedCode(s, i, attr)
        if not self.is_writing then return "" end
        s = s:gsub("\n$", "")
        local buf = {}
        if attr ~= nil then
          table.insert(buf, {"\\markdownRendererFencedCodeAttributeContextBegin",
                             self.attributes(attr)})
        end
        local name = util.cache_verbatim(options.cacheDir, s)
        table.insert(buf, {"\\markdownRendererInputFencedCode{",
                           name,"}{",self.string(i),"}"})
        if attr ~= nil then
          table.insert(buf, "\\markdownRendererFencedCodeAttributeContextEnd")
        end
        return buf
      end

      if allow_raw_blocks then
        function self.rawBlock(s, attr)
          if not self.is_writing then return "" end
          s = s:gsub("\n$", "")
          local name = util.cache_verbatim(options.cacheDir, s)
          return {"\\markdownRendererInputRawBlock{",
                  name,"}{", self.string(attr),"}"}
        end
      end
    end, extend_reader = function(self)
      local parsers = self.parsers
      local writer = self.writer

      local function captures_geq_length(_,i,a,b)
        return #a >= #b and i
      end

      local tilde_infostring
                           = C((parsers.linechar
                              - (parsers.spacechar^1 * parsers.newline))^0)

      local backtick_infostring
                           = C((parsers.linechar
                              - (parsers.backtick
                                + parsers.spacechar^1 * parsers.newline))^0)

      local fenceindent
      local fencehead      = function(char, infostring)
        return               C(parsers.nonindentspace) / function(s) fenceindent = #s end
                           * Cg(char^3, "fencelength")
                           * parsers.optionalspace
                           * infostring
                           * (parsers.newline + parsers.eof)
      end

      local fencetail      = function(char)
        return               parsers.nonindentspace
                           * Cmt(C(char^3) * Cb("fencelength"), captures_geq_length)
                           * parsers.optionalspace * (parsers.newline + parsers.eof)
                           + parsers.eof
      end

      local fencedline     = function(char)
        return               C(parsers.line - fencetail(char))
                           / function(s)
                               local i = 1
                               local remaining = fenceindent
                               while true do
                                 local c = s:sub(i, i)
                                 if c == " " and remaining > 0 then
                                   remaining = remaining - 1
                                   i = i + 1
                                 elseif c == "\t" and remaining > 3 then
                                   remaining = remaining - 4
                                   i = i + 1
                                 else
                                   break
                                 end
                               end
                               return s:sub(i)
                             end
      end

      local TildeFencedCode
             = fencehead(parsers.tilde, tilde_infostring)
             * Cs(fencedline(parsers.tilde)^0)
             * fencetail(parsers.tilde)

      local BacktickFencedCode
             = fencehead(parsers.backtick, backtick_infostring)
             * Cs(fencedline(parsers.backtick)^0)
             * fencetail(parsers.backtick)

            local infostring_with_attributes
                             = Ct(C((parsers.linechar
                                    - ( parsers.optionalspace
                                      * parsers.attributes))^0)
                                 * parsers.optionalspace
                                 * Ct(parsers.attributes))

      local FencedCode
               = (TildeFencedCode + BacktickFencedCode)
               / function(infostring, code)
                   local expanded_code = self.expandtabs(code)

                   if allow_raw_blocks then
                     local raw_attr = lpeg.match(parsers.raw_attribute,
                                                 infostring)
                     if raw_attr then
                       return writer.rawBlock(expanded_code, raw_attr)
                     end
                   end

                   local attr = nil
                   if allow_attributes then
                     local match = lpeg.match(infostring_with_attributes,
                                              infostring)
                     if match then
                       infostring, attr = table.unpack(match)
                     end
                   end
                   return writer.fencedCode(expanded_code, infostring, attr)
                 end

      self.insert_pattern("Block after Verbatim",
                          FencedCode, "FencedCode")

      local fencestart
      if blank_before_code_fence then
        fencestart = parsers.fail
      else
        fencestart = fencehead(parsers.backtick, backtick_infostring)
                   + fencehead(parsers.tilde, tilde_infostring)
      end

      self.update_rule("EndlineExceptions", function(previous_pattern)
        if previous_pattern == nil then
          previous_pattern = parsers.EndlineExceptions
        end
        return previous_pattern + fencestart
      end)

      self.add_special_character("`")
      self.add_special_character("~")
    end
  }
end
M.extensions.fenced_divs = function(blank_before_div_fence)
  return {
    name = "built-in fenced_divs syntax extension",
    extend_writer = function(self)
      function self.div_begin(attributes)
        local start_output = {"\\markdownRendererFencedDivAttributeContextBegin\n",
                              self.attributes(attributes)}
        local end_output = {"\n\\markdownRendererFencedDivAttributeContextEnd "}
        return self.push_attributes("div", attributes, start_output, end_output)
      end
      function self.div_end()
        return self.pop_attributes("div")
      end
    end, extend_reader = function(self)
      local parsers = self.parsers
      local writer = self.writer
      local fenced_div_infostring
                             = C((parsers.linechar
                                - ( parsers.spacechar^1
                                  * parsers.colon^1))^1)

      local fenced_div_begin = parsers.nonindentspace
                             * parsers.colon^3
                             * parsers.optionalspace
                             * fenced_div_infostring
                             * ( parsers.spacechar^1
                               * parsers.colon^1)^0
                             * parsers.optionalspace
                             * (parsers.newline + parsers.eof)

      local fenced_div_end = parsers.nonindentspace
                           * parsers.colon^3
                           * parsers.optionalspace
                           * (parsers.newline + parsers.eof)
      self.initialize_named_group("div_level", "0")

      local function increment_div_level(increment)
        local function update_div_level(s, i, current_level) -- luacheck: ignore s i
          current_level = tonumber(current_level)
          local next_level = tostring(current_level + increment)
          return true, next_level
        end

        return Cg( Cmt(Cb("div_level"), update_div_level)
                 , "div_level")
      end

      local FencedDiv = fenced_div_begin
                      / function (infostring)
                          local attr = lpeg.match(Ct(parsers.attributes), infostring)
                          if attr == nil then
                            attr = {"." .. infostring}
                          end
                          return attr
                        end
                      / writer.div_begin
                      * increment_div_level(1)
                      * parsers.skipblanklines
                      * Ct( (V("Block") - fenced_div_end)^-1
                          * ( parsers.blanklines
                            / function()
                                return writer.interblocksep
                              end
                            * (V("Block") - fenced_div_end))^0)
                      * parsers.skipblanklines
                      * fenced_div_end * increment_div_level(-1)
                      * (Cc("") / writer.div_end)

      self.insert_pattern("Block after Verbatim",
                          FencedDiv, "FencedDiv")

      self.add_special_character(":")

      local function check_div_level(s, i, current_level) -- luacheck: ignore s i
        current_level = tonumber(current_level)
        return current_level > 0
      end

      local is_inside_div = Cmt(Cb("div_level"), check_div_level)
      local fencestart = is_inside_div * fenced_div_end

      self.update_rule("BlockquoteExceptions", function(previous_pattern)
        if previous_pattern == nil then
          previous_pattern = parsers.BlockquoteExceptions
        end
        return previous_pattern + fencestart
      end)

      if not blank_before_div_fence then
        self.update_rule("EndlineExceptions", function(previous_pattern)
          if previous_pattern == nil then
            previous_pattern = parsers.EndlineExceptions
          end
          return previous_pattern + fencestart
        end)
      end
    end
  }
end
M.extensions.header_attributes = function()
  return {
    name = "built-in header_attributes syntax extension",
    extend_writer = function()
    end, extend_reader = function(self)
      local parsers = self.parsers
      local writer = self.writer

      local AtxHeading = Cg(parsers.heading_start, "level")
                       * parsers.optionalspace
                       * (C(((parsers.linechar
                             - ((parsers.hash^1
                                * parsers.optionalspace
                                * parsers.attributes^-1
                                + parsers.attributes)
                               * parsers.optionalspace
                               * parsers.newline))
                            * (parsers.linechar
                              - parsers.hash
                              - parsers.lbrace)^0)^1)
                           / self.parser_functions.parse_inlines)
                       * Cg(Ct(parsers.newline
                              + (parsers.hash^1
                                * parsers.optionalspace
                                * parsers.attributes^-1
                                + parsers.attributes)
                              * parsers.optionalspace
                              * parsers.newline), "attributes")
                       * Cb("level")
                       * Cb("attributes")
                       / writer.heading

      local SetextHeading = #(parsers.line * S("=-"))
                          * (C(((parsers.linechar
                                - (parsers.attributes
                                  * parsers.optionalspace
                                  * parsers.newline))
                               * (parsers.linechar
                                 - parsers.lbrace)^0)^1)
                              / self.parser_functions.parse_inlines)
                          * Cg(Ct(parsers.newline
                                 + (parsers.attributes
                                   * parsers.optionalspace
                                   * parsers.newline)), "attributes")
                          * parsers.heading_level
                          * Cb("attributes")
                          * parsers.optionalspace
                          * parsers.newline
                          / writer.heading

      local Heading = AtxHeading + SetextHeading
      self.update_rule("Heading", Heading)
    end
  }
end
M.extensions.inline_code_attributes = function()
  return {
    name = "built-in inline_code_attributes syntax extension",
    extend_writer = function()
    end, extend_reader = function(self)
      local writer = self.writer

      local CodeWithAttributes = parsers.inticks
                               * Ct(parsers.attributes)
                               / writer.code

      self.insert_pattern("Inline before Code",
                          CodeWithAttributes,
                          "CodeWithAttributes")
    end
  }
end
M.extensions.line_blocks = function()
  return {
    name = "built-in line_blocks syntax extension",
    extend_writer = function(self)
      function self.lineblock(lines)
        if not self.is_writing then return "" end
        local buffer = {}
        for i = 1, #lines - 1 do
          buffer[#buffer + 1] = { lines[i], self.hard_line_break }
        end
        buffer[#buffer + 1] = lines[#lines]

        return {"\\markdownRendererLineBlockBegin\n"
                  ,buffer,
                  "\n\\markdownRendererLineBlockEnd "}
      end
    end, extend_reader = function(self)
      local parsers = self.parsers
      local writer = self.writer

      local LineBlock = Ct(
                        (Cs(
                          ( (parsers.pipe * parsers.space)/""
                          * ((parsers.space)/entities.char_entity("nbsp"))^0
                          * parsers.linechar^0 * (parsers.newline/""))
                          * (-parsers.pipe
                            * (parsers.space^1/" ")
                            * parsers.linechar^1
                            * (parsers.newline/"")
                            )^0
                          * (parsers.blankline/"")^0
                        ) / self.parser_functions.parse_inlines)^1) / writer.lineblock

      self.insert_pattern("Block after Blockquote",
                           LineBlock, "LineBlock")
    end
  }
end
M.extensions.link_attributes = function()
  return {
    name = "built-in link_attributes syntax extension",
    extend_writer = function()
    end, extend_reader = function(self)
      local parsers = self.parsers
      local writer = self.writer
      local options = self.options


      local define_reference_parser = parsers.define_reference_parser
                                    * ( parsers.spnl
                                      * Ct(parsers.attributes))^-1

      local ReferenceWithAttributes = define_reference_parser
                                    * parsers.blankline^1
                                    / self.register_link

      self.update_rule("Reference", ReferenceWithAttributes)


      local function indirect_link(label, sps, tag,
                                   attribute_text,
                                   attributes)
        return writer.defer_call(function()
          local r, fallback = self.lookup_reference(label, sps, tag,
                                                    attributes)
          if r then
            return writer.link(
              self.parser_functions.parse_inlines_no_link(label),
              r.url, r.title, r.attributes)
          else
            local buf = {fallback}
            if attributes then
              table.insert(buf, writer.string(attribute_text))
            end
            return buf
          end
        end)
      end

      local DirectLinkWithAttributes = parsers.direct_link
                                     * (Ct(parsers.attributes))^-1
                                     / writer.link

      local IndirectLinkWithAttributes = parsers.indirect_link
                                       * (C(Ct(parsers.attributes)))^-1
                                       / indirect_link

      local LinkWithAttributes = DirectLinkWithAttributes
                               + IndirectLinkWithAttributes

      self.update_rule("Link", LinkWithAttributes)


      local function indirect_image(label, sps, tag,
                                    attribute_text,
                                    attributes)
        return writer.defer_call(function()
          local r, fallback = self.lookup_reference(label, sps, tag,
                                                    attributes)
          if r then
            return writer.image(writer.string(label),
                                r.url, r.title, r.attributes)
          else
            local buf = {"!", fallback}
            if attributes then
              table.insert(buf, writer.string(attribute_text))
            end
            return buf
          end
        end)
      end

      local DirectImageWithAttributes = parsers.direct_image
                                      * Ct(parsers.attributes)
                                      / writer.image

      local IndirectImageWithAttributes = parsers.indirect_image
                                        * C(Ct(parsers.attributes))
                                        / indirect_image

      local ImageWithAttributes = DirectImageWithAttributes
                                + IndirectImageWithAttributes

      self.insert_pattern("Inline before Image",
                          ImageWithAttributes,
                          "ImageWithAttributes")


      local AutoLinkUrlWithAttributes
                      = parsers.auto_link_url
                      * Ct(parsers.attributes)
                      / self.auto_link_url

      self.insert_pattern("Inline before AutoLinkUrl",
                          AutoLinkUrlWithAttributes,
                          "AutoLinkUrlWithAttributes")

      local AutoLinkEmailWithAttributes
                      = parsers.auto_link_email
                      * Ct(parsers.attributes)
                      / self.auto_link_email

      self.insert_pattern("Inline before AutoLinkEmail",
                          AutoLinkEmailWithAttributes,
                          "AutoLinkEmailWithAttributes")

      if options.relativeReferences then

        local AutoLinkRelativeReferenceWithAttributes
                        = parsers.auto_link_relative_reference
                        * Ct(parsers.attributes)
                        / self.auto_link_url

        self.insert_pattern(
          "Inline before AutoLinkRelativeReference",
          AutoLinkRelativeReferenceWithAttributes,
          "AutoLinkRelativeReferenceWithAttributes")

      end

    end
  }
end
M.extensions.notes = function(notes, inline_notes)
  assert(notes or inline_notes)
  return {
    name = "built-in notes syntax extension",
    extend_writer = function(self)
      function self.note(s)
        return {"\\markdownRendererNote{",s,"}"}
      end
    end, extend_reader = function(self)
      local parsers = self.parsers
      local writer = self.writer

      if inline_notes then
        local InlineNote
                    = parsers.circumflex
                    * (parsers.tag / self.parser_functions.parse_inlines_no_inline_note)
                    / writer.note

        self.insert_pattern("Inline after Emph",
                            InlineNote, "InlineNote")
      end
      if notes then
        local function strip_first_char(s)
          return s:sub(2)
        end

        local RawNoteRef
                      = #(parsers.lbracket * parsers.circumflex)
                      * parsers.tag / strip_first_char

        local rawnotes = {}

        -- like indirect_link
        local function lookup_note(ref)
          return writer.defer_call(function()
            local found = rawnotes[self.normalize_tag(ref)]
            if found then
              return writer.note(
                self.parser_functions.parse_blocks_nested(found))
            else
              return {"[",
                self.parser_functions.parse_inlines("^" .. ref), "]"}
            end
          end)
        end

        local function register_note(ref,rawnote)
          rawnotes[self.normalize_tag(ref)] = rawnote
          return ""
        end

        local NoteRef = RawNoteRef / lookup_note

        local NoteBlock
                    = parsers.leader * RawNoteRef * parsers.colon
                    * parsers.spnl * parsers.indented_blocks(parsers.chunk)
                    / register_note

        local Blank = NoteBlock + parsers.Blank
        self.update_rule("Blank", Blank)

        self.insert_pattern("Inline after Emph",
                            NoteRef, "NoteRef")
      end

      self.add_special_character("^")
    end
  }
end
M.extensions.pipe_tables = function(table_captions)

  local function make_pipe_table_rectangular(rows)
    local num_columns = #rows[2]
    local rectangular_rows = {}
    for i = 1, #rows do
      local row = rows[i]
      local rectangular_row = {}
      for j = 1, num_columns do
        rectangular_row[j] = row[j] or ""
      end
      table.insert(rectangular_rows, rectangular_row)
    end
    return rectangular_rows
  end

  local function pipe_table_row(allow_empty_first_column
                               , nonempty_column
                               , column_separator
                               , column)
    local row_beginning
    if allow_empty_first_column then
      row_beginning = -- empty first column
                      #(parsers.spacechar^4
                       * column_separator)
                    * parsers.optionalspace
                    * column
                    * parsers.optionalspace
                    -- non-empty first column
                    + parsers.nonindentspace
                    * nonempty_column^-1
                    * parsers.optionalspace
    else
      row_beginning = parsers.nonindentspace
                    * nonempty_column^-1
                    * parsers.optionalspace
    end

    return Ct(row_beginning
             * (-- single column with no leading pipes
                #(column_separator
                 * parsers.optionalspace
                 * parsers.newline)
               * column_separator
               * parsers.optionalspace
               -- single column with leading pipes or
               -- more than a single column
               + (column_separator
                 * parsers.optionalspace
                 * column
                 * parsers.optionalspace)^1
               * (column_separator
                 * parsers.optionalspace)^-1))
  end

  return {
    name = "built-in pipe_tables syntax extension",
    extend_writer = function(self)
      function self.table(rows, caption)
        if not self.is_writing then return "" end
        local buffer = {"\\markdownRendererTable{",
          caption or "", "}{", #rows - 1, "}{", #rows[1], "}"}
        local temp = rows[2] -- put alignments on the first row
        rows[2] = rows[1]
        rows[1] = temp
        for i, row in ipairs(rows) do
          table.insert(buffer, "{")
          for _, column in ipairs(row) do
            if i > 1 then -- do not use braces for alignments
              table.insert(buffer, "{")
            end
            table.insert(buffer, column)
            if i > 1 then
              table.insert(buffer, "}")
            end
          end
          table.insert(buffer, "}")
        end
        return buffer
      end
    end, extend_reader = function(self)
      local parsers = self.parsers
      local writer = self.writer

      local table_hline_separator = parsers.pipe + parsers.plus

      local table_hline_column = (parsers.dash
                                 - #(parsers.dash
                                    * (parsers.spacechar
                                      + table_hline_separator
                                      + parsers.newline)))^1
                               * (parsers.colon * Cc("r")
                                 + parsers.dash * Cc("d"))
                               + parsers.colon
                               * (parsers.dash
                                 - #(parsers.dash
                                    * (parsers.spacechar
                                      + table_hline_separator
                                      + parsers.newline)))^1
                               * (parsers.colon * Cc("c")
                                 + parsers.dash * Cc("l"))

      local table_hline = pipe_table_row(false
                                        , table_hline_column
                                        , table_hline_separator
                                        , table_hline_column)

      local table_caption_beginning = parsers.skipblanklines
                                    * parsers.nonindentspace
                                    * (P("Table")^-1 * parsers.colon)
                                    * parsers.optionalspace

      local table_row = pipe_table_row(true
                                      , (C((parsers.linechar - parsers.pipe)^1)
                                        / self.parser_functions.parse_inlines)
                                      , parsers.pipe
                                      , (C((parsers.linechar - parsers.pipe)^0)
                                        / self.parser_functions.parse_inlines))

      local table_caption
      if table_captions then
        table_caption = #table_caption_beginning
                      * table_caption_beginning
                      * Ct(parsers.IndentedInline^1)
                      * parsers.newline
      else
        table_caption = parsers.fail
      end

      local PipeTable = Ct(table_row * parsers.newline
                        * table_hline
                        * (parsers.newline * table_row)^0)
                      / make_pipe_table_rectangular
                      * table_caption^-1
                      / writer.table

      self.insert_pattern("Block after Blockquote",
                          PipeTable, "PipeTable")
    end
  }
end
M.extensions.raw_inline = function()
  return {
    name = "built-in raw_inline syntax extension",
    extend_writer = function(self)
      local options = self.options

      function self.rawInline(s, attr)
        if not self.is_writing then return "" end
        local name = util.cache_verbatim(options.cacheDir, s)
        return {"\\markdownRendererInputRawInline{",
                name,"}{", self.string(attr),"}"}
      end
    end, extend_reader = function(self)
      local writer = self.writer

      local RawInline = parsers.inticks
                      * parsers.raw_attribute
                      / writer.rawInline

      self.insert_pattern("Inline before Code",
                          RawInline, "RawInline")
    end
  }
end
M.extensions.strike_through = function()
  return {
    name = "built-in strike_through syntax extension",
    extend_writer = function(self)
      function self.strike_through(s)
        return {"\\markdownRendererStrikeThrough{",s,"}"}
      end
    end, extend_reader = function(self)
      local parsers = self.parsers
      local writer = self.writer

      local StrikeThrough = (
        parsers.between(parsers.Inline, parsers.doubletildes,
                        parsers.doubletildes)
      ) / writer.strike_through

      self.insert_pattern("Inline after Emph",
                          StrikeThrough, "StrikeThrough")

      self.add_special_character("~")
    end
  }
end
M.extensions.subscripts = function()
  return {
    name = "built-in subscripts syntax extension",
    extend_writer = function(self)
      function self.subscript(s)
        return {"\\markdownRendererSubscript{",s,"}"}
      end
    end, extend_reader = function(self)
      local parsers = self.parsers
      local writer = self.writer

      local Subscript = (
        parsers.between(parsers.Str, parsers.tilde, parsers.tilde)
      ) / writer.subscript

      self.insert_pattern("Inline after Emph",
                          Subscript, "Subscript")

      self.add_special_character("~")
    end
  }
end
M.extensions.superscripts = function()
  return {
    name = "built-in superscripts syntax extension",
    extend_writer = function(self)
      function self.superscript(s)
        return {"\\markdownRendererSuperscript{",s,"}"}
      end
    end, extend_reader = function(self)
      local parsers = self.parsers
      local writer = self.writer

      local Superscript = (
        parsers.between(parsers.Str, parsers.circumflex, parsers.circumflex)
      ) / writer.superscript

      self.insert_pattern("Inline after Emph",
                          Superscript, "Superscript")

      self.add_special_character("^")
    end
  }
end
M.extensions.tex_math = function(tex_math_dollars,
                                 tex_math_single_backslash,
                                 tex_math_double_backslash)
  return {
    name = "built-in tex_math syntax extension",
    extend_writer = function(self)
      function self.display_math(s)
        if not self.is_writing then return "" end
        return {"\\markdownRendererDisplayMath{",self.math(s),"}"}
      end
      function self.inline_math(s)
        if not self.is_writing then return "" end
        return {"\\markdownRendererInlineMath{",self.math(s),"}"}
      end
    end, extend_reader = function(self)
      local parsers = self.parsers
      local writer = self.writer

      local function between(p, starter, ender)
        return (starter * C(p * (p - ender)^0) * ender)
      end

      local allowed_before_closing = B( parsers.backslash * parsers.any
                                      + parsers.any * (parsers.nonspacechar - parsers.backslash))
      local dollar_math_content = parsers.backslash^-1
                                * parsers.any
                                - parsers.blankline^2
                                - parsers.dollar

      local inline_math_opening_dollars = parsers.dollar
                                        * #(parsers.nonspacechar)

      local inline_math_closing_dollars = allowed_before_closing
                                        * parsers.dollar
                                        * -#(parsers.digit)

      local inline_math_dollars = between(C( dollar_math_content),
                                          inline_math_opening_dollars,
                                          inline_math_closing_dollars)

      local display_math_opening_dollars  = parsers.dollar
                                          * parsers.dollar

      local display_math_closing_dollars  = parsers.dollar
                                          * parsers.dollar

      local display_math_dollars = between(C( dollar_math_content),
                                           display_math_opening_dollars,
                                           display_math_closing_dollars)
      local backslash_math_content  = parsers.any
                                    - parsers.blankline^2
      local inline_math_opening_double  = parsers.backslash
                                        * parsers.backslash
                                        * parsers.lparent
                                        * #(parsers.nonspacechar)

      local inline_math_closing_double  = allowed_before_closing
                                        * parsers.backslash
                                        * parsers.backslash
                                        * parsers.rparent

      local inline_math_double  = between(C( backslash_math_content),
                                          inline_math_opening_double,
                                          inline_math_closing_double)

      local display_math_opening_double = parsers.backslash
                                        * parsers.backslash
                                        * parsers.lbracket

      local display_math_closing_double = allowed_before_closing
                                        * parsers.backslash
                                        * parsers.backslash
                                        * parsers.rbracket

      local display_math_double = between(C( backslash_math_content),
                                          display_math_opening_double,
                                          display_math_closing_double)
      local inline_math_opening_single  = parsers.backslash
                                        * parsers.lparent
                                        * #(parsers.nonspacechar)

      local inline_math_closing_single  = allowed_before_closing
                                        * parsers.backslash
                                        * parsers.rparent

      local inline_math_single  = between(C( backslash_math_content),
                                          inline_math_opening_single,
                                          inline_math_closing_single)

      local display_math_opening_single = parsers.backslash
                                        * parsers.lbracket

      local display_math_closing_single = allowed_before_closing
                                        * parsers.backslash
                                        * parsers.rbracket

      local display_math_single = between(C( backslash_math_content),
                                          display_math_opening_single,
                                          display_math_closing_single)

      local display_math = parsers.fail

      local inline_math = parsers.fail

      if tex_math_dollars then
        display_math = display_math + display_math_dollars
        inline_math = inline_math + inline_math_dollars
      end

      if tex_math_double_backslash then
        display_math = display_math + display_math_double
        inline_math = inline_math + inline_math_double
      end

      if tex_math_single_backslash then
        display_math = display_math + display_math_single
        inline_math = inline_math + inline_math_single
      end

      local TexMath = display_math / writer.display_math
                    + inline_math / writer.inline_math

      self.insert_pattern("Inline after Emph",
                          TexMath, "TexMath")

      if tex_math_dollars then
        self.add_special_character("$")
      end

      if tex_math_single_backslash or tex_math_double_backslash then
        self.add_special_character("\\")
        self.add_special_character("[")
        self.add_special_character("]")
        self.add_special_character(")")
        self.add_special_character("(")
      end
    end
  }
end
M.extensions.jekyll_data = function(expect_jekyll_data)
  return {
    name = "built-in jekyll_data syntax extension",
    extend_writer = function(self)
      function self.jekyllData(d, t, p)
        if not self.is_writing then return "" end

        local buf = {}

        local keys = {}
        for k, _ in pairs(d) do
          table.insert(keys, k)
        end
        table.sort(keys)

        if not p then
          table.insert(buf, "\\markdownRendererJekyllDataBegin")
        end

        if #d > 0 then
            table.insert(buf, "\\markdownRendererJekyllDataSequenceBegin{")
            table.insert(buf, self.identifier(p or "null"))
            table.insert(buf, "}{")
            table.insert(buf, #keys)
            table.insert(buf, "}")
        else
            table.insert(buf, "\\markdownRendererJekyllDataMappingBegin{")
            table.insert(buf, self.identifier(p or "null"))
            table.insert(buf, "}{")
            table.insert(buf, #keys)
            table.insert(buf, "}")
        end

        for _, k in ipairs(keys) do
          local v = d[k]
          local typ = type(v)
          k = tostring(k or "null")
          if typ == "table" and next(v) ~= nil then
            table.insert(
              buf,
              self.jekyllData(v, t, k)
            )
          else
            k = self.identifier(k)
            v = tostring(v)
            if typ == "boolean" then
              table.insert(buf, "\\markdownRendererJekyllDataBoolean{")
              table.insert(buf, k)
              table.insert(buf, "}{")
              table.insert(buf, v)
              table.insert(buf, "}")
            elseif typ == "number" then
              table.insert(buf, "\\markdownRendererJekyllDataNumber{")
              table.insert(buf, k)
              table.insert(buf, "}{")
              table.insert(buf, v)
              table.insert(buf, "}")
            elseif typ == "string" then
              table.insert(buf, "\\markdownRendererJekyllDataString{")
              table.insert(buf, k)
              table.insert(buf, "}{")
              table.insert(buf, t(v))
              table.insert(buf, "}")
            elseif typ == "table" then
              table.insert(buf, "\\markdownRendererJekyllDataEmpty{")
              table.insert(buf, k)
              table.insert(buf, "}")
            else
              error(format("Unexpected type %s for value of " ..
                           "YAML key %s", typ, k))
            end
          end
        end

        if #d > 0 then
          table.insert(buf, "\\markdownRendererJekyllDataSequenceEnd")
        else
          table.insert(buf, "\\markdownRendererJekyllDataMappingEnd")
        end

        if not p then
          table.insert(buf, "\\markdownRendererJekyllDataEnd")
        end

        return buf
      end
    end, extend_reader = function(self)
      local parsers = self.parsers
      local writer = self.writer

      local JekyllData
                    = Cmt( C((parsers.line - P("---") - P("..."))^0)
                         , function(s, i, text) -- luacheck: ignore s i
                             local data
                             local ran_ok, _ = pcall(function()
                               -- TODO: Replace with `require("tinyyaml")` in TeX Live 2023
                               local tinyyaml = require("markdown-tinyyaml")
                               data = tinyyaml.parse(text, {timestamps=false})
                             end)
                             if ran_ok and data ~= nil then
                               return true, writer.jekyllData(data, function(s)
                                 return self.parser_functions.parse_blocks_nested(s)
                               end, nil)
                             else
                               return false
                             end
                           end
                         )

      local UnexpectedJekyllData
                    = P("---")
                    * parsers.blankline / 0
                    * #(-parsers.blankline)  -- if followed by blank, it's thematic break
                    * JekyllData
                    * (P("---") + P("..."))

      local ExpectedJekyllData
                    = ( P("---")
                      * parsers.blankline / 0
                      * #(-parsers.blankline)  -- if followed by blank, it's thematic break
                      )^-1
                    * JekyllData
                    * (P("---") + P("..."))^-1

      self.insert_pattern("Block before Blockquote",
                          UnexpectedJekyllData, "UnexpectedJekyllData")
      if expect_jekyll_data then
        self.update_rule("ExpectedJekyllData", ExpectedJekyllData)
      end
    end
  }
end
function M.new(options)
  options = options or {}
  setmetatable(options, { __index = function (_, key)
    return defaultOptions[key] end })
  local extensions = {}

  if options.bracketedSpans then
    local bracketed_spans_extension = M.extensions.bracketed_spans()
    table.insert(extensions, bracketed_spans_extension)
  end

  if options.contentBlocks then
    local content_blocks_extension = M.extensions.content_blocks(
      options.contentBlocksLanguageMap)
    table.insert(extensions, content_blocks_extension)
  end

  if options.definitionLists then
    local definition_lists_extension = M.extensions.definition_lists(
      options.tightLists)
    table.insert(extensions, definition_lists_extension)
  end

  if options.fencedCode then
    local fenced_code_extension = M.extensions.fenced_code(
      options.blankBeforeCodeFence,
      options.fencedCodeAttributes,
      options.rawAttribute)
    table.insert(extensions, fenced_code_extension)
  end

  if options.fencedDivs then
    local fenced_div_extension = M.extensions.fenced_divs(
      options.blankBeforeDivFence)
    table.insert(extensions, fenced_div_extension)
  end

  if options.headerAttributes then
    local header_attributes_extension = M.extensions.header_attributes()
    table.insert(extensions, header_attributes_extension)
  end

  if options.inlineCodeAttributes then
    local inline_code_attributes_extension =
      M.extensions.inline_code_attributes()
    table.insert(extensions, inline_code_attributes_extension)
  end

  if options.jekyllData then
    local jekyll_data_extension = M.extensions.jekyll_data(
      options.expectJekyllData)
    table.insert(extensions, jekyll_data_extension)
  end

  if options.linkAttributes then
    local link_attributes_extension =
      M.extensions.link_attributes()
    table.insert(extensions, link_attributes_extension)
  end

  if options.lineBlocks then
    local line_block_extension = M.extensions.line_blocks()
    table.insert(extensions, line_block_extension)
  end

  if options.pipeTables then
    local pipe_tables_extension = M.extensions.pipe_tables(
      options.tableCaptions)
    table.insert(extensions, pipe_tables_extension)
  end

  if options.rawAttribute then
    local raw_inline_extension = M.extensions.raw_inline()
    table.insert(extensions, raw_inline_extension)
  end

  if options.strikeThrough then
    local strike_through_extension = M.extensions.strike_through()
    table.insert(extensions, strike_through_extension)
  end

  if options.subscripts then
    local subscript_extension = M.extensions.subscripts()
    table.insert(extensions, subscript_extension)
  end

  if options.superscripts then
    local superscript_extension = M.extensions.superscripts()
    table.insert(extensions, superscript_extension)
  end

  if options.texMathDollars or
     options.texMathSingleBackslash or
     options.texMathDoubleBackslash then
    local tex_math_extension = M.extensions.tex_math(
      options.texMathDollars,
      options.texMathSingleBackslash,
      options.texMathDoubleBackslash)
    table.insert(extensions, tex_math_extension)
  end

  if options.footnotes or options.inlineFootnotes or
     options.notes or options.inlineNotes then
    local notes_extension = M.extensions.notes(
      options.footnotes or options.notes,
      options.inlineFootnotes or options.inlineNotes)
    table.insert(extensions, notes_extension)
  end

  if options.citations then
    local citations_extension = M.extensions.citations(options.citationNbsps)
    table.insert(extensions, citations_extension)
  end

  if options.fancyLists then
    local fancy_lists_extension = M.extensions.fancy_lists()
    table.insert(extensions, fancy_lists_extension)
  end
  for _, user_extension_filename in ipairs(options.extensions) do
    local user_extension = (function(filename)
      local pathname = util.lookup_files(filename)
      local input_file = assert(io.open(pathname, "r"),
        [[Could not open user-defined syntax extension "]]
        .. pathname .. [[" for reading]])
      local input = assert(input_file:read("*a"))
      assert(input_file:close())
      local user_extension, err = load([[
        local sandbox = {}
        setmetatable(sandbox, {__index = _G})
        _ENV = sandbox
      ]] .. input)()
      assert(user_extension,
        [[Failed to compile user-defined syntax extension "]]
        .. pathname .. [[": ]] .. (err or [[]]))
      assert(user_extension.api_version ~= nil,
        [[User-defined syntax extension "]] .. pathname
        .. [[" does not specify mandatory field "api_version"]])
      assert(type(user_extension.api_version) == "number",
        [[User-defined syntax extension "]] .. pathname
        .. [[" specifies field "api_version" of type "]]
        .. type(user_extension.api_version)
        .. [[" but "number" was expected]])
      assert(user_extension.api_version > 0
         and user_extension.api_version <= metadata.user_extension_api_version,
        [[User-defined syntax extension "]] .. pathname
        .. [[" uses syntax extension API version "]]
        .. user_extension.api_version .. [[ but markdown.lua ]]
        .. metadata.version .. [[ uses API version ]]
        .. metadata.user_extension_api_version
        .. [[, which is incompatible]])

      assert(user_extension.grammar_version ~= nil,
        [[User-defined syntax extension "]] .. pathname
        .. [[" does not specify mandatory field "grammar_version"]])
      assert(type(user_extension.grammar_version) == "number",
        [[User-defined syntax extension "]] .. pathname
        .. [[" specifies field "grammar_version" of type "]]
        .. type(user_extension.grammar_version)
        .. [[" but "number" was expected]])
      assert(user_extension.grammar_version == metadata.grammar_version,
        [[User-defined syntax extension "]] .. pathname
        .. [[" uses grammar version "]] .. user_extension.grammar_version
        .. [[ but markdown.lua ]] .. metadata.version
        .. [[ uses grammar version ]] .. metadata.grammar_version
        .. [[, which is incompatible]])

      assert(user_extension.finalize_grammar ~= nil,
        [[User-defined syntax extension "]] .. pathname
        .. [[" does not specify mandatory "finalize_grammar" field]])
      assert(type(user_extension.finalize_grammar) == "function",
        [[User-defined syntax extension "]] .. pathname
        .. [[" specifies field "finalize_grammar" of type "]]
        .. type(user_extension.finalize_grammar)
        .. [[" but "function" was expected]])
      local extension = {
        name = [[user-defined "]] .. pathname .. [[" syntax extension]],
        extend_reader = user_extension.finalize_grammar,
        extend_writer = function() end,
      }
      return extension
    end)(user_extension_filename)
    table.insert(extensions, user_extension)
  end
  local writer = M.writer.new(options)
  local reader = M.reader.new(writer, options)
  local convert = reader.finalize_grammar(extensions)

  return convert
end

return M
