# quiet-skies

Screensavers for a rooted LG TV running [Glasshouse](https://github.com/rorygallagher2024/glasshouse) — a quiet TV, de-spied and made our own, deserves a quiet sky.

Each one is a folder with a `saver.json` and a `main.qml`, in Glasshouse's own [screen saver format](https://github.com/rorygallagher2024/glasshouse/blob/main/docs/development/WRITING-SCREENSAVERS.md). Written by Catherine & Claude for a living room in the UK, and shared under the MIT licence.

## Dusk Murmuration

One great flock of starlings over a reedbed, under a winter dusk that deepens into night and back over twenty minutes. A hundred and sixty birds, each heeding its nearest neighbours — separation, alignment, cohesion — so the flock gathers, stretches, splits and reforms the way real murmurations do. The birds are glossy: each is painted from a palette of eight shades and glints when it banks into the low light, and because neighbours turn together the flash sweeps across the flock like a shoal of fish. Every minute or three a falcon stoops through; the flock flinches away and the flinch travels as a wave.

Measured at about 25% of one core on a 2022 LG C2 (webOS 9), a little over Glasshouse's own target of 20%. Six versions were shaped in one evening by a pair of eyes on the sofa saying "more like birds, less like flies".

*Screenshot to follow.*

## Window Sky *(coming once its co-author has said yes)*

The TV as a window: the real night sky behind the living-room wall, right now, computed from the TV's clock. Bright stars and constellations where they truly are, the Moon in its real phase, the Milky Way, live cloud, rain and mist from Open-Meteo, and the odd satellite, meteor and passing aircraft.

Three lines at the top of `main.qml` make it your sky. The example below is Greenwich:

```
property real lat: 51.48        // your latitude
property real lon: 0.00         // your longitude, east positive
property real azCentre: 180     // the compass direction the TV "faces" from the sofa (0 N, 90 E, 180 S, 270 W)
```

It reaches the network (Open-Meteo, no key, every ten minutes), so Glasshouse will note that under its name in the list. If you'd rather it didn't, delete the `fetchWeather` call and the sky stays clear.

## Installing

1. Root your LG TV and install Glasshouse ([their install guide](https://github.com/rorygallagher2024/glasshouse/blob/main/docs/install.md)).
2. Copy a folder into `/var/lib/tvweb/screensavers/` on the TV:
   ```
   scp -r dusk-murmuration root@<tv-ip>:/var/lib/tvweb/screensavers/
   ```
3. Open Glasshouse's **Screensaver** tab. The new one is listed after Glasshouse's own, marked *Added on this TV*. Pick it, and press **Start screen saver** to see it now.

Glasshouse copies the folder to where the TV runs it from when you pick it, so after changing a file, pick it again. Try it at both **Dim** and **Bright**.

## Checking a change

Glasshouse's checker catches most of what makes a screensaver show black:

```
python3 <glasshouse>/scripts/check-screensavers.py dusk-murmuration/
```

## Credits

Catherine & Claude, autumn 2026. Window Sky with Ross, who told us which way the wall faces. Thanks to Rory Gallagher and the Glasshouse contributors for a TV that can be owned, and for the screensaver format that made this easy.
