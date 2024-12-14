----!strict

-- Getting services
local RUN_SERVICE = game:GetService("RunService")
local TWEEN_SERVICE = game:GetService("TweenService")
local DEBRIS = game:GetService("Debris")

-- Creates a type for the functions
type NpcImp = {
	__index: NpcImp,
	new: (data: {Model | IntValue | Player}) -> NpcClass,
	MoveTo: (self: NpcClass, location: Vector3) -> (),
	Explode: (self: NpcClass) -> (),
	Fling: (self: NpcClass, Speed: IntValue) -> ()
}

-- Creates a type for the object properties
type NpcClass = typeof(setmetatable({}:: {
	Model: Model, 
	WalkSpeed: IntValue,
	WalkAnimationId: number,
	WalkAnimTrack: AnimationTrack,
	IdleAnimationId: number,
	IdleAnimTrack: AnimationTrack,
	MoveConnection: RBXScriptConnection,
}, {}:: NpcImp))


local NpcClass: NpcImp = {}:: NpcImp
NpcClass.__index = NpcClass -- set meta-method

-- Usually I would put these in a seperate module
local Names: {string} = {"Bob", "Billy", "Rob", "Richard", "Finley"}
local Speeches: {string} = {
	"Wow there is a player in the game!",
	"I'm just exploring the world",
	"I'm getting tired from walking",
	"Woah whats good bro"
}

-- Creates new NPC object
function NpcClass.new(data): NpcClass
	local self = {}

	self.Model = data.Rig
	self.Model.Parent = workspace
	self.Model:SetAttribute("Exploding", false)
	
	self.WalkSpeed = data.Speed
	self.WalkAnimationId = data.WalkAnim or nil; self.WalkAnimTrack = nil
	self.IdleAnimationId = data.IdleAnim or nil; self.IdleAnimTrack = nil
	self.MoveConnection = nil

	local Animator: Animator = self.Model.Humanoid.Animator

	if self.WalkAnimationId then -- The user might not have included an ID so we check
		local WalkAnimation: Animation = Instance.new("Animation", script) -- Storing the animation in the script because playing animations is replicated.
		WalkAnimation.Name = "Walk"
		WalkAnimation.AnimationId = self.WalkAnimationId
		self.WalkAnimTrack = Animator:LoadAnimation(WalkAnimation) -- Using animator instead of humanoid due to roblox update
	end

	if self.IdleAnimationId then -- The user might not have included an ID so we check
		local IdleAnimation: Animation = Instance.new("Animation", script)
		IdleAnimation.Name = "Idle"
		IdleAnimation.AnimationId = self.IdleAnimationId
		self.IdleAnimTrack = Animator:LoadAnimation(IdleAnimation)
	end

	-- Randomising appearance

	local Skin = Color3.fromRGB(math.random(1, 255), math.random(1, 255), math.random(1, 255))
	local Shirt = Color3.fromRGB(math.random(1, 255), math.random(1, 255), math.random(1, 255))
	local Pants = Color3.fromRGB(math.random(1, 255), math.random(1, 255), math.random(1, 255))

	local BodyColors: BodyColors = self.Model["Body Colors"]
	BodyColors.HeadColor3 = Skin
	BodyColors.LeftArmColor3 = Skin
	BodyColors.RightArmColor3 = Skin
	BodyColors.TorsoColor3 = Shirt
	BodyColors.LeftLegColor3 = Pants
	BodyColors.RightLegColor3 = Pants

	local NameIndex = Names[math.random(1, #Names)]
	local LowerText = self.Model.Head.NameTag.LowerText
	local UpperText = self.Model.Head.NameTag.UpperText

	self.Model.Name = NameIndex
	UpperText.Text = NameIndex
	LowerText.Text = Speeches[math.random(1, #Speeches)]

	task.spawn(function()
		while task.wait(5) do -- Changes the speech of the NPC every 5 seconds, this function breaks once the npc is destroyed
			LowerText = Speeches[math.random(1, #Speeches)]

			if not self.Model then
				break 
			end
		end
	end)

	return setmetatable(self, NpcClass)
end

function NpcClass:MoveTo(location)
	if self.MoveConnection ~= nil then -- checking if the npc is already moving, if it is then cancel the movement.
		self.MoveConnection:Disconnect() -- I would stop the walk anim here but we would play it anyway so there's no point
	end

	local StartPosition: Vector3 = self.Model.HumanoidRootPart.Position
	local Alpha: number = 0 -- Setting the delta outside the connection because we're using render stepped.

	if self.IdleAnimTrack and self.IdleAnimTrack.IsPlaying == true then -- check if the animation track is playing, if it is then stop it
		self.IdleAnimTrack:Stop()
	end

	self.WalkAnimTrack:Play()

	self.MoveConnection = RUN_SERVICE.RenderStepped:Connect(function(delta)
		Alpha = math.clamp(Alpha + (self.WalkSpeed * delta) / (StartPosition - location).Magnitude, 0, 1) -- This calculates an alpha that uses a speed constant. It's also clamped to never go over 1 but I don't think it's needed tbh

		local Interpolation: Vector3 = StartPosition:Lerp(location, Alpha)

		self.Model:PivotTo(CFrame.lookAlong(Interpolation, (location - StartPosition).Unit)) -- Using CFrame.lookalong to make the NPC look at the destination while going to it

		if Alpha >= 1 then -- once the alpha 1 is one we disconnect everything and stop and start the right animations
			self.MoveConnection:Disconnect() 

			if self.WalkAnimTrack and self.WalkAnimTrack.IsPlaying == true then
				self.WalkAnimTrack:Stop()
			end

			if self.IdleAnimTrack then
				self.IdleAnimTrack:Play()
			end
		end
	end)

	self.WalkAnimTrack.Ended:Wait()
end

function NpcClass:Delete()
	if self.MoveConnection ~= nil then  -- disconnect a moveconnection if its moving
		self.MoveConnection:Disconnect() 
	end

	if self.Model then
		self.Model:Destroy()
	end
	table.clear(self) -- same as self = nil
end

function NpcClass:Explode()
	if self.Model:GetAttribute("Exploding") == true then -- preventing this from running multiple times
		return
	end
	
	self.Model:SetAttribute("Exploding", true)
	task.spawn(function() -- looping through every part and making it tween to red. U?sing task.Spawn so it does it at the same time for every part.
		for _, part: BasePart in pairs(self.Model:GetChildren()) do
			if part:IsA("BasePart") and part:FindFirstChildOfClass("Attachment") then
				TWEEN_SERVICE:Create(
					part,
					TweenInfo.new(2),
					{Color = Color3.fromRGB(255, 1, 5)}
				):Play()
			end
		end
	end)
	
	task.wait(2)
	
	-- Creates a new part and puts a special mesh inside it to make it a sphere, this is extremely basic and could be improved.
	local NewPart: BasePart = Instance.new("Part", game.Workspace)
	DEBRIS:AddItem(NewPart, 1)
	NewPart.Transparency = 0.5
	NewPart.Color = Color3.fromRGB(255, 173, 32)
	NewPart.CanCollide = false
	NewPart.Position = self.Model.HumanoidRootPart.Position
	NewPart.Anchored = true
	NewPart.Size = Vector3.new(1,1,1)
	
	local NewExplosionPart: SpecialMesh = Instance.new("SpecialMesh", NewPart)
	NewExplosionPart.MeshType = Enum.MeshType.Sphere
	NewExplosionPart.Scale = Vector3.new(1, 1, 1)
	
	local Grow = TWEEN_SERVICE:Create(NewPart, TweenInfo.new(0.5), {Size = Vector3.new(10, 10, 10)})
	Grow:Play()
	
	Grow.Completed:Once(function() -- We use once because this is going to be fired once, saves a bit of memory by not keeping the connection after it fires once
		self:Delete()
	end)
end

function NpcClass:Fling(Speed) -- similar to :moveTo but is dedicated to sending the npc flying into the abyss
	if self.MoveConnection ~= nil then
		self.MoveConnection:Disconnect() 
	end

	local NewLocation = Vector3.new(math.random(1, 1000), math.random(1, 1000), math.random(1, 1000)) -- We don't do a negative value because the NPC would fling under the world which doesn't make sense
	local StartPosition: Vector3 = self.Model.HumanoidRootPart.Position
	local Alpha: number = 0
	
	-- Yeah I've already explained the stuff below in :moveTo
	self.MoveConnection = RUN_SERVICE.RenderStepped:Connect(function(delta)
		Alpha = math.clamp(Alpha + ((Speed or 100) * delta) / (StartPosition - NewLocation).Magnitude, 0, 1) 

		local Interpolation: Vector3 = StartPosition:Lerp(NewLocation, Alpha)

		self.Model:PivotTo(CFrame.lookAlong(Interpolation, (NewLocation - StartPosition).Unit))

		if Alpha >= 1 then
			self.MoveConnection:Disconnect()
			self:Delete()
		end
	end)
end

return NpcClass

--[[
Cover letter to application reader.

To whom it may concern,
Hello, this is an extremely basic NPC system. Due to the fact I was limited to using one script I had to make this client only otherwise I would be using remote events: normally
I would let the server handle all the positions and the client handle all the movement animations. The animations currently don't work and I can't figure out why. I've been trying
to figure it out for ages but hopefully you understand what I was trying to do lol. I would spend more time to debug the issue and fix it however I'm quite busy with college and
my game. Thank you for considering my application.

Lots of blox,
Sindious
]]--
