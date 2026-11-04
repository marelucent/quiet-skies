import QtQuick 2.4
import Eos.Window 0.1

// Dusk Murmuration - one flock of starlings over a reedbed, under a winter
// dusk that deepens into night and back. Each bird heeds only its nearest
// few neighbours: keep a little room, match their heading, drift towards
// them. Now and then a falcon cuts through and the flock flinches away.
// Made by Catherine & Claude, 28 Oct 2026.

WebOSWindow {
    id: win

    width: 1920
    height: 1080
    windowType: "_WEBOS_WINDOW_TYPE_SCREENSAVER"
    appId: "com.webos.app.screensaver"
    title: "Screen Saver"
    visible: true
    color: "black"

    property int level: __TVWEB_LEVEL__

    // ---- time
    property real t: 0                                  // seconds since start
    property real t0: Math.random() * 1200              // random place in the dusk cycle
    property real cycle: 1200                           // dusk -> night -> dusk, seconds
    property real night: 0                              // 0 dusk .. 0.85 night, updated slowly

    // ---- the flock
    property int count: 160
    property var px: []
    property var py: []
    property var vx: []
    property var vy: []
    property real minSpeed: 2.6
    property real maxSpeed: 3.9
    property real maxTurn: 0.065                        // radians a frame: birds bank, flies jink
    property real maxAccel: 0.16
    property real reedTop: 930                          // birds stay above this

    // ---- the falcon
    property bool fActive: false
    property real fx: -100
    property real fy: 300
    property real fvx: 0
    property real fvy: 0
    property real fSeekUntil: 0
    property real fPhase: 0
    property int fFrame: 0

    // ---- the shimmer: starlings are glossy, so a bird flashes paler when it
    // banks, or when it is heading into the low light. Neighbours turn
    // together, so the flash sweeps across the flock like a shoal of fish.
    property var pal: []                                // 8 shades, dark to glint
    property var lv: []                                 // each bird's current shade
    property var tr: []                                 // each bird's smoothed bank
    property real lightAngle: 3.4                       // heading that faces the low sun (radians)
    property color sheenDusk: "#8e9088"
    property color sheenNight: "#2c3442"
    property real nextFalcon: 50 + Math.random() * 60

    // ---- winter dusk palette (top, middle, low sky, horizon) and night
    property color duskTop: "#3e4a5d"
    property color duskMid: "#6f7b8d"
    property color duskLow: "#a8a28c"
    property color duskHorizon: "#d8c79a"
    property color nightTop: "#04070c"
    property color nightMid: "#0b111b"
    property color nightLow: "#161e2b"
    property color nightHorizon: "#222a38"
    property color birdDusk: "#0c0f15"
    property color birdNight: "#05070b"

    function mix(a, b, k) {
        return Qt.rgba(a.r + (b.r - a.r) * k, a.g + (b.g - a.g) * k, a.b + (b.b - a.b) * k, 1);
    }

    // ---- the sky
    Rectangle {
        id: sky
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0;  color: win.mix(win.duskTop, win.nightTop, win.night) }
            GradientStop { position: 0.5;  color: win.mix(win.duskMid, win.nightMid, win.night) }
            GradientStop { position: 0.8;  color: win.mix(win.duskLow, win.nightLow, win.night) }
            GradientStop { position: 0.9;  color: win.mix(win.duskHorizon, win.nightHorizon, win.night) }
            GradientStop { position: 1.0;  color: win.mix(win.duskLow, win.nightLow, win.night) }
        }
    }

    // ---- a few stars, as night comes
    Repeater {
        model: 45
        Rectangle {
            width: 2; height: 2; radius: 1
            color: "#dfe6f0"
            x: Math.random() * 1920
            y: Math.random() * 520
            opacity: Math.max(0, (win.night - 0.3) * 2.6) * (0.4 + Math.random() * 0.6)
        }
    }

    // ---- the flock
    Repeater {
        id: flock
        model: win.count
        Rectangle {
            width: 6; height: 2
            radius: 1
            antialiasing: true
            color: "#0c0f15"        // set each frame from the shimmer palette
            x: -50; y: -50
        }
    }

    // ---- the falcon: a body, a tail, and two long pointed wings that beat
    // and glide; folded back tight when it stoops
    Canvas {
        id: falcon
        width: 46; height: 34
        visible: win.fActive
        x: win.fx - width / 2
        y: win.fy - height / 2
        antialiasing: true
        property real spread: 0.8
        onPaint: {
            var c = getContext("2d");
            c.reset();
            c.fillStyle = "#0a0c11";
            var s = spread;
            // tail
            c.beginPath();
            c.moveTo(14, 17); c.lineTo(3, 14.5); c.lineTo(3, 19.5); c.closePath(); c.fill();
            // body and head
            c.beginPath();
            c.ellipse(12, 14.5, 26, 5); c.fill();
            // wings: from the shoulder out to a swept-back point
            var tipX = 25 - 15 * (1 - s), reach = 15 * s + 2;
            c.beginPath();
            c.moveTo(29, 16); c.lineTo(tipX, 17 - reach); c.lineTo(19, 16); c.closePath(); c.fill();
            c.beginPath();
            c.moveTo(29, 18); c.lineTo(tipX, 17 + reach); c.lineTo(19, 18); c.closePath(); c.fill();
        }
    }

    // ---- the reedbed, drawn once
    Canvas {
        id: reeds
        x: 0; y: 900
        width: 1920; height: 180
        onPaint: {
            var c = getContext("2d");
            c.reset();
            c.fillStyle = "#07090d";
            c.fillRect(0, 120, 1920, 60);
            c.strokeStyle = "#07090d";
            c.lineCap = "round";
            for (var i = 0; i < 900; i++) {
                var x = Math.random() * 1920;
                var h = 30 + Math.random() * 95 + 25 * Math.sin(x / 140);
                var lean = (Math.random() - 0.5) * 18;
                c.lineWidth = 1 + Math.random() * 1.6;
                c.beginPath();
                c.moveTo(x, 180);
                c.quadraticCurveTo(x + lean * 0.3, 180 - h * 0.6, x + lean, 180 - h);
                c.stroke();
                if (Math.random() < 0.12) {
                    c.beginPath();
                    c.ellipse(x + lean - 2, 180 - h - 9, 4, 12);
                    c.fillStyle = "#07090d";
                    c.fill();
                }
            }
        }
    }

    // dims the whole picture at the Dim level
    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: win.level > 0 ? 0 : 0.35
    }

    // ---- setting off
    Component.onCompleted: {
        var cx = 400 + Math.random() * 1100, cy = 400 + Math.random() * 200;
        var a0 = Math.random() * Math.PI * 2;
        var x = [], y = [], u = [], w = [];
        for (var i = 0; i < count; i++) {
            x.push(cx + (Math.random() - 0.5) * 260);
            y.push(cy + (Math.random() - 0.5) * 160);
            var a = a0 + (Math.random() - 0.5) * 0.8;
            u.push(Math.cos(a) * 3.2);
            w.push(Math.sin(a) * 3.2);
        }
        px = x; py = y; vx = u; vy = w;
        var l = [], r = [];
        for (i = 0; i < count; i++) { l.push(-1); r.push(0); }
        lv = l; tr = r;
        updateSky();
    }

    function updateSky() {
        var p = ((t + t0) % cycle) / cycle;
        // lingers at dusk, dips only into a gentle half-dark, never too dark to see the birds
        night = 0.6 * Math.pow(0.5 - 0.5 * Math.cos(2 * Math.PI * p), 1.6);
        // the shimmer palette follows the light: dark bird to glint
        var base = mix(birdDusk, birdNight, night), sheen = mix(sheenDusk, sheenNight, night);
        var pl = [];
        for (var s = 0; s < 8; s++) pl.push(mix(base, sheen, Math.pow(s / 7, 1.4)));
        pal = pl;
        var l = lv;
        for (var i = 0; i < l.length; i++) l[i] = -1;    // repaint every bird
    }

    // ---- one step of the flock
    function step() {
        var n = count, W = 1920, H = reedTop;
        var x = px, y = py, u = vx, w = vy;
        var cs = 60, cols = 34, grid = {};
        var i, j, k;

        for (i = 0; i < n; i++) {
            k = Math.floor(x[i] / cs) + Math.floor(y[i] / cs) * cols;
            if (grid[k]) grid[k].push(i); else grid[k] = [i];
        }

        // steady pull together: a flock changes shape by turning, not by swelling
        var coh = 0.0019;
        // a wandering point the whole flock leans towards, in long sweeping
        // arcs, kept to the lower two-thirds of the sky where the light is
        var tx = W * (0.5 + 0.36 * Math.sin(t * 0.083 + 1.3));
        var ty = H * (0.56 + 0.16 * Math.sin(t * 0.131 + 0.4));

        // the falcon
        var cxs = 0, cys = 0;
        for (i = 0; i < n; i++) { cxs += x[i]; cys += y[i]; }
        cxs /= n; cys /= n;
        if (!fActive && t > nextFalcon) {
            // comes in high from one side, beating its wings
            var left = Math.random() < 0.5;
            fx = left ? -60 : W + 60;
            fy = 60 + Math.random() * 220;
            fvx = left ? 6 : -6;
            fvy = 0.6;
            fSeekUntil = t + 4.5;
            fActive = true;
        }
        if (fActive) {
            var fa = Math.atan2(fvy, fvx), fsp = Math.sqrt(fvx * fvx + fvy * fvy), want;
            var stooping = t < fSeekUntil;
            if (stooping) {
                // the stoop: wings folded, dropping on the flock, gathering speed
                want = Math.atan2(cys - fy, cxs - fx);
                fsp = Math.min(12, fsp + 0.12);
            } else {
                // the pull-up: climbs away and out, beating again, slowing
                want = Math.atan2(-260 - fy, (fvx >= 0 ? W + 300 : -300) - fx);
                fsp = Math.max(6.5, fsp - 0.06);
            }
            // never into the reeds
            if (fy > reedTop - 220) want = Math.atan2(-1, fvx >= 0 ? 1 : -1);
            var fda = want - fa;
            if (fda > Math.PI) fda -= 2 * Math.PI; else if (fda < -Math.PI) fda += 2 * Math.PI;
            var ftl = stooping ? 0.035 : 0.05;
            fa += Math.max(-ftl, Math.min(ftl, fda));
            fvx = Math.cos(fa) * fsp; fvy = Math.sin(fa) * fsp;
            fx += fvx; fy += fvy;
            falcon.rotation = fa * 57.2958;
            // wings: tucked in the stoop, a strong beat otherwise
            fPhase += stooping ? 0 : 0.32;
            falcon.spread = stooping ? 0.3 : 0.62 + 0.38 * Math.sin(fPhase);
            fFrame++;
            if (fFrame % 2 === 0) falcon.requestPaint();
            if (fx < -150 || fx > W + 150 || fy < -150 || fy > 1230) {
                fActive = false;
                nextFalcon = t + 70 + Math.random() * 110;
            }
        }

        var R2 = 95 * 95, S2 = 40 * 40, F = 260;
        for (i = 0; i < n; i++) {
            var xi = x[i], yi = y[i];
            var cx0 = Math.floor(xi / cs), cy0 = Math.floor(yi / cs);
            var ax = 0, ay = 0, sx = 0, sy = 0, au = 0, aw = 0, ox = 0, oy = 0, m = 0;
            for (var gy = cy0 - 1; gy <= cy0 + 1 && m < 9; gy++) {
                for (var gx = cx0 - 1; gx <= cx0 + 1 && m < 9; gx++) {
                    var cell = grid[gx + gy * cols];
                    if (!cell) continue;
                    for (var q = 0; q < cell.length && m < 9; q++) {
                        j = cell[q];
                        if (j === i) continue;
                        var dx = x[j] - xi, dy = y[j] - yi, d2 = dx * dx + dy * dy;
                        if (d2 > R2) continue;
                        m++;
                        au += u[j]; aw += w[j];
                        ox += x[j]; oy += y[j];
                        if (d2 < S2) {
                            // a gentle sidestep, not a shove
                            var sd = Math.sqrt(d2) + 0.5, sk = (1 - sd / 40) * 0.3;
                            sx -= dx / sd * sk; sy -= dy / sd * sk;
                        }
                    }
                }
            }
            if (m > 0) {
                // match neighbours' heading strongly: the wave that runs through a flock
                ax += (au / m - u[i]) * 0.075 + (ox / m - xi) * coh;
                ay += (aw / m - w[i]) * 0.075 + (oy / m - yi) * coh;
            }
            // each bird's own small wander, so the flock never settles into lines
            ax += Math.sin(t * 0.9 + i * 1.7) * 0.03;
            ay += Math.cos(t * 0.7 + i * 2.3) * 0.03;
            ax += sx; ay += sy;
            // towards the flock's middle, gently, so stragglers come home
            ax += (cxs - xi) * 0.00025; ay += (cys - yi) * 0.00025;
            // and the wandering point
            ax += (tx - xi) * 0.0003; ay += (ty - yi) * 0.0003;
            // soft edges: the top of the sky pushes harder, keep above the reeds
            if (xi < 160) ax += 0.12; else if (xi > W - 160) ax -= 0.12;
            if (yi < 240) ay += 0.03 + (240 - yi) * 0.0011;
            else if (yi > H - 160) ay -= 0.16;
            // the falcon
            var fear = 0;
            if (fActive) {
                var fdx = xi - fx, fdy = yi - fy, fd = Math.sqrt(fdx * fdx + fdy * fdy) + 1;
                // frightened birds turn away and speed up; their neighbours copy
                // the turn, so the flinch runs through the flock as a wave
                if (fd < F) { fear = 1 - fd / F; ax += fdx / fd * fear * 0.4; ay += fdy / fd * fear * 0.4; }
            }
            // a bird can only push so hard - a little more when frightened
            var acap = maxAccel * (1 + fear * 1.5);
            var am = Math.sqrt(ax * ax + ay * ay);
            if (am > acap) { ax = ax / am * acap; ay = ay / am * acap; }
            var ou = u[i], ow = w[i];
            var nu = ou + ax, nw = ow + ay;
            // and can only bank so sharply: this is what makes them swoop
            var a1 = Math.atan2(ow, ou), a2 = Math.atan2(nw, nu), da = a2 - a1;
            if (da > Math.PI) da -= 2 * Math.PI; else if (da < -Math.PI) da += 2 * Math.PI;
            var tl = maxTurn * (1 + fear * 2);
            var sp = Math.sqrt(nu * nu + nw * nw);
            if (da > tl || da < -tl) {
                var na = a1 + (da > 0 ? tl : -tl);
                nu = Math.cos(na) * sp; nw = Math.sin(na) * sp;
                da = da > 0 ? tl : -tl;
            }
            // how hard this bird is banking, smoothed: wings tilt to the light
            tr[i] = tr[i] * 0.82 + Math.abs(da) / maxTurn * 0.18;
            var lim = maxSpeed * (1 + fear * 0.6);
            if (sp > lim) { nu = nu / sp * lim; nw = nw / sp * lim; }
            else if (sp < minSpeed) { nu = nu / (sp + 0.001) * minSpeed; nw = nw / (sp + 0.001) * minSpeed; }
            u[i] = nu; w[i] = nw;
        }

        var P = pal, L = lv, T = tr, LA = lightAngle;
        for (i = 0; i < n; i++) {
            x[i] += u[i]; y[i] += w[i];
            var b = flock.itemAt(i);
            if (b) {
                var hd = Math.atan2(w[i], u[i]);
                b.x = x[i] - 3;
                b.y = y[i] - 1;
                b.rotation = hd * 57.2958;
                // the glint: heading into the low light, or banking hard
                var face = Math.cos(hd - LA);
                face = face > 0 ? face * face * face * face : 0;
                var g = 0.6 * face + 0.55 * Math.min(1, T[i]);
                var s8 = Math.min(7, Math.round(g * 7));
                if (s8 !== L[i]) { b.color = P[s8]; L[i] = s8; }
            }
        }
    }

    Timer {
        interval: 33; running: true; repeat: true
        onTriggered: { win.t += 0.033; win.step(); }
    }
    Timer {
        interval: 2000; running: true; repeat: true
        onTriggered: win.updateSky()
    }
}
