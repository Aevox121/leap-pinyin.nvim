-- Deep diagnosis: why does 用 behave differently from 气 in Vim regex?

vim.cmd("enew!")
vim.api.nvim_buf_set_lines(0, 0, -1, false, { "用户名 气泡 中华" })

local line = vim.fn.getline(1)
print("line bytes:", #line)
for i = 1, #line do
  io.write(string.format("%02x ", string.byte(line, i)))
end
print()

-- Direct character match via match()
print("\nmatch() tests:")
print("  match('\\V用', ...):", vim.fn.match(line, "\\V用"))
print("  match('\\V\\[用]', ...):", vim.fn.match(line, "\\V\\[用]"))
print("  match('\\V气', ...):", vim.fn.match(line, "\\V气"))
print("  match('\\V\\[气]', ...):", vim.fn.match(line, "\\V\\[气]"))
print("  match('\\V户', ...):", vim.fn.match(line, "\\V户"))
print("  match('\\V\\[户]', ...):", vim.fn.match(line, "\\V\\[户]"))

-- encoding check
print("\nencoding:", vim.o.encoding)
print("fileencoding:", vim.bo.fileencoding)

-- Try without \V
print("\nWithout \\V (magic):")
print("  match('用', ...):", vim.fn.match(line, "用"))
print("  match('[用]', ...):", vim.fn.match(line, "[用]"))
print("  match('气', ...):", vim.fn.match(line, "气"))
print("  match('[气]', ...):", vim.fn.match(line, "[气]"))

-- Try with very magic
print("\nWith \\v (verymagic):")
print("  match('\\v用', ...):", vim.fn.match(line, "\\v用"))
print("  match('\\v[用]', ...):", vim.fn.match(line, "\\v[用]"))

-- Specifically 用 is U+7528
print(string.format("\n用 codepoint: %d (U+%X)", vim.fn.char2nr("用"), vim.fn.char2nr("用")))
print(string.format("气 codepoint: %d (U+%X)", vim.fn.char2nr("气"), vim.fn.char2nr("气")))
print(string.format("户 codepoint: %d (U+%X)", vim.fn.char2nr("户"), vim.fn.char2nr("户")))
