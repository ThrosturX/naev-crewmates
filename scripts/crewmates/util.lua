local util = {}

function util.copy_array(source)
   local copy = {}
   for _, value in ipairs(source or {}) do
      copy[#copy + 1] = value
   end
   return copy
end

function util.join_arrays(first, second)
   local joined = util.copy_array(first)
   for _, value in ipairs(second or {}) do
      joined[#joined + 1] = value
   end
   return joined
end

function util.pick_one(values, fallback)
   if not values or #values == 0 then
      return fallback
   end
   return values[rnd.rnd(1, #values)]
end

function util.pick_key(mapping)
   local keys = {}
   for key in pairs(mapping or {}) do
      keys[#keys + 1] = key
   end
   return util.pick_one(keys)
end

function util.pick_from_map(mapping)
   local key = util.pick_key(mapping)
   return key and util.pick_one(mapping[key])
end

function util.merge(target, source)
   for key, value in pairs(source or {}) do
      target[key] = value
   end
   return target
end

function util.sanitize_phrase(phrase, blacklist)
   local blocked = {}
   for _, word in ipairs(blacklist or {}) do
      blocked[word] = true
   end

   local words = {}
   for word in (phrase or ""):gmatch("%w+") do
      if not blocked[word] then
         words[#words + 1] = word
      end
   end
   return table.concat(words, " ")
end

return util
