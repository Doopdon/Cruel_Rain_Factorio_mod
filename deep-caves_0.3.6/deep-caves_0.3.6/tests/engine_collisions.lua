-- Small native placement check independent of the distant-generation suite.
local suite={}
local passed,failed=0,0
local function check(ok,message) assert(ok,message) end
local function test(name,fn)
 local ok,err=pcall(fn)
 if ok then passed=passed+1;log("DC_ENGINE PASS "..name)
 else failed=failed+1;log("DC_ENGINE FAIL "..name..": "..tostring(err)) end
end
function suite.prepare() end
function suite.run()
  test("both nest types allow native unit and character placement inside their footprint",function()
    local surface=game.create_surface("nest-collision-test",{width=64,height=64})
    surface.request_to_generate_chunks({0,0},1);surface.force_generate_chunk_requests()
    for _,entity in pairs(surface.find_entities_filtered{}) do entity.destroy() end
    local tiles={}
    for x=-12,12 do for y=-12,12 do tiles[#tiles+1]={name="concrete",position={x,y}} end end
    surface.set_tiles(tiles)
    for _,name in ipairs({"biter-spawner","spitter-spawner"}) do
      local nest=surface.create_entity{name=name,position={0,0},force="enemy"}
      check(nest and nest.valid,"could not create "..name)
      for _,unit in ipairs({"small-biter","behemoth-biter","small-spitter","behemoth-spitter","character"}) do
        check(surface.can_place_entity{name=unit,position={0,0}},unit.." blocked by "..name)
      end
      check(nest.health>0 and nest.destructible,"nest became invulnerable")
      nest.destroy()
    end
    game.delete_surface(surface)
  end)
 log(string.format("DC_ENGINE RESULT %d passed, %d failed",passed,failed))
 if failed>0 then error("Nest collision regression failed") end
end
return suite
