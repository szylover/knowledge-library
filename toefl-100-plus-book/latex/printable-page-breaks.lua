local in_printable_appendix = false

function Para(element)
  if #element.content == 1
    and element.content[1].t == 'Str'
    and element.content[1].text == '\\newpage' then
    return pandoc.RawBlock('latex', '\\newpage')
  end
end

function Header(element)
  local title = pandoc.utils.stringify(element)

  if element.level == 1 then
    in_printable_appendix = title == '20｜可打印答题纸与记录表'
  elseif in_printable_appendix and element.level == 2 and title ~= '本册索引' then
    return {
      pandoc.RawBlock('latex', '\\addtocontents{toc}{\\protect\\addvspace{10pt}}'),
      element
    }
  end
end
