std = "luajit"
globals = {
  "vim",
  "bit",
}

files["tests/run.lua"] = {
  globals = {
    "describe",
    "it",
    "before_each",
    "after_each",
  },
}
