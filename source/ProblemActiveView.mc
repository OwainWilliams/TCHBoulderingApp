// ============================================================
//  ProblemActiveView.mc
//  Shown while a boulder problem attempt is in progress.
//
//  Displays:
//    - Grade badge (large coloured circle + name)
//    - Live stopwatch updated every second by a Timer
//    - Two action buttons:  UP = Completed | DOWN = Attempted
//    - BACK = cancel attempt and return to grade picker
//
//  Fix from v1: stopwatch now ticks automatically via a 1-second
//  Timer instead of only updating on button presses.
//  Also removed the broken gradeIndexOf+getCurrentView pattern;
//  the grade index is read directly from App.getApp().
// ============================================================

using Toybox.WatchUi as Ui;
using Toybox.Graphics as Gfx;
using Toybox.Application as App;
using Toybox.Timer;
using Toybox.Time;

// ============================================================
//  ProblemActiveView
// ============================================================
class ProblemActiveView extends Ui.View {

    hidden var _ticker = null;

    function initialize() {
        View.initialize();
    }

    function onLayout(dc) {}

    function onShow() {
        _ticker = new Timer.Timer();
        _ticker.start(method(:onTick), 1000, true);
        Ui.requestUpdate();
    }

    function onHide() {
        if (_ticker != null) {
            _ticker.stop();
            _ticker = null;
        }
    }

    function onTick() as Void {
        Ui.requestUpdate();
    }

    function onUpdate(dc) {
        var app = App.getApp();
        var w   = dc.getWidth();
        var h   = dc.getHeight();
        var cx  = w / 2;
        var insetY = h * 15 / 100;

        // Background
        dc.setColor(Gfx.COLOR_BLACK, Gfx.COLOR_BLACK);
        dc.clear();

        if (!app.isProblemActive()) { return; }

        // ── Current time ──────────────────────────────────────
        var timeInfo = Time.Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        var timeStr  = timeInfo.hour.format("%02d") + ":" + timeInfo.min.format("%02d");
        dc.setColor(0x888888, Gfx.COLOR_TRANSPARENT);
        dc.drawText(cx, insetY / 2 - 8, Gfx.FONT_XTINY,
                    timeStr, Gfx.TEXT_JUSTIFY_CENTER);

        var gradeIdx   = app.getCurrentGradeIdx();
        var gradeName  = GRADES[gradeIdx];
        var gradeColor = GRADE_COLORS[gradeIdx];

        // ── Grade badge ──────────────────────────────────────
        var badgeY = insetY + 32;
        var badgeR = 34;

        dc.setColor(gradeColor, Gfx.COLOR_TRANSPARENT);
        dc.fillCircle(cx, badgeY, badgeR);

        // Outline for White (8) and Black (9) to separate from background
        if (gradeIdx == 8 || gradeIdx == 9) {
            dc.setColor(0x555555, Gfx.COLOR_TRANSPARENT);
            dc.drawCircle(cx, badgeY, badgeR);
        }

        // Text contrast inside the badge
        var useDarkText = (gradeIdx == 0 || gradeIdx == 7 || gradeIdx == 8);
        dc.setColor(useDarkText ? Gfx.COLOR_BLACK : Gfx.COLOR_WHITE,
                    Gfx.COLOR_TRANSPARENT);
        dc.drawText(cx, badgeY - 12, Gfx.FONT_SMALL,
                    gradeName, Gfx.TEXT_JUSTIFY_CENTER);

        // ── Stopwatch ────────────────────────────────────────
        var problemStart = app.getProblemStart();
        var elapsedSec   = problemStart != null
            ? Time.now().subtract(problemStart).value()
            : 0;

        var m = (elapsedSec / 60).toNumber();
        var s = (elapsedSec % 60).toNumber();
        if (m > 99) { m = 99; }
        var clockStr = m.format("%02d") + ":" + s.format("%02d");

        dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_TRANSPARENT);
        dc.drawText(cx, badgeY + badgeR + 6, Gfx.FONT_LARGE,
                    clockStr, Gfx.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x555555, Gfx.COLOR_TRANSPARENT);
        dc.drawText(cx, badgeY + badgeR + 38, Gfx.FONT_XTINY,
                    "time on problem", Gfx.TEXT_JUSTIFY_CENTER);

        // ── Outcome hints ─────────────────────────────────────
        // Side-by-side: left = TRIED (DOWN), right = SENT (UP)
        var margin  = w * 20 / 100;
        var colW    = (w - margin * 2) / 2;
        var leftCX  = margin + colW / 2;          // centre of left column
        var rightCX = margin + colW + colW / 2;   // centre of right column
        var hintY   = h - insetY - 48;
        var triW    = 8;   // half-width of triangle
        var triH    = 10;  // height of triangle

        // Down-pointing triangle (DOWN → Tried)
        dc.setColor(Gfx.COLOR_GREEN, Gfx.COLOR_TRANSPARENT);
             dc.fillPolygon([[leftCX, hintY],
                        [leftCX - triW, hintY + triH],
                        [leftCX + triW, hintY + triH]]);
        
        dc.drawText(leftCX, hintY + triH + 2, Gfx.FONT_TINY, "SENT", Gfx.TEXT_JUSTIFY_CENTER);

        // Up-pointing triangle (UP → Sent)
        dc.setColor(Gfx.COLOR_YELLOW, Gfx.COLOR_TRANSPARENT);
        dc.fillPolygon([[rightCX - triW, hintY],
                        [rightCX + triW, hintY],
                        [rightCX, hintY + triH]]);
        dc.drawText(rightCX, hintY + triH + 2, Gfx.FONT_TINY, "TRIED", Gfx.TEXT_JUSTIFY_CENTER);

        // ── Cancel hint ───────────────────────────────────────
        dc.setColor(0x444444, Gfx.COLOR_TRANSPARENT);
        dc.drawText(cx, h - insetY - 2, Gfx.FONT_XTINY,
                    "BACK to cancel", Gfx.TEXT_JUSTIFY_CENTER);
    }
}

// ============================================================
//  ProblemActiveDelegate
// ============================================================
class ProblemActiveDelegate extends Ui.BehaviorDelegate {

    function initialize() {
        BehaviorDelegate.initialize();
    }

    // UP → log as Completed, return to home
    function onPreviousPage() {
        App.getApp().logCurrentProblem(OUTCOME_COMPLETED);
        Ui.popView(Ui.SLIDE_RIGHT);
        return true;
    }

    // DOWN → log as Attempted, return to home
    function onNextPage() {
        App.getApp().logCurrentProblem(OUTCOME_ATTEMPTED);
        Ui.popView(Ui.SLIDE_RIGHT);
        return true;
    }

    // BACK → cancel this attempt without logging it
    //        Return to grade picker at the same grade so the
    //        user can try again immediately.
    function onBack() {
        var gradeIdx = App.getApp().getCurrentGradeIdx();

        // Clear the in-progress problem state without logging
        App.getApp().clearCurrentProblem();

        var pickerView = new GradePickerView(gradeIdx);
        Ui.switchToView(
            pickerView,
            new GradePickerDelegate(gradeIdx, pickerView),
            Ui.SLIDE_RIGHT
        );
        return true;
    }
}
