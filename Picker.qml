import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.Commons
import qs.Ui
import "Glyphs.js" as Glyphs
import "GlyphSearch.js" as GlyphSearch

// Full-screen overlay, laid out like omarchy.emojis: type to search, arrows to
// move, Enter to make the highlighted glyph the menu icon.
Item {
  id: root

  property var shell: null
  property var manifest: null

  property bool opened: false
  property string filterText: ""
  property int setIndex: 0
  property int selectedIndex: 0
  property bool cursorActive: false
  property var glyphs: GlyphSearch.parse(Glyphs.raw)
  property var results: []
  property string widgetId: (manifest && manifest.id) || "nzkritik.nerd-menu"
  property string currentHex: ""
  property string status: ""

  readonly property var selectedGlyph: cursorActive && selectedIndex >= 0 && selectedIndex < results.length
    ? results[selectedIndex] : null

  property color background: Color.menu.background
  property color foreground: Color.menu.text
  property color border: Color.menu.border
  property var borderSpec: Border.surfaceSpec("menu", "border", border, Math.max(1, Style.space(2)))
  property color scrim: Color.menu.scrim
  property color selectedBackground: Color.menu.selectedBackground
  property color selectedText: Color.menu.selectedText
  readonly property int cornerRadius: Style.cornerRadius
  property string fontFamily: Style.font.menuFamily
  property string glyphFamily: Style.font.family
  property int contentMargin: Style.spacing.panelPadding
  property int headerHeight: Math.max(Style.space(34), Style.font.title + Style.spacing.controlPaddingY * 2)
  property int tabsHeight: Math.max(Style.space(26), Style.font.body + Style.spacing.controlPaddingY * 2)
  property int footerHeight: Math.max(Style.space(52), Style.font.displayLarge + Style.spacing.md)
  property int contentSpacing: Style.spacing.md
  property int cardWidth: Math.min(Style.space(640), panel.width - Style.gapsOut * 2)
  property int cardHeight: Math.min(Style.space(600), panel.height - Style.gapsOut * 2)

  property int cellWidth: Math.max(Style.space(44), Style.font.display + Style.spacing.md)
  property int cellHeight: cellWidth
  property int columns: Math.max(1, Math.floor(resultGrid.width / cellWidth))

  function open(payloadJson) {
    var payload = {}
    try { payload = JSON.parse(payloadJson || "{}") || {} } catch (e) {}
    // The payload is only ever a hint for which cell to highlight.
    root.currentHex = /^[0-9a-f]{2,6}$/.test(String(payload.glyph || "")) ? String(payload.glyph) : ""
    root.opened = true
    root.status = ""
    root.filterText = ""
    root.setIndex = 0
    root.results = GlyphSearch.filter(root.glyphs, "", 0)
    root.selectedIndex = Math.max(0, root.indexOfHex(root.currentHex))
    root.cursorActive = root.results.length > 0
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
    scrollTimer.restart()
  }

  function close() {
    root.opened = false
  }

  function dismiss() {
    root.opened = false
    if (root.shell && typeof root.shell.hide === "function") root.shell.hide(root.widgetId)
  }

  function toggle() {
    if (root.opened) root.dismiss()
    else root.open("{}")
  }

  function indexOfHex(hex) {
    for (var i = 0; i < root.results.length; i++)
      if (root.results[i].h === hex) return i
    return -1
  }

  function rebuild() {
    root.results = GlyphSearch.filter(root.glyphs, root.filterText, root.setIndex)
    if (root.selectedIndex >= root.results.length) root.selectedIndex = Math.max(0, root.results.length - 1)
    root.cursorActive = root.results.length > 0
    scrollTimer.restart()
  }

  // The window, and so the grid, only gets its size once it is shown; scroll
  // after that layout pass instead of against a zero-width grid.
  Timer {
    id: scrollTimer
    interval: 0
    onTriggered: {
      if (root.results.length === 0) return
      resultGrid.forceLayout()
      resultGrid.positionViewAtIndex(root.selectedIndex, GridView.Center)
    }
  }

  function setFilter(next) {
    root.filterText = next
    root.selectedIndex = 0
    root.rebuild()
  }

  function setSet(next) {
    var n = GlyphSearch.SETS.length
    root.setIndex = (next + n) % n
    root.selectedIndex = 0
    root.rebuild()
  }

  function moveTo(index) {
    if (root.results.length === 0) return
    root.cursorActive = true
    root.selectedIndex = Math.max(0, Math.min(root.results.length - 1, index))
    resultGrid.positionViewAtIndex(root.selectedIndex, GridView.Contain)
  }

  function select(delta) {
    if (root.results.length === 0) return
    root.moveTo((root.selectedIndex + delta + root.results.length) % root.results.length)
  }

  function selectRow(delta) { root.moveTo(root.selectedIndex + delta * root.columns) }

  function selectPage(delta) {
    var visibleRows = Math.max(1, Math.floor(resultGrid.height / root.cellHeight))
    root.moveTo(root.selectedIndex + delta * root.columns * visibleRows)
  }

  // The bar entry for this widget, from the shell's copy of shell.json.
  function barEntry() {
    var layout = root.shell && root.shell.barConfig ? root.shell.barConfig.layout : null
    var sections = ["left", "center", "right"]
    for (var s = 0; layout && s < sections.length; s++) {
      var entries = layout[sections[s]] || []
      for (var i = 0; i < entries.length; i++)
        if (entries[i] && entries[i].id === root.widgetId) return entries[i]
    }
    return null
  }

  // Saves through the plugin API's updateEntryInline, which rewrites this
  // widget's shell.json entry, so the bar picks it up like any other setting
  // change. It replaces the whole entry, so keys other than ours are carried
  // over. A failure keeps the picker open and says why rather than closing as
  // if it had worked.
  function apply(glyph) {
    if (!glyph) return
    if (!root.shell || typeof root.shell.updateEntryInline !== "function") {
      root.status = "Can't save from here; run: omarchy bar set " + root.widgetId + " glyph " + (glyph.h || "''")
      return
    }
    var entry = root.barEntry()
    if (!entry) {
      root.status = "Put the widget on the bar first: omarchy bar put " + root.widgetId + " --section left --index 0"
      return
    }
    var next = {}
    for (var k in entry) if (k !== "id") next[k] = entry[k]
    next.glyph = glyph.h
    next.font = glyph.h ? glyph.f : ""
    // false also means "nothing changed", which is fine: the entry was found.
    root.shell.updateEntryInline(root.widgetId, next)
    root.dismiss()
  }

  PanelWindow {
    id: panel
    visible: root.opened
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "omarchy-nerd-menu"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore

    Rectangle {
      anchors.fill: parent
      color: root.scrim
    }

    MouseArea {
      anchors.fill: parent
      onClicked: root.dismiss()
    }

    BorderSurface {
      id: card
      width: root.cardWidth
      height: root.cardHeight
      radius: root.cornerRadius
      anchors.centerIn: parent
      color: root.background
      borderSpec: root.borderSpec
      padding: root.contentMargin

      MouseArea { anchors.fill: parent; onClicked: {} }

      Item {
        id: keyCatcher
        anchors.fill: parent
        focus: true

        Keys.priority: Keys.BeforeItem
        Keys.onPressed: function(event) {
          if (event.key === Qt.Key_Escape) {
            if (root.filterText) root.setFilter("")
            else root.dismiss()
          } else if (Util.editsFilter(event, root.filterText)) {
            root.setFilter(Util.editedFilter(event, root.filterText))
          } else if (event.key === Qt.Key_Backtab || (event.key === Qt.Key_Tab && (event.modifiers & Qt.ShiftModifier))) {
            root.setSet(root.setIndex - 1)
          } else if (event.key === Qt.Key_Tab) {
            root.setSet(root.setIndex + 1)
          } else if (event.key === Qt.Key_R && (event.modifiers & Qt.ControlModifier)) {
            root.apply(GlyphSearch.OMARCHY_LOGO)
          } else if (event.key === Qt.Key_Left) {
            root.select(-1)
          } else if (event.key === Qt.Key_Right) {
            root.select(1)
          } else if (event.key === Qt.Key_Up) {
            root.selectRow(-1)
          } else if (event.key === Qt.Key_Down) {
            root.selectRow(1)
          } else if (event.key === Qt.Key_PageUp) {
            root.selectPage(-1)
          } else if (event.key === Qt.Key_PageDown) {
            root.selectPage(1)
          } else if (event.key === Qt.Key_Home && (event.modifiers & Qt.ControlModifier)) {
            root.moveTo(0)
          } else if (event.key === Qt.Key_End && (event.modifiers & Qt.ControlModifier)) {
            root.moveTo(root.results.length - 1)
          } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.apply(root.selectedGlyph)
          } else if (event.text && event.text.length === 1 && event.text.charCodeAt(0) >= 32 && event.text.charCodeAt(0) !== 127
                     && !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))) {
            root.setFilter(root.filterText + event.text)
          } else {
            return
          }
          event.accepted = true
        }
      }

      Column {
        anchors.fill: parent
        anchors.topMargin: card.contentTopInset
        anchors.rightMargin: card.contentRightInset
        anchors.bottomMargin: card.contentBottomInset
        anchors.leftMargin: card.contentLeftInset
        spacing: root.contentSpacing

        Item {
          width: parent.width
          height: root.headerHeight

          Text {
            textFormat: Text.PlainText
            anchors.left: parent.left
            anchors.right: countLabel.left
            anchors.rightMargin: root.contentSpacing
            anchors.verticalCenter: parent.verticalCenter
            text: root.filterText || "Search Nerd Font icons…"
            color: root.foreground
            opacity: root.filterText ? 1 : 0.58
            font.family: root.fontFamily
            font.pixelSize: Style.font.heading
            elide: Text.ElideRight
          }

          Text {
            id: countLabel
            textFormat: Text.PlainText
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: root.results.length.toLocaleString(Qt.locale(), "f", 0)
            color: root.foreground
            opacity: 0.5
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
          }
        }

        Flickable {
          id: tabs
          width: parent.width
          height: root.tabsHeight
          contentWidth: tabRow.implicitWidth
          flickableDirection: Flickable.HorizontalFlick
          boundsBehavior: Flickable.StopAtBounds
          clip: true

          Row {
            id: tabRow
            height: parent.height
            spacing: Style.space(4)

            Repeater {
              model: GlyphSearch.SETS

              delegate: Rectangle {
                id: tab
                required property var modelData
                required property int index
                readonly property bool current: index === root.setIndex

                height: tabRow.height
                width: tabLabel.implicitWidth + Style.spacing.md * 2
                radius: root.cornerRadius
                color: current ? root.selectedBackground : "transparent"
                onCurrentChanged: if (current) tabs.contentX = Math.max(0, Math.min(x - Style.spacing.md, tabs.contentWidth - tabs.width))

                Text {
                  id: tabLabel
                  textFormat: Text.PlainText
                  anchors.centerIn: parent
                  text: tab.modelData.label
                  color: tab.current ? root.selectedText : root.foreground
                  opacity: tab.current ? 1 : 0.7
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.body
                }

                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.setSet(tab.index)
                }
              }
            }
          }
        }

        Item {
          width: parent.width
          height: parent.height - root.headerHeight - root.tabsHeight - root.footerHeight - root.contentSpacing * 3

          GridView {
            id: resultGrid
            anchors.fill: parent
            model: root.results
            clip: true
            cellWidth: root.cellWidth
            cellHeight: root.cellHeight
            boundsBehavior: Flickable.StopAtBounds
            cacheBuffer: root.cellHeight * 4
            onWidthChanged: if (root.opened) scrollTimer.restart()

            delegate: Rectangle {
              id: cell
              required property int index
              required property var modelData

              readonly property bool hasCursor: root.cursorActive && index === root.selectedIndex
              readonly property bool isCurrent: modelData.h === root.currentHex

              width: root.cellWidth
              height: root.cellHeight
              radius: root.cornerRadius
              color: hasCursor ? root.selectedBackground : "transparent"
              border.width: isCurrent ? Math.max(1, Style.space(1)) : 0
              border.color: cell.hasCursor ? root.selectedText : root.foreground

              Text {
                textFormat: Text.PlainText
                anchors.centerIn: parent
                text: GlyphSearch.glyphText(cell.modelData)
                color: cell.hasCursor ? root.selectedText : root.foreground
                font.family: cell.modelData.f || root.glyphFamily
                font.pixelSize: Style.font.display
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
              }

              MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onContainsMouseChanged: if (containsMouse) {
                  root.cursorActive = true
                  root.selectedIndex = cell.index
                }
                onClicked: {
                  root.selectedIndex = cell.index
                  root.apply(cell.modelData)
                }
              }
            }
          }

          Column {
            anchors.centerIn: parent
            spacing: Style.space(8)
            visible: root.results.length === 0

            Text {
              text: "󰈉"
              color: root.selectedText
              opacity: 0.8
              font.family: root.glyphFamily
              font.pixelSize: Style.font.displayLarge
              horizontalAlignment: Text.AlignHCenter
              width: parent.width
            }

            Text {
              textFormat: Text.PlainText
              text: "No icons match “" + root.filterText + "”"
              color: root.foreground
              opacity: 0.7
              font.family: root.fontFamily
              font.pixelSize: Style.font.title
              horizontalAlignment: Text.AlignHCenter
            }
          }
        }

        // Preview of the highlighted glyph at bar size and large, its Nerd
        // Fonts class name, and the keys.
        Item {
          width: parent.width
          height: root.footerHeight

          Text {
            id: bigGlyph
            textFormat: Text.PlainText
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: root.footerHeight
            horizontalAlignment: Text.AlignHCenter
            text: GlyphSearch.glyphText(root.selectedGlyph)
            color: root.foreground
            font.family: (root.selectedGlyph && root.selectedGlyph.f) || root.glyphFamily
            font.pixelSize: Style.font.displayLarge
          }

          Column {
            anchors.left: bigGlyph.right
            anchors.leftMargin: root.contentSpacing
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(2)

            Text {
              textFormat: Text.PlainText
              width: parent.width
              elide: Text.ElideRight
              text: root.status || (root.selectedGlyph
                ? (root.selectedGlyph.f ? "Omarchy logo (default)" : "nf-" + root.selectedGlyph.n)
                  + "   " + GlyphSearch.codePointLabel(root.selectedGlyph)
                  + (root.selectedGlyph.h === root.currentHex ? "   · current" : "")
                : "")
              color: root.status ? Color.urgent : root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.title
            }

            Text {
              textFormat: Text.PlainText
              width: parent.width
              elide: Text.ElideRight
              text: "Enter set icon · Tab switch set · Ctrl+R Omarchy logo · Esc close"
              color: root.foreground
              opacity: 0.5
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
            }
          }
        }
      }
    }
  }
}
