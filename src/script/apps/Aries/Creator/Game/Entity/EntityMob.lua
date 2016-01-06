--[[
Title: Mob entity
Author(s): LiXizhi
Date: 2013/7/14
Desc: 
use the lib:
------------------------------------------------------------
NPL.load("(gl)script/apps/Aries/Creator/Game/Entity/EntityMob.lua");
local EntityMob = commonlib.gettable("MyCompany.Aries.Game.EntityManager.EntityMob")
local entity = MyCompany.Aries.Game.EntityManager.EntityMob:new({x,y,z,radius});
entity:Attach();
-------------------------------------------------------
]]
NPL.load("(gl)script/apps/Aries/Creator/Game/Items/ItemClient.lua");
NPL.load("(gl)script/apps/Aries/Creator/Game/Common/Direction.lua");
NPL.load("(gl)script/apps/Aries/Creator/Game/Entity/EntityMovable.lua");
NPL.load("(gl)script/apps/Aries/Creator/Game/Entity/PlayerSkins.lua");
NPL.load("(gl)script/apps/Aries/Creator/Game/Common/Variables.lua");
NPL.load("(gl)script/apps/Aries/Creator/Game/Common/Files.lua");
local Files = commonlib.gettable("MyCompany.Aries.Game.Common.Files");
local Variables = commonlib.gettable("MyCompany.Aries.Game.Common.Variables");
local PlayerSkins = commonlib.gettable("MyCompany.Aries.Game.EntityManager.PlayerSkins")
local Direction = commonlib.gettable("MyCompany.Aries.Game.Common.Direction")
local ItemClient = commonlib.gettable("MyCompany.Aries.Game.Items.ItemClient");
local PhysicsWorld = commonlib.gettable("MyCompany.Aries.Game.PhysicsWorld");
local BlockEngine = commonlib.gettable("MyCompany.Aries.Game.BlockEngine")
local TaskManager = commonlib.gettable("MyCompany.Aries.Game.TaskManager")
local block_types = commonlib.gettable("MyCompany.Aries.Game.block_types")
local GameLogic = commonlib.gettable("MyCompany.Aries.Game.GameLogic")
local EntityManager = commonlib.gettable("MyCompany.Aries.Game.EntityManager");
local QuickSelectBar = commonlib.gettable("MyCompany.Aries.Creator.Game.Desktop.QuickSelectBar");
NPL.load("(gl)script/ide/headon_speech.lua");

local math_abs = math.abs;
local math_random = math.random;
local math_floor = math.floor;

local Entity = commonlib.inherit(commonlib.gettable("MyCompany.Aries.Game.EntityManager.EntityMovable"), commonlib.gettable("MyCompany.Aries.Game.EntityManager.EntityMob"));

-- persistent object by default. 
Entity.is_persistent = true;
-- class name
Entity.class_name = "Mob";
-- register class
EntityManager.RegisterEntityClass(Entity.class_name, Entity);
-- enabled frame move. 
Entity.framemove_interval = 0.2;
Entity.can_random_move = true;
Entity.hp = 0;
Entity.respawn_time = 0;
Entity.group_id = GameLogic.SentientGroupIDs.Mob;

function Entity:init()
	if(not Entity._super.init(self)) then
		return;
	end
	self.variables = Variables:new();
	self.variables:CreateVariable("name", self.GetDisplayName, self);

	local obj = self:GetInnerObject();
	local item = self:GetItemClass();
	if(item and obj) then
		self.hp = item.hp or 1;
		self.respawn_time = item.respawn_time or 300000;
		return self;
	end
end

-- virtual function: overwrite to customize physical object
function Entity:CreatePhysicsObject()
	local physic_obj = Entity._super.CreatePhysicsObject(self);
	physic_obj:SetRadius(BlockEngine.half_blocksize);
	physic_obj:SetCanBounce(false);
	physic_obj:SetSurfaceDecay(3);
	physic_obj:SetAirDecay(0);
	physic_obj:SetMinSpeed(0.1);
	return physic_obj;
end

function Entity:CanTeleport()
	return true;
end

-- set the model name
function Entity:SetMainAssetPath(name)
	if(self:GetMainAssetPath() ~= name) then
		self.mainAssetPath = name;
		self:RefreshClientModel(true);
	end
end

function Entity:OnRespawn()
	local item = self:GetItem();
	if(item) then
		self.hp = item.hp or 1;
		local mob = self:GetInnerObject();
		if(not mob) then
			return;
		end
		mob:SetVisible(true);
	end
end

function Entity:OnDead()
	self.hp = 0;
	self.dead_time = commonlib.TimerManager.GetCurrentTime();

	local mob = self:GetInnerObject();
	if(not mob) then
		return;
	end
	mob:SetVisible(false);

	if(not self.collected) then
		self.collected = true;
		local item = self:GetItem();
		if(item) then
			GameLogic.events:DispatchEvent({type = "OnCollectItem" , block_id = self.item_id, count = 1});
			item:CreateBlockPieces(self.bx, self.by, self.bz);
		end
	end
end

-- virtual function: when the entity is hit (attacked) by the missile
function Entity:OnHit(attack_value, fromX, fromY, fromZ)
	local mob = self:GetInnerObject();
	if(not mob) then
		return;
	end
	local mobChar = mob:ToCharacter()
	mobChar:Stop();
	if(mobChar:HasAnimation(73)) then
		mobChar:PlayAnimation(73);
	end

	local spritestyle = "CombatDigits";
	local color = "da2d2d";
	-- TODO: attack - defense, plus some bonus point
	local damage = math.random(attack_value, attack_value+10);
	self.hp = self.hp - damage;
	
	if(self.hp <= 0) then
		self:OnDead();
	end

	local content = string.format("-%d", damage);
	
	local anim_type = "plain";
	local mcml_str = string.format([[<aries:textsprite spritestyle="%s" color="#%s" text="%s" default_fontsize="12" fontsize="19"/>]], spritestyle, color, content);

	local sCtrlName = headon_speech.Speek(mob.name, mcml_str, 2, true, true, true, -1);
	if(sCtrlName) then
		if(anim_type == "plain") then
			UIAnimManager.PlayCustomAnimation(800, function(elapsedTime)
				local parent = ParaUI.GetUIObject(sCtrlName);
				if(parent:IsValid()) then
					local t = elapsedTime / 1000
					parent.translationx = math.floor( - 100 * t );
					parent.translationy = math.floor( -60 * t + 50 * t * t);
					
					if(elapsedTime < 400) then
					else
						parent.colormask = format("255 255 255 %d", math.floor( (1 - (elapsedTime-400) / 400)*255) );
					end
					parent:ApplyAnim();
				end
			end);
		end
	end
end

-- let the camera focus on this player and take control of it. 
-- @return return true if focus is set
function Entity:SetFocus()
	EntityManager.SetFocus(self);
	return true;
end

function Entity:CheckRespawn()
	self.dead_time = self.dead_time or commonlib.TimerManager.GetCurrentTime();
	if ((self.dead_time + self.respawn_time) < commonlib.TimerManager.GetCurrentTime()) then
		self:OnRespawn();
	end
end

-- @param bPreviousSkin: nil for next, true for previous
-- return true if toggled, or nil if no skin to toggle.
function Entity:ToggleNextSkin(bPreviousSkin)
	local obj = self:GetInnerObject();
	if(obj) then
		if(PlayerSkins:CheckModelHasSkin(obj:GetPrimaryAsset():GetKeyName())) then
			self:SetSkin(PlayerSkins:GetNextSkin(bPreviousSkin));
			return true;
		else
			self:SetSkin(nil);
		end
	end
end

-- set whether the mob will move according to its own logic. 
function Entity:SetCanRandomMove(bCanRandomMove)
	self.can_random_move = bCanRandomMove;
end

-- @param filename: can be relative to current world.
function Entity:SetModelFile(filename)
	if(self.model_filename ~= filename) then
		self.model_filename = filename;
		filename = Files.GetWorldFilePath(filename);
		self:SetMainAssetPath(filename);
	end
end

function Entity:GetModelFile()
	return self.model_filename;
end

function Entity:LoadFromXMLNode(node)
	Entity._super.LoadFromXMLNode(self, node);

	local attr = node.attr;
	if(attr) then
		if(attr.can_random_move) then
			self.can_random_move = (attr.can_random_move ~= "false" and attr.can_random_move~=false)
		end
		if(attr.model_filename) then
			self:SetModelFile(attr.model_filename);
		end
	end
end

function Entity:SaveToXMLNode(node)
	node = Entity._super.SaveToXMLNode(self, node);
	if(not self.can_random_move) then
		node.attr.can_random_move = false;
	end
	if(self:GetModelFile()) then
		node.attr.model_filename = self:GetModelFile();
	end
	return node;
end

function Entity:CanBePushedBy(fromEntity)
    return true;
end

-- virtual function: get array of item stacks that will be displayed to the user when user try to create a new item. 
-- @return nil or array of item stack.
function Entity:GetNewItemsList()
	local itemStackArray = Entity._super.GetNewItemsList(self) or {};
	local ItemStack = commonlib.gettable("MyCompany.Aries.Game.Items.ItemStack");
	itemStackArray[#itemStackArray+1] = ItemStack:new():Init(block_types.names.CommandLine,1);
	itemStackArray[#itemStackArray+1] = ItemStack:new():Init(block_types.names.Code,1);
	return itemStackArray;
end

-- called every frame
function Entity:FrameMove(deltaTime)
	Entity._super.FrameMove(self, deltaTime);

	-- check respawn
	if (self.hp <= 0) then
		self:CheckRespawn()
		return;
	end
	if(self.can_random_move and not self:HasSpeed()) then
		self:TryMoveRandomly();
	end
end