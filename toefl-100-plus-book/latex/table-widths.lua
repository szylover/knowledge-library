function Table(tbl)
  local count = #tbl.colspecs
  if count == 0 then
    return tbl
  end

  local width = 0.94 / count
  for index, spec in ipairs(tbl.colspecs) do
    tbl.colspecs[index] = { spec[1], width }
  end

  return tbl:walk {
    Str = function(str)
      if not str.text:find('+', 1, true) then
        return nil
      end

      local parts = pandoc.List:new()
      local start = 1
      while true do
        local plus = str.text:find('+', start, true)
        if not plus then
          if start <= #str.text then
            parts:insert(pandoc.Str(str.text:sub(start)))
          end
          break
        end

        if plus > start then
          parts:insert(pandoc.Str(str.text:sub(start, plus - 1)))
        end
        parts:insert(pandoc.Str('+'))
        parts:insert(pandoc.RawInline('latex', '\\penalty0\\hskip0pt\\relax{}'))
        start = plus + 1
      end

      return parts
    end
  }
end
