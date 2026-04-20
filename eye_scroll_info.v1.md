# eye_scroll2.html - Info v1

## 1. What the file is

`eye_scroll2.html` is a single-file browser demo for **hands-free scrolling by eye/face movement**.

Main idea:

- shows a Hebrew mobile-style UI
- asks for access to the **front camera**
- tries to detect face/eye direction
- scrolls content **up** when the gaze/face goes toward the top zone
- scrolls content **down** when the gaze/face goes toward the bottom zone

It is designed mainly for:

- phone/mobile-like full-screen use
- Hebrew RTL layout
- experimental eye/face-controlled scrolling

---

## 2. What it does

### UI flow

The page contains:

- **Start screen**
  - title: `גלילה בעיניים`
  - button: `הפעל מצלמה`
- **Permission screen**
  - shown if camera access fails
- **Calibration screen**
  - 3-second countdown before camera starts
- **Status bar**
  - shows current state like waiting, tracking, scroll up, scroll down
- **Top and bottom scroll zones**
  - top zone means scroll up
  - bottom zone means scroll down
- **Generated article cards**
  - sample Hebrew content cards are created by JavaScript

### Tracking behavior

The script tries this order:

1. **MediaPipe FaceMesh**
   - loaded from jsDelivr CDN
   - uses facial landmarks
   - mainly uses:
     - iris center landmarks when available
     - otherwise nose tip
   - creates a normalized vertical gaze value

2. **Simple fallback tracking**
   - if MediaPipe fails but camera works
   - uses basic canvas brightness/face-position approximation
   - less accurate

3. **Touch fallback**
   - if camera permission fails
   - long press near top/bottom scroll zones scrolls content

### Scrolling logic

- top zone = scroll upward
- bottom zone = scroll downward
- middle zone = no scrolling
- the deeper into the zone, the faster the scroll
- content is moved using:

```javascript
content.style.transform = `translateY(${-scrollY}px)`;
```

### Visual indicators

- eye cursor shown in center horizontally
- gaze bar follows current gaze Y
- status text changes color/state
- top zone uses cyan-like accent
- bottom zone uses pink/red-like accent

---

## 3. Important technical notes

### External dependencies

The file depends on internet access for:

- Google Font:
  - `Heebo`
- MediaPipe script:
  - `https://cdn.jsdelivr.net/npm/@mediapipe/face_mesh@0.4/face_mesh.js`

So without internet:

- fonts may fall back
- FaceMesh will not load
- simple tracking or permission fallback may be used instead

### Camera requirements

The page uses:

```javascript
navigator.mediaDevices.getUserMedia(...)
```

That usually works best on:

- `https://`
- or `http://localhost`

It may not work reliably from direct `file://` opening, depending on browser security rules.

### One implementation mismatch

The code comment says:

- `FALLBACK: touch/mouse hold`

But in practice the file only implements:

- `touchstart`
- `touchmove`
- `touchend`

I do **not** see mouse fallback handlers like:

- `mousedown`
- `mousemove`
- `mouseup`

So desktop mouse fallback is currently missing.

### Resize detail

The page recalculates max scroll on resize, but some values like:

- `screenH`
- `ZONE_PX`

are calculated once and not fully recomputed after resize.

So after major resizing or orientation changes, behavior may become less accurate.

---

## 4. How to test it

## Recommended test method

Use a local web server instead of opening the file directly.

### Option A - Python

From the folder:

```powershell
cd C:\Git\zTmpProjects
python -m http.server 8000
```

Then open:

```text
http://localhost:8000/eye_scroll2.html
```

### Option B - VS Code Live Server

- open the folder in VS Code
- install/use Live Server
- launch `eye_scroll2.html`

### Option C - any local static server

Any local server is fine as long as the page opens from `localhost`.

---

## 5. Manual test steps

### Test 1 - Basic page load

1. open the page
2. verify the Hebrew start screen appears
3. verify the button `הפעל מצלמה` is visible

Expected:

- dark themed UI
- top and bottom scroll zones
- sample content cards exist

### Test 2 - Camera permission success

1. click `הפעל מצלמה`
2. allow camera access
3. wait through calibration countdown

Expected:

- permission dialog appears
- calibration screen shows countdown
- then tracking starts
- status changes to eye tracking mode

### Test 3 - Scroll up/down by gaze or face movement

1. move face/gaze upward
2. move face/gaze downward

Expected:

- upward movement scrolls toward top
- downward movement scrolls toward bottom
- cursor and gaze bar move visually
- status text updates

### Test 4 - MediaPipe failure fallback

Simulate network failure or block CDN.

Expected:

- camera may still work
- simple tracking mode may start
- status may show:
  - `👁 מצב פשוט`

### Test 5 - Permission denied fallback

1. block camera permission
2. reopen page

Expected:

- permission screen appears
- touch fallback mode is enabled
- long press near top/bottom zones scrolls content

### Test 6 - Mobile test

Best tested on:

- Android Chrome
- iPhone Safari

Expected:

- camera prompt
- touch fallback is relevant
- full-screen mobile behavior feels closer to intended design

---

## 6. Quick functional summary

In short, the file is a:

- **single-page eye/face scrolling prototype**
- **camera-based experimental UI**
- **Hebrew RTL demo**
- **mobile-oriented interaction concept**

It does **not** perform true hardware-grade eye tracking.
It uses:

- FaceMesh landmarks if available
- otherwise a simpler face-position approximation

So it is best described as:

**gaze-like / face-movement scrolling demo**

---

## 7. Suggested quick checks

If it does not work:

1. use `localhost`, not direct file open
2. make sure camera permission is allowed
3. make sure internet is available for MediaPipe CDN
4. test on a phone
5. check browser console for errors

---

## 8. Files inspected

- `C:\Git\zTmpProjects\eye_scroll2.html`

