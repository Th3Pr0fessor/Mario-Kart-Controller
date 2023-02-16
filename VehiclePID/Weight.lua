return function(Object): number
	local mass = 0
	for i, v in pairs(Object:GetChildren()) do
		if v:IsA("BasePart") then
			mass = mass + (v:GetMass() * 196.2)
		end
	end
	return mass
end
