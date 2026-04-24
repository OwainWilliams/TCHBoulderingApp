// ============================================================
//  GradePickerView.mc
//  Scrollable grade selector.
//
//  The delegate holds a direct reference to the view and calls
//  setSelectedIdx() on each scroll, which triggers a plain
//  requestUpdate() — no view recreation or slide animation.
// ============================================================

using Toybox.WatchUi as Ui;
using Toybox.Graphics as Gfx;
using Toybox.Application as App;

// ── Grade colour palette ────────────────────────────────────
// Must stay in the same order as the GRADES array in BoulderingApp.mc:
//   0=Grey 1=Green 2=Orange 3=Blue 4=Purple
//   5=Pink 6=Red   7=Yellow 8=White 9=Black
var GRADE_COLORS = [
    0xAAAAAA,   // Grey
    0x00BB00,   // Green
    0xFF6600,   // Orange
    0x0055FF,   // Blue
    0x8800DD,   // Purple
    0xFF44AA,   // Pink
    0xDD0000,   // Red
    0xFFFFFF,   // White
    0xFFDD00,   // Yellow
    0x2A2A2A    // Black
];

// ── Indices that need a border to stay visible on black bg ──
var GRADE_NEEDS_BORDER = [8, 9]; // White, Black

// ============================================================
//  GradePickerView
//  Draws 5 grades centred on the selected one.
//  The delegate holds a reference to this view and calls
//  setSelectedIdx() on scroll — no view recreation needed.
// ============================================================
class GradePickerView extends Ui.View {

    hidden var _selectedIdx;

    // selectedIdx: which grade is currently highlighted (0–9)
    function initialize(selectedIdx) {
        View.initialize();
        _selectedIdx = selectedIdx;
    }

    // Called by the delegate on each scroll step
    function setSelectedIdx(idx) {
        _selectedIdx = idx;
        Ui.requestUpdate();
    }

    function onLayout(dc) {}

    function onShow() {
        Ui.requestUpdate();
    }

    function onUpdate(dc) {
        var w  = dc.getWidth();
        var h  = dc.getHeight();
        var cx = w / 2;
        var insetY = h * 15 / 100;
        // Horizontal inset keeps list rows away from curved edges
        var insetX = w * 10 / 100;

        // Background
        dc.setColor(Gfx.COLOR_BLACK, Gfx.COLOR_BLACK);
        dc.clear();

        // Header
        dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_TRANSPARENT);
        dc.drawText(cx, insetY, Gfx.FONT_TINY, "Select Grade", Gfx.TEXT_JUSTIFY_CENTER);

        // ── Visible list window: 5 items, selected item centred ─
        var itemH    = 32;
        var listTop  = h / 2 - itemH * 5 / 2;

        for (var offset = -2; offset <= 2; offset++) {
            var idx  = _selectedIdx + offset;
            if (idx < 0 || idx >= GRADES.size()) { continue; }

            var yTop = listTop + (offset + 2) * itemH;
            var isSel = (offset == 0);

            // Selection highlight — inset from sides for round screen
            if (isSel) {
                dc.setColor(0x1E1E1E, Gfx.COLOR_TRANSPARENT);
                dc.fillRoundedRectangle(insetX, yTop, w - insetX * 2, itemH - 2, 7);
                // Accent left bar
                dc.setColor(GRADE_COLORS[idx], Gfx.COLOR_TRANSPARENT);
                dc.fillRoundedRectangle(insetX, yTop, 4, itemH - 2, 2);
            }

            // Colour dot
            var dotR = isSel ? 9 : 6;
            var dotX = insetX + 18;
            var dotY = yTop + itemH / 2 - 1;

            dc.setColor(GRADE_COLORS[idx], Gfx.COLOR_TRANSPARENT);
            dc.fillCircle(dotX, dotY, dotR);

            // Outline on White and Black so they're visible against bg
            if (idx == 8 || idx == 9) {
                dc.setColor(0x666666, Gfx.COLOR_TRANSPARENT);
                dc.drawCircle(dotX, dotY, dotR);
            }

            // Grade name
            var textCol = isSel ? Gfx.COLOR_WHITE : 0x666666;
            var font    = isSel ? Gfx.FONT_SMALL : Gfx.FONT_TINY;
            dc.setColor(textCol, Gfx.COLOR_TRANSPARENT);
            dc.drawText(dotX + dotR + 8, yTop + (isSel ? 5 : 7), font,
                        GRADES[idx], Gfx.TEXT_JUSTIFY_LEFT);
        }

        // ── Scroll arrows ────────────────────────────────────
        dc.setColor(0x555555, Gfx.COLOR_TRANSPARENT);
        if (_selectedIdx > 0) {
            // Up arrow triangle
            var ay = listTop - 6;
            dc.fillPolygon([[cx, ay - 8], [cx + 7, ay], [cx - 7, ay]]);
        }
        if (_selectedIdx < GRADES.size() - 1) {
            // Down arrow triangle
            var dy = listTop + 5 * itemH + 8;
            dc.fillPolygon([[cx, dy + 8], [cx + 7, dy], [cx - 7, dy]]);
        }

        // // ── Bottom hint ──────────────────────────────────────
        // dc.setColor(0xFF6600, Gfx.COLOR_TRANSPARENT);
        // dc.drawText(cx, h - insetY - 10, Gfx.FONT_XTINY,
        //             "SELECT to start problem", Gfx.TEXT_JUSTIFY_CENTER);
    }

    function onHide() {}
}

// ============================================================
//  GradePickerDelegate
//  Owns the selection state.  Holds a reference to the view
//  and updates it in-place on scroll — no view recreation or
//  slide animation, so scrolling is instant and smooth.
// ============================================================
class GradePickerDelegate extends Ui.BehaviorDelegate {

    hidden var _selectedIdx;
    hidden var _view;

    function initialize(startIdx, view) {
        BehaviorDelegate.initialize();
        _selectedIdx = startIdx;
        _view = view;
    }

    // SELECT → confirm grade, hand off to ProblemActiveView
    function onSelect() {
        App.getApp().startProblem(_selectedIdx);
        Ui.switchToView(
            new ProblemActiveView(),
            new ProblemActiveDelegate(),
            Ui.SLIDE_LEFT
        );
        return true;
    }

    // UP button → scroll selection up (towards Grey)
    function onPreviousPage() {
        if (_selectedIdx > 0) {
            _selectedIdx--;
            _view.setSelectedIdx(_selectedIdx);
        }
        return true;
    }

    // DOWN button → scroll selection down (towards Black)
    function onNextPage() {
        if (_selectedIdx < GRADES.size() - 1) {
            _selectedIdx++;
            _view.setSelectedIdx(_selectedIdx);
        }
        return true;
    }

    // BACK → cancel, return to home
    function onBack() {
        Ui.popView(Ui.SLIDE_RIGHT);
        return true;
    }
}
