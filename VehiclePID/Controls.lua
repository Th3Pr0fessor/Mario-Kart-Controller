--[[
Controls

    A short description of the module.

SYNOPSIS

    -- Lua code that showcases an overview of the API.
    local foobar = Controls.TopLevel('foo')
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

-- Implementation of Controls.

--// Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--// module
local Controls = {}

export type AngularForces = { [string]: AngularVelocity }

local function Lerp(a, b, t)
	return a + (b - a) * t
end

function Controls.Drift(self, actionName, inputState, _inputObject)
	local VehicleRoot: BasePart = self.VehicleRoot
	local VehicleSeat: VehicleSeat = self.VehicleSeat

	if actionName == "Drifting" then
		if inputState == Enum.UserInputState.Begin then
			VehicleRoot:ApplyImpulse(VehicleRoot.CFrame.UpVector * 800)

			if VehicleSeat.Steer ~= 0 then
				self.SteerStartAngle = VehicleRoot.Orientation.Y
				self.SteerDesired = 0
				self.SteerDirection = VehicleSeat.Steer
				self.Drifting = true
			end
		else
			self.Drifting = false
		end
	end
end

local MaxSteerAngle = 20
local BaseDriftAngle = 50
local force = 40000

function Controls.Update(
	self,
	deltaTime: number,
	VehicleSeat: VehicleSeat,
	VehicleRoot: BasePart,
	Torque: AngularVelocity
)
	local Velocity = VehicleSeat.AssemblyLinearVelocity
	local CurrentSpeedPercent = VehicleSeat.AssemblyLinearVelocity.Magnitude / VehicleSeat.MaxSpeed

	local MaxSpeed = VehicleSeat.MaxSpeed
	local SteerDirection = 1
	local DesiredSteerRotation = 0
	local DriftVelocity = Vector3.zero

	if self.Drifting and VehicleSeat.Throttle > 0 then
		local DriftForce = VehicleRoot.CFrame.RightVector * force * -self.SteerDirection * deltaTime
		local DriftAngle = self.SteerStartAngle + -(self.SteerDirection * BaseDriftAngle)
		local CurrentAngle = VehicleRoot.Orientation.Y
		local DesiredY = -VehicleSeat.Steer * 2

		CurrentAngle += DesiredY

		VehicleRoot.Orientation = VehicleRoot.Orientation:Lerp(
			Vector3.new(VehicleRoot.Orientation.X, CurrentAngle, VehicleRoot.Orientation.Z),
			0.6
		)
		VehicleRoot:ApplyImpulse(Vector3.new(DriftForce.X, 0, DriftForce.Z))
	else
		DesiredSteerRotation = ((-VehicleSeat.Steer * SteerDirection) * VehicleSeat.TurnSpeed) * CurrentSpeedPercent
		-- print("\n", DesiredSteerRotation)
		self.Drifting = false
	end

	if self.CurrentSpeed < MaxSpeed then
		local Desired = 0
		local Time = 0.8
		if VehicleSeat.Throttle > 0 then
			Desired = MaxSpeed * VehicleSeat.Throttle
			Time = 1 * deltaTime
		elseif VehicleSeat.Throttle < 0 then
			Desired = -MaxSpeed / 1.6
			Time = 0.03
			SteerDirection = -1
		else
			Desired = 0
			Time = 0.01
		end
		self.CurrentSpeed = Lerp(self.CurrentSpeed, Desired, Time)
	end

	local DesiredVelocity: Vector3 = VehicleRoot.CFrame.LookVector * self.CurrentSpeed

	VehicleSeat.AssemblyLinearVelocity =
		Vector3.new(DesiredVelocity.X, VehicleSeat.AssemblyLinearVelocity.Y, DesiredVelocity.Z)
	Torque.AngularVelocity = Vector3.new(0, DesiredSteerRotation, 0) -- * VehicleSeat.Steer
end

return Controls
