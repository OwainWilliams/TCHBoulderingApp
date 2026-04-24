// ============================================================
//  HomeView.mc
//  Screen 1 (idle) and Screen 2 (session active).
//
//  A 1-second Timer keeps the elapsed session clock ticking
//  without requiring any button presses.
// ============================================================

using Toybox.WatchUi as Ui;
using Toybox.Graphics as Gfx;
using Toybox.Application as App;
using Toybox.System as Sys;
using Toybox.Timer;
using Toybox.Time;
using Toybox.Math;

// ============================================================
//  HomeView
// ============================================================
class HomeView extends Ui.View {

    hidden var _ticker     = null;   // Timer.Timer — drives 1-second redraws
    hidden var _quoteIndex = 0;

    hidden var QUOTES = [
        "JUST GO UP!",
        "TRUST THE FEET",
        "BREATHE",
        "COMMIT!",
        "STAY CALM",
        "SEND IT!",
        "DONT LOOK DOWN",
    ];

    hidden var COLOURS = [
        0xFF6600,   // Orange
        0x0055FF,   // Blue
        0x8800DD,   // Purple
        0xFF44AA,   // Pink
        0xDD0000,   // Red
        0xFFFFFF,   // White
        0xFFDD00    // Yellow
    ];

    function initialize() {
        View.initialize();
    }

    function onLayout(dc) {
        // No XML layout — we draw everything manually in onUpdate
    }

    function onShow() {
        // Pick a new random quote each time the view appears
        Math.srand(Time.now().value());
        _quoteIndex = Math.rand() % QUOTES.size();

        // Start a 1-second repeating timer so the clock updates automatically
        _ticker = new Timer.Timer();
        _ticker.start(method(:onTick), 1000, true);
        Ui.requestUpdate();
    }

    function onHide() {
        // Always stop the timer when the view is not visible to save battery
        if (_ticker != null) {
            _ticker.stop();
            _ticker = null;
        }
    }

    // Called every second by the timer
    function onTick() as Void {
        Ui.requestUpdate();
    }

    function onUpdate(dc) {
        var app = App.getApp();
        var w   = dc.getWidth();
        var h   = dc.getHeight();
        var cx  = w / 2;
        // Safe inset for round watch faces (~15% of screen)
        var insetY = h * 15 / 100;

        // ── Background ───────────────────────────────────────
        dc.setColor(Gfx.COLOR_BLACK, Gfx.COLOR_BLACK);
        dc.clear();

        // ── Title bar ────────────────────────────────────────
        dc.setColor(COLOURS[_quoteIndex], Gfx.COLOR_TRANSPARENT);
        dc.drawText(cx, insetY, Gfx.FONT_SMALL, QUOTES[_quoteIndex].toString(), Gfx.TEXT_JUSTIFY_CENTER);

        if (!app.isSessionActive()) {
            _drawIdleState(dc, w, h, cx, insetY);
        } else {
            _drawActiveState(dc, w, h, cx, app, insetY);
        }
    }

    // ── Idle (no session) ────────────────────────────────────

    hidden function _drawIdleState(dc, w, h, cx, insetY) {
        dc.setColor(Gfx.COLOR_DK_GRAY, Gfx.COLOR_TRANSPARENT);
        dc.drawText(cx, h / 2 - 20, Gfx.FONT_SMALL,
                    "No session", Gfx.TEXT_JUSTIFY_CENTER);

        dc.setColor(0xFF6600, Gfx.COLOR_TRANSPARENT);
        dc.drawText(cx, h / 2 + 10, Gfx.FONT_TINY,
                    "Press Start", Gfx.TEXT_JUSTIFY_CENTER);
    }

    // ── Active session ───────────────────────────────────────

    hidden function _drawActiveState(dc, w, h, cx, app, insetY) {
        // RECORDING label + elapsed clock on the same row
        var rowY    = insetY + 30;
        var leftX   = w * 20 / 100;
        var rightX  = w * 80 / 100;

        dc.setColor(Gfx.COLOR_RED, Gfx.COLOR_TRANSPARENT);
        dc.drawText(leftX, rowY, Gfx.FONT_XTINY, "RECORDING", Gfx.TEXT_JUSTIFY_LEFT);

        var elapsed = _formatSec(Time.now().subtract(app.getSessionStart()).value());
        dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_TRANSPARENT);
        dc.drawText(rightX, rowY, Gfx.FONT_XTINY, elapsed, Gfx.TEXT_JUSTIFY_RIGHT);

        // Current time
        var clockTime = Sys.getClockTime();
        var timeStr   = clockTime.hour.format("%02d") + ":" + clockTime.min.format("%02d");
        dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_TRANSPARENT);
        dc.drawText(cx, h / 20 + 12, Gfx.FONT_XTINY, timeStr, Gfx.TEXT_JUSTIFY_CENTER);

        // Problem count
        var count = app.getProblemCount();
        var label = count == 1 ? "1 problem" : count.toString() + " problems";
        dc.setColor(0xFF6600, Gfx.COLOR_TRANSPARENT);
        dc.drawText(cx, h / 4 + 42, Gfx.FONT_XTINY,
                    label, Gfx.TEXT_JUSTIFY_CENTER);

        // Completed vs attempted sub-count
        var problems   = app.getProblems();
        var completed  = 0;
        for (var i = 0; i < problems.size(); i++) {
            if (problems[i]["outcome"].equals(OUTCOME_COMPLETED)) { completed++; }
        }
        var attempted = problems.size() - completed;

        dc.setColor(Gfx.COLOR_DK_GRAY, Gfx.COLOR_TRANSPARENT);
        dc.drawText(cx, h / 2, Gfx.FONT_SMALL,
                    completed.toString() + " sent  " + attempted.toString() + " tried",
                    Gfx.TEXT_JUSTIFY_CENTER);

        // Button hints at bottom — pulled up to stay within circular safe area
        dc.setColor(Gfx.COLOR_DK_GRAY, Gfx.COLOR_TRANSPARENT);
        dc.drawText(cx, h - insetY - 44, Gfx.FONT_XTINY,
                    "START: add problem", Gfx.TEXT_JUSTIFY_CENTER);
        dc.drawText(cx, h - insetY - 30, Gfx.FONT_XTINY,
                    "DOWN: end & save", Gfx.TEXT_JUSTIFY_CENTER);
        dc.drawText(cx, h - insetY - 16, Gfx.FONT_XTINY,
                    "BACK: discard", Gfx.TEXT_JUSTIFY_CENTER);
    }

    // ── Helpers ──────────────────────────────────────────────

    // Converts a raw second count into "MM:SS" (wraps at 99:59)
    hidden function _formatSec(totalSec) {
        var m = (totalSec / 60).toNumber();
        var s = (totalSec % 60).toNumber();
        if (m > 99) { m = 99; }
        return m.format("%02d") + ":" + s.format("%02d");
    }
}

// ============================================================
//  HomeDelegate
// ============================================================
class HomeDelegate extends Ui.BehaviorDelegate {

    function initialize() {
        BehaviorDelegate.initialize();
    }

    // SELECT:
    //   - Idle    → start session
    //   - Active  → open grade picker
    function onSelect() {
        var app = App.getApp();

        if (!app.isSessionActive()) {
            app.startSession();
            Ui.requestUpdate();
        } else {
            var pickerView = new GradePickerView(0);
            Ui.pushView(
                pickerView,
                new GradePickerDelegate(0, pickerView),
                Ui.SLIDE_LEFT
            );
        }
        return true;
    }

    // DOWN (onNextPage): show save confirmation if session is active
    function onNextPage() {
        var app = App.getApp();
        if (app.isSessionActive()) {
            Ui.pushView(
                new Ui.Confirmation("Save & upload?"),
                new SaveConfirmDelegate(),
                Ui.SLIDE_UP
            );
        }
        return true;
    }

    // BACK: offer to discard the session while one is running
    function onBack() {
        if (App.getApp().isSessionActive()) {
            Ui.pushView(
                new Ui.Confirmation("Discard session?"),
                new DiscardConfirmDelegate(),
                Ui.SLIDE_UP
            );
            return true;
        }
        return false;    // let the OS handle it (exit app)
    }
}

// ============================================================
//  SaveConfirmDelegate  —  "Save & upload?" yes/no
// ============================================================
class SaveConfirmDelegate extends Ui.ConfirmationDelegate {

    function initialize() {
        ConfirmationDelegate.initialize();
    }

    function onResponse(response) {
        if (response == Ui.CONFIRM_YES) {
            // endSession() handles stop → save → upload → switchToView(SummaryView)
            App.getApp().endSession();
        }
        // If NO: just fall back — the Confirmation pops itself
        return true;
    }
}

// ============================================================
//  DiscardConfirmDelegate  —  "Discard session?" yes/no
// ============================================================
class DiscardConfirmDelegate extends Ui.ConfirmationDelegate {

    function initialize() {
        ConfirmationDelegate.initialize();
    }

    function onResponse(response) {
        if (response == Ui.CONFIRM_YES) {
            App.getApp().discardSession();
            Ui.requestUpdate();
        }
        // If NO: Confirmation pops itself, session continues
        return true;
    }
}
