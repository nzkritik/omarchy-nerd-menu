import Quickshell
import QtQuick
import qs.Commons
import qs.Ui

// Drop-in for omarchy.menu: same left/right click, but the glyph comes from
// this widget's shell.json entry, and middle click opens the icon picker.
BarWidget {
  id: root

  // Both values come from shell.json, which anything running as the user can
  // edit, so only a plain hex code point and a plain family name get through.
  readonly property string glyphHex: {
    var v = String(setting("glyph", "")).toLowerCase()
    if (!/^[0-9a-f]{2,6}$/.test(v)) return ""
    var cp = parseInt(v, 16)
    return cp >= 0x20 && cp <= 0x10ffff && (cp < 0xd800 || cp > 0xdfff) ? v : ""
  }
  readonly property string glyphFont: {
    var v = String(setting("font", ""))
    return /^[A-Za-z0-9][A-Za-z0-9 ._-]{0,63}$/.test(v) ? v : ""
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  // A third-party widget's `bar` has no shellQuote(), but it does carry a
  // scoped shell that may toggle this plugin's own overlay, so no command
  // line is built at all. The argv fallback never goes through a shell either.
  function openPicker() {
    var payload = JSON.stringify({ glyph: root.glyphHex, font: root.glyphFont })
    var api = root.bar ? root.bar.shell : null
    if (api && typeof api.toggle === "function") api.toggle(root.moduleName, payload)
    else Quickshell.execDetached(["omarchy-shell", "shell", "toggle", root.moduleName, payload])
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.glyphHex ? String.fromCodePoint(parseInt(root.glyphHex, 16)) : "\ue900"
    fontFamily: !root.glyphHex ? "omarchy"
      : (root.glyphFont || (root.bar ? root.bar.fontFamily : Style.font.family))
    horizontalMargin: 7.5
    onPressed: function(button) {
      if (!root.bar) return
      if (button === Qt.RightButton) root.bar.run("xdg-terminal-exec")
      else if (button === Qt.MiddleButton) root.openPicker()
      else root.bar.run("omarchy-shell shell toggle omarchy.menu '{\"menu\":\"root\"}'")
    }
  }
}
