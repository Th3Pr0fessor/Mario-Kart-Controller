local Rays: Folder = workspace.Terrain:FindFirstChild("Rays")

if not Rays then
	Rays = Instance.new("Folder")
	Rays.Name = "Rays"
	Rays.Parent = workspace.Terrain
end

return function(RayName: string, Origin: Vector3, Direction: Vector3, Params: RaycastParams): RaycastResult
	local RayPart: Part = Rays:FindFirstChild(RayName)

	if not RayPart then
		RayPart = Instance.new("Part")
		RayPart.Size = Vector3.new(0.01, 0.01, math.abs((Origin - (Origin + Direction)).Magnitude))
		RayPart.Name = RayName
		RayPart.Material = Enum.Material.Neon
		RayPart.Anchored = true
		RayPart.CanCollide = false
		RayPart.Parent = Rays
	end

	RayPart.Size = Vector3.new(0.01, 0.01, math.abs((Origin - (Origin + Direction)).Magnitude))
	RayPart.CFrame = CFrame.new((Origin + (Origin + Direction)) / 2, Origin + Direction)

	if Params.FilterType == Enum.RaycastFilterType.Blacklist then
		Params.FilterDescendantsInstances = { Params.FilterDescendantsInstances, Rays:GetDescendants() }
	end

	local rayResults: RaycastResult = workspace:Raycast(Origin, Direction, Params)

	if rayResults then
		RayPart.CFrame = CFrame.new((Origin + rayResults.Position) / 2, rayResults.Position)
		RayPart.Size = Vector3.new(0.01, 0.01, (Origin - rayResults.Position).Magnitude)
		RayPart.Color = Color3.new(0, 0, 1)
	else
		RayPart.Color = Color3.new(1, 0, 0)
	end

	return rayResults
end
