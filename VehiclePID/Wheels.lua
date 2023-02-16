--[[
Wheels

    A short description of the module.

SYNOPSIS

    -- Lua code that showcases an overview of the API.
    local foobar = Wheels.TopLevel('foo')
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

-- Implementation of Wheels.

--// Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--// Modules
local Modules = script.Parent
local Spring = require(Modules.RoPID)
local Raycast = require(Modules.Raycast)
local InitForces = require(Modules.Forces)
local InitAttachments = require(Modules.Attach)

export type AngularForces = { [string]: AngularVelocity }
export type Attachments = { [string]: Attachment }
export type WheelMeshes = { [string]: Attachment }
export type Springs = { [string]: Spring.Spring }
export type Forces = { [string]: VectorForce }

--// Class
local Wheels = {}
Wheels.__index = Wheels

function Wheels.CreateSprings(VehicleRoot, Attachments): Springs
	local Vehicle: Model = VehicleRoot.Parent

	-- local Attachments: Attachments = InitAttachments(VehicleRoot)
	-- local BodyForce, Forces, AngularForces: VectorForce & Forces & AngularForces = InitForces(VehicleRoot, Attachments)

	local Springs = {}

	for WheelName: string, WheelAttachment: Attachment in pairs(Attachments) do
		local CurrentSpring: Spring.Spring =
			Spring.new(Vehicle:GetAttribute("Stiffness"), 1, Vehicle:GetAttribute("Damping"), nil, nil)

		Springs[WheelName] = CurrentSpring
	end

	return Springs
end

function Wheels.CreateWheelModels(Vehicle, Attachments)
	local Wheels: WheelMeshes = {}

	local WheelsFolder = Instance.new("Folder")
	WheelsFolder.Name = "Wheels"
	WheelsFolder.Parent = Vehicle

	for AttachmentName, Attachment: Attachment in Attachments do
		local Assets = ReplicatedStorage:FindFirstChild("Assets")
		local WheelMesh: MeshPart = Assets:FindFirstChild("Wheel"):Clone()
		local WheelAttachment: Attachment = WheelMesh:FindFirstChild("Attachment")
		local RigidConstraint: RigidConstraint = WheelMesh:FindFirstChild("RigidConstraint")

		WheelMesh.Name = AttachmentName

		RigidConstraint.Attachment0 = WheelAttachment
		RigidConstraint.Attachment1 = Attachment

		WheelMesh.Parent = WheelsFolder
		Wheels[AttachmentName] = WheelAttachment
	end

	return Wheels
end

function Wheels.GetWheels(WheelsFolder)
	local Wheels = {}

	for _, WheelMesh: MeshPart in pairs(WheelsFolder:GetChildren()) do
		Wheels[WheelMesh.Name] = WheelMesh:FindFirstChild("Attachment")
	end

	return Wheels
end

function Wheels.CreateWheels(VehicleRoot): Attachments & VectorForce & Springs
	local Vehicle: Model = VehicleRoot.Parent

	local Attachments: Attachments = InitAttachments(VehicleRoot)
	local WheelMeshes: WheelMeshes = Wheels.CreateWheelModels(Vehicle, Attachments)

	local BodyForce, Forces, AngularForces: VectorForce & Forces & AngularForces = InitForces(VehicleRoot, Attachments)
	local Springs = {}

	for WheelName: string, WheelAttachment: Attachment in pairs(Attachments) do
		local CurrentSpring: Spring.Spring =
			Spring.new(Vehicle:GetAttribute("Stiffness"), 1, Vehicle:GetAttribute("Damping"), nil, nil)

		Springs[WheelName] = CurrentSpring
	end

	return WheelMeshes, Attachments, Springs, Forces, BodyForce, AngularForces
end

function Wheels.new(Wheels)
	local info = {}

	setmetatable(info, Wheels)
	return info
end

local memory = {}

type ServerForces = {
	BodyPosition: BodyPosition,
	BodyGyro: BodyGyro,
}

local function Lerp(a, b, t)
	return a + (b - a) * t
end

function Wheels.ServerUpdate(self, ServerForces: ServerForces, Attachments: Attachments)
	local Vehicle: Model = self.Vehicle
	local VehicleRoot: BasePart = self.VehicleRoot
	local VehicleSeat: VehicleSeat = self.VehicleSeat

	local BodyGyro: BodyGyro = ServerForces["BodyGyro"]
	local BodyPosition: BodyPosition = ServerForces["BodyPosition"]

	if VehicleSeat.Occupant ~= nil then
		BodyGyro.MaxTorque = Vector3.zero
		BodyPosition.MaxForce = Vector3.zero
		return
	end

	local AverageHeight = 0
	local AverageNormal = Vector3.zero

	local Weight = Vehicle:GetAttribute("Weight")
	local Damping = Vehicle:GetAttribute("Damping")
	local Stiffness = Vehicle:GetAttribute("Stiffness")
	local WheelRadius = Vehicle:GetAttribute("WheelRadius")
	local SuspensionLength = Vehicle:GetAttribute("Suspension")
	local MaxSuspensionLength = (SuspensionLength + WheelRadius)

	local Params = RaycastParams.new()
	Params.FilterDescendantsInstances = { Vehicle }
	Params.FilterType = Enum.RaycastFilterType.Blacklist

	local RaycastResult = Raycast(
		Vehicle.Name .. "Position",
		(VehicleRoot.CFrame * CFrame.new(0, -VehicleRoot.Size.Y / 2, 0)).Position,
		VehicleRoot.CFrame:VectorToWorldSpace(Vector3.new(0, -1, 0)) * MaxSuspensionLength,
		Params
	)

	if RaycastResult then
		local hit = RaycastResult.Instance
		local normal = RaycastResult.Normal
		local position = RaycastResult.Position

		if RaycastResult.Instance.CanCollide then
			BodyPosition.MaxForce = Vector3.new(Weight / 5, math.huge, Weight / 5)
			BodyPosition.Position = (CFrame.new(position, position + normal) * CFrame.new(
				0,
				0,
				-MaxSuspensionLength + 0.5
			)).Position
			BodyGyro.MaxTorque = Vector3.new(math.huge, 0, math.huge)
			BodyGyro.CFrame = CFrame.new(position, position + normal) * CFrame.Angles(-math.pi / 2, 0, 0)
		else
			BodyPosition.MaxForce = Vector3.new()
			BodyGyro.MaxTorque = Vector3.new()
		end
	else
		BodyPosition.MaxForce = Vector3.new()
		BodyGyro.MaxTorque = Vector3.new()
	end
end

local SteerAngle = 30
local WheelFriction = 5.5
local LastDirection = 1

function Wheels.ClientUpdate(
	self,
	deltaTime,
	Attachments: Attachments,
	WheelMeshes: WheelMeshes,

	Springs: Springs,
	Forces: Forces,
	Torque: Torque
)
	local Vehicle: Model = self.Vehicle
	local VehicleRoot: BasePart = self.VehicleRoot
	local VehicleSeat: VehicleSeat = self.VehicleSeat

	local Params = RaycastParams.new()
	Params.FilterDescendantsInstances = { Vehicle }
	Params.FilterType = Enum.RaycastFilterType.Blacklist

	local Weight = Vehicle:GetAttribute("Weight")
	local Damping = Vehicle:GetAttribute("Damping")
	local Stiffness = Vehicle:GetAttribute("Stiffness")
	local WheelRadius = Vehicle:GetAttribute("WheelRadius")
	local SuspensionLength = Vehicle:GetAttribute("Suspension")
	local MaxSuspensionLength = (SuspensionLength + WheelRadius)

	self.LastSteerDirection = self["LastSteerDirection"] or 1

	self.SmoothSteer = math.abs(VehicleSeat.SteerFloat - (self.SmoothSteer or 0)) <= deltaTime * 5
			and VehicleSeat.SteerFloat
		or (self.SmoothSteer or 0) + math.sign(VehicleSeat.SteerFloat - (self.SmoothSteer or 0)) * deltaTime * 5

	for WheelName: string, Wheel: Attachment in pairs(Attachments) do
		local Spring = Springs[WheelName]
		local VectorForce = Forces[WheelName]
		local CurrentWheel = WheelMeshes[WheelName]

		local RaycastResult = Raycast(
			Vehicle.Name .. WheelName,
			Wheel.WorldPosition,
			-Wheel.WorldCFrame.UpVector * MaxSuspensionLength,
			Params
		)

		Spring.Gains.kP = Stiffness
		Spring.Gains.kI = Vehicle:GetAttribute("Integeral")
		Spring.Gains.kD = Damping

		if RaycastResult then
			local Velocity = VehicleRoot:GetVelocityAtPosition(Wheel.WorldPosition)
			local steeringForce: Vector3 = Vector3.zero

			local Output: number = Spring:Calculate(MaxSuspensionLength * 0.8, RaycastResult.Distance, deltaTime)
			local Force: Vector3 = VehicleRoot.CFrame.UpVector * Output * (Weight / workspace.Gravity)

			if WheelName:lower():find("front") then
				local steeringDir: Vector3 = Wheel.WorldCFrame.RightVector * VehicleSeat.Steer
				local vehicleVelocity = VehicleRoot.AssemblyLinearVelocity

				local vehicleSpeed = vehicleVelocity.Magnitude
				local Right = Wheel.CFrame.X > 0 and true or false

				local steeringVelocity: number = steeringDir:Dot(VehicleRoot:GetVelocityAtPosition(Wheel.WorldPosition))
				local velocityChange = -steeringVelocity * WheelFriction

				steeringForce = steeringDir * (Weight / workspace.Gravity) * velocityChange

				local SteerRotation = math.deg(Torque.AngularVelocity.Y)

				Wheel.Orientation = Vector3.new(
					Wheel.Orientation.X,
					Lerp(
						Wheel.Orientation.Y,
						VehicleSeat.Throttle * -VehicleSeat.Steer * 30 + (Right and 180 or 0),
						0.1
					),
					Wheel.Orientation.Z
				)
			end

			if VehicleSeat.Throttle ~= 0 then
				local Test = VehicleRoot.CFrame.LookVector.Z > 0 and 1 or -1
				LastDirection = VehicleSeat.Throttle * -Test
			end

			local Direction = VehicleSeat.Throttle ~= 0 and VehicleSeat.Throttle or LastDirection
			local XRot = Direction * VehicleRoot.AssemblyLinearVelocity.Magnitude
			local Desired = CurrentWheel.CFrame * CFrame.fromEulerAnglesXYZ(math.rad(XRot), 0, 0)

			CurrentWheel.CFrame = CurrentWheel.CFrame:Lerp(Desired, 0.5)

			VectorForce.Force = Force + steeringForce
		else
			VectorForce.Force = Vector3.zero
		end
	end
end

return Wheels
