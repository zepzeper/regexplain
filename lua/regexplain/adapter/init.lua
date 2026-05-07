local registry = require("regexplain.adapter.registry")

  registry.register("lua", require("regexplain.adapter.adapters.lua"))
registry.register("vim", require("regexplain.adapter.adapters.vim"))
registry.register("pcre", require("regexplain.adapter.adapters.pcre"))

return registry
