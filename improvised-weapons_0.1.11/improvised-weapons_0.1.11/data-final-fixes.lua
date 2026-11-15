local function add_ingredient(recipe, name, amount)
  if not recipe then return end
  recipe.ingredients = recipe.ingredients or {}
  for _, ingredient in ipairs(recipe.ingredients) do
    if (ingredient.name or ingredient[1]) == name then
      if ingredient.name then ingredient.amount = ingredient.amount + amount
      else ingredient[2] = ingredient[2] + amount end
      return
    end
  end
  table.insert(recipe.ingredients, {type = "item", name = name, amount = amount})
end
for _, name in ipairs({"firearm-magazine", "piercing-rounds-magazine", "uranium-rounds-magazine"}) do
  add_ingredient(data.raw.recipe[name], "coal", 1)
end
add_ingredient(data.raw.recipe["gun-turret"], "electronic-circuit", 5)
add_ingredient(data.raw.recipe["flamethrower-turret"], "electronic-circuit", 10)
local gun = data.raw["ammo-turret"]["gun-turret"]
if gun then
  gun.energy_source = {type = "electric", usage_priority = "primary-input", buffer_capacity = "100kJ",
    input_flow_limit = "1MW", drain = "1kW"}
  gun.energy_per_shot = "10kJ"
  gun.localised_description = {"entity-description.iw-powered-gun-turret"}
end
local technology = data.raw.technology["gun-turret"]
if technology and technology.unit then
  -- Ensure the science prerequisite path cannot itself require gun turrets.
  -- This is normally already true in vanilla, but also avoids a modded cycle.
  local visited = {}
  local function remove_back_edges(name)
    if name == "gun-turret" or visited[name] then return end
    visited[name] = true
    local tech = data.raw.technology[name]
    if not tech then return end
    for i = #(tech.prerequisites or {}), 1, -1 do
      local prerequisite = tech.prerequisites[i]
      if prerequisite == "gun-turret" then table.remove(tech.prerequisites, i)
      else remove_back_edges(prerequisite) end
    end
  end
  remove_back_edges("military-science-pack")
  remove_back_edges("logistic-science-pack")
  technology.unit.ingredients = {{"automation-science-pack",1},{"logistic-science-pack",1},{"military-science-pack",1}}
  technology.prerequisites = technology.prerequisites or {}
  for _, prerequisite in ipairs({"logistic-science-pack", "military-science-pack"}) do
    if data.raw.technology[prerequisite] then
      local present = false
      for _, old in ipairs(technology.prerequisites) do if old == prerequisite then present = true end end
      if not present then table.insert(technology.prerequisites, prerequisite) end
    end
  end
end

local flame = data.raw["fluid-turret"] and data.raw["fluid-turret"]["flamethrower-turret"]
if flame then flame.localised_description = {"entity-description.iw-powered-flamethrower-turret"} end
