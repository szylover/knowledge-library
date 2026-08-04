function Table(tbl)
  local count = #tbl.colspecs
  if count == 0 then
    return tbl
  end

  local width = 0.94 / count
  for index, spec in ipairs(tbl.colspecs) do
    tbl.colspecs[index] = { spec[1], width }
  end

  return tbl
end
