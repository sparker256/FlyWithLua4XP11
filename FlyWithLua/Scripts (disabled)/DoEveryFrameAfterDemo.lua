-- Demonstrate the do_every_frame() and do_every_frame_after() callbacks.
-- Create a flight with 2 or more AI aircraft, then invoke this script via it's menu item.

if not SUPPORTS_FLOATING_WINDOWS then
    -- to make sure the script doesn't stop old FlyWithLua versions
    logMsg("imgui not supported by your FlyWithLua version")
    return
end

require("graphics")

-- load the XPLM library
local ffi = require("ffi")

-- find the right lib to load
local XPLMlib = ""
if SYSTEM == "IBM" then
	-- Windows OS (no path and file extension needed)
  	if SYSTEM_ARCHITECTURE == 64 then
    		XPLMlib = "XPLM_64"  -- 64bit
  	else
    		XPLMlib = "XPLM"     -- 32bit
  	end
elseif SYSTEM == "LIN" then
  	-- Linux OS (we need the path "Resources/plugins/" here for some reason)
  	if SYSTEM_ARCHITECTURE == 64 then
    		XPLMlib = "Resources/plugins/XPLM_64.so"  -- 64bit
  	else
    		XPLMlib = "Resources/plugins/XPLM.so"     -- 32bit
  	end
elseif SYSTEM == "APL" then
  	-- Mac OS (we need the path "Resources/plugins/" here for some reason)
  	XPLMlib = "Resources/plugins/XPLM.framework/XPLM" -- 64bit and 32 bit
else
  	return -- this should not happen
end

-- load the lib and store in local variable
local XPLM = ffi.load(XPLMlib)

local w1 = ffi.new("int[1]")
local w2 = ffi.new("int[1]")
local w3 = ffi.new("int[1]")
local AIRCRAFT_FILENAME = ffi.new("char[1024]")
local AIRCRAFT_PATH = ffi.new("char[1024]")

local PLANE_COUNT
local PLANE_TOTAL 
local PLANE_PLUGIN
local ACQUIRED = 0
local GrabAIPlane_window = nil
local Window_Is_Open = false 
local ShowGrabAIPlaneWindow = false
local HideGrabAIPlaneWindow = false
local xp_ver = get("sim/version/xplane_internal_version")
local Callback = 0 -- which callback to use


-----------------------------------
--DATAREFS
-----------------------------------

dataref("PAUSED", "sim/time/paused")
dataref("AIRCRAFT_ALTITUDE_AGL", "sim/flightmodel/position/y_agl")

dataref("gPlaneX", "sim/flightmodel/position/local_x", "writable")
dataref("gPlaneY", "sim/flightmodel/position/local_y", "writable")
dataref("gPlaneZ", "sim/flightmodel/position/local_z", "writable")
dataref("gPlaneTheta", "sim/flightmodel/position/theta", "writable")
dataref("gPlanePhi", "sim/flightmodel/position/phi", "writable")
dataref("gPlanePsi", "sim/flightmodel/position/psi", "writable")
dataref("gPlaneAPHeading", "sim/cockpit/autopilot/heading", "writable")
dataref("gPlaneAPCurrentAltitude", "sim/cockpit/autopilot/current_altitude", "writable")
dataref("gPlaneLandingLights", "sim/cockpit/electrical/landing_lights_on")
dataref("gPlaneNavLights", "sim/cockpit/electrical/nav_lights_on")
dataref("gPlaneBeaconLights", "sim/cockpit/electrical/beacon_lights_on")
dataref("gPlaneStrobeLights", "sim/cockpit/electrical/strobe_lights_on")
gPlaneGear = dataref_table("sim/aircraft/parts/acf_gear_deploy")
gPlaneThrottle = dataref_table("sim/flightmodel2/engines/throttle_used_ratio")

dataref("wPlaneX1", "sim/multiplayer/position/plane1_x", "writable")
dataref("wPlaneY1", "sim/multiplayer/position/plane1_y", "writable")
dataref("wPlaneZ1", "sim/multiplayer/position/plane1_z", "writable")
dataref("wPlaneTheta1", "sim/multiplayer/position/plane1_the", "writable")
dataref("wPlanePhi1", "sim/multiplayer/position/plane1_phi", "writable")
dataref("wPlanePsi1", "sim/multiplayer/position/plane1_psi", "writable")
wPlaneGear1 = dataref_table("sim/multiplayer/position/plane1_gear_deploy", "writable")
wPlaneThrottle1 = dataref_table("sim/multiplayer/position/plane1_throttle", "writable")
dataref("wPlaneAlt1", "sim/multiplayer/position/plane1_el")
dataref("wPlaneLandingLights1", "sim/multiplayer/position/plane1_landing_lights_on", "writable")
dataref("wPlaneNavLights1", "sim/multiplayer/position/plane1_nav_lights_on", "writable")
dataref("wPlaneBeaconLights1", "sim/multiplayer/position/plane1_beacon_lights_on", "writable")
dataref("wPlaneStrobeLights1", "sim/multiplayer/position/plane1_strobe_lights_on", "writable")

dataref("wPlaneX2", "sim/multiplayer/position/plane2_x", "writable")
dataref("wPlaneY2", "sim/multiplayer/position/plane2_y", "writable")
dataref("wPlaneZ2", "sim/multiplayer/position/plane2_z", "writable")
dataref("wPlaneTheta2", "sim/multiplayer/position/plane2_the", "writable")
dataref("wPlanePhi2", "sim/multiplayer/position/plane2_phi", "writable")
dataref("wPlanePsi2", "sim/multiplayer/position/plane2_psi", "writable")
wPlaneGear2 = dataref_table("sim/multiplayer/position/plane2_gear_deploy", "writable")
wPlaneThrottle2 = dataref_table("sim/multiplayer/position/plane2_throttle", "writable")
dataref("wPlaneLandingLights2", "sim/multiplayer/position/plane2_landing_lights_on", "writable")
dataref("wPlaneNavLights2", "sim/multiplayer/position/plane2_nav_lights_on", "writable")
dataref("wPlaneBeaconLights2", "sim/multiplayer/position/plane2_beacon_lights_on", "writable")
dataref("wPlaneStrobeLights2", "sim/multiplayer/position/plane2_strobe_lights_on", "writable")

ffi.cdef("typedef int XPLMPluginID")
ffi.cdef("void XPLMCountAircraft (int * outPLANE_COUNT, int * outPLANE_TOTAL, XPLMPluginID * outController)")
ffi.cdef("void XPLMGetNthAircraftModel (int inINDEX, char * outAIRCRAFT_FILENAME, char *﻿outAIRCRAFT_PATH)")
ffi.cdef("typedef void (* XPLMPlanesAvailable_f)(void * inRefcon)")
ffi.cdef("int XPLMAcquirePlanes ( char ** inAIRCRAFT_PATH, XPLMPlanesAvailable_f inCallback, void * inRefcon)")
ffi.cdef("void XPLMDisableAIForPlane (int inAI)")
ffi.cdef("void XPLMReleasePlanes(void)")

-- Get aircraft details
XPLM.XPLMCountAircraft (w1 , w2 , w3)  
PLANE_COUNT, PLANE_TOTAL, PLANE_PLUGIN = w1[0], w2[0], w3[0]


function GrabAIPlane_on_close_floating_window() -- cleanup when nthe window is closed. Needs to be global.

	Window_Is_Open = false
	ReleaseAIPlanes()

end

local function GrabAIPlane_hide_window() -- Hide the window

    if Window_Is_Open then
		float_wnd_destroy(GrabAIPlane_window)
		Window_Is_Open = false
    end
	 
end	

local function GrabAIPlane_show_window() -- Show the app window. Needs to be global.

   if(Window_Is_Open == false) then	
		local Window_Title = string.format("do_every_frame_after() Demo", view_id)
		GrabAIPlane_window = float_wnd_create(550, 90, 1, true) -- Width / Height
		if(GrabAIPlane_window == nil) then
			return
		end
		Window_Is_Open = true
	    float_wnd_set_title(GrabAIPlane_window, Window_Title)
	    float_wnd_set_imgui_builder(GrabAIPlane_window, "GrabAIPlane_window_build")
	    float_wnd_set_onclose(GrabAIPlane_window, "GrabAIPlane_on_close_floating_window")
	end
	
end

function Manage_GrabAIPlane_Window() -- needs to be a global function so do_often() can see it.

	if(ShowGrabAIPlaneWindow == true) then  -- This indow is opened via a flight loop, not a callback.
		GrabAIPlane_show_window()
		ShowGrabAIPlaneWindow = false
	else
		if(HideGrabAIPlaneWindow == true) then -- This window is closed via a flight loop, not a callback.
			GrabAIPlane_hide_window()
			HideGrabAIPlaneWindow = false
		end
	end
	
end

function acquire_AIplanes_callback() -- This is requred so that when released, the AI plane will return under control of x-plane. Needs to be global.
    XPLMSpeakString("Planes acquired callback invoked.")
end

local function AcquireAIPlanes()

	if XPLM.XPLMAcquirePlanes(ai_plane_array, acquire_AIplanes_callback, nil) ~= 1 then  -- Grab the AI Plane details
		XPLMSpeakString("XPLM Acquire Planes did not succeed. Another plugin may be controlling the AI aircraft")
	else
		XPLM.XPLMDisableAIForPlane(1)
		XPLM.XPLMDisableAIForPlane(2)
		ACQUIRED = 1
		Callback = 1
	end
	
end

function ReleaseAIPlanes() -- Needs to be global so GrabAIPlane_on_close_floating_window()can see it.

	XPLM.XPLMReleasePlanes()	
	XPLM.XPLMCountAircraft (w1 , w2 , w3)
	PLANE_COUNT, PLANE_TOTAL, PLANE_PLUGIN = w1[0], w2[0], w3[0]
	ACQUIRED = 0
	Callback = 0
end

function GrabAIPlane_Open_Settings() -- set a variable that will cause the doOften() to open the window. Needs to be global.
	if (Window_Is_Open == false) then
		ShowGrabAIPlaneWindow = true
	else
		HideGrabAIPlaneWindow = true
	end	
	
end

function Do_GrabAIPlane() -- needs to be a global function so do_every_frame() can see it.

	if Callback == 1 then 
		wPlaneX1 = gPlaneX 		-- move the AI plane near to the user plane
		wPlaneY1 = gPlaneY 		--                 ""
		wPlaneZ1 = gPlaneZ + 20 --                 ""  offset by 20
		wPlaneTheta1 = gPlaneTheta	-- copy the user plane's attitude	
		wPlanePsi1 = gPlanePsi	--                 ""
		wPlanePhi1 = gPlanePhi	--                 "" 	
	end

end

function Do_GrabAIPlaneAfter() -- needs to be a global function so do_every_frame_after() can see it.

	if Callback == 2 then
		wPlaneX2 = gPlaneX
		wPlaneY2 = gPlaneY
		wPlaneZ2 = gPlaneZ + 20
		wPlaneTheta2 = gPlaneTheta		
		wPlanePsi2 = gPlanePsi
		wPlanePhi2 = gPlanePhi		
	end

end

function GrabAIPlane_window_build(formation_window, x, y)   

    XPLM.XPLMCountAircraft (w1 , w2 , w3)
    PLANE_COUNT, PLANE_TOTAL, PLANE_PLUGIN = w1[0], w2[0], w3[0]
	
	imgui.TextUnformatted("FlyWithLUA Version is " .. xp_ver)
	if Callback == 1 then
		imgui.TextUnformatted("Using do_every_frame() callback")
	elseif Callback == 2 then
		imgui.TextUnformatted("Using do_every_frame_after() callback")
	else
		imgui.TextUnformatted("")	
	end
	imgui.TextUnformatted("")
	-- check if the FlyWithLUA version is compatible with the do__every+_frame_after() callback.
	if (xp_ver < 120000 and PLUGIN_VERSION_NO >= "2.7.38") or (xp_ver >= 120000 and PLUGIN_VERSION_NO >= "2.8.13") then
		if PLANE_COUNT < 3 then -- do we have enough AI planes
			imgui.TextUnformatted("Not enough AI Planes Available. Please add 2 AI planes and start again.")
		else		
			if imgui.Button("Grab AI Plane") then
				AcquireAIPlanes()
			end	
			imgui.SameLine()
			if ACQUIRED == 1 then
				if imgui.Button("Release AI Plane") then
					ReleaseAIPlanes()
				end
				imgui.SameLine()		
				if imgui.Button("Use Standard Callback") then
					Callback = 1
				end
					imgui.SameLine()
				if imgui.Button("Use After Callback") then
					Callback = 2							
				end
			end	
		end	
	else
		imgui.TextUnformatted("This version does not support do_every_frame_after() callbacks.")
	end

end

	
add_macro("Show after() demo Window", "GrabAIPlane_Open_Settings()") -- add menu item

if PLUGIN_VERSION_NO == nil then PLUGIN_VERSION_NO = "0.0.0" end -- Older version didn't have a a version variable.
if (xp_ver < 120000 and PLUGIN_VERSION_NO >= "2.7.38") or (xp_ver >= 120000 and PLUGIN_VERSION_NO >= "2.8.13") then -- check if compatible version
	do_every_frame("Do_GrabAIPlane()")
	do_every_frame_after("Do_GrabAIPlaneAfter()")	
	Callback = 0
	print("[do_every_frame_after() demo] Later Version Found.  Doing both do_every_frame_after() and do_every_frame()") -- write to log.txt
else
	do_every_frame_after("Do_GrabAIPlane()")
	Callback = 0
	print("[do_every_frame_after() demo] Later Version Not Found.  Doing do_every_frame() only")	
end

do_often("Manage_GrabAIPlane_Window()")


