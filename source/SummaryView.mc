// ============================================================
//  SummaryView.mc
//  Post-session summary shown after the user confirms save.
//
//  Fix from v1: This view was never navigated to (endSession()
//  didn't call switchToView).  That is now fixed in
//  BoulderingApp.endSession() which calls:
//    Ui.switchToView(new SummaryView(finalProblems), ...)
//
//  Layout:
//    - "Session saved!" / "Uploading…" header
//    - Total problems  |  Sent count  |  Tried count
//    - Per-grade breakdown: coloured dots, one column per grade used
//    - "BACK to exit" footer
// ============================================================

using Toybox.Application as App;
using Toybox.Application.Storage;
using Toybox.WatchUi as Ui;
using Toybox.Graphics as Gfx;
using Toybox.System as Sys;

// ============================================================
//  SummaryView
// ============================================================
class SummaryView extends Ui.View {

    hidden var _problems;   // snapshot passed in from endSession()

    function initialize(problems) {
        View.initialize();
        _problems = problems;
    }

    function onLayout(dc) {}

    function onShow() { Ui.requestUpdate(); }

    function onUpdate(dc) {
        var w  = dc.getWidth();
        var h  = dc.getHeight();
        var cx = w / 2;
        var insetY = h * 15 / 100;
        var insetX = w * 12 / 100;

        dc.setColor(Gfx.COLOR_BLACK, Gfx.COLOR_BLACK);
        dc.clear();

        // ── Header ───────────────────────────────────────────
        dc.setColor(0xFF6600, Gfx.COLOR_TRANSPARENT);
        dc.drawText(cx, insetY, Gfx.FONT_SMALL, "Session Saved!", Gfx.TEXT_JUSTIFY_CENTER);

        // Dynamic upload status
        var pending = App.getApp().getPendingUploadCount();
        var lastCode = Storage.getValue("lastResponseCode");
        var statusText;
        var statusColor;
        if (pending == 0) {
            statusText  = "Uploaded to cloud";
            statusColor = Gfx.COLOR_GREEN;
        } else if (lastCode != null && lastCode != 200 && lastCode != 201) {
            statusText  = "Upload err " + lastCode.toString();
            statusColor = Gfx.COLOR_RED;
        } else if (Sys.getDeviceSettings().phoneConnected) {
            statusText  = "Uploading...";
            statusColor = 0x555555;
        } else {
            statusText  = "Will upload when synced";
            statusColor = 0x555555;
        }
        dc.setColor(statusColor, Gfx.COLOR_TRANSPARENT);
        dc.drawText(cx, insetY + 22, Gfx.FONT_XTINY, statusText, Gfx.TEXT_JUSTIFY_CENTER);

        // ── Compute totals ────────────────────────────────────
        var total     = _problems.size();
        var completed = 0;
        var attempted = 0;
        for (var i = 0; i < total; i++) {
            if (_problems[i]["outcome"].equals(OUTCOME_COMPLETED)) { completed++; }
            else { attempted++; }
        }

        // ── Stat row: total | sent | tried ───────────────────
        var rowY  = insetY + 40;
        var col1  = cx - w / 4;
        var col2  = cx;
        var col3  = cx + w / 4;

        _drawStat(dc, col1, rowY, total.toString(),      "total");
        _drawStatColored(dc, col2, rowY, completed.toString(),  "sent",  Gfx.COLOR_GREEN);
        _drawStatColored(dc, col3, rowY, attempted.toString(),  "tried", Gfx.COLOR_RED);

        // Divider
        dc.setColor(0x333333, Gfx.COLOR_TRANSPARENT);
        dc.drawLine(insetX, rowY + 36, w - insetX, rowY + 36);

        // ── Per-grade breakdown ───────────────────────────────
        var usedGrades = [];
        for (var gi = 0; gi < GRADES.size(); gi++) {
            var gc = 0;
            var ga = 0;
            for (var pi = 0; pi < _problems.size(); pi++) {
                if (_problems[pi]["grade"].equals(GRADES[gi])) {
                    if (_problems[pi]["outcome"].equals(OUTCOME_COMPLETED)) { gc++; }
                    else { ga++; }
                }
            }
            if (gc + ga > 0) {
                usedGrades.add({
                    "idx"  => gi,
                    "comp" => gc,
                    "att"  => ga
                });
            }
        }

        // Lay out grade dots in a grid — max 5 per row, centred
        var dotAreaTop = rowY + 44;
        var dotSpaceW  = w - insetX * 2;
        var colCount   = usedGrades.size() < 5 ? usedGrades.size() : 5;
        if (colCount == 0) { colCount = 1; }

        var cellW  = dotSpaceW / colCount;
        var dotR   = 10;

        for (var di = 0; di < usedGrades.size(); di++) {
            var col   = di % 5;
            var row   = di / 5;
            var dotCX = insetX + col * cellW + cellW / 2;
            var dotCY = dotAreaTop + row * 36 + 12;

            // Bail out if we'd draw off screen
            if (dotCY + dotR + 12 > h - insetY - 10) { break; }

            var gi    = usedGrades[di]["idx"];
            var gc    = usedGrades[di]["comp"];
            var ga    = usedGrades[di]["att"];
            var gAll  = gc + ga;

            // Dot fill
            dc.setColor(GRADE_COLORS[gi], Gfx.COLOR_TRANSPARENT);
            dc.fillCircle(dotCX, dotCY, dotR);

            // Outline for White / Black
            if (gi == 8 || gi == 9) {
                dc.setColor(0x666666, Gfx.COLOR_TRANSPARENT);
                dc.drawCircle(dotCX, dotCY, dotR);
            }

            // "sent/total" label under dot
            dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_TRANSPARENT);
            dc.drawText(dotCX, dotCY + dotR + 1, Gfx.FONT_XTINY,
                        gc.toString() + "/" + gAll.toString(),
                        Gfx.TEXT_JUSTIFY_CENTER);
        }

        // ── Footer hint ───────────────────────────────────────
        dc.setColor(0x444444, Gfx.COLOR_TRANSPARENT);
        dc.drawText(cx, h - insetY - 6, Gfx.FONT_XTINY,
                    "BACK to exit", Gfx.TEXT_JUSTIFY_CENTER);
    }

    // Draws a big number with a small label below it
    hidden function _drawStat(dc, x, y, value, label) {
        _drawStatColored(dc, x, y, value, label, Gfx.COLOR_WHITE);
    }

    hidden function _drawStatColored(dc, x, y, value, label, color) {
        dc.setColor(color, Gfx.COLOR_TRANSPARENT);
        dc.drawText(x, y, Gfx.FONT_MEDIUM, value, Gfx.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x666666, Gfx.COLOR_TRANSPARENT);
        dc.drawText(x, y + 24, Gfx.FONT_XTINY, label, Gfx.TEXT_JUSTIFY_CENTER);
    }

    function onHide() {}
}

// ============================================================
//  SummaryDelegate
// ============================================================
class SummaryDelegate extends Ui.BehaviorDelegate {

    function initialize() {
        BehaviorDelegate.initialize();
    }

    // BACK on the summary screen exits the app cleanly
    function onBack() {
        Sys.exit();
        return true;
    }
}
