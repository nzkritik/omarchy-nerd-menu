.pragma library

// Tabs in the picker. `prefixes` are the Nerd Fonts class prefixes (nf-md-…).
var SETS = [
  { label: "All", prefixes: [] },
  { label: "Logos", prefixes: ["linux"] },
  { label: "Devicons", prefixes: ["dev"] },
  { label: "Font Awesome", prefixes: ["fa", "fae"] },
  { label: "Material", prefixes: ["md"] },
  { label: "Codicons", prefixes: ["cod"] },
  { label: "Octicons", prefixes: ["oct"] },
  { label: "Seti", prefixes: ["seti", "custom"] },
  { label: "Weather", prefixes: ["weather"] },
  { label: "Other", prefixes: ["pom", "extra", "iec", "pl", "ple"] }
]

// The stock logo, so the picker can also put things back.
var OMARCHY_LOGO = { n: "omarchy-logo", c: 0xe900, s: "linux", h: "", f: "omarchy" }

function parse(raw) {
  var out = [OMARCHY_LOGO]
  var lines = String(raw || "").split("\n")
  for (var i = 0; i < lines.length; i++) {
    var sp = lines[i].indexOf(" ")
    if (sp < 1) continue
    var name = lines[i].slice(0, sp)
    var hex = lines[i].slice(sp + 1)
    out.push({ n: name, c: parseInt(hex, 16), s: name.slice(0, name.indexOf("-")), h: hex, f: "" })
  }
  return out
}

function inSet(glyph, setIndex) {
  var prefixes = SETS[setIndex] ? SETS[setIndex].prefixes : []
  return prefixes.length === 0 || prefixes.indexOf(glyph.s) !== -1
}

// Every word must appear in the name ("nf-" and "U+" are optional); a word
// that is a whole code point also matches it. Names whose icon part starts
// with the first word sort ahead of names that only contain it.
function filter(glyphs, query, setIndex) {
  var words = String(query || "").toLowerCase().trim().split(/\s+/).filter(function(w) { return w.length > 0 })
  for (var k = 0; k < words.length; k++) words[k] = words[k].replace(/^nf-/, "").replace(/^u\+/, "")

  var first = [], rest = []
  for (var i = 0; i < glyphs.length; i++) {
    var g = glyphs[i]
    if (!inSet(g, setIndex)) continue
    var name = g.n.toLowerCase()
    var ok = true
    for (var j = 0; j < words.length && ok; j++)
      ok = name.indexOf(words[j]) !== -1 || (g.h !== "" && g.h === words[j])
    if (!ok) continue
    var icon = name.slice(name.indexOf("-") + 1)
    if (words.length > 0 && (icon.indexOf(words[0]) === 0 || g.h === words[0])) first.push(g)
    else rest.push(g)
  }
  return first.concat(rest)
}

function glyphText(g) {
  return g ? String.fromCodePoint(g.c) : ""
}

function codePointLabel(g) {
  return g ? "U+" + g.c.toString(16).toUpperCase() : ""
}
