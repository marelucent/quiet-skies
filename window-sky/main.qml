import QtQuick 2.4
import Eos.Window 0.1

// Window Sky - the real night sky behind your wall, drawn from
// the TV's own clock: bright stars and constellations where they truly are
// at this minute, the Moon in its real phase, the Milky Way, a city's glow
// low on the horizon, and now and then a satellite or a meteor.
// Made by Ross, Catherine & Claude, 30 Oct 2026.

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

    // ---- where and which way we look
    // ---- make it your sky: these four lines. The example is Greenwich, looking south.
    property real lat: 51.48            // your latitude
    property real lon: 0.00             // your longitude, east positive
    property real azCentre: 180         // the compass direction the TV "faces" from the sofa (0 N, 90 E, 180 S, 270 W)
    property string place: "Greenwich"  // the name shown in the corner caption
    property real cityGlowAz: -1        // the compass direction of a city's glow on your horizon, or -1 for none
    property real fov: 200              // degrees across the screen
    property real topAlt: 82            // altitude at the top edge
    property real horizonY: 930
    property real timeScale: 1          // 1 = real time; raise to watch the sky wheel

    // ---- state read off the clock
    property real sunAlt: -30
    property real twilight: 0           // 0 full night .. 1 bright twilight
    property real startMs: 0

    // ---- the weather, asked of Open-Meteo for these coordinates every ten minutes
    property bool wxOk: false
    property real wxCloud: 0            // percent
    property real wxRain: 0             // mm in the last hour
    property real wxVis: 20000          // metres
    property real wxWind: 0             // km/h
    property real wxWindDir: 270        // degrees, where it comes from
    property real wxTemp: 0             // C
    property int wxCode: 0              // WMO weather code
    property string wxAt: ""
    // ---- space weather, asked of NOAA's Space Weather Prediction Center every fifteen minutes
    property bool swOk: false
    property real swKp: 0               // planetary K index: 0 quiet .. 9 extreme storm
    property real swWind: 0             // solar wind speed, km/s
    property string swAt: ""            // hour of the Kp reading, UTC
    property real auroraKp: 6           // the Kp at which aurora could really be seen low in the north from your latitude (6 suits southern England; lower further north)
    property real auroraHintKp: 3       // below auroraKp but above this, a faint glow hints at aurora further north (Ross's wish; not visible from here)
    property real swTestKp: -1          // set to e.g. 8 to preview the aurora; -1 = use the real reading
    function fetchSpace() {
        var x1 = new XMLHttpRequest();
        x1.onreadystatechange = function () {
            if (x1.readyState !== 4) return;
            if (x1.status !== 200) { console.log("window-sky: Kp request failed, status " + x1.status); return; }
            try {
                var rows = JSON.parse(x1.responseText);
                var last = rows[rows.length - 1];
                var kp = (last instanceof Array) ? Number(last[1]) : Number(last.Kp);
                var tag = (last instanceof Array) ? String(last[0]) : String(last.time_tag);
                if (isNaN(kp)) throw "no Kp in the last row";
                win.swKp = win.swTestKp >= 0 ? win.swTestKp : kp;
                win.swAt = tag.slice(11, 16);
                win.swOk = true;
                console.log("window-sky: space weather Kp " + kp + " at " + tag);
                aurora.requestPaint();
                hud.requestPaint();
            } catch (e) { console.log("window-sky: Kp parse failed: " + e); }
        };
        x1.open("GET", "https://services.swpc.noaa.gov/products/noaa-planetary-k-index.json");
        x1.send();
        var x2 = new XMLHttpRequest();
        x2.onreadystatechange = function () {
            if (x2.readyState !== 4 || x2.status !== 200) return;
            try {
                var j = JSON.parse(x2.responseText);
                if (j instanceof Array) j = j[j.length - 1];
                var v = Number(j.proton_speed !== undefined ? j.proton_speed : j.WindSpeed);
                if (!isNaN(v)) { win.swWind = v; hud.requestPaint(); }
            } catch (e) { console.log("window-sky: solar wind parse failed: " + e); }
        };
        x2.open("GET", "https://services.swpc.noaa.gov/products/summary/solar-wind-speed.json");
        x2.send();
    }
    Timer { interval: 900000; running: true; repeat: true; onTriggered: win.fetchSpace() }

    function fetchWeather() {
        var xhr = new XMLHttpRequest();
        var url = "https://api.open-meteo.com/v1/forecast?latitude=" + lat + "&longitude=" + lon
                + "&current=temperature_2m,cloud_cover,precipitation,weather_code,visibility,wind_speed_10m,wind_direction_10m&timezone=auto";
        xhr.onreadystatechange = function () {
            if (xhr.readyState !== 4) return;
            if (xhr.status !== 200) { console.log("window-sky: weather request failed, status " + xhr.status); return; }
            try {
                var j = JSON.parse(xhr.responseText);
                var cu = j.current;
                win.wxCloud = Number(cu.cloud_cover);
                win.wxRain = Number(cu.precipitation);
                win.wxVis = Number(cu.visibility);
                win.wxWind = Number(cu.wind_speed_10m);
                win.wxWindDir = Number(cu.wind_direction_10m);
                win.wxTemp = Number(cu.temperature_2m);
                win.wxCode = Number(cu.weather_code);
                win.wxAt = String(cu.time).slice(11, 16);
                win.wxOk = true;
                console.log("window-sky: weather " + win.wxCloud + "% cloud, " + win.wxTemp + "C, rain " + win.wxRain + ", vis " + win.wxVis);
                sky.requestPaint();
                clouds.requestPaint();
                rain.requestPaint();
                hud.requestPaint();
            } catch (e) { console.log("window-sky: weather parse failed: " + e); }
        };
        xhr.open("GET", url);
        xhr.send();
    }
    Timer { interval: 600000; running: true; repeat: true; onTriggered: win.fetchWeather() }

    // ---- a star: [ra hours, dec degrees, magnitude, tint]
    // tint: 0 white-blue, 1 white, 2 yellow, 3 orange-red
    property var stars: [
        // Ursa Major 0-6
        [11.062,61.75,1.8,1],[11.031,56.38,2.4,0],[11.897,53.69,2.4,0],[12.257,57.03,3.3,0],[12.900,55.96,1.8,0],[13.399,54.93,2.2,0],[13.792,49.31,1.9,0],
        // Ursa Minor 7-9
        [2.530,89.26,2.0,2],[14.845,74.16,2.1,3],[15.345,71.83,3.0,1],
        // Cassiopeia 10-14
        [0.153,59.15,2.3,1],[0.675,56.54,2.2,3],[0.945,60.72,2.2,0],[1.430,60.24,2.7,1],[1.907,63.67,3.4,0],
        // Cepheus 15-19
        [21.310,62.59,2.4,1],[21.478,70.56,3.2,0],[23.656,77.63,3.2,2],[22.181,58.20,3.4,2],[22.828,66.20,3.5,2],
        // Draco 20-22
        [17.943,51.49,2.2,3],[17.507,52.30,2.8,2],[14.073,64.38,3.7,1],
        // Orion 23-30
        [5.919,7.41,0.5,3],[5.242,-8.20,0.1,0],[5.419,6.35,1.6,0],[5.533,-0.30,2.2,0],[5.604,-1.20,1.7,0],[5.679,-1.94,1.8,0],[5.796,-9.67,2.1,0],[5.586,9.93,3.4,0],
        // Taurus 31-37
        [4.599,16.51,0.9,3],[5.438,28.61,1.7,0],[3.791,24.10,2.9,0],[4.330,15.63,3.6,2],[5.627,21.14,3.0,0],[4.477,19.18,3.5,2],[4.477,15.87,3.8,1],
        // Gemini 38-42
        [7.577,31.89,1.6,1],[7.755,28.03,1.1,2],[6.629,16.40,1.9,1],[6.732,25.13,3.0,2],[6.383,22.51,2.9,3],
        // Auriga 43-47
        [5.278,46.00,0.1,2],[5.992,44.95,1.9,1],[5.995,37.21,2.6,1],[4.950,33.17,2.7,3],[5.033,43.82,3.0,1],
        // Perseus 48-53
        [3.405,49.86,1.8,2],[3.136,40.96,2.1,0],[3.715,47.79,3.0,0],[3.964,40.01,2.9,0],[3.080,53.51,2.9,2],[3.902,31.88,2.9,0],
        // Andromeda 54-57
        [0.140,29.09,2.1,0],[1.162,35.62,2.1,3],[2.065,42.33,2.1,2],[0.656,30.86,3.3,3],
        // Pegasus 58-61
        [23.063,28.08,2.4,3],[23.079,15.21,2.5,0],[0.220,15.18,2.8,0],[21.736,9.88,2.4,3],
        // Cygnus 62-66
        [20.690,45.28,1.3,1],[20.370,40.26,2.2,2],[20.770,33.97,2.5,2],[19.750,45.13,2.9,0],[19.512,27.96,3.1,2],
        // Lyra 67-69
        [18.616,38.78,0.0,1],[18.835,33.36,3.5,0],[18.982,32.69,3.2,0],
        // Aquila 70-72
        [19.846,8.87,0.8,1],[19.771,10.61,2.7,3],[19.922,6.41,3.7,2],
        // Bootes 73-75
        [14.261,19.18,0.0,3],[14.750,27.07,2.4,2],[13.911,18.40,2.7,2],
        // Leo 76-79
        [10.140,11.97,1.4,0],[11.818,14.57,2.1,1],[10.333,19.84,2.0,2],[11.235,20.52,2.6,1],
        // Canis Major 80-83
        [6.752,-16.72,-1.5,1],[6.977,-28.97,1.5,0],[6.378,-17.96,2.0,0],[7.140,-26.39,1.8,2],
        // Canis Minor 84-85
        [7.655,5.22,0.4,2],[7.453,8.29,2.9,0],
        // Aries 86-87
        [2.120,23.46,2.0,3],[1.911,20.81,2.6,1],
        // Cetus 88-89
        [3.038,4.09,2.5,3],[0.727,-17.99,2.0,2],
        // Fomalhaut 90, Antares 91, Spica 92, Alphard 93
        [22.961,-29.62,1.2,1],[16.490,-26.43,1.0,3],[13.420,-11.16,1.0,0],[9.460,-8.66,2.0,3],
        // Hercules 94-95, Corona Borealis 96, Ophiuchus 97
        [16.504,21.49,2.8,2],[17.244,14.39,3.1,3],[15.578,26.71,2.2,1],[17.582,12.56,2.1,1],
        // Triangulum 98, Delphinus 99-100
        [2.159,34.99,3.0,1],[20.661,15.91,3.8,0],[20.626,14.60,3.6,2],
        // Aquarius 101, Capricornus 102-103
        [22.096,0.32,3.0,2],[21.784,-16.13,2.9,1],[20.350,-14.78,3.6,2],
        // Pisces 104, Eridanus 105, Lepus 106-107
        [1.524,15.35,3.8,2],[5.131,-5.09,2.8,0],[5.545,-17.82,2.6,0],[5.471,-20.76,2.8,1],
        // Monoceros/Puppis fillers 108-109
        [8.059,-40.00,2.2,0],[7.286,-37.10,2.7,0]
    ]

    // constellation figures as pairs of star indices
    property var lines: [
        [0,1],[1,2],[2,3],[3,0],[3,4],[4,5],[5,6],
        [7,9],[9,8],
        [10,11],[11,12],[12,13],[13,14],
        [15,16],[16,17],[17,19],[19,18],[18,15],
        [20,21],
        [23,25],[25,26],[26,27],[27,28],[28,29],[23,28],[25,24],[24,26],[30,23],[30,25],
        [31,35],[31,36],[36,34],[34,37],[37,31],[36,32],[31,33],
        [38,39],[39,40],[38,41],[41,42],[42,40],
        [43,44],[44,45],[45,46],[46,47],[47,43],
        [48,49],[48,50],[50,51],[51,53],[48,52],
        [54,57],[57,55],[55,56],
        [54,58],[58,59],[59,60],[60,54],[59,61],
        [62,63],[63,64],[63,65],[64,66],
        [67,68],[68,69],[69,67],
        [71,70],[70,72],
        [73,74],[73,75],
        [76,78],[78,79],[79,77],[77,76],
        [80,82],[80,83],[83,81],
        [84,85],
        [86,87],
        [94,95],
        [99,100],
        [102,103],
        [106,107]
    ]

    // names drawn faintly at a star's position: [index, text, isStar]
    property var labels: [
        [3,"Ursa Major",false],[7,"Polaris",true],[11,"Cassiopeia",false],[16,"Cepheus",false],
        [26,"Orion",false],[23,"Betelgeuse",true],[24,"Rigel",true],[31,"Aldebaran",true],[33,"Pleiades",true],
        [41,"Gemini",false],[43,"Capella",true],[48,"Perseus",false],[55,"Andromeda",false],[59,"Pegasus",false],
        [63,"Cygnus",false],[62,"Deneb",true],[67,"Vega",true],[70,"Altair",true],[73,"Arcturus",true],
        [78,"Leo",false],[80,"Sirius",true],[84,"Procyon",true],[90,"Fomalhaut",true],[86,"Aries",false],[20,"Draco",false],
        [91,"Antares",true],[66,"Albireo",true],[92,"Spica",true],[96,"Corona Borealis",false],[94,"Hercules",false],[99,"Delphinus",false]
    ]

    property var tints: ["#cfd9ff", "#ffffff", "#fff2c8", "#ffc99a"]

    // ---- astronomy (all angles in radians unless named deg)
    function nowDate() {
        if (timeScale === 1) return new Date();
        var e = Date.now() - startMs;
        return new Date(Date.now() + e * (timeScale - 1));
    }
    function jd(d) { return d.getTime() / 86400000 + 2440587.5; }
    function rad(x) { return x * Math.PI / 180; }
    function deg(x) { return x * 180 / Math.PI; }
    function norm360(x) { x = x % 360; if (x < 0) x += 360; return x; }

    function lstDeg(j) {
        var dd = j - 2451545.0;
        var T = dd / 36525;
        var g = 280.46061837 + 360.98564736629 * dd + 0.000387933 * T * T;
        return norm360(g + lon);
    }
    // ra hours, dec degrees -> {alt, az} degrees, az from north clockwise
    function altaz(raH, decD, lst) {
        var H = rad(norm360(lst - raH * 15));
        var p = rad(lat), d = rad(decD);
        var sa = Math.sin(d) * Math.sin(p) + Math.cos(d) * Math.cos(p) * Math.cos(H);
        var alt = Math.asin(sa);
        var A = Math.atan2(Math.sin(H), Math.cos(H) * Math.sin(p) - Math.tan(d) * Math.cos(p));
        return { alt: deg(alt), az: norm360(deg(A) + 180) };
    }
    function screen(aa) {
        var dAz = ((aa.az - azCentre + 540) % 360) - 180;
        var half = fov / 2;
        if (dAz < -half - 6 || dAz > half + 6) return null;
        var x = 960 + dAz / half * 960;
        var y = horizonY - aa.alt / topAlt * horizonY;
        return { x: x, y: y, alt: aa.alt };
    }
    // sun: ecliptic longitude and equatorial place
    function sunPos(j) {
        var n = j - 2451545.0;
        var L = norm360(280.460 + 0.9856474 * n);
        var g = rad(norm360(357.528 + 0.9856003 * n));
        var lam = rad(L + 1.915 * Math.sin(g) + 0.020 * Math.sin(2 * g));
        var eps = rad(23.439 - 0.0000004 * n);
        var ra = Math.atan2(Math.cos(eps) * Math.sin(lam), Math.cos(lam));
        var dec = Math.asin(Math.sin(eps) * Math.sin(lam));
        return { raH: norm360(deg(ra)) / 15, decD: deg(dec), lamD: deg(lam) };
    }
    // moon: low-precision, good to about a degree
    function moonPos(j) {
        var T = (j - 2451545.0) / 36525;
        var Lp = rad(norm360(218.316 + 481267.881 * T));
        var D = rad(norm360(297.850 + 445267.112 * T));
        var M = rad(norm360(357.529 + 35999.050 * T));
        var Mp = rad(norm360(134.963 + 477198.868 * T));
        var F = rad(norm360(93.272 + 483202.018 * T));
        var lam = deg(Lp) + 6.289 * Math.sin(Mp) + 1.274 * Math.sin(2 * D - Mp) + 0.658 * Math.sin(2 * D)
                + 0.214 * Math.sin(2 * Mp) - 0.186 * Math.sin(M) - 0.114 * Math.sin(2 * F);
        var bet = 5.128 * Math.sin(F) + 0.281 * Math.sin(Mp + F) + 0.278 * Math.sin(Mp - F) + 0.173 * Math.sin(2 * D - F);
        var eps = rad(23.439);
        var l = rad(norm360(lam)), b = rad(bet);
        var ra = Math.atan2(Math.sin(l) * Math.cos(eps) - Math.tan(b) * Math.sin(eps), Math.cos(l));
        var dec = Math.asin(Math.sin(b) * Math.cos(eps) + Math.cos(b) * Math.sin(eps) * Math.sin(l));
        return { raH: norm360(deg(ra)) / 15, decD: deg(dec), lamD: norm360(lam) };
    }
    // galactic l,b (deg) -> ra hours, dec deg
    function galToEq(lD, bD) {
        var l = rad(lD), b = rad(bD);
        var gx = Math.cos(b) * Math.cos(l), gy = Math.cos(b) * Math.sin(l), gz = Math.sin(b);
        var x = -0.0548755604 * gx + 0.4941094279 * gy - 0.8676661490 * gz;
        var y = -0.8734370902 * gx - 0.4448296300 * gy - 0.1980763734 * gz;
        var z = -0.4838350155 * gx + 0.7469822445 * gy + 0.4559837762 * gz;
        return { raH: norm360(deg(Math.atan2(y, x))) / 15, decD: deg(Math.asin(z)) };
    }

    // ---- the sky itself: redrawn every 20 seconds
    Canvas {
        id: sky
        anchors.fill: parent
        renderStrategy: Canvas.Cooperative
        onPaint: {
            var c = getContext("2d");
            c.reset();
            var d = win.nowDate();
            var j = win.jd(d);
            var lst = win.lstDeg(j);
            var sun = win.sunPos(j);
            var sunAA = win.altaz(sun.raH, sun.decD, lst);
            win.sunAlt = sunAA.alt;
            var tw = Math.max(0, Math.min(1, (sunAA.alt + 18) / 18));   // 0 night .. 1 civil twilight
            win.twilight = tw;

            // sky: deep night blue-black, lifting into twilight blue
            var g = c.createLinearGradient(0, 0, 0, 1080);
            g.addColorStop(0.0, win.mixHex("#020409", "#1c2f58", tw));
            g.addColorStop(0.55, win.mixHex("#060a14", "#33507f", tw));
            g.addColorStop(0.86, win.mixHex("#0d131f", "#6d86b0", tw));
            g.addColorStop(1.0, win.mixHex("#141a26", "#9aa6c0", tw));
            c.fillStyle = g;
            c.fillRect(0, 0, 1920, 1080);

            // a city's glow low on the horizon, if you have one
            var gl = win.cityGlowAz >= 0 ? win.screen({ alt: 0, az: win.cityGlowAz }) : null;
            if (gl) {
                var rg = c.createRadialGradient(gl.x, win.horizonY + 60, 10, gl.x, win.horizonY + 60, 520);
                rg.addColorStop(0, "rgba(255,170,90,0.30)");
                rg.addColorStop(0.35, "rgba(255,150,70,0.12)");
                rg.addColorStop(1, "rgba(255,140,60,0)");
                c.fillStyle = rg;
                c.fillRect(0, 0, 1920, 1080);
            }

            // how much the weather hides: cloud thins everything, thick cloud hides it
            var cloudK = win.wxOk ? Math.max(0, 1 - Math.pow(win.wxCloud / 100, 1.4) * 1.05) : 1;

            // the Milky Way: a soft band along the galactic equator
            var mwAlpha = 0.11 * (1 - tw) * cloudK;
            if (mwAlpha > 0.01) {
                for (var l = 0; l < 360; l += 4) {
                    // brighter towards the centre (l ~ 0) and through Cygnus (l ~ 80), faintest at the anticentre
                    var bright = 0.55 + 0.45 * Math.cos(win.rad(l));
                    if (l > 40 && l < 100) bright += 0.25;
                    for (var bb = -9; bb <= 9; bb += 6) {
                        var eq = win.galToEq(l, bb);
                        var s = win.screen(win.altaz(eq.raH, eq.decD, lst));
                        if (!s || s.alt < -2) continue;
                        var r = 70 - Math.abs(bb) * 3;
                        var mg = c.createRadialGradient(s.x, s.y, 0, s.x, s.y, r);
                        var a = mwAlpha * bright * (bb === 0 ? 1 : 0.6);
                        mg.addColorStop(0, "rgba(214,222,245," + a.toFixed(3) + ")");
                        mg.addColorStop(1, "rgba(214,222,245,0)");
                        c.fillStyle = mg;
                        c.fillRect(s.x - r, s.y - r, r * 2, r * 2);
                    }
                }
            }

            // place every star
            var pos = [];
            for (var i = 0; i < win.stars.length; i++) {
                var st = win.stars[i];
                var p = win.screen(win.altaz(st[0], st[1], lst));
                pos.push(p);
            }

            // constellation lines, faint
            c.strokeStyle = "rgba(150,170,210," + (0.22 * (1 - tw * 0.8)).toFixed(3) + ")";
            c.lineWidth = 1;
            for (i = 0; i < win.lines.length; i++) {
                var a1 = pos[win.lines[i][0]], a2 = pos[win.lines[i][1]];
                if (!a1 || !a2 || a1.alt < 0 || a2.alt < 0) continue;
                if (Math.abs(a1.x - a2.x) > 900) continue;      // don't stitch across the wrap
                c.beginPath(); c.moveTo(a1.x, a1.y); c.lineTo(a2.x, a2.y); c.stroke();
            }

            // stars: size and brightness by magnitude, a little colour by type
            var fade = (1 - tw * 0.85) * (0.08 + 0.92 * cloudK);
            for (i = 0; i < win.stars.length; i++) {
                p = pos[i];
                if (!p || p.alt < -0.5) continue;
                st = win.stars[i];
                var m = st[2];
                var rr = Math.max(0.9, 3.4 - 0.75 * m);
                var al = Math.max(0.25, Math.min(1, 1.15 - 0.2 * m)) * fade;
                var col = win.tints[st[3]];
                if (rr > 2.2) {
                    var hg = c.createRadialGradient(p.x, p.y, 0, p.x, p.y, rr * 3.2);
                    hg.addColorStop(0, win.rgba(col, al * 0.55));
                    hg.addColorStop(1, win.rgba(col, 0));
                    c.fillStyle = hg;
                    c.fillRect(p.x - rr * 3.2, p.y - rr * 3.2, rr * 6.4, rr * 6.4);
                }
                c.fillStyle = win.rgba(col, al);
                c.beginPath(); c.arc(p.x, p.y, rr, 0, 6.2832); c.fill();
            }

            // names, only when the screen is at full brightness
            if (win.level > 0) {
                c.font = "20px sans-serif";
                c.textAlign = "left";
                for (i = 0; i < win.labels.length; i++) {
                    var lb = win.labels[i];
                    p = pos[lb[0]];
                    if (!p || p.alt < 3) continue;
                    c.fillStyle = lb[2] ? "rgba(200,210,235,0.42)" : "rgba(170,185,220,0.30)";
                    c.fillText(lb[1], p.x + 9, p.y + (lb[2] ? 6 : -10));
                }
            }

            // hand the brightest stars to the twinkle layer
            var tx = [], ty = [], tr = [], tc = [];
            for (i = 0; i < win.stars.length && tx.length < win.twN; i++) {
                p = pos[i]; st = win.stars[i];
                if (!p || p.alt < 0.5 || st[2] > 2.3) continue;
                tx.push(p.x); ty.push(p.y); tr.push(Math.max(1.2, 3.4 - 0.75 * st[2])); tc.push(win.tints[st[3]]);
            }
            while (tx.length < win.twN) { tx.push(-100); ty.push(-100); tr.push(1); tc.push("#ffffff"); }
            win.twX = tx; win.twY = ty; win.twR = tr; win.twC = tc;
            win.cloudK = cloudK;
            win.stamp = d;
            hud.requestPaint();

            // the Moon, in its true phase
            var mo = win.moonPos(j);
            var mp = win.screen(win.altaz(mo.raH, mo.decD, lst));
            if (mp && mp.alt > -1) {
                var elong = win.rad(win.norm360(mo.lamD - sun.lamD));    // 0 new, 180 full
                var k = (1 - Math.cos(elong)) / 2;                      // lit fraction
                var waxing = Math.sin(elong) > 0;                       // lit on the west (right) side
                var R = 26;
                var mg2 = c.createRadialGradient(mp.x, mp.y, R, mp.x, mp.y, R * 4.5);
                mg2.addColorStop(0, "rgba(240,236,220," + (0.22 * k).toFixed(3) + ")");
                mg2.addColorStop(1, "rgba(240,236,220,0)");
                c.fillStyle = mg2;
                c.fillRect(mp.x - R * 4.5, mp.y - R * 4.5, R * 9, R * 9);
                // lit disc
                c.fillStyle = "#efe9d4";
                c.beginPath(); c.arc(mp.x, mp.y, R, 0, 6.2832); c.fill();
                // shadow: a dark half on the unlit side, then an ellipse for the terminator
                var dark = "#0b0f1a";
                c.save();
                c.beginPath(); c.arc(mp.x, mp.y, R, 0, 6.2832); c.clip();
                c.fillStyle = dark;
                var sgn = waxing ? -1 : 1;    // dark side: east (left) when waxing
                c.fillRect(mp.x + (sgn < 0 ? -R : 0), mp.y - R, R, R * 2);
                var w = Math.abs(Math.cos(elong)) * R;
                c.fillStyle = (k < 0.5) ? dark : "#efe9d4";
                c.beginPath();
                c.ellipse(mp.x - w, mp.y - R, w * 2, R * 2);
                c.fill();
                c.restore();
            }
        }
    }

    function mixHex(a, b, k) {
        var ca = Qt.darker(a, 1), cb = Qt.darker(b, 1);
        var r = ca.r + (cb.r - ca.r) * k, g = ca.g + (cb.g - ca.g) * k, bl = ca.b + (cb.b - ca.b) * k;
        return "rgb(" + Math.round(r * 255) + "," + Math.round(g * 255) + "," + Math.round(bl * 255) + ")";
    }
    function rgba(hex, a) {
        var col = Qt.darker(hex, 1);
        return "rgba(" + Math.round(col.r * 255) + "," + Math.round(col.g * 255) + "," + Math.round(col.b * 255) + "," + a.toFixed(3) + ")";
    }

    Timer {
        interval: 20000; running: true; repeat: true
        onTriggered: sky.requestPaint()
    }

    // ---- a satellite now and then: a steady dot crossing the sky in about a minute
    property bool satOn: false
    property real sx: 0
    property real sy: 0
    property real svx: 0
    property real svy: 0
    Rectangle {
        id: sat
        width: 3; height: 3; radius: 1.5
        color: "#e8eefc"
        visible: win.satOn
        x: win.sx; y: win.sy
    }
    Timer {
        id: satTimer
        interval: 50; running: win.satOn; repeat: true
        onTriggered: {
            win.sx += win.svx; win.sy += win.svy;
            if (win.sx < -10 || win.sx > 1930 || win.sy < -10 || win.sy > win.horizonY - 40) win.satOn = false;
        }
    }
    Timer {
        interval: 90000 + Math.random() * 120000; running: true; repeat: true
        onTriggered: {
            if (win.satOn || win.twilight > 0.6) return;
            var fromLeft = Math.random() < 0.5;
            win.sx = fromLeft ? -5 : 1925;
            win.sy = 80 + Math.random() * 500;
            var speed = 1.3 + Math.random() * 0.9;
            win.svx = (fromLeft ? 1 : -1) * speed;
            win.svy = (Math.random() - 0.5) * 0.9;
            win.satOn = true;
        }
    }

    // ---- a meteor: a quick streak, every few minutes
    Canvas {
        id: meteor
        anchors.fill: parent
        property real mx: 0
        property real my: 0
        property real mdx: 0
        property real mdy: 0
        property int frame: 0
        property bool on: false
        onPaint: {
            var c = getContext("2d");
            c.reset();
            if (!on) return;
            var len = 90 + frame * 18;
            var tail = c.createLinearGradient(mx, my, mx - mdx * len, my - mdy * len);
            tail.addColorStop(0, "rgba(255,255,240," + (0.95 - frame * 0.1).toFixed(2) + ")");
            tail.addColorStop(1, "rgba(255,255,240,0)");
            c.strokeStyle = tail;
            c.lineWidth = 2;
            c.beginPath(); c.moveTo(mx, my); c.lineTo(mx - mdx * len, my - mdy * len); c.stroke();
        }
    }
    Timer {
        interval: 40; running: meteor.on; repeat: true
        onTriggered: {
            meteor.mx += meteor.mdx * 26; meteor.my += meteor.mdy * 26;
            meteor.frame++;
            if (meteor.frame > 9) { meteor.on = false; }
            meteor.requestPaint();
        }
    }
    Timer {
        interval: 50000 + Math.random() * 130000; running: true; repeat: true
        onTriggered: {
            if (meteor.on) return;
            meteor.mx = 200 + Math.random() * 1500;
            meteor.my = 40 + Math.random() * 400;
            var ang = (Math.random() < 0.5 ? 1 : -1) * (0.6 + Math.random() * 0.8);
            meteor.mdx = Math.cos(ang) * (Math.random() < 0.5 ? 1 : -1);
            meteor.mdy = Math.abs(Math.sin(ang));
            meteor.frame = 0;
            meteor.on = true;
        }
    }

    // ---- aurora: a green arc low in the north, only when the real Kp says it could be seen from here.
    // Hidden in twilight, veiled by reported cloud, and drawn behind the clouds and the trees.
    Canvas {
        id: aurora
        anchors.fill: parent
        property real s: Math.max(0, Math.min(1, (win.swKp - win.auroraKp) / 3))
        property real hint: win.swKp < win.auroraKp ? Math.max(0, Math.min(1, (win.swKp - win.auroraHintKp) / (win.auroraKp - win.auroraHintKp))) : 0
        // the solar wind sets the pace: slow wind, the curtain hangs; fast wind, it ripples
        property real pace: win.swWind > 0 ? Math.max(0.5, Math.min(2.5, win.swWind / 400)) : 1
        visible: win.swOk && (s > 0 || hint > 0) && win.twilight < 0.5
        onPaint: {
            var c = getContext("2d");
            c.reset();
            if (!win.swOk || (s <= 0 && hint <= 0)) return;
            var n0 = win.screen({ alt: 0, az: 0 });
            if (!n0) return;
            var veil = (win.wxOk && win.swTestKp < 0) ? (1 - 0.8 * win.wxCloud / 100) : 1;
            var top = s > 0 ? 8 + s * 42 : 3 + hint * 5;
            var hpx = top / win.topAlt * win.horizonY;
            var wpx = (s > 0 ? 40 + s * 70 : 24 + hint * 16) / (win.fov / 2) * 960;
            var a = (s > 0 ? 0.10 + 0.45 * s : 0.04 + 0.08 * hint) * veil * (1 - win.twilight);
            var g = c.createRadialGradient(n0.x, win.horizonY, 0, n0.x, win.horizonY, wpx);
            g.addColorStop(0, "rgba(110,255,170," + a.toFixed(3) + ")");
            g.addColorStop(0.5, "rgba(80,230,150," + (a * 0.5).toFixed(3) + ")");
            g.addColorStop(1, "rgba(60,200,140,0)");
            c.save(); c.translate(n0.x, win.horizonY); c.scale(1, hpx / wpx); c.translate(-n0.x, -win.horizonY);
            c.fillStyle = g;
            c.beginPath(); c.arc(n0.x, win.horizonY, wpx, 3.1416, 6.2832); c.fill();
            c.restore();
            if (s > 0.25) {
                var t = Date.now() / 60000 * pace;
                var nr = Math.round(10 + s * 26);
                for (var i = 0; i < nr; i++) {
                    var u = (i + 0.5) / nr * 2 - 1;
                    var x = n0.x + u * wpx * 0.85 + Math.sin(t * 0.7 + i * 1.7) * 18;
                    var h = hpx * (0.55 + 0.45 * Math.abs(Math.sin(i * 2.3 + t * 0.4))) * (1 - 0.5 * u * u);
                    var w = 10 + 22 * Math.abs(Math.sin(i * 3.1));
                    var ra = a * (0.25 + 0.5 * Math.abs(Math.sin(i * 1.3 + t)));
                    var lg = c.createLinearGradient(0, win.horizonY - h, 0, win.horizonY);
                    lg.addColorStop(0, "rgba(255,90,120,0)");
                    lg.addColorStop(0.25, "rgba(255,90,120," + (ra * s * 0.6).toFixed(3) + ")");
                    lg.addColorStop(0.6, "rgba(120,255,170," + ra.toFixed(3) + ")");
                    lg.addColorStop(1, "rgba(120,255,170,0)");
                    c.fillStyle = lg;
                    c.fillRect(x - w / 2, win.horizonY - h, w, h);
                }
            }
        }
        SequentialAnimation on opacity {
            loops: Animation.Infinite
            running: aurora.visible
            NumberAnimation { from: 0.6; to: 1.0; duration: Math.round(7000 / aurora.pace); easing.type: Easing.InOutSine }
            NumberAnimation { from: 1.0; to: 0.6; duration: Math.round(9000 / aurora.pace); easing.type: Easing.InOutSine }
        }
        Timer { interval: Math.round(20000 / aurora.pace); running: aurora.visible; repeat: true; onTriggered: aurora.requestPaint() }
    }

    // ---- the weather on the window
    property real cloudK: 1

    // cloud banks: soft grey masses drawn to match the reported cover, drifting with the wind
    Canvas {
        id: clouds
        width: 3840; height: 1080
        x: 0
        visible: win.wxOk && win.wxCloud > 25 && win.swTestKp < 0   // a preview shows a clear sky
        renderStrategy: Canvas.Cooperative
        onPaint: {
            var c = getContext("2d");
            c.reset();
            if (!win.wxOk) return;
            var cover = win.wxCloud / 100;
            if (cover < 0.25) return;
            var n = Math.round(18 + cover * 70);
            var dark = win.twilight > 0.3 ? 0.55 : 0.95;
            for (var i = 0; i < n; i++) {
                var cx = Math.random() * 1920, cy = 120 + Math.random() * 700 * (0.6 + cover * 0.6);
                var w = 180 + Math.random() * 420 * (0.5 + cover), h = w * (0.22 + Math.random() * 0.2);
                var a = (0.10 + cover * 0.55) * (0.6 + Math.random() * 0.4);
                var g = c.createRadialGradient(cx, cy, 0, cx, cy, w / 2);
                var tone = Math.round(20 + 30 * (1 - cover) + 14 * win.twilight);
                g.addColorStop(0, "rgba(" + tone + "," + (tone + 3) + "," + (tone + 10) + "," + (a * dark).toFixed(3) + ")");
                g.addColorStop(0.55, "rgba(" + tone + "," + (tone + 3) + "," + (tone + 10) + "," + (a * 0.55 * dark).toFixed(3) + ")");
                g.addColorStop(1, "rgba(" + tone + "," + (tone + 3) + "," + (tone + 10) + ",0)");
                c.fillStyle = g;
                c.save(); c.translate(cx, cy); c.scale(1, h / w); c.translate(-cx, -cy);
                c.beginPath(); c.arc(cx, cy, w / 2, 0, 6.2832); c.fill();
                c.restore();
                // the same bank again one screen along, so the drift wraps seamlessly
                c.fillStyle = g;
                c.save(); c.translate(cx + 1920, cy); c.scale(1, h / w); c.translate(-(cx + 1920), -cy);
                c.beginPath(); c.arc(cx + 1920, cy, w / 2, 0, 6.2832); c.fill();
                c.restore();
            }
        }
        // drift: faster in stronger wind, direction from where the wind comes
        NumberAnimation on x {
            id: drift
            loops: Animation.Infinite
            from: (win.wxWindDir > 180) ? -1920 : 0
            to: (win.wxWindDir > 180) ? 0 : -1920
            duration: Math.round(1920 / Math.max(4, Math.min(60, win.wxWind)) * 1000 * 6)
            running: clouds.visible
        }
    }

    // mist: low visibility settles a pale band on the horizon
    Rectangle {
        anchors.left: parent.left; anchors.right: parent.right
        y: win.horizonY - 260; height: 380
        visible: win.wxOk && win.wxVis < 6000
        opacity: win.wxOk ? Math.max(0, Math.min(0.75, (6000 - win.wxVis) / 6000)) : 0
        gradient: Gradient {
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 0.7; color: "#2a3140" }
            GradientStop { position: 1.0; color: "#2a3140" }
        }
    }

    // rain on the window: streaks that run down the glass
    Canvas {
        id: rain
        width: 1920; height: 2160
        x: 0; y: 0
        visible: win.wxOk && win.wxRain > 0
        onPaint: {
            var c = getContext("2d");
            c.reset();
            if (!win.wxOk || win.wxRain <= 0) return;
            var n = Math.round(60 + Math.min(6, win.wxRain) * 90);
            var slant = (win.wxWind / 60) * (win.wxWindDir > 180 ? 1 : -1) * 20;
            c.lineCap = "round";
            for (var i = 0; i < n; i++) {
                var x = Math.random() * 1920, y = Math.random() * 2160;
                var len = 14 + Math.random() * 30;
                c.strokeStyle = "rgba(200,215,240," + (0.12 + Math.random() * 0.2).toFixed(2) + ")";
                c.lineWidth = 1 + Math.random() * 1.2;
                c.beginPath(); c.moveTo(x, y); c.lineTo(x + slant * (len / 40), y + len); c.stroke();
            }
            // a few beads of water sitting on the glass
            for (i = 0; i < n / 3; i++) {
                x = Math.random() * 1920; y = Math.random() * 2160;
                c.fillStyle = "rgba(210,222,245,0.16)";
                c.beginPath(); c.arc(x, y, 1.5 + Math.random() * 2.5, 0, 6.2832); c.fill();
            }
        }
        NumberAnimation on y {
            loops: Animation.Infinite
            from: -1080; to: 0
            duration: Math.round(6000 / Math.max(0.3, Math.min(5, win.wxRain)))
            running: rain.visible
        }
    }

    // ---- the treeline, drawn once: a dark wood along the bottom with a few taller trees
    Canvas {
        id: trees
        x: 0; y: 860
        width: 1920; height: 220
        // a bare oak: trunk, then branches that fork and thin out
        function branch(c, x, y, ang, len, w, depth) {
            if (depth === 0 || len < 4) return;
            var nx = x + Math.cos(ang) * len, ny = y - Math.sin(ang) * len;
            c.lineWidth = w;
            c.beginPath(); c.moveTo(x, y); c.lineTo(nx, ny); c.stroke();
            var n = 2 + (Math.random() < 0.4 ? 1 : 0);
            for (var i = 0; i < n; i++) {
                var a = ang + (Math.random() - 0.5) * 1.3 + (i - (n - 1) / 2) * 0.45;
                branch(c, nx, ny, a, len * (0.6 + Math.random() * 0.2), Math.max(0.8, w * 0.62), depth - 1);
            }
        }
        // a broadleaf crown: a cluster of overlapping rounded lobes
        function crown(c, x, y, r) {
            for (var i = 0; i < 7; i++) {
                var a = Math.random() * 6.2832, d = Math.random() * r * 0.55;
                c.beginPath(); c.arc(x + Math.cos(a) * d, y - Math.abs(Math.sin(a)) * d * 0.8, r * (0.45 + Math.random() * 0.35), 0, 6.2832); c.fill();
            }
        }
        function conifer(c, x, base, h, w) {
            var tiers = 4;
            for (var i = 0; i < tiers; i++) {
                var ty = base - h * i / tiers, tw = w * (1 - i / (tiers + 0.5));
                c.beginPath(); c.moveTo(x - tw, ty); c.lineTo(x, ty - h / tiers * 1.7); c.lineTo(x + tw, ty); c.closePath(); c.fill();
            }
        }
        onPaint: {
            var c = getContext("2d");
            c.reset();
            var ground = 112;
            // a far wood, slightly lifted from black so it reads as distance
            c.fillStyle = "#0a0e18";
            var x = -20;
            while (x < 1940) {
                crown(c, x, ground - 18 - Math.random() * 16, 26 + Math.random() * 22);
                x += 28 + Math.random() * 22;
            }
            // the near hedgerow and wood, black
            c.fillStyle = "#04060a";
            c.strokeStyle = "#04060a";
            c.lineCap = "round";
            c.fillRect(0, ground, 1920, 108);
            x = -30;
            while (x < 1950) {
                var kind = Math.random();
                if (kind < 0.12) {
                    conifer(c, x, ground + 4, 60 + Math.random() * 50, 16 + Math.random() * 10);
                    x += 30 + Math.random() * 20;
                } else if (kind < 0.26) {
                    // a tall bare tree, winter
                    var th = 55 + Math.random() * 60;
                    branch(c, x, ground + 6, 1.5708 + (Math.random() - 0.5) * 0.15, th * 0.55, 5 + Math.random() * 3, 5);
                    x += 60 + Math.random() * 50;
                } else {
                    crown(c, x, ground - 8 - Math.random() * 10, 18 + Math.random() * 20);
                    x += 22 + Math.random() * 20;
                }
            }
            // low scrub along the very bottom edge
            for (var i = 0; i < 160; i++) {
                var sx = Math.random() * 1920;
                c.beginPath(); c.arc(sx, ground + 6, 6 + Math.random() * 12, 3.1416, 6.2832); c.fill();
            }
        }
    }

    // ---- twinkle: the brightest stars shimmer, each to its own rhythm
    property int twN: 40
    property var twX: []
    property var twY: []
    property var twR: []
    property var twC: []
    Item {
    anchors.fill: parent
    opacity: 0.08 + 0.92 * win.cloudK
    Repeater {
        model: win.twN
        Rectangle {
            property real r: win.twR.length > index ? win.twR[index] : 1
            width: r * 2.6; height: r * 2.6; radius: width / 2
            color: win.twC.length > index ? win.twC[index] : "#ffffff"
            x: (win.twX.length > index ? win.twX[index] : -100) - width / 2
            y: (win.twY.length > index ? win.twY[index] : -100) - height / 2
            antialiasing: true
            SequentialAnimation on opacity {
                loops: Animation.Infinite
                NumberAnimation { to: 0.25 + Math.random() * 0.3; duration: 350 + Math.random() * 1100; easing.type: Easing.InOutSine }
                NumberAnimation { to: 0.85 + Math.random() * 0.15; duration: 350 + Math.random() * 1100; easing.type: Easing.InOutSine }
            }
        }
    }
    }

    // ---- an aircraft on the approach: a steady white light and a blinking red one, crossing slowly
    property bool acOn: false
    property real acX: 0
    property real acY: 0
    property real acVX: 0
    property real acVY: 0
    Item {
        visible: win.acOn
        x: win.acX; y: win.acY
        Rectangle { width: 4; height: 4; radius: 2; color: "#f4f6ff"; x: 0; y: 0 }
        Rectangle {
            width: 5; height: 5; radius: 2.5; color: "#ff3b2e"; x: win.acVX > 0 ? -9 : 9; y: -1
            SequentialAnimation on opacity {
                loops: Animation.Infinite
                NumberAnimation { to: 1; duration: 120 }
                NumberAnimation { to: 0; duration: 120 }
                PauseAnimation { duration: 1100 }
            }
        }
    }
    Timer {
        interval: 60; running: win.acOn; repeat: true
        onTriggered: {
            win.acX += win.acVX; win.acY += win.acVY;
            if (win.acX < -20 || win.acX > 1940) win.acOn = false;
        }
    }
    Timer {
        interval: 70000 + Math.random() * 110000; running: true; repeat: true
        onTriggered: {
            if (win.acOn) return;
            var fromLeft = Math.random() < 0.5;
            win.acX = fromLeft ? -10 : 1930;
            win.acY = 350 + Math.random() * 450;
            win.acVX = (fromLeft ? 1 : -1) * (0.9 + Math.random() * 0.5);
            win.acVY = (Math.random() - 0.4) * 0.25;
            win.acOn = true;
        }
    }

    // ---- compass points on the ground, and a caption, at full brightness
    property var stamp: new Date()
    Canvas {
        id: hud
        anchors.fill: parent
        onPaint: {
            var c = getContext("2d");
            c.reset();
            if (win.level <= 0) return;
            c.font = "18px sans-serif";
            c.textAlign = "center";
            c.fillStyle = "rgba(170,180,205,0.5)";
            var names = ["N","NNE","NE","ENE","E","ESE","SE","SSE","S","SSW","SW","WSW","W","WNW","NW","NNW"];
            for (var i = 0; i < 16; i++) {
                var cp = win.screen({ alt: 0, az: i * 22.5 });
                if (!cp || cp.x < 30 || cp.x > 1890) continue;
                c.fillText(names[i], cp.x, 1004);
                c.fillRect(cp.x - 0.5, win.horizonY + 48, 1, 12);
            }
            c.textAlign = "left";
            c.font = "19px sans-serif";
            c.fillStyle = "rgba(190,200,225,0.55)";
            var d = win.stamp;
            var hh = d.getHours(), mm = d.getMinutes();
            var dirs = ["north","north-east","east","south-east","south","south-west","west","north-west"];
            var dirName = dirs[Math.round(win.azCentre / 45) % 8];
            var text = d.getDate() + " " + ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"][d.getMonth()] + " " + d.getFullYear()
                     + "   " + (hh < 10 ? "0" : "") + hh + ":" + (mm < 10 ? "0" : "") + mm
                     + "   " + win.place + ", looking " + dirName;
            c.fillText(text, 28, 1056);
            if (win.wxOk) {
                var codes = { 0: "clear", 1: "mainly clear", 2: "partly cloudy", 3: "overcast", 45: "fog", 48: "freezing fog",
                              51: "light drizzle", 53: "drizzle", 55: "heavy drizzle", 61: "light rain", 63: "rain", 65: "heavy rain",
                              71: "light snow", 73: "snow", 75: "heavy snow", 80: "showers", 81: "showers", 82: "heavy showers", 95: "thunder" };
                var w = codes[win.wxCode] || ("weather code " + win.wxCode);
                var wx = w + "  ·  cloud " + Math.round(win.wxCloud) + "%  ·  " + win.wxTemp.toFixed(0) + "°C  ·  wind " + Math.round(win.wxWind) + " km/h"
                       + (win.wxRain > 0 ? "  ·  rain " + win.wxRain.toFixed(1) + " mm" : "")
                       + (win.wxVis < 6000 ? "  ·  visibility " + (win.wxVis / 1000).toFixed(1) + " km" : "")
                       + "   (Open-Meteo, " + win.wxAt + ")";
                c.textAlign = "right";
                c.fillText(wx, 1892, 1056);
            }
            if (win.swOk) {
                var kk = win.swKp;
                var kw = kk < 3 ? "quiet" : kk < 4 ? "unsettled" : kk < 5 ? "active" : kk < 6 ? "minor storm" : kk < 7 ? "moderate storm" : kk < 8 ? "strong storm" : kk < 9 ? "severe storm" : "extreme storm";
                var sw = "space weather: Kp " + kk.toFixed(1) + " " + kw
                       + (win.swWind > 0 ? "  \u00b7  solar wind " + Math.round(win.swWind) + " km/s" : "")
                       + (kk >= win.auroraKp ? "  \u00b7  aurora possible low in the north" : (kk >= win.auroraHintKp ? "  \u00b7  aurora further north, not visible from here" : ""))
                       + "   (NOAA, " + win.swAt + " UTC)";
                c.textAlign = "right";
                c.fillText(sw, 1892, 1030);
                win.gaugeX = 1892 - c.measureText(sw).width - 138;
            }
        }
    }

    // ---- solar wind gauge: motes streaming across a small strip beside the space weather line.
    // An instrument, not a view: the solar wind cannot be seen. 300 km/s drifts; 700 km/s races.
    property real gaugeX: 1400
    Item {
        id: windGauge
        x: win.gaugeX; y: 1017
        width: 120; height: 14
        clip: true
        visible: win.swOk && win.swWind > 0 && win.level > 0
        opacity: 0.6
        Item {
            id: motes
            width: 240; height: 14
            Repeater {
                model: 16
                Rectangle {
                    x: (((index % 8) * 47 + 11) % 120) + (index >= 8 ? 120 : 0)
                    y: ((index % 8) * 5) % 12
                    width: 6 + (index % 3) * 3; height: 1.5; radius: 1
                    color: "#bcd0ff"
                }
            }
            NumberAnimation on x {
                from: -120; to: 0
                loops: Animation.Infinite
                duration: Math.round(1800000 / Math.max(200, Math.min(1200, win.swWind > 0 ? win.swWind : 400)))
                running: windGauge.visible
            }
        }
    }

    // dims the whole picture at the Dim level
    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: win.level > 0 ? 0 : 0.35
    }

    Component.onCompleted: {
        startMs = Date.now();
        sky.requestPaint();
        trees.requestPaint();
        fetchWeather();
        fetchSpace();
    }
}
