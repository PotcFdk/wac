
include("wac/aircraft.lua")
include("wac/keyboard.lua")

CreateClientConVar("wac_cl_air_realism", 3, true, true)
CreateClientConVar("wac_cl_air_sensitivity", 1, true, true)
CreateClientConVar("wac_cl_air_usejoystick", 0, true, true)
CreateClientConVar("wac_cl_air_smoothview", 1, true, true)
CreateClientConVar("wac_cl_air_mouse", 1, true, true)
CreateClientConVar("wac_cl_air_mouse_swap", 1, true, true)
CreateClientConVar("wac_cl_air_mouse_invert_pitch", 0, true, true)
CreateClientConVar("wac_cl_air_mouse_invert_yawroll", 0, true, true)
CreateClientConVar("wac_cl_air_shakeview", 1, true, true)

surface.CreateFont("wac_heli_big", {
	font = "monospace",
	size = 32
})

surface.CreateFont("wac_heli_small", {
	font = "monospace",
	size = 28
})

usermessage.Hook("wac_toggle_thirdp", function(m)
	RunConsoleCommand("gmod_vehicle_viewmode", GetConVar("gmod_vehicle_viewmode"):GetInt() == 1 and 0 or 1)
end)

for k, t in pairs(wac.aircraft.keys) do
	CreateClientConVar("wac_cl_air_key_"..k, t.k, true, true)
end

wac.key.addHook("wac_cl_air_keyboard", function(key, pressed)
	if !LocalPlayer():GetVehicle():GetNWEntity("wac_aircraft"):IsValid() or vgui.CursorVisible() then return end
	local k = 0
	for i, _ in pairs(wac.aircraft.keys) do
		if GetConVar("wac_cl_air_key_" .. i):GetInt() == key then
			RunConsoleCommand("wac_air_key_" .. i, (pressed and "1" or "0"))
		end
	end
end)

--[[
Plays enter and exit animations, calls entity viewCalc
]]
wac.hook("CalcView", "wac_air_calcview", function(p, pos, ang, fov)

	p.wac = p.wac or {}
	p.wac.air = p.wac.air or {}

	local aircraft = p:GetVehicle():GetNWEntity("wac_aircraft")

	if p.wac.thirdPerson != GetConVar("gmod_vehicle_viewmode"):GetBool() then
		p.wac.thirdPerson = !p.wac.thirdPerson
		if IsValid(aircraft) then
			aircraft:onViewSwitch(p, p.wac.thirdPerson)
		end
	end

	local targetView;
	if IsValid(aircraft) and GetViewEntity() == p and aircraft.SeatsT then
		local pid = p:GetNWInt("wac_passenger_id")
		if pid == 0 then pid = 1 end

		if !p.wac.inAircraft then
			aircraft:onEnter(p)
		end
		targetView = aircraft:viewCalc(pid, p, pos, ang, fov)

		if !p.wac.inAircraft then
			p.wac.inAircraft = true
			p.wac.localView = {
					--[[origin = p.wac.lastView.origin - pos,
					angles = Angle(
							math.AngleDifference(p.wac.lastView.angles.p, ang.p),
							math.AngleDifference(p.wac.lastView.angles.y, ang.y),
							math.AngleDifference(p.wac.lastView.angles.r, ang.r)
					),
				fov = fov - targetView.fov]]
				origin = Vector(0,0,0),
				angles = Angle(0,0,0),
				fov = 0
			}
		end
	else
		if p.wac.inAircraft then
			p.wac.inAircraft = false
			if !GetConVar("gmod_vehicle_viewmode"):GetBool() then
				p.wac.localView = {
					origin = p.wac.lastView.origin - pos,
					angles = p.wac.lastView.angles - ang,
					fov = p.wac.lastView.fov - fov
				}
			end
		end
	end
	
	if p:GetVehicle():IsValid() then
		if !p.wac.inVehicle then
			p.wac.inVehicle = true
		end
	else
		p.wac.inVehicle = false
	end

	if p.wac.localView then
		wac.smoothApproachVector(p.wac.localView.origin, Vector(0,0,0), 20)
		p.wac.localView.angles = wac.smoothApproachAngles(p.wac.localView.angles, Angle(0,0,0), 20)
		p.wac.localView.fov = wac.smoothApproach(p.wac.localView.fov, 0, 20)

		if p.wac.localView.fov < 0.01 and p.wac.localView.origin:Distance(Vector(0,0,0)) < 0.01 and !targetView then
			p.wac.localView = nil
			return
		end

		targetView = targetView or {origin = pos, angles = ang, fov = fov}

		return {
			origin = targetView.origin + p.wac.localView.origin,
			angles = targetView.angles + p.wac.localView.angles,
			fov = targetView.fov + p.wac.localView.fov
		}
	end
	--[[
	if IsValid(aircraft) and aircraft.SeatsT and p:GetNWInt("wac_passenger_id") != 0 then
		return aircraft:viewCalc(p:GetNWInt("wac_passenger_id"), p, pos, ang, fov)
	end
	]]

end)


--[[
local enterTime;	
local fovTime=0.5
wac.hook("CalcView", "wac_heli_calcview", function(p, pos, ang, fov)

	p.wac = p.wac or {enterTime=0, leaveTime=0}

	if p.wac.thirdPerson != GetConVar("gmod_vehicle_viewmode"):GetBool() then
		p.wac.thirdPerson = !p.wac.thirdPerson
	end

	local aircraft = p:GetVehicle():GetNWEntity("wac_aircraft")

	if GetViewEntity() == p then
		if IsValid(aircraft) then
			local targetView = aircraft:CalcPlayerView(p:GetNWInt("wac_passenger_id"),p,pos,ang)
			if targetView then
				if !enterTime then enterTime=CurTime() end
				local fovd = GetConVar("fov_desired"):GetInt()
				targetView.fov = (1-math.Clamp(CurTime()-enterTime,0,fovTime)/fovTime)*fovd+(fov-(90-fovd))*math.Clamp(CurTime()-enterTime,0,fovTime)/fovTime
				p.wac.leaveView = {
					origin = targetView.origin,
					angles = targetView.angles,
					fov = targetView.fov
				}
				p.wac.leaveTime = CurTime()
				p.wac.inAircraft = true
				return targetView
			end
		end
		if p.wac.leaveView and GetConVar("gmod_vehicle_viewmode"):GetInt() == 0 then
			if p.wac.inAircraft then
				p.wac.inAircraft = false
				p.wac.leaveView.angles = ang - p.wac.leaveView.angles
				p.wac.leaveView.origin = p:WorldToLocal(p.wac.leaveView.origin - Vector(0,0,65))
			end
			local m = math.Clamp(CurTime()-p.wac.leaveTime,0,1)*100
			p.wac.leaveView.angles = wac.smoothApproachAngles(p.wac.leaveView.angles, Angle(0,0,0), m)
			wac.smoothApproachVector(p.wac.leaveView.origin, Vector(0,0,0), m)
			if p.wac.leaveView.origin:Distance(Vector(0,0,0))>0.01 then
				return {
					origin = pos+p.wac.leaveView.origin,
					angles = ang-p.wac.leaveView.angles,
				}
			end
		end
	end
end)
]]

-- menu
wac.addMenuPanel(wac.menu.tab, wac.menu.category, wac.menu.aircraft, function(panel, info)

	panel:AddControl("Label", {Text = "Client Settings"})
	
	local presetParams = {
		Label = "Presets",
		MenuButton = 1,
		Folder = "wac_aircraft",
		Options = {
			mouse = {
				wac_cl_air_easy = "1",
				wac_cl_air_sensitivity = "1",
				wac_cl_air_usejoystick = "0",
				wac_cl_air_mouse = "1",
				wac_cl_air_mouse_swap ="1",
				wac_cl_air_mouse_invert_pitch = "0",
				wac_cl_air_mouse_invert_yawroll = "0",
				wac_cl_air_key_1 = KEY_E,
				wac_cl_air_key_2 = KEY_R,
				wac_cl_air_key_3 = KEY_W,
				wac_cl_air_key_4 = KEY_S,
				wac_cl_air_key_5 = KEY_A,
				wac_cl_air_key_6 = KEY_D,
				wac_cl_air_key_7 = KEY_NONE,
				wac_cl_air_key_8 = KEY_NONE,
				wac_cl_air_key_9 = KEY_A,
				wac_cl_air_key_10 = KEY_D,
				wac_cl_air_key_11 = KEY_LALT,
				wac_cl_air_key_12 = MOUSE_LEFT,
				wac_cl_air_key_13 = MOUSE_RIGHT,
				wac_cl_air_key_14 = MOUSE_4,
				wac_cl_air_key_15 = KEY_SPACE,
			},
			keyboard = {
				wac_cl_air_easy = "1",
				wac_cl_air_sensitivity = "1",
				wac_cl_air_usejoystick = "0",
				wac_cl_air_mouse = "0",
				wac_cl_air_mouse_swap = "0",
				wac_cl_air_mouse_invert_pitch = "0",
				wac_cl_air_mouse_invert_yawroll = "0",
				wac_cl_air_key_1 = KEY_E,
				wac_cl_air_key_2 = KEY_R,
				wac_cl_air_key_3 = KEY_SPACE,
				wac_cl_air_key_4 = KEY_LSHIFT,
				wac_cl_air_key_5 = KEY_A,
				wac_cl_air_key_6 = KEY_D,
				wac_cl_air_key_7 = KEY_W,
				wac_cl_air_key_8 = KEY_S,
				wac_cl_air_key_9 = MOUSE_LEFT,
				wac_cl_air_key_10 = MOUSE_RIGHT,
				wac_cl_air_key_11 = KEY_LALT,
				wac_cl_air_key_12 = KEY_F,
				wac_cl_air_key_13 = KEY_G,
				wac_cl_air_key_14 = MOUSE_4,
				wac_cl_air_key_15 = KEY_X,
			},
		},
		CVars = {
			"wac_cl_air_easy",
			"wac_cl_air_sensitivity",
			"wac_cl_air_usejoystick",
			"wac_cl_air_mouse",
			"wac_cl_air_mouse_swap",
			"wac_cl_air_mouse_invert_pitch",
			"wac_cl_air_mouse_invert_yawroll",
		}
	}	
	for i,t in pairs(wac.aircraft.keys) do
		table.insert(presetParams.CVars, "wac_cl_air_key_" .. i)
	end
	panel:AddControl("ComboBox", presetParams)
	
	for i,t in pairs(wac.aircraft.keys) do
		local k = vgui.Create("wackeyboard::key", panel)
		k:setLabel(t.n)
		k:setKey(t.k)
		k.runCommand="wac_cl_air_key_"..i
		panel:AddPanel(k)	
	end
	
	panel:AddControl("Slider", {
		Label = "Sensitivity",
		Type = "float",
		Min = 0.5,
		Max = 1.9,
		Command = "wac_cl_air_sensitivity",
	})
	
	panel:AddControl("Slider", {
		Label = "Realism",
		Type = "float",
		Min = 1,
		Max = 3,
		Command = "wac_cl_air_realism",
	})
	
	panel:CheckBox("Smooth View","wac_cl_air_smoothview")
	
	panel:CheckBox("Shake View","wac_cl_air_shakeview")

	if info["wac_cl_air_usejoystick"]=="0" then
		panel:CheckBox("Use Mouse","wac_cl_air_mouse")
		if info["wac_cl_air_mouse"]=="1" then
			panel:CheckBox(" - Invert Pitch","wac_cl_air_mouse_invert_pitch")
			panel:CheckBox(" - Invert Yaw/Roll","wac_cl_air_mouse_invert_yawroll")
			panel:CheckBox(" - Swap Yaw/Roll","wac_cl_air_mouse_swap")
			panel:AddControl("Label", {Text = ""})
		end
	end
	
	panel:CheckBox("Use Joystick","wac_cl_air_usejoystick")
	
	if info["wac_cl_air_usejoystick"]=="1" then
		panel:AddControl("Button", {
			Label = "Joystick Configuration",
			Command = "joyconfig"
		})
	end
	
	panel:AddControl("Label", {Text = ""})
	panel:AddControl("Label", {Text = "Admin Settings"})

	panel:CheckBox("Server Tickrate is 66","wac_air_doubletick")

	panel:AddControl("Slider", {
		Label="Start Speed",
		Type="float",
		Min=0.1,
		Max=2,
		Command="wac_air_startspeed",
	})
	
	if game.SinglePlayer() then
		panel:CheckBox("Dev Helper","wac_cl_air_showdevhelp")
		if info["wac_cl_air_showdevhelp"]=="1" then
			panel:AddControl("Button", {
				Label = "Spawn",
				Command = "wac_cl_air_clientsidemodel_create",
			})
			panel:AddControl("Button", {
				Label = "Remove",
				Command = "wac_cl_air_clientsidemodel_remove",
			})
			panel:AddControl("TextBox", {
				Label="Model",
				MaxLength=512,
				Text="",
				Command="wac_cl_air_clmodel_model",
			})
			panel:AddControl("Slider", {
				Label="X",
				Type="float",
				Min=-600,
				Max=600,
				Command="wac_cl_air_clmodel_line_x",
			})
			panel:AddControl("Slider", {
				Label="Y",
				Type="float",
				Min=-200,
				Max=200,
				Command="wac_cl_air_clmodel_line_y",
			})
			panel:AddControl("Slider", {
				Label="Z",
				Type="float",
				Min=-200,
				Max=200,
				Command="wac_cl_air_clmodel_line_z",
			})
			panel:AddControl("Button", {
				Label = "Print",
				Command = "wac_cl_air_clmodel_printvars",
			})
			panel:AddControl("Button", {
				Label = "Reset",
				Command = "wac_cl_air_clmodel_line_x 0;wac_cl_air_clmodel_line_y 0;wac_cl_air_clmodel_line_z 0;",
			})
		end
	end
end,
	"wac_cl_air_mouse",
	"wac_cl_air_usejoystick",
	"wac_cl_air_showdevhelp"
)