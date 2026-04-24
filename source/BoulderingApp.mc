// ============================================================
//  BoulderingApp.mc
//  Entry point for the Garmin Connect IQ Bouldering Tracker.
//
//  Responsibilities:
//    - Owns all session and problem state
//    - Controls ActivityRecording session lifecycle
//    - Builds the JSON payload and POSTs it on save (once only)
//    - Navigates to SummaryView after saving
//
// ============================================================

using Toybox.Application as App;
using Toybox.Application.Storage;
using Toybox.WatchUi as Ui;
using Toybox.ActivityRecording;
using Toybox.Communications as Comm;
using Toybox.System as Sys;
using Toybox.Time;
using Toybox.Lang;

// ── Persistent upload queue key ───────────────────────────────
const STORAGE_KEY_PENDING = "pendingUploads";

// ── API defaults (used when getProperty returns null on sideloaded builds) ─
const DEFAULT_API_ENDPOINT = "https://owain.codes/umbraco/api/bouldering/postsession";
const DEFAULT_API_KEY      = "";

// ── Grade names (index matches GRADE_COLORS in GradePickerView) ─
var GRADES = [
    "Grey",   // 0
    "Green",  // 1
    "Orange", // 2
    "Blue",   // 3
    "Purple", // 4
    "Pink",   // 5
    "Red",    // 6
    "White",  // 7
    "Yellow", // 8
    "Black"   // 9
];

// ── Outcome string constants ──────────────────────────────────
const OUTCOME_COMPLETED = "Completed";
const OUTCOME_ATTEMPTED = "Attempted";

// ============================================================
//  BoulderingApp
// ============================================================
class BoulderingApp extends App.AppBase {

    // ActivityRecording session (null when not recording)
    hidden var _arSession = null;

    // Session wall-clock state
    hidden var _sessionActive = false;
    hidden var _sessionStart  = null;   // Time.Moment  (set by Time.now())

    // Problem-in-progress
    hidden var _problemActive    = false;
    hidden var _problemGradeIdx  = 0;
    hidden var _problemStart     = null; // Time.Moment

    // Completed problem log — each entry is a Dictionary:
    //   { "grade": String, "outcome": String, "durationSec": Number }
    hidden var _problems = [];

    // ── AppBase lifecycle ────────────────────────────────────

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state) {
        // Retry any uploads that failed in a previous session
        flushPendingUploads();
    }

    function onStop(state) {
        // App exited without saving — clean up gracefully without uploading
        if (_arSession != null) {
            _arSession.stop();
            _arSession = null;
        }
    }

    function getInitialView() {
        return [new HomeView(), new HomeDelegate()];
    }

    // ── Session control ──────────────────────────────────────

    function startSession() {
        if (_sessionActive) { return; }

        _arSession = ActivityRecording.createSession({
            :name     => "TCH Bouldering",
            :sport    => Toybox.Activity.SPORT_ROCK_CLIMBING,
            :subtype  => Toybox.Activity.SUB_SPORT_BOULDERING,
            
        });
        _arSession.start();

        _sessionStart  = Time.now();
        _sessionActive = true;
        _problems      = [];
    }

    // Called when user confirms "Save & upload".
    // Stops recording, saves the FIT file, builds payload, uploads,
    // then pushes the SummaryView so the user sees their stats.
    function endSession() {
        if (!_sessionActive) { return; }

        // Auto-log any problem still running as Attempted
        if (_problemActive) {
            logCurrentProblem(OUTCOME_ATTEMPTED);
        }

        // Snapshot the problem list before clearing state,
        // so SummaryView can display it independently.
        var finalProblems = _problems;

        // Build payload before clearing _sessionStart
        var payload = _buildPayload(finalProblems);

        // Stop and persist the FIT activity file
        _arSession.stop();
        _arSession.save();
        _arSession = null;

        _sessionActive = false;
        _problems      = [];
        _sessionStart  = null;

        // Persist to storage first, then attempt upload
        _savePendingUpload(payload);
        flushPendingUploads();

        // Navigate to summary screen
        Ui.switchToView(
            new SummaryView(finalProblems),
            new SummaryDelegate(),
            Ui.SLIDE_UP
        );
    }

    function discardSession() {
        if (_arSession != null) {
            _arSession.stop();
            _arSession = null;
        }
        _sessionActive    = false;
        _problemActive    = false;
        _problems         = [];
        _sessionStart     = null;
        _problemStart     = null;
    }

    // ── Problem control ──────────────────────────────────────

    function startProblem(gradeIdx) {
        if (!_sessionActive || _problemActive) { return; }

        _problemActive   = true;
        _problemGradeIdx = gradeIdx;
        _problemStart    = Time.now();
    }

    function logCurrentProblem(outcome) {
        if (!_problemActive) { return; }

        var durSec = Time.now().subtract(_problemStart).value();

        _problems.add({
            "grade"       => GRADES[_problemGradeIdx],
            "outcome"     => outcome,
            "durationSec" => durSec
        });

        _problemActive = false;
        _problemStart  = null;
    }

    function clearCurrentProblem() {
        _problemActive = false;
        _problemStart  = null;
    }

    // ── Upload queue (persisted to Storage) ────────────────────

    // Save a payload to the persistent queue so it survives app exit
    hidden function _savePendingUpload(payload) {
        var queue = Storage.getValue(STORAGE_KEY_PENDING);
        if (queue == null) {
            queue = [];
        }
        queue.add(payload);
        Storage.setValue(STORAGE_KEY_PENDING, queue);
    }

    // Remove the first (oldest) entry after a successful upload
    hidden function _removePendingUpload() {
        var queue = Storage.getValue(STORAGE_KEY_PENDING);
        if (queue == null || queue.size() == 0) { return; }

        // Rebuild array without the first element
        var updated = [];
        for (var i = 1; i < queue.size(); i++) {
            updated.add(queue[i]);
        }
        if (updated.size() == 0) {
            Storage.deleteValue(STORAGE_KEY_PENDING);
        } else {
            Storage.setValue(STORAGE_KEY_PENDING, updated);
        }
    }

    // Attempt to upload the next pending payload if phone is connected
    function flushPendingUploads() {
        if (!Sys.getDeviceSettings().phoneConnected) { return; }

        var queue = Storage.getValue(STORAGE_KEY_PENDING);
        if (queue == null || queue.size() == 0) { return; }

        _sendToAPI(queue[0]);
    }

    // Number of sessions awaiting upload (for views to query)
    function getPendingUploadCount() {
        var queue = Storage.getValue(STORAGE_KEY_PENDING);
        return (queue != null) ? queue.size() : 0;
    }

    // ── Payload builder ───────────────────────────────────────

    hidden function _buildPayload(problems) {
        // Total session duration — measured from sessionStart to now
        var totalSec = _sessionStart != null
            ? Time.now().subtract(_sessionStart).value()
            : 0;

        var completed = 0;
        var attempted = 0;
        for (var i = 0; i < problems.size(); i++) {
            if (problems[i]["outcome"].equals(OUTCOME_COMPLETED)) { completed++; }
            else { attempted++; }
        }

        var settings = Sys.getDeviceSettings();

        return {
            "deviceId"         => settings.uniqueIdentifier.toString(),
            "sessionDate"      => _sessionStart != null
                                      ? _sessionStart.value()
                                      : Time.now().value(),
            "totalDurationSec" => totalSec,
            "totalProblems"    => problems.size(),
            "completed"        => completed,
            "attempted"        => attempted,
            "problems"         => problems
        };
    }

    // ── API upload ────────────────────────────────────────────

    hidden function _sendToAPI(payload) {
        var endpoint = App.getApp().getProperty("ApiEndpoint") as Lang.String;
        if (endpoint == null || endpoint.equals("")) { endpoint = DEFAULT_API_ENDPOINT; }

        var apiKey = App.getApp().getProperty("ApiKey") as Lang.String;
        if (apiKey == null || apiKey.equals("")) { apiKey = DEFAULT_API_KEY; }
        var options = {
            :method       => Comm.HTTP_REQUEST_METHOD_POST,
            :headers      => {
                "Content-Type" => "application/json",
                "X-Api-Key"    => apiKey
            },
            :responseType => Comm.HTTP_RESPONSE_CONTENT_TYPE_JSON
        };

        Comm.makeWebRequest(endpoint, payload, options, method(:onApiResponse));
    }

    function onApiResponse(responseCode as Toybox.Lang.Number, data as Toybox.Lang.Dictionary or Toybox.Lang.String or Null) as Void {
        Storage.setValue("lastResponseCode", responseCode);
        if (responseCode == 200 || responseCode == 201) {
            Sys.println("Bouldering session uploaded OK (" + responseCode.toString() + ")");
            // Remove the successfully sent payload and try the next one
            _removePendingUpload();
            flushPendingUploads();
        } else {
            // Data stays in Storage — will retry on next app launch
            Sys.println("Upload failed – HTTP " + responseCode.toString());
        }
        Ui.requestUpdate();
    }

    // ── Getters (used by views) ───────────────────────────────

    function isSessionActive()     { return _sessionActive; }
    function isProblemActive()     { return _problemActive; }
    function getProblemCount()     { return _problems.size(); }
    function getSessionStart()     { return _sessionStart; }
    function getCurrentGradeIdx()  { return _problemGradeIdx; }
    function getCurrentGrade()     { return GRADES[_problemGradeIdx]; }
    function getProblemStart()     { return _problemStart; }
    function getProblems()         { return _problems; }
}
