--[[
Vehicle

    A short description of the module.

SYNOPSIS

    -- Lua code that showcases an overview of the API.
    local foobar = Vehicle.TopLevel('foo')
    print(foobar.Thing)

DESCRIPTION

    A detailed description of the module.

API

    -- Describes each API item using Luau type declarations.

    -- Top-level functions use the function declaration syntax.
    function ModuleName.TopLevel(thing: string): Foobar

    -- A description of Foobar.
    type Foobar = {

        -- A description of the Thing member.
        Thing: string,

        -- Each distinct item in the API is separated by \n\n.
        Member: string,

    }
]]

-- Implementation of Vehicle.

--// Services
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

--// Dependency
local Weight = require(script.Weight)
local Wheels = require(script.Wheels)
local Controls = require(script.Controls)

--// Variables
local WheelList = {
	"FrontRight",
	"FrontLeft",
	"RearRight",
	"RearLeft",
}

local DefualtSettings = {
	Integeral = 1,
	Stiffness = 50,
	Damping = 3,

	Suspension = 2,
	WheelRadius = 0.5,
}

local function SetNetworkOwner(Humanoid: Humanoid, Vehicle: Model)
	local Player = Players:GetPlayerFromCharacter(Humanoid.Parent)

	if not Player then
		error("No a player in the seat")
	end

	for Index, Object: BasePart in pairs(Vehicle:GetChildren()) do
		if not Vehicle:IsA("Part") and not Vehicle:IsA("MeshPart") then
			continue
		end

		Object:SetNetworkOwner(Humanoid and Players:GetPlayerFromCharacter(Humanoid.Parent) or nil)
	end

	return Player
end

local function AddRequirements(Attachments)
	local VectorForces = {}

	for i, v in pairs(Attachments) do
		VectorForces[i] = Instance.new("VectorForce")
		VectorForces[i].Force = Vector3.zero
		VectorForces[i].Attachment0 = v
		VectorForces[i].RelativeTo = Enum.ActuatorRelativeTo.Attachment0
		VectorForces[i].Name = i .. "VectorForce"
		VectorForces[i].Parent = v.Parent
	end

	return VectorForces
end

local function GetInstances(_Vehicle: Model, InstanceType: string, PreferedLabel: string): {}
	local Temp = {
		FrontRight = _Vehicle,
	}

	for Index, AttachmentName in pairs(WheelList) do
		Temp[AttachmentName] = _Vehicle.PrimaryPart:WaitForChild(
			PreferedLabel and PreferedLabel .. AttachmentName or AttachmentName .. InstanceType,
			3
		)
	end

	return Temp
end

function CreateServerForces(Root): { BodyPositon: BodyPosition, BodyGyro: BodyGyro }
	local bodyPosition = Instance.new("BodyPosition", Root)
	bodyPosition.MaxForce = Vector3.new()

	local bodyGyro = Instance.new("BodyGyro", Root)
	bodyGyro.MaxTorque = Vector3.new()

	return { BodyPosition = bodyPosition, BodyGyro = bodyGyro }
end

--// Class
local Vehicle = {}
Vehicle.__index = Vehicle

function Vehicle.new(VehicleRoot: BasePart, TempSettings: {})
	local self = {}

	--// Vehicle
	self.Vehicle = VehicleRoot.Parent

	--// VehicleRoot
	self.VehicleRoot = VehicleRoot

	--// VehicleSeat
	self.VehicleSeat = VehicleRoot.Parent:FindFirstChildOfClass("VehicleSeat")

	--// Controls
	self.SteerFloat = 0
	self.ThrottleFloat = 0

	--// Settings
	self.Settings = TempSettings or {}

	--// Binds & Connections
	self.Binds = {}
	self.Connections = {}

	--// Forces
	self.ClientForces = {}

	--// Client Settings
	self.CurrentSpeed = 0

	--// Server Only
	if RunService:IsServer() then
		self.ServerForces = CreateServerForces(VehicleRoot)
	else
		self.ServerForces = {
			BodyPosition = VehicleRoot:FindFirstChildOfClass("BodyPosition"),
			BodyGyro = VehicleRoot:FindFirstChildOfClass("BodyGyro"),
		}
	end

	setmetatable(self, Vehicle)
	return self
end

function Vehicle:CreateSettings()
	local Vehicle: Model = self.Vehicle
	local VehicleRoot: BasePart = self.VehicleRoot

	for SettingName, SettingValue in pairs(DefualtSettings) do
		self.Settings[SettingName] = SettingValue

		Vehicle:SetAttribute(SettingName, SettingValue)
	end

	self:SetWeight()
end

function Vehicle:SetWeight()
	local Vehicle: Model = self.Vehicle

	Vehicle:SetAttribute("Weight", Weight(Vehicle))

	Vehicle.DescendantAdded:Connect(function(descendant)
		Vehicle:SetAttribute("Weight", Weight(Vehicle))
	end)
end

function Vehicle:CreateWheels()
	local Vehicle = self.Vehicle
	local VehicleRoot = self.VehicleRoot

	local WheelsMeshes: Wheels.WheelMeshes, Attachments: Wheels.Attachments, Springs: Wheels.Springs, Forces: Wheels.Forces, BodyForce: VectorForce, Torque: Torque

	if RunService:IsClient() then
		WheelsMeshes = Wheels.GetWheels(Vehicle:WaitForChild("Wheels"))
		Attachments = GetInstances(Vehicle, "Attachment")
		Forces = GetInstances(Vehicle, "VectorForce")
		Torque = VehicleRoot:WaitForChild("Torque")
		Springs = Wheels.CreateSprings(self.VehicleRoot, Attachments)
	else
		WheelsMeshes, Attachments, Springs, Forces, BodyForce, Torque = Wheels.CreateWheels(self.VehicleRoot)
	end

	self.Torque = Torque
	self.Forces = Forces
	self.Springs = Springs
	self.WheelMeshes = WheelsMeshes
	self.Attachments = Attachments
end

function Vehicle:Update(deltaTime: number)
	local VehicleSeat: VehicleSeat = self.VehicleSeat
	local VehicleRoot: BasePart = self.VehicleRoot

	local Torque: Torque = self.Torque
	local Forces: Wheels.Forces = self.Forces
	local Springs: Wheels.Springs = self.Springs
	local WheelMeshes: Wheels.WheelMeshes = self.WheelMeshes
	local Attachments: Wheels.Attachments = self.Attachments

	if VehicleSeat.Occupant then
		if RunService:IsClient() then
			Controls.Update(self, deltaTime, VehicleSeat, VehicleRoot, Torque)
			Wheels.ClientUpdate(self, deltaTime, Attachments, WheelMeshes, Springs, Forces, Torque)
		end
	else
		if RunService:IsServer() then
			Wheels.ServerUpdate(self, self.ServerForces, Attachments)
		end
	end
end

function Vehicle:KillForces()
	local BodyGyro: BodyGyro = self.ServerForces["BodyGyro"]
	local BodyPosition: BodyPosition = self.ServerForces["BodyPosition"]

	BodyGyro.MaxTorque = Vector3.zero
	BodyPosition.MaxForce = Vector3.zero
end

function Vehicle:Listen()
	local VehicleSeat: VehicleSeat = self.VehicleSeat

	if RunService:IsServer() then
		VehicleSeat:GetPropertyChangedSignal("Occupant"):Connect(function()
			self:Disconnect()

			local Occupant = VehicleSeat.Occupant

			if Occupant then
				self:KillForces()

				local Player = SetNetworkOwner(VehicleSeat.Occupant, VehicleSeat.Parent)

				if not Players:GetPlayerFromCharacter(Occupant.Parent) then
					VehicleSeat.Occupant = nil
				end
			else
				self:Connect()
			end
		end)
	else
		-- Client Connection
		VehicleSeat:GetPropertyChangedSignal("Occupant"):Connect(function()
			local Occupant = VehicleSeat.Occupant

			if Occupant and Players:GetPlayerFromCharacter(Occupant.Parent) == Players.LocalPlayer then
				self:Connect()
				self.occupant = Players:GetPlayerFromCharacter(Occupant.Parent)

				self.Connections["CurrentPlayerSeat"] = VehicleSeat:GetPropertyChangedSignal("Occupant")
					:Connect(function()
						self:Disconnect()
					end)
			end
		end)
	end
end

function Vehicle:Connect()
	local VehicleSeat: VehicleSeat = self.VehicleSeat
	local VehicleRoot: BasePart = self.VehicleRoot

	if RunService:IsClient() then
		self.Connections["Steer"] = VehicleSeat:GetPropertyChangedSignal("SteerFloat"):Connect(function()
			self.SteerFloat = VehicleSeat.SteerFloat
			-- VehicleRoot.AssemblyAngularVelocity =  VehicleRoot.AssemblyAngularVelocity:Lerp()
		end)

		self.Connections["Throttle"] = VehicleSeat:GetPropertyChangedSignal("Throttle"):Connect(function()
			self.Throttle = VehicleSeat.Throttle
		end)

		ContextActionService:BindAction("Drifting", function(...)
			Controls.Drift(self, ...)
		end, true, Enum.KeyCode.LeftShift)

		table.insert(self.Binds, "Drifting")
	end

	self.Connections["Update"] = RunService[RunService:IsServer() and "Heartbeat" or "RenderStepped"]:Connect(
		function(deltaTime)
			self:Update(deltaTime)
		end
	)
end

function Vehicle:Disconnect(...)
	if #{ ... } > 0 then
		for __, ParameterConnection: RBXScriptConnection in pairs({ ... }) do
			ParameterConnection:Disconnect()
		end
	else
		for _, Connection: RBXScriptConnection in pairs(self.Connections) do
			Connection:Disconnect()
		end
	end

	for i, BindName in pairs(self.Binds) do
		ContextActionService:UnbindAction(BindName)
	end
end

function Vehicle:Init()
	self:CreateSettings()
	self:CreateWheels()
	self:Listen()
	if RunService:IsServer() then
		self:Connect()
	end
end

return Vehicle
