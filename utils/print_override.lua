local Public = {}

local locale_string = {'', '[PRINT] ', nil}

function print(str)
    locale_string[3] = str
    log(locale_string)
end

local raw_print = print
Public.raw_print = raw_print

return Public
