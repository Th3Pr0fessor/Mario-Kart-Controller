local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage.Modules

local VehicleDictionary = require(Modules.VehicleDictionary)

return function(Chasis: Part): { [string]: Attachment }
	local Attachments = {}

	local WheelInfo = VehicleDictionary.MainKart

	local Front = -(Chasis.Size.Z / 2.2)
	local Right = Chasis.Size.X / 2
	local Bottom = -Chasis.Size.Y / 2 + 0.25

	local Rotate = CFrame.fromEulerAnglesXYZ(0, math.pi, 0)

	local Positions = {
		FrontRight = CFrame.new(Right, Bottom, WheelInfo.Front) * Rotate,
		FrontLeft = CFrame.new(-Right, Bottom, WheelInfo.Front),
		RearRight = CFrame.new(Right, Bottom, WheelInfo.Back) * Rotate,
		RearLeft = CFrame.new(-Right, Bottom, WheelInfo.Back),
	}

	for WheelName, Position: CFrame in pairs(Positions) do
		local Attachment = Instance.new("Attachment")
		Attachment.CFrame = Position
		Attachment.Visible = true
		Attachment.Name = WheelName .. "Attachment"
		Attachment.Parent = Chasis

		Attachments[WheelName] = Attachment
	end

	return Attachments
end
