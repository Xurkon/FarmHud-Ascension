# FarmHud

![Version](https://img.shields.io/badge/version-2.0.3-blue?style=flat-square)
![WoW Version](https://img.shields.io/badge/WoW-3.3.5a-orange?style=flat-square)
[![Platform](https://img.shields.io/badge/platform-Project%20Ascension-green?style=flat-square)](https://ascension.gg/)
[![Docs](https://img.shields.io/badge/docs-GitHub%20Pages-blue?style=flat-square)](https://xurkon.github.io/FarmHud/)
&nbsp;&nbsp;
[![Patreon](https://img.shields.io/badge/-Patreon-red?logo=patreon&style=flat-square)](https://www.patreon.com/Xurkon)
[![PayPal](https://img.shields.io/badge/-PayPal-blue?logo=paypal&style=flat-square)](https://paypal.me/kancerous)

> **Complete rewrite for WoW 3.3.5a (Project Ascension)** - Taint-free implementation

## Description

Turn your minimap into a HUD for farming ore, herbs, and other resources!

![FarmHud Screenshot1](./farmhud1.jpg) ![FarmHud Screenshot2](./farmhud2.jpg)

## Features

* **No action bar taint** - Works correctly when entering combat with HUD open
* Gather circle *(color / transparency adjustable)*
* Direction indicators (cardinal points) *(color / transparency / distance adjustable)*
* Player coordinates *(color / transparency adjustable)*
* Time display (server and/or local time)
* Custom player arrow/dot styles (6 options including hide)
* HUD size and scale options
* Text scale for cardinal directions
* Minimap button and broker panel integration *(optional)*
* Show minimap terrain texture *(transparency adjustable)*
* Key bindings
* Hide in instances option
* Hide in combat option

## Commands

* `/farmhud` or `/fhud` - Toggle HUD
* `/farmhud options` - Open options panel

## Options Panel

Available via Game Menu > Interface > AddOns > FarmHud
or by chat command `/farmhud options`

## Addon Compatibility

Works with minimap addons that add pins:

* GatherMate2
* Routes  
* HandyNotes
* TomTom

## Macro Functions

* `/run FarmHud:Toggle()`
* `/run FarmHud:MouseToggle()`
* `/run FarmHud:OpenOptions()`

## Work In Progress

The following features are still being implemented:

* Custom gather circle options
* Range circles module
* TrailPath module
* Tracking type toggles

## Author

**Xurkon** - Complete rewrite for Project Ascension

## Disclaimer

> World of Warcraft© and Blizzard Entertainment© are all trademarks or registered trademarks of Blizzard Entertainment in the United States and/or other countries. These terms and all related materials, logos, and images are copyright © Blizzard Entertainment.
