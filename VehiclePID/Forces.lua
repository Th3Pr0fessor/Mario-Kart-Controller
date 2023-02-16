local function createRootAttachment(Root): Attachment
	local Attachment = Instance.new("Attachment")
	Attachment.Parent = Root
	Attachment.Name = "Body"

	return Attachment
end

local function createTurnAttachment(Root)
	local TurnAttachment = Root:FindFirstChild("TurnAttachment") or Instance.new("Attachment")
	TurnAttachment.Name = "TurnAttachment"
	TurnAttachment.Parent = Root
	TurnAttachment.CFrame = CFrame.new(0, -Root.Size.Y / 2.2, -Root.Size.Z / 2.2)

	TurnAttachment.Visible = true

	return TurnAttachment
end

local function createRootTorque(Root, Attachment): Attachment
	local Torque = Root:FindFirstChild("Torque") or Instance.new("AngularVelocity")
	Torque.Attachment0 = Attachment
	Torque.RelativeTo = Enum.ActuatorRelativeTo.Attachment0
	Torque.Visible = true
	Torque.Name = "Torque"
	Torque.ReactionTorqueEnabled = true
	Torque.MaxTorque = math.huge
	-- Torque.MaxTorque = Vector3.new(0, math.huge, 0)
	-- Torque.P = 3000
	Torque.AngularVelocity = Vector3.zero

	Torque.Parent = Root

	return Attachment
end

return function(Chasis: Part, Attachments: { [string]: Attachment }): VectorForce & { [string]: VectorForce }
	local VectorForces = {}
	local AngularForces = {}

	Chasis.Transparency = 0.5

	local Front = Chasis.Size.Z / 2.2
	local Right = Chasis.Size.X / 2
	local Bottom = -Chasis.Size.Y / 2 + 0.25

	local Positions = {
		FrontRight = CFrame.new(Right, Bottom, Front),
		FrontLeft = CFrame.new(-Right, Bottom, Front),
		RearRight = CFrame.new(Right, Bottom, -Front),
		RearLeft = CFrame.new(-Right, Bottom, -Front),
	}

	local RootForce = Instance.new("VectorForce")
	RootForce.Visible = true
	RootForce.Force = Vector3.zero
	RootForce.Color = BrickColor.Green()
	RootForce.Name = "BodyForce"
	RootForce.Attachment0 = Chasis:FindFirstChild("Body") or createRootAttachment(Chasis)
	RootForce.RelativeTo = Enum.ActuatorRelativeTo.World
	RootForce.Parent = Chasis

	local Torque = createRootTorque(Chasis, createTurnAttachment(Chasis))

	for WheelName, Position: CFrame in pairs(Positions) do
		local VectorForce = Instance.new("VectorForce")
		VectorForce.Visible = true
		VectorForce.Force = Vector3.zero
		VectorForce.Color = BrickColor.Green()
		VectorForce.Name = WheelName .. "VectorForce"
		VectorForce.Attachment0 = Attachments[WheelName]
		VectorForce.RelativeTo = Enum.ActuatorRelativeTo.Attachment0
		VectorForce.Parent = Chasis

		VectorForces[WheelName] = VectorForce
	end

	return RootForce, VectorForces, Torque
end
