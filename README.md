
# vcircuits

Simple kiosk dashboard written in vala

## Compiling

First, install some build requirements: `sudo apt install valac libsecret-1-dev libgtk3.0-cil-dev  libgtk2.0-dev libjson-glib-dev libgtk-3-dev`

Then, it should be as simple as running "make"! If there are any problems, please feel free to open an issue.

## Configuration

Configuration is a JSON object with the following keys:

### sources

A list of source config objects describing endpoints that are polled regularly. These can be HTTP (REST) polled on a timer, MQTT subscriptions, or others if support has been added.

These config objects may have the following fields:

#### Fields - All Types

 * **type**: The type of source. Currently supported are "rest" and "mqtt".
 * **enabled**: Whether this source will be polled/subscribed or not.
 
#### Fields - mqtt

 * **uid**: Unique ID to present to the MQTT server.
 * **host**: Hostname of the MQTT server.
 * **port**: Port to connect to the MQTT server (usually 1883 or 8883).
 * **user**: User with which to authenticate with the MQTT server.
 * **protocol**: Can be "mqtt" or "mqtts" if TLS is used.

#### Fields - rest

 * **host**: Hostname of the HTTP server.
 * **port**: Port to connect to the HTTP server (usually 80 or 443).
 * **user**: (Optional) User if basic authentication is used. Can be "bearer" to setup a bearer token.
 * **protocol**: Can be "http" or "https" if TLS is used.
 * **frequency**: How often (in ms) to poll the HTTP server.
 * **time\_fmt**: (Optional) In POST data, replace \<now\> tokens with current time in this format (in UNIX format, e.g. %m-%d-Y).

### lists

This can be a set of named lists, which can then be substituted for lists in dashlet configuration later on. If a dashlet configuration is expecting a list and receives a string in its configuration object, it is assumed that it is the key to one of these lists.

### options

General configuration options which define the dashboard:

 * **background**: Can be a CSS color, including words like "black" or "white".
 * **foreground**: Can be a CSS color, including words like "black" or "white".
 * **width**: Width of the dashboard window in pixels.
 * **height**: Height of the dashboard window in pixels.
 * **decorated**: Whether to apply window manager decorations. "true" or "false"
 * **style**: Additional CSS styling options for GTK.

### dashboard

These are the dashlets that display on the dashboard.

(TBA)

