PICOLOVE
--------

A fork of the original PICOLOVE, an implementation of PICO-8's API in LÖVE  
Original is on github at: https://github.com/picolove/picolove  
Requires LÖVE 11.x

PICO-8: http://www.lexaloffle.com/pico-8.php  
LÖVE: https://love2d.org/

##### What it is:

 * An implementation of PICO-8's api in LÖVE

##### Why:

 * For a fun challenge!
 * Allow standalone publishing of PICO-8 games on other platforms
  * Should work on mobile devices [*](#android-packaging)
 * Configurable controls
 * Extendable
 * No arbitrary cpu or memory limitations
 * No arbitrary code size limitations
 * Better debugging tools available
 * Open source

##### What it isn't:

 * A replacement for PICO-8
 * A perfect replica
 * No dev tools, no image editor, map editor, sfx editor, music editor
 * No modifying or saving carts
 * Not memory compatible with PICO-8

##### Differences:

 * Uses floating point numbers not fixed point
 * Uses LuaJIT not lua 5.2
 * Memory layout is not complete

##### Extra features:

 * `ipairs()`, `pairs()` standard lua functions
 * `assert(expr,message)` if expr is not true then errors with message
 * `error(message)` bluescreens with an error message
 * `warning(message)` prints warning and stacktrace to console
 * `setfps(fps)` changes the consoles framerate
 * `_keyup`, `_keydown`, `_textinput` allow using direct keyboard input

##### Android Packaging:

Replace nocart.p8 with your game, since this is the default cartridge on boot. Text P8 or PNG P8.PNG is supported.  
Follow the steps at [Android Game Packaging](https://bitbucket.org/MartinFelis/love-android-sdl2/wiki/Game_Packaging)  
An additional step when editing AndroidManifest.xml is to remove ```android:screenOrientation="landscape"``` if you would like your game to support orientation rotation (Portrait and Landscape)
